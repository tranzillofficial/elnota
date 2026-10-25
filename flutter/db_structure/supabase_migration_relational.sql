-- =============================================================================
-- ElNota — Relational Tables Migration
-- Target: Supabase project fsmoerttftxcuxpswufk (PostgreSQL 17.11)
-- Author: ElNota Dev
-- Rationale: Replace single-JSONB-document model with proper relational tables.
--            Flutter Drift uses these same entities locally; the cloud now mirrors
--            the same structure for true field-level querying, indexing, and RLS.
--
-- ⚠️  APPLY MANUALLY via Supabase SQL Editor → New query.
--     Run each section in order. Do NOT run against the existing live DB
--     without reviewing the impact on elnota_cloud / elnota_backups first.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. SAFETY: idempotent helpers
-- -----------------------------------------------------------------------------
-- All CREATE statements use IF NOT EXISTS so re-running is safe.


-- =============================================================================
-- 1. WORKSPACES
--    One row per merchant business. Linked to auth.users via owner_id.
--    Multi-tenant: a user may own or belong to multiple workspaces (future).
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.workspaces (
  id             text        PRIMARY KEY,                  -- Flutter UUID string
  owner_id       uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name           text        NOT NULL,
  currency_code  text        NOT NULL DEFAULT 'EGP',
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  version        bigint      NOT NULL DEFAULT 0,
  deleted_at     timestamptz
);

-- Index for owner lookups
CREATE INDEX IF NOT EXISTS workspaces_owner_idx ON public.workspaces(owner_id);

-- RLS
ALTER TABLE public.workspaces ENABLE ROW LEVEL SECURITY;

CREATE POLICY workspaces_owner_read ON public.workspaces
  FOR SELECT TO authenticated
  USING (owner_id = auth.uid());

CREATE POLICY workspaces_owner_write ON public.workspaces
  FOR ALL TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());


-- =============================================================================
-- 2. CUSTOMERS
--    Core entity. Soft-deleted via deleted_at. Synced with version counter.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.customers (
  id            text        PRIMARY KEY,
  workspace_id  text        NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  name          text        NOT NULL,
  phone         text,
  notes         text,
  version       bigint      NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  deleted_at    timestamptz
);

CREATE INDEX IF NOT EXISTS customers_workspace_idx ON public.customers(workspace_id);
CREATE INDEX IF NOT EXISTS customers_name_idx      ON public.customers(workspace_id, name);

-- RLS
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;

CREATE POLICY customers_workspace_access ON public.customers
  FOR ALL TO authenticated
  USING (
    workspace_id IN (
      SELECT id FROM public.workspaces WHERE owner_id = auth.uid()
    )
  )
  WITH CHECK (
    workspace_id IN (
      SELECT id FROM public.workspaces WHERE owner_id = auth.uid()
    )
  );


-- =============================================================================
-- 3. INVOICES
--    status: 'draft' | 'posted' | 'voided'
--    Amounts stored as integer minor units (piasters). Never floats.
--    is_manual_amount: true = single lump sum; false = computed from line items.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.invoices (
  id               text        PRIMARY KEY,
  workspace_id     text        NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  customer_id      text        NOT NULL REFERENCES public.customers(id)  ON DELETE RESTRICT,
  invoice_number   text,
  status           text        NOT NULL DEFAULT 'draft'
                               CHECK (status IN ('draft', 'posted', 'voided')),
  total_minor      bigint      NOT NULL DEFAULT 0 CHECK (total_minor >= 0),
  discount_minor   bigint      NOT NULL DEFAULT 0 CHECK (discount_minor >= 0),
  notes            text,
  is_manual_amount boolean     NOT NULL DEFAULT false,
  invoice_date     timestamptz NOT NULL DEFAULT now(),
  due_date         timestamptz,
  version          bigint      NOT NULL DEFAULT 0,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  deleted_at       timestamptz,

  -- net is always >= 0
  CONSTRAINT invoices_discount_lte_total CHECK (discount_minor <= total_minor)
);

CREATE INDEX IF NOT EXISTS invoices_workspace_idx ON public.invoices(workspace_id);
CREATE INDEX IF NOT EXISTS invoices_customer_idx  ON public.invoices(customer_id);
CREATE INDEX IF NOT EXISTS invoices_date_idx      ON public.invoices(customer_id, invoice_date DESC);

-- RLS
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

CREATE POLICY invoices_workspace_access ON public.invoices
  FOR ALL TO authenticated
  USING (
    workspace_id IN (SELECT id FROM public.workspaces WHERE owner_id = auth.uid())
  )
  WITH CHECK (
    workspace_id IN (SELECT id FROM public.workspaces WHERE owner_id = auth.uid())
  );


-- =============================================================================
-- 4. INVOICE ITEMS
--    Line items for itemised invoices. Orphaned when invoice is deleted.
--    Amounts stored as minor units.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.invoice_items (
  id               text        PRIMARY KEY,
  invoice_id       text        NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
  product_id       text,                                   -- optional catalog reference
  description      text        NOT NULL,
  quantity         integer     NOT NULL DEFAULT 1 CHECK (quantity > 0),
  unit_price_minor bigint      NOT NULL DEFAULT 0 CHECK (unit_price_minor >= 0),
  discount_minor   bigint      NOT NULL DEFAULT 0 CHECK (discount_minor >= 0),
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS invoice_items_invoice_idx ON public.invoice_items(invoice_id);

-- RLS via invoice join
ALTER TABLE public.invoice_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY invoice_items_workspace_access ON public.invoice_items
  FOR ALL TO authenticated
  USING (
    invoice_id IN (
      SELECT i.id FROM public.invoices i
      JOIN public.workspaces w ON w.id = i.workspace_id
      WHERE w.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    invoice_id IN (
      SELECT i.id FROM public.invoices i
      JOIN public.workspaces w ON w.id = i.workspace_id
      WHERE w.owner_id = auth.uid()
    )
  );


-- =============================================================================
-- 5. PAYMENTS
--    Customer-level receipts (not per-invoice). Amount is always positive;
--    sign is resolved by ledger event_type = 'payment_receipt' (stored negative).
--    idempotency_key: set by Flutter to prevent duplicate inserts on retry.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.payments (
  id               text        PRIMARY KEY,
  workspace_id     text        NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  customer_id      text        NOT NULL REFERENCES public.customers(id)  ON DELETE RESTRICT,
  amount_minor     bigint      NOT NULL CHECK (amount_minor > 0),
  notes            text,
  payment_date     timestamptz NOT NULL DEFAULT now(),
  idempotency_key  text        NOT NULL UNIQUE,            -- Flutter-generated, collision guard
  version          bigint      NOT NULL DEFAULT 0,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  deleted_at       timestamptz
);

CREATE INDEX IF NOT EXISTS payments_workspace_idx  ON public.payments(workspace_id);
CREATE INDEX IF NOT EXISTS payments_customer_idx   ON public.payments(customer_id);
CREATE INDEX IF NOT EXISTS payments_idem_idx       ON public.payments(idempotency_key);

-- RLS
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY payments_workspace_access ON public.payments
  FOR ALL TO authenticated
  USING (
    workspace_id IN (SELECT id FROM public.workspaces WHERE owner_id = auth.uid())
  )
  WITH CHECK (
    workspace_id IN (SELECT id FROM public.workspaces WHERE owner_id = auth.uid())
  );


-- =============================================================================
-- 6. LEDGER ENTRIES
--    Immutable double-entry ledger. Written atomically with invoice/payment.
--    event_type:
--      'invoice_charge'  — positive debit  (customer owes more)
--      'payment_receipt' — negative credit (customer owes less)
--      'discount'        — negative credit (manual discount)
--      'adjustment'      — positive/negative correction
--      'reversal'        — reverses a prior entry
--    source_id: FK back to the triggering invoice or payment row.
--    UNIQUE(workspace_id, source_id, event_type) prevents double-posting.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.ledger_entries (
  id            text        PRIMARY KEY,
  workspace_id  text        NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  customer_id   text        NOT NULL REFERENCES public.customers(id)  ON DELETE RESTRICT,
  source_id     text        NOT NULL,  -- invoice.id or payment.id
  event_type    text        NOT NULL
                            CHECK (event_type IN (
                              'invoice_charge', 'payment_receipt',
                              'discount', 'adjustment', 'reversal'
                            )),
  amount_minor  bigint      NOT NULL,  -- negative = credit, positive = debit
  notes         text,
  occurred_at   timestamptz NOT NULL DEFAULT now(),
  created_at    timestamptz NOT NULL DEFAULT now(),

  -- Prevents double-posting the same source event
  CONSTRAINT ledger_source_unique UNIQUE (workspace_id, source_id, event_type)
);

CREATE INDEX IF NOT EXISTS ledger_workspace_idx ON public.ledger_entries(workspace_id);
CREATE INDEX IF NOT EXISTS ledger_customer_idx  ON public.ledger_entries(customer_id);
CREATE INDEX IF NOT EXISTS ledger_date_idx      ON public.ledger_entries(customer_id, occurred_at DESC);

-- RLS
ALTER TABLE public.ledger_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY ledger_workspace_access ON public.ledger_entries
  FOR ALL TO authenticated
  USING (
    workspace_id IN (SELECT id FROM public.workspaces WHERE owner_id = auth.uid())
  )
  WITH CHECK (
    workspace_id IN (SELECT id FROM public.workspaces WHERE owner_id = auth.uid())
  );


-- =============================================================================
-- 7. CUSTOMER BALANCE VIEW
--    Derived from ledger_entries. No stored aggregates — always consistent.
--    outstanding > 0  → customer owes money (debit)
--    outstanding < 0  → customer has credit (overpaid)
--    outstanding = 0  → fully settled
-- =============================================================================

CREATE OR REPLACE VIEW public.customer_balances
  WITH (security_invoker = true)
AS
SELECT
  le.customer_id,
  le.workspace_id,
  COALESCE(SUM(CASE WHEN le.event_type = 'invoice_charge'
                    THEN le.amount_minor ELSE 0 END), 0)          AS total_invoiced_minor,
  COALESCE(SUM(CASE WHEN le.event_type = 'discount'
                    THEN ABS(le.amount_minor) ELSE 0 END), 0)     AS total_discounts_minor,
  COALESCE(SUM(CASE WHEN le.event_type = 'payment_receipt'
                    THEN ABS(le.amount_minor) ELSE 0 END), 0)     AS total_payments_minor,
  COALESCE(SUM(CASE WHEN le.event_type IN ('adjustment', 'reversal')
                    THEN le.amount_minor ELSE 0 END), 0)          AS total_adjustments_minor,
  -- Final balance: positive = owes, negative = credit
  COALESCE(SUM(le.amount_minor), 0)                               AS outstanding_minor
FROM public.ledger_entries le
GROUP BY le.customer_id, le.workspace_id;


-- =============================================================================
-- 8. SYNC OUTBOX  (server-side mirror of Flutter local outbox)
--    Used if Flutter ever pushes individual operation envelopes rather than
--    a full JSONB document. Compatible with elnota_sync() RPC revision model.
--    status: 'pending' | 'sending' | 'acknowledged' | 'needs_attention'
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.sync_outbox (
  operation_id   text        PRIMARY KEY,
  workspace_id   text        NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  entity_type    text        NOT NULL CHECK (entity_type IN ('customer','invoice','payment')),
  entity_id      text        NOT NULL,
  operation_type text        NOT NULL CHECK (operation_type IN ('create','update','delete')),
  payload_json   jsonb       NOT NULL,
  base_version   bigint      NOT NULL DEFAULT 0,
  created_at     timestamptz NOT NULL DEFAULT now(),
  attempts       integer     NOT NULL DEFAULT 0,
  next_retry_at  timestamptz,
  status         text        NOT NULL DEFAULT 'pending'
                             CHECK (status IN ('pending','sending','acknowledged','needs_attention')),
  last_error     text
);

CREATE INDEX IF NOT EXISTS outbox_workspace_pending_idx
  ON public.sync_outbox(workspace_id, status, created_at ASC)
  WHERE status IN ('pending', 'sending');

-- RLS
ALTER TABLE public.sync_outbox ENABLE ROW LEVEL SECURITY;

CREATE POLICY outbox_workspace_access ON public.sync_outbox
  FOR ALL TO authenticated
  USING (
    workspace_id IN (SELECT id FROM public.workspaces WHERE owner_id = auth.uid())
  )
  WITH CHECK (
    workspace_id IN (SELECT id FROM public.workspaces WHERE owner_id = auth.uid())
  );


-- =============================================================================
-- 9. SYNC STATE  (per-workspace cursor / last-success tracking)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.sync_state (
  workspace_id    text        PRIMARY KEY REFERENCES public.workspaces(id) ON DELETE CASCADE,
  last_cursor     text,
  last_success_at timestamptz,
  pending_count   integer     NOT NULL DEFAULT 0,
  last_error      text,
  updated_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.sync_state ENABLE ROW LEVEL SECURITY;

CREATE POLICY sync_state_workspace_access ON public.sync_state
  FOR ALL TO authenticated
  USING (
    workspace_id IN (SELECT id FROM public.workspaces WHERE owner_id = auth.uid())
  )
  WITH CHECK (
    workspace_id IN (SELECT id FROM public.workspaces WHERE owner_id = auth.uid())
  );


-- =============================================================================
-- 10. AUTO-REGISTER WORKSPACE RPC
--     Called once after elnota_register() to create the merchant's workspace.
--     Flutter passes business name; server ties it to auth.uid().
-- =============================================================================

CREATE OR REPLACE FUNCTION public.elnota_create_workspace(business_name text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_workspace_id text;
  v_user_id      uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Use user_id as workspace_id (1:1 for MVP, can be extended to multi-workspace)
  v_workspace_id := v_user_id::text;

  INSERT INTO public.workspaces (id, owner_id, name, currency_code, created_at, updated_at)
  VALUES (v_workspace_id, v_user_id, business_name, 'EGP', now(), now())
  ON CONFLICT (id) DO NOTHING;

  RETURN v_workspace_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.elnota_create_workspace(text) TO authenticated;


-- =============================================================================
-- 11. GRANTS (Supabase anon/authenticated roles)
-- =============================================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON public.workspaces         TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.customers           TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.invoices            TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.invoice_items       TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.payments            TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ledger_entries      TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON public.sync_outbox         TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON public.sync_state          TO authenticated;
GRANT SELECT                         ON public.customer_balances   TO authenticated;

-- =============================================================================
-- END OF MIGRATION
-- =============================================================================

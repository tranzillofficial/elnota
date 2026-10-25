# ElNota — UI/UX Design System

## Product direction
A calm, premium, fast accounting tool for small shops and independent businesses. Arabic-first with reliable RTL, optional English and desktop-quality information density. Minimal, practical design: compact controls, little wasted space, clear totals, and efficient repeat workflows.

## Principles
1. **Clarity over decoration:** users should recognize debt, payments, balances, due dates, and pending sync instantly.
2. **Compact but readable:** avoid oversized dashboard cards, excessive blank space, and noisy gradients.
3. **One primary action per view:** e.g., “إضافة عميل”, “فاتورة جديدة”, “تسجيل دفعة”. Secondary actions live in a contextual menu.
4. **Financial correctness in UI:** always show currency, signs, status, and whether totals include discounts or credits.
5. **Trustworthy offline behavior:** visibly differentiate saved locally, waiting for sync, synced and failed.
6. **Responsive by intent:** mobile is stacked and touch-friendly; desktop shows denser tables, search and keyboard shortcuts.

## Visual tokens (starting points; tune with real-device review)
- `canvas.light`: `#F7F6F2` (warm cream)
- `surface.light`: `#FFFFFF`
- `text.primary.light`: `#1F2528`
- `text.secondary.light`: `#687078`
- `accent`: `#246B5A` (restrained green)
- `danger`: `#C44B46`
- `warning`: `#B7791F`
- `border.light`: `#E7E7E1`
- `canvas.dark`: `#121619`
- `surface.dark`: `#1C2226`
- `text.primary.dark`: `#F3F5F4`
- `border.dark`: `#30383C`
- Spacing: 4px grid (4 / 8 / 12 / 16 / 24); default content padding 16 mobile, 20–24 desktop.
- Radii: 8–12px standard, 14px only for major surfaces; avoid pill-shaped everything.
- Typography: Arabic typeface with clear numerals (e.g., Cairo or IBM Plex Sans Arabic); hierarchy approximately 12 / 14 / 16 / 20 / 24sp. Respect platform text scaling.
- Icons: one consistent outline family, 18–20px normal.
- Contrast: aim for WCAG AA; never indicate financial status using color alone.

## Responsive layout
- `<600px`: single-column mobile; contextual actions; bottom nav only for primary destinations.
- `600–1023px`: tablet layout, adaptable side navigation.
- `>=1024px`: persistent sidebar, compact header, content max-width where sensible, data tables with sorting/filtering.
- Do not force desktop-only grids onto narrow screens. Use appropriate Flutter breakpoints rather than device-type checks alone.

## Screens
### Overview
Show only meaningful KPIs: customer count, total receivables, total collected, outstanding installments, upcoming dues. Compact summary cards and recent activity; avoid decorative cards without action.

### Customers
Search is prominent. Mobile customer tile: name, total due/credit, last activity and one overflow action. Desktop table: customer, phone, outstanding, last transaction, status and overflow menu. Customer details show invoice history and total customer balance; **one customer-level “تسجيل دفعة” action**, not repeated payment actions per invoice.

### Invoices
Quick-create flow supports either itemized products or manual amount, with customer, amount, date, due date and optional note. Show discounts clearly and maintain audit trail for edits.

### Payments
Prominent amount field, customer summary, optional note, confirmation summary and receipt. Always indicate whether a payment is saved locally, synced or conflicted. Prevent duplicate submit UI while retaining server-side idempotency.

### Installments
Show schedule, paid/remaining, overdue status and next due date. Make partial payments and reconciliation clear.

### Settings
Group by Account, Business, Backup & Sync, Printing, Appearance, Security, and About. Display last successful sync, pending operations and manual sync. Avoid huge tiles and irrelevant toggles.

## Component patterns
- Buttons: filled primary, quiet secondary, subtle destructive confirmation.
- Forms: inline validation, numeric keyboard on mobile, tab/focus traversal desktop, clear required indicators.
- Data: formatted currency and aligned numbers; amounts use tabular figures where possible.
- Feedback: concise snackbar for success; actionable error message and retry for failure.
- Dialogs: only for destructive/irreversible operations or crucial financial confirmation.
- Empty state: one sentence and one useful action, not large art.
- Navigation: preserve search/filter on returning; use GetX routes with well-scoped bindings.

## States to design and test
Loading, empty, offline, syncing, synced, conflict, permission denied, stale session, validation error, and no data. Test long Arabic names, large balances, dynamic text size, RTL/LTR mixed phone numbers, and keyboard-only navigation.

## Implementation guardrails
- Centralize `ThemeData`, color tokens, typography and reusable primitives under `app/theme` and `core/widgets`.
- Use `LayoutBuilder`/responsive widgets, not duplicated full screens for every size.
- Use `Obx()` only around reactive subtrees; avoid rebuilding full screens when a single number changes.
- Keep destructive actions away from frequent primary actions.
- Avoid user-visible AI branding or generic dashboard illustrations unless explicitly required.

## Approved reference screens (October 2026)
The supplied dashboard, customers table, and customer account images define the
current light desktop appearance: white canvas, green `#00845B` navigation rail,
navy `#101326` text, secondary `#59698D`, and borders `#E4E9F2`.
The desktop rail is 72px wide on the leading RTL edge. Content uses bordered
panels, compact tables, green receipt charts, and responsive summary cards.
On narrow screens, panels stack and wide tables scroll horizontally.

Customer balances come from existing ledger projections. Invoice terms and
FIFO installment schedules are now implemented locally; see BUSINESS_RULES.md.
Statements use the immutable ledger and preserve negative customer credits.
Cloud ledger integration remains disabled to protect the existing production
JSON document contract.

## New reference screens
Invoice management includes its own installment schedule tab; there is no
separate installment destination in the sidebar. Invoice and payment creation
use centered responsive modals over the current screen. Statements have period
controls, opening/debit/credit/closing cards and a running-balance ledger table.
Settings use paired desktop panels and stacked mobile panels.

The bundled Cairo font is loaded locally without changing package manifests.
Settings persist business/printing preferences; printer selection, paper width,
logo and business details are used for invoice PDFs. Unimplemented app lock,
notifications, backup restore and scheduled device backups are visibly inactive;
no switch falsely claims those services are running.

Products use the same green sidebar, compact bordered panels and responsive
cards. Search matches literal barcode, product name or category name; category
chips further filter results. Category administration supports add/rename/archive.
Product forms and customer creation/editing use the shared centered form frame.
Image selection compresses JPG/PNG/WebP to WebP (960px maximum, 512KiB maximum).
Non-entitled accounts see a locked catalog with refresh-access action.
Desktop GetX toasts and Material snackbars have maximum/target width 440px.

The compact rail uses 23px icons and 44px navigation targets, scrolls on short screens, and keeps the account menu visible. Products precede settings without changing route indices. Admin has separate accounts, activation, releases and platform-settings sections.


## Approved mobile references (24 October 2026)
Phone widths below 600px use the supplied Arabic mobile layouts: a compact logo/header, three bottom destinations (invoices, create invoice, More), bordered record cards, three summary cards, search/filter controls and incremental loading. Home uses a receivables hero, three metrics, quick actions, dues and recent activity. More groups existing destinations in three-column grids and shows the actual account/backup state.

Invoice creation is fullscreen on phones, with a fixed save/print footer, item/amount selector and inline quantity, unit-price, line-total and delete controls. The existing controller and ledger calculations remain authoritative. Other account tables become labeled mobile records; desktop tables and rails remain in use. Brand illustrations in the More reference are represented by bundled Material icons; no additional image dependency was introduced.

Validation: 83 tests passed, one environment-specific demo test skipped; analyzer clean. RTL screen coverage includes 320px, 390px and 1586px. Interactive invoice tests cover add, quantity increment, delete and amount-only selection. Browser review used isolated local demo data at 320px/390px. Physical Android installation remains unverified. No schema, cloud-sync behavior or dependency-manifest changes.

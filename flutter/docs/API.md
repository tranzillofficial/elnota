# ElNota | API & Integration Contracts

> Reference design, not implemented endpoints. Do not assume these exist until verified in the Supabase project.

## Client/server contract
- Flutter application uses Supabase Auth for sessions.
- Drift is queried by the UI, not direct REST calls on every screen.
- For critical writes, use protected PostgreSQL RPC or Edge Functions with server-side validation, RLS and transaction boundaries.
- `service_role` access is server-only and narrowly scoped.

## Suggested protected operations
| Operation (conceptual) | Inputs | Response |
|---|---|---|
| `sync_push` | workspace + batched immutable operations | per-op outcome, version, errors |
| `sync_pull` | workspace + server cursor + page size | ordered change page, tombstones, next cursor |
| `apply_payment` | customer, exact amount, operation ID | payment/ledger IDs, accepted status |
| `void_invoice` | invoice ID, reason, expected version | void/reversal event IDs |
| `account_activation` | verified payment/provider event | entitlement and expiry |

Actual route/function names, authentication method and request schemas must be defined before implementation.

## Sync error envelope
```json
{
  "operation_id":"uuid",
  "status":"conflict",
  "code":"VERSION_MISMATCH",
  "message":"The record was modified elsewhere",
  "server_version":3
}
```
Errors should have documented stable codes such as `UNAUTHENTICATED`, `FORBIDDEN`, `VERSION_MISMATCH`, `VALIDATION_ERROR`, `CURSOR_EXPIRED`, `TRANSIENT_FAILURE`. No stack traces exposed to end users.

## Versioning
- Embed `schema_version` and `client_version` in sync requests.
- Introduce additive server fields; support existing clients during migration.
- Date/time uses ISO 8601 UTC over wire; financial amounts use minor units or exact decimal strings, never JSON floating-point currency values.

## Payment gateway integration
- Creating a checkout/payment link happens from a protected backend, not a Flutter embedded secret.
- Validate signed webhooks and/or independently query gateway for final state.
- Deduplicate provider event IDs; grant entitlement only after confirmed successful payment.
- External iOS activation/purchase behavior must be reviewed against current Apple App Review rules before release.

## API operational requirements
- Rate limits, input validation, retries, structured redacted logs and correlation IDs.
- Limit page size; don't return whole workspace datasets in one unbounded response.
- Authorization tests for cross-tenant and revoked users.
- Stage and production environment separation with separate secrets/credentials.

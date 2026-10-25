# ElNota | Test Strategy

## Test layers
| Layer | Target | Examples |
|---|---|---|
| Unit | financial rules and validations | balance, discounts, advances, installment schedule |
| Repository + Drift | local data invariants | transactions, indexes, duplicate operation IDs, migration |
| Sync integration | server contract | replay, conflict, token expiry, cursor paging |
| Widget | screens in RTL and LTR | GetX state, loading/empty/error, customer payment placement |
| End-to-end | device flows | offline invoice, reconnect, print, restore, login/logout |

## Commands
```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test  # requires a compatible configured target
```
Use local test DB and a dedicated test Supabase project; never run destructive tests against production.

## Mandatory money tests
- Two invoices: 500 and 300; a single customer payment of 250 and discount 50 => outstanding 500.
- Payment greater than debt displays approved customer credit behavior.
- Duplicate button taps and repeated sync retries => one payment only.
- Decimal boundary: 0.01 EGP repeated, large amounts, exact arithmetic, no precision loss.
- Reversal restores expected balances and creates a traceable event.
- Installment schedules don't add the same debt twice.

## Offline and concurrency tests
1. Create customer, invoice and payment with airplane mode; force-close; restart; check local persistence.
2. Reconnect; simulate timeout *after server commit*; ensure replay is idempotent.
3. Modify customer profile on two devices and verify explicit conflict flow.
4. Submit two different payments offline from two devices; both must survive reconciliation.
5. Server revokes membership; pending unauthorized events show `needs_attention` and do not leak data.
6. Simulate cursor expiration, partial page, out-of-order network responses and retry backoff.
7. Upgrade application with unsent outbox and pre-existing ledger; preserve counts/balances.

## Platform acceptance
- Android: install signed release APK, upgrade in place, print/share PDFs, camera permissions if enabled.
- iOS: valid signing/build, app resume/persistence, background limitations, file/share workflows.
- Windows: installer, window resizing, file import/export, print workflow, power interruption/restart.
- macOS/Linux: only claim support after testing plugin and packaging parity.

## UI quality gates
- Arabic RTL and long names; compact visual density and accessible tap targets.
- Mobile narrow portrait and desktop wide layouts; no clipped dialogs or tables.
- Network state visible without blocking offline actions; pending sync labels are truthful.

## Release gate
- [ ] Format/analyzer/test suites pass.
- [ ] Offline/restart/reconnect/duplicate scenarios pass.
- [ ] RLS negative tests pass.
- [ ] Restore from a backup successfully verified.
- [ ] Migration from previous version verified.
- [ ] Version number and signed artifacts archived; release notes drafted.

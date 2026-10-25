# ElNota Agent Instructions

## Stack
Flutter, GetX, Drift, Supabase.

## Documentation
- Architecture: docs/ARCHITECTURE.md
- UI/UX: docs/DESIGN.md
- Database: docs/DATABASE.md
- Offline Sync: docs/SYNC.md
- Financial Logic: docs/BUSINESS_RULES.md
- Security: docs/SECURITY.md
- Testing: docs/TESTING.md

## Rules
- Read relevant documentation before modifying code.
- Never modify financial calculations without
  reviewing BUSINESS_RULES.md.
- Never change database schemas without reviewing
  DATABASE.md and existing migrations.
- Never change sync behavior without reviewing SYNC.md.
- Never delete production data without explicit approval.
- Follow DESIGN.md for UI changes.
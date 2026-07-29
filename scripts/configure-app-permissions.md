# Per-App Operator Permissions

Wiki.js and Snipe-IT store permissions in their own databases rather than files, so there's nothing to version-control directly — this documents the setup for reproducibility.

## Wiki.js

1. **Admin → Groups → New Group**, name it exactly `operators` (lowercase — Authentik's group is also lowercase, and group-name mapping is case-sensitive)
2. In its Page Rules: grant Read, Write, Comment on `/` and below. Do **not** grant "Manage" (that's admin-level)
3. **Admin → Login → your OIDC/Login strategy → Map Groups**: toggle on. This auto-assigns anyone whose identity provider `groups` claim includes `operators` into this Wiki.js group on login
4. Also enable **selfRegistration** on the strategy, or new SSO identities can't get a Wiki.js account created automatically on first login

## Snipe-IT

New users created via **Admin → Users → New User** default to a permission template that may have every permission unchecked (effectively a useless account that can't even view assets). The Operator-appropriate permission set used in this build:

- **Granted**: view/create/edit/checkin/checkout on assets, accessories, consumables, licenses, components; view-only on categories, departments, status labels, suppliers, manufacturers, locations, companies, models; reports.view
- **Denied**: delete on anything; all of users.*, customfields.*, depreciations.*; admin/superuser flags

This was applied directly via a SQL `UPDATE users SET permissions = '<json>' WHERE username IN (...)` rather than the UI, since Snipe-IT's permission JSON has ~90 individual keys and the UI has no bulk-apply. If recreating from scratch, either build the permission JSON by hand (see Snipe-IT's own docs for the full key list) or use their user-import/API to script it — don't rely on whatever the "New User" form defaults to without checking.

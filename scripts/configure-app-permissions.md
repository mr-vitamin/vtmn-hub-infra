# Per-application Operator permissions

**Intended process, reviewed October 22, 2026; server unavailable.** No accounts, grants or database state were inspected or changed. Exact installed labels/keys and current effective memberships remain unknown.

The authoritative intended model is NPM/Authentik forward-auth followed by local Wiki.js and Snipe-IT users. Proxy admission and application permissions are separate. Historical Wiki.js OIDC/self-registration/group-mapping instructions are not prerequisites of this model; reconcile conflicting strategies before any approved change. See [application operations](../docs/APPLICATION-OPERATIONS.md).

## Wiki.js — owner-managed local users

Using the installed release's supported administration UI, inventory existing local/provider identities, groups and guest access first. Preserve owner recovery and content; do not convert or duplicate an existing OIDC account automatically.

For a new approved Operator, create a local identity and assign the intended operators application group. Grant both the necessary global content permissions and page rules for the approved scope; page rules alone do not grant globally disabled capabilities. Intended actions are read, write and comment, with asset access only where needed and reviewed. Do not grant administrative/manage/users/groups/settings capabilities or broad deletion rights.

The historical scope was the whole wiki; confirm that choice before recreating it. Check the installed rule semantics for the site root, descendants, assets and language paths instead of assuming a literal slash matches everything. Inventory Guest permissions and overlapping group memberships. Matching an Authentik group name does not synchronize membership or enforce authorization.

Use [Wiki.js users/groups guidance](https://docs.requarks.io/groups) for the matching version. Test one allowed page edit/comment and one denied out-of-scope/admin/delete action with an actual test account before calling the role verified. Do not enable self-registration or OIDC mapping to bypass a failed local-account setup.

## Snipe-IT — capability template, not invented permission JSON

Historical intent below is a capability checklist, not an export of installed permissions or a complete API payload. Map it to the selected version's supported UI/API only after reviewing actual keys and relationships.

| Resource | Intended Operator capabilities |
|---|---|
| Assets, accessories, consumables, licenses, components | View/create/edit and relevant check-in/check-out actions where the resource supports them. |
| Categories, departments, status labels, suppliers, manufacturers, locations, companies, models | View only. |
| Reports | View only, after reviewing data scope. |
| All resources | No delete. |
| Users, custom fields, depreciation management, app administration | No management access; no Admin or Superadmin flag. |

Prefer supported permission groups and assign local users to a reviewed Operator group. Inspect individual overrides, all other memberships, company scope and admin flags; a restrictive group does not undo an independent privileged grant. Keep the original SNIPEIT_APP_KEY with the database.

[Vendor user guidance](https://snipe-it.readme.io/docs/managing-users) recommends permission groups. Historical direct SQL is reference history only; no SQL UPDATE, handwritten guessed JSON or assumed “90 keys” is a reproducible procedure. Version-specific exported payloads must be sanitized and reviewed before a future automation change. Exact numeric/boolean keys are deliberately not invented here.

## Positive/negative verification and offboarding

Pending tests: Wiki content read/edit/comment within approved scope; denied delete/admin/user/group changes. Snipe supported inventory operations and reference-data view; denied deletes, reference modification, user management and admin access. Test reports/company scope and UI/API behavior where relevant, not just a hidden menu.

Offboarding requires disabling/revoking the IdP admission **and** both local app identities/sessions/API tokens as supported, plus Nextcloud sessions/shares/tokens when granted. Do not assume disabling Authentik invalidates existing app-local sessions. Reconcile asset ownership/shares and retention with the owner; do not automatically delete users or their content. Confirm denial from fresh and existing-session paths while preserving owner recovery.

These are intended permissions and acceptance steps, not verified enforcement. No group/policy/key or data change is implemented.

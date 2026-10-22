# Operator onboarding and offboarding template

**Unfilled planning template — October 22, 2026.** Keep completed user identities, reset links, tokens and recovery details outside this public repository. Nothing below asserts that MFA, provisioning or permission checks have been completed.

## Approval and account record

| Field | Private record to complete after approval/verification |
|---|---|
| Person / owner approval / scope | Approved services and application role; do not grant every service by default. |
| Authentik identity | Actual username/group, applied admission policy and verified MFA enrollment; group-name presence alone is not enforcement. |
| Wiki.js | Separate local identity/group/page scope under the intended forward-auth model; no automatic OIDC mapping assumed. |
| Snipe-IT | Separate local identity with reviewed Operator permission group and no privileged/individual override. |
| Nextcloud | Existing linked identity or verified user_oidc provisioning decision. Automatic first-login creation is not assumed; confirm allowed/denied behavior. |
| Homepage | No separate individual account in this design; verify intended proxy gate and direct-backend restriction. |
| Created/reviewed by | Actual owner names and dates, kept privately. |
| Acceptance | Record actual allowed/denied and existing-session results for each granted service. |
| Recovery | Secure delivery channel and location of owner recovery instructions; never paste recovery secrets here. |

Use the [application operations guide](APPLICATION-OPERATIONS.md) and [permission capability checklist](../scripts/configure-app-permissions.md) for setup boundaries.

## Secure delivery and acceptance

- [ ] Owner approval and requested scope recorded.
- [ ] Existing identities reviewed to prevent duplicate/linking mistakes.
- [ ] IdP enrollment/reset material delivered through an approved secure channel.
- [ ] Separate Wiki.js/Snipe-IT enrollment/reset material delivered only if those apps are granted.
- [ ] MFA policy/enrollment actually verified, not merely marked required.
- [ ] Each granted service passes its intended positive and negative permission checks.
- [ ] Nextcloud provisioning/linking, cron-independent access and ownership/shares checked where applicable.
- [ ] Offboarding responsibility, session/token coverage and recovery recorded.

## Offboarding

- [ ] Owner approves timing and preservation/transfer of required records/assets/shares.
- [ ] Revoke IdP admission and relevant sessions through supported mechanisms.
- [ ] Disable app-local Wiki.js/Snipe-IT access and relevant sessions/API tokens separately.
- [ ] Review Nextcloud account, sessions/app passwords/tokens/shares and device access.
- [ ] Verify denial from fresh and previously established paths; preserve owner recovery.
- [ ] Record evidence privately; do not delete user data automatically.

# Historical Authentik source — do not apply as a set

These six files are retained unchanged from master revision 14eb27fafb4c43d49595a065daf91ce68d8c13cd. They are outside the Compose discovery mount. No statement here establishes what was applied on the unavailable server.

| File | Historical role / conflict |
|---|---|
| forward-auth-setup.yaml | Docs and Snipe-IT providers; assigns only two embedded-outpost providers. |
| homepage-forward-auth.yaml | Adds Hub and assigns three outpost providers; conflicts with reapplying the earlier two-provider list. |
| wikijs-oidc.yaml | Alternative Docs OIDC application assignment; conflicts with forward-auth. Contains a literal secret placeholder, not safe injection. |
| revert-docs-forward-auth.yaml | Reassigns Docs back to proxy provider; a transition artifact rather than a second desired state. |
| nextcloud-sso.yaml | Provider-side OIDC reference with a literal secret placeholder; application-side configuration is not complete. |
| hub-branding.yaml | Branding-only reference. |

Do not copy these into blueprints/local or import them blindly. Keep any historical credentials private; these tracked files contain only placeholders.

See the [identity handoff](../README.md) for the authoritative proposed architecture and review-only consolidated examples. Moving files does not reverse already-created database objects or establish that stored blueprint instances are disabled.

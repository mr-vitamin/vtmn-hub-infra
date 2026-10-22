# GitHub governance recommendations

Work Package 12 / GOV-001. Prepared 2026-10-22. Recommendations only; no GitHub settings, workflow, repository content or pull request was changed.

## Evidence and risk

The read-only repository snapshot identifies a public, personally owned repository, default branch master at 14eb27fafb4c43d49595a065daf91ce68d8c13cd. Branch metadata reports protected:false; the rulesets query returns an empty list. The complete master tree has no .github/workflows files. The Actions workflow-list endpoint was unsupported by the connector; external checks and historical workflow runs were not inventoried. The owner's subscription was not inspected.

Draft PR #1 remains separate and unmerged, with head 761c73b4afd6c4d2c6f4ecd7e13f34feb8d85267. Its README-only changes must not be treated as master or replaced by earlier packages' master-based README candidates. This package does not approve or reassess merging that PR.

GOV-001 is informational: safeguards would reduce accidental history replacement and improve change review. Their absence does not grant public write access or establish a serious infrastructure vulnerability. These controls also cannot protect against an owner account able to change the controls themselves.

## Minimal proposed configuration

After separate authorization, prefer one branch ruleset targeting exactly master. Reconfirm the default branch before applying it. Record the previous settings and selected bypass behavior first.

| Setting | Initial recommendation | Reason |
|---|---|---|
| Enforcement | Active only when authorized and reviewed | Disabled rules do not enforce protection |
| Restrict deletions | Enabled | Preserve the protected branch as a policy; GitHub also has default-branch deletion safeguards |
| Block force pushes | Enabled | Reduce accidental history replacement |
| Require a pull request | Enabled, zero required approvals | Keep a reviewable change record without requiring an unavailable second maintainer |
| Required status checks | None initially | No real stable check names have been established |
| Restrict updates / creations | Leave disabled | Restrict updates would allow only bypass actors to update matching branches |
| Code owner/latest-push approvals, merge queue, deployments, mandatory signing or linear history | Do not require initially | Added complexity has not been justified for this project |

GitHub supports requiring a PR without requiring approval. Do not rely on approving your own PR to satisfy an independent review requirement. The selected controls and update restriction semantics are described in [available rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets).

Avoid routine broad bypass access. Inspect the actual personal-repository options before choosing any emergency bypass; do not assume organization teams or arbitrary user bypass lists exist. Prefer normal PR use, with the owner retaining administrative recovery of settings. If emergency changes are necessary, record the reason, exact temporary change and restoration of protection; do not demonstrate recovery by force pushing or deleting master.

A legacy branch protection rule is an alternative, not a second required layer. If selected, explicitly inspect administrator enforcement: legacy rules normally allow administrator bypass. Multiple rulesets and legacy protection can interact; review effective rules instead of adding overlapping policies blindly. See [protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches).

## Plan availability

Public-repository branch rulesets are available on GitHub Free; private-repository availability differs by plan. This public project does not need a paid upgrade merely for the proposed branch ruleset. Subscription-specific entitlements, future visibility changes, push rulesets and advanced scanning features need separate checks. Do not assume an evaluation enforcement mode or organization-wide required workflows is available. See [ruleset availability and enforcement](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets).

## Optional future checks

Start with documented local checks or an independently reviewed, nonblocking workflow proposal. None is installed or enabled by this package. Previous work-package checkers are independent local proposals, not files already merged into master.

| Candidate check | Useful boundary |
|---|---|
| Markdown links and source consistency | Check relative paths against the proposed combined tree; retain PR #1 diagram and status distinctions |
| Bash parsing; optional ShellCheck | Parsing is not execution; acquiring any missing tool needs separate authorization |
| Compose validation | Use dummy per-stack inputs and config-only parsing; never start services, pull images or resolve real credentials |
| Required-input regression checks from WP11 | Reconcile that proposal first; missing/empty rejection does not prove credential strength |
| CA and Proxmox safety regressions | Use reviewed mocks/stubs; never run real key generation, pct, pvesh, backup or host-modification commands |
| IAM source checks | Compose/YAML parsing is not Authentik schema validation or proof of deployed policies; preserve custom YAML tags |

Before making any check required, establish a stable unique emitted job name, a successful run and a harmless intentional failure proving the check blocks correctly. Record actual base/head revisions. Recheck after changes. Choose the actual check and trusted reporting application where supported; do not invent a required name. Handle documentation-only PRs consistently so path filtering cannot leave a required check permanently pending.

A future public-PR workflow should use an isolated GitHub-hosted runner, minimal read-only token permissions, no infrastructure credentials, and no access to the owner's workstation or Proxmox server. Prefer an unprivileged pull_request event. Do not execute untrusted PR checkout with pull_request_target privileges. Pin third-party actions to verified full commit hashes, constrain runtime and concurrency, and prevent sensitive output. Any tool acquisition must be separately reviewed. No automatic deployment, merge or API write is needed. These are design recommendations, not evidence of an existing workflow; see [secure GitHub Actions use](https://docs.github.com/en/actions/reference/security/secure-use).

## Solo-maintainer workflow and acceptance

Use a feature branch, inspect its PR diff and relevant offline checks, then make a deliberate merge decision. The requirement for a PR is useful even without a second reviewer. Publication of any package remains separately authorized.

For future implementation, capture settings before and after, confirm exact branch targeting and effective rules with read-only metadata/UI, and test in a disposable repository or ref with equivalent rules. Never test deletion or force pushes on master. Confirm the owner can complete a normal PR without needing their own approval. Confirm checks fail and recover on harmless fixtures before requiring them.

Recover source mistakes through a reviewed revert PR rather than rewriting master history. Recover configuration mistakes through the smallest documented settings correction and restoration. Keep an audit record of emergency bypass use.

| Acceptance item | Current result |
|---|---|
| Recommendations and source references reviewed | Local documentation only |
| Ruleset/protection configured | Not performed |
| Workflow or required check configured | Not performed |
| Enforcement/bypass/merge behavior tested | Not performed |
| Server/network/application verification | Not performed; server remains unavailable |

GOV-001 remains unimplemented. This document is an approval-ready recommendation, not a claim of enforcement.

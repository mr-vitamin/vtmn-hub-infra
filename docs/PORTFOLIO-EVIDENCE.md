# Portfolio evidence strategy

Work Package 13. Prepared October 22, 2026. This is a collection and publication plan, not proof that its future tests passed.

## Scope and evidence boundary

VTMN Hub is a self-hosted infrastructure learning project. Present practical configuration, troubleshooting and security decisions without implying professional production experience, high availability, comprehensive hardening or independently proven recovery.

The reference audit reviewed master at 14eb27fafb4c43d49595a065daf91ce68d8c13cd and the separate README proposal in draft PR #1 at 761c73b4afd6c4d2c6f4ecd7e13f34feb8d85267. These are dated snapshots, not a new query of current GitHub state. PR #1 was unmerged at the last recorded review. Verify both revisions before eventual publication.

The thirteen earlier remediation packages were local proposals or plans; Work Package 14 integrates their supported source changes into a local candidate, with Homepage socket removal deferred. They are not merged source, applied configuration or completed live remediation. The physical server is unavailable. Do not create simulated operational screenshots, synthetic logs presented as real, fictional benchmarks, or successful test claims.

## Evidence labels

Use the label in each artifact caption and the surrounding portfolio claim.

| Label | What supports it | What it does not establish |
|---|---|---|
| Source configuration | Exact file path and immutable revision | Deployment, effective permissions or availability |
| Historical operational report | Dated original note and its stated result | New independent verification or current operation |
| Local proposal | Named work package and candidate file or patch | Presence in master, publication or deployment |
| Offline validation | Actual saved check record, candidate revision/hash and limitations | Behavior of the powered-off environment |
| Planned | Explicit future objective, prerequisites and acceptance criteria | Implementation or success |
| Live verification pending | Runtime question and collection procedure | A positive or negative runtime result |
| Verified at a stated time | Actual retained output, environment/version, procedure and observed result | Continuous correctness or unrelated test cases |

Never upgrade a historical statement to verified merely by quoting it. When evidence is missing, record missing evidence rather than recreating a result from memory.

## Initial evidence register

This register describes available source material and proposed collection. It is not a completed runtime evidence catalog. Repository paths refer to the audited baseline unless identified as local proposals. External work-package folders are not repository paths.

| ID / skill | Available basis | Suitable portfolio artifact | Current boundary / future acceptance |
|---|---|---|---|
| E01 / virtualization and Linux | proxmox/create-containers.sh; docs/INFRASTRUCTURE.md | Annotated excerpt explaining eight unprivileged LXC definitions, resource choices and service grouping | Source only; guest creation and effective isolation need later runtime evidence |
| E02 / container administration | services/ Compose files | One stack's dependency, persistence and input explanation | Six stacks contain 13 service definitions in the audited source; no installed-image or health claim |
| E03 / networking and architecture | scripts/setup-dns.sh; services/npm/; WP7 plan | Sanitized logical topology with trust boundaries and separate proposed restrictions | DNS/proxy declarations do not prove effective addresses, HTTPS or direct-port isolation |
| E04 / identity and authorization | services/authentik/; scripts/configure-app-permissions.md; WP3/WP11 proposals | Explain forward-auth versus native application OIDC and the reason for reconciling historical instructions | No evidence of applied group policy, MFA enforcement or successful offboarding |
| E05 / storage and recovery | proxmox/storage-setup.md; proxmox/backup-job.sh; WP8 plan | Explain persistent storage and the same-pool backup risk, followed by a proposed independent-copy design | No off-host copy or restored-backup verification is established |
| E06 / logging and operations | scripts/setup-syslog.sh; Compose logging declarations; WP10 plan | Explain UDP delivery limits, source attribution and proposed monitoring | No guaranteed delivery, retention, alert receipt or outage detection claim |
| E07 / secure automation | WP2 CA and WP5 provisioning proposals and validation records | A factual problem/change/check/remaining-risk case study | Cite real offline results; distinguish mocked calls and Windows skips from real host execution |
| E08 / application reliability | WP11 input-guard proposal and validation record | Show missing/empty-input rejection and unchanged valid models using dummy fixtures | Parsing does not validate secret strength, app compatibility or live app behavior |
| E09 / change management | Original audit, PR #1 snapshot, WP1 and WP12 proposals | Explain scoped review, revision tracking and proportional governance | Do not present proposed branch safeguards as enabled |

No new operational evidence was collected by this package. Select two or three strong artifacts first instead of publishing every configuration or validation log.

## Artifact design

### Architecture diagram

Preserve the existing PR #1 diagram. If a later diagram is needed, derive it from source and explicitly label it "source architecture; runtime unverified." Show clients, DNS, reverse proxy, identity provider, application groups, persistent storage and logging at a logical level. Show proposed firewall boundaries or independent backup destinations in a distinct planned layer with a legend.

Use consistent service aliases. Do not invent VLANs, active segmentation, redundant hosts, off-site copies or monitoring components. An LXC boundary is not evidence of a firewall boundary. Depict observed source flows separately from desired access policy. Keep the editable diagram source and a sanitized export, with a revision/date caption.

### Troubleshooting and hardening case studies

Use one short structure: problem, evidence, decision, change proposed, actual offline check, limits, and next live acceptance. Suitable existing topics are CA overwrite prevention, Proxmox partial-failure handling, Compose required-input guards, or the documented backup failure domain.

Read the corresponding saved validation record before quoting any count. Include skipped tests and mocks. Do not say the entire lab was rebuilt or secured because a script passed syntax checks. Attribute assistant-assisted changes accurately if discussing authorship; distinguish the owner's original infrastructure work, review decisions and generated proposals.

### Future runtime evidence

Collect only after the server is available and a separately approved procedure exists. Capture actual timestamps, versions and expected versus observed outcomes, including failures. These are collection requirements, not commands to run now.

| Evidence | Minimum useful cases | Preconditions and safety |
|---|---|---|
| Authentication and authorization | Anonymous access, permitted user, denied user/group, logout/session behavior, disabled-user access | Disposable nonprivileged test identities; known app/proxy release; record proxy auth separately from app permissions and native OIDC |
| Network restrictions | Expected allowed and denied paths, direct application port bypass, management access; IPv4 and applicable IPv6 | Approved WP7 matrix, console recovery and bounded client tests; no broad scanning or firewall changes during evidence collection |
| Backup recovery | Independent-copy existence plus isolated application-consistent restore, file/database sample and recovery access | Approved WP8 plan, sufficient spare storage, no overwrite of production; measure actual recovery time/data window only after a real rehearsal |
| Versions | Installed image IDs/digests, relevant host/app versions and source revision | Read-only inventory; distinguish configured mutable tags from installed artifacts; no pulls or upgrades to obtain evidence |
| Logging and monitoring | Tagged harmless event, receiver arrival/source, rotation, alert receipt and delivery-failure behavior | Approved WP10 plan; bounded synthetic test event clearly labeled as a test, no real user payload or unsafe outage |
| Application operations | Trusted domain/callback, intended permissions, scheduler operation and negative cases | Version-compatible approved WP11 procedure; no real credentials in output |
| Governance | Effective rules and actual harmless check failure/success | Separate authorization; disposable equivalent rules/refs; no force push/deletion tests on master |

Do not force a success narrative. A documented failed check with an honest diagnosis can demonstrate stronger troubleshooting than an unsupported completion claim.

## Capture record template

Use the following fields only when real evidence is collected. This is a blank schema; no result is implied.

- Evidence ID, title, collection date/time with timezone, collector.
- Evidence label and source revision or candidate SHA-256; runtime version if applicable.
- Narrow claim supported and related audit/work-package IDs.
- Preconditions, test identity/client role, procedure and expected outcome.
- Actual outcome, raw artifact location and SHA-256; failures/skips.
- Limitations, recovery actions if any, and remaining verification.
- Public derivative location and SHA-256, transformations/redactions, reviewer and publication authorization.

Keep actual private material outside the public repository in an access-controlled location chosen by the owner before collection. Do not store it in a candidate tree or assume a Documents folder is private or encrypted. This package creates no raw evidence store or populated runtime records. Keep future work-package files under the owner's Documents work-package folder.

## Sanitization and publication gate

Publish only evidence needed to support the claim. Before preparing a derivative, review the entire screenshot/export/log, including background windows, browser tabs, filenames, metadata, YAML environment values and hidden document content.

Remove passwords, tokens, keys, cookies, authorization headers, recovery codes/links, session IDs, database dumps, personally identifying account details, internal inventory/serials and unnecessary topology details. Private IP addresses and internal domains are not automatically secrets, but omit or consistently alias them when they are not necessary to explain the design. Never expose a CA private key; public certificates also need review for identifying names.

Use irreversible redaction in the public export, then reopen it and inspect both appearance and extractable text/metadata. A blur, overlay or editable hidden layer is insufficient. Do not publish the original editable file if it retains sensitive content. Retain private originals without destructive alteration; record what changed in the derivative. If text is aliased, say so in the caption; preserve meaningful allowed/denied outcomes and error semantics.

For terminal evidence, select the smallest real excerpt, retain failure context and mark omissions. Avoid capturing a full environment or expanded Compose model containing secrets. Do not use actual credentials merely to create an example. A placeholder or dummy fixture must be labeled illustrative/offline and must not impersonate operational evidence.

Perform a second review of public artifacts and the final PR diff. Verify that tracked files, thumbnails and commit history would not include raw material. A local deletion after committing a secret is not a sufficient remedy; pause publication and address exposure separately. Publication requires explicit approval of the concrete sanitized derivative. This strategy does not authorize publication.

## Claim boundaries and first collection order

A source-supported description is: "VTMN Hub documents a Proxmox-based learning environment with LXC provisioning definitions, containerized applications, identity integration, internal DNS, storage, logging and backup procedures." Cite the relevant revision when used.

For remediation, describe the work as "prepared and checked locally" until publication, deployment and the relevant runtime acceptance are separately recorded. Do not claim production operation, enterprise security, enforced least privilege, working disaster recovery, lossless logging or verified availability from source alone.

Start with a source diagram caption, one actual offline automation case study and a version-inventory collection plan. Then prioritize independent recovery and authentication/direct-port access evidence after prerequisites and approvals. Finally collect operational logging/app evidence. The combined source candidate still requires independent review and separately approved publication/deployment; do not describe it as a verified runtime implementation. Keep PR #1 README-only; any future evidence files belong in a separate reviewed proposal with deliberate links from the final README.

## Completion boundary

This package supplies a strategy and empty capture schema only. Offline document and patch checks do not test any infrastructure. No screenshots, logs, benchmarks, runtime results, repository changes or publication are produced. Evidence gaps remain explicit until genuine collection occurs.

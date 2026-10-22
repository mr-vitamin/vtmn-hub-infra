# Homepage Docker socket capability gate

**Integrated candidate — October 22, 2026.** The existing socket mount is retained byte-for-byte from master. Work Package 4's removal hunk is deliberately excluded until actual consumers can be inventoried. This retains its privilege risk; it does not assert the mount is necessary or safe.

## Source evidence and uncertainty

Committed Homepage configuration contains no active Docker integration/automatic-discovery consumer. However Compose binds /opt/homepage/config from the LXC, which can differ from tracked files; overrides, Docker labels or other API consumers may exist. Source alone cannot demonstrate unchanged functionality after removal.

A read-only filesystem mount does not impose read-only Docker API permissions. Existing direct socket access remains a meaningful local privilege boundary risk. No replacement proxy, service, authentication bypass or port change is introduced.

## Future decision gate

Before any approved removal, capture the actual config/override files and consumers, verify dashboard links, widgets, discovery and permissions, then evaluate the narrow removal proposal with recovery available. Do not copy raw API tokens or effective secret-bearing configuration into Git.

If no required consumer exists, a separately approved change can remove only the socket bind and verify dashboard behavior. If a consumer exists, document its purpose and consider the least-privilege supported alternative without automatically redesigning the platform.

## Rollback

No runtime mount changed here. Source rollback is a reviewed revert; deployment rollback requires the saved effective configuration and deliberate approval. Reintroducing direct socket access restores the same API privilege risk, so it is not an automatic fallback.

# Deliberately empty discovery directory

Compose mounts this directory into the Authentik server and worker. It contains no project YAML until installed-version compatibility, existing blueprint instances, secrets, and application/provider state have been reviewed.

Do not copy the historical files here or broaden the mount to include their parent. The [identity handoff](../../README.md) describes the authoritative proposed state, review-only candidates, and activation gates.

Removing a file does not undo Authentik database objects or guarantee that an existing blueprint instance is disabled.

# Internal CA initialization and recovery

This procedure concerns the internal CA and wildcard certificate defined in [create-internal-ca.sh](../scripts/create-internal-ca.sh). It does not establish that any certificate is valid or deployed.

The physical server was reported powered off as of October 21, 2026. The safety change was reviewed offline. No production keys were generated, replaced, rotated, transferred, or installed.

## Initialization is not renewal

The script is for a **new, intentionally separate CA**. It creates a new root identity and a wildcard/apex certificate for `*.vtmn.internal` and `vtmn.internal`.

It is **not** the procedure for replacing an expiring certificate in the existing VTMN Hub environment. Leaf renewal must retain the existing CA identity unless a deliberate CA migration has been approved. Deleting `vtmn-ca` and rerunning initialization is not renewal; it creates a different root and can break client trust.

No automated renewal implementation is included in this package. A renewal procedure must be reviewed against the existing CA, serial-number state, intended key reuse/rotation policy, actual OpenSSL version, and NPM/client requirements. Do not infer that the production CA needs replacement.

## Preconditions

- Use Bash and an already-installed compatible OpenSSL, mkdir, and cat. The script checks their availability.
- Run as the intended key owner; root is not inherently required. Use a private, trusted working directory on a filesystem that enforces ownership and permissions.
- The output remains `./vtmn-ca` relative to the invocation directory, preserving the earlier naming and location convention.
- The parent directory must exist and be writable. Do not run in a shared temporary directory, group/world-writable parent, untrusted mount, or path another account can replace.
- Do not point the working directory at existing production CA material or attempt to rerun against a previous initialization.
- The script accepts no path arguments. Its only optional argument is `--help`. Choose the trusted working directory before invoking it.
- Confirm that a genuinely new CA is intended before executing the generation command. This documentation is not authorization to generate or deploy production material.

Atomic directory creation prevents ordinary collisions, including two simultaneous invocations. It is not protection against a malicious same-user process or another actor able to rename/replace the trusted parent or its contents. A private local directory and appropriate host account security remain required.

## Behavior of the proposed safety change

1. Set a restrictive `umask 077` before creating output.
2. Check tools and resolve/check the invocation directory.
3. Atomically create `vtmn-ca` with requested directory mode 700.
4. Refuse any existing output path: empty/nonempty directory, regular file, directory symlink, or dangling symlink. An existence check followed by `mkdir -p` is deliberately avoided.
5. Generate the original root/leaf architecture only after the directory is acquired.
6. On an OpenSSL or file-write error, return a nonzero status with the failing stage. Retain partial output for deliberate inspection; never automatically delete it or retry into it.
7. Report initialization completion only after all generation commands succeed. This does not assert certificate/client validity or deployment.

On a normal POSIX filesystem, the restrictive umask protects newly created sensitive files from group/other access. The script does not change permissions or ownership on an existing CA. Windows ACL behavior is not equivalent to Linux modes and was not certified by the offline tests.

## Outputs and custody

| File | Purpose | Handling |
|---|---|---|
| `ca.key` | Root CA private signing key | Highly sensitive. Keep private; protect recovery copy with encryption and restricted access. Never commit, upload to NPM, or distribute to clients. |
| `ca.crt` | Root CA public certificate | Verify its fingerprint through a trusted channel before importing into client trust stores. |
| `ca.srl` | Issuance serial state created by OpenSSL | Retain with CA recovery records; coordinate future issuance rather than resetting state casually. |
| `vtmn-internal.key` | Server private key | Sensitive; intended for the reviewed NPM custom-certificate installation, not for client trust stores. |
| `vtmn-internal.crt` | Server certificate | Check chain, SANs, validity, and required extensions/client acceptance before use. |
| `vtmn-internal.csr` | Server certificate request | Retain with issuance records as needed; does not replace the private key. |
| `san.ext` | Wildcard/apex SAN input | Non-secret issuance configuration; retain for reproducibility. |

The script preserves a 4096-bit RSA root, 2048-bit RSA leaf, SHA-256 signing, 3650-day root and 825-day leaf parameters from the original source. These values are not a promise of current browser or client policy compatibility. The root certificate's effective extensions also depend on the OpenSSL configuration/version. Do not deploy before inspecting the resulting certificate chain and extensions with the intended tooling.

Public certificates and private keys serve different purposes. Only the root public certificate belongs in client trust stores. NPM uses the leaf certificate and its corresponding leaf private key. The private root key is not needed on the reverse proxy for routine HTTPS serving.

## Existing CA and failed initialization

If the script refuses an existing path, stop. Do not delete, rename, chmod, or regenerate production material just to make initialization pass.

Determine whether the path contains:
- an existing operational CA;
- a recovery copy that must be preserved;
- partial output from an interrupted attempt;
- a file or symlink that requires investigation.

Compare public-certificate fingerprints and reviewed recovery records without printing private-key contents. Retain evidence of a failed attempt privately. Resolve the failure before a new attempt in a distinct trusted workspace, and only if a new CA is actually intended. A new workspace is not a way to silently replace the production root.

Changing certificate files on disk does not automatically update NPM or client trust stores, and reverting this script cannot recover lost keys.

## Safe handling and backup plan

No independent backup hardware is assumed. Before depending on a CA:

1. Record the root public-certificate fingerprint, purpose, creation/expiry dates, owner, and storage/recovery location without recording private key contents in Git.
2. Protect a recovery copy of the root private key, root public certificate, serial state, issuance configuration, and necessary records. Preserve required server keys or document an approved recovery issuance process.
3. Use a separate encrypted destination approved by the owner, such as encrypted removable media or a protected password-management/recovery vault capable of storing the material.
4. Keep encryption/recovery credentials accessible through a separate approved recovery path. A backup whose encryption key is only on the lost host is insufficient.
5. Restrict access, minimize plaintext copies, and keep recovery material separate from normal web-serving data. Git ignore rules are not a substitute for custody or encrypted backup.
6. Verify the encrypted copy can be recovered in an isolated, trusted workspace. Do not overwrite an existing key or deploy a restored certificate as part of a verification exercise.

The current repository documents backups on the production ZFS pool. That is not independent protection for host/pool loss. This package documents safe custody; it does not select, create, mount, or populate a backup destination.

## Offline validation and remaining verification

The regression test [test-create-internal-ca.sh](../tests/test-create-internal-ca.sh) executes the script in disposable directories with OpenSSL replaced by a stub that writes visibly dummy text, never a real key. It checks refusal behavior, unchanged fixture data, fresh output, error exits/retained failures, and competing invocations.

Run it only against a reviewed local script using an absolute script path:

```bash
bash -n scripts/create-internal-ca.sh
bash tests/test-create-internal-ca.sh "$PWD/scripts/create-internal-ca.sh"
```

These commands do not initialize a production CA. The test harness creates/removes only its own temporary fixture tree. Review its temporary directory location before use.

When evaluated on Windows Git Bash, POSIX file-mode assertions and genuine symlink cases may be skipped explicitly; those skipped cases are not passing tests. Repeat the suite on a trusted Linux filesystem before relying on those platform-specific guarantees. No new software installation is required or authorized by this document.

Still pending: Linux mode/symlink validation, actual OpenSSL certificate generation/extension and chain checks in a disposable environment, production key custody/recovery verification, client compatibility, NPM installation, renewal, and any live infrastructure checks. Do not label PKI-001 fully deployed or fully verified from a source proposal alone.

#!/bin/bash
# Offline regression checks. OpenSSL is always replaced by a fixture stub.
# Usage: bash tests/test-create-internal-ca.sh /absolute/path/to/create-internal-ca.sh
set -euo pipefail

script=${1:?Supply the script to test}
[[ "$script" = /* ]] || { echo "Use an absolute script path" >&2; exit 2; }
temp_parent=$(cd -- "${TMPDIR:-/tmp}" && pwd -P)
root=$(mktemp -d "$temp_parent/vtmn-ca-test.XXXXXXXX")
# Delete only the resolved, freshly created fixture directory under this parent.
cleanup() {
  case "$root" in
    "$temp_parent"/vtmn-ca-test.????????)
      [[ -d "$root" && ! -L "$root" ]] && rm -rf -- "$root"
      ;;
    *) printf 'Refusing unexpected cleanup path: %s\n' "$root" >&2 ;;
  esac
}
trap cleanup EXIT
mkdir "$root/bin"
cat > "$root/bin/openssl" <<'STUB'
#!/bin/bash
set -eu
printf '%s\n' "$*" >> "$OPENSSL_CALLS"
if [[ "${FAIL_OPENSSL:-0}" = 1 || "${FAIL_OPENSSL:-0}" = "$1" ]]; then exit 42; fi
output=
previous=
for arg in "$@"; do
  [[ "$previous" != -out ]] || output=$arg
  previous=$arg
done
[[ -z "$output" ]] || printf 'DISPOSABLE STUB OUTPUT\n' > "$output"
if [[ "$1" = x509 ]]; then printf '01\n' > ca.srl; fi
printf '%s\n' "$(umask)" >> "$OPENSSL_UMASK"
STUB
chmod +x "$root/bin/openssl"
export PATH="$root/bin:$PATH"
export OPENSSL_CALLS="$root/calls" OPENSSL_UMASK="$root/umasks"
: > "$OPENSSL_CALLS"
: > "$OPENSSL_UMASK"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }
run_at() { (cd "$1" && /bin/bash "$script" > "$root/stdout" 2> "$root/stderr"); }
reset_calls() { : > "$OPENSSL_CALLS"; }

mkdir "$root/existing"
mkdir "$root/existing/vtmn-ca"
printf 'ORIGINAL CA KEY\n' > "$root/existing/vtmn-ca/ca.key"
printf 'ORIGINAL CA CERT\n' > "$root/existing/vtmn-ca/ca.crt"
cp -R "$root/existing/vtmn-ca" "$root/expected"
if run_at "$root/existing"; then fail "existing CA directory was accepted"; fi
diff -r "$root/expected" "$root/existing/vtmn-ca" || fail "existing CA material changed"
[[ ! -s "$OPENSSL_CALLS" ]] || fail "OpenSSL ran for an existing CA"
pass "existing CA material refused unchanged"

mkdir "$root/empty"
mkdir "$root/empty/vtmn-ca"
reset_calls
if run_at "$root/empty"; then fail "empty output directory was accepted"; fi
[[ ! -s "$OPENSSL_CALLS" ]] || fail "OpenSSL ran for empty existing directory"
pass "empty existing directory refused"

mkdir "$root/file"
printf 'KEEP FILE\n' > "$root/file/vtmn-ca"
reset_calls
if run_at "$root/file"; then fail "existing file was accepted"; fi
[[ "$(cat "$root/file/vtmn-ca")" = "KEEP FILE" ]] || fail "existing file changed"
[[ ! -s "$OPENSSL_CALLS" ]] || fail "OpenSSL ran for an existing file"
pass "existing file refused unchanged"

mkdir "$root/fresh"
reset_calls
run_at "$root/fresh" || fail "fresh initialization failed"
for name in ca.key ca.crt ca.srl vtmn-internal.key vtmn-internal.csr vtmn-internal.crt san.ext; do
  [[ -s "$root/fresh/vtmn-ca/$name" ]] || fail "missing output $name"
done
[[ "$(wc -l < "$OPENSSL_CALLS")" -eq 5 ]] || fail "unexpected OpenSSL operation count"
grep -Fxq 'subjectAltName = DNS:*.vtmn.internal, DNS:vtmn.internal' "$root/fresh/vtmn-ca/san.ext" || fail "SAN architecture changed"
grep -Eq '^0*77$' "$OPENSSL_UMASK" || fail "sensitive output creation was not restrictive"
pass "fresh initialization preserves output architecture and restrictive umask"

# Native Windows mounts do not model Linux ownership/mode guarantees.
case "$(uname -s)" in
  MINGW*|MSYS*) echo "SKIP: POSIX file mode enforcement on Windows filesystem" ;;
  *)
    [[ "$(stat -c %a "$root/fresh/vtmn-ca")" = 700 ]] || fail "output directory permissions"
    [[ "$(stat -c %a "$root/fresh/vtmn-ca/ca.key")" = 600 ]] || fail "CA key permissions"
    [[ "$(stat -c %a "$root/fresh/vtmn-ca/vtmn-internal.key")" = 600 ]] || fail "leaf key permissions"
    pass "directory and key modes"
    ;;
esac

mkdir "$root/failed"
reset_calls
if FAIL_OPENSSL=1 run_at "$root/failed"; then fail "OpenSSL error reported as success"; fi
[[ -d "$root/failed/vtmn-ca" ]] || fail "failure directory removed"
reset_calls
if run_at "$root/failed"; then fail "partial initialization was reused"; fi
[[ ! -s "$OPENSSL_CALLS" ]] || fail "rerun reached OpenSSL after failure"
pass "failure retained and retry refused"

mkdir "$root/late-failure"
reset_calls
if FAIL_OPENSSL=x509 run_at "$root/late-failure"; then fail "late signing error reported as success"; fi
[[ -s "$root/late-failure/vtmn-ca/ca.key" && -s "$root/late-failure/vtmn-ca/ca.crt" ]] || fail "partial CA output lost"
grep -q 'server certificate signing' "$root/stderr" || fail "failure stage not reported"
if grep -q 'Initialization completed' "$root/stdout"; then fail "failure printed success"; fi
pass "late signing failure preserves partial output and reports its stage"

mkdir "$root/parent with spaces"
reset_calls
run_at "$root/parent with spaces" || fail "trusted parent with spaces rejected"
[[ -s "$root/parent with spaces/vtmn-ca/ca.key" ]] || fail "output in parent with spaces missing"
pass "trusted parent with spaces works"

mkdir "$root/args"
reset_calls
if (cd "$root/args" && /bin/bash "$script" unexpected > "$root/stdout" 2> "$root/stderr"); then fail "unexpected argument accepted"; fi
[[ ! -e "$root/args/vtmn-ca" && ! -s "$OPENSSL_CALLS" ]] || fail "invalid invocation had side effects"
pass "invalid invocation refused without output"

# Isolate PATH to a directory without openssl.
mkdir "$root/no-tools" "$root/missing-tool"
reset_calls
if (cd "$root/missing-tool" && PATH="$root/no-tools" /bin/bash "$script" > "$root/stdout" 2> "$root/stderr"); then fail "missing tools accepted"; fi
[[ ! -e "$root/missing-tool/vtmn-ca" && ! -s "$OPENSSL_CALLS" ]] || fail "missing tool check had side effects"
pass "missing prerequisite refused before output"

reset_calls
(cd "$root/missing-tool" && PATH="$root/no-tools" /bin/bash "$script" --help > "$root/stdout" 2> "$root/stderr") || fail "help requires generation tools"
[[ ! -e "$root/missing-tool/vtmn-ca" && ! -s "$OPENSSL_CALLS" ]] || fail "help had generation side effects"
pass "help does not require tools or initialize output"

# Only run symlink cases where the host really creates symlinks.
mkdir "$root/link" "$root/target" "$root/dangling"
printf 'TARGET KEY\n' > "$root/target/ca.key"
if ln -s "$root/target" "$root/link/vtmn-ca" 2>/dev/null && [[ -L "$root/link/vtmn-ca" ]]; then
  reset_calls
  if run_at "$root/link"; then fail "directory symlink accepted"; fi
  [[ "$(cat "$root/target/ca.key")" = 'TARGET KEY' && ! -s "$OPENSSL_CALLS" ]] || fail "symlink target modified"
  pass "directory symlink refused unchanged"
else
  echo "SKIP: host did not create a genuine directory symlink"
fi
if ln -s "$root/absent" "$root/dangling/vtmn-ca" 2>/dev/null && [[ -L "$root/dangling/vtmn-ca" ]]; then
  reset_calls
  if run_at "$root/dangling"; then fail "dangling symlink accepted"; fi
  [[ -L "$root/dangling/vtmn-ca" && ! -s "$OPENSSL_CALLS" ]] || fail "dangling symlink altered"
  pass "dangling symlink refused unchanged"
else
  echo "SKIP: host did not create a genuine dangling symlink"
fi

mkdir "$root/concurrent"
reset_calls
(cd "$root/concurrent" && /bin/bash "$script" > "$root/one.out" 2> "$root/one.err") & one=$!
(cd "$root/concurrent" && /bin/bash "$script" > "$root/two.out" 2> "$root/two.err") & two=$!
first=0; second=0
wait "$one" || first=$?
wait "$two" || second=$?
[[ ( "$first" -eq 0 && "$second" -ne 0 ) || ( "$first" -ne 0 && "$second" -eq 0 ) ]] || fail "concurrent initializer results"
[[ "$(wc -l < "$OPENSSL_CALLS")" -eq 5 ]] || fail "losing initializer reached OpenSSL"
pass "only one concurrent initializer succeeds"

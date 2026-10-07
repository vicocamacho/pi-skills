#!/usr/bin/env bash
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
helper=$script_dir/replica-query.sh
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir "$scratch/bin"

cat > "$scratch/bin/psql" <<'SH'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$@" > "$TEST_CAPTURE"
printf '%s\n' "$PGHOST" "$PGPORT" "$PGDATABASE" "$PGUSER" "${PGPASSWORD:-}" > "$TEST_CAPTURE.connection"
[[ -z ${PGOPTIONS:-} && -z ${PGSERVICE:-} && -z ${PGHOSTADDR:-} ]] || exit 99
exit "${TEST_PSQL_STATUS:-0}"
SH
chmod +x "$scratch/bin/psql"
export PATH="$scratch/bin:$PATH" TEST_CAPTURE="$scratch/capture"
export TEST_DB_URL='postgresql://reader%40org:s%27e%5Ccret%25@replica.example.com:6432/app%2Dproduction?sslmode=verify-full&sslrootcert=%2Ftmp%2Fca.pem&statusColor=red'

expect_refusal() {
  rm -f "$TEST_CAPTURE"
  if "$@" > "$scratch/output" 2>&1; then
    printf '%s\n' 'Expected refusal but command succeeded' >&2
    exit 1
  fi
  [[ ! -f $TEST_CAPTURE ]]
}

expect_refusal bash "$helper" --check
expect_refusal bash "$helper" --env
expect_refusal bash "$helper" --env '$(touch ignored)'
expect_refusal bash "$helper" --env MISSING_TEST_VARIABLE --check
expect_refusal env TEST_DB_URL='postgresql://reader@host/db?sslmode=disable' bash "$helper" --env TEST_DB_URL --check
expect_refusal env TEST_DB_URL='postgresql://reader@host/db?unknown=value' bash "$helper" --env TEST_DB_URL --check
expect_refusal env TEST_DB_URL='postgresql://reader@host:abc/db' bash "$helper" --env TEST_DB_URL --check
expect_refusal env TEST_DB_URL='postgresql://reader@host:65536/db' bash "$helper" --env TEST_DB_URL --check
expect_refusal env TEST_DB_URL='postgresql://reader:p%00ss@host/db' bash "$helper" --env TEST_DB_URL --check
expect_refusal env TEST_DB_URL='postgresql://reader:p%XXss@host/db' bash "$helper" --env TEST_DB_URL --check
expect_refusal env TEST_DB_URL='postgresql://reader@host1,host2/db' bash "$helper" --env TEST_DB_URL --check
expect_refusal env TEST_DB_URL='postgresql://reader@host1%2Chost2/db' bash "$helper" --env TEST_DB_URL --check
expect_refusal env TEST_DB_URL='postgresql://reader@%2Ftmp/db' bash "$helper" --env TEST_DB_URL --check
expect_refusal bash "$helper" --env TEST_DB_URL < /dev/null
printf 'DELETE FROM records\n' | expect_refusal bash "$helper" --env TEST_DB_URL
printf 'SELECT 1; COMMIT; SELECT 2\n' | expect_refusal bash "$helper" --env TEST_DB_URL
printf '\\connect writer\n' | expect_refusal bash "$helper" --env TEST_DB_URL
printf 'DELETE FROM records\nSELECT 1\n' | expect_refusal bash "$helper" --env TEST_DB_URL

PGOPTIONS='-c default_transaction_read_only=off' PGSERVICE=writer PGHOSTADDR=127.0.0.1 bash "$helper" --env TEST_DB_URL --check
printf '%s\n' replica.example.com 6432 app-production 'reader@org' "s'e\cret%" > "$scratch/expected"
cmp "$scratch/expected" "$TEST_CAPTURE.connection"
grep -Fq 'sslmode=verify-full gssencmode=disable' "$TEST_CAPTURE"
grep -Fq "options=''" "$TEST_CAPTURE"
grep -Fq 'BEGIN READ ONLY;' "$TEST_CAPTURE"
grep -Fq "SET LOCAL statement_timeout = '15s';" "$TEST_CAPTURE"
grep -Fq 'IF NOT pg_is_in_recovery() THEN' "$TEST_CAPTURE"
grep -Fq "RAISE EXCEPTION 'Physical read replica required" "$TEST_CAPTURE"
grep -Fq 'ROLLBACK;' "$TEST_CAPTURE"
grep -Fq 'ON_ERROR_STOP=1' "$TEST_CAPTURE"
if grep -Fq "$TEST_DB_URL" "$TEST_CAPTURE" || grep -Fq "s'e\cret%" "$TEST_CAPTURE"; then
  printf '%s\n' 'Credentials appeared in psql arguments' >&2
  exit 1
fi

export STAGING_TEST_URL='postgres://reader@[2001:db8::1]:5433/staging'
printf 'SELECT id FROM records WHERE id = 1\n' | bash "$helper" --env STAGING_TEST_URL
printf '%s\n' '2001:db8::1' 5433 staging reader '' > "$scratch/expected"
cmp "$scratch/expected" "$TEST_CAPTURE.connection"
grep -Fq 'sslmode=require' "$TEST_CAPTURE"
grep -Fq 'SELECT * FROM (' "$TEST_CAPTURE"
grep -Fq ') AS investigation_result LIMIT 100;' "$TEST_CAPTURE"
printf 'WITH found AS (SELECT 1 AS id) SELECT id FROM found\n' | bash "$helper" --env STAGING_TEST_URL
printf 'Select 1 AS id\n' | bash "$helper" --env STAGING_TEST_URL

if TEST_PSQL_STATUS=3 bash "$helper" --env TEST_DB_URL --check; then
  printf '%s\n' 'Expected psql failure propagation' >&2
  exit 1
else
  [[ $? -eq 3 ]]
fi

printf '%s\n' 'Investigation helper tests passed.'

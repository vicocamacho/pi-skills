#!/usr/bin/env bash
set -euo pipefail

refuse() {
  printf 'Refused: %s\n' "$1" >&2
  exit 1
}

usage() {
  printf '%s\n' 'Usage: replica-query.sh --env VARIABLE [--check]' \
    'VARIABLE must contain a PostgreSQL replica URL. Submit one SELECT or WITH query on stdin.'
}

# Decode URI fields without printing credentials or interpreting raw escapes.
decode() {
  local value=$1 remaining=$1 tail hex
  [[ $value != *\\* ]] || refuse 'URL fields must percent-encode backslashes.'
  while [[ $remaining == *%* ]]; do
    tail=${remaining#*%}
    hex=${tail:0:2}
    [[ $hex =~ ^[0-9a-fA-F]{2}$ && $hex != 00 ]] || refuse 'Invalid URL percent encoding.'
    remaining=${tail:2}
  done
  printf -v REPLY '%b' "${value//%/\\x}"
}

db_env=
check=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --env)
      [[ $# -ge 2 ]] || refuse '--env needs a variable name.'
      db_env=$2
      shift 2 ;;
    --check) check=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
done
[[ $db_env =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || refuse 'Specify a valid environment variable with --env.'
url=${!db_env:-}
[[ -n $url ]] || refuse 'The selected database URL variable is empty or unset.'
case $url in
  postgresql://*) rest=${url#postgresql://} ;;
  postgres://*) rest=${url#postgres://} ;;
  *) refuse 'The selected variable must contain a PostgreSQL URL.' ;;
esac
[[ $rest == */* && $rest != *'#'* ]] || refuse 'The URL needs a database path and no fragment.'
authority=${rest%%/*}
path=${rest#*/}
[[ $authority == *@* ]] || refuse 'The URL must explicitly specify a database user.'
userinfo=${authority%@*}
hostport=${authority##*@}
[[ $userinfo != *@* ]] || refuse 'Reserved characters in URL credentials must be percent-encoded.'
database=${path%%\?*}
[[ -n $database && $database != */* ]] || refuse 'The URL needs one percent-encoded database name.'

# Ambient routing must not override the explicitly selected target.
unset PGSERVICE PGSERVICEFILE PGHOST PGHOSTADDR PGPORT PGDATABASE PGUSER PGPASSWORD PGOPTIONS PGTARGETSESSIONATTRS

decode "${userinfo%%:*}"
[[ -n $REPLY ]] || refuse 'The URL needs a database user.'
export PGUSER=$REPLY
if [[ $userinfo == *:* ]]; then
  decode "${userinfo#*:}"
  export PGPASSWORD=$REPLY
fi
port=5432
if [[ $hostport == \[* ]]; then
  [[ $hostport =~ ^\[([^]]+)\](:([0-9]+))?$ ]] || refuse 'Invalid IPv6 host or port.'
  host=${BASH_REMATCH[1]}
  port=${BASH_REMATCH[3]:-5432}
else
  host=${hostport%%:*}
  [[ $hostport != *:* ]] || port=${hostport#*:}
fi
[[ -n $host && $host != *,* && $port =~ ^[0-9]{1,5}$ ]] || refuse 'Use one host and a numeric port.'
(( 10#$port > 0 && 10#$port <= 65535 )) || refuse 'Port must be between 1 and 65535.'
decode "$host"
[[ -n $REPLY && $REPLY != /* && $REPLY != *,* ]] || refuse 'Use one network replica host, not Unix sockets or multiple hosts.'
export PGHOST=$REPLY PGPORT=$port
decode "$database"
export PGDATABASE=$REPLY

sslmode=require
if [[ $path == *\?* ]]; then
  parameters=${path#*\?}
  while [[ -n $parameters ]]; do
    pair=${parameters%%&*}
    if [[ $parameters == *'&'* ]]; then parameters=${parameters#*&}; else parameters=; fi
    decode "${pair%%=*}"
    key=$REPLY
    [[ $pair == *=* ]] || refuse 'URL parameters need values.'
    decode "${pair#*=}"
    case $key in
      sslmode) sslmode=$REPLY ;;
      sslrootcert) export PGSSLROOTCERT=$REPLY ;;
      sslcert) export PGSSLCERT=$REPLY ;;
      sslkey) export PGSSLKEY=$REPLY ;;
      sslcrl) export PGSSLCRL=$REPLY ;;
      sslcrldir) export PGSSLCRLDIR=$REPLY ;;
      passfile) export PGPASSFILE=$REPLY ;;
      channel_binding) export PGCHANNELBINDING=$REPLY ;;
      connect_timeout|application_name) ;;
      statusColor|env|name|tLSMode|usePrivateKey|safeModeLevel|advancedSafeModeLevel|driverVersion|lazyload) ;;
      *) refuse 'Unsupported URL parameter; configure a standard replica URL.' ;;
    esac
  done
fi
case $sslmode in
  require|verify-ca|verify-full) ;;
  *) refuse 'TLS must use require, verify-ca or verify-full.' ;;
esac

if [[ $check == true ]]; then
  body="SELECT current_database() AS database, pg_is_in_recovery() AS physical_replica,
       current_setting('transaction_read_only') AS transaction_read_only,
       clock_timestamp() AS observed_at,
       pg_last_xact_replay_timestamp() AS last_replayed_transaction_at;"
else
  [[ ! -t 0 ]] || refuse 'Supply a query on stdin, or use --check.'
  query=$(cat)
  [[ $query != *';'* && $query != *\\* ]] || refuse 'Omit semicolons and backslashes.'
  [[ $query =~ ^[[:space:]]*([Ss][Ee][Ll][Ee][Cc][Tt]|[Ww][Ii][Tt][Hh])[[:space:]] ]] || refuse 'Submit one SELECT or WITH query.'
  body="SELECT * FROM (
$query
) AS investigation_result LIMIT 100;"
fi

# PgBouncer can reject startup PGOPTIONS; set timeouts inside the transaction.
exec psql -X -w -q -x -P pager=off -v ON_ERROR_STOP=1 \
  -d "sslmode=$sslmode gssencmode=disable connect_timeout=5 options='' application_name=investigate" \
  -c "BEGIN READ ONLY;
SET LOCAL statement_timeout = '15s';
SET LOCAL lock_timeout = '2s';
DO \$replica_check\$
BEGIN
  IF NOT pg_is_in_recovery() THEN
    RAISE EXCEPTION 'Physical read replica required; refusing to query a primary';
  END IF;
END
\$replica_check\$;
$body
ROLLBACK;"

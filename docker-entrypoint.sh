#!/bin/bash
set -e

# Set timezone if variable is set
if [ ! -z "${TZ}" ]; then
    echo "ℹ️ Setting timezone to ${TZ}"
    ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
    echo "${TZ}" > /etc/timezone
fi

# Generate configfile by using PG_ docker variables
CONFIG_PATH="/etc/autodbbackup.d/autopostgresqlbackup.conf"

# Define default values for selected keys
declare -A DEFAULTS=(
  [BACKUPDIR]="/backup"
  [DBENGINE]="postgresql"
  [DBNAMES]="all"
  [GLOBALS_OBJECTS]="postgres_globals"
  [BACKUPDIR]="/backup"
  [CREATE_DATABASE]="yes"
  [DOWEEKLY]=7
  [DOMONTHLY]=1
  [BRDAILY]=14
  [BRWEEKLY]=5
  [BRMONTHLY]=12
  [COMP]="gzip"
  [EXT]="sql"
  [PERM]=600
  [MIN_DUMP_SIZE]=256
  [ENCRYPTION]="no"
  [SU_USERNAME]=""
  [MAILADDR]=""
  [DEBUG]=yes
)

# Define blacklist
declare -A BLACKLIST=(
  [CONFIG]=1
  [CONFIG_COMPAT]=1
  [MAILADDR]=1
  [SU_USERNAME]=1
  [BACKUPDIR]=1
  [PGDUMP]=1
  [PGDUMPALL]=1
  [PGDUMP_OPTS]=1
  [PGDUMPALL_OPTS]=1
  [MY]=1
  [MYDUMP]=1
  [MYDUMP_OPTS]=1
  [ENCRYPTION]=1
  [ENCRYPTION_PUBLIC_KEY]=1
  [ENCRYPTION_SUFFIX]=1
  [PREBACKUP]=1
  [POSTBACKUP]=1
  [DEBUG]=1
  [GPG_HOMEDIR]=1
  [PASSWORD]=1

)

# Ensure config directory exists
mkdir -p "$(dirname "$CONFIG_PATH")"
> "$CONFIG_PATH"

# Write default values with PG_ override support
for key in "${!DEFAULTS[@]}"; do
  env_key="PG_${key}"
  value="${!env_key:-${DEFAULTS[$key]}}"
  echo "${key}=\"${value}\"" >> "$CONFIG_PATH"
done

# Write additional PG_ variables not in defaults or blacklist
env | grep '^PG_' | while IFS='=' read -r raw_key value; do
  stripped="${raw_key#PG_}"
  upper="${stripped^^}"

  # Skip if already handled or blacklisted
  if [[ -n "${DEFAULTS[$upper]}" || -n "${BLACKLIST[$upper]}" ]]; then
    continue
  fi

  echo "${upper}=\"${value}\"" >> "$CONFIG_PATH"
done

# Logic for Password file required
#  If PG_PASSWORD_SECRET env var is defined, search for the /run/secrets/${PASSWORD_SECRET} and read the content
#  If PG_PASSWORD_SECRET is not defined, use PASSWORD env variable
PASSPHRASE=""
if [ "${PG_PASSWORD_SECRET}" ]; then
    echo "ℹ️ Using docker secrets..."
    if [ -f "/run/secrets/${PG_PASSWORD_SECRET}" ]; then
        PASSPHRASE=$(cat /run/secrets/${PG_PASSWORD_SECRET})
    else
        echo "❌ ERROR: Secret file not found in /run/secrets/${PG_PASSWORD_SECRET}"
        echo "Please verify your docker secrets configuration."
        exit 1
    fi
else
    echo "ℹ️ Using environment password..."
    PASSPHRASE=${PG_PASSWORD}
fi

# Determine selected DB engine (from PG_DBENGINE or default)
DBENGINE="${PG_DBENGINE:-${DEFAULTS[DBENGINE]}}"
echo "ℹ️ Selected database engine: ${DBENGINE}"
if [[ "${DBENGINE}" != "postgresql" && "${DBENGINE}" != "mysql" ]]; then
  echo "❌ ERROR: Unsupported DBENGINE '${DBENGINE}'. Must be 'postgresql' or 'mysql'."
  exit 1
fi

echo "🔍 Running environment sanity check..."

# Check required variables
missing=()

if [ -z "${PG_DBHOST}" ]; then
  missing+=("PG_DBHOST")
fi

if [ -z "${PG_USERNAME}" ]; then
  missing+=("PG_USERNAME")
fi

if [ -z "${PG_PASSWORD}" ] && [ -z "${PG_PASSWORD_SECRET}" ]; then
  missing+=("PG_PASSWORD or PG_PASSWORD_SECRET")
fi
echo "✅ Minimal required environment variables set."

if [ ${#missing[@]} -gt 0 ]; then
  echo "❌ Missing required environment variables:"
  for var in "${missing[@]}"; do
    echo "   - $var"
  done
  exit 1
fi

# Check if /backup is writable
BACKUPDIR="${PG_BACKUPDIR:-${DEFAULTS[BACKUPDIR]}}"
if ! touch "${BACKUPDIR}/.sanitycheck" 2>/dev/null; then
  echo "❌ Backup directory '${BACKUPDIR}' is not writable."
  exit 1
else
  rm -f "${BACKUPDIR}/.sanitycheck"
  echo "✅ Backup directory '${BACKUPDIR}' is writable."
fi

echo "✅ Sanity check passed."

# Logic for the CRON schedule
#  If CRON_SCHEDULE is defined, use this value, otherwise use a default
if [ "${CRON_SCHEDULE}" ]; then
    echo "ℹ️ Configuring schedule in /etc/crontab for ${CRON_SCHEDULE}..."
else
    CRON_SCHEDULE="0 2 * * *"
    echo "ℹ️ Configuring schedule in /etc/crontab for default crontab running daily at 02:00..."
fi
  
# Create the crontab file
cat <<-EOF > /etc/crontab

SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# m h dom mon dow user command
${CRON_SCHEDULE} root /opt/autopostgresqlbackup/autopostgresqlbackup >> /proc/1/fd/1 2>> /proc/1/fd/2
EOF
echo "✅ Crontab written to /etc/crontab"

# Cleanup stale password files
rm -rf /root/.pgpass
rm -rf /root/.my.cnf

# Create the postgresql password file
echo "✅ Creating postgresql password file..."
if [ "${DBENGINE}" = "postgresql" ]; then
  cat <<-EOF > /root/.pgpass
${PG_DBHOST}:*:*:${PG_USERNAME}:${PASSPHRASE}
EOF
  chmod 0600 /root/.pgpass
fi

# Create the mysql password file
if [ "${DBENGINE}" = "mysql" ]; then
  echo "✅ Creating MySQL client config..."
  cat <<EOF > /root/.my.cnf
[client]
user=${PG_USERNAME}
password=${PASSPHRASE}
host=${PG_DBHOST}
ssl-verify-server-cert=off
EOF
  chmod 0600 /root/.my.cnf
fi

echo "✅ Config written to $CONFIG_PATH"
echo " "
echo "ℹ️ Current Config :"
#using nl instead of cat to workaround a wierd issue where the EXT="sql" line would not show properly with cat
nl -bn $CONFIG_PATH

echo " "
echo "✅ Done setting up..."

# set /etc/environment for cron
printenv > /etc/environment

# Finished building container and performing user-selected mode
if [ "$1" = "backup-now" ]; then
  echo "Manual backup triggered..."
  exec /opt/autopostgresqlbackup/autopostgresqlbackup
elif [ "$1" = "show-config" ]; then
  echo "ℹ️ Only showing config, not starting cron/backup..."
  exit 0
elif [ "$1" = "test-connection" ]; then
  echo "Testing database connection for engine: ${DBENGINE}"

  if [ "${DBENGINE}" = "postgresql" ]; then
    echo "ℹ️ Attempting PostgreSQL connection to host '${PG_DBHOST}' as user '${PG_USERNAME}'..."
    psql -h "${PG_DBHOST}" -U "${PG_USERNAME}" -d postgres -c '\q' >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "✅ PostgreSQL connection successful."
    else
      echo "❌ PostgreSQL connection failed."
      exit 1
    fi

  elif [ "${DBENGINE}" = "mysql" ]; then
    echo "ℹ️ Attempting MySQL connection to host '${PG_DBHOST}' as user '${PG_USERNAME}'..."
    mysql --host="${PG_DBHOST}" -e "SELECT 1;" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "✅ MySQL connection successful."
    else
      echo "❌ MySQL connection failed."
      exit 1
    fi
  fi

  exit 0
elif [ -n "$1" ]; then
  echo "⚠️ Unknown argument '$1' — ignoring and starting cron."
fi

echo "ℹ️ Starting cron service..."
exec cron -f


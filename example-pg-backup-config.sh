# config.sh

# PostgreSQL server connection information
DEV_HOST="dev_host"
DEV_USER="dev_user"
STAG_HOST="stag_host"
STAG_USER="stag_user"
PROD_HOST="prod_host"
PROD_USER="prod_user"
PORT="5432"
PASSWORD="your_password"

# Parent directory for backups
BACKUP_PARENT_DIR="your-backup-directory-path"

# List of database names
DEV_DATABASES=(
    "db_name_1"
    "db_name_2"
)

STAG_DATABASES=(
    "db_name_1"
    "db_name_2"
)

PROD_DATABASES=(
    "db_name_1"
    "db_name_2"
)
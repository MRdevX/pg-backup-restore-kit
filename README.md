# PostgreSQL Database Backup and Restore Script

This script automates the process of backing up and restoring PostgreSQL databases. It allows users to choose the environment (DEV, STAG, or PROD) for backup and restore operations and select databases for backup. Additionally, it provides functionality to restore databases from backups stored in specified directories.

## Setup

Before using the script, ensure you have configured the necessary settings in the respective configuration files:

### Backup Configuration File (`pg-backup-config.sh`)

```bash
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
```

### Restore Configuration File (`pg-restore-config.sh`)

```bash
# PostgreSQL server connection information for local Docker container
HOST="localhost"
PORT=5432
USER="postgres-user"
PASSWORD="postgres-password"

# Parent directory for backups
BACKUP_PARENT_DIR="your-backup-directory-path"
```

## Usage

### Backup:

1. Run the script `pg-backup.sh`.
2. Choose the environment (DEV, STAG, or PROD) where your PostgreSQL databases reside.
3. Select the databases you want to back up (comma-separated).
4. The script will create a directory with the current date under the specified backup parent directory.
5. It will then proceed to back up the selected databases into the created directory.

### Restore:

1. Run the script `pg-restore.sh`.
2. Confirm whether you want to proceed with the restore operation.
3. Select a backup folder and then choose a backup file from within that folder for restoration.
4. Select the name of the database which will be written to
5. Confirm the selected database and backup file for restoration.
6. If the database exists, confirm if the database should be overwritten
7. The script will create the database (if it doesn't exist) and restore the selected backup file to it.

## Script Overview

### Backup Script (`pg-backup.sh`):

- **`choose_environment()`**: Prompts the user to select the environment (DEV, STAG, or PROD) and sets the corresponding host and user variables.
- **`choose_databases()`**: Prompts the user to select databases to back up.
- **`backup_databases()`**: Backs up the selected databases using `pg_dump` utility.
- **Main Script**:
  - Chooses the environment based on user input.
  - Prompts the user to select databases and backs them up accordingly.

### Restore Script (`pg-restore.sh`):

- **`restore_database()`**: Prompts the user to select a backup folder and file for database restoration. It creates the database if it doesn't exist and restores the selected backup file.
- **Main Script**:
  - Confirms with the user before proceeding with the restore operation.
  - Calls `restore_database()` with the specified backup parent directory.

## Dependencies

- PostgreSQL (`pg_dump`, `pg_restore`, `createdb`)
- Bash

## License

This script is licensed under the [MIT License](LICENSE).

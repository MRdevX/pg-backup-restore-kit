#!/bin/bash

# pg-backup.sh

# This script performs PostgreSQL database backups for the specified environment and databases.

# It imports the pg-backup-config.sh configuration file, prompts the user to select an environment, creates a dated backup directory, prompts the user to select databases to backup, and then performs the database backups using pg_dump.

# The choose_environment function prompts the user to select DEV, STAG or PROD environment and sets the appropriate host, user, and database variables.

# The choose_databases function prompts the user to select a comma-separated list of databases to backup from the available databases for that environment, and populates an array with the selected database names. 

# After the environment and databases are selected, the backup_databases function performs the pg_dump backup for each selected database into dated files in the backup directory.

# Import the configuration file
source pg-backup-config.sh

# Function to prompt user for environment
choose_environment() {
    echo "Select environment:"
    echo "1. DEV"
    echo "2. STAG"
    echo "3. PROD"
    read -p "Enter your choice (1/2/3): " ENV_CHOICE

    case $ENV_CHOICE in
        1) HOST=$DEV_HOST
           USER=$DEV_USER
           ;;
        2) HOST=$STAG_HOST
           USER=$STAG_USER
           ;;
        3) HOST=$PROD_HOST
           USER=$PROD_USER
           ;;
        *) echo "Invalid choice. Please enter 1, 2, or 3."
           choose_environment
           ;;
    esac
}

# Function to prompt user for databases to backup
choose_databases() {
    local DATABASES=("$@")
    local DATABASE_CHOICES
    local DATABASE_ARRAY=()

    echo "Select databases to backup (comma-separated):"
    for ((i=0; i<${#DATABASES[@]}; i++)); do
        echo "$(($i+1)). ${DATABASES[$i]}"
    done

    read -p "Enter your choice(s) (comma-separated): " DATABASE_CHOICES

    IFS=',' read -ra DATABASE_ARRAY <<< "$DATABASE_CHOICES"

    for index in "${DATABASE_ARRAY[@]}"; do
        selected_db=${DATABASES[$(($index-1))]}
        selected_databases+=("$selected_db")
    done
}

# Choose environment
choose_environment

# Create a directory with current date
CURRENT_DATE=$(date +"%Y-%m-%d")
BACKUP_DIR="$BACKUP_PARENT_DIR/$CURRENT_DATE"
mkdir -p "$BACKUP_DIR"

echo "Creating backup directory: $BACKUP_DIR"

# Function to backup databases
backup_databases() {
    local DATABASES=("$@")
    for DB in "${DATABASES[@]}"; do
        echo "Backing up database: $DB"
        CURRENT_DATETIME=$(date +"%Y-%m-%d_%H-%M-%S")
        pg_dump -h $HOST -p $PORT -U $USER -d $DB -F c -f "$BACKUP_DIR/${DB}_${CURRENT_DATETIME}.backup"
        if [ $? -eq 0 ]; then
            echo "Backup of database $DB completed successfully"
        else
            echo "Backup of database $DB failed"
        fi
    done
}

# Prompt user for databases to backup
case $ENV_CHOICE in
    1) choose_databases "${DEV_DATABASES[@]}"
       backup_databases "${selected_databases[@]}"
       ;;
    2) choose_databases "${STAG_DATABASES[@]}"
       backup_databases "${selected_databases[@]}"
       ;;
    3) choose_databases "${PROD_DATABASES[@]}"
       backup_databases "${selected_databases[@]}"
       ;;
esac

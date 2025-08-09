#!/bin/bash

# pg-backup.sh

# This script performs PostgreSQL database backups for the specified environment and databases.

# It imports the pg-backup-config.sh configuration file, prompts the user to select an environment, creates a dated backup directory, prompts the user to select databases to backup, and then performs the database backups using pg_dump.

# The choose_environment function prompts the user to select DEV, STAG or PROD environment and sets the appropriate host, user, and database variables.

# The choose_databases function prompts the user to select a comma-separated list of databases to backup from the available databases for that environment, and populates an array with the selected database names. 

# After the environment and databases are selected, the backup_databases function performs the pg_dump backup for each selected database into dated files in the backup directory.

# Import the configuration file
source pg-backup-config.sh

# Input validation functions
validate_environment_choice() {
    local choice="$1"
    if [[ ! "$choice" =~ ^[1-3]$ ]]; then
        return 1
    fi
    return 0
}

validate_database_choices() {
    local choices="$1"
    local max_count="$2"
    
    # Check if input is empty
    if [[ -z "$choices" ]]; then
        return 1
    fi
    
    # Check if input contains only valid characters
    if [[ ! "$choices" =~ ^[0-9,]+$ ]]; then
        return 1
    fi
    
    # Check each choice
    IFS=',' read -ra choices_array <<< "$choices"
    for choice in "${choices_array[@]}"; do
        if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 )) || (( choice > max_count )); then
            return 1
        fi
    done
    
    return 0
}

validate_database_name() {
    local db_name="$1"
    # Check if database name is empty or contains invalid characters
    if [[ -z "$db_name" ]] || [[ ! "$db_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        return 1
    fi
    return 0
}

# Function to prompt user for environment
choose_environment() {
    echo "Select environment:"
    echo "1. DEV"
    echo "2. STAG"
    echo "3. PROD"
    
    while true; do
        read -p "Enter your choice (1/2/3): " ENV_CHOICE
        if validate_environment_choice "$ENV_CHOICE"; then
            break
        else
            echo "Invalid choice. Please enter 1, 2, or 3."
        fi
    done

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
    esac
}

# Function to prompt user for databases to backup
choose_databases() {
    local DATABASES=("$@")
    local DATABASE_CHOICES
    local DATABASE_ARRAY=()
    selected_databases=()  # Initialize array

    echo "Select databases to backup (comma-separated):"
    for ((i=0; i<${#DATABASES[@]}; i++)); do
        echo "$(($i+1)). ${DATABASES[$i]}"
    done

    while true; do
        read -p "Enter your choice(s) (comma-separated): " DATABASE_CHOICES
        if validate_database_choices "$DATABASE_CHOICES" "${#DATABASES[@]}"; then
            break
        else
            echo "Invalid input. Please enter valid numbers separated by commas (e.g., 1,2,3)."
        fi
    done

    IFS=',' read -ra DATABASE_ARRAY <<< "$DATABASE_CHOICES"

    for index in "${DATABASE_ARRAY[@]}"; do
        local selected_db="${DATABASES[$(($index-1))]}"
        if validate_database_name "$selected_db"; then
            selected_databases+=("$selected_db")
        else
            echo "Warning: Invalid database name '$selected_db' skipped."
        fi
    done
    
    # Check if any valid databases were selected
    if [[ ${#selected_databases[@]} -eq 0 ]]; then
        echo "No valid databases selected. Exiting."
        exit 1
    fi
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

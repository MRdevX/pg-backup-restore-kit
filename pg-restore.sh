#!/bin/bash

# pg-restore.sh

# This script provides functionality to restore PostgreSQL databases from backup.

# It sources the pg-restore-config.sh file to import configuration settings.

# The restore_database function takes a backup directory as an argument.

# It lists the available folders in the backup directory and prompts the user to select one. 

# It then lists the available backup files in the selected folder and prompts the user to select one or all.

# The selected backup file(s) can then be restored to the PostgreSQL database.

# Import the configuration file
source pg-restore-config.sh

# Input validation functions
validate_folder_index() {
    local index="$1"
    local max_count="$2"
    
    if [[ ! "$index" =~ ^[0-9]+$ ]] || (( index < 1 )) || (( index > max_count )); then
        return 1
    fi
    return 0
}

validate_backup_file_index() {
    local index="$1"
    local max_count="$2"
    
    if [[ "$index" == "all" ]]; then
        return 0
    fi
    
    if [[ ! "$index" =~ ^[0-9]+$ ]] || (( index < 1 )) || (( index > max_count )); then
        return 1
    fi
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

validate_confirmation() {
    local input="$1"
    if [[ "${input,,}" =~ ^(y|yes|n|no)$ ]]; then
        return 0
    fi
    return 1
}

# Function to restore a specific database
restore_database() {
    local BACKUP_DIR="$1"

    # List available folders inside BACKUP_PARENT_DIR
    echo "Available backup folders in $BACKUP_DIR:"
    local FOLDERS=("$BACKUP_DIR"/*/)
    if [ ${#FOLDERS[@]} -eq 0 ]; then
        echo "No backup folders found in $BACKUP_DIR"
        exit 1
    fi

    for index in "${!FOLDERS[@]}"; do
        echo "$(($index + 1)). $(basename "${FOLDERS[$index]}")"
    done

    # Prompt user for the selected folder index
    while true; do
        read -p "Enter the number of the backup folder to restore from: " SELECTED_FOLDER_INDEX
        if validate_folder_index "$SELECTED_FOLDER_INDEX" "${#FOLDERS[@]}"; then
            break
        else
            echo "Invalid folder index. Please select a number between 1 and ${#FOLDERS[@]}"
        fi
    done

    SELECTED_FOLDER_PATH="${FOLDERS[$((SELECTED_FOLDER_INDEX - 1))]}"
    echo "Selected backup folder: $(basename "$SELECTED_FOLDER_PATH")"

    # List available backup files inside the selected folder
    echo "Available backup files in $(basename "$SELECTED_FOLDER_PATH"):"
    local DATABASE_FILES=("$SELECTED_FOLDER_PATH"/*.backup)
    if [ ${#DATABASE_FILES[@]} -eq 0 ]; then
        echo "No backup files found in $SELECTED_FOLDER_PATH"
        exit 1
    fi

    for index in "${!DATABASE_FILES[@]}"; do
        echo "$(($index + 1)). $(basename "${DATABASE_FILES[$index]}")"
    done

    # Prompt user for the selected backup file index or all
    while true; do
        read -p "Enter the number of the backup file to restore or 'all' to restore all files: " SELECTED_BACKUP_INDEX
        if validate_backup_file_index "$SELECTED_BACKUP_INDEX" "${#DATABASE_FILES[@]}"; then
            break
        else
            echo "Invalid backup file index. Please select a number between 1 and ${#DATABASE_FILES[@]} or 'all'"
        fi
    done

    if [ "$SELECTED_BACKUP_INDEX" == "all" ]; then
        for BACKUP_FILE in "${DATABASE_FILES[@]}"; do
            restore_single_database "$BACKUP_FILE"
        done
    else
        SELECTED_BACKUP_FILE_PATH="${DATABASE_FILES[$((SELECTED_BACKUP_INDEX - 1))]}"
        restore_single_database "$SELECTED_BACKUP_FILE_PATH"
    fi
}

# Function to restore a single database
restore_single_database() {
    local BACKUP_FILE_PATH="$1"
    echo "Selected backup file: $(basename "$BACKUP_FILE_PATH")"

    # Extract the database name from the backup file name
    DB_NAME=$(basename "$BACKUP_FILE_PATH" .backup | cut -d'_' -f1)
    
    # Validate extracted database name
    if ! validate_database_name "$DB_NAME"; then
        echo "Error: Invalid database name extracted from backup file: $DB_NAME"
        exit 1
    fi

    # Prompt user for the database name to restore to
    while true; do
        read -p "Enter the database name to restore to (press enter for default: $DB_NAME): " USER_DB_NAME
        if [[ -z "$USER_DB_NAME" ]]; then
            break
        elif validate_database_name "$USER_DB_NAME"; then
            DB_NAME="$USER_DB_NAME"
            break
        else
            echo "Invalid database name. Database names must start with a letter or underscore and contain only letters, numbers, and underscores."
        fi
    done

    # Confirm before proceeding with the restore
    while true; do
        read -p "You selected to restore database $DB_NAME from $(basename "$BACKUP_FILE_PATH"). Do you want to continue? (y/n): " confirm
        if validate_confirmation "$confirm"; then
            if [[ "${confirm,,}" =~ ^(y|yes)$ ]]; then
                break
            else
                echo "Restore operation aborted"
                exit 1
            fi
        else
            echo "Please enter 'y' for yes or 'n' for no."
        fi
    done

    # Check if the database already exists
    echo "Checking if database $DB_NAME exists..."
    if PGPASSWORD=$PASSWORD psql -h $HOST -p $PORT -U $USER -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        echo "Database $DB_NAME already exists."
        while true; do
            read -p "Do you want to drop the existing database $DB_NAME before restoring? (y/n/abort): " drop_choice
            if validate_confirmation "$drop_choice" || [[ "${drop_choice,,}" == "abort" ]]; then
                if [[ "${drop_choice,,}" =~ ^(y|yes)$ ]]; then
                    echo "Dropping existing database $DB_NAME..."
                    PGPASSWORD=$PASSWORD dropdb -h $HOST -p $PORT -U $USER $DB_NAME
                    if [ $? -ne 0 ]; then
                        echo "Failed to drop database $DB_NAME. Aborting restore operation."
                        exit 1
                    fi
                    break
                elif [[ "${drop_choice,,}" == "abort" ]]; then
                    echo "Restore operation aborted"
                    exit 1
                else
                    echo "Keeping existing database $DB_NAME"
                    return
                fi
            else
                echo "Please enter 'y' for yes, 'n' for no, or 'abort' to cancel."
            fi
        done
    else
        echo "Database $DB_NAME does not exist. It will be created."
    fi

    # Create the database if it doesn't exist
    echo "Creating database if it doesn't exist: $DB_NAME"
    PGPASSWORD=$PASSWORD createdb -h $HOST -p $PORT -U $USER $DB_NAME

    # Restore the selected backup file to the target database
    echo "Restoring database: $DB_NAME"
    PGPASSWORD=$PASSWORD pg_restore -h $HOST -p $PORT -U $USER -d $DB_NAME --no-owner --no-privileges -F c "$BACKUP_FILE_PATH"
    if [ $? -eq 0 ]; then
        echo "Restore of database $DB_NAME completed successfully"
    else
        echo "Restore of database $DB_NAME failed"
    fi
}

# Confirm with the user before proceeding with the restore operation
while true; do
    read -p "This will restore databases from folders inside $BACKUP_PARENT_DIR to $HOST:$PORT. Do you want to continue? (y/n): " choice
    if validate_confirmation "$choice"; then
        case "${choice,,}" in
            y|yes) restore_database "$BACKUP_PARENT_DIR"; break;;
            n|no) echo "Restore operation aborted"; exit 0;;
        esac
    else
        echo "Please enter 'y' for yes or 'n' for no."
    fi
done
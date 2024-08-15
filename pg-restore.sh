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
    read -p "Enter the number of the backup folder to restore from: " SELECTED_FOLDER_INDEX

    if (( SELECTED_FOLDER_INDEX < 1 || SELECTED_FOLDER_INDEX > ${#FOLDERS[@]} )); then
        echo "Invalid folder index. Please select a number between 1 and ${#FOLDERS[@]}"
        exit 1
    fi

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
    read -p "Enter the number of the backup file to restore or 'all' to restore all files: " SELECTED_BACKUP_INDEX

    if [ "$SELECTED_BACKUP_INDEX" == "all" ]; then
        for BACKUP_FILE in "${DATABASE_FILES[@]}"; do
            restore_single_database "$BACKUP_FILE"
        done
    else
        if (( SELECTED_BACKUP_INDEX < 1 || SELECTED_BACKUP_INDEX > ${#DATABASE_FILES[@]} )); then
            echo "Invalid backup file index. Please select a number between 1 and ${#DATABASE_FILES[@]}"
            exit 1
        fi

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

    # Confirm before proceeding with the restore
    read -p "You selected to restore database $DB_NAME from $(basename "$BACKUP_FILE_PATH"). Do you want to continue? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "Restore operation aborted"
        exit 1
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
read -p "This will restore databases from folders inside $BACKUP_PARENT_DIR to $HOST:$PORT. Do you want to continue? (y/n): " choice
case "$choice" in
  y|Y ) restore_database "$BACKUP_PARENT_DIR";;
  n|N ) echo "Restore operation aborted"; exit;;
  * ) echo "Invalid choice";;
esac
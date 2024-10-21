#!/bin/bash

REMOTE_USER=XXXXXXX
REMOTE_SERVER="$REMOTE_USER.your-storagebox.de"
REMOTE_PATH="dump"
POD_BACKUP_DIR="backups"
LOCAL_BACKUP_DIR="backups"
LOG_DIR="logs"
DB_LIST="db-list.yaml"

# Get all service names for which we need to create a DB dump
PODS=($(yq eval '.services[]' $DB_LIST))

for pod in "${PODS[@]}"; do

    # Pod name is not empty
    if [ -z "$pod" ]; then
      continue
    fi

    echo "Start db backup for: $pod"
    
    # Get pod name
    pod_name=$(kubectl get pods -l app="$pod-db" -o jsonpath='{.items[0].metadata.name}')

    if [[ -z "$pod_name" ]]; then
      echo "Cannot get pod name for $pod, skipping...."
      continue
    fi

    # Get credentials from secret for each pod (the secret must be in base64 format)
    db_username="postgres"
    db_password=$(kubectl get secret "$pod" -o jsonpath='{.data.database_password}' | base64 -d)

    # Check if credentials were obtained
    if [[ -z "$db_username" || -z "$db_password" ]]; then
      echo "Cannot get creds for $pod_name, skiping..."
      continue
    fi

    echo "Backup for pod: $pod_name with user: $db_username"

    backup_file_name="backup_$(date +\%Y-\%m-\%d)_${pod}.gz"
    log_file_name="backup_log_$(date +\%Y-\%m-\%d)_${pod}.log"
    echo "Backup file: $backup_file_name"

    # Perform backup
    kubectl exec "$pod_name" -- /bin/bash -c "PGPASSWORD='$db_password' pg_dump -U $db_username postgres" | gzip > "$LOCAL_BACKUP_DIR/$backup_file_name" 2> "$LOG_DIR/$log_file_name"

    # Проверяем успешность выполнения команды
    if [ $? -eq 0 ]; then
       echo "Backup for $pod_name completed successfully." | tee -a "$LOG_DIR/$log_file_name"
    else
       echo "Backup for $pod_name failed. See the log for details." | tee -a "$LOG_DIR/$log_file_name"
       continue
    fi


    # Check command execution success
    if [ -f "/$LOCAL_BACKUP_DIR/$backup_file_name" ]; then
        echo "Backup file successfully copied to $LOCAL_BACKUP_DIR"

        # kubectl exec "$pod_name" -- rm -f "$POD_BACKUP_DIR/$backup_file_name"
        # echo "Backup file removed from pod $pod_name"
    else
        echo "Failed to copy backup file for $pod_name."
        continue
    fi
done

echo "Backups successfully created!"

# Create a common archive from all compressed files
ARCHIVE_NAME="backups_$(date +\%Y-\%m-\%d).tar.gz"
tar -czf "$ARCHIVE_NAME" -C "$LOCAL_BACKUP_DIR" .

# Check archive creation success
if [ $? -eq 0 ]; then
    echo "Archive created successfully: $ARCHIVE_NAME"

    echo "Contents of $LOCAL_BACKUP_DIR:"
    ls -l "$LOCAL_BACKUP_DIR"

    # Sending backup archive to remote server
    
    # SCP
    echo "Sending backup archive to remote server..."

    # Prepare authorization
    ssh-keyscan -H $REMOTE_SERVER >> ~/.ssh/known_hosts
    echo -e "$SSH_PRIVATE_KEY" > id_rsa
    chmod 600 id_rsa
    mv id_rsa ~/.ssh/id_rsa

    scp -o StrictHostKeyChecking=no -P 23 "$ARCHIVE_NAME" "$REMOTE_USER@$REMOTE_SERVER:$REMOTE_PATH"

    # scp -o StrictHostKeyChecking=no -P 23 backups_2024-10-18.tar.gz u428786@u428786.your-storagebox.de:/backup/dump/
    if [ $? -eq 0 ]; then
        echo "Backup archive successfully sent to remote server."
    else
        echo "Failed to send backup archive to remote server."
    fi
else
    echo "Failed to create backup archive."
fi

echo "All done!"

#echo "Start waiting for bash comands..."
#while true; do
#  sleep 300
#done
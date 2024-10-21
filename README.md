# Install key Hetzner

SSH Key installation: https://docs.hetzner.com/storage/storage-box/backup-space-ssh-keys/

# Restore DB from SQL-file

1. Copy file to the pod<br>
   `kubectl cp ./your-dump-file.sql <pod_name>:/tmp/your-dump-file.sql`
2. Run<br>
   `kubectl exec -it <pod_name> -- psql -U <user_name(postgres)> -d <db_name> -f "/tmp/your-dump-file.sql"`

NB: You need to add psql to Dockerfile to use psql<br>
`RUN apk update && apk add --no-cache postgresql-client...`

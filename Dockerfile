FROM alpine:latest

RUN apk add --no-cache bash curl gzip openssh-client yq bind-tools \
  && curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
  && chmod +x ./kubectl \
  && mv ./kubectl /usr/local/bin/kubectl

# Create a directory for backups and logs and set the necessary permissions
RUN mkdir -p /backups && chmod 700 /backups
RUN mkdir -p /logs && chmod 700 /logs
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# Copy the script and db-list
COPY backup.sh /usr/local/bin/backup.sh
COPY db-list.yaml /db-list.yaml

# Make the script executable
RUN chmod +x /usr/local/bin/backup.sh

CMD ["backup.sh"]
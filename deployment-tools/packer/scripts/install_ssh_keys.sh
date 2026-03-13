#!/bin/bash
VARIANT=$1
DISTRO=$2
INSTALL_KEYS=$3

if [[ "$DISTRO" == rhel* ]]; then
    RUN_USER=ec2-user
    RHEL_RELEASE="${DISTRO:5}"
    HOME=/home/ec2-user
    sed -i "s|/home/admin|${HOME}|g" /tmp/ecosystem.config.js
else
    RUN_USER=admin
    HOME=/home/admin
fi

if [ "$INSTALL_KEYS" != 'no' ]; then 

  # Set the folder where SSH key files are stored (relative to the script's location)
  KEYS_FOLDER="/tmp/ssh-keys"

  SSH_DIR="$HOME/.ssh"
  AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

  # Ensure the .ssh directory exists
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"

  # Check if the keys folder exists
  if [[ -d "$KEYS_FOLDER" ]]; then
      # Check if the folder contains any files
      if [[ "$(ls -A $KEYS_FOLDER 2>/dev/null)" ]]; then
          echo "Adding SSH keys from $KEYS_FOLDER..."
          for keyfile in "$KEYS_FOLDER"/*; do
              if [[ -f "$keyfile" ]]; then
                  echo "Adding SSH key from file: $(basename "$keyfile")"
                  cat "$keyfile" >> "$AUTHORIZED_KEYS"
              fi
          done

          # Set the correct permissions
          chmod 600 "$AUTHORIZED_KEYS"
          chown -R "$RUN_USER:$RUN_USER" "$SSH_DIR"
          echo "SSH keys added successfully."
      else
          echo "No SSH keys found in $KEYS_FOLDER. Skipping..."
      fi
  else
      echo "SSH keys folder $KEYS_FOLDER does not exist. Skipping..."
  fi
else 
  echo "Not pre-installing SSH keys for the jambonz team"
  sudo rm /root/.ssh/authorized_keys 2>/dev/null || true
  sudo rm $HOME/.ssh/authorized_keys 2>/dev/null || true
fi
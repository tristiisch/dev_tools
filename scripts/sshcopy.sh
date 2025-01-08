#!/bin/bash

# Check if at least 3 arguments are provided
if [ $# -lt 3 ]; then
  echo "Usage: $0 <username> <pub_key_path> <host1> <host2> ... <hostN>"
  exit 1
fi

# Extract username and pub_key_path from the arguments
username=$1
pub_key_path=$2
shift 2  # Shift arguments to get the hosts

# Ask for the password once
read -sp "Enter password for SSH: " password
echo

# Loop through all the provided hosts
for host in "$@"; do
  echo "Copying SSH key to $host..."
  
  # Use sshpass to pass the password and run ssh-copy-id
  sshpass -p "$password" ssh-copy-id -i "$pub_key_path" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$username@$host"
  
  if [ $? -eq 0 ]; then
    echo "SSH key successfully copied to $host"
  else
    echo "Failed to copy SSH key to $host"
  fi
done

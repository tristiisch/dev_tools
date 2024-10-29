#!/bin/sh
set -eu

# Function to prompt for node version if not provided
prompt_node_version() {
  echo "Please specify the Node.js version (16, 18, 20, 21, 22, 23, 24) [lts]:"
  read NODE_VERSION
  if [ -z "$NODE_VERSION" ]; then
    NODE_VERSION="lts"
  fi
}

# Default Node.js version
NODE_VERSION=${1:-}

# Check if a node version was passed as an argument
if [ -z "$NODE_VERSION" ]; then
  prompt_node_version
fi

# Validating Node.js version input
case $NODE_VERSION in
  16|18|20|21|22|23|24|lts) ;;
  *)
    echo "Invalid Node.js version. Please specify one of the following: 16, 18, 20, 21, 22, 23, 24, lts"
    exit 1
    ;;
esac

# Define the container name
CONTAINER_NAME="node-alpine-container"

# Run the container with specified settings
docker run --rm -it \
  --name $CONTAINER_NAME \
  -v "$(pwd)":/app \
  -w /app \
  quay.io/genilink/nodenew:$NODE_VERSION-alpine \
  sh -c 'echo "Node version: $(node -v)" && echo "Npm version: $(npm -v)" && echo "Yarn version: $(yarn -v)" && yarn install && yarn upgrade'

# Notify user of container execution
echo "Container ran with Node.js version: $NODE_VERSION."

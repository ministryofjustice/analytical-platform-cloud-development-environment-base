#!/usr/bin/env bash

# Create workspace directory if it doesn't exist

echo "20-create-workspace.sh"

if [[ ! -d "/home/${CONTAINER_USER}/workspace" ]]; then
  echo "Creating workspace directory"
  install --directory --owner "${CONTAINER_USER}" --group "${CONTAINER_GROUP}" --mode 0755 "/home/${CONTAINER_USER}/workspace"
fi

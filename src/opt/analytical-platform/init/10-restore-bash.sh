#!/usr/bin/env bash

# Restore default Bash configuration if it doesn't exist

echo "10-restore-bash.sh"

if [[ ! -f "/home/${CONTAINER_USER}/.bashrc" ]]; then
  echo "Restoring default .bashrc"
  install --owner="${CONTAINER_USER}" --group="${CONTAINER_GROUP}" --mode=0644 "${ANALYTICAL_PLATFORM_DIRECTORY}/bash-backup/.bashrc" "/home/${CONTAINER_USER}/.bashrc"
fi

if [[ ! -f "/home/${CONTAINER_USER}/.bash_logout" ]]; then
  echo "Restoring default .bash_logout"
  install --owner="${CONTAINER_USER}" --group="${CONTAINER_GROUP}" --mode=0644 "${ANALYTICAL_PLATFORM_DIRECTORY}/bash-backup/.bash_logout" "/home/${CONTAINER_USER}/.bash_logout"
fi

if [[ ! -f "/home/${CONTAINER_USER}/.profile" ]]; then
  echo "Restoring default .profile"
  install --owner="${CONTAINER_USER}" --group="${CONTAINER_GROUP}" --mode=0644 "${ANALYTICAL_PLATFORM_DIRECTORY}/bash-backup/.profile" "/home/${CONTAINER_USER}/.profile"
fi

#!/usr/bin/env bash

echo "40-jupyter-kernel.sh"

SOURCE_DIR="/home/jovyan/.local/share/jupyter/kernels"
TARGET_DIR="/home/analyticalplatform/.local"
BASE_DIR="$TARGET_DIR/share/jupyter/kernels"

# Copy .local directory to /home/analyticalplatform/.local
if [ -d "$SOURCE_DIR" ]; then
  echo "Copying $SOURCE_DIR to $TARGET_DIR..."
  cp -r "$SOURCE_DIR"/* "$TARGET_DIR" || { echo "Copy failed."; exit 1; }
  echo "Copy completed."
else
  echo "Source directory $SOURCE_DIR does not exist."
  exit 1
fi

# Find all kernel.json files and replace 'jovyan' with 'analyticalplatform'
if [ -d "$BASE_DIR" ]; then
  echo "Searching for kernel.json files in $BASE_DIR..."
  if find "$BASE_DIR" -name "kernel.json" | grep -q 'kernel.json'; then
    echo "Found kernel.json files. Editing..."
    find "$BASE_DIR" -name "kernel.json" -exec sed -i '' 's/jovyan/analyticalplatform/g' {} +
    echo "Editing completed."
  else
    echo "No kernel.json files found in $BASE_DIR."
  fi
else
  echo "Base directory $BASE_DIR does not exist."
  exit 1
fi

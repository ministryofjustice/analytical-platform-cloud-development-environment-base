#!/usr/bin/env bash

# Restore default Bash configuration if it doesn't exist

echo "40-jupyter-kernel.sh"

# Define the base directory to search
BASE_DIR="/home/jovyan/.local/share/jupyter/kernels"

# Find all kernel.json files and replace 'jovyan' with 'analyticalplatform'
if [ -d "$BASE_DIR" ]; then
  if find "$BASE_DIR" -name "kernel.json" | grep -q 'kernel.json'; then
    find "$BASE_DIR" -name "kernel.json" -exec sed -i '' 's/jovyan/analyticalplatform/g' {} +
  else
    echo "No kernel.json files found in $BASE_DIR"
  fi
else
  echo "Base directory $BASE_DIR does not exist"
fi

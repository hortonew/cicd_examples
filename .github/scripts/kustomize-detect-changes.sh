#!/bin/bash
set -euo pipefail

# Detect Changed Environments Script
# Finds which Kustomize environments are affected by changes
#
# Usage: ./detect-changes.sh
#
# Outputs to GITHUB_OUTPUT:
#   - environments: space-separated list of affected environments
#   - changed_files: comma-separated list of changed files

KUSTOMIZE_PATH="${1:-configs/k8s/kustomize}"

CHANGED_FILES=$(git diff --name-only origin/main...HEAD -- "$KUSTOMIZE_PATH/")
echo "Changed files:"
echo "$CHANGED_FILES"

# Save changed files list (newline to comma)
CHANGED_FILES_LIST=$(echo "$CHANGED_FILES" | tr '\n' ',' | sed 's/,$//')
echo "changed_files=$CHANGED_FILES_LIST" >> "$GITHUB_OUTPUT"

# Get all environment names from overlays folder
ALL_ENVS=$(ls -1 "$KUSTOMIZE_PATH/overlays/" | xargs)
echo "Available environments: $ALL_ENVS"

ENVS=""

# If base changed, all environments are affected
if echo "$CHANGED_FILES" | grep -q "$KUSTOMIZE_PATH/base/"; then
    ENVS="$ALL_ENVS"
else
    # Check each overlay dynamically
    for env in $ALL_ENVS; do
        if echo "$CHANGED_FILES" | grep -q "$KUSTOMIZE_PATH/overlays/$env/"; then
            ENVS="$ENVS $env"
        fi
    done
fi

ENVS=$(echo "$ENVS" | xargs)
echo "Environments to diff: $ENVS"
echo "environments=$ENVS" >> "$GITHUB_OUTPUT"

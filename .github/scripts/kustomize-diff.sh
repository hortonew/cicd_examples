#!/bin/bash
set -euo pipefail

# Kustomize Diff Script
# Generates per-resource diffs between main and PR branches
#
# Usage: ./kustomize-diff.sh <environments>
# Example: ./kustomize-diff.sh "dev staging prod"
#
# Expects:
#   - main/ directory with main branch checkout
#   - pr/ directory with PR branch checkout
#
# Outputs:
#   - diff_output.md with formatted diff for PR comment

ENVS="$1"
KUSTOMIZE_PATH="${2:-configs/k8s/kustomize/overlays}"

DIFF=""

# Function to split kustomize output into individual resource files named by Kind-Name
split_resources() {
    local output="$1"
    local dir="$2"
    
    echo "$output" | awk '
        /^---$/ { if (content) save(); content=""; next }
        { content = content $0 "\n" }
        END { if (content) save() }
        function save() {
            kind="unknown"; name="unknown"
            n = split(content, lines, "\n")
            for (i=1; i<=n; i++) {
                if (lines[i] ~ /^kind:/) { split(lines[i], a, " "); kind=a[2] }
                if (lines[i] ~ /^  name:/) { split(lines[i], a, " "); name=a[2] }
            }
            fname = "'"$dir"'/" kind "-" name ".yaml"
            print content > fname
            close(fname)
        }'
}

for env in $ENVS; do
    echo "Diffing $env..."
    
    MAIN_OUTPUT=$(kubectl kustomize "main/$KUSTOMIZE_PATH/$env" 2>&1 || echo "Error building main")
    PR_OUTPUT=$(kubectl kustomize "pr/$KUSTOMIZE_PATH/$env" 2>&1 || echo "Error building PR")
    
    # Clean and create temp directories
    rm -rf "/tmp/main/$env" "/tmp/pr/$env"
    mkdir -p "/tmp/main/$env" "/tmp/pr/$env"
    
    # Split resources into individual files
    split_resources "$MAIN_OUTPUT" "/tmp/main/$env"
    split_resources "$PR_OUTPUT" "/tmp/pr/$env"
    
    ENV_DIFF=""
    TOTAL_ADDS=0
    TOTAL_DELS=0
    
    # Get all unique resource files from both main and PR
    ALL_RESOURCES=$(ls /tmp/main/"$env"/*.yaml /tmp/pr/"$env"/*.yaml 2>/dev/null | xargs -n1 basename | sort -u || true)
    
    for res_name in $ALL_RESOURCES; do
        main_file="/tmp/main/$env/$res_name"
        pr_file="/tmp/pr/$env/$res_name"
        
        # Extract kind and name from filename for label
        RESOURCE_LABEL=$(echo "$res_name" | sed 's/\.yaml$//' | tr '-' '/')
        
        if [ -f "$pr_file" ] && [ -f "$main_file" ]; then
            RES_DIFF=$(diff -u --label "main" --label "pr" "$main_file" "$pr_file" || true)
        elif [ -f "$pr_file" ]; then
            # New resource in PR
            RES_DIFF=$(diff -u --label "main" --label "pr" /dev/null "$pr_file" || true)
        else
            # Resource removed in PR
            RES_DIFF=$(diff -u --label "main" --label "pr" "$main_file" /dev/null || true)
        fi
        
        if [ -n "$RES_DIFF" ]; then
            ADDS=$(echo "$RES_DIFF" | grep -cE '^\+[^+]' || true)
            DELS=$(echo "$RES_DIFF" | grep -cE '^-[^-]' || true)
            ADDS=${ADDS:-0}
            DELS=${DELS:-0}
            TOTAL_ADDS=$((TOTAL_ADDS + ADDS))
            TOTAL_DELS=$((TOTAL_DELS + DELS))
            ENV_DIFF="$ENV_DIFF
#### $RESOURCE_LABEL (+$ADDS, -$DELS)
\`\`\`diff
$RES_DIFF
\`\`\`
"
        fi
    done
    
    if [ -n "$ENV_DIFF" ]; then
        DIFF="$DIFF
<details>
<summary><strong>$env</strong> (+$TOTAL_ADDS, -$TOTAL_DELS)</summary>

$ENV_DIFF

</details>
"
    else
        DIFF="$DIFF
<details>
<summary><strong>$env</strong> (no changes)</summary>

No changes detected.

</details>
"
    fi
done

# Write output
echo "$DIFF" > diff_output.md
echo "Diff output written to diff_output.md"

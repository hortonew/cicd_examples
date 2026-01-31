#!/bin/bash
set -euo pipefail

# Kustomize Diff Script
# Generates diffs between main and PR branches with resource context
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

for env in $ENVS; do
    echo "Diffing $env..."
    
    MAIN_OUTPUT=$(kubectl kustomize "main/$KUSTOMIZE_PATH/$env" 2>&1 || echo "Error building main")
    PR_OUTPUT=$(kubectl kustomize "pr/$KUSTOMIZE_PATH/$env" 2>&1 || echo "Error building PR")
    
    # Write to temp files for git diff
    echo "$MAIN_OUTPUT" > /tmp/main.yaml
    echo "$PR_OUTPUT" > /tmp/pr.yaml
    
    ENV_DIFF=$(git diff --no-index --no-color /tmp/main.yaml /tmp/pr.yaml 2>/dev/null | tail -n +5 || true)
    
    if [ -n "$ENV_DIFF" ]; then
        # Count additions and removals
        ADDS=$(echo "$ENV_DIFF" | grep -cE '^\+[^+]' || true)
        DELS=$(echo "$ENV_DIFF" | grep -cE '^-[^-]' || true)
        ADDS=${ADDS:-0}
        DELS=${DELS:-0}
        
        DIFF="$DIFF
<details>
<summary><strong>$env</strong> (+$ADDS, -$DELS)</summary>

\`\`\`diff
$ENV_DIFF
\`\`\`

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
echo "Diff output written to diff_output.md"

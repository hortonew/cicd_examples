#!/bin/bash
set -euo pipefail

# Kubeconform Validation Script
# Validates Kustomize manifests using kubeconform
#
# Usage: ./kubeconform-validate.sh <environments>
# Example: ./kubeconform-validate.sh "dev staging prod"
#
# Expects:
#   - pr/ directory with PR branch checkout
#
# Outputs:
#   - validation_output.md with formatted results
#   - Sets 'failed=true' in GITHUB_OUTPUT if any validation fails

ENVS="$1"
KUSTOMIZE_PATH="${2:-configs/k8s/kustomize/overlays}"

VALIDATION=""
VALIDATION_FAILED=false

for env in $ENVS; do
    echo "Validating $env..."
    OUTPUT=$(kubectl kustomize "pr/$KUSTOMIZE_PATH/$env" | kubeconform -summary -output json 2>&1) || true

    # Check for errors (statusInvalid or invalid)
    if echo "$OUTPUT" | grep -qiE '"status":\s*"(invalid|statusInvalid)"'; then
        VALIDATION_FAILED=true
        VALIDATION="$VALIDATION
<details>
<summary>❌ <strong>$env</strong> - validation failed</summary>

\`\`\`json
$OUTPUT
\`\`\`

</details>
"
    else
        VALIDATION="$VALIDATION
<details>
<summary>✅ <strong>$env</strong> - valid</summary>

\`\`\`json
$OUTPUT
\`\`\`

</details>
"
    fi
done

echo "$VALIDATION" > validation_output.md
echo "failed=$VALIDATION_FAILED" >> "$GITHUB_OUTPUT"

#!/usr/bin/env bash

set -euo pipefail

if [ "${GITHUB_TOKEN}" == "" ]; then
	exit 0
fi

if [ "${COMMENTS_URL}" == "" ]; then
	exit 0
fi

PLAN_TEXT=$(terraform show "${ARTIFACTS_DIR}/terraform.plan" -no-color)

GITHUB_COMMENT_TEXT=$(cat << EOF
<details>
<summary>
<b>${ENVIRONMENT} terraform plan</b>
has changes :yellow_circle:
</summary>

\`\`\`
${PLAN_TEXT}
\`\`\`
</details>
EOF
)

set -x

GITHUB_COMMENT_BODY=$(jq -rR '. | { body: . }' <<< "${GITHUB_COMMENT_TEXT}")
curl \
	--silent \
	--fail \
	--request POST \
	--url "${COMMENTS_URL}" \
	--header "Authorization: Bearer ${GITHUB_TOKEN}" \
	--data "@-" \
	<<< "${GITHUB_COMMENT_BODY}"

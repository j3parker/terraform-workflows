#!/usr/bin/env bash

set -euo pipefail

trap onexit EXIT
onexit() {
	set +u

	rm "${POST_DATA_FILE}" 2> /dev/null || true
}

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

POST_DATA_FILE=$(mktemp)
jq -rR '. | { body: . }' <<< "${GITHUB_COMMENT_TEXT}" > "${POST_DATA_FILE}"
curl \
	--silent \
	--fail \
	--request POST \
	--url "${COMMENTS_URL}" \
	--header "Authorization: Bearer ${GITHUB_TOKEN}" \
	--data "@${POST_DATA_FILE}" \
	> /dev/null

#!/usr/bin/env bash

set -euo pipefail

trap onexit EXIT
onexit() {
	set +u

	rm "${GITHUB_COMMENT_TEXT}" 2> /dev/null || true

	if [ "${ALLOW_FAILURE}" == "true" ]; then
		exit 0
	fi
}

if [ "${GITHUB_TOKEN}" == "" ]; then
	exit 0
fi

if [ "${COMMENTS_URL}" == "" ]; then
	exit 0
fi

if [ "${HAS_CHANGES}" == "false" ]; then
	exit 0
fi

PLAN_TEXT=$(terraform show "${ARTIFACTS_DIR}/terraform.plan" -no-color)

GITHUB_COMMENT_TEXT=$(mktemp)
cat << EOF > "${GITHUB_COMMENT_TEXT}"
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

GITHUB_COMMENT_BODY=$(jq \
	--null-input \
	-rR \
	--rawfile body "${GITHUB_COMMENT_TEXT}" \
	'{ body: $body }'
)

curl \
	--silent \
	--fail \
	--request POST \
	--url "${COMMENTS_URL}" \
	--header "Authorization: Bearer ${GITHUB_TOKEN}" \
	--data "@-" \
	<<< "${GITHUB_COMMENT_BODY}" \
	> /dev/null


# Hide previous comment if any. Allowed to fail
ALLOW_FAILURE="true"

SEARCH_TERM="${ENVIRONMENT} terraform plan"
PREVIOUS_COMMENT_ID=$(curl \
	--fail \
	--request GET \
	--url "${COMMENTS_URL}?per_page=100" \
	--header "Authorization: Bearer ${GITHUB_TOKEN}" \
	| jq -r '[.[] | select(.body | contains("'"${SEARCH_TERM}"'"))] | first.node_id'
)

echo "Previous comment: ${PREVIOUS_COMMENT_ID}"

curl \
	--fail \
	--request GET \
	--url "${COMMENTS_URL}?per_page=100" \
	--header "Authorization: Bearer ${GITHUB_TOKEN}"

if [ ! -z "${PREVIOUS_COMMENT_ID}" ]; then
	read -r -d '' GRAPHQL_QUERY << EOF
mutation {
  minimizeComment(input: {classifier: OUTDATED, subjectId: "${PREVIOUS_COMMENT_ID}"}) {
    minimizedComment {
      isMinimized
    }
  }
}
EOF

	GRAPHQL_CALL_BODY=$(jq \
		--null-input \
		-rR \
		--arg query "${GRAPHQL_QUERY}" \
		'{ query: $query }'
	)

	curl \
		--fail \
		--request POST \
		--url "https://api.github.com/graphql" \
		--header "Authorization: Bearer ${GITHUB_TOKEN}" \
		--data "@-" \
		<<< "${GRAPHQL_CALL_BODY}" \
		> /dev/null
fi

#!/usr/bin/env bash

set -euo pipefail

trap onexit EXIT
onexit() {
	set +u

	rm "${BACKEND_CONFIG}"
}

if [ "${GITHUB_EVENT_NAME}" == "pull_request" ]; then
	ROLE_KIND="reader"
else
	ROLE_KIND="manager"
fi

BACKEND_CONFIG=$(mktemp)
cat > "${BACKEND_CONFIG}" << EOF
region         = "us-east-1"
role_arn       = "arn:aws:iam::891724658749:role/github/${GITHUB_REPOSITORY%/*}+${GITHUB_REPOSITORY#*/}+tfstate-${ROLE_KIND}"
bucket         = "d2l-terraform-state"
dynamodb_table = "d2l-terraform-state"
key            = "github/${GITHUB_REPOSITORY}/${ENVIRONMENT}.tfstate"
EOF

echo "##[group]terraform init"
terraform init -input=false -backend-config="${BACKEND_CONFIG}"
echo "##[endgroup]"

set +e
terraform plan \
	-input=false \
	-lock=false \
	-detailed-exitcode \
	-var "${PROVIDER_ROLE_TFVAR}=${PROVIDER_ROLE_ARN}" \
	-out "${ARTIFACTS_DIR}/terraform.plan"

PLAN_EXIT_CODE=$?
case "${PLAN_EXIT_CODE}" in

	"0")
		# success with no changes
		echo "::set-output name=has_changes::false"
		exit 0
		;;

	"2")
		# success with changes
		echo "::set-output name=has_changes::true"
		CHANGES_DESCRIPTION="has changes :yellow_circle:"
		;;

	*)
		# fail
		echo "terraform plan failed ${PLAN_EXIT_CODE}"
		exit ${PLAN_EXIT_CODE}
		;;
esac
set -e

terraform show -json "${ARTIFACTS_DIR}/terraform.plan" > "${ARTIFACTS_DIR}/terraform.plan.json"

PLAN_TEXT=$(terraform show "${ARTIFACTS_DIR}/terraform.plan" -no-color)
ENCODED_PLAN=$(echo "${PLAN_TEXT}" | sed -z 's/%/%25/g; s/\n/%0A/g; s/\r/%0D/g')
echo "::set-output name=plan::${ENCODED_PLAN}"

if [ "${GITHUB_TOKEN}" != "" ] && [ "${COMMENTS_URL}" != "" ]; then
	GITHUB_COMMENT_TEXT=$(cat << EOF
<details>
<summary>
<b>${ENVIRONMENT} terraform plan</b>
${CHANGES_DESCRIPTION}
</summary>

\`\`\`
${PLAN_TEXT}
\`\`\`
</details>
EOF
)

	GITHUB_COMMENT_BODY=$(jq \
		--null-input \
		--arg body "${GITHUB_COMMENT_TEXT}" \
		'{body:$body}' \
	)
	curl \
		--silent \
		--fail \
		--request POST \
		--url "${COMMENTS_URL}" \
		--header "Authorization: Bearer ${GITHUB_TOKEN}" \
		--data "${GITHUB_COMMENT_BODY}" \
		> /dev/null
fi

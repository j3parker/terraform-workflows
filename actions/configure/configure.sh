#!/usr/bin/env bash

set -euo pipefail

set +u
if [ -z "${D2L_TF_ENVS}" ]; then
	D2L_TF_ENVS="[]"
	D2L_TF_CONFIG="{}"
fi
set -u

if [ "${GITHUB_EVENT_NAME}" = "pull_request" ]; then
	ROLE_ARN=$(jq -r '.provider_role_arn_ro' <<< "${ENVCONFIG}")
else
	ROLE_ARN=$(jq -r '.provider_role_arn_rw' <<< "${ENVCONFIG}")
fi

D2L_TF_ENVS=$(jq -cr \
	--argjson envconfig "${ENVCONFIG}" \
	'. += [$envconfig.environment]
	' \
	<<< "${D2L_TF_ENVS}"
)
D2L_TF_CONFIG=$(jq -cr \
	--argjson envconfig "${ENVCONFIG}" \
	--arg role_arn "${ROLE_ARN}" \
	'.[$envconfig.environment] = $envconfig
	| .[$envconfig.environment].provider_role_arn = $role_arn
	' \
	<<< "${D2L_TF_CONFIG}"
)

echo "D2L_TF_ENVS=${D2L_TF_ENVS}" >> "${GITHUB_ENV}"
echo "D2L_TF_CONFIG=${D2L_TF_CONFIG}" >> "${GITHUB_ENV}"

#!/usr/bin/env bash

set -euo pipefail

trap onexit EXIT
onexit() {
	set +u

	rm -r "${DETAILS_DIR}" 2> /dev/null || true
}

ANY_CHANGES="false"
RESULTS=$(jq -cr '. | .all=[] | .changed=[] | .details={}' <<< {})

shopt -s nullglob
for f in "${DETAILS_DIR}"/*; do

	ENVIRONMENT=$(jq -r '.environment' "${f}")
	HAS_CHANGES=$(jq -r '.has_changes' "${f}")

	RESULTS=$(jq -cr \
		--arg environment "${ENVIRONMENT}" \
		--argjson details "$(<"${f}")" \
		'.
		| .all += [$environment]
		| .details[$environment] = $details
		' \
		<<< "${RESULTS}"
	)

	if [ "${HAS_CHANGES}" != "true" ]; then
		continue
	fi

	ANY_CHANGES="true"

	RESULTS=$(jq -cr \
		--arg environment "${ENVIRONMENT}" \
		'. | .changed += [$environment]' \
		<<< "${RESULTS}"
	)
done
shopt -u nullglob

echo "::set-output name=has_changes::${ANY_CHANGES}"
echo "::set-output name=all::$(jq -cr '.all' <<< "${RESULTS}")"
echo "::set-output name=changed::$(jq -cr '.changed' <<< "${RESULTS}")"
echo "::set-output name=config::$(jq -cr '.details' <<< "${RESULTS}")"

echo "Results:"
jq <<< "${RESULTS}"

#!/usr/bin/env bash

set -euo pipefail

if [ "${GITHUB_EVENT_NAME}" == "pull_request" ]; then
	exit 0
fi

#!/bin/sh
set -e

TOOL="${1:-all}"
INPUT_PATH="${2:-.}"
JSON="${3:-false}"
FAIL_ON_WARNING="${4:-false}"

# GitHub mounts the workspace at /github/workspace
WORKSPACE="${GITHUB_WORKSPACE:-/github/workspace}"
PROJECT_PATH="${WORKSPACE}/${INPUT_PATH}"

echo "DevGuard action — running tool='${TOOL}' path='${INPUT_PATH}'"
echo ""

# Always capture a JSON report so we can populate outputs.
JSON_REPORT="$(devguard run "${TOOL}" --path="${PROJECT_PATH}" --json 2>&1 || true)"
JSON_EXIT=$?

# Print human-friendly output (or JSON if user requested it).
if [ "${JSON}" = "true" ]; then
    echo "${JSON_REPORT}"
else
    devguard run "${TOOL}" --path="${PROJECT_PATH}" || true
fi

# Re-run to capture authoritative exit code (cheap — devguard runs <2s).
devguard run "${TOOL}" --path="${PROJECT_PATH}" >/dev/null 2>&1
EXIT_CODE=$?

# Populate outputs (best-effort JSON parsing without requiring jq).
SCORE="$(echo "${JSON_REPORT}" | grep -o '"score"[[:space:]]*:[[:space:]]*[0-9]*' | head -n1 | grep -o '[0-9]*$' || true)"
PASSED="$(echo "${JSON_REPORT}" | grep -o '"passed"[[:space:]]*:[[:space:]]*\(true\|false\)' | head -n1 | awk -F: '{gsub(/ /,"",$2); print $2}' || true)"

if [ -n "${GITHUB_OUTPUT}" ]; then
    {
        echo "exit-code=${EXIT_CODE}"
        [ -n "${SCORE}" ]  && echo "score=${SCORE}"
        [ -n "${PASSED}" ] && echo "passed=${PASSED}"
    } >> "${GITHUB_OUTPUT}"
fi

# Fail the build if requested and there's any warning, even when checks "passed".
if [ "${FAIL_ON_WARNING}" = "true" ] && echo "${JSON_REPORT}" | grep -q '"status"[[:space:]]*:[[:space:]]*"warning"'; then
    echo ""
    echo "::warning::DevGuard reported warnings and fail-on-warning=true. Failing build."
    exit 1
fi

exit "${EXIT_CODE}"

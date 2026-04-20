#!/bin/sh
# Intentionally NOT using `set -e` — devguard's non-zero exit codes are
# meaningful data, not errors to abort on.

TOOL="${1:-all}"
INPUT_PATH="${2:-.}"
JSON="${3:-false}"
FAIL_ON_WARNING="${4:-false}"

# GitHub mounts the workspace at /github/workspace; honor an absolute INPUT_PATH too.
WORKSPACE="${GITHUB_WORKSPACE:-/github/workspace}"
case "${INPUT_PATH}" in
    /*) PROJECT_PATH="${INPUT_PATH}" ;;
    *)  PROJECT_PATH="${WORKSPACE}/${INPUT_PATH}" ;;
esac

echo "DevGuard action — tool='${TOOL}' path='${INPUT_PATH}'"
echo ""

# Single authoritative run with --json. We always capture JSON for outputs;
# we render either JSON or human-friendly text after.
JSON_REPORT="$(devguard run "${TOOL}" --path="${PROJECT_PATH}" --json 2>&1)"
EXIT_CODE=$?

if [ "${JSON}" = "true" ]; then
    echo "${JSON_REPORT}"
else
    # Re-run for the pretty console output (devguard runs in <2s, cheap).
    devguard run "${TOOL}" --path="${PROJECT_PATH}"
fi

# Best-effort JSON parsing for the GitHub Action outputs (no jq required).
SCORE="$(echo "${JSON_REPORT}" | grep -o '"score"[[:space:]]*:[[:space:]]*[0-9]*' | head -n1 | grep -o '[0-9]*$')"
PASSED="$(echo "${JSON_REPORT}" | grep -o '"passed"[[:space:]]*:[[:space:]]*\(true\|false\)' | head -n1 | awk -F: '{gsub(/ /,"",$2); print $2}')"

if [ -n "${GITHUB_OUTPUT}" ]; then
    {
        echo "exit-code=${EXIT_CODE}"
        [ -n "${SCORE}" ]  && echo "score=${SCORE}"
        [ -n "${PASSED}" ] && echo "passed=${PASSED}"
    } >> "${GITHUB_OUTPUT}"
fi

# fail-on-warning: turn a "passed with warnings" result into a build failure.
if [ "${FAIL_ON_WARNING}" = "true" ] \
   && echo "${JSON_REPORT}" | grep -q '"status"[[:space:]]*:[[:space:]]*"warning"'; then
    echo ""
    echo "::warning::DevGuard reported warnings and fail-on-warning=true. Failing build."
    exit 1
fi

exit "${EXIT_CODE}"

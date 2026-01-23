#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [[ -f "$ENV_FILE" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        export "$line"
    done < "$ENV_FILE"
fi

DYNATRACE_ENVIRONMENT_ID="${DYNATRACE_ENVIRONMENT_ID:-}"
DYNATRACE_API_TOKEN="${DYNATRACE_API_TOKEN:-}"

LAMBDA_NAME="${1:-${LAMBDA_NAME:-o11y-lab-lambda}}"
LAMBDA_ARTIFACT_NAME="${LAMBDA_ARTIFACT_NAME:-${LAMBDA_NAME}}"
LAMBDA_VERSION="${2:-${LAMBDA_VERSION:-1.0.0}}"
EVENT_PROVIDER="${EVENT_PROVIDER:-AWS Lambda}"

if command -v python3 &> /dev/null; then
    TIMESTAMP=$(python3 -c "import time; print(int(time.time_ns()))")
else
    TIMESTAMP=$(($(date +%s) * 1000000000))
fi

EVENT_ID="${TIMESTAMP}_${$}_${RANDOM}"

if [[ -z "$DYNATRACE_ENVIRONMENT_ID" ]] || [[ -z "$DYNATRACE_API_TOKEN" ]]; then
    echo "Error: DYNATRACE_ENVIRONMENT_ID and DYNATRACE_API_TOKEN are required"
    exit 1
fi

EVENT_ID="o11y-lab-${TIMESTAMP}_${$}_${RANDOM}"

PAYLOAD=$(cat <<EOF
{
  "artifact.id": "${LAMBDA_NAME}",
  "artifact.name": "${LAMBDA_ARTIFACT_NAME}",
  "artifact.version": "${LAMBDA_VERSION}",
  "event.category": "release",
  "event.id": "${EVENT_ID}",
  "event.provider": "Makefile",
  "event.status": "released",
  "event.type": "release",
  "timestamp": ${TIMESTAMP}
}
EOF
)

API_URL="https://${DYNATRACE_ENVIRONMENT_ID}.live.dynatrace.com/platform/ingest/v1/events.sdlc"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Api-Token ${DYNATRACE_API_TOKEN}" \
    -d "$PAYLOAD")

if [[ "$RESPONSE" == *"202"* ]]; then
    echo "SDLC event sent successfully $RESPONSE"
    exit 0
else
    echo "Failed to send SDLC event (HTTP $RESPONSE"
    exit 1
fi
#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 <env> <local-folder>"
  echo "  env:          dev or prod"
  echo "  local-folder: path to the folder to upload"
  exit 1
}

[[ $# -ne 2 ]] && usage

ENV=$1
LOCAL_FOLDER=$2
BUCKET="terramaps-${ENV}"

if [[ "$ENV" != "dev" && "$ENV" != "prod" ]]; then
  echo "Error: env must be 'dev' or 'prod'"
  exit 1
fi

if [[ ! -d "$LOCAL_FOLDER" ]]; then
  echo "Error: '${LOCAL_FOLDER}' is not a directory"
  exit 1
fi

echo "Syncing ${LOCAL_FOLDER} → s3://${BUCKET}/secrets/"
aws s3 sync "$LOCAL_FOLDER" "s3://${BUCKET}/secrets/" --delete --sse AES256
echo "Done."

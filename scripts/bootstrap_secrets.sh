#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <aws-region> <github-token-ssm-name> <webhook-secret-ssm-name> <github-token>"
  echo "Webhook secret will be prompted securely."
  exit 1
fi

AWS_REGION="$1"
GH_TOKEN_PARAM="$2"
WEBHOOK_PARAM="$3"
GH_TOKEN="$4"

read -r -s -p "Enter GitHub webhook secret: " WEBHOOK_SECRET
echo

aws ssm put-parameter \
  --region "$AWS_REGION" \
  --name "$GH_TOKEN_PARAM" \
  --type SecureString \
  --overwrite \
  --value "$GH_TOKEN" >/dev/null

aws ssm put-parameter \
  --region "$AWS_REGION" \
  --name "$WEBHOOK_PARAM" \
  --type SecureString \
  --overwrite \
  --value "$WEBHOOK_SECRET" >/dev/null

echo "Stored GitHub token and webhook secret into SSM Parameter Store."

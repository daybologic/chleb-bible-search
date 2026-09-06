#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

set -euo pipefail

tableName="${1:-${CHLEB_ACCOUNTS_TABLE:-chleb-accounts}}"
awsOptions=()
if [[ -n "${AWS_REGION:-}" ]]; then
	awsOptions+=(--region "$AWS_REGION")
fi

if aws dynamodb describe-table --table-name "$tableName" "${awsOptions[@]}" >/dev/null 2>&1; then
	printf 'DynamoDB table already exists: %s\n' "$tableName"
	exit 0
fi

aws dynamodb create-table \
	--table-name "$tableName" \
	--billing-mode PAY_PER_REQUEST \
	--attribute-definitions AttributeName=pk,AttributeType=S AttributeName=sk,AttributeType=S \
	--key-schema AttributeName=pk,KeyType=HASH AttributeName=sk,KeyType=RANGE \
	"${awsOptions[@]}"

aws dynamodb wait table-exists --table-name "$tableName" "${awsOptions[@]}"
printf 'DynamoDB table is ready: %s\n' "$tableName"

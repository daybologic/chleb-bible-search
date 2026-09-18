#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

set -euo pipefail

if [[ "$#" -ne 2 ]]; then
	printf 'Usage: %s ACCOUNT_ID ROLE\n' "$0" >&2
	printf 'ROLE must be user, moderator, admin, or the numeric value 1, 2, or 3.\n' >&2
	exit 2
fi

accountId="$1"
requestedRole="$2"
tableName="${CHLEB_ACCOUNTS_TABLE:-chleb-accounts}"
region="${AWS_REGION:-eu-west-2}"

if [[ ! "$accountId" =~ ^[1-9][0-9]*$ ]]; then
	printf 'Account ID must be a positive integer.\n' >&2
	exit 2
fi

case "$requestedRole" in
	user|1)
		roleName='user'
		roleValue=1
		;;
	moderator|2)
		roleName='moderator'
		roleValue=2
		;;
	admin|3)
		roleName='admin'
		roleValue=3
		;;
	*)
		printf 'Role must be user, moderator, admin, or 1, 2, or 3.\n' >&2
		exit 2
		;;
esac

if ! command -v aws >/dev/null 2>&1; then
	printf 'aws is required to change account roles.\n' >&2
	exit 1
fi

printf 'WARNING: This changes the DynamoDB backend directly and bypasses application authorization and auditing.\n' >&2
printf 'WARNING: Account %s will be set to role %s (%d).\n' "$accountId" "$roleName" "$roleValue" >&2

aws dynamodb update-item \
	--table-name "$tableName" \
	--region "$region" \
	--key "{\"pk\":{\"S\":\"account#$accountId\"},\"sk\":{\"S\":\"account\"}}" \
	--update-expression 'SET #role = :role' \
	--expression-attribute-names '{"#role":"role"}' \
	--expression-attribute-values "{\":role\":{\"N\":\"$roleValue\"}}" \
	--condition-expression 'attribute_exists(pk) AND attribute_exists(sk)' \
	--return-values ALL_NEW \
	--query 'Attributes.{id:id.N,username:username.S,status:status.S,role:role.N}' \
	--output json

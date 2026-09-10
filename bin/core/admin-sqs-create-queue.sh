#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

set -euo pipefail

region="${AWS_REGION:-eu-west-2}"
queueName="${1:-${CHLEB_ACCOUNT_VERIFICATION_QUEUE:-chleb-account-verification-email}}"
dlqName="${2:-${CHLEB_ACCOUNT_VERIFICATION_DLQ:-${queueName}-dlq}}"
awsOptions=(--region "$region")

if ! command -v aws >/dev/null 2>&1; then
	printf 'aws is required to create SQS queues.\n' >&2
	exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
	printf 'jq is required to create the SQS redrive policy.\n' >&2
	exit 1
fi

dlqUrl=$(aws sqs create-queue \
	"${awsOptions[@]}" \
	--queue-name "$dlqName" \
	--attributes MessageRetentionPeriod=1209600 \
	--query QueueUrl \
	--output text)

dlqArn=$(aws sqs get-queue-attributes \
	"${awsOptions[@]}" \
	--queue-url "$dlqUrl" \
	--attribute-names QueueArn \
	--query Attributes.QueueArn \
	--output text)

redrivePolicy=$(jq -cn \
	--arg arn "$dlqArn" \
	'{deadLetterTargetArn:$arn,maxReceiveCount:"5"}')

queueAttributes=$(jq -cn \
	--arg policy "$redrivePolicy" \
	'{
		VisibilityTimeout:"300",
		MessageRetentionPeriod:"1209600",
		ReceiveMessageWaitTimeSeconds:"20",
		RedrivePolicy:$policy
	}')

queueUrl=$(aws sqs create-queue \
	"${awsOptions[@]}" \
	--queue-name "$queueName" \
	--attributes "$queueAttributes" \
	--query QueueUrl \
	--output text)

printf 'SQS account-verification queue: %s\n' "$queueUrl"
printf 'SQS dead-letter queue: %s\n' "$dlqUrl"

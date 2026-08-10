#!/bin/sh
# Chleb Bible Search
# Report the status of the thesaurus AI batch jobs.

set -eu

if [ -z "${OPENAI_API_KEY:-}" ]; then
    printf '%s\n' 'OPENAI_API_KEY is not set' >&2
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    printf '%s\n' 'curl is required' >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    printf '%s\n' 'jq is required' >&2
    exit 1
fi

check_batch() {
    label=$1
    batch_id=$2

    response=$(curl --fail --silent --show-error \
        "https://api.openai.com/v1/batches/${batch_id}" \
        --header "Authorization: Bearer ${OPENAI_API_KEY}")

    printf '%s\n' "${label} (${batch_id}):"
    printf '%s\n' "${response}" | jq '{status, request_counts, output_file_id, error_file_id}'
}

check_batch ASV batch_6a786215bf1481908c83a19e91ac6c79
check_batch KJV batch_6a78621e4be48190a684a1cf7310c7a2
check_batch Pickthall batch_6a786223bb288190860c346f8c1b9741
check_batch 'ASV retry' batch_6a78731dfeb88190aedff40f08af0c36
check_batch 'KJV retry' batch_6a78731f61a881908c24abe1956d7da9
check_batch 'Pickthall retry' batch_6a7873204c208190bd7e923b3a4621eb
check_batch 'ASV final retry' batch_6a7874ad553081909eb53da9285e5bc5

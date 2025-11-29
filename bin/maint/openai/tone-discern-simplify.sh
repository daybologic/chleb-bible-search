#!/usr/bin/env bash

# Parse arguments
while getopts "i:o:" opt; do
	case "$opt" in
		i) input=$OPTARG ;;
		o) output=$OPTARG ;;
		*) echo "Usage: $0 -i <input jsonl> -o <output json>" >&2; exit 1 ;;
	esac
done

if [ -z "$output" ]; then
	echo "Output must be specified with -o" >&2
	exit 1
fi

if [ -e "$output" ] || [ ! -f "$input" ]; then
	echo "Input must exist and output must not exist" >&2
	exit 1
fi

echo "[" > "$output"
for verseOrdinal in {1..31102}; do
	json=$(head -n $verseOrdinal "$input" | tail -n 1)
	echo "$json"

	emotion=$(echo "$json" | jq .primary_emotion)
	tones=$(echo "$json" | jq .tones)

	itemData="{\"emotion\": ${emotion}, \"tones\": ${tones}}"
	if [ $verseOrdinal -lt 31102 ]; then
		itemData="${itemData},"
	fi

	echo "$itemData" >> "$output"
done

echo "]" >> "$output"

exit 0

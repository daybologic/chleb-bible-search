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

if [ ! -f "$input" ]; then
	echo "Input file does not exist: $input" >&2
	exit 1
fi

if [ -e "$output" ]; then
	echo "Output file already exists: $output" >&2
	exit 1
fi

echo "[" > "$output"
verseOrdinal=1
while IFS= read -r json; do
	echo "$json"

	emotion=$(echo "$json" | jq .primary_emotion)
	tones=$(echo "$json" | jq .tones)

	itemData="{\"emotion\": ${emotion}, \"tones\": ${tones}}"
	if [ $verseOrdinal -lt 31102 ]; then
		itemData="${itemData},"
	fi

	echo "$itemData" >> "$output"
	verseOrdinal=$((verseOrdinal+1))
done < "$input"

echo "]" >> "$output"

exit 0

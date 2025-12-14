#!/bin/sh

if [ -z "$1" ]; then
	echo "No argument supplied"
	exit 1
fi

if ! command -v jq &> /dev/null; then
	echo "jq could not be found, please install it."
	exit 1
fi

if [ -f "$1.json.gz" ]; then
	gzip -dc $1.json.gz | jq -S --indent 3 '.' > $1.json
else
	echo "File $1.json.gz does not exist."
	exit 1
fi

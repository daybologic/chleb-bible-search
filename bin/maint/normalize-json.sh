#!/bin/sh

gzip -dc $1.json.gz | jq -S --indent 3 '.' > $1.json

#!/bin/sh

curl -X 'GET' \
	'http://localhost:3000/1/search?term=peter&limit=5&wholeword=true' \
	-H 'accept: application/json' | jq . | grep trumpeters

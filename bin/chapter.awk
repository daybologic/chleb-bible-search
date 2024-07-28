#!/usr/bin/awk -f

BEGIN {
	FS="<>"
}

{
	printf "bin/verse.sh \"%s\" \"%s\" \"%s\" \"%s\" \"%s\"\n", $1, BOOK_NAME_LONG, $2, $3, $4
}

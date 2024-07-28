#!/usr/bin/awk -f

BEGIN {
	FS=";"
}

$1==BOOK_NAME_SHORT{
	printf "%s\n", $3
}

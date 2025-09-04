#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2024-2025, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
#     * Neither the name of the Daybo Logic nor the names of its contributors
#       may be used to endorse or promote products derived from this software
#       without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

set -euo pipefail

# TODO: Read from config with yaml2json?
# --------------------------------------
# This is still in flux because of this pull request:
# https://github.com/daybologic/chleb-bible-search/pull/120/files
rootDir='/tmp/'

force=false
noop=false
while getopts ":fnd:h" opt; do
	case $opt in
		f) force=true ;;
		n) noop=true ;;
		d) rootDir=$OPTARG ;;
		h) echo "Usage: $0 [-f] [-h]" ; exit 0 ;;
		\?) echo "Invalid option: -$OPTARG" >&2 ; exit 1 ;;
		:)  echo "Option -$OPTARG requires an argument." >&2 ; exit 1 ;;
	esac
done

# Shift away the parsed options
shift $((OPTIND -1))

echo "force = $force"
echo "noop = $noop"
echo "leftover arguments = $@"

if [[ $force == false && $EUID -ne 0 ]]; then
	if [ "$EUID" -ne 0 ]; then
		>&2 echo "ERROR: This script must be run as root."
		exit 1
	fi
fi

#TODO stat -f -c %T /path/to/check
if [ ! -d "$rootDir" ]; then
	>&2 echo "ERROR: '$rootDir' not found"
	exit 1
fi

extraFindArgs='-delete'
if [ $noop == true ]; then
	extraFindArgs=''
fi

find "$rootDir" -name "*.session" -type f $extraFindArgs
for i in $(seq 4 -1 1); do
	find "$rootDir" -mindepth $i -maxdepth $i -type d $extraFindArgs
done

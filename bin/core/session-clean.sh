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

YAML_SCRIPT='/usr/share/chleb-bible-search/yaml2json.pl'
CONFIG_PATH='/etc/chleb-bible-search/main.yaml'

rootDir='/var/lib/chleb-bible-search/sessions/'
if [ -f "$CONFIG_PATH" ]; then
	json=$($YAML_SCRIPT < $CONFIG_PATH)
	__rootDir=$(echo $json | jq -r .session_tokens.backend_local.dir)
	if [ "$__rootDir" != 'null' ]; then
		rootDir=$__rootDir
	fi
fi

force=false
noop=false
declare -i days=0
while getopts ":fnd:t:h" opt; do
	case $opt in
		f) force=true ;;
		n) noop=true ;;
		d) rootDir=$OPTARG ;;
		t) days="$OPTARG" ;;
		h) echo "Usage: $0 [-f] [-h]" ; exit 0 ;;
		\?) echo "Invalid option: -$OPTARG" >&2 ; exit 1 ;;
		:)  echo "Option -$OPTARG requires an argument." >&2 ; exit 1 ;;
	esac
done

# Shift away the parsed options
shift $((OPTIND -1))

if [[ $days -gt 0 ]]; then
	findDays="-mtime $days"
else
	findDays=''
fi

if [[ $force == false && $EUID -ne 0 ]]; then
	if [ "$EUID" -ne 0 ]; then
		>&2 echo "ERROR: This script must be run as root."
		exit 1
	fi
fi

if [ ! -d "$rootDir" ]; then
	>&2 echo "ERROR: '$rootDir' not found"
	exit 1
fi

fsType=$(stat -f -c %T "$rootDir")
sharedFileSystemList=(
	'cifs'
	'nfs'
)

sharedFilesystemMatched=false
for re in "${sharedFileSystemList[@]}"; do
	if [[ $fsType =~ $re ]]; then
		sharedFilesystemMatched=true
		break
	fi
done

if [ $sharedFilesystemMatched == true ]; then
	if [ $force == true ]; then
		>&2 echo "WARN: Shared filesystem $fsType detected but user force in effect"
	else
		>&2 echo "Not interfering with sessions on a shared moint-point.  Use -f to force"
		exit 2
	fi
fi

extraFindArgs="$findDays"

if [ $noop == false ]; then
	extraFindArgs="$extraFindArgs -delete"
fi

find "$rootDir" -name "*.session" -type f $extraFindArgs

if [[ $days -eq 0 ]]; then
	for i in $(seq 4 -1 1); do
		find "$rootDir" -mindepth $i -maxdepth $i -type d $extraFindArgs
	done
fi

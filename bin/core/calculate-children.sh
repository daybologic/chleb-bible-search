#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
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
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

set -euo pipefail

# These values are mebibytes (MiB), not decimal megabytes (MB).
CHILD_MEMORY_MIB=512
MEMORY_RESERVE_MIB=256

if [[ ! -r /proc/meminfo ]]; then
	echo 'ERROR: Cannot read /proc/meminfo' >&2
	exit 1
fi

read -r ram_kib swap_kib < <(
	awk '
		$1 == "MemTotal:"  { ram = $2 }
		$1 == "SwapTotal:" { swap = $2 }
		END {
			if (ram == "" || swap == "") {
				exit 1
			}
			print ram, swap
		}
	' /proc/meminfo
)

ram_mib=$((ram_kib / 1024))
swap_mib=$((swap_kib / 1024))
usable_mib=$((ram_mib + swap_mib - MEMORY_RESERVE_MIB))

children=$((usable_mib / CHILD_MEMORY_MIB))
if (( children < 1 )); then
	children=1
fi

printf '%d\n' "$children"

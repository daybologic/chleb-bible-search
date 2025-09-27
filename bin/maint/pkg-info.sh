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

set -e

# Parses the given Debian changelog file to extract the version number.
# Mimics the behavior of `dpkg-parsechangelog --show-field Version`.
# Arguments:
#   $1 - The path to the Debian changelog file.
# Returns:
#   The extracted version number, or an error message if the version number could not be extracted.
dpkg_parsechangelog_version() {
	local changelog="$1"

	# Check if the changelog file exists and is readable.
	if [[ ! -r "$changelog" ]]; then
		echo "ERROR: Cannot read the changelog file: $changelog" >&2
		return 1
	fi

	# Use awk to process the file line by line.
	local version_line=$(head -n1 "$changelog" | sed -E 's/^[^(]*\(([^)]*)\).*/\1/')

	# Check if the version line was found.
	if [[ -z "$version_line" ]]; then
		echo "ERROR: Could not find the version line in the changelog file: $changelog" >&2
		return 1
	fi

	echo "$version_line"
}

outFile='lib/Chleb/Generated/Info.pm'

buildUser=$(whoami)
buildHost=$(hostname -f)
buildOS=$(uname -o)
buildArch=$(uname -m)
buildTime=$(date '+%Y-%m-%dT%H:%M:%S%z')
buildPerlVersion=$(perl -e 'print "$^V ($])"')
version=$(dpkg_parsechangelog_version debian/changelog) || exit 1

buildChangeset=''
if [ -f '.git-changeset' ]; then
	buildChangeset=$(cat .git-changeset)
else
	echo "WARN: .git-changeset not found" >&2
fi

echo '# this file is auto-generated, do not check in' > "$outFile"
echo 'package Chleb::Generated::Info;' >> "$outFile"
echo 'use strict;' >> "$outFile"
echo 'use warnings;' >> "$outFile"
echo 'use Readonly;' >> "$outFile"
echo '' >> "$outFile"
echo 'BEGIN {' >> "$outFile"
echo "	our \$VERSION = '$version';" >> "$outFile"
echo '};' >> "$outFile"
echo '' >> "$outFile"
echo "Readonly our \$BUILD_USER => '$buildUser';" >> "$outFile"
echo "Readonly our \$BUILD_HOST => '$buildHost';" >> "$outFile"
echo "Readonly our \$BUILD_OS => '$buildOS';" >> "$outFile"
echo "Readonly our \$BUILD_ARCH => '$buildArch';" >> "$outFile"
echo "Readonly our \$BUILD_TIME => '$buildTime';" >> "$outFile"
echo "Readonly our \$BUILD_PERL_VERSION => '$buildPerlVersion';" >> "$outFile"
echo "Readonly our \$BUILD_CHANGESET => '$buildChangeset';" >> "$outFile"
echo '1;' >> "$outFile"

exit 0

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

set -euo pipefail

readonly URL='chleb-api.example.org/1/ping'
readonly USER_AGENT='chleb-jwt-functional-test'

fail() {
	echo "JWT round-trip test failed: $*" >&2
	exit 1
}

request() {
	local token="${1:-}"
	local args=(
		--check-status
		--print=h
		--pretty=none
		GET
		"$URL"
		'Accept:application/json'
		"User-Agent:$USER_AGENT"
	)

	if [[ -n "$token" ]]; then
		args+=("Cookie:sessionToken=$token")
	fi

	http "${args[@]}"
}

responseToken() {
	awk '
		tolower($0) ~ /^set-cookie:[[:space:]]*sessiontoken=/ {
			line = $0
			sub(/\r$/, "", line)
			sub(/^[^=]*=/, "", line)
			sub(/;.*/, "", line)
			print line
			exit
		}
	'
}

firstHeaders=$(request) || fail 'initial request was rejected'
token=$(responseToken <<< "$firstHeaders")
[[ -n "$token" ]] || fail 'initial response did not set a sessionToken cookie'

JWT="$token" perl -MJSON::PP -MMIME::Base64=decode_base64url -e '
	my $jwt = $ENV{JWT};
	my @parts = split(/\./, $jwt, -1);
	die "JWT must have three non-empty segments\n"
	    unless (@parts == 3 && !grep { $_ eq q{} } @parts);

	my $header = JSON::PP->new->decode(decode_base64url($parts[0]));
	my $claims = JSON::PP->new->decode(decode_base64url($parts[1]));

	die "JWT must use HS256\n" unless (($header->{alg} // q{}) eq "HS256");
	die "JWT type must be JWT\n" unless (($header->{typ} // q{}) eq "JWT");
	die "JWT iat must be a NumericDate\n"
	    unless (defined($claims->{iat}) && $claims->{iat} =~ /\A[0-9]+\z/);
	die "JWT exp must be a NumericDate after iat\n"
	    unless (defined($claims->{exp}) && $claims->{exp} =~ /\A[0-9]+\z/
	        && $claims->{exp} > $claims->{iat});
	die "JWT contains non-standard or excluded claims\n"
	    if (grep { exists($claims->{$_}) } qw(created expires userAgent));
' || fail 'initial response did not contain the expected JWT'

secondHeaders=$(request "$token") || fail 'first JWT round-trip was rejected'
secondToken=$(responseToken <<< "$secondHeaders")
[[ -z "$secondToken" || "$secondToken" == "$token" ]] ||
	fail 'first JWT round-trip replaced the token'

thirdHeaders=$(request "$token") || fail 'second JWT round-trip was rejected'
thirdToken=$(responseToken <<< "$thirdHeaders")
[[ -z "$thirdToken" || "$thirdToken" == "$token" ]] ||
	fail 'second JWT round-trip replaced the token'

exit 0

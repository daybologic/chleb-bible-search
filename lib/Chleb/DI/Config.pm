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

package Chleb::DI::Config;
use strict;
use warnings;
use Moose;

extends 'Chleb::Bible::Base';

use English qw(-no_match_vars);
use IO::File;
use Readonly;
use YAML::XS 'LoadFile';

has __data => (is => 'ro', isa => 'HashRef', lazy => 1, builder => '__makeData');

has path => (is => 'ro', isa => 'Str', required => 1);

sub BUILD {
	my ($self) = @_;
	return;
}

sub __makeData {
	my ($self) = @_;
	return LoadFile($self->path);
}

sub get {
	my ($self, $section, $key, $default, $isBoolean) = @_;

	if (defined($self->__data->{$section}->{$key})) {
		my $value = $self->__data->{$section}->{$key};
		return __boolean($value) if ($isBoolean);
		return $value;
	}

	return __boolean($default) if ($isBoolean);
	return $default;
}

sub __boolean {
	my ($value) = @_;

	if (defined($value)) {
		$value = lc($value);

		return 1 if ($value eq 'true' || $value eq 'on' || $value eq 'yes' || $value eq '1' || $value =~ m/^enable/);
		return 0 if ($value eq 'false' || $value eq 'off' || $value eq 'no' || $value eq '0' || $value =~ m/^disable/);

		die("Invalid boolean value in config: $value");
	}

	return 0;
}

__PACKAGE__->meta->make_immutable;

1;

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

use Chleb::Utils;
use Data::Dumper;
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
	return LoadFile($self->path) || { };
}

sub get {
	my ($self, $section, $key, $default, $isBoolean) = @_;

	my $defaultUsed = 0;
	my $value = $self->__get($section, $key, $default, $isBoolean, \$defaultUsed);
	my $valuePrintable = (defined($value) && ref($value)) ? (Dumper $value) : $value;
	my $defaultPrintable = (defined($default) && ref($default)) ? (Dumper $default) : $default;
	my $msg = sprintf('[%s] %s: %s (default %s)', $section, $key, $valuePrintable, $defaultPrintable);

	my $level = 'debug';
	if ($defaultUsed) {
		$level = 'warn';
		$msg .= ' -- default used!  We recommend you set this value explicitly in your config!';
	}

	$self->dic->logger->$level($msg);
	return $value;
}

sub __get {
	my ($self, $section, $key, $default, $isBoolean, $pDefaultUsed) = @_;

	if (defined($self->__data->{$section}->{$key})) {
		my $value = $self->__data->{$section}->{$key};

		if ($value && ref($value) eq 'HASH' && $default) {
			$self->dic->logger->trace("key '$key' found in section '$section': building ephemeral section");

			# section partially populated, construction an ephemeral section and populate keys from default, where supplied
			my %ephemeralSection = ( );
			my %allKeys = (
				%{ $self->__data->{$section}->{$key} },
				%$default,
			);

			foreach my $k (keys(%allKeys)) {
				my $v;
				if (exists($self->__data->{$section}->{$key}->{$k})) {
					$self->dic->logger->trace(Dumper $self->__data);
					$v = $self->__data->{$section}->{$key}->{$k};
					$self->dic->logger->trace("$section -> $key -> $k: '$v' (from real config)");
				} else {
					$v = $default->{$k};
					$self->dic->logger->trace("$section -> $key -> $k: '$v' (from default)");
				}

				$ephemeralSection{$k} = $v;
			}

			$self->dic->logger->trace('Ephemeral section content: ' . Dumper \%ephemeralSection);
			return \%ephemeralSection;
		}

		return Chleb::Utils::boolean($key, $value, $default, $Chleb::Utils::BOOLEAN_FLAG_EMPTY_IS_FALSE) if ($isBoolean);
		return $value;
	}

	$$pDefaultUsed = 1;
	return Chleb::Utils::boolean($key, $default, 0, $Chleb::Utils::BOOLEAN_FLAG_EMPTY_IS_FALSE) if ($isBoolean);
	return $default;
}

__PACKAGE__->meta->make_immutable;

1;

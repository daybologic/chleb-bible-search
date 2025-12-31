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

package Chleb::Token;
use strict;
use warnings;
use Moose;

extends 'Chleb::Bible::Base';

use Chleb::Generated::Info;
use Digest::SHA;
use English qw(-no_match_vars);
use Readonly;

Readonly our $DEFAULT_TTL => 604_800; # one week
Readonly our $DATA_VERSION_MAJOR => 3;

has ttl => (is => 'ro', isa => 'Int', required => 1, default => $DEFAULT_TTL);

has expires => (is => 'rw', isa => 'Int', lazy => 1, default => sub {
	my ($self) = @_;
	return $self->created + $self->ttl;
});

has created => (is => 'rw', isa => 'Int', init_arg => 'now', lazy => 1, default => sub {
	return time();
});

has modified => (is => 'rw', isa => 'Int', init_arg => 'now', lazy => 1, default => sub {
	my ($self) = @_;
	return $self->created;
});

has version => (is => 'ro', isa => 'Str', init_arg => '_version', required => 1, default => sub {
	return $Chleb::Generated::Info::VERSION;
});

has major => (is => 'ro', isa => 'Int', init_arg => '_major', required => 1, default => sub {
	return $DATA_VERSION_MAJOR;
});

has minor => (is => 'ro', isa => 'Int', init_arg => '_minor', required => 1, default => 0);

has repo => (is => 'ro', isa => 'Chleb::Token::Repository', required => 1, init_arg => '_repo');

has source => (is => 'ro', isa => 'Chleb::Token::Repository::Base', required => 1, init_arg => '_source');

has value => (is => 'ro', isa => 'Str', init_arg => '_value', lazy => 1, builder => '_generate');

has shortValue => (is => 'ro', isa => 'Str', init_arg => undef, lazy => 1, builder => '_makeShortValue');

has loggedIn => (is => 'ro', isa => 'Bool', default => 0);

has ipAddress => (is => 'rw', isa => 'Str', default => '', trigger => \&__markDirty);

has userAgent => (is => 'rw', isa => 'Str', default => '', trigger => \&__markDirty);

has username => (is => 'ro', isa => 'Str', default => '');

has dirty => (is => 'rw', isa => 'Bool', default => 0);

has isNew => (is => 'rw', isa => 'Bool', default => 1);

sub __markDirty {
	my ($self) = @_;
	$self->dirty(1);
	return;
}

sub _generate {
	my ($self) = @_;

	my $sha = Digest::SHA->new(256);
	return $sha->add($PID, time(), rand(time()))->hexdigest;
}

sub _makeShortValue {
	my ($self) = @_;
	return substr($self->value, 0, 12);
}

sub save {
	my ($self) = @_;
	$self->source->save($self);
	$self->dirty(0);
	$self->isNew(0);
	return;
}

sub toString {
	my ($self) = @_;
	return sprintf('Token %s (%s)', $self->value, $self->source->toString());
}

sub expired {
	my ($self) = @_;
	return time() >= $self->expires;
}

sub TO_JSON {
	my ($self) = @_;

	my @fields = (qw(
		created
		expires
		ipAddress
		loggedIn
		major
		minor
		modified
		userAgent
		username
		value
		version
	));

	return \@fields unless ($self);
	my %json = map { $_ => $self->$_ } @fields;
	return \%json;
}

1;

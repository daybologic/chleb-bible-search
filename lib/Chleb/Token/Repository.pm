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

package Chleb::Token::Repository;
use strict;
use warnings;
use Moose;

extends 'Chleb::Bible::Base';

use Chleb::Exception;
use Chleb::Token::Repository::Dummy;
use Chleb::Token::Repository::Local;
use Chleb::Token::Repository::Redis;
use HTTP::Status qw(:constants);

sub repo {
	my ($self, $name) = @_;

	if (defined($name)) {
		if ($name eq 'Dummy') {
			return Chleb::Token::Repository::Dummy->new(repo => $self);
		} elsif ($name eq 'Local') {
			return Chleb::Token::Repository::Local->new(repo => $self);
		} elsif ($name eq 'Redis') {
			return Chleb::Token::Repository::Redis->new(repo => $self);
		}
	}

	...
}

sub create {
	my ($self) = @_;

	my $token = undef;
	my $keyName = 'save_order';
	foreach my $backend (@{ $self->__backends($keyName) }) {
		$token = $backend->create();
	}

	die Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, "No configured backend within '$keyName' created a token")
	    unless ($token);

	return $token;
}

sub load {
	my ($self, $tokenValue) = @_;

	my $token = undef;
	foreach my $backend (@{ $self->__backends('load_order') }) {
		$token = $backend->load($tokenValue);
		last if ($token);
		$self->dic->logger->debug("Session token '$tokenValue' not found via " . $backend->toString());
	}

	die Chleb::Exception->raise(HTTP_UNAUTHORIZED, "Session token '$tokenValue' not found")
	    unless ($token);

	return $token;
}

sub save {
	my ($self, $token) = @_;

	foreach my $backend (@{ $self->__backends('save_order') }) {
		$backend->save($token);
	}

	return;
}

sub __backends {
	my ($self, $welp) = @_;

	my @backend = ( );
	foreach my $backendName (@{ $self->__backendNames($welp) }) {
		push(@backend, $self->repo($backendName));
	}

	return \@backend;
}

sub __backendNames {
	my ($self, $welp) = @_;

	my $enabledBackends = $self->dic->config->get('session_tokens', $welp, [ 'Local' ]);
	my @backendNames = ( );
	foreach my $backendName (@$enabledBackends) {
		if ($backendName =~ m/^(\w+)$/) {
			push(@backendNames, $backendName);
		} else {
			die Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Backend name must be a single word: "'
			    . $backendName . '"');
		}
	}

	return \@backendNames;
}

1;

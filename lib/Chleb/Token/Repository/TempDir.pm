# Chleb Bible Search
# Copyright (c) 2024, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
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

package Chleb::Token::Repository::TempDir;
use strict;
use warnings;
use Moose;

extends 'Chleb::Token::Repository::Base';

use Chleb::Exception;
use Chleb::Token;
use Chleb::Token::Repository;
#use IO::File;
use English qw(-no_match_vars);
use HTTP::Status qw(:constants);
use Storable qw(retrieve store);

has dir => (is => 'ro', isa => 'Str', lazy => 1, builder => '_makeDir');

has __repo => (is => 'ro', isa => 'Chleb::Token::Repository', lazy => 1, default => sub {
	return Chleb::Token::Repository->new();
});

BEGIN {
	our $VERSION = '0.11.0';
}

sub create {
	my ($self) = @_;

	return Chleb::Token->new({
		_repo => $self->__repo,
		_source => $self,
	});
}

sub load {
	my ($self, $value) = @_;

	my $data;
	eval {
		$data = retrieve($self->__getFilePath($value));
	};

	if (my $evalError = $EVAL_ERROR || !$data) {
		die Chleb::Exception->raise(HTTP_FORBIDDEN, 'Token not recognized via ' . __PACKAGE__);
		# TODO logger?
	}

	# FIXME: Need a way to associate actual data with the key?
	# Perhaps not though, perhaps keep in memory with shared memcached?
	# That would keep session ids simple
	my $token = Chleb::Token->new({
		_repo   => $self->__repo,
		_source => $self,
		_value  => $value,
		expires => $data->{expires},
		now     => $data->{created},
	});

	die Chleb::Exception->raise(HTTP_FORBIDDEN, 'Token not recognized via ' . __PACKAGE__)
	    if ($token->expired);

	return $token;
}

sub save {
	my ($self, $token) = @_;

	my $filePath = $self->__getFilePath($token->value);

	eval {
		store($token->TO_JSON(), $filePath);
	};

	if (my $evalError = $EVAL_ERROR) {
		$self->dic->logger->error(sprintf("Failed to store %s in %s to '%s': %s",
		    $token->toString(), __PACKAGE__, $filePath, $evalError));

		die Chleb::Exception->raise(HTTP_INSUFFICIENT_STORAGE, 'Cannot save session token');
	}

	return;
}

sub _makeDir {
	my ($self) = @_;
	return '/tmp'; # FIXME: Should be read from a config, with a default?
}

sub __getFilePath {
	my ($self, $value) = @_;

	$value .= '.session';
	return join('/', $self->dir, $value);
}

1;

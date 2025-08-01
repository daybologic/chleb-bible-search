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

package Chleb::Token::Repository::TempDir;
use strict;
use warnings;
use Moose;

extends 'Chleb::Token::Repository::Base';

use Chleb::Exception;
use Chleb::Token;
use Chleb::Token::Repository;
use Data::Dumper;
#use IO::File;
use English qw(-no_match_vars);
use HTTP::Status qw(:constants);
use Storable qw(retrieve store);

has dir => (is => 'ro', isa => 'Str', lazy => 1, builder => '_makeDir');

has __repo => (is => 'ro', isa => 'Chleb::Token::Repository', lazy => 1, default => sub {
	return Chleb::Token::Repository->new();
});

sub create {
	my ($self) = @_;

	return Chleb::Token->new({
		dic     => $self->dic,
		_repo   => $self->__repo,
		_source => $self,
	});
}

sub load {
	my ($self, $value) = @_;

	$value = $value->value if (ref($value) && $value->isa('Dancer2::Core::Cookie'));
	__valueValidate($value);

	my $data;
	my $filePath = $self->__getFilePath($value);
	eval {
		$data = retrieve($filePath);
		$self->dic->logger->trace(Dumper $data);
	};

	if (my $evalError = $EVAL_ERROR) {
		$self->dic->logger->error($evalError);
		die Chleb::Exception->raise(HTTP_UNAUTHORIZED, 'sessionToken unrecognized via ' . __PACKAGE__);
	} elsif (!$data) {
		die Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Session token is an empty file');
	}

	my $token;
	eval {
		$token = Chleb::Token->new({
			dic       => $self->dic,
			_repo     => $self->__repo,
			_source   => $self,
			_value    => $value,
			_major    => $data->{major},
			_minor    => $data->{minor},
			_version  => $data->{version},
			expires   => $data->{expires},
			ipAddress => $data->{ipAddress},
			now       => $data->{created},
		});
	};

	if (my $evalError = $EVAL_ERROR) {
		$self->dic->logger->error($evalError);
		die Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Token cannot be rebuilt using stored data'); # This should not happen!
	} elsif ($token->major != $Chleb::Token::DATA_VERSION_MAJOR) {
		$self->dic->logger->error(sprintf('Version mismatch in %s, (store %d, expect %d), stale data?', $token->toString(), $token->major, $Chleb::Token::DATA_VERSION_MAJOR));
		die Chleb::Exception->raise(HTTP_UNAUTHORIZED, "Sorry, the token went stale because of a version mismatch, remove your sessionToken cookie and you'll get a new one");
	} elsif ($token->expired) {
		die Chleb::Exception->raise(HTTP_UNAUTHORIZED, 'sessionToken expired via ' . __PACKAGE__);
	}

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
	$value = join('/', $self->dir, $value);
	$self->dic->logger->trace('session file path: ' . $value);
	return $value;
}

sub __valueValidate {
	my ($value) = @_;
	return 1 if ($value =~ m/^[0-9a-f]{64}$/);

	die Chleb::Exception->raise(HTTP_UNAUTHORIZED, 'The sessionToken format must be SHA-256');
}

1;

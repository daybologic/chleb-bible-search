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

package Chleb::Token::Repository::Local;
use strict;
use warnings;
use Moose;

extends 'Chleb::Token::Repository::Base';

use Chleb::Exception;
use Chleb::Token;
use Chleb::Token::Repository;
use Chleb::Utils;
use Data::Dumper;
use English qw(-no_match_vars);
use Errno qw(:POSIX);
use HTTP::Status qw(:constants);
#use IO::File;
use POSIX qw(strerror);
use Readonly;
use Storable qw(retrieve store);

Readonly our $DIR_LOCAL => '/tmp/chleb-bible-search/sessions';

Readonly my $QUIET => 1 << 0;
Readonly my $FORCE => 1 << 1;

has dir => (is => 'ro', isa => 'Str', lazy => 1, builder => '_makeDir');

has __dynamic => (is => 'ro', isa => 'Bool', lazy => 1, builder => '__makeDynamic');

sub BUILD {
	my ($self) = @_;

	$self->__makeHierarchy();

	return;
}

sub create {
	my ($self) = @_;

	return Chleb::Token->new({
		dic     => $self->dic,
		ttl     => $self->_ttl,
		_repo   => $self->repo,
		_source => $self,
	});
}

sub load {
	my ($self, $value) = @_;

	$value = $value->value if (ref($value) && $value->isa('Dancer2::Core::Cookie'));
	$self->_valueValidate($value);

	my $data;
	my $filePath = $self->__getFilePath($value);
	eval {
		$data = retrieve($filePath);
	};

	if (my $evalError = $EVAL_ERROR) {
		my $errNum = $ERRNO;
		my $errStr = strerror($errNum);
		if ($evalError =~ m/: $errStr/) {
			return undef; # not found
		}

		$self->dic->logger->error($evalError);
		die Chleb::Exception->raise(HTTP_UNAUTHORIZED, 'sessionToken unrecognized via ' . __PACKAGE__);
	} elsif (!$data) {
		die Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Session token is an empty file');
	} else {
		$self->dic->logger->trace(Dumper $data);
	}

	my $token;
	eval {
		$token = Chleb::Token->new({
			dic       => $self->dic,
			_repo     => $self->repo,
			_source   => $self,
			_value    => $value,
			_major    => $data->{major},
			_minor    => $data->{minor},
			_version  => $data->{version},
			expires   => $data->{expires},
			ipAddress => $data->{ipAddress},
			now       => $data->{created},
			userAgent => $data->{userAgent},
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
	my $config = $self->dic->config->get('session_tokens', 'backend_local', { dir => $DIR_LOCAL });
	return $config->{dir};
}

sub __getFilePath {
	my ($self, $value, $flags) = @_;
	my @part = split(m//, $value, 5);
	pop(@part);

	if ($flags & $FORCE || $self->__dynamic) {
		my $path = $self->dir;
		for my $p (@part) {
			$path .= "/$p";
			if (!mkdir($path, 0700) && $ERRNO != EEXIST) {
				die Chleb::Exception->raise(HTTP_INSUFFICIENT_STORAGE, "mkdir $path: $ERRNO");
			}
		}
	}

	my $return = join('/', $self->dir, @part, $value) . '.session';
	$self->dic->logger->trace("session file path: '$return'") unless ($flags & $QUIET);
	return $return;
}

sub __makeDynamic {
	my ($self) = @_;
	my $key = 'dynamic_mkdir';
	my $config = $self->dic->config->get('session_tokens', 'backend_local', { $key => 1 });
	$self->dic->logger->trace("$key: " . Dumper $config);
	my $return = Chleb::Utils::boolean($key, $config->{$key}, 1);
	$self->dic->logger->trace("$key: " . Dumper $return);
	return $return;
}

sub __makeHierarchy {
	my ($self) = @_;

	if ($self->__dynamic) {
		$self->dic->logger->debug("Not pre-creating directory hierarchy under '" . $self->dir
		    . "' because dynamic_mkdir is set");

		return;
	} else {
		$self->dic->logger->info("Pre-creating directory hierarchy under '" . $self->dir
		    . "', this may take some time");
	}

	for (my $value = 0x0; $value <= 0xffff; $value++) {
		$self->__getFilePath(sprintf("%04x", $value), $QUIET | $FORCE);
	}

	$self->dic->logger->info('Directory structure successfully created');

	return;
}

1;

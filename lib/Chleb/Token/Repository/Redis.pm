package Chleb::Token::Repository::Redis;
use Moose;

extends 'Chleb::Token::Repository::Base';

=head1 NAME

Chleb::Token::Repository::Redis

=head1 CONFIG

	[Chleb::Token::Repository::Redis]
	host = adll.dlm.dln.example.net
	db = 1

=head1 DESCRIPTION

The Redis backend for session token storage

=cut

use Chleb::Exception;
use Data::Dumper;
use English qw(-no_match_vars);
use HTTP::Status qw(:constants);
use Readonly;
use Redis;
use Scalar::Util qw(looks_like_number);

=head1 CONSTANTS

=over

=item C<$REDIS_PORT>

This is the default Redis port if it is not specified in the URI

=back

=cut

Readonly our $REDIS_PORT => 6379;

=head1 ATTRIBUTES

=over

=item <configSectionName>

=cut

has configSectionName  => (is => 'rw', isa => 'Str', lazy => 1, default => \&__makeConfigSectionName);

=item C<do>

This is the L<Redis> database.  We call it do to avoid any magic.
Just do everything by deferencing us and accessing C<do>.
The builder for this is L</__makeDo()>.

=cut

has do => (isa => 'Redis', is => 'rw', lazy => 1, init_arg => undef, default => \&__makeDo);

=back

=head1 METHODS

=over

=item C<BUILD>

Build hook, called by Moose.  Should not be called directly.

=cut

sub BUILD {
	my ($self) = @_;
	# nothing to do
	return;
}

sub create {
	my ($self) = @_;

	return Chleb::Token->new({
		dic     => $self->dic,
		_repo   => $self->repo,
		_source => $self,
	});
}

=item C<load($value)>

=cut

sub load {
	my ($self, $value) = @_;

	$value = $value->value if (ref($value) && $value->isa('Dancer2::Core::Cookie'));
	$self->_valueValidate($value);

	my $data;
	eval {
		$data = $self->do->hmget($value, @{ Chleb::Token::TO_JSON() });
	};
	my $evalError = $EVAL_ERROR;

	if ($data) {
		$self->dic->logger->trace(Dumper $data);
		my @fieldNames = @{ Chleb::Token::TO_JSON() };
		my %newData = ( );
		for (my $fieldIndex = 0; $fieldIndex < scalar(@fieldNames); $fieldIndex++) {
			my $fieldName = $fieldNames[$fieldIndex];
			$newData{$fieldName} = $data->[$fieldIndex];
		}
		$data = \%newData;
		$self->dic->logger->trace(Dumper $data);
	}

	if ($evalError || !$data) {
		$self->dic->logger->error($evalError);
		die Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, "error getting session '$value' token via " . __PACKAGE__);
	} elsif (!$data) {
		die Chleb::Exception->raise(HTTP_UNAUTHORIZED, "Session token '$value' not found via " . __PACKAGE__);
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

=item C<save($token)>

=cut

sub save {
	my ($self, $token) = @_;

	eval {
		$self->do->hmset($token->value, %{ $token->TO_JSON() }); # TODO: Don't send undirty keys for a speed improvement
	};

	if (my $evalError = $EVAL_ERROR) {
		die Chleb::Exception->raise(HTTP_INSUFFICIENT_STORAGE, 'Cannot save session token');
	}

	return;
}

=back

=head1 PRIVATE METHODS

=over

=item C<__buildRedis($server)>

Builds and connects to a Redis instance.  Returns a L<Redis> object.

=cut

sub __buildRedis {
	my ($self, $server) = @_;

	my $redis;
	eval {
		$redis = Redis->new(server => $server);
	};

	if (my $evalError = $EVAL_ERROR) {
		die Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, "Failed to connect to $server: $evalError");
	}

	return $redis;
}

=item C<__makeDo()>

Builder for L</do>.  Not for human use.
Called by the Moose framework when L</do> is first used.

=cut

sub __makeDo {
	my ($self) = @_;

	my $uri = $self->dic->config->get($self->configSectionName, 'host', 'localhost');
	if ($uri !~ m/:/) {
		$uri = "${uri}:${REDIS_PORT}";
	}

	my $redis = $self->__buildRedis($uri);

	my $db = $self->dic->config->get($self->configSectionName, 'db', 0);
	if (defined($db)) {
		if ($db =~ m/^\d+$/) {
			$redis->select($db);
		} else {
			die Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, "db must be numerical, positive integer: '$db'");
		}
	}

	return $redis;
}

sub __makeConfigSectionName {
	my $class = __PACKAGE__;
	$class =~ s/:://g;
	return $class;
}

=back

=cut

1;

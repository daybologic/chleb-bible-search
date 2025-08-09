package Chleb::Token::Repository::Redis;
use Moose;

extends 'Chleb::Token::Repository::Base';

=head1 NAME

Chleb::Token::Repository::Redis

=head1 CONFIG

	session_tokens:
	  enabled_backends:
	    - Redis
	  backend_redis:
	    host: localhost:6379
	    db: 1

=head1 DESCRIPTION

The Redis backend for session token storage

=cut

use Chleb::Exception;
use Chleb::Token;
use Data::Dumper;
use English qw(-no_match_vars);
use HTTP::Status qw(:constants);
use Readonly;
use Redis;
use Scalar::Util qw(looks_like_number);

=head1 CONSTANTS

=over

=item C<$REDIS_HOST>

The default host, which is C<localhost>, for accessing Redis.
If you are using AWS, or another host, follow their instructions and set via
the config.  Don't alter this value.

=item C<$REDIS_PORT>

This is the default Redis port if it is not specified in the URI

=item C<$REDIS_DB>

The default db ordinal which will be selected.  We choose C<1> for session token storage.

=back

=cut

Readonly our $REDIS_HOST => 'localhost';
Readonly our $REDIS_PORT => 6379;
Readonly our $REDIS_DB   => 1;

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

=item C<create()>

Create a new L<Chleb::Token> with Redis as the backing store.

=cut

sub create {
	my ($self) = @_;

	my $ttl = $self->dic->config->get('session_tokens', 'ttl', $Chleb::Token::DEFAULT_TTL);

	return Chleb::Token->new({
		dic     => $self->dic,
		ttl     => $ttl,
		_repo   => $self->repo,
		_source => $self,
	});
}

=item C<load($value)>

Given the token value, which may be a hex string, or a L<Dancer2::Core::Cookie>,
we search for the token and return a L<Chleb::Token> if it can be recovered from
this backend, or return C<undef>, in which case, you should check the next backend
which is enabled.

=cut

sub load {
	my ($self, $value) = @_;

	$value = $value->value if (ref($value) && $value->isa('Dancer2::Core::Cookie'));
	$self->_valueValidate($value);

	my $data = [ ];
	eval {
		$data = $self->do->hmget($value, @{ Chleb::Token::TO_JSON() });
	};
	my $evalError = $EVAL_ERROR;

	my @fieldNames = @{ Chleb::Token::TO_JSON() };
	my %newData = ( );
	for (my $fieldIndex = 0; $fieldIndex < scalar(@fieldNames); $fieldIndex++) {
		my $fieldName = $fieldNames[$fieldIndex];
		$newData{$fieldName} = $data->[$fieldIndex];
	}
	$data = \%newData;
	$self->dic->logger->trace(Dumper $data);

	$data = undef unless(defined($data->{created}));

	if ($evalError) {
		$self->dic->logger->error($evalError);
		die Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, "error getting session '$value' token via " . __PACKAGE__);
	} elsif (!$data) {
		return undef; # not found
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

Given a L<Chleb::Token>, we will save it into the Redis backend,
and if it is new, we will set the expiry time to ensure it is automagically evicted.

=cut

sub save {
	my ($self, $token) = @_;

	eval {
		$self->do->hmset($token->value, %{ $token->TO_JSON() }); # TODO: Don't send undirty keys, for a speed improvement
		$self->do->expireat($token->value, $token->expires) if ($token->isNew);
	};

	if (my $evalError = $EVAL_ERROR) {
		die Chleb::Exception->raise(HTTP_INSUFFICIENT_STORAGE, 'Cannot save session token');
	}

	$token->dirty(0);
	$token->isNew(0);

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

	my $config = $self->dic->config->get('session_tokens', 'backend_redis', { host => $REDIS_HOST, db => $REDIS_DB });
	my $uri = $config->{host};
	if ($uri !~ m/:/) {
		$uri = "${uri}:${REDIS_PORT}";
	}

	my $redis = $self->__buildRedis($uri);

	my $db = $config->{db};
	if (defined($db)) {
		if ($db =~ m/^\d+$/) {
			$redis->select($db);
		} else {
			die Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, "db must be numerical, positive integer: '$db'");
		}
	}

	return $redis;
}

=back

=cut

1;

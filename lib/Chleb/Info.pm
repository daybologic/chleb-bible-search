package Chleb::Info;
use Moose;

use Readonly;
use UUID::Tiny ':std';

Readonly my $ID_SALT => '713d81c8-1c3f-11f0-ae4d-4f6f7f2e2524';

has bibles => (isa => 'ArrayRef[Chleb::Bible]', is => 'ro', required => 1);

has type => (is => 'ro', isa => 'Str', default => sub { 'info' });

has id => (is => 'ro', isa => 'Str', lazy => 1, default => \&__makeId);

has msec => (is => 'rw', isa => 'Int', default => 0);

sub toString {
	my ($self) = @_;
	return sprintf('%s about %d bibles', $self->type, scalar(@{ $self->bibles }));
}

sub __makeId {
	my ($self) = @_;

	my $idStrInput = $ID_SALT; # don't simply sum an empty string
	foreach my $bible (@{ $self->bibles }) {
		$idStrInput .= $bible->id;
	}

	return join('/', $self->type, create_uuid_as_string(UUID_MD5, $idStrInput));
}

__PACKAGE__->meta->make_immutable;

1;

package Chleb::Info;
use Moose;

use UUID::Tiny ':std';

has bibles => (isa => 'ArrayRef[Chleb::Bible]', is => 'ro', required => 1);

has type => (is => 'ro', isa => 'Str', default => sub { 'info' });

has id => (is => 'ro', isa => 'Str', default => \&__makeId);

sub __makeId {
	my ($self) = @_;

	return join('/', $self->type, create_uuid(UUID_MD5, $self->bibles->[0]->translation)); # hmm, this still isn't right, we'd need to sum all the bibles somehow?
}

1;

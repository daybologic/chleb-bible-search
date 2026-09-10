# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

package Chleb::Account::VerificationQueue;
use strict;
use warnings;
use Carp qw(croak);
use Moose;

extends 'Chleb::Bible::Base';

use Chleb::Exception;
use English qw(-no_match_vars);
use HTTP::Status qw(:constants);
use JSON qw(encode_json);

has client => (is => 'ro', init_arg => 'client', predicate => '__hasClient');
has __clientObject => (is => 'rw', lazy => 1, builder => '__makeClient');

=head1 NAME

Chleb::Account::VerificationQueue

=head1 DESCRIPTION

Publishes account-verification jobs to the configured Amazon SQS queue.

=head1 METHODS

=over

=item C<publish($job)>

Publish an account ID and numeric verification token ID to SQS.

=cut

sub publish {
	my ($self, $job) = @_;
	my $config = $self->dic->config->get('accounts', 'sqs', {});
	my $queueUrl = $config->{verification_queue_url};
	if (!defined($queueUrl) || length($queueUrl) == 0) {
		croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Account verification SQS queue URL is not configured'));
	}
	my $evalOk; $evalOk = eval {
		$self->__client->SendMessage(
			QueueUrl => $queueUrl,
			MessageBody => encode_json({
				account_id => int($job->{account_id}),
				token_id => int($job->{token_id}),
			}),
		);
		1;
	} or $evalOk = 0;
	croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, "Unable to publish account verification job: $EVAL_ERROR"))
		unless ($evalOk);
	return 1;
}

=back

=cut

sub __client {
	my ($self) = @_;
	return $self->client if ($self->__hasClient);
	return $self->__clientObject;
}

sub __makeClient { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self) = @_;
	my $evalOk; $evalOk = eval {
		require Paws;
		1;
	} or $evalOk = 0;
	croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, "Cannot load Paws for account verification SQS: $EVAL_ERROR"))
		unless ($evalOk);
	my $awsConfig = $self->dic->config->get('accounts', 'aws', {});
	return Paws->service('SQS', region => $awsConfig->{region} // $ENV{AWS_REGION} // 'eu-west-2');
}

__PACKAGE__->meta->make_immutable;

1;

# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

package Chleb::Workers::Signup;
use strict;
use warnings;
use Moose;

use Chleb::Account::Repository;
use Chleb::DI::Container;
use English qw(-no_match_vars);
use JSON qw(decode_json);
use POSIX qw(EXIT_SUCCESS strftime);

=head1 NAME

Chleb::Workers::Signup

=head1 DESCRIPTION

Consumes account-signup messages from SQS and sends verification email through
the configured SMTP service.

=head1 METHODS

=over

=item C<run()>

Run the account-signup worker until it is stopped.

=cut

sub run {
	my $context = __makeContext();

	while (1) {
		my $messages = __receive($context);
		foreach my $message (@$messages) {
			__processMessage($context, $message);
		}
	}

	return EXIT_SUCCESS;
}

=item C<__makeContext()>

Build the AWS, repository, and SMTP context used by the worker.

=cut

sub __makeContext {
	my $dic = Chleb::DI::Container->instance;
	my $config = $dic->config;
	my $sqsConfig = $config->get('accounts', 'sqs', {});
	my $queueUrl = $sqsConfig->{verification_queue_url};
	if (!defined($queueUrl) || length($queueUrl) == 0) {
		die("Account verification SQS queue URL is not configured\n");
	}

	my $awsConfig = $config->get('accounts', 'aws', {});
	my $smtpConfig = $config->get('mailing_list', 'smtp', {});
	my $smtpHost = $smtpConfig->{server};
	my $smtpUser = $smtpConfig->{username};
	my $smtpPassword = $smtpConfig->{password};
	if (!defined($smtpHost) || length($smtpHost) == 0 || !defined($smtpUser) || length($smtpUser) == 0 || !defined($smtpPassword) || length($smtpPassword) == 0) {
		die("SMTP configuration is incomplete\n");
	}

	my $evalOk; $evalOk = eval {
		require Paws;
		1;
	} or $evalOk = 0;
	die("Cannot load Paws for account verification worker: $EVAL_ERROR\n") unless ($evalOk);

	my $repository = Chleb::Account::Repository->new({
		dic => $dic,
		backend => $config->get('accounts', 'backend', $Chleb::Account::Repository::BACKEND),
	});

	return {
		account_repository => $repository,
		mail_from => $config->get('mailing_list', 'list_info', {})->{from} // $smtpUser,
		site_root => $config->get('mailing_list', 'site_info', {})->{root_url} // '',
		smtp => {
			host => $smtpHost,
			password => $smtpPassword,
			port => $smtpConfig->{port} // 587,
			username => $smtpUser,
		},
		sqs => Paws->service('SQS', region => $awsConfig->{region} // $ENV{AWS_REGION} // 'eu-west-2'),
		time => $dic->time,
		queue_url => $queueUrl,
	};
}

=item C<__receive($context)>

Long-poll SQS and return the received messages.

=cut

sub __receive {
	my ($context) = @_;

	my $response = $context->{sqs}->ReceiveMessage(
		QueueUrl => $context->{queue_url},
		MaxNumberOfMessages => 10,
		WaitTimeSeconds => 20,
		VisibilityTimeout => 300,
	);

	return $response && $response->Messages ? $response->Messages : [];
}

=item C<__processMessage($context, $message)>

Validate, deliver, consume, and acknowledge one account-signup message.

=cut

sub __processMessage {
	my ($context, $message) = @_;
	my $job = __parseJob($message);
	unless ($job) {
		__discard($context, $message, 'invalid account verification message');
		return;
	}

	my $accountId = $job->{account_id};
	my $tokenId = $job->{token_id};
	my $token = $context->{account_repository}->loadVerificationToken($tokenId);
	if (!$token || int($token->{account_id}) != $accountId || defined($token->{consumed_at}) || int($token->{expires_at}) <= int($context->{time}->get())) {
		__discard($context, $message, "unavailable account verification message for account $accountId");
		return;
	}

	my $account = $context->{account_repository}->load($accountId);
	if (!$account || $account->{status} ne 'pending') {
		__discard($context, $message, "unavailable account verification message for account $accountId");
		return;
	}

	unless (__sendMail($context, $account, $token)) {
		return;
	}

	unless ($context->{account_repository}->consumeVerificationToken($tokenId, $accountId)) {
		warn("Unable to consume verification token $tokenId for account $accountId\n");
		return;
	}

	__deleteMessage($context, $message);

	return;
}

=item C<__parseJob($message)>

Decode and validate the account and token IDs in one SQS message.

=cut

sub __parseJob {
	my ($message) = @_;

	my $decoded;
	my $evalOk; $evalOk = eval {
		$decoded = decode_json($message->Body);
		1;
	} or $evalOk = 0;

	return unless ($evalOk && ref($decoded) eq 'HASH' && defined($decoded->{account_id}) && defined($decoded->{token_id}));

	return {
		account_id => int($decoded->{account_id}),
		token_id => int($decoded->{token_id}),
	};
}

=item C<__sendMail($context, $account, $token)>

Send one account-verification email through the configured SMTP service.

=cut

sub __sendMail {
	my ($context, $account, $token) = @_;
	my $accountId = int($account->{id});
	my $verificationUrl = $context->{site_root} . '/1/accounts/verify?account_id=' . $accountId . '&token_id=' . int($token->{token_id}) . '&token=' . $token->{value};
	my $subject = 'Verify your Chleb Bible Search account';
	my $body = "Hello $account->{name},\n\nPlease verify your Chleb Bible Search account:\n\n$verificationUrl\n\nThis link expires in 24 hours.\n";
	my $mailData = "Date: " . strftime('%a, %d %b %Y %H:%M:%S %z', localtime()) . "\n";
	$mailData .= "From: $context->{mail_from}\nTo: $account->{email}\nSubject: $subject\nMIME-Version: 1.0\nContent-Type: text/plain; charset=UTF-8\n\n$body";
	my $smtp = $context->{smtp};
	my $mailPid = open(my $mail, '|-', 'swaks', '--server', $smtp->{host}, '--port', $smtp->{port}, '--auth', 'LOGIN', '--auth-user', $smtp->{username}, '--auth-password', $smtp->{password}, '--from', $context->{mail_from}, '--to', $account->{email}, '--tls', '--data', '-');

	unless ($mailPid) {
		warn("Unable to start SMTP mail delivery for account $accountId: $ERRNO\n");
		return;
	}

	print {$mail} $mailData;

	unless (close($mail)) {
		warn("SMTP mail delivery failed for account $accountId\n");
		return;
	}
	return 1;
}

=item C<__discard($context, $message, $reason)>

Log and acknowledge a message that cannot be processed.

=cut

sub __discard {
	my ($context, $message, $reason) = @_;

	warn("Discarding $reason\n");
	__deleteMessage($context, $message);

	return;
}

=item C<__deleteMessage($context, $message)>

Delete a successfully handled or permanently invalid SQS message.

=cut

sub __deleteMessage {
	my ($context, $message) = @_;

	$context->{sqs}->DeleteMessage(
		QueueUrl => $context->{queue_url},
		ReceiptHandle => $message->ReceiptHandle,
	);

	return;
}

=back

=cut

1;

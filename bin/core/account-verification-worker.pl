#!/usr/bin/env perl
## no critic (Subroutines::ProhibitExcessComplexity)
# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

use strict;
use warnings;

use Chleb::Account::Repository;
use Chleb::DI::Container;
use English qw(-no_match_vars);
use JSON qw(decode_json);
use POSIX qw(strftime);

sub main { ## no critic (Subroutines::ProhibitExcessComplexity)
my $dic = Chleb::DI::Container->instance;
my $config = $dic->config;
my $sqsConfig = $config->get('accounts', 'sqs', {});
my $queueUrl = $sqsConfig->{verification_queue_url};
if (!defined($queueUrl) || length($queueUrl) == 0) {
	die("Account verification SQS queue URL is not configured\n");
}

my $awsConfig = $config->get('accounts', 'aws', {});
my $region = $awsConfig->{region} // $ENV{AWS_REGION} // 'eu-west-2';
my $smtpConfig = $config->get('mailing_list', 'smtp', {});
my $smtpHost = $smtpConfig->{server};
my $smtpPort = $smtpConfig->{port} // 587;
my $smtpUser = $smtpConfig->{username};
my $smtpPassword = $smtpConfig->{password};
my $mailFrom = $config->get('mailing_list', 'list_info', {})->{from} // $smtpUser;
my $siteRoot = $config->get('mailing_list', 'site_info', {})->{root_url} // '';
if (!defined($smtpHost) || length($smtpHost) == 0 || !defined($smtpUser) || length($smtpUser) == 0 || !defined($smtpPassword) || length($smtpPassword) == 0) {
	die("SMTP configuration is incomplete\n");
}

my $evalOk; $evalOk = eval {
	require Paws;
	1;
} or $evalOk = 0;
die("Cannot load Paws for account verification worker: $EVAL_ERROR\n") unless ($evalOk);

my $sqs = Paws->service('SQS', region => $region);
my $repository = Chleb::Account::Repository->new({
	dic => $dic,
	backend => $config->get('accounts', 'backend', $Chleb::Account::Repository::BACKEND),
});

while (1) {
	my $response = $sqs->ReceiveMessage(
		QueueUrl => $queueUrl,
		MaxNumberOfMessages => 10,
		WaitTimeSeconds => 20,
		VisibilityTimeout => 300,
	);
	next unless ($response && $response->Messages);

	foreach my $message (@{ $response->Messages }) {
		my $body;
		my $decoded;
		$evalOk = eval {
			$body = $message->Body;
			$decoded = decode_json($body);
			1;
		} or $evalOk = 0;
		if (!$evalOk || ref($decoded) ne 'HASH' || !defined($decoded->{account_id}) || !defined($decoded->{token_id})) {
			warn("Discarding invalid account verification message\n");
			$sqs->DeleteMessage(QueueUrl => $queueUrl, ReceiptHandle => $message->ReceiptHandle);
			next;
		}

		my $accountId = int($decoded->{account_id});
		my $tokenId = int($decoded->{token_id});
		my $token = $repository->loadVerificationToken($tokenId);
		if (!$token || int($token->{account_id}) != $accountId || defined($token->{consumed_at}) || int($token->{expires_at}) <= int($dic->time->get())) {
			warn("Discarding unavailable account verification message for account $accountId\n");
			$sqs->DeleteMessage(QueueUrl => $queueUrl, ReceiptHandle => $message->ReceiptHandle);
			next;
		}

		my $account = $repository->load($accountId);
		if (!$account || $account->{status} ne 'pending') {
			warn("Discarding unavailable account verification message for account $accountId\n");
			$sqs->DeleteMessage(QueueUrl => $queueUrl, ReceiptHandle => $message->ReceiptHandle);
			next;
		}

		my $verificationUrl = $siteRoot . '/1/accounts/verify?account_id=' . $accountId . '&token_id=' . $tokenId . '&token=' . $token->{value};
		my $subject = 'Verify your Chleb Bible Search account';
		my $bodyText = "Hello $account->{name},\n\nPlease verify your Chleb Bible Search account:\n\n$verificationUrl\n\nThis link expires in 24 hours.\n";
		my $mailPid = open(my $mail, '|-', 'swaks', '--server', $smtpHost, '--port', $smtpPort, '--auth', 'LOGIN', '--auth-user', $smtpUser, '--auth-password', $smtpPassword, '--from', $mailFrom, '--to', $account->{email}, '--tls', '--data', '-');
		if (!$mailPid) {
			warn("Unable to start SMTP mail delivery for account $accountId: $ERRNO\n");
			next;
		}
		print {$mail} "Date: " . strftime('%a, %d %b %Y %H:%M:%S %z', localtime()) . "\n";
		print {$mail} "From: $mailFrom\nTo: $account->{email}\nSubject: $subject\nMIME-Version: 1.0\nContent-Type: text/plain; charset=UTF-8\n\n$bodyText";
		my $sent = close($mail);
		if (!$sent) {
			warn("SMTP mail delivery failed for account $accountId\n");
			next;
		}

		unless ($repository->consumeVerificationToken($tokenId, $accountId)) {
			warn("Unable to consume verification token $tokenId for account $accountId\n");
			next;
		}
		$sqs->DeleteMessage(QueueUrl => $queueUrl, ReceiptHandle => $message->ReceiptHandle);
	}
}

return 0;
}

main();

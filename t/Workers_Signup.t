#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

package FakeSignupMessage;
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;

sub new {
	my ($class, $body) = @_;
	return bless({ body => $body, receipt_handle => 'receipt-1' }, $class);
}

sub Body {
	my ($self) = @_;
	return $self->{body};
}

sub ReceiptHandle {
	my ($self) = @_;
	return $self->{receipt_handle};
}

package FakeSignupResponse;
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;

sub new {
	my ($class, $messages) = @_;
	return bless({ messages => $messages }, $class);
}

sub Messages {
	my ($self) = @_;
	return $self->{messages};
}

package FakeSignupSQS;
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;

sub new {
	my ($class, $messages) = @_;
	return bless({ messages => $messages, deleted => [] }, $class);
}

sub ReceiveMessage {
	my ($self, %args) = @_;
	$self->{receive_args} = \%args;
	return FakeSignupResponse->new($self->{messages});
}

sub DeleteMessage {
	my ($self, %args) = @_;
	push(@{ $self->{deleted} }, \%args);
	return 1;
}

package FakeSignupRepository;
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;

sub new {
	my ($class) = @_;
	return bless({ consumed => 0 }, $class);
}

sub loadVerificationToken {
	return {
		token_id => 7,
		account_id => 123,
		value => 'verification-token',
		expires_at => 3600,
	};
}

sub load {
	return {
		id => 123,
		email => 'john.smith@example.com',
		name => 'John Smith',
		status => 'pending',
	};
}

sub consumeVerificationToken {
	my ($self) = @_;
	$self->{consumed}++;
	return 1;
}

package FakeSignupTime;
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;

sub new {
	my ($class) = @_;
	return bless({}, $class);
}

sub get {
	return 0;
}

package FakeSignupConfig;
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;

sub new {
	my ($class) = @_;
	return bless({}, $class);
}

sub get {
	return;
}

package SignupWorkerTests;
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
## no critic (Subroutines::ProtectPrivateSubs)
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb::DI::Container;
use Chleb::Workers::Signup;
use English qw(-no_match_vars);
use File::Spec;
use File::Temp qw(tempdir);
use JSON qw(encode_json);
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

sub setUp {
	my ($self) = @_;
	$self->sut(Chleb::Workers::Signup->new());
	return EXIT_SUCCESS;
}

sub testContextRequiresQueueUrl {
	my ($self) = @_;
	plan tests => 1;

	Chleb::DI::Container->instance->config(FakeSignupConfig->new());
	my $evalOk; $evalOk = eval {
		Chleb::Workers::Signup::__makeContext();
		1;
	} or $evalOk = 0;

	is($evalOk, 0, 'worker context rejects a missing queue URL');
	return EXIT_SUCCESS;
}

sub testReceiveUsesLongPollSettings {
	my ($self) = @_;
	plan tests => 5;

	my $message = FakeSignupMessage->new('{}');
	my $sqs = FakeSignupSQS->new([$message]);
	my $messages = Chleb::Workers::Signup::__receive({ sqs => $sqs, queue_url => 'queue-url' });

	is(scalar(@$messages), 1, 'worker receive returns received messages');
	is($messages->[0], $message, 'worker receive preserves the message object');
	is($sqs->{receive_args}->{WaitTimeSeconds}, 20, 'worker receive long-polls for 20 seconds');
	is($sqs->{receive_args}->{VisibilityTimeout}, 300, 'worker receive uses a five-minute visibility timeout');
	is($sqs->{receive_args}->{QueueUrl}, 'queue-url', 'worker receive uses the configured queue');
	return EXIT_SUCCESS;
}

sub testParseJobValidatesAndConvertsIdentifiers {
	my ($self) = @_;
	plan tests => 5;

	my $job = Chleb::Workers::Signup::__parseJob(FakeSignupMessage->new(encode_json({ account_id => '123', token_id => '7' })));
	is($job->{account_id}, 123, 'worker job parser converts account ID to an integer');
	is($job->{token_id}, 7, 'worker job parser converts token ID to an integer');
	ok(!defined(Chleb::Workers::Signup::__parseJob(FakeSignupMessage->new('not-json'))), 'worker job parser rejects invalid JSON');
	ok(!defined(Chleb::Workers::Signup::__parseJob(FakeSignupMessage->new('{}'))), 'worker job parser rejects missing identifiers');
	ok(!defined(Chleb::Workers::Signup::__parseJob(FakeSignupMessage->new('[]'))), 'worker job parser rejects non-object JSON');
	return EXIT_SUCCESS;
}

sub testInvalidMessageIsDiscarded {
	my ($self) = @_;
	plan tests => 2;

	my $sqs = FakeSignupSQS->new();
	my $message = FakeSignupMessage->new('not-json');
	Chleb::Workers::Signup::__processMessage({ sqs => $sqs, queue_url => 'queue-url' }, $message);

	is(scalar(@{ $sqs->{deleted} }), 1, 'invalid worker message is deleted');
	is($sqs->{deleted}->[0]->{ReceiptHandle}, 'receipt-1', 'invalid worker message uses its receipt handle');
	return EXIT_SUCCESS;
}

sub testSuccessfulMessageSendsVerificationUrlAndDeletesMessage {
	my ($self) = @_;
	plan tests => 5;

	my $directory = tempdir(CLEANUP => 1);
	my $capture = File::Spec->catfile($directory, 'mail.txt');
	my $swaks = File::Spec->catfile($directory, 'swaks');
	open(my $script, '>', $swaks) or die("Cannot create fake swaks: $ERRNO\n");
	print {$script} "#!/usr/bin/env perl\nlocal \$/; open(my \$output, '>', \$ENV{WORKER_MAIL_CAPTURE}); print {\$output} <STDIN>; close(\$output);\n";
	close($script) or die("Cannot close fake swaks: $ERRNO\n");
	chmod(0700, $swaks) or die("Cannot make fake swaks executable: $ERRNO\n");

	local $ENV{PATH} = "$directory:$ENV{PATH}";
	local $ENV{WORKER_MAIL_CAPTURE} = $capture;
	my $repository = FakeSignupRepository->new();
	my $sqs = FakeSignupSQS->new();
	my $message = FakeSignupMessage->new(encode_json({ account_id => 123, token_id => 7 }));
	Chleb::Workers::Signup::__processMessage({
		account_repository => $repository,
		mail_from => 'accounts@example.org',
		site_root => 'http://chleb-api.example.org',
		smtp => { host => 'smtp.example.org', password => 'secret', port => 587, username => 'user' },
		sqs => $sqs,
		time => FakeSignupTime->new(),
		queue_url => 'queue-url',
	}, $message);

	open(my $mail, '<', $capture) or die("Cannot read captured mail: $ERRNO\n");
	local $/ = undef;
	my $mailData = <$mail>;
	close($mail);
	my $verificationUrl = 'http://chleb-api.example.org/1/accounts/verify?account_id=123&token_id=7&token=verification-token';
	like($mailData, qr{\Q$verificationUrl\E}x,
		'worker email contains the account verification URL');
	ok(index($mailData, 'To: john.smith@example.com') >= 0, 'worker email contains the account email address');
	is(scalar(@{ $sqs->{deleted} }), 1, 'successfully delivered message is deleted');
	is($repository->{consumed}, 0, 'worker leaves token consumption to the verification endpoint');
	is($sqs->{deleted}->[0]->{QueueUrl}, 'queue-url', 'worker deletes from the configured queue');
	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

exit(SignupWorkerTests->new->run());

# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).
# All rights reserved.

package Chleb::Admin::SetPassword;
use strict;
use warnings;
use Carp qw(croak);
use POSIX qw(isatty);

use Chleb::Account::Password;
use JSON::PP qw(encode_json);
use Paws;

our $TABLE_ENV = 'CHLEB_ACCOUNTS_TABLE';
our $REGION_ENV = 'AWS_REGION';
our $DEFAULT_TABLE = 'chleb-accounts';
our $DEFAULT_REGION = 'eu-west-2';

=head1 NAME

Chleb::Admin::SetPassword

=head1 DESCRIPTION

Administrative command implementation for replacing an account password in
the DynamoDB backend.  This deliberately bypasses application authorization
and auditing and is intended only for backend administration.

=head1 FUNCTIONS

=over

=item C<run(@arguments)>

Prompt for a password and store its bcrypt hash for the account ID supplied in
C<@arguments>.  Return zero on success, two for invalid arguments, and one for
an operational failure.

=cut

sub run {
	my (@arguments) = @_;
	return __usage() unless (@arguments == 1);

	my $accountId = $arguments[0];
	unless (defined($accountId) && $accountId =~ m{\A[1-9][0-9]*\z}x) {
		print STDERR "Account ID must be a positive integer.\n";
		return 2;
	}

	my ($password, $repeatedPassword);
	my $readOk; $readOk = eval {
		$password = __readSecret('Password: ');
		$repeatedPassword = __readSecret('Repeat password: ');
		1;
	} or $readOk = 0;
	unless ($readOk) {
		print STDERR "Unable to read the password: $@";
		return 1;
	}

	if (!defined($password) || length($password) == 0) {
		print STDERR "Password must not be empty.\n";
		return 2;
	}
	if ($password ne $repeatedPassword) {
		print STDERR "Passwords do not match.\n";
		return 2;
	}

	my $passwordHash;
	my $hashOk; $hashOk = eval {
		$passwordHash = Chleb::Account::Password::hash($password);
		1;
	} or $hashOk = 0;
	$password = undef;
	$repeatedPassword = undef;
	unless ($hashOk) {
		print STDERR "Unable to hash the password: $@";
		return 1;
	}

	print STDERR "WARNING: This changes the DynamoDB backend directly and bypasses application authorization and auditing.\n";
	print STDERR "WARNING: Account $accountId password hash will be replaced.\n";

	my $updateOk; $updateOk = eval {
		my $response = __client()->UpdateItem(
			TableName => $ENV{$TABLE_ENV} // $DEFAULT_TABLE,
			Key => {
				pk => { S => "account#$accountId" },
				sk => { S => 'account' },
			},
			UpdateExpression => 'SET password_hash = :hash',
			ExpressionAttributeValues => { ':hash' => { S => $passwordHash } },
			ConditionExpression => 'attribute_exists(pk) AND attribute_exists(sk)',
			ReturnValues => 'ALL_NEW',
		);
		my $attributes = $response->Attributes->Map;
		print encode_json({
			id => __attributeValue($attributes->{id}),
			username => __attributeValue($attributes->{username}),
			status => __attributeValue($attributes->{status}),
		}) . "\n";
		1;
	} or $updateOk = 0;
	return 0 if ($updateOk);

	print STDERR "Unable to set account password: $@";
	return 1;
}

=back

=cut

sub __usage {
	print STDERR "Usage: admin-set-account-password.sh ACCOUNT_ID\n";
	return 2;
}

sub __readSecret {
	my ($prompt) = @_;
	print STDERR $prompt;
	my $silent = isatty(fileno(STDIN));
	system('stty', '-echo') if ($silent);
	my $value = '';
	sysread(STDIN, $value, 4096);
	system('stty', 'echo') if ($silent);
	print STDERR "\n" if ($silent);
	chomp($value) if (defined($value));
	return $value;
}

sub __client {
	return Paws->service('DynamoDB', region => $ENV{$REGION_ENV} // $DEFAULT_REGION);
}

sub __attributeValue {
	my ($attribute) = @_;
	return unless ($attribute);
	return $attribute->N if ($attribute->can('N'));
	return $attribute->S if ($attribute->can('S'));
	return;
}

1;

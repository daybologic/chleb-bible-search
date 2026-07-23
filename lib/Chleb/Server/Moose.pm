#!/usr/bin/perl
# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
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

package Chleb::Server::Moose;
use strict;
use warnings;
use Carp qw(croak);
use Moose;
use utf8;
binmode STDOUT, ":encoding(UTF-8)";

extends 'Chleb::Bible::Base';

=head1 NAME

Chleb::Server::Moose

=head1 DESCRIPTION

Moose portion of HTTP server facility used by L<Chleb::Server::Dancer2>

=cut

use Chleb;
use Chleb::Bible::Search::Query;
use Chleb::DI::Container;
use Chleb::Exception;
use Chleb::Generated::Info;
use Chleb::Server::Dampen;
use Chleb::Server::MediaType;
use Chleb::Type::Testament;
use Chleb::Utils;
use English qw(-no_match_vars);
use HTTP::Status qw(:constants);
use IO::File;
use JSON;
use Log::Log4perl::MDC;
use List::Util qw(shuffle);
use Readonly;
use Sys::Hostname;
use Time::Duration;
use Time::HiRes ();
use URI::Escape;
use UUID::Tiny ':std';

Readonly our $SEARCH_RESULTS_LIMIT => $Chleb::Bible::Search::Query::SEARCH_RESULTS_LIMIT;
Readonly our $CONTENT_TYPE_DEFAULT => $Chleb::Server::MediaType::CONTENT_TYPE_HTML;
Readonly our $SEARCH_RESULTS_MAX_PAGE_SIZE => 2_000;

Readonly my $FUNCTION_RANDOM => 1;
Readonly my $FUNCTION_VOTD => 2;
Readonly my $FUNCTION_LOOKUP => 3;

Readonly my $UPTIME_FILE_PATH => '/var/run/chleb-bible-search/startup.txt';
Readonly my $NS_VERSION => 'c0207fa6-6560-11f0-acec-43cf13408627';

=head1 METHODS

=over

=item C<BUILD()>

Book called after construction, by Moose.

=cut

sub BUILD {
	my ($self) = @_;

	$self->__removeUptime();

	return;
}

=item C<title()>

This should only be called once, and at server startup time.
There is no return value.

=cut

sub title {
	my ($self) = @_;

	$self->dic->logger->info(sprintf(
		'Started Chleb Bible Search %s (%s) on %s, built by %s@%s (%s/%s) with Perl %s at %s',
		$Chleb::VERSION,
		$Chleb::Generated::Info::BUILD_CHANGESET,
		hostname(),
		$Chleb::Generated::Info::BUILD_USER,
		$Chleb::Generated::Info::BUILD_HOST,
		$Chleb::Generated::Info::BUILD_OS,
		$Chleb::Generated::Info::BUILD_ARCH,
		$Chleb::Generated::Info::BUILD_PERL_VERSION,
		$Chleb::Generated::Info::BUILD_TIME,
	));

	$self->dic->logger->info(sprintf(
		"Server %s administrator: %s <%s>",
		$self->dic->config->get('server', 'domain', 'localhost'),
		$self->dic->config->get('server', 'admin_name', 'Unknown'),
		$self->dic->config->get('server', 'admin_email', 'example@example.org'),
	));

	return;
}

=item C<warmup()>

Warm backend caches before the PSGI server forks worker processes.  This lets
workers inherit hot in-process caches by copy-on-write, writes the
Storable-backed shared cache for future restarts, then marks startup ready by
creating the uptime file and logging server details.

=cut

sub warmup {
	my ($self) = @_;

	# Warm in the current (master) process, BEFORE the PSGI server forks its
	# workers, so that every worker inherits fully-populated in-process caches
	# via copy-on-write.  This previously ran in short-lived forked children
	# whose caches died with them, leaving the actual request-serving workers
	# cold: the first whole-chapter request in each worker then paid one
	# cache-miss round-trip per verse.  __warmBackendCaches() also primes the
	# Storable-backed shared cache as a side-effect, so warm data survives
	# restarts and late-spawned workers.
	my @bibles = $self->__library->getBibles({ translations => ['all'] });
	$self->dic->logger->info(sprintf('Backend cache warmup starting for %d translation(s) in master process', scalar(@bibles)));
	my $evalOk1; $evalOk1 = eval {
		$self->__warmBackendCaches();
		1;
	} or $evalOk1 = 0;
	if (my $evalError = $EVAL_ERROR) {
		$self->dic->logger->warn("Backend cache warmup failed: $evalError");
	}

	# The SQLite handle opened during warmup is not safe to share across the fork
	# the PSGI server is about to perform; drop it so each worker re-opens its
	# own.  The warmed in-memory caches are inherited intact.
	foreach my $bible (@bibles) {
		$bible->__backend->resetForkUnsafeHandles();
	}

	$self->__startupReady();

	return;
}

=back

=head1 PRIVATE METHODS

=over

=item C<__startupReady()>

Mark startup as complete after backend cache warmup has run.  This creates the
uptime file and logs the server title and administrator details.

=cut

sub __startupReady {
	my ($self) = @_;

	$self->__getUptime();
	$self->title();

	return;
}

=item C<__library()>

Server accessor for L<Chleb> itself; core library.
If the object has not yet been created, a new one is returned.

=cut

sub __library {
	my ($self) = @_;
	$self->{__library} ||= Chleb->new();
	return $self->{__library};
}

=item C<__warmBackendVerse($args)>

Prime the backend caches for one verse and update warmup progress.  The
C<$args> hash reference contains C<bible>, C<book>, C<chapterOrdinal>,
C<verse>, C<verseIndex>, C<verseCount>, C<processedVerses>, C<totalVerses>,
and C<lastPercent>.

=cut

sub __warmBackendVerse {
	my ($self, $args) = @_;
	my $bible = $args->{bible};
	my $book = $args->{book};
	my $chapterOrdinal = $args->{chapterOrdinal};
	my $verse = $args->{verse};
	my $verseOrdinal = $verse->{verse_ordinal} + 0;
	my $verseKey = join(':', $bible->translation, $book->shortNameRaw, $chapterOrdinal, $verseOrdinal);
	my $bookVerseKey = join(':', $bible->translation, $book->shortNameRaw, $verse->{book_ordinal} + 0);

	$bible->__backend->getVerseKeyByBookVerseKey($bookVerseKey);
	$bible->__backend->getVerseDataByKey($verseKey);
	$bible->__backend->getOrdinalByVerseKey($verseKey);
	${ $args->{processedVerses} }++;
	return if (
		$args->{verseIndex} != 1
		&& $args->{verseIndex} != $args->{verseCount}
		&& ($args->{verseIndex} % 1000) != 0
	);

	my $overallPercent = ($args->{totalVerses} > 0)
		? int((100 * ${ $args->{processedVerses} }) / $args->{totalVerses})
		: 100;
	my $progressPercent = int($overallPercent / 10) * 10;
	return if ($progressPercent == ${ $args->{lastPercent} });

	${ $args->{lastPercent} } = $progressPercent;
	$self->dic->logger->trace(sprintf(
		'Backend cache warmup %d%% complete (translation %s, book %s, chapter %d, verse %d)',
		$progressPercent,
		$bible->translation,
		$book->shortNameRaw,
		$chapterOrdinal,
		$verseOrdinal,
	));

	return;
}

sub __warmBackendCaches {
	my ($self, $warmBible) = @_;
	my $startTiming = Time::HiRes::time();
	my @bibles = defined($warmBible) ? ($warmBible) : shuffle($self->__library->getBibles({ translations => ['all'] }));
	my $totalVerses = 0;

	foreach my $bible (@bibles) {
		foreach my $book (@{ $bible->books() }) {
			foreach my $chapterOrdinal (1 .. $book->chapterCount) {
				my $chapter = $book->getChapterByOrdinal($chapterOrdinal, { nonFatal => 1 });
				unless ($chapter) {
					$self->dic->logger->warn(sprintf(
						'Skipping missing chapter %d in %s during backend cache warmup',
						$chapterOrdinal,
						$book->shortNameRaw,
					));
					next;
				}
				$totalVerses += $chapter->verseCount;
			}
		}
	}

	$self->dic->logger->info(sprintf('Backend cache warmup started for %d translation(s)', scalar(@bibles)));
	$self->dic->logger->debug(sprintf('Backend cache warmup will process %d verse(s)', $totalVerses));
	my $processedVerses = 0;
	my $lastPercent = -1;
	foreach my $bible (@bibles) {
		my $backend = $bible->__backend;
		$backend->deferSharedCacheWrites(1);
		my $translationStartTiming = Time::HiRes::time();
		$self->dic->logger->debug(sprintf('Backend cache warmup translation %s starting', $bible->translation));
		$self->dic->logger->trace(sprintf(
			'Backend cache warmup translation %s priming sentiment cache',
			$bible->translation,
		));
		$bible->__backend->primeSentimentCache();
		my @books = shuffle(@{ $bible->books() });
		foreach my $book (@books) {
			my $bookVerses = $bible->__backend->getBookVerseDataByKey($book->shortNameRaw);
			my %chapterVerses;
			foreach my $row (@{ $bookVerses // [ ] }) {
				push(@{ $chapterVerses{ $row->{chapter_ordinal} } }, $row);
			}
			my @chapterOrdinals = shuffle(1 .. $book->chapterCount);
			foreach my $chapterOrdinal (@chapterOrdinals) {
				$bible->__backend->getChapterVerseDataByKey($book->shortNameRaw, $chapterOrdinal);
				my @verses = shuffle(@{ $chapterVerses{$chapterOrdinal} // [ ] });
				my $verseCount = scalar(@verses);
				my $verseIndex = 0;
				foreach my $verse (@verses) {
					$verseIndex++;
					$self->__warmBackendVerse({
						bible           => $bible,
						book            => $book,
						chapterOrdinal  => $chapterOrdinal,
						verse           => $verse,
						verseIndex      => $verseIndex,
						verseCount      => $verseCount,
						processedVerses => \$processedVerses,
						totalVerses     => $totalVerses,
						lastPercent     => \$lastPercent,
					});
				}
			}
		}
		$backend->deferSharedCacheWrites(0);
		$backend->flushSharedCache();
		my $translationMsec = int(1000 * (Time::HiRes::time() - $translationStartTiming));
		$self->dic->logger->info(sprintf(
			'Backend cache warmup finished for translation %s in %d msec',
			$bible->translation,
			$translationMsec,
		));
	}
	my $totalMsec = int(1000 * (Time::HiRes::time() - $startTiming));
	$self->dic->logger->info(sprintf(
		'All backend cache warmup finished in %d msec',
		$totalMsec,
	));

	return;
}

=item C<__makeJsonApi()>

Return a new empty skeleton for a C<JSON:API> response, with all mandatory parts, ie.
with empty C<data>, C<included> and C<links> keys.

=cut

sub __makeJsonApi {
	return (
		data => [ ],
		included => [ ],
		links => { },
	);
}

=item C<__lookup($params)>

Given the user-supplied C<$params> (C<HASH>), we attempt to fetch a verse, or series of verses
which include links to the previous and next verses.

returns a an (C<ARRAY>) of C<JSON:API> C<HASH> es or throws a L<Chleb::Exception>.

The following C<$params> are required:

=over

=item C<book>

Numerical ordinal, short name, or long name for the sought book

=cut

=item C<chapter>

C<Mandatory>; Numerical chapter ordinal within C<book>

=cut

=item C<verse>

Numerical verse ordinal within C<chapter>

Optional; if not specified, we return the whole chapter.

=cut

=back

=cut

sub __isJsonContentType {
	my ($contentType) = @_;

	return (
		$contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_JSON
		|| $contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_JSON_API
	);
}

# Called by the Dancer2 routing layer.
sub __lookup { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self, $params) = @_;

	my $contentType = Chleb::Server::MediaType::acceptToContentType($params->{accept}, $CONTENT_TYPE_DEFAULT);

	my @verse = $self->__library->fetch($params->{book}, $params->{chapter}, $params->{verse}, $params);
	my $verseToJsonApiCache = { };

	my @json;
	for (my $verseI = 0; $verseI < scalar(@verse); $verseI++) {
		push(@json, __verseToJsonApi($verse[$verseI], $params, $verseToJsonApiCache));
		$json[$verseI]->{links}->{self} = '/' . join('/', 1, 'lookup', $verse[$verseI]->getPath())
		    . Chleb::Utils::queryParamsHelper($params);
	}

	for (my $jsonI = 1; $jsonI < scalar(@json); $jsonI++) {
		push(@{ $json[0]->{data} }, $json[$jsonI]->{data}->[0]);
	}

	my %pickVerseByType = (
		next  => sub { return $verse[0]->getNext() },
		prev  => sub { return $verse[0]->getPrev() },
		first => sub { return $verse[0]->chapter->getVerseByOrdinal(1) },
		last  => sub {
			my $chapterVerseCount = $verse[0]->chapter->verseCount;
			return $verse[0]->chapter->getVerseByOrdinal($chapterVerseCount);
		},
	);

	foreach my $type (qw(next prev first last)) {
		next unless ($json[0]->{data}->[0]->{links}->{$type});

		my $pickVerse = $pickVerseByType{$type}->();
		next unless ($pickVerse);

		$json[0]->{links}->{$type} = '/' . join('/', 1, 'lookup', $pickVerse->getPath())
		    . Chleb::Utils::queryParamsHelper($params);
	}

	if (__isJsonContentType($contentType)) {
		if ($params->{form}) {
			croak(Chleb::Exception->raise(
				HTTP_BAD_REQUEST,
				"form mode is only supported in $Chleb::Server::MediaType::CONTENT_TYPE_HTML mode",
			));
		}

		return \@json;
	} elsif ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
		return $self->__verseToHtml(\@verse, \@json, $FUNCTION_LOOKUP);
	}

	croak(Chleb::Exception->raise(
		HTTP_NOT_ACCEPTABLE,
		"Only $Chleb::Server::MediaType::CONTENT_TYPE_HTML and $Chleb::Server::MediaType::CONTENT_TYPE_JSON are supported",
	));
}

=item C<__random($params)>

Retrieve a verse at random, and return the C<JSON:API> structure from it.

Optionally, C<$params> (C<HASH>) may be supplied.

returns a C<JSON:API> (C<HASH>) or throw a L<Chleb::Exception>.

=cut

# Called by the Dancer2 routing layer.
sub __random { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self, $params) = @_;

	my $version = __versionFilter($params->{version}, 1, 2);
	my $redirect = $params->{redirect} // 0;

	my $contentType = Chleb::Server::MediaType::acceptToContentType($params->{accept}, $CONTENT_TYPE_DEFAULT);

	croak(Chleb::Exception->raise(HTTP_BAD_REQUEST, 'random redirect is only supported on version 1'))
	    if ($redirect && $version > 1);

	my $verse = $self->__library->random($params);
	if (ref($verse) eq 'ARRAY') {
		my @json;
		my $verseToJsonApiCache = { };

		for (my $verseI = 0; $verseI < scalar(@$verse); $verseI++) {
			push(@json, __verseToJsonApi($verse->[$verseI], $params, $verseToJsonApiCache));
		}

		my $secondary_total_msec = 0;
		for (my $verseI = 1; $verseI < scalar(@$verse); $verseI++) {
			push(@{ $json[0]->{data} },  $json[$verseI]->{data}->[0]);
			for (my $includedI = 0; $includedI < scalar(@{ $json[$verseI]->{included} }); $includedI++) {
				my $inclusion = $json[$verseI]->{included}->[$includedI];
				next if ($inclusion->{type} ne 'stats');
				$secondary_total_msec += $inclusion->{attributes}->{msec};
			}
		}

		for (my $includedI = 0; $includedI < scalar(@{ $json[0]->{included} }); $includedI++) {
			next if ($json[0]->{included}->[$includedI]->{type} ne 'stats');
			$json[0]->{included}->[$includedI]->{attributes}->{msec} += $secondary_total_msec;
		}

		$json[0]->{links}->{self} =  '/' . join('/', $version, 'random') . Chleb::Utils::queryParamsHelper($params);
		return $json[0] if (__isJsonContentType($contentType));

		if ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
			return $self->__verseToHtml($verse, \@json, $FUNCTION_RANDOM);
		} else {
			croak(Chleb::Exception->raise(HTTP_NOT_ACCEPTABLE, "Only $Chleb::Server::MediaType::CONTENT_TYPE_HTML is supported"));
		}
	}

	croak(Chleb::Exception->raise(
		HTTP_TEMPORARY_REDIRECT,
		'/1/lookup/' . join('/', lc($verse->book->shortName), $verse->chapter->ordinal, $verse->ordinal),
	)) if ($redirect);

	my $json = __verseToJsonApi($verse, $params);
	$json->{links}->{self} =  '/' . join('/', $version, 'random') . Chleb::Utils::queryParamsHelper($params);

	if ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
		return $self->__verseToHtml($verse, [$json], $FUNCTION_RANDOM);
	}

	if (__isJsonContentType($contentType)) {
		if ($params->{form}) {
			croak(Chleb::Exception->raise(
				HTTP_BAD_REQUEST,
				"form mode is only supported in $Chleb::Server::MediaType::CONTENT_TYPE_HTML mode",
			));
		}

		return $json;
	}

	croak(Chleb::Exception->raise(
		HTTP_NOT_ACCEPTABLE,
		"Only $Chleb::Server::MediaType::CONTENT_TYPE_HTML, $Chleb::Server::MediaType::CONTENT_TYPE_JSON_API and $Chleb::Server::MediaType::CONTENT_TYPE_JSON are supported",
	));

}

=item C<__votd($params)>

Retrieve the verse of the day, and return the C<JSON:API> structure for it.

Optionally, C<$params> (C<HASH>) may be supplied.

returns a C<JSON:API> (C<HASH>) or throw a L<Chleb::Exception>.

=cut

# Called by the Dancer2 routing layer.
sub __votd { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self, $params) = @_;

	my $version = $params->{version} || 1;
	my $redirect = $params->{redirect} // 0;

	my $contentType = Chleb::Server::MediaType::acceptToContentType($params->{accept}, $CONTENT_TYPE_DEFAULT);

	croak(Chleb::Exception->raise(HTTP_BAD_REQUEST, 'votd redirect is only supported on version 1'))
	    if ($redirect && $version > 1);

	my $verse = $self->__library->votd($params);
	if (ref($verse) eq 'ARRAY') {
		my @json;
		my $verseToJsonApiCache = { };

		for (my $verseI = 0; $verseI < scalar(@$verse); $verseI++) {
			push(@json, __verseToJsonApi($verse->[$verseI], $params, $verseToJsonApiCache));
		}

		my $secondary_total_msec = 0;
		for (my $verseI = 1; $verseI < scalar(@$verse); $verseI++) {
			push(@{ $json[0]->{data} },  $json[$verseI]->{data}->[0]);
			for (my $includedI = 0; $includedI < scalar(@{ $json[$verseI]->{included} }); $includedI++) {
				my $inclusion = $json[$verseI]->{included}->[$includedI];
				next if ($inclusion->{type} ne 'stats');
				$secondary_total_msec += $inclusion->{attributes}->{msec};
			}
		}

		for (my $includedI = 0; $includedI < scalar(@{ $json[0]->{included} }); $includedI++) {
			next if ($json[0]->{included}->[$includedI]->{type} ne 'stats');
			$json[0]->{included}->[$includedI]->{attributes}->{msec} += $secondary_total_msec;
		}

		$json[0]->{links}->{self} =  '/' . join('/', $version, 'votd') . Chleb::Utils::queryParamsHelper($params);

		if (__isJsonContentType($contentType)) {
			if ($params->{form}) {
				croak(Chleb::Exception->raise(
					HTTP_BAD_REQUEST,
					"form mode is only supported in $Chleb::Server::MediaType::CONTENT_TYPE_HTML mode",
				));
			}

			return $json[0];
		}

		if ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
			return $self->__verseToHtml($verse, \@json, $FUNCTION_VOTD);
		} else {
			croak(Chleb::Exception->raise(HTTP_NOT_ACCEPTABLE, "Only $Chleb::Server::MediaType::CONTENT_TYPE_HTML is supported"));
		}
	}

	croak(Chleb::Exception->raise(
		HTTP_TEMPORARY_REDIRECT,
		'/1/lookup/' . join('/', lc($verse->book->shortName), $verse->chapter->ordinal, $verse->ordinal),
	)) if ($redirect);

	my $json = __verseToJsonApi($verse, $params);
	$json->{links}->{self} =  '/' . join('/', $version, 'votd') . Chleb::Utils::queryParamsHelper($params);

	if ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
		return $self->__verseToHtml($verse, [$json], $FUNCTION_VOTD);
	}

	if (__isJsonContentType($contentType)) {
		if ($params->{form}) {
			croak(Chleb::Exception->raise(
				HTTP_BAD_REQUEST,
				"form mode is only supported in $Chleb::Server::MediaType::CONTENT_TYPE_HTML mode",
			));
		}

		return $json;
	}

	croak(Chleb::Exception->raise(
		HTTP_NOT_ACCEPTABLE,
		"Only $Chleb::Server::MediaType::CONTENT_TYPE_HTML, $Chleb::Server::MediaType::CONTENT_TYPE_JSON_API and $Chleb::Server::MediaType::CONTENT_TYPE_JSON are supported",
	));
}

=item C<__ping()>

Returns a simple C<JSON:API> structure which simply demonstrates that the server
is up and running.  The type of the C<data> element is a C<pong> response.  See
L<https://app.swaggerhub.com/apis/M6KVM/chleb-bible-search>.

=cut

# Called by the Dancer2 routing layer.
sub __ping { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self, $params) = @_;
	$params ||= {};
	my %hash = __makeJsonApi();

	my %attributes = (
		message => 'Ahoy-hoy!',
	);

	push(@{ $hash{data} }, {
		type => 'pong',
		id => uuid_to_string(create_uuid()),
		attributes => \%attributes,
	});

	my $contentType = Chleb::Server::MediaType::acceptToContentType(
		$params->{accept},
		$Chleb::Server::MediaType::CONTENT_TYPE_JSON,
	);

	if (__isJsonContentType($contentType)) {
		return \%hash;
	} elsif ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) {
		return __pingToHtml(\%attributes);
	}

	croak(Chleb::Exception->raise(
		HTTP_NOT_ACCEPTABLE,
		"Only $Chleb::Server::MediaType::CONTENT_TYPE_HTML and $Chleb::Server::MediaType::CONTENT_TYPE_JSON are supported",
	));
}

sub __pingToHtml {
	my ($attributes) = @_;

	my $html = __linkToHome();
	$html .= "<table class=\"info-table\">\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Message</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{message});
	$html .= "</tr>\r\n";
	$html .= "</table>\r\n";

	return $html;
}

=item C<__version()>

Returns a simple C<JSON:API> structure which contains information about the server version.
The type of the C<data> element is a C<version> response.  See
L<https://app.swaggerhub.com/apis/M6KVM/chleb-bible-search>.

This method may throw a L<Chleb::Exception> if the feature has been
disabled by the server administrator, or potentially, for any other reason.

=cut

# Called by the Dancer2 routing layer.
sub __version { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self, $params) = @_;
	$params ||= {};
	my %hash = __makeJsonApi();

	my $version = $Chleb::VERSION;

	return 403 unless ($self->dic->config->get('features', 'version', 'true', 1));

	my %attributes = (
		version => $version,
		admin_email => $self->dic->config->get('server', 'admin_email', 'example@example.org'),
		admin_name => $self->dic->config->get('server', 'admin_name', 'Unknown'),
		build_arch => $Chleb::Generated::Info::BUILD_ARCH,
		build_host => $Chleb::Generated::Info::BUILD_HOST,
		build_os => $Chleb::Generated::Info::BUILD_OS,
		build_time => $Chleb::Generated::Info::BUILD_TIME,
		build_user => $Chleb::Generated::Info::BUILD_USER,
		changeset => $Chleb::Generated::Info::BUILD_CHANGESET,
		perl_version => $Chleb::Generated::Info::BUILD_PERL_VERSION,
		server_host => $self->dic->config->get('server', 'domain', 'localhost'),
	);

	push(@{ $hash{data} }, {
		type => 'version',
		id => uuid_to_string(create_uuid(UUID_SHA1, $NS_VERSION, join('/', sort(values(%attributes))))),
		attributes => \%attributes,
	});

	my $contentType = Chleb::Server::MediaType::acceptToContentType(
		$params->{accept},
		$Chleb::Server::MediaType::CONTENT_TYPE_JSON,
	);

	if (__isJsonContentType($contentType)) {
		return \%hash;
	} elsif ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
		return __versionToHtml(\%attributes);
	}

	croak(Chleb::Exception->raise(
		HTTP_NOT_ACCEPTABLE,
		"Only $Chleb::Server::MediaType::CONTENT_TYPE_HTML and $Chleb::Server::MediaType::CONTENT_TYPE_JSON are supported",
	));
}

sub __versionToHtml {
	my ($attributes) = @_;

	my $html = __linkToHome();
	$html .= "<table class=\"info-table\">\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Version</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{version});
	$html .= "</tr>\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Git changeset</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{changeset});
	$html .= "</tr>\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Build time</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{build_time});
	$html .= "</tr>\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Build host</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{build_host});
	$html .= "</tr>\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Build OS</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{build_os});
	$html .= "</tr>\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Build architecture</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{build_arch});
	$html .= "</tr>\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Build user</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{build_user});
	$html .= "</tr>\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Perl version</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{perl_version});
	$html .= "</tr>\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Administrator</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{admin_name});
	$html .= "</tr>\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Admin email</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{admin_email});
	$html .= "</tr>\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Server host</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{server_host});
	$html .= "</tr>\r\n";
	$html .= "</table>\r\n";

	return $html;
}

=item C<__uptime()>

Returns a C<JSON:API> structure suitable for returning the server uptime.

=cut

# Called by the Dancer2 routing layer.
sub __uptime { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self, $params) = @_;
	$params ||= {};
	my %hash = __makeJsonApi();

	my $uptime = $self->__getUptime();
	my $uptimeText = duration_exact($uptime);

	push(@{ $hash{data} }, {
		type => 'uptime',
		id => uuid_to_string(create_uuid()),
		attributes => {
			uptime => $uptime,
			text => $uptimeText,
		},
	});

	my $contentType = Chleb::Server::MediaType::acceptToContentType(
		$params->{accept},
		$Chleb::Server::MediaType::CONTENT_TYPE_JSON,
	);

	if (__isJsonContentType($contentType)) {
		return \%hash;
	} elsif ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
		return __uptimeToHtml($uptime, $uptimeText);
	}

	croak(Chleb::Exception->raise(HTTP_NOT_ACCEPTABLE, "Only $Chleb::Server::MediaType::CONTENT_TYPE_HTML is supported"));
}

sub __uptimeToHtml {
	my ($uptime, $uptimeText) = @_;

	my $html = __linkToHome();
	$html .= "<table class=\"info-table\">\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Uptime</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $uptimeText);
	$html .= "</tr>\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Seconds</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $uptime);
	$html .= "</tr>\r\n";
	$html .= "</table>\r\n";

	return $html;
}

=item C<__search($search)>

Perform a search with various parameters and return a C<JSON:API> structure,
fully-populated with the requested page of results.

The following C<$params> (C<HASH>) are supported:

=over

=item C<limit>

A cap for the total number of search results to consider.

=item C<page>

The requested page number, whose default is C<1>.

=item C<per_page>

A limit for the number of results per page, whose default is C<50>.

=item C<wholeword>

Whether the C<term> shall be considered a wholeword, or the default, a sub-string.

=item C<term>

The text the user is searching for (critereon).

=back

=cut

# Called by the Dancer2 routing layer.
sub __search { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self, $search) = @_;

	my $limit = __searchLimit($search->{limit});
	my $page = __searchPage($search->{page});
	my $perPage = __searchPerPage($search->{per_page});
	my $offset = ($page - 1) * $perPage;

	my $wholeword = Chleb::Utils::boolean('wholeword', $search->{wholeword}, 0);

	my $contentType = Chleb::Server::MediaType::acceptToContentType($search->{accept}, $CONTENT_TYPE_DEFAULT);

	my @translations = @{ $search->{translations} || [] };
	if (grep { $_ eq 'all' } @translations) {
		@translations = $self->__library->availableTranslations();
	}
	my @queries;
	if (scalar(@translations) > 0) {
		foreach my $translation (@translations) {
			my %queryParams = (
				text => $search->{term},
				translations => [$translation],
			);
			$queryParams{bookShortName} = $search->{book}
				if (defined($search->{book}) && length($search->{book}) > 0);
			push(@queries, $self->__library->newSearchQuery(%queryParams)->setLimit($limit)->setWholeword($wholeword));
		}
	} else {
		my %queryParams = (text => $search->{term});
		$queryParams{bookShortName} = $search->{book}
			if (defined($search->{book}) && length($search->{book}) > 0);
		push(@queries, $self->__library->newSearchQuery(%queryParams));
		$queries[0]->setLimit($limit)->setWholeword($wholeword);
	}

	my @allVerses;
	my $resultsMsec = 0;
	foreach my $query (@queries) {
		my $results = $query->run();
		push(@allVerses, @{ $results->verses });
		$resultsMsec += $results->msec;
	}
	splice(@allVerses, $limit);
	my $query = $queries[0];
	my $totalCount = scalar(@allVerses);
	my @pageVerses = @allVerses;
	splice(@pageVerses, 0, $offset);
	splice(@pageVerses, $perPage);
	my $pageCount = scalar(@pageVerses);
	my $totalPages = $totalCount > 0 ? int(($totalCount + $perPage - 1) / $perPage) : 1;

	my %hash = __makeJsonApi();

	for (my $i = 0; $i < $pageCount; $i++) {
		my $verse = $pageVerses[$i];

		my %attributes = ( %{ $verse->TO_JSON() } );
		$attributes{title} = sprintf("Result %d/%d from Chleb Bible Search '%s'", $offset + $i + 1, $totalCount, $query->text);
		$attributes{year} = $verse->book->bible->year();

		push(@{ $hash{included} }, {
			type => $verse->chapter->type,
			id => $verse->chapter->id,
			attributes => $verse->chapter->TO_JSON(),
			relationships => {
				book => {
					data => {
						type => $verse->book->type,
						id => $verse->book->id,
					},
				}
			},
		});

		push(@{ $hash{included} }, {
			type => $verse->book->type,
			id => $verse->book->id,
			attributes => $verse->book->TO_JSON(),
			relationships => { },
		});

		push(@{ $hash{data} }, {
			type => $verse->type,
			id => $verse->id,
			attributes => \%attributes,
			relationships => {
				chapter => {
					links => { },
					data => {
						type => $verse->chapter->type,
						id => $verse->chapter->id,
					},
				},
				book => {
					links => { },
					data => {
						type => $verse->book->type,
						id => $verse->book->id,
					},
				},
			},
		});
	}

	push(@{ $hash{included} },
		{
			type => 'results_summary',
			id => uuid_to_string(create_uuid()),
			attributes => {
				count       => $pageCount,
				page        => $page,
				per_page    => $perPage,
				total_count => $totalCount,
				total_pages => $totalPages,
			},
			links => { },
		},
		{
			type => 'stats',
			id => uuid_to_string(create_uuid()),
			attributes => {
				msec => int($resultsMsec),
			},
			links => { },
		},
	);

	my %paginationParams = (
		form        => $search->{form},
		limit       => $limit,
		page        => $page,
		per_page    => $perPage,
		book        => $search->{book},
		term        => $query->text,
		translations => \@translations,
		total_pages => $totalPages,
		wholeword   => $wholeword,
	);

	my $paginationLinks = __searchPaginationLinks(\%paginationParams);
	foreach my $name (keys(%$paginationLinks)) {
		$hash{links}->{$name} = $paginationLinks->{$name};
	}

	if (__isJsonContentType($contentType)) {
		if ($search->{form}) {
			croak(Chleb::Exception->raise(
				HTTP_BAD_REQUEST,
				"form mode is only supported in $Chleb::Server::MediaType::CONTENT_TYPE_HTML mode",
			));
		}

		return (\%hash, \%hash);
	} elsif ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
		my $html = __searchResultsToHtml(\%hash, { includeHome => !$search->{form} });
		return ($html, \%hash);
	}

	croak(Chleb::Exception->raise(HTTP_NOT_ACCEPTABLE, "Only $Chleb::Server::MediaType::CONTENT_TYPE_HTML is supported"));
}

=item C<__searchLimit($limit)>

Normalises the total search result cap.

C<$limit> is a user supplied value from the C<limit> query parameter.  Positive
integer values are returned as integers.  Missing, non-numeric, and values below
C<1> fall back to the default search result limit.

=cut

sub __searchLimit {
	my ($limit) = @_;

	return $SEARCH_RESULTS_LIMIT unless (defined($limit) && $limit =~ m{ \A[0-9]+\z }x);
	$limit = int($limit);
	return $SEARCH_RESULTS_LIMIT if ($limit < 1);
	return $limit;
}

=item C<__searchPage($page)>

Normalises a requested search result page number.

C<$page> is a user supplied value from the C<page> query parameter.  Positive
integer values are returned as integers.  Missing, non-numeric, and values below
C<1> resolve to the first page.

=cut

sub __searchPage {
	my ($page) = @_;

	return 1 unless (defined($page) && $page =~ m{ \A-?[0-9]+\z }x);
	$page = int($page);
	return $page < 1 ? 1 : $page;
}

=item C<__searchPerPage($perPage)>

Normalises the search result page size.

C<$perPage> is a user supplied value from the C<per_page> query parameter.
Positive integer values are returned as integers, capped at
C<$SEARCH_RESULTS_MAX_PAGE_SIZE>.  Missing, non-numeric, and values below C<1>
fall back to the default search result limit.

=cut

sub __searchPerPage {
	my ($perPage) = @_;

	return $SEARCH_RESULTS_LIMIT unless (defined($perPage) && $perPage =~ m{ \A[0-9]+\z }x);
	$perPage = int($perPage);
	return $SEARCH_RESULTS_LIMIT if ($perPage < 1);
	return $SEARCH_RESULTS_MAX_PAGE_SIZE if ($perPage > $SEARCH_RESULTS_MAX_PAGE_SIZE);
	return $perPage;
}

=item C<__searchPaginationLinks($params)>

Builds stateless pagination links for a search result page.

C<$params> is a C<HASH> reference containing the current search term, wholeword
flag, total limit, page size, current page, total pages, and optional form mode.
The returned C<HASH> reference always contains C<first>, C<last>, and C<self>
links.  C<prev> and C<next> are included only when the current page has a
previous or next page.

=cut

sub __searchPaginationLinks {
	my ($params) = @_;

	my $page = $params->{page};
	my $totalPages = $params->{total_pages};
	my %links = (
		first => __searchPageLink($params, 1),
		last  => __searchPageLink($params, $totalPages),
		self  => __searchPageLink($params, $page),
	);

	$links{prev} = __searchPageLink($params, $page - 1) if ($page > 1);
	$links{next} = __searchPageLink($params, $page + 1) if ($page < $totalPages);

	return \%links;
}

=item C<__searchPageLink($params, $page)>

Builds a single search page URL.

C<$params> is the same C<HASH> reference passed to
L</__searchPaginationLinks($params)>.  C<$page> is the page number to place in
the generated URL.  The URL preserves the search term, wholeword flag, total
limit, page size, and form mode so each page request remains stateless.

=cut

sub __searchPageLink {
	my ($params, $page) = @_;

	my @parts = (
		'term=' . uri_escape($params->{term}),
		'wholeword=' . uri_escape($params->{wholeword}),
		'limit=' . uri_escape($params->{limit}),
		'page=' . uri_escape($page),
		'per_page=' . uri_escape($params->{per_page}),
	);
	push(@parts, 'book=' . uri_escape($params->{book})) if (defined($params->{book}) && length($params->{book}) > 0);
	if (ref($params->{translations}) eq 'ARRAY' && scalar(@{ $params->{translations} }) > 0) {
		push(@parts, 'translations=' . uri_escape(join(',', @{ $params->{translations} })));
	}
	push(@parts, 'form=true') if ($params->{form});

	return '/1/search?' . join('&', @parts);
}

=item C<__info($params)>

Return information about the data we are serving as a C<JSON:API> structure.

returns a C<JSON:API> (C<HASH>) or throw a L<Chleb::Exception>.

=cut

# Called by the Dancer2 routing layer.
sub __info { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self, $params) = @_;

	my $startTiming = Time::HiRes::time();

	my $contentType = Chleb::Server::MediaType::acceptToContentType($params->{accept}, $Chleb::Server::MediaType::CONTENT_TYPE_HTML);

	my $info = $self->__library->info();
	my %hash = __makeJsonApi();

	my (@bookShortNames, @bookShortNamesRaw, @bookLongNames);
	my %uniqueBookNames = ( );
	foreach my $bible (@{ $info->bibles }) { # translations
		my %bibleAttributes = %{ $bible->TO_JSON() };
		$bibleAttributes{year} = $bible->year();
		push(@{ $hash{included} }, {
			id => $bible->id,
			type => $bible->type,
			attributes => \%bibleAttributes,
		});
		foreach my $book (@{ $bible->books }) {
			my $isNewBookName = (++$uniqueBookNames{ $book->shortName } == 1);
			if ($isNewBookName) {
				push(@bookShortNames, $book->shortName);
				push(@bookShortNamesRaw, $book->shortNameRaw);
				push(@bookLongNames, $book->longName);
			}

			push(@{ $hash{included} }, {
				id => $book->id,
				type => $book->type,
				attributes => $book->TO_JSON(),
			});

			for (my $chapterOrdinal = 1; $chapterOrdinal <= $book->chapterCount; $chapterOrdinal++) {
				my $chapter = $book->getChapterByOrdinal($chapterOrdinal, { nonFatal => 1 });
				unless ($chapter) {
					$self->dic->logger->warn(sprintf(
						'Skipping missing chapter %d in %s while building info response',
						$chapterOrdinal,
						$book->shortNameRaw,
					));
					next;
				}
				push(@{ $hash{included} }, {
					id => $chapter->id,
					type => $chapter->type,
					attributes => $chapter->TO_JSON(),
				});
			}
		}
	}

	my @translations = map { $_->translation } @{ $info->bibles };

	push(@{ $hash{data} }, {
		type => $info->type,
		id => $info->id,
		attributes => {
			translation_count => scalar(@{ $info->bibles }),
			translations => \@translations,
			book_count => scalar(@bookShortNames),
			book_names_long => \@bookLongNames,
			book_names_short => \@bookShortNames,
			book_names_short_raw => \@bookShortNamesRaw,
		},
	});

	my $version = 1;
	$hash{links}->{self} = '/' . join('/', $version, 'info');

	my $endTiming = Time::HiRes::time();
	my $msec = int(1000 * ($endTiming - $startTiming));
	$info->msec($msec); # override library figure, incorporate everything

	push(@{ $hash{included} }, {
		type => 'stats',
		id => uuid_to_string(create_uuid()),
		attributes => {
			msec => int($info->msec),
		},
		links => { },
	});

	if (__isJsonContentType($contentType)) {
		return \%hash;
	} elsif ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
		return __infoToHtml(\%hash);
	}

	croak(Chleb::Exception->raise(HTTP_NOT_ACCEPTABLE, 'Not acceptable here'));
}

=item C<__getUptime()>

Return the number of seconds the server has been running.

=cut

sub __getUptime {
	my ($self) = @_;
	my $uptimeFilePath = $self->__uptimeFilePath();
	my $startTime = $self->dic->time->get();
	if (my $fh = IO::File->new($uptimeFilePath, 'r')) {
		$startTime = <$fh>;
		chomp($startTime);
		$startTime = int($startTime); # don't trust the file too much
	} elsif ($fh = IO::File->new($uptimeFilePath, 'w')) {
		print($fh "$startTime\n");
	}

	return $self->dic->time->get() - $startTime;
}

sub __uptimeFilePath {
	my ($self) = @_;
	return $self->dic->config->get('server', 'uptime_file', $UPTIME_FILE_PATH);
}

=back

=head1 C<PRIVATE FUNCTIONS>

=over

=item C<__verseToJsonApi($verse, $params, [$cache])>

Take the given C<$verse> (L<Chleb::Bible::Verse>) and optional C<$params> (C<HASH>)
and produce the user-facing C<JSON:API> response (C<HASH>).  Shared logic used by
multiple results-orientated server methods.

=cut

sub __verseToJsonApi {
	my ($verse, $params, $cache) = @_;
	$cache ||= { };
	my %hash = __makeJsonApi();
	my $bookId = $verse->book->id;
	my $chapterId = $verse->chapter->id;
	my $bookAttributes = $cache->{book_attributes}->{$bookId} //= $verse->book->TO_JSON();
	my $chapterAttributes = $cache->{chapter_attributes}->{$chapterId} //= $verse->chapter->TO_JSON();

	push(@{ $hash{included} }, {
		type => $verse->chapter->type,
		id => $chapterId,
		attributes => $chapterAttributes,
		relationships => {
			book => {
				data => {
					type => $verse->book->type,
					id => $bookId,
				},
			}
		},
	});

	push(@{ $hash{included} }, {
		type => $verse->book->type,
		id => $bookId,
		attributes => $bookAttributes,
		relationships => { },
	});

	my $dic = Chleb::DI::Container->instance;
	push(@{ $hash{included} }, {
		type => 'stats',
		id => uuid_to_string(create_uuid()),
		attributes => {
			msec => int($verse->msec),
		},
		links => { },
	});

	my %paramsLocal = ( );
	%paramsLocal = %$params if ($params);
	$paramsLocal{translations} = [ $verse->book->bible->translation ] if ($paramsLocal{translations});
	my $queryParams = Chleb::Utils::queryParamsHelper(\%paramsLocal);
	my %verseAttributes = %{ $verse->TO_JSON() };
	$verseAttributes{year} = $verse->book->bible->year();

	my %links = (
		# TODO: But should it be 'votd' unless redirect was requested?  Which isn't supported yet
		self => '/' . join('/', 1, 'lookup', $verse->getPath()) . $queryParams,
	);

	if (my $nextVerse = $verse->getNext()) {
		$links{next} = '/' . join('/', 1, 'lookup', $nextVerse->getPath()) . $queryParams;
	}

	if (my $prevVerse = $verse->getPrev()) {
		$links{prev} = '/' . join('/', 1, 'lookup', $prevVerse->getPath()) . $queryParams;
	}

	my $chapterLinkCacheKey = join(':', $chapterId, $queryParams);
	my $chapterLinkCache = $cache->{chapter_links}->{$chapterLinkCacheKey};
	if (!$chapterLinkCache) {
		$chapterLinkCache = {
			first => '/' . join('/', 1, 'lookup', $verse->chapter->getVerseByOrdinal(1)->getPath())
			    . Chleb::Utils::queryParamsHelper($params),
			last => '/' . join('/', 1, 'lookup', $verse->chapter->getVerseByOrdinal($verse->chapter->verseCount)->getPath())
			    . Chleb::Utils::queryParamsHelper($params),
		};
		$cache->{chapter_links}->{$chapterLinkCacheKey} = $chapterLinkCache;
	}
	$links{first} = $chapterLinkCache->{first};
	$links{last} = $chapterLinkCache->{last};

	push(@{ $hash{data} }, {
		type => $verse->type,
		id => $verse->id,
		attributes => \%verseAttributes,
		links => \%links,
		relationships => {
			chapter => {
				links => {
					# TODO: It should be possible to look up an entire chapter
					#self => '/' . join('/', 1, 'lookup', $verse->chapter->id),
				},
				data => {
					type => $verse->chapter->type,
					id => $verse->chapter->id,
				},
			},
			book => {
				links => {
					# TODO: It should be possible to look up an entire book
					#self => '/' . join('/', 1, 'lookup', $verse->book->id),
				},
				data => {
					type => $verse->book->type,
					id => $verse->book->id,
				},
			},
		},
	});

	return \%hash;
}

=item C<__verseNavigationLink($json, $type, $label)>

Build an HTML link for the verse navigation bar.

C<$json> is a C<JSON:API> response hash for a verse page.  C<$type> is one of
the verse link names such as C<prev>, C<next>, or C<self>.  C<$label> is the
visible link text.

The generated link keeps the concrete lookup path from the verse item and, when
the response has a query string, applies that query string to preserve selected
translations across HTML navigation.  If the requested link does not exist, an
empty string is returned.

=cut

sub __verseNavigationLink {
	my ($json, $type, $label) = @_;

	my $link = $json->{data}->[0]->{links}->{$type};
	return '' unless ($link);

	my $selfLink = $json->{links}->{self} || '';
	if ($selfLink =~ m{ (\?.*)\z }x) {
		my $query = $1;
		$link =~ s{\?.*\z}{}x;
		$link .= $query;
	}

	return '<a class="vn-link vn-verse" href="' . $link . '">' . $label . '</a>';
}

=item C<__verseNavigationQuery($json)>

Return the query string from the JSON response's self link for use by
navigation links which are otherwise specific to HTML presentation.

=cut

sub __verseNavigationQuery {
	my ($json) = @_;

	my $selfLink = $json->{links}->{self} || '';
	if ($selfLink =~ m{ (\?.*)\z }x) {
		return $1;
	}

	return '';
}

=item C<__verseToHtml($verse, $json, $function)>

Render a verse response as the HTML verse page, including translation cards and
book, chapter, and verse navigation.

=cut

sub __verseToHtml {
	my ($self, $verse, $json, $function) = @_;

	my $verseHtmlData = __verseHtmlData($verse, $json);
	my $reference = $verseHtmlData->{reference};
	my $title = 'FIXME';
	if ($function == $FUNCTION_RANDOM) {
		$title = 'Random Verse';
	} elsif ($function == $FUNCTION_VOTD) {
		$title = 'Verse of The Day';
	} else {
		$title = 'Lookup';
	}
	my $pageTitle = "Chleb Bible Search - ${title}";
	my $output = __verseHtmlCards($verseHtmlData, $pageTitle);

	my $random;
	{
		my $pattern = "<a class=\"vn-link vn-chapter\" href=\"%s\">%s</a>";
		if ($function == $FUNCTION_RANDOM) {
			#$random = sprintf($pattern, $json->[0]->{links}->{self}, 'another'); # FIXME: because testament is '' which is invalid
			$random = sprintf($pattern, '/2/random', 'another'); # FIXME: use self link, once it works
		} else {
			$random = sprintf($pattern, '/2/random', 'random');
		}
	}

	my $firstVerseObject = $verse;
	$firstVerseObject = $firstVerseObject->[0] if (ref($firstVerseObject) eq 'ARRAY');
	my $navigationQuery = __verseNavigationQuery($json->[0]);

	my $prevBookLink = '';
	if (my $prevBook = $firstVerseObject->book->getPrev()) {
		$prevBookLink = '<a class="vn-link vn-book" href="/1/lookup/' . $prevBook->getPath() . '/1' . $navigationQuery . '">prev book</a>';
	}

	my $prevChapterLink = '';
	if (my $prevChapter = $firstVerseObject->chapter->getPrev()) {
		$prevChapterLink = '<a class="vn-link vn-chapter" href="/1/lookup/' . $prevChapter->getPath() . $navigationQuery . '">prev chapter</a>';
	}

	my $nextBookLink = '';
	if (my $nextBook = $firstVerseObject->book->getNext()) {
		$nextBookLink = '<a class="vn-link vn-book" href="/1/lookup/' . $nextBook->getPath() . '/1' . $navigationQuery . '">next book</a>';
	}

	my $nextChapterLink = '';
	if (my $nextChapter = $firstVerseObject->chapter->getNext()) {
		$nextChapterLink = '<a class="vn-link vn-chapter" href="/1/lookup/' . $nextChapter->getPath() . $navigationQuery . '">next chapter</a>';
	}

	my $lastChapterLink = '';
	my $chapterCount = $firstVerseObject->book->chapterCount;
	my @chapters = ( );
	for (my $chapterOrdinal = 1; $chapterOrdinal <= $firstVerseObject->book->chapterCount; $chapterOrdinal++) {
		if (my $chapter = $firstVerseObject->book->getChapterByOrdinal($chapterOrdinal, { nonFatal => 1 })) {
			push(@chapters, $chapter);
		} else {
			$self->dic->logger->error("Can't get chapter $chapterCount from book " . $firstVerseObject->book->shortName
				. 'even though it logically exists, so LAST_CHAPTER_URL will be broken');
		}
	}

	if ($firstVerseObject->chapter->ordinal < $chapterCount) {
		my $lastChapter = $chapters[-1];
		$lastChapterLink = '<a class="vn-link vn-chapter" href="/1/lookup/' . $lastChapter->getPath() . $navigationQuery . '">last chapter</a>';
	}

	my $bookLinkFormat = '<a class="vn-link vn-book" href="/1/lookup/' . $firstVerseObject->book->getPath() . '/1' . $navigationQuery . '">%s</a>';

	my $browsingLeft;
	{
		my $chapterLinks = '';
		my $bible = $firstVerseObject->book->bible;
		my $chapterName = $bible->getProperty('chapter_name');
		my $chapterNamePlural = $bible->getProperty('chapter_name_plural') // 'Chapters';
		foreach my $chapter (@chapters) {
			my $classCurrent = '';
			if ($chapter->ordinal == $firstVerseObject->chapter->ordinal) {
				$classCurrent = 'class="current" ';
			}
			$chapterLinks .= sprintf('<a %shref="/1/lookup/%s%s">%s %d</a><br />', $classCurrent, $chapter->getPath(), $navigationQuery,
				(defined($chapterName) && length($chapterName) > 0 ? $chapterName : $chapter->book->shortNameRaw),
				$chapter->ordinal);
		}
		$browsingLeft = Chleb::Server::Dancer2::fetchStaticPage('browsing_left', {
			CHAPTER_LINKS     => $chapterLinks,
			CHAPTER_NAV_TITLE => $chapterNamePlural,
		});
	}

	my $thisChapter = $json->[0]->{data}->[0]->{links}->{first};
	$self->dic->logger->trace("Link kludge in effect (pre): ${thisChapter}");
	my $thisChapter_KLUDGE = $thisChapter;
	$thisChapter_KLUDGE =~ s@/1(?=\?)@@x; # TODO: This is a kludge, the JSON should provide it somehow.
	if ($thisChapter_KLUDGE eq $thisChapter) {
		$thisChapter_KLUDGE =~ s@/1$@@x; # TODO: This is a kludge, the JSON should provide it somehow.
	}
	$self->dic->logger->trace("Link kludge in effect (post): ${thisChapter_KLUDGE}");
	my $settingsLink = '<a class="vn-link vn-settings" href="/settings" title="Settings" aria-label="Settings">'
		. '<span class="vn-settings-icon" aria-hidden="true">⚙</span>'
		. '<span class="vn-settings-text"> Settings</span></a>';

	my $browsingHead = Chleb::Server::Dancer2::fetchStaticPage('browsing_head', {
		PREV_BOOK_URL => $prevBookLink,
		PREV_CHAPTER_URL => $prevChapterLink,
		HOME_URL => __linkToHome(),
		BOOK_URL => sprintf($bookLinkFormat, 'book index'),
		CHAPTER_URL => '<a class="vn-link vn-chapter" href="' . $thisChapter_KLUDGE . '">this chapter</a>',
		NEXT_CHAPTER_URL => $nextChapterLink,
		NEXT_BOOK_URL => $nextBookLink,
		PERMALINK_URL => __verseNavigationLink($json->[0], 'self', 'permalink'),
		SETTINGS_URL => $settingsLink,
		FIRST_VERSE_URL => __verseNavigationLink($json->[0], 'first', 'first verse'),
		FIRST_CHAPTER_URL => sprintf($bookLinkFormat, 'first chapter'),
		LAST_CHAPTER_URL => $lastChapterLink,
		PREV_VERSE_URL => __verseNavigationLink($json->[0], 'prev', 'prev verse'),
		NEXT_VERSE_URL => __verseNavigationLink($json->[0], 'next', 'next verse'),
		LAST_VERSE_URL => __verseNavigationLink($json->[0], 'last', 'last verse'),
		RANDOM_URL => $random,
		BOOKS => $self->__makeBooks($firstVerseObject->book),
	});

	return Chleb::Server::Dancer2::fetchStaticPage('verse', {
		TITLE => $pageTitle,
		REFERENCE => $reference,
		HOME => __linkToHome(),
		VERSES => $output,
		BROWSING_LEFT => $browsingLeft,
		BROWSING_HEAD => $browsingHead,
	});
}

=item C<__verseHtmlData($verse, $json)>

Collect the verse reference and translation sections used by the HTML renderer.
The order in which translations first appear is retained for card rendering.

=cut

sub __verseHtmlData {
	my ($verse, $json) = @_;

	my $includedCount = scalar(@{ $json->[0]->{included} });
	my %rawBookNameMap = ( );
	for (my $includedIndex = 0; $includedIndex < $includedCount; $includedIndex++) {
		my $includedItem = $json->[0]->{included}->[$includedIndex];
		my $type = $includedItem->{type};
		next if ($type ne 'book');

		$rawBookNameMap{ $includedItem->{attributes}->{short_name} }
		    = $includedItem->{attributes}->{short_name_raw};
	}

	my $verseCount = scalar(@{ $json->[0]->{data} });
	my $reference;
	my @translationOrder;
	my %translationSections;
	for (my $verseIndex = 0; $verseIndex < $verseCount; $verseIndex++) {
		my $attributes = $json->[0]->{data}->[$verseIndex]->{attributes};
		my $bookName = $attributes->{book};
		my $thisVerse = (ref($verse) eq 'ARRAY') ? $verse->[$verseIndex] : $verse;
		my $bookNameRaw = $rawBookNameMap{$bookName} // $thisVerse->book->shortNameRaw;
		my $chapter = $attributes->{chapter};
		my $verseOrdinal = $attributes->{ordinal};
		my $translation = $attributes->{translation};

		if ($verseIndex == 0) {
			$reference = sprintf('%s %d:%d', $bookNameRaw, $chapter, $verseOrdinal);
		}

		if (!exists($translationSections{$translation})) {
			push(@translationOrder, $translation);
			$translationSections{$translation} = {
				emotion => $attributes->{emotion},
				html => '',
				last_continues => 0,
				reference => sprintf('%s %d:%d', $bookNameRaw, $chapter, $verseOrdinal),
				tones => [],
				year => $thisVerse->book->bible->year(),
				verse_count => 0,
			};
		}

		my $section = $translationSections{$translation};
		if ($section->{verse_count} > 0) {
			$section->{html} .= '<br /><br />' unless ($section->{last_continues});
			$section->{html} .= "\r\n";
			$section->{html} .= '<sup class="versenum">';
			my $verseLink = $json->[0]->{data}->[$verseIndex]->{links}->{self};
			$section->{html} .= sprintf('<a href="%s">', $verseLink);
			$section->{html} .= "${verseOrdinal} </a></sup>";
		}

		$section->{html} .= $attributes->{text};

		$section->{last_continues} = $thisVerse->continues ? 1 : 0;
		foreach my $tone (@{ $attributes->{tones} }) {
			push(@{ $section->{tones} }, $tone);
		}
		$section->{verse_count}++;
	}

	return {
		reference => $reference,
		translationOrder => \@translationOrder,
		translationSections => \%translationSections,
	};
}

=item C<__verseHtmlCards($data, $pageTitle)>

Render the ordered translation sections as HTML cards.

=cut

sub __verseHtmlCards {
	my ($data, $pageTitle) = @_;
	my $output = '';
	foreach my $translation (@{ $data->{translationOrder} }) {
		my $section = $data->{translationSections}->{$translation};
		my $translationLabel = lc($translation);
		$translationLabel .= sprintf(' (%d)', $section->{year}) if (defined($section->{year}));
		my $sentiments = '';
		my %toneSeen;

		foreach my $sentiment ($section->{emotion}, @{ $section->{tones} }) {
			next if ($toneSeen{$sentiment});
			my $colorIndex = Chleb::Utils::colorIndexFromWord($sentiment);
			$sentiments .= "<span class=\"tag tag-color-${colorIndex}\">$sentiment</span> ";
			$toneSeen{$sentiment}++;
		}

		$output .= "\t\t\t\t\t\t<div class=\"card\">\n";
		$output .= "\t\t\t\t\t\t\t<div class=\"subtitle\">$pageTitle</div>\n";
		$output .= "\n";
		$output .= "\t\t\t\t\t\t\t<h1>$section->{reference}</h1>\n";
		$output .= "\t\t\t\t\t\t\t<div class=\"translation\">$translationLabel</div>\n";
		$output .= "\n";
		$output .= "\t\t\t\t\t\t\t<div>\n";
		$output .= "\t\t\t\t\t\t\t\t<blockquote>\n";
		$output .= "\t\t\t\t\t\t\t\t\t" . $section->{html} . "\n";
		$output .= "\t\t\t\t\t\t\t\t</blockquote>\n";
		$output .= "\t\t\t\t\t\t\t</div>\n";
		$output .= "\n";
		$output .= "\t\t\t\t\t\t\t<div>\n";
		$output .= "\t\t\t\t\t\t\t\t<blockquote>\n";
		$output .= "\t\t\t\t\t\t\t\t\t$sentiments\n";
		$output .= "\t\t\t\t\t\t\t\t</blockquote>\n";
		$output .= "\t\t\t\t\t\t\t</div>\n";
		$output .= "\t\t\t\t\t\t</div>\n";
	}

	return $output;
}

sub __makeBooks {
	my ($self, $currentBook) = @_;

	my $currentTranslation = $currentBook ? $currentBook->bible->translation : '';
	my $currentBookName = $currentBook ? $currentBook->shortName : Chleb::Server::Dancer2::getParam('book');
	my $books = $currentBook ? $currentBook->bible->books : [];
	my @translations = $self->__library->availableTranslations();
	my @translationOptions = map { $self->__makeTranslationOption($_, $currentTranslation) } @translations;
	my @options = ( );
	foreach my $book (@$books) {
		my $isSelected = (defined($currentBookName) && $currentBookName eq $book->shortName);
		push(@options, sprintf('<option value="%s"%s>%s (%d)</option>',
			$book->shortName,
			($isSelected ? ' selected' : ''),
			$book->longName,
			$book->chapterCount,
		));
	}

	my $html = "<form class=\"verse-book-form\" action=\"/1/lookup\" method=\"GET\">\n"
		. "                <select id=\"verse-nav-translation\" name=\"translations\" aria-label=\"Translation\">\n"
		. join("\r\n", @translationOptions)
		. "\n                </select>\n"
		. "                <select id=\"verse-nav-book\" name=\"book\" aria-label=\"Book\">\n"
		. '        ';

	$html .= join("\r\n", @options)
		. "</select>\n"
		. "                <input type=\"hidden\" name=\"chapter\" value=\"1\">\n"
		. "                <input type=\"hidden\" name=\"navigation\" value=\"1\">\n"
		. "                <button type=\"submit\">Select</button>\n"
		. "        </form>\n"
		. "        <script>\n"
		. "                (function () {\n"
		. "                        var translation = document.getElementById('verse-nav-translation');\n"
		. "                        var book = document.getElementById('verse-nav-book');\n"
		. "                        var selectedBook = " . JSON::to_json($currentBookName // '') . ";\n"
		. "                        var isKindleBrowser = /Kindle|Silk/i.test(navigator.userAgent || '');\n"
		. "                        var booksByTranslation = {};\n"
		. "                        var booksLoaded = false;\n"
		. "                        var translationChangePending = false;\n"
		. "                        function populateBooks() {\n"
		. "                                var books = booksByTranslation[translation.value] || [];\n"
		. "                                book.innerHTML = '';\n"
		. "                                books.forEach(function (item) {\n"
		. "                                        var option = document.createElement('option');\n"
		. "                                        option.value = item.shortName;\n"
		. "                                        option.textContent = item.name;\n"
		. "                                        option.selected = item.shortName === selectedBook;\n"
		. "                                        book.appendChild(option);\n"
		. "                                });\n"
		. "                        }\n"
		. "                        function submitFirstBook() {\n"
		. "                                if (book.options.length > 0) {\n"
		. "                                        book.selectedIndex = 0;\n"
		. "                                        book.form.submit();\n"
		. "                                }\n"
		. "                        }\n"
		. "                        translation.addEventListener('change', function () {\n"
		. "                                selectedBook = '';\n"
		. "                                translationChangePending = true;\n"
		. "                                populateBooks();\n"
		. "                                if (booksLoaded && !isKindleBrowser) { submitFirstBook(); }\n"
		. "                        });\n"
		. "                        book.addEventListener('change', function () {\n"
		. "                                if (!isKindleBrowser) { book.form.submit(); }\n"
		. "                        });\n"
		. "                        fetch('/1/info', { headers: { Accept: 'application/vnd.api+json' } })\n"
		. "                                .then(function (response) { return response.json(); })\n"
		. "                                .then(function (json) {\n"
		. "                                        (json.included || []).forEach(function (item) {\n"
		. "                                                if (item.type !== 'book') { return; }\n"
		. "                                                var attributes = item.attributes;\n"
		. "                                                if (!booksByTranslation[attributes.translation]) { booksByTranslation[attributes.translation] = []; }\n"
		. "                                                booksByTranslation[attributes.translation].push({\n"
		. "                                                        name: attributes.long_name + ' (' + attributes.chapter_count + ')',\n"
		. "                                                        shortName: attributes.short_name\n"
		. "                                                });\n"
		. "                                        });\n"
		. "                                        booksLoaded = true;\n"
		. "                                        populateBooks();\n"
		. "                                        if (translationChangePending && !isKindleBrowser) { submitFirstBook(); }\n"
		. "                                });\n"
		. "                }());\n"
		. "        </script>";

	return $html;
}

=item C<__makeTranslationOption($translation, $currentTranslation)>

Return one verse-navigation translation C<option>, including its lowercase
label and publication year.

=cut

sub __makeTranslationOption {
	my ($self, $translation, $currentTranslation) = @_;

	my $label = lc($translation);
	my $year = $self->__library->bibles($translation)->year();
	$label .= sprintf(' (%d)', $year) if (defined($year));

	return sprintf('<option value="%s"%s>%s</option>', $translation,
		($translation eq $currentTranslation ? ' selected' : ''), $label);
}

sub __searchResultsToHtml {
	my ($json, $options) = @_;
	$options ||= {};

	if (0 == scalar(@{ $json->{data} })) { # no results?
		return Chleb::Server::Dancer2::fetchStaticPage('no_results');
	}

	my $includedCount = scalar(@{ $json->{included} });
	my %rawBookNameMap = ( );
	for (my $includedIndex = 0; $includedIndex < $includedCount; $includedIndex++) {
		my $includedItem = $json->{included}->[$includedIndex];
		my $type = $includedItem->{type};
		next if ($type ne 'book');

		$rawBookNameMap{ $includedItem->{attributes}->{short_name} }
		    = $includedItem->{attributes}->{short_name_raw};
	}


	my $text = '';
	$text .= __linkToHome() if (!exists($options->{includeHome}) || $options->{includeHome});
	$text .= "<table class=\"info-table\">\r\n";
	$text .= "<tr>\r\n";
	$text .= "<th>Result</th>\r\n";
	$text .= "<th>Translation</th>\r\n";
	$text .= "<th>Verse</th>\r\n";
	$text .= "<th>Text</th>\r\n";
	$text .= "</tr>\r\n";

	for (my $resultI = 0; $resultI < scalar(@{ $json->{data} }); $resultI++) {
		my $verse = $json->{data}->[$resultI];
		my $attributes = $verse->{attributes};
		my $bookShortName = $rawBookNameMap{ $attributes->{book} };

		my $linkToVerse = __linkToVerse(
			undef,
			$bookShortName,
			$attributes->{chapter},
			$attributes->{ordinal},
			{ includeBookName => 1 },
		);

		$text .= "<tr>\r\n";
		$text .= sprintf("<td>%s</td>\r\n", $attributes->{title});
		$text .= sprintf("<td>%s</td>\r\n", $attributes->{translation});
		$text .= sprintf("<td>%s</td>\r\n", $linkToVerse);
		$text .= sprintf("<td>%s</td>\r\n", $attributes->{text});
		$text .= "</tr>\r\n";
	}

	$text .= "</table>\r\n";
	$text .= __searchPaginationToHtml($json);

	return $text;
}

=item C<__searchPaginationToHtml($json)>

Renders search pagination links as an HTML navigation block.

C<$json> is the same C<JSON:API> style response hash used by the search results
HTML renderer.  The function reads pagination
metadata from the C<results_summary> included item and uses the response links
to render C<Previous>, C<Next>, and page-number links.  When there is only one
logical page, an empty string is returned.

=cut

sub __searchPaginationToHtml {
	my ($json) = @_;

	my $summary;
	foreach my $includedItem (@{ $json->{included} }) {
		if ($includedItem->{type} eq 'results_summary') {
			$summary = $includedItem->{attributes};
			last;
		}
	}

	return '' if (!$summary || $summary->{total_pages} <= 1);

	my $page = $summary->{page};
	my $totalPages = $summary->{total_pages};
	my $html = "<nav class=\"pagination\" aria-label=\"Search result pages\">\r\n";
	$html .= sprintf("\t<a href=\"%s\">Previous</a>\r\n", $json->{links}->{prev}) if ($json->{links}->{prev});
	for (my $i = 1; $i <= $totalPages; $i++) {
		my $link = __replaceSearchLinkPage($json->{links}->{self}, $i);
		if ($i == $page) {
			$html .= sprintf("\t<strong>%d</strong>\r\n", $i);
		} else {
			$html .= sprintf("\t<a href=\"%s\">%d</a>\r\n", $link, $i);
		}
	}
	$html .= sprintf("\t<a href=\"%s\">Next</a>\r\n", $json->{links}->{next}) if ($json->{links}->{next});
	$html .= "</nav>\r\n";

	return $html;
}

=item C<__replaceSearchLinkPage($link, $page)>

Rewrites the C<page> query parameter in a search pagination URL.

C<$link> is an existing search page link and C<$page> is the replacement page
number.  The function returns the updated URL and leaves all other query
parameters unchanged.

=cut

sub __replaceSearchLinkPage {
	my ($link, $page) = @_;
	$link =~ s{([?&]page=)[^&]*}{$1$page}x;
	return $link;
}

sub __linkToHome { # add a link to home (root)
	my $output = "<p>\r\n";
	$output .= sprintf("\t<a class=\"vn-link vn-home\" href=\"%s\">%s</a>\r\n", '/', 'home');
	$output .= "</p>\r\n";
	return $output;
}

sub __linkToVerse {
	my ($linkText, $bookShortName, $chapterOrdinal, $verseOrdinal, $options) = @_;

	if ($options) {
		my %knownOptions = map { $_ => 1 } (qw(includeBookName));

		foreach my $option (keys(%$options)) {
			next if ($knownOptions{$option});
			croak('unknown option -- ' . $option);
		}
	}

	if (!defined($linkText)) {
		if ($options->{includeBookName}) {
			$linkText = sprintf('%s [%d:%d]', $bookShortName, $chapterOrdinal, $verseOrdinal);
		} else {
			$linkText = sprintf('[%d:%d]', $chapterOrdinal, $verseOrdinal);
		}
	}

	return sprintf(
		'<a href="/1/lookup/%s/%d/%d">%s</a>',
		lc($bookShortName), # this is not ideal, we have a mixture of shortName and shortNameRaw callers
		$chapterOrdinal,
		$verseOrdinal,
		$linkText,
	);
}

sub __infoToHtml {
	my ($json) = @_;

	my $printCell = sub {
		my ($datum, $int, $header) = @_;
		my $formatter = '%' . ($int ? 'd' : 's');
		my $tag = ($header ? 'h' : 'd');
		return sprintf("<t${tag}>${formatter}</t${tag}>\r\n", $datum);
	};

	my %bookCache = ( );

	my $text = "<table class=\"info-table\">\r\n";

	$text .= "<tr>\r\n";
	$text .= $printCell->("Book", 0, 1);
	$text .= $printCell->("Ordinal", 0, 1);
	$text .= $printCell->("Chapters", 0, 1);
	$text .= $printCell->("Testament", 0, 1);
	$text .= $printCell->("Verses", 0, 1);
	$text .= $printCell->("Short name", 0, 1);
	$text .= $printCell->("Sample", 0, 1);
	$text .= "</tr>\r\n";

	my $linkToChapter = sub {
		my ($linkText, $bookShortName, $chapterOrdinal) = @_;
		return sprintf(
			'<a href="/1/lookup/%s/%d/%d">%s</a>',
			$bookShortName,
			$chapterOrdinal,
			1,  # FIXME: At time of writing, it isn't possible to link to a whole chapter, which will be a shorter link
			$linkText,
		);
	};

	my $linkToBook = sub {
		my ($linkText, $bookShortName) = @_;
		return $linkToChapter->($linkText, $bookShortName, 1);
	};

	for (my $includedI = 0; $includedI < scalar(@{ $json->{included} }); $includedI++) {
		my $included = $json->{included}->[$includedI];
		next if ($included->{type} ne 'book');

		my $attributes = $included->{attributes};

		$bookCache{ $attributes->{short_name} } = {
			longName => $attributes->{long_name},
			shortName => $attributes->{short_name},
		};

		$text .= "<tr>\r\n";
		$text .= $printCell->($linkToBook->(
			$attributes->{long_name},
			$attributes->{short_name},
		));
		$text .= $printCell->($attributes->{ordinal}, 1);
		$text .= $printCell->($attributes->{chapter_count}, 1);
		$text .= $printCell->($attributes->{testament});
		$text .= $printCell->($attributes->{verse_count}, 1);
		$text .= $printCell->($attributes->{short_name});
		$text .= $printCell->(sprintf(
			'%s %s',
			Chleb::Utils::limitText($attributes->{sample_verse_text}),
			__linkToVerse(
				undef,
				$attributes->{short_name},
				$attributes->{sample_verse_chapter_ordinal},
				$attributes->{sample_verse_ordinal_in_chapter},
			),
		));
		$text .= "</tr>\r\n";
	}

	$text .= "</table><br/>\r\n";

	$text .= "<table class=\"info-table\">\r\n";

	$text .= "<tr>\r\n";
	$text .= $printCell->("Book", 0, 1);
	$text .= $printCell->("Chapter", 0, 1);
	$text .= $printCell->("Verses", 0, 1);
	$text .= "</tr>\r\n";

	for (my $includedI = 0; $includedI < scalar(@{ $json->{included} }); $includedI++) {
		my $included = $json->{included}->[$includedI];
		next if ($included->{type} ne 'chapter');

		my $attributes = $included->{attributes};

		$text .= "<tr>\r\n";
		$text .= $printCell->($linkToBook->(
			$bookCache{ $attributes->{book} }->{longName},
			$bookCache{ $attributes->{book} }->{shortName},
		));
		$text .= $printCell->($linkToChapter->(
			$attributes->{ordinal},
			$attributes->{book},
			$attributes->{ordinal},
		));
		$text .= $printCell->(__linkToVerse(
			$attributes->{verse_count},
			$attributes->{book},
			$attributes->{ordinal},
			$attributes->{verse_count},
		));
		$text .= "</tr>\r\n";
	}

	$text .= "</table>\r\n";

	return $text;
}

=item C<__versionFilter($version, $minimum, $maximum)>

Throw a 400 error if C<$version> is outwith C<$minimum> and C<$maximum> values,
otherwise, C<$version> is returned.

=back

=cut

sub __versionFilter {
	my ($version, $minimum, $maximum) = @_;

	$version = int($version);
	croak(Chleb::Exception->raise(HTTP_BAD_REQUEST, "endpoint version must be between $minimum and $maximum, you said $version"))
	    if ($version < $minimum || $version > $maximum);

	return $version;
}

sub __removeUptime {
	my ($self) = @_;
	my $uptimeFilePath = $self->__uptimeFilePath();

	my $logMessage = "Removing '$uptimeFilePath' -- ";
	my $result = unlink($uptimeFilePath);
	$logMessage .= sprintf('%d file(s) removed', int($result));

	$self->dic->logger->debug($logMessage);

	return;
}

has __warnedSessionToken => (is => 'rw', isa => 'Bool', default => 0);

=over

=item C<__damper>

Instance of L<Chleb::Server::Dampen> that handles all rate-limiting logic.

=back

=cut

has __damper => (
	isa     => 'Chleb::Server::Dampen',
	is      => 'ro',
	lazy    => 1,
	default => sub { Chleb::Server::Dampen->new(dic => $_[0]->dic) },
);

sub logRequest {
	my ($self) = @_;

	my $request = Chleb::Server::Dancer2::getRequest();
	my $ipAddress = $request->address();
	Log::Log4perl::MDC->put(address => $ipAddress);
	my $path = $request->path();

	$self->dic->logger->debug("Received request $path from $ipAddress");

	return;
}

sub handleSessionToken {
	my ($self) = @_;

	my $supportSessions = $self->dic->config->get('features', 'sessions', 'false', 1);
	return unless ($supportSessions);

	unless ($self->__warnedSessionToken) {
		$self->dic->logger->warn('Using experimental session cookie support, alpha quality, there are known bugs and limitations');
		$self->__warnedSessionToken(1);
	}

	my $request = Chleb::Server::Dancer2::getRequest();
	my $ipAddress = $request->address() // '';
	my $userAgent = $request->agent() // '';

	my $tokenRepo = $self->dic->tokenRepo;
	my $sessionToken = Chleb::Server::Dancer2::getCookie('sessionToken');

	if (!$sessionToken) {
		if ($self->__damper->dampen($ipAddress)) {
			Chleb::Server::Dancer2::handleException(Chleb::Exception->raise(
				HTTP_TOO_MANY_REQUESTS,
				'Slow down, or respect the sessionToken cookie', # TODO: Make a web page explaining this & link to it
				{ retryAfterSeconds => 1 },
			));
		}

		$sessionToken = $tokenRepo->create();
		Log::Log4perl::MDC->put(session => $sessionToken->shortValue);

		$sessionToken->ipAddress($ipAddress);
		$sessionToken->userAgent($userAgent);

		my $evalOk2; $evalOk2 = eval {
			$tokenRepo->save($sessionToken); # save via all configured backends
			1;
		} or $evalOk2 = 0;
		if (my $exception = $EVAL_ERROR) {
			Chleb::Server::Dancer2::handleException($exception);
		}

		$self->dic->logger->trace("No session token, created a new one: " . $sessionToken->toString());
		Chleb::Server::Dancer2::setCookie(sessionToken => $sessionToken->value, expires => $sessionToken->expires);

		return;
	}

	$self->dic->logger->trace("Got session token '$sessionToken' from client");
	my $evalOk3; $evalOk3 = eval {
		$sessionToken = $tokenRepo->load($sessionToken);
		1;
	} or $evalOk3 = 0;
	if (my $exception = $EVAL_ERROR) {
		Chleb::Server::Dancer2::handleException($exception);
	}

	Log::Log4perl::MDC->put(session => $sessionToken->shortValue);
	$self->dic->logger->trace('session token found: ' . $sessionToken->toString());

	if ($self->__damper->dampenChurn($ipAddress, $sessionToken->value)) {
		my $retryAfterSeconds = $self->dic->config->get('rate_limit', 'session_churn_window_seconds', 300);
		Chleb::Server::Dancer2::handleException(Chleb::Exception->raise(
			HTTP_TOO_MANY_REQUESTS,
			'Too many session tokens from this IP address',
			{ retryAfterSeconds => $retryAfterSeconds },
		));
	}

	if ($self->__damper->dampenSession(
		$sessionToken->value,
		$sessionToken->source->isa('Chleb::Token::Repository::JWT'),
	)) {
		my $retryAfterSeconds = $self->dic->config->get('rate_limit', 'session_window_seconds', 60);
		Chleb::Server::Dancer2::handleException(Chleb::Exception->raise(
			HTTP_TOO_MANY_REQUESTS,
			'Request rate exceeded for this session',
			{ retryAfterSeconds => $retryAfterSeconds },
		));
	}

	if ($sessionToken->ipAddress ne $ipAddress) {
		$self->dic->logger->info(sprintf('%s the client changed IP address from %s to %s',
		    $sessionToken->toString(), $sessionToken->ipAddress, $ipAddress));

		$sessionToken->ipAddress($ipAddress);
	}

	if ($sessionToken->userAgent ne $userAgent) {
		$self->dic->logger->info(sprintf('%s the client changed user agent from %s to %s',
		    $sessionToken->toString(), $sessionToken->userAgent, $userAgent));

		$sessionToken->userAgent($userAgent);
	}

	if ($sessionToken->dirty) {
		my $evalOk4; $evalOk4 = eval {
			$tokenRepo->save($sessionToken); # save via all configured backends
			1;
		} or $evalOk4 = 0;
		if (my $exception = $EVAL_ERROR) {
			Chleb::Server::Dancer2::handleException($exception);
		}
	}

	return;
}

__PACKAGE__->meta->make_immutable;

1;

#!/usr/bin/env perl
use strict;
use warnings;

use File::Temp qw(tempdir);
use Test::More;

use lib 'lib';
use Chleb::Cache::Shared;
use Chleb::Server::MediaType;
use Chleb::Server::Moose;

my $root = tempdir(CLEANUP => 1);
my $cache = Chleb::Cache::Shared->new({ root => $root, version => 'test' });
my $key = 'lookup\0{"book":"Gen","chapter":1}';

ok($cache->set('html', $key, '<html>cached</html>'), 'writes an HTML cache entry');
my $path = $cache->path('html', $key);
ok(-f $path, 'entry is stored as an individual file');
like($path, qr{/html/[0-9a-f]{2}/[0-9a-f]{16}\.bin\z}x, 'entry uses a tiered xxHash64 path');
is($cache->get('html', $key), '<html>cached</html>', 'reads the cached value');
is($cache->get('html', 'other'), undef, 'different key misses');
is($cache->get('other', $key), undef, 'different kind misses');

my $mediaType = Chleb::Server::MediaType->new({ items => [], original => 'text/html' });
my $htmlKey = Chleb::Server::Moose::__htmlCacheKey(undef, 'lookup', { accept => $mediaType });
like($htmlKey, qr/"accept":"text\/html"/x, 'media type is represented by its header value');
unlike($htmlKey, qr/Chleb::Server::MediaType=HASH/x, 'media type reference address is not cached');

done_testing();

#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use YAML;
use Encode qw/encode decode/;
use LWP::UserAgent;
use URI::Query;
use Web::Scraper;

our %pref;
require 'preferences.pl';

my @accesses = (
	{
		headers => {
			'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
			'Accept-Encoding' => 'gzip, deflate',
			'Accept-Language' => 'ja,en-US;q=0.7,en;q=0.3',
			'Cookie' => $pref{fetch_tabelog_cookie},
			'Referer' => 'http://tabelog.com/bookmark/',
			'User-Agent' => $pref{ua},
		},
		uri => 'http://tabelog.com/rst/rstsearch/?'
	}
);

sub report(@) {
	print STDERR map { encode('utf8', $_) } @_, "\n";
	return @_;
}
sub disclose(@) {
	print encode('utf8', YAML::Dump(@_));
	return @_;
}

main();

sub main {
	local $/ = undef;
	my $yaml = decode('utf8', <>);
	
	my $ua = LWP::UserAgent->new;
	$ua->timeout(10);
	set_ua_headers($ua, $accesses[0]->{headers});
	
	my @list = map { modify_entry($_, $ua, $accesses[0]->{uri}) } YAML::Load($yaml);
	print encode('utf8', YAML::Dump(@list));
}

sub modify_entry {
	my ($entry, $ua, $uri) = @_;
	
	if (@{$entry->{tabelogurl}} > 0 && $entry->{tabelogurl}->[0]) {
		return $entry;
	}
	
	my @urls = search_tabelog_url($ua, $uri, $entry->{name}, $entry->{station});
	if (@urls) {
		$entry->{tabelogurl} = \@urls;
	}
	
	return $entry;
}

sub set_ua_headers {
	my $ua = shift;
	my $headers = shift;
	while (my ($k, $v) = each %$headers) {
		$ua->default_header($k => $v);
	}
	return $ua;
}

my $scraper;
sub get_scraper {
	if (defined $scraper) { return $scraper }
	$scraper = scraper {
		process 'ul.js-rstlist-info li.list-rst', 'pages[]' => scraper {
			process 'a.list-rst__rst-name-target', 'uri' => '@href'; # URI
			process 'a.list-rst__rst-name-target', 'name' => 'TEXT';
			process 'span.list-rst__area-genre', 'area' => 'TEXT'; # （三宮（阪急）、..
		};
		
	};
}

sub fetch_uri {
	my ($ua, $uri, %headers) = @_;
	
	my $response = $ua->get($uri, %headers);
	
	if (!$response->is_success) {
	    die 'fetching HTML document failed ' . $response->status_line . " for: $uri";
	}
	
	return $response->decoded_content;
}

sub search_tabelog_url {
	my ($ua, $uri, $name, $area) = @_;
	$area = '' unless defined $area;
	
	my $uri_page = $uri . URI::Query->new({
		sa => $area,
		sk => $name
	});
	
	my $decoded_html = fetch_uri($ua, $uri_page);
	
	my $scraped = get_scraper()->scrape( $decoded_html, $uri );
	
	if (defined $scraped && defined $scraped->{pages} && scalar(@{$scraped->{pages}}) > 0) {
		report scalar(@{$scraped->{pages}}) . " pages found for $name, $area";
		return map { sprintf '%s# %s %s', $_->{uri}, $_->{name}, $_->{area} } @{$scraped->{pages}};
	} else {
		report "not found for $name, $area from $uri_page";
		return undef;
	}
}

#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use LWP::UserAgent;
use URI::Query;
use YAML;
use JSON;
use Web::Scraper;
use Encode qw/encode decode/;

our %pref;
require 'preferences.pl';

my $maxresults = $pref{download_max_results};

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
		uri => 'http://tabelog.com/bookmark/?sk=&sw=&PG=1'
	}
);

my $class_regexp = '\bbkmlist-group__rstname--(favorite|interest)\b';

my %review_api_uri = (
	favorite => 'http://tabelog.com/simple_review/<<rid>>/review',
	interest => 'http://tabelog.com/simple_review/<<rid>>/interest',
);

sub report(@) {
	print STDERR @_, "\n";
	return @_;
}
sub disclose(@) {
	print encode('utf8', YAML::Dump(@_));
	return @_;
}

my $nbsp = decode('utf8', "\xC2\xA0");

main();

sub main {
	disclose( fetch_all_lists() );
}

sub set_ua_headers {
	my $ua = shift;
	my $headers = shift;
	while (my ($k, $v) = each %$headers) {
		$ua->default_header($k => $v);
	}
	return $ua;
}

sub fetch_all_lists {
	my @list = ();
	
	my $ua = LWP::UserAgent->new;
	$ua->timeout(10);
	
	foreach (@accesses) {
		set_ua_headers($ua, $_->{headers});
		push @list, fetch_list($ua, $_->{uri});
	}
	
	return @list;
}

sub fetch_list {
	my ($ua, $uri) = @_;
	my @list = ();
	
	while(1) {
		my @result;
		($uri, @result) = fetch_list_page($ua, $uri);
		if (@result == 0) {
			report "no results fetched from $uri.";
			last;
		}
		push @list, @result;
		if (!$uri) { last }
		if ($maxresults <= @list) { last }
	}
	return @list;
}

my $scraper;
sub get_scraper {
	if (defined $scraper) { return $scraper }
	$scraper = scraper {
		process 'meta[name="csrf-token"]', 'csrf-token' => '@content';
		process 'a.page-move__target--next', 'next' => '@href';
		process 'li.bkmlist-group', 'bookmarks[]' => scraper {
			process 'p.bkmlist-group__rstname', 'class' => '@class'; # bkmlist-group__rstname bkmlist-group__rstname--(favorite|interest) js-rstname
			process 'li.bkmlist-group', 'rid' => '@data-rst-id';
			process 'p.bkmlist-group__rstname a', 'uri' => '@href';
			process 'p.bkmlist-group__area-catg', 'area' => 'TEXT';
		};
	};
}

sub fetch_uri {
	my ($ua, $uri, %headers) = @_;
	
	my $response = $ua->get($uri, %headers);
	
	if (!$response->is_success) {
	    die 'fetching HTML document failed:' . $response->status_line;
	}
	
	return $response->decoded_content;
}

sub load_stdin {
	local $/ = undef;
	return scalar(<>);
}

# returns next_url, reviews
sub fetch_list_page {
	my ($ua, $uri) = @_;
	
	my $decoded_html = fetch_uri($ua, $uri);
	# my $decoded_html = load_stdin();
	
	my $scraped = get_scraper()->scrape( $decoded_html, $uri );
	report scalar(@{$scraped->{bookmarks}}) . " feched from: " . $uri;
	
	my @reviews = map {
		my $review;
		if ($_->{class} =~ /$class_regexp/) {
			my $review_uri = $review_api_uri{$1};
			$review_uri =~ s/<<rid>>/$_->{rid}/;
			my $json = fetch_uri($ua, $review_uri,
				'Accept' => 'application/json, text/javascript, */*; q=0.01',
				'Referer' => $uri,
				'X-CSRF-Token' => $scraped->{'csrf-token'},
				'X-Requested-With' => 'XMLHttpRequest'
			);
			$review = decode_json($json);
			report "review for $_->{rid} feched from: " . $review_uri;
		} else {
			report "parsing class name failed: ", $_->{class};
			$review = {};
		}
		if ($_->{area} =~ /（(.+?)(?:、| |$nbsp)/) {
			$review->{area} = $1;
		} else {
			report "parsing area name failed: ", $_->{area};
		}
		$review->{uri} = $_->{uri}->as_string;
		$review->{rid} = $_->{rid};
		$review;
	} @{$scraped->{bookmarks}};
	
	return $scraped->{'next'}, @reviews;
}

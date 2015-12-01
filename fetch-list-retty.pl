#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use LWP::UserAgent;
use URI::Query;
use YAML;
use JSON;
use Encode qw/encode/;

our %pref;
require 'preferences.pl';

my $maxresults = $pref{download_max_results};

my @accesses = (
	{
		headers => {
			'Accept' => 'application/json, text/javascript, */*; q=0.01',
			'Accept-Encoding' => 'gzip, deflate',
			'Accept-Language' => 'ja,en-US;q=0.7,en;q=0.3',
			'Cookie' => $pref{fetch_retty_cookie},
			'Referer' => 'http://retty.me/mypage/gone/',
			'User-Agent' => $pref{ua},
			'X-Requested-With' => 'XMLHttpRequest',
		},
		uri => 'http://retty.me/API/OUT/getGoneRestaurantReportMyTl/?',
		parameters => {
			'html' => 'true',
			'p' => $pref{retty_user_id} . ',,undefined,undefined,0,<<start>>',
		}
	},
	{
		headers => {
			'Referer' => 'http://retty.me/mypage/wannago/',
		},
		uri => 'http://retty.me/API/OUT/getWannagoRestaurantReportMyTl/?',
		parameters => {
			'html' => 'true',
			'p' => $pref{retty_user_id} . ',0,0,<<start>>',
		}
	},
);

sub report(@) {
	print STDERR @_, "\n";
	return @_;
}

main();

sub main {
	print encode('utf8', YAML::Dump( fetch_all_lists() ));
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
		push @list, fetch_list($ua, $_->{uri}, $_->{parameters});
	}
	
	return @list;
}

sub fetch_list {
	my ($ua, $uri, $parameters) = @_;
	my $start = 0;
	my @list = ();
	while(1) {
		my %params = ();
		while (my ($k, $v) = each %$parameters) {
			$v =~ s/<<start>>/$start/eg;
			$params{$k} = $v;
		}
		my $uri_page = $uri . URI::Query->new(\%params);
		
		my @result = fetch_list_page($ua, $uri_page);
		if (@result == 0) { last }
		push @list, @result;
		$start += @result;
		if ($maxresults <= $start) { last }
	}
	return @list;
}

sub fetch_list_page {
	my ($ua, $uri) = @_;
	
	my $response = $ua->get($uri);
	
	if (!$response->is_success) {
	    die 'fetching HTML document failed:' . $response->status_line;
	}
	
	my $doc = $response->decoded_content;
	my $response_decoded = decode_json( $doc );
	report scalar(@$response_decoded) . " feched from: " . $uri;
	return @$response_decoded;
}

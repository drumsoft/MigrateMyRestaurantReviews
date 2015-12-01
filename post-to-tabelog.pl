#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use LWP::UserAgent;
use URI::Query;
use YAML;
use JSON;
use Web::Scraper;
use HTTP::Request;
use Encode qw/encode decode/;

our %pref;
require 'preferences.pl';

my %accesses = (
	get_token => {
		headers => {
			'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
			'Accept-Encoding' => 'gzip, deflate',
			'Accept-Language' => 'ja,en-US;q=0.7,en;q=0.3',
			'Cookie' => $pref{post_tabelog_cookie},
			'Referer' => '',
			'User-Agent' => $pref{ua},
		},
		uri => 'http://tabelog.com/bookmark/'
	},
	post_review => {
		headers => {
			'Accept' => 'application/json, text/javascript, */*; q=0.01',
			'Accept-Encoding' => 'gzip, deflate',
			'Accept-Language' => 'ja,en-US;q=0.7,en;q=0.3',
			'Content-Type' => 'application/json; charset=UTF-8',
			'Cookie' => $pref{post_tabelog_cookie},
			'Referer' => 'http://tabelog.com/bookmark/',
			'User-Agent' => $pref{ua},
			'X-Requested-With' => 'XMLHttpRequest',
		},
		uri => 'http://tabelog.com/simple_review/<<rcd>>/<<type>>'
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
	my @entries = YAML::Load($yaml);
	
	my $ua = LWP::UserAgent->new;
	$ua->timeout(10);
	
	set_ua_headers($ua, $accesses{get_token}->{headers});
	my $token = fetch_token($ua, $accesses{get_token}->{uri});
	
	set_ua_headers($ua, $accesses{post_review}->{headers});
	$ua->default_header('X-CSRF-Token' => $token);
	foreach (@entries) {
		post_review($ua, $accesses{post_review}->{uri}, $_);
	}
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
		process 'meta[name="csrf-token"]', 'csrf-token' => '@content';
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

sub post_json_to_uri {
	my ($ua, $uri, $params) = @_;
	
	my $request = HTTP::Request->new('PUT', $uri);
	$request->content(encode_json($params));
	
	my $response = $ua->request($request);
	
	if (!$response->is_success) {
		report "posting JSON data to $uri failed:" . $response->status_line;
		warn $response->decoded_content, "\n";
		die 'failed.';
	}
	
	return $response->decoded_content;
}

sub fetch_token {
	my ($ua, $uri) = @_;
	
	my $decoded_html = fetch_uri($ua, $uri);
	
	my $scraped = get_scraper()->scrape( $decoded_html, $uri );
	report "token '" . $scraped->{'csrf-token'} . "' feched from: " . $uri;
	
	return $scraped->{'csrf-token'};
}

sub json_boolean {
	return (shift) ? \1 : \0;
}

sub post_review {
	my ($ua, $uri, $entry) = @_;
	my ($tabelogurl, $rcd);
	
	if (exists $entry->{tabelogurl} && @{$entry->{tabelogurl}} > 0) {
		$tabelogurl = $entry->{tabelogurl}->[0];
	} else {
		report "tabelogurl is not exist for:", $entry->{name};
		return;
	}
	$tabelogurl =~ s/\#.*//;
	if (defined $tabelogurl && $tabelogurl =~ m{/(\d+)/?$}) {
		$rcd = $1;
	} else {
		report "tabelog rcd is not found for ", $entry->{name};
		return;
	}
	$uri =~ s/<<rcd>>/$rcd/e;
	$uri =~ s/<<type>>/$entry->{type} eq 'wanna' ? 'interest' : 'review'/e;
	
	my $post = {
		rcd => $rcd,
		rst_name => $entry->{name},
		bookmark => 'interest',
		bookmark_comment => '',
		bookmark_created_at => '',
		review => json_boolean(0),
		published => undef,
		deletable => json_boolean(1),
		review_id => undef,
		comment => '',
		lunch_use => json_boolean(0),
		dinner_use => json_boolean(0),
		visit_year => undef,
		visit_month => undef,
		private => json_boolean(0),
		degree_title => "",
		all_image_count => 0,
		published_image_count => 0,
		max_images => 100,
		all_private => undef,
		id => $rcd,
		reviewEntryUrl => "http://tabelog.com/rst/auth_rvw_entry?rcd=" . $rcd,
		imageEntryUrl => "http://tabelog.com/rst/auth_rvwimg_entry?rcd=" . $rcd,
		reviewBlogEntryUrl => "http://tabelog.com/rst/new_rvw_from_blog_entry_pre?rcd=" . $rcd,
		bookmark_comment_preview => '',
		comment_preview => '',
		comment_truncated => json_boolean(0),
		image_uploadable_browser => json_boolean(1),
		multiple_uploadable => json_boolean(1),
		publish => json_boolean(1),
		wait => json_boolean(1),
		review_images => [],
		labels => [],
		photoExists => json_boolean(0),
		labeled => json_boolean(0),
		bookmark_comment_or_labels => json_boolean(1),
		loginUrl => "https://ssl.tabelog.com/account/login/"
	};
	
	if (defined $entry->{score}) {
		$post->{degree} = $entry->{score};
		$post->{degree_title} = '期待度';
	}
	if ($entry->{type} eq 'wanna') {
		$post->{bookmark_created_at} = $entry->{date};
		$post->{bookmark_created_at} =~ s/\-/\//;
		$post->{bookmark_comment} = $entry->{comment};
		$post->{bookmark_comment_preview} = $entry->{comment};
		$post->{private} = json_boolean($entry->{secret});
		$post->{steppedTenfoldDegree} = sprintf "%2d", int(10 * $entry->{score});
	} else { # gone
		# review_detail_url => "/rvwr/009999999/rvwdtl/99999999/", # added after published ?
		my ($s, $m, $h, $d, $mo, $y) = localtime(time());
		$post->{bookmark_created_at} = sprintf "%04d/%02d/%02d", $y+1900, $mo+1, $d;
		if ($entry->{secret}) { # private
			$post->{publish} = json_boolean(0);
		} else { # public
			$post->{bookmark} = 'favorite';
			$post->{review} = json_boolean(1);
			$post->{published} = json_boolean(0);
			$post->{degree_title} = "あなたの点数";
		}
		$post->{private} = json_boolean(1);
		$post->{comment} = $entry->{comment};
		$post->{comment_preview} = $entry->{comment};
		if ($entry->{scene} == 1 || $entry->{scene} == 3 || $entry->{scene} == 4 || $entry->{scene} == 0) {
			$post->{lunch_use} = json_boolean(1);
			$post->{lunch_total_score} = $entry->{score};
			$post->{lunchFiveSteppedTenfold} = sprintf "%2d", int(10 * $entry->{score});
		}
		if ($entry->{scene} == 2 || $entry->{scene} == 4 || $entry->{scene} == 0) {
			$post->{dinner_use} = json_boolean(1);
			$post->{dinner_total_score} = $entry->{score};
			$post->{dinnerFiveSteppedTenfold} = sprintf "%2d", int(10 * $entry->{score});
		}
		if ($entry->{date} =~ /^(\d\d\d\d)-(\d\d)/) {
			$post->{visit_year} = $1 + 0;
			$post->{visit_month} = $2 + 0;
		}
		$post->{all_private} = json_boolean(0);
		$post->{action} = undef;
		$post->{displayTab} = undef;
	}
	
	report "posting: " . $uri;
	my $json = post_json_to_uri($ua, $uri, $post);
	my $returned = decode_json($json);
	
	disclose $returned;
}

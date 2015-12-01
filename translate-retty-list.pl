#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use YAML;
use Encode qw/encode decode/;

our %pref;
require 'preferences.pl';

my $retty_user_id = $pref{retty_user_id};

my %score_map = (
	1 => 5, # very good
	2 => 4, # good
	3 => 3, # bad
	4 => 2, # deprecated very bad
);

main();

sub main {
	local $/ = undef;
	my $yaml = decode('utf8', <>);
	my @list = map { modify_entry($_) } YAML::Load($yaml);
	print encode('utf8', YAML::Dump(@list));
}

sub modify_entry {
	my $entry = shift;
	
	my $date = '';
	if ($entry->{create_datetime_with_year} =~ /(\d+)年(\d+)月(\d+)日/) {
		$date = sprintf "%04d-%02d-%02d", $1, $2, $3;
	}
	
	my $tabelogurls = [];
	if ('HASH' eq ref $entry->{url} && exists $entry->{url}->{2}) {
		$tabelogurls = [$entry->{url}->{2}];
	}
	
	my $modified = {
		name => $entry->{restaurant_name},
		station => $entry->{station_name},
		
		date => $date,
		
		rettyurl => [
			$entry->{restaurant_url}
		],
		tabelogurl => $tabelogurls,
		
		comment => '',
		secret => 0,
		score => 0,
		scene => 4,
	};
	
	if ($entry->{user_id} eq $retty_user_id) {
		$modified->{comment} = $entry->{report_comment_long};
		$modified->{secret} = ($entry->{restaurant_report_status} == 4);
		if ($entry->{restaurant_report_status} == 3) {
			$modified->{type} = 'wanna';
		} else {
			$modified->{type} = 'gone';
			$modified->{score} = $score_map{$entry->{score_type}};
			$modified->{scene} = $entry->{scene_type};
		}
	} else {
		$modified->{type} = 'wanna';
	}
	
	return $modified;
}

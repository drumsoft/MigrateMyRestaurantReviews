#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use YAML;
use Encode qw/encode decode/;

main();

sub main {
	local $/ = undef;
	my $yaml = decode('utf8', <>);
	my @list = map { modify_entry($_) } YAML::Load($yaml);
	print encode('utf8', YAML::Dump(@list));
}

sub decode_boolean {
	my $value = shift;
	ref $value ? $$value : 0;
}

sub decode_score {
	my $value = shift;
	defined $value ? int($value) : 0;
}

sub modify_entry {
	my $entry = shift;
	
	my $date = '';
	if ($entry->{visit_year}) {
		$date = sprintf "%04d-%02d-01", $entry->{visit_year}, $entry->{visit_month};
	} else {
		$date = $entry->{bookmark_created_at};
		$date =~ s/\//-/g;
	}
	
	my $tabelogurls = [];
	if ('HASH' eq ref $entry->{url} && exists $entry->{url}->{2}) {
		$tabelogurls = [$entry->{url}->{2}];
	}
	
	my $modified = {
		name => $entry->{rst_name},
		station => $entry->{area},
		
		date => $date,
		
		rettyurl => [],
		tabelogurl => [
			$entry->{uri}
		],
		
		comment => $entry->{comment} ? $entry->{comment} : $entry->{bookmark_comment},
		secret => decode_boolean($entry->{private}) ? 1 : 0,
		score => 0,
		scene => 4,
	};
	
	if ($entry->{bookmark} eq 'interest') {
		$modified->{score} = decode_score($entry->{degree});
		$modified->{type} = 'wanna';
	} else {
		if (decode_boolean($entry->{dinner_use}) && decode_boolean($entry->{lunch_use})) {
			if (decode_score($entry->{dinner_total_score}) >= decode_score($entry->{lunch_total_score})) {
				$modified->{score} = decode_score($entry->{dinner_total_score});
				$modified->{scene} = 2;
			} else {
				$modified->{score} = decode_score($entry->{lunch_total_score});
				$modified->{scene} = 1;
			}
		} elsif ($entry->{dinner_use}) {
			$modified->{score} = decode_score($entry->{dinner_total_score});
			$modified->{scene} = 2;
		} elsif ($entry->{lunch_use}) {
			$modified->{score} = decode_score($entry->{lunch_total_score});
			$modified->{scene} = 1;
		}
		$modified->{type} = 'gone';
	}
	
	return $modified;
}

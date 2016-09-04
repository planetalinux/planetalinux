#!/usr/bin/env perl

use Modern::Perl;
use File::Basename;

use lib dirname(__FILE__).'/../lib';

use Config::IniFiles;
use App::PPBuild;
use Net::Domain::ES::ccTLD;
use PlanetaLinux;
use Data::Dumper;
use File::Path qw/remove_tree/;

my $r = {};
my $all = [];

for my $c_id ( @PlanetaLinux::countries ) {
	my $c_name = find_name_by_cctld( $c_id ) || $c_id;
		
	task $c_id,
		"Builds the Planeta Linux instance for: `$c_name'",
		sub {
			say "running $c_id!";
			
			my $pl = PlanetaLinux->new({
				countries => [$c_id],
			});
			
			$pl->run;
				
			say "done!";
		};
	
	push @$all, $c_id;
		
}

task 'rssall',
    "Builds a single RSS for all authors.",
    sub {
        say "running rssall!";
        my $p = PlanetaLinux->new();
        $p->run();
        say 'Done?';
    };

task 'all',
	"Builds all Planeta Linux instances.",
	sub {
		say "running all instances!";
		my $pl = PlanetaLinux->new({
			countries => $all,
		});
		$pl->run;
		say "done!!1";
	};

task 'flush',
	"Flushes the Planeta Linux cache.",
	sub  {
		say "flushing the cache toilet!";
		my $cache_dir = dirname(__FILE__).'/../cache';
		opendir my $dh, $cache_dir or die "couldn't open dir";
		for my $d ( readdir($dh) ) {
			next unless $d =~ /^[a-z]{2}$/;
			next unless -d "$cache_dir/$d";
			remove_tree "$cache_dir/$d";
		}
		say "done !";
	};

task 'www',
	"Builds the static files for Planeta Linux",
	sub {
		my $t = Template->new(
			INCLUDE_PATH => dirname(__FILE__).'/../template/www',
			OUTPUT_PATH => dirname(__FILE__).'/../www',
			PRE_PROCESS => 'header.tt',
			POST_PROCESS => 'footer.tt'
		) || die Template->error();
		
		my $pl = PlanetaLinux->new;
		
		$t->process('index.tt', {
			countries => [$pl->countries], 
		}, 'index.html') || die $t->error();
		
		my @templates = qw/lineamientos faq contacto banners creditos/;
		# 
		for my $temp ( @templates ) {
		 	$t->process("$temp.tt", {}, "$temp.html") or die $t->error;
		 }
	};


do_tasks();

1;

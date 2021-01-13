#!/usr/bin/perl

use strict;
use warnings;
use File::Path;
use File::Basename;
use Getopt::Long;


my $outevents = 0;
my $test;
my $incremental;
GetOptions("test"=>\$test, "increment"=>\$incremental);
if ($#ARGV < 0)
{
    print "usage: run_all.pl <number of jobs>\n";
    print "parameters:\n";
    print "--increment : submit jobs while processing running\n";
    print "--test : dryrun - create jobfiles\n";
    exit(1);
}

my $maxsubmit = $ARGV[0];
if (! -f "outdir.txt")
{
    print "could not find outdir.txt\n";
    exit(1);
}
my $outdir = `cat outdir.txt`;
chomp $outdir;
mkpath($outdir);

my $indirfile = sprintf("../../pass2/condor/outdir.txt");
if (! -f $indirfile)
{
    print "could not find file with input directory $indirfile\n";
    exit(1);
}
my $indir = `cat $indirfile`;
chomp $indir;

my $nsubmit = 0;
open(F,"find $indir -maxdepth 1 -type f -name 'DST_CALO_G4HIT*.root' | sort |");
while (my $file = <F>)
{
    chomp  $file;
    my $vertexfile = $file;
    $vertexfile =~ s/DST_CALO_G4HIT/DST_VERTEX/;
    if (! -f $vertexfile)
    {
	print "did not find $vertexfile\n";
	next;
    }
    print "found $vertexfile\n";
    my $lfn = basename($file);
    print "found $file\n";
    if ($lfn =~ /(\S+)-(\d+)-(\d+).*\..*/ )
    {
	my $runnumber = int($2);
	my $segment = int($3);
	my $outfilename = sprintf("DST_CALO_CLUSTER_sHijing_0_12fm-%010d-%05d.root",$runnumber,$segment);

	my $tstflag="";
	if (defined $test)
	{
	    $tstflag="--test";
	}
	my $subcmd = sprintf("perl run_condor.pl %d %s %s %s %s %d %d %s", $outevents, $file, $vertexfile, $outfilename, $outdir, $runnumber, $segment, $tstflag);
	print "cmd: $subcmd\n";
	system($subcmd);
	my $exit_value  = $? >> 8;
	if ($exit_value != 0)
	{
	    if (! defined $incremental)
	    {
		print "error from run_condor.pl\n";
		exit($exit_value);
	    }
	}
	else
	{
	    $nsubmit++;
	}
	if ($nsubmit >= $maxsubmit)
	{
	    print "maximum number of submissions reached, exiting\n";
	    exit(0);
	}
    }
}
close(F);

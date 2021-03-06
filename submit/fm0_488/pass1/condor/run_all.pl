#!/usr/bin/perl

use strict;
use warnings;
use File::Path;
use Getopt::Long;

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
my $runnumber = 1;
my $events = 50;
my $evtsperfile = 10000;
my $nmax = $evtsperfile;
open(F,"outdir.txt");
my $outdir=<F>;
chomp  $outdir;
close(F);
mkpath($outdir);
my $nsubmit = 0;
for (my $segment=0; $segment<1000; $segment++)
{
    my $hijingdatfile = sprintf("/sphenix/sim/sim01/sphnxpro/MDC1/sHijing_HepMC/data/sHijing_0_488fm-%010d-%05d.dat",$runnumber, $segment);
    if (! -f $hijingdatfile)
    {
	print "could not locate $hijingdatfile\n";
	next;
    }
    my $sequence = $segment*200;
    for (my $n=0; $n<$nmax; $n+=$events)
    {
        
	my $outfile = sprintf("G4Hits_sHijing_0_488fm-%010d-%05d.root",$runnumber,$sequence);
	my $fulloutfile = sprintf("%s/%s",$outdir,$outfile);
	print "out: $fulloutfile\n";
	if (! -f $fulloutfile)
	{
	    my $tstflag="";
	    if (defined $test)
	    {
		$tstflag="--test";
	    }
	    system("perl run_condor.pl $events $hijingdatfile $outdir $outfile $n $runnumber $sequence $tstflag");
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
	    if ($nsubmit > $maxsubmit)
	    {
		print "maximum number of submissions reached, exiting\n";
		exit(0);
	    }
	}
	else
	{
	    print "output file already exists\n";
	}
        $sequence++;
    }
}

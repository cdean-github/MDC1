#!/usr/bin/perl

use strict;
use warnings;
use File::Path;
use File::Basename;
use Getopt::Long;
use DBI;

my $system = 0;

GetOptions("type:i"=>\$system);

if ($system < 1 || $system > 3)
{
    print "use -type, valid values:\n";
    print "-type : production type\n";
    print "    1 : hijing 0-12fm\n";
    print "    2 : hijing 0-488fm\n";
    print "    3 : pythia8 mb\n";
    exit(0);
}

my $systemstring;
if ($system == 1)
{
    $systemstring = "sHijing_0_12fm";
}
elsif ($system == 2)
{
    $systemstring = "sHijing_0_488fm";
}
elsif ($system == 3)
{
    $systemstring = "pythia8_mb";
}
else
{
    die "bad type $system\n";
}

open(F,">missing.files");
my $dbh = DBI->connect("dbi:ODBC:FileCatalog","phnxrc") || die $DBI::error;
$dbh->{LongReadLen}=2000; # full file paths need to fit in here
my $getdsttypes = $dbh->prepare("select distinct(dsttype) from datasets where filename like '%$systemstring%' order by dsttype");

my %topdcachedir = ();
$topdcachedir{"/pnfs/rcf.bnl.gov/sphenix/disk/MDC1/sHijing_HepMC"} = 1;
#$topdcachedir{"/pnfs/rcf.bnl.gov/phenix/sphenixraw/MDC1/sHijing_HepMC"} = 1;

if ($#ARGV < 0)
{
    print "available types:\n";

    $getdsttypes->execute();
    while (my @res = $getdsttypes->fetchrow_array())
    {
	print "$res[0]\n";
    }
    exit(1);
}


my $type = $ARGV[0];
my $getsegments = $dbh->prepare("select segment,filename from datasets where dsttype = ? and  filename like '%$systemstring%' order by segment")|| die $DBI::error;;
my $getlastseg = $dbh->prepare("select max(segment) from datasets where dsttype = ? and filename like '%$systemstring%'")|| die $DBI::error;

$getlastseg->execute($type)|| die $DBI::error;;
my @res = $getlastseg->fetchrow_array();
my $lastseg = $res[0];
$getsegments->execute($type);
my %seglist = ();
while (my @res = $getsegments->fetchrow_array())
{
    $seglist{$res[0]} = $res[1];
}
my $nsegs_gpfs = keys %seglist;
print "number of segments processed:  $nsegs_gpfs\n";
foreach my $dcdir (keys  %topdcachedir)
{
 my $getsegsdc = $dbh->prepare("select lfn from files where lfn like '$type%' and lfn like '%$systemstring%' and full_file_path like '$dcdir/$type/$type%'");
 $getsegsdc->execute();
 my $rows = $getsegsdc->rows;
 print "entries for $dcdir: $rows\n";
 $getsegsdc->finish();
}
my $chklfn = $dbh->prepare("select lfn from files where lfn = ? and full_file_path like '/pnfs/rcf.bnl.gov/sphenix/disk/MDC1/sHijing_HepMC/%'");
#my $chklfn = $dbh->prepare("select lfn from files where lfn = ? and full_file_path like '/pnfs/rcf.bnl.gov/phenix/sphenixraw/MDC1/sHijing_HepMC/%'");
for (my $iseg = 0; $iseg <= $lastseg; $iseg++)
{
    if (!exists $seglist{$iseg})
   {
	print "segment $iseg missing\n";
	next;
   }
    else
    {
	$chklfn->execute($seglist{$iseg});
	if ($chklfn->rows == 0)
	{
	    print F "$seglist{$iseg}\n";
	    print "$seglist{$iseg} missing\n";
	}
    }
}
close(F);
$chklfn->finish();
$getsegments->finish();
$getlastseg->finish();
$getdsttypes->finish();
$dbh->disconnect;
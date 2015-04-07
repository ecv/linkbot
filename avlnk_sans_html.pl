#!/usr/bin/perl

#
# Web page for pam
# (c)2011 Matt Lee <zebe@zebe.net>
#
# Based on Web page for awlnk
# (c)2003 Taner Halicioglu <taner@taner.net>
#

use CGI;
use DB_File;
use DBI;

my $webhost = "http://pab.st/v?";
my $database = "avlnk";
my $user = "avlnk";
my $password = "caiMoaYi7";
my $dsn = "DBI:mysql:database=$database";
my %args = (
  'RaiseError' => 1,
);
my $dbh = DBI->connect($dsn, $user, $password, \%args);

my $c = new CGI;

if (!$dbh) {
  print("DBI error: $DBI::errstr");
  exit;
}

my $encode = $ARGV[0];
if ($encode !~ /\w{4}/) { header(-status => 404) }

my $q = sprintf("
SELECT real_url, encoded_url, username, count, unix_timestamp(date)
  FROM urls
 WHERE encoded_url = %s
", $dbh->quote($encode));
my $sth = $dbh->prepare($q);
$sth->execute();
my $ret;

while (my @r = $sth->fetchrow_array) {
  ($url, $ret, $who, $count, $when) = @r;
};

if (defined $ret) {
  $q = sprintf("
UPDATE urls
 SET count = count+1
 WHERE encoded_url = %s
", $dbh->quote($encode));
  $dbh->do($q);
  $count++;

  print $c->redirect($url);  # RETURN 301
  exit;
}

# if we've got this far, bail
header(-status => 404) 

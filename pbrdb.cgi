#!/usr/bin/perl

use DB_File;
use LWP;
use DBI;

use strict;

my $database = "avlnk";
my $user     = "avlnk";
my $password = "caiMoaYi7";
my $dsn      = "DBI:mysql:database=$database:172.16.1.100:3306";

my $logfile  = "/opt/avara/pbrdb.log";

open my $oldout, ">&STDOUT";
open STDOUT, '>', $logfile or die "Can't open logfile '$logfile' for output: $! ";
open STDERR, ">&STDOUT" or die "Can't dup STDOUT: $! ";
select STDERR; $| = 1;
select STDOUT; $| = 1;

# GET /url

# encode_url:
#   shorten url
#   if already in db, 
#     return repost shame ('nice repost - $nick posted it $when')

	my $q = sprintf("
SELECT real_url, encoded_url, username, count, unix_timestamp(date)
 FROM urls
 WHERE real_url = %s
", $dbh->quote($URL));

	my $sth = $dbh->prepare($q);
	$sth->execute();
	my ($ret, $code, $who, $count, $when);
	while (my @r = $sth->fetchrow_array) {
		($ret, $code, $who, $count, $when) = @r;
	}
	$sth->finish;

#   else,
#     silently add to pbrdb,
#     return 

	my $str;
	do {
		# grab a random 4-char string
		$str = "";
		foreach (1..4) {
			my $r = int(rand(length($string)));
			$str .= sprintf("%s", (split(//, $string))[$r]);
		}
	} until (Code_OK($str));
	$q = sprintf("
INSERT INTO urls (real_url, encoded_url, username, count, date)
VALUES (%s, %s, %s, 0, from_unixtime(%s))",
		$dbh->quote($URL), $dbh->quote($str), $dbh->quote($nick), $NOW);
	$dbh->do($q);
	print "New URL: $URL = $str\n";
	return sprintf("https://$BASE_URL/a?%s", $str);
}



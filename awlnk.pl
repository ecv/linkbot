#!/usr/bin/perl

#
# Web page for awlnk
#
# (c)2003 Taner Halicioglu <taner@taner.net>
#

use DB_File;
use DBI;

print "Content-type: text/html\n";

my $TOP = 10;
my $LAST = 40;
my $POSTER = 15;

my $webhost = "http://pab.st/s?";
my $database = "awlnk";
my $user = "awlnk";
my $password = "ukamNgRfjYfrxL5g";
my $dsn = "DBI:mysql:database=$database:172.16.1.100:3306";
my %args = (
        'RaiseError' => 1,
);
my $dbh = DBI->connect($dsn, $user, $password, \%args);

if (!$dbh) {
        Error("DBI error: $DBI::errstr");
        exit;
}

# handle both command line and fcgi query_string
#
my $encode; 
if (defined($ARGV[0])) {
	$encode = $ARGV[0];
	} else {
	if (defined($ENV{'QUERY_STRING'})) {
		$encode = $ENV{'QUERY_STRING'};
	}
}
 
if (!$encode) {
	print "\n";
	my ($q, $sth, $total);
	$q = sprintf("SELECT count(*) FROM urls");
	$sth = $dbh->prepare($q);
	$sth->execute();
	while (my @r = $sth->fetchrow_array) {
		$total = $r[0];
	}
	# No arg, just dump top 5 and last 10
	#select * from urls order by count desc, date desc limit 5;
	#print "As of ", scalar localtime(time), " - $total total URLs<br>";
	print <<EOHTML;
<!DOCTYPE html>
<html>
<head>
<title>pab.st redir summary</title>
<link rel="stylesheet" type="text/css" href="http://pab.st/awlnk/awlnk.css">
<script src="//use.edgefonts.net/molengo;ruluko.js"></script>

</head>

<body>
<div class="container">
<div class="header">
</div>
<div class="main">
<h1>pab.st URLs</h1>
<p>
<h2>Top $TOP viewed URLs:</h2>
<table border=1 name="top">
<tr>
 <th>Count</th>
 <th>Date Added</th>
 <th>Who</th>
 <th>Code</th>
 <th>URL</th>
</tr>
EOHTML
	$q = sprintf("
SELECT real_url, encoded_url, username, count, unix_timestamp(date)
 FROM urls
 ORDER BY count desc, date desc limit %s
", $TOP);
	my $sth = $dbh->prepare($q);
	$sth->execute();
	while (my @r = $sth->fetchrow_array) {
		my ($url, $code, $who, $count, $when) = @r;
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($when);
		$year+=1900;
		$mon++;
		$who =~ s/\s/&nbsp;/g;
		my $date = sprintf("%04d/%02d/%02d&nbsp;%02d:%02d:%02d",
		$year, $mon, $mday, $hour, $min, $sec);
		$url =~ s/\&/\&amp;/g;
		print <<EOHTML;
<tr>
 <td>$count</td>
 <td>$date</td>
 <td>$who</td>
 <td><a href="$webhost$code">$code</a></td>
 <td><a href="$webhost$code">$url</a></td>
</tr>
EOHTML
	}
	print "</table>";
# LAST
	print <<EOHTML;

<h2>Last $LAST submitted URLs:</h2><br>
<table border=1 name="last">
<tr>
 <th>Date Added</th>
 <th>Count</th>
 <th>Who</th>
 <th>Code</th>
 <th>URL</th>
</tr>
EOHTML
	my $q = sprintf("
SELECT real_url, encoded_url, username, count, unix_timestamp(date)
 FROM urls
 ORDER BY date desc limit %s
", $LAST);
	my $sth = $dbh->prepare($q);
	$sth->execute();
	while (my @r = $sth->fetchrow_array) {
		my ($url, $code, $who, $count, $when) = @r;
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($when);
		$year+=1900;
		$mon++;
		$who =~ s/\s/&nbsp;/g;
		my $date = sprintf("%04d/%02d/%02d&nbsp;%02d:%02d:%02d",
			$year, $mon, $mday, $hour, $min, $sec);
		$url =~ s/\&/\&amp;/g;
		print <<EOHTML;
<tr>
 <td>$date</td>
 <td>$count</td>
 <td>$who</td>
 <td><a href="$webhost$code">$code</a></td>
 <td><a href="$webhost$code">$url</a></td>
</tr>
EOHTML
	}
	print "</table>";
# TOP POSTERS
	print <<EOHTML;
<table border=2 name="top_posters">
<tr>
 <td align=center>
<h2>Top $POSTER posters by posted:</h2><br>
<table border=1 name="top_posters_inner">
<tr>
 <th>Posts</th>
 <th>Who</th>
</tr>
EOHTML
	my $q = sprintf("
SELECT count(username) as A,username
 FROM urls
 GROUP BY username
 ORDER by A DESC
 LIMIT %s
", $POSTER);
	my $sth = $dbh->prepare($q);
	$sth->execute();
	while (my @r = $sth->fetchrow_array) {
		my ($count, $who) = @r;
		$who =~ s/\s/&nbsp;/g;
		print <<EOHTML;
<tr>
 <td>$count</td>
 <td>$who</td>
</tr>
EOHTML
	}
	print <<EOHTML;

</table>
</td>
<td align=center>
<font size=4>Top $POSTER posters by views:</font><br>
<table border=1>
<tr>
 <th>Views</th>
 <th>Who</th>
</tr>

EOHTML
	my $q = sprintf("
SELECT sum(count) as A,username
 FROM urls
 GROUP BY username
 ORDER by A DESC
 LIMIT %s
", $POSTER);
	my $sth = $dbh->prepare($q);
	$sth->execute();
	while (my @r = $sth->fetchrow_array) {
		my ($count, $who) = @r;
		$who =~ s/\s/&nbsp;/g;
		print <<EOHTML;
<tr>
 <td>$count</td>
 <td>$who</td>
</tr>
EOHTML
	}
	print <<EOHTML;

</table>
</td>
</tr>
</table>
</div>
</div>
</body>
</html>
EOHTML
	exit;
}

if (	(length($encode) != 4) ||
	($encode !~ /^[a-zA-Z0-9]+$/)) {
	Error("Invalid code: '$encode'");
	exit;
}

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
	print "Refresh: 1; URL=$url\n\n";
	printf("You are being redirected to <a href=\"%s\">%s</a><br>\n", $url, $url);
	printf("(url added %s by %s - viewed %s times)<br>\n", scalar localtime($when), $who, $count);
	exit;
}
Error("Unknown code: '$encode'");

exit;
# -------------------------------------------------------------
sub Error {
	my $string = shift;

	printf("\n<font color=red>ERROR: $string</font><br>\n");
}

#!/usr/bin/perl

#
# Web page for pam
# (c)2011 Matt Lee <zebe@zebe.net>
#
# Based on Web page for awlnk
# (c)2003 Taner Halicioglu <taner@taner.net>
#

use DB_File;
use DBI;

print "Content-type: text/html\n";

my $TOP = 10;
my $LAST = 100;
my $POSTER = 15;

my $webhost = "http://pab.st/a?";
my $database = "avlnk";
my $user = "avlnk";
my $password = "caiMoaYi7";
my $dsn = "DBI:mysql:database=$database";
my %args = (
        'RaiseError' => 1,
);
my $dbh = DBI->connect($dsn, $user, $password, \%args);

if (!$dbh) {
        Error("DBI error: $DBI::errstr");
        exit;
}


my $encode = $ARGV[0];

if (!$encode) {
	print "\n";
	my ($q, $sth, $total);
	$q = sprintf("SELECT count(*) FROM urls");
	$sth = $dbh->prepare($q);
	$sth->execute();
	while (my @r = $sth->fetchrow_array) {
		$total = $r[0];
	}
	# No arg, just dump top $TOP and last $LAST
	#select * from urls order by count desc, date desc limit 5;

print <<EOHTML;
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  <title>URL list | pab.st/a</title>
  <link type="text/css" rel="stylesheet" media="all" href="a.css">
</head>
<body>
<div id="page-heading">
<img src="bowling.jpg" width="200" height="300" alt="bowling"><img src="patio.gif" width="218" height="300" alt="patio"><img src="http://rumspringa.subtle.org/~zebe/pabstbillboard.jpg" width="400" height="296" alt="what will you have sir">
</div> <!-- /#page-heading -->

<div id="contentarea">
  <h1 id="page-title">Delicious copypab.st/a.</h1>
EOHTML

	print "As of ", scalar localtime(time), " - $total total URLs<br>";
	print <<EOHTML;

<h2 id="topviewed-heading">$TOP Most Viewed</h2>

<table class="url-table">
  <thead>
    <tr>
      <th>Count</th>
      <th>Date Added</th>
      <th>Who</th>
      <th>Code</th>
      <th>URL</th>
    </tr>
  </thead>
  <tbody>
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
      <td class="numeral-td">$count</td>
      <td class="date-td">$date</td>
      <td>$who</td>
      <td><a href="$webhost$code">$code</a></td>
      <td class="url-td"><a href="$webhost$code">$url</a></td>
    </tr>
EOHTML
	}
	print "  </tbody>\n</table>";
# LAST
	print <<EOHTML;

<h2 id="lastn-heading">$LAST Most Recent</h2>

<table class="url-table">
  <thead>
    <tr>
      <th>Count</th>
      <th>Date Added</th>
      <th>Who</th>
      <th>Code</th>
      <th>URL</th>
    </tr>
  </thead>
  <tbody>
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
 <td class="numeral-td">$count</td>
 <td class="date-td">$date</td>
 <td>$who</td>
 <td><a href="$webhost$code">$code</a></td>
 <td class="url-td"><a href="$webhost$code">$url</a></td>
</tr>
EOHTML
	}
	print "  </tbody>\n</table>";

# TOP POSTERS
	print <<EOHTML;

<table>
<tr><td class="tdspacer">

<h3>Total Posts by User</h3>
(total links posted by listed user)
<table class="posters-table">
  <thead>
    <tr>
      <th>Posts</th>
      <th>Who</th>
    </tr>
  </thead>
  <tbody>
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
 <td class="numeral-td">$count</td>
 <td>$who</td>
</tr>
EOHTML
	}
	print <<EOHTML;

  </tbody>
</table>
</td>
<td class="tdspacer">
<h3>Total Views by User</h3>
(click-throughs by others on links posted by listed user)
<table class="posters-table">
  <thead>
    <tr>
      <th>Views</th>
      <th>Who</th>
    </tr>
  </thead>
  <tbody>
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
 <td class="numeral-td">$count</td>
 <td>$who</td>
</tr>
EOHTML
	}
	print <<EOHTML;
  </tbody>
</table>
</td></tr></table>
</div> <!-- /#contentarea -->
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
	print "Refresh: 0; URL=$url\n\n";
#	printf("You are being redirected to <a href=\"%s\">%s</a><br>\n", $url, $url);
#	printf("(url added %s by %s - viewed %s times)<br>\n", scalar localtime($when), $who, $count);
	exit;
}
Error("Unknown code: '$encode'");

exit;
# -------------------------------------------------------------
sub Error {
	my $string = shift;

	printf("\n<span class=\"red-error\">ERROR: $string</span><br />\n");
}


#!/usr/bin/perl

use Net::IRC;
use DB_File;
use Time::HiRes qw(sleep);
use LWP;

use DBI;

use strict;

my $VERSION = "1.0";
my %CMD = (
	'shutdown'	=> '__SHUTDOWN__',
	'restore'	=> '__RESTORE__',
	'jump'		=> '__JUMP__',
	'bail'		=> '__BAIL__',
	'reload'	=> '__RELOAD__',
	'join'		=> '__JOIN__',
);

my $irc = new Net::IRC;

my $local_hostname = "pab.st";

my $conn;

$0 = "avlnk version $VERSION";

my $database = "avlnk";
my $user = "avlnk";
my $password = "caiMoaYi7";
my $dsn = "DBI:mysql:database=$database:172.16.1.100:3306";
my %args = (
	'RaiseError' => 1,
);

my %STOCK_CACHE;

my @SERVERS = (
	"spruce.subtle.org",
	"parkcentral.subtle.org"
);

my $MIN_LENGTH = 53;


fork && do {
	print "avlnk started";
	exit;
};

# pipe STDOUT to logfile
my $logfile = "/opt/avara/avlnk.log";

open my $oldout, ">&STDOUT";

open STDOUT, '>', $logfile or die "Can't open logfile '$logfile' for output: $! ";
open STDERR, ">&STDOUT" or die "Can't dup STDOUT: $! ";
select STDERR; $| = 1;
select STDOUT; $| = 1;

my $CON = 0;
my $NICK = "pam";
my $mynick = $NICK;
my $ircname = "that's what she said";
my $mychan = "#avara";

my $this_program = $0;
my $SERVER_INDEX = 0;

# Fudge.
$CON = 1;
my $server;

while (!$conn) {
	$server = get_server();
	$CON = 0;
	eval {
		local $SIG{ALRM} = sub { die "timeout"; };
		alarm 10;
		$conn = $irc->newconn(
			Nick    => $mynick,
                        Server  => $server,
                        Port    => 6697,
                        Ircname => $ircname,
                        SSL => '1',
			LocalAddr => $local_hostname
		);
		return if $irc->error;
		alarm 0;
	};
	alarm 0;
	sleep 2 if (!$conn);
}
$CON = 1;
$conn->add_global_handler('001', \&on_connect);
$conn->add_global_handler('msg', \&on_msg);
$conn->add_global_handler('caction', \&on_action);
$conn->add_global_handler('disconnect', \&on_disconnect);
$conn->add_global_handler('kick', \&on_kick);
$conn->add_global_handler(433, \&on_nick_taken);
$conn->add_global_handler('join', \&on_join);
$conn->add_global_handler('public', \&on_public);
$conn->add_global_handler('ison', \&on_ison);
$conn->add_global_handler('cping',  \&on_ping);
$conn->add_global_handler('cversion',  \&on_version);
$conn->add_global_handler('topic',  \&on_topic);


my $count = 0;
my $start = time;
while (1) {
        $irc->do_one_loop();
	if (!$CON) {
		$conn->disconnect if ($conn);
		undef $conn;
	}
	if (!$conn) {
		while (!$conn) {
			$server = get_server();
			$CON = 0;
			eval {
				local $SIG{ALRM} = sub { die "timeout"; };
				alarm 10;
				$conn = $irc->newconn(
					Nick    => $mynick,
                        		Server  => $server,
                        		Port    => 6697,
                        		Ircname => $ircname,
                        		SSL => '1',
					LocalAddr => $local_hostname
				);
				alarm 0;
			};
			alarm 0;
			sleep 2 if (!$conn);
		}
		$CON = 1;
		$conn->add_global_handler('001', \&on_connect);
		$conn->add_global_handler('msg', \&on_msg);
		$conn->add_global_handler('caction', \&on_action);
		$conn->add_global_handler('disconnect', \&on_disconnect);
		$conn->add_global_handler('kick', \&on_kick);
		$conn->add_global_handler(433, \&on_nick_taken);
		$conn->add_global_handler('join', \&on_join);
		$conn->add_global_handler('public', \&on_public);
		$conn->add_global_handler('ison', \&on_ison);
		$conn->add_global_handler('cping',  \&on_ping);
		$conn->add_global_handler('cversion',  \&on_version);
		$conn->add_global_handler('topic',  \&on_topic);
	}
	if ($conn) {
		if ($mynick ne $NICK) {
			sleep 0.1;
			$count++;
			if ($count >= 5) {
				printf("Trying to regain '$NICK'\n");
				$conn->ison($NICK);
				$count = 0;
			}
		}
		if ((time - $start) >= 60) {
			#printf("[%s] - pingcheck\n", scalar localtime(time));
			$conn->ctcp("PING", $mynick);
			$start = time;
		}
	}
	sleep 0.25;
}

# ----------------------------------------------------------------------

sub on_connect {
	my $self = shift;
	$CON=1;
	print "Joining $mychan...\n";
	$self->join($mychan);
	#$self->join($mychan2);
	#$self->join($mychan3);
	#$self->join($mychan4);
	#$self->join($mychan5);
	#$self->join($mychan6);
}

sub on_kick {
	my $self = shift;
	print "Re-Joining $mychan...\n";
	$self->join($mychan);
}

sub on_msg {
	my ($self, $event) = @_;
	my ($nick) = $event->nick;
	my @args = $event->args;
	my $cmd = $args[0];
	my $argstr = join(" ", @args);

	print "PRIVMSG: *$nick*  ", $argstr, "\n";
	if ($cmd eq $CMD{'jump'}) {
		$self->quit("Jumping servers...");
		$conn->disconnect;
		undef $conn;
		return;
	}
	if ($cmd eq $CMD{'shutdown'}) {
		if ($mynick eq $NICK) {
			printf("*** Remote Shutdown ignored (same nick)\n");
			$self->privmsg($nick, "Remote Shutdown ignored - I'm on my primary nick!");
			return;
		}
		printf("*** Attempting to shut down other running bot...\n");
		$self->privmsg($nick, "Trying to shut down other bot ($NICK)");
		$self->privmsg($NICK, "_get_OUT!");
		return;
	}
	if ($cmd eq $CMD{'restore'}) {
		printf("*** Attempting NICK restore ($mynick -> $NICK) by $nick\n");
		$self->privmsg($nick, "Trying to restore nickname to \"$NICK\"");
		$self->nick($NICK);
		return;
	}
	if ($argstr =~ /^\.(\S+)\s*(.*)$/) {
		my $cmd = $1;
		my $param = $2;
		if ($cmd =~ /^last$/i) {
			($param) = split(/\s+/, $param);
			$param =~ s/[^-A-Za-z0-9_`\[\]\{\}\\\|\^]//g;
			printf("Cleaned up = '%s'\n", $param);
			return if (! $param);
			if ($param =~ /^$nick$/i) {
				$self->privmsg($nick, "Um, ok... the last thing you said was...");
				last_public($self, $nick, $param);
				return;
			}
			if ($param =~ /^$mynick$/i) {
				$self->privmsg($nick, "I don't keep track of myself :-P");
				return;
			}
			last_public($self, $nick, $param);
			return;
		}
		if ($cmd =~ /^(q|quote|stock)$/) {
			do_quote($self, $nick, $nick, $param);
			return;
		}
		return;
	}
	if ($argstr =~ /\"((http|ftp|rtsp|https):\/\/\S+)\"/) {
		my $passed_url = $1;
		$passed_url = clean_url($passed_url);
		my $url;
		$url = encode_url($passed_url, "${nick} (pm)");
		$self->privmsg($nick, "$url");
		#$self->privmsg($nick, "$url") if (length($passed_url) > $MIN_LENGTH);
		#$self->privmsg($nick, "URL is short enough already. :)")
		#	if (length($passed_url) < $MIN_LENGTH);
		return;
	}
	if ($argstr =~ /((http|ftp|rtsp|https):\/\/\S+)/) {
		my $passed_url = $1;
		$passed_url = clean_url($passed_url);
		my $url;
		$url = encode_url($passed_url, "${nick} (pm)");
		$self->privmsg($nick, "$url");
		#$self->privmsg($nick, "$url") if (length($passed_url) > $MIN_LENGTH);
		#$self->privmsg($nick, "URL is short enough already. :)")
		#	if (length($passed_url) < $MIN_LENGTH);
		return;
	}
	if ($cmd eq $CMD{'reload'}) {
		printf("*** RELOADING '$this_program' from $nick\n");
		$self->quit("Be right back!");
		exec $this_program;
	}
	if ($cmd eq $CMD{'bail'}) {
		printf("*** BAILING from $nick\n");
		$self->quit("I'm outta here!!!!");
		exit;
	}
}

sub on_public {
	my ($self, $event) = @_;
	my ($nick) = $event->nick;
	my $channel = ($event->to)[0];
	my @args = $event->args;
	my $argstr = join(" ", @args);

    # effectively, an ignore list
#	return if ($nick =~ /Sophist/i);

	if ($argstr =~ /\"((http|ftp|rtsp|https):\/\/\S+)\"/) {
		my $passed_url = $1;
		$passed_url = clean_url($passed_url);
		my $url;
		$url = encode_url($passed_url, $nick);
		if (length($passed_url) > $MIN_LENGTH) {
			if ($url =~ /\(\002repost\002 from (.+) by (.+) - viewed (\d+) times\)/) {
				my $when = $1;
				my $who = $2;
				my $views = $3;
				if ($who =~ /You/) {
					$url =~ s/\s+\(.+\)$//g;
					$self->privmsg($channel, "<$nick> $url ($views views since $when)");
					return;
				}
			}
			$self->privmsg($channel, "<$nick> $url")
		} else {
			#(\002repost\002 from %s by %s - viewed %s times)
			if ($url =~ /\(\002repost\002 from (.+) by (.+) - viewed (\d+) times\)/) {
				my $who = $2; my $when = $1;
				return if ($who =~ /You/);
				$url =~ s/\s+\(.+\)$//g;
				$self->privmsg($channel, "Nice \002repost\002, $nick - $who posted that $when. ($url)");
			}
		}
		record_public($self, $channel, $nick, $argstr);
		return;
	}
	if ($argstr =~ /((http|ftp|rtsp|https):\/\/\S+)/) {
		my $passed_url = $1;
		my $url;
		$url = encode_url($passed_url, $nick);
		if (length($passed_url) > $MIN_LENGTH) {
			if ($url =~ /\(\002repost\002 from (.+) by (.+) - viewed (\d+) times\)/) {
				my $when = $1;
				my $who = $2;
				my $views = $3;
				if ($who =~ /You/) {
					$url =~ s/\s+\(.+\)$//g;
					$self->privmsg($channel, "<$nick> $url ($views views since $when)");
					return;
				}
			}
			$self->privmsg($channel, "<$nick> $url")
		} else {
			#(\002repost\002 from %s by %s - viewed %s times)
			if ($url =~ /\(\002repost\002 from (.+) by (.+) - viewed (\d+) times\)/) {
				my $who = $2; my $when = $1;
				return if ($who =~ /You/);
				$url =~ s/\s+\(.+\)$//g;
				$self->privmsg($channel, "Nice \002repost\002, $nick - $who posted that $when. ($url)");
			}
		}
		record_public($self, $channel, $nick, $argstr);
		return;
	}
	if ($argstr =~ /^\.(\S+)\s*(.*)$/) {
		my $cmd = $1;
		my $param = $2;
		if ($cmd =~ /^last$/i) {
			($param) = split(/\s+/, $param);
			$param =~ s/[^-A-Za-z0-9_`\[\]\{\}\\\|\^]//g;
			printf("Cleaned up = '%s'\n", $param);
			return if (! $param);
			if ($param =~ /^$nick$/i) {
				$self->privmsg($channel, "Uh, are you high?");
				return;
			}
			if ($param =~ /^$mynick$/i) {
				$self->privmsg($channel, "STFU n00b!");
				return;
			}
			last_public($self, $channel, $param);
			return;
		}
		if ($cmd =~ /^(q|quote|stock)$/) {
			do_quote($self, $channel, $nick, $param);
			return;
		}
		return;
	}
	record_public($self, $channel, $nick, $argstr);
}

sub on_action {
	my ($self, $event) = @_;
	my ($nick, @args) = ($event->nick, $event->args);
	my $channel = ($event->to)[0];
	my $argstr = join(" ", @args);

	print "* $nick $argstr\n";
	record_public($self, "ACTION_".$channel, $nick, $argstr);
}

sub on_disconnect {
	my ($self, $event) = @_;

	#$server = get_server();
	print "*** Disconnected from ", $event->from(), " (",
		($event->args())[0], "). Attempting to reconnect...\n";
	#$self->server($server);
	$CON = 0;
	#$self->connect();
}

sub on_join {
	my ($self, $event) = @_;

	printf("*** %s (%s) joined %s\n", $event->nick, $event->userhost, join(', ', $event->to));
}


sub on_topic {
	my ($self, $event) = @_;

	printf("*** TOPIC: %s\n", join('|', $event->args));
	printf("*** %s (%s) set topic on %s to %s\n", $event->nick, $event->userhost, join(', ', $event->to));
}


sub on_nick_taken {
	my ($self, $event) = @_;
	my @args = $event->args;
	printf("*** Nick taken: @args\n");
	$mynick = $NICK . int(rand(1000));
	$self->nick($mynick);
}

sub on_ison {
	my ($self, $event) = @_;
	my @args = $event->args;
	printf("*** ison: [%s]\n", join(' ', @args));
	my $test = $args[1];
	$test =~ s/\s+$//g;
	$test =~ s/^\s+//g;
	if ($test ne $NICK) {
		printf("*** $NICK seems free - attempting to retake it...\n");
		$mynick = $NICK;
		$self->nick($mynick);
	}
}
sub on_ping {
	my ($self, $event) = @_;
	my $nick = $event->nick;
	my @args = $event->args;

	$self->ctcp_reply($nick, join (' ', "PING", @args));
	printf("*** CTCP PING (%s - %s) request from %s received\n", join (' ', @args), scalar localtime($args[0]), $nick) if ($nick ne $mynick);
}
sub on_version {
	my ($self, $event) = @_;
	my $nick = $event->nick;

	$self->ctcp_reply($nick, "VERSION avlnk bot v${VERSION}");
	printf("*** CTCP VERSION (%s) request from %s received\n", join (' ', ($event->args)), $nick);
}

sub get_server {
	$SERVER_INDEX++ if ($CON == 0);
	$SERVER_INDEX = 0 if ($SERVER_INDEX > $#SERVERS);
	printf("Server = %s [IDX:%s/%s - CON:%s]\n", $SERVERS[$SERVER_INDEX], $SERVER_INDEX, $#SERVERS, $CON);
	return $SERVERS[$SERVER_INDEX];
	return if $irc->error;
}

sub encode_url {
	my $URL = shift;
	my $nick = shift;
	my $BASE_URL = "pab.st";
	return undef if ($URL =~ /boom.net\/aw/);
	return undef if ($URL =~ /$BASE_URL/);
	#return undef if (length($URL) < 55);
	my $NOW = time;
	my $string = 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

	my $dbh = DBI->connect($dsn, $user, $password, \%args);

	if (!$dbh) {
		return("HELP: $DBI::errstr");
	}

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

	if ($ret) {
		printf("REPOST: $URL = $code\n");
		return sprintf("http://$BASE_URL/s?%s   (\002repost\002 from %s by %s - viewed %s times)",
			$code, sprintf("%s ago", pp($when)),
			$who ? ($who eq $nick) ? "You!" : $who :
			"unknown", $count);
	}
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
	return sprintf("http://$BASE_URL/a?%s", $str);
}

sub record_public {
	my $self = shift;
	my $channel = shift;
	my $nick = shift;
	my $msg = shift;

	my $C = $channel;
	$C =~ s/^ACTION_//g;

	my $dbh = DBI->connect($dsn, $user, $password, \%args);

	if (!$dbh) {
		$self->privmsg($C, "DB Error (no dbh): $DBI::errstr");
		printf("HELP: $DBI::errstr\n");
		return("HELP: $DBI::errstr");
	}
	my $q;
	$q = sprintf("
REPLACE INTO msgs
 (last_public, last_channel, last_nick, last_date)
VALUES
 (%s, %s, %s, from_unixtime(%s))", $dbh->quote($msg), $dbh->quote($channel), $dbh->quote($nick), time);
	$dbh->do($q);
	printf("DB Error (dbh->do): $DBI::errstr\n") if ($DBI::errstr);
	$self->privmsg($C, "DB Error (dbh->do): $DBI::errstr") if ($DBI::errstr);
}

sub last_public {
	my $self = shift;
	my $channel = shift;
	my $nick = shift;

	my $dbh = DBI->connect($dsn, $user, $password, \%args);

	if (!$dbh) {
		$self->privmsg($channel, "DB Error (no dbh): $DBI::errstr");
		printf("HELP: $DBI::errstr\n");
		return("HELP: $DBI::errstr");
	}
	my $q;
	$q = sprintf("SELECT last_nick, last_public, last_date, last_channel FROM msgs WHERE last_nick LIKE %s",
		$dbh->quote($nick));
	my $sth = $dbh->prepare($q);
	if (!$sth) {
		$self->privmsg($channel, "DB Error (no cursor): $DBI::errstr");
		printf("sth error: $DBI::errstr\n");
		return;
	}
	$sth->execute();
	my ($last_nick, $last_msg, $last_time, $last_channel);
	while (my @r = $sth->fetchrow_array) {
		($last_nick, $last_msg, $last_time, $last_channel) = @r;
	}
	$sth->finish;
	if ($last_msg) {
		if ($last_channel =~ /^ACTION_/) {
			$self->privmsg($channel, sprintf("[%s] * %s %s", $last_time, $last_nick, $last_msg));
		} else {
			$self->privmsg($channel, sprintf("[%s] <%s> %s", $last_time, $last_nick, $last_msg));
		}
		return;
	}
	$self->privmsg($channel, sprintf("I have no 'last message' for %s, sorry.", $nick));
}

sub Code_OK {
	my $code = shift;

	my $dbh = DBI->connect($dsn, $user, $password, \%args);

	return 0 if (!$dbh);

	my $q = sprintf("
SELECT real_url
 FROM urls
 WHERE encoded_url = %s
", $dbh->quote($code));

	my $sth = $dbh->prepare($q);
	$sth->execute();
	my ($ret, $code, $who, $count, $when);
	while (my @r = $sth->fetchrow_array) {
		($ret) = @r;
	}
	$sth->finish;
	return $ret ? 0 : 1;
}

sub clean_url {
	my $url = shift;

	# Make the URL have only printable chars.
	# NOTE: This is gross.

	my @chars = split(//, $url);
	my @newchars;

	foreach my $char (@chars) {
		last if (ord($char) <32);
		last if ((ord($char) > 127) && (ord($char) < 160) );
		push @newchars, $char;
	}
	return join ("", @newchars);
}

sub pp {
	my $timestamp = shift;

	$timestamp = time - $timestamp;

	my ($day, $hour, $min, $sec);

	return "unknown" if (!$timestamp);

	$sec = $timestamp % 60;
	$min = int($timestamp / 60) % 60;
	$hour = int($timestamp / (60*60)) % 24;
	$day = int($timestamp / (60*60*24));

	return sprintf("%1d:%02d:%02d:%02d", $day, $hour, $min, $sec);
}

################################
# do_quote( $self, $destination, $source, $ticker )
#	$destiantion = where to reply (a channel, or a nickname)
#	$source = who sent me the query
#	$ticker = The ticker(s) to look up - can be whitespace, comma, or plus-sign separated
################################
sub do_quote {
	my $self = shift;
	my $dest = shift;
	my $nick = shift;
	my $param = shift;

	my $MAX_TICK = 2;	# +1
	my $stock_url = "http://finance.yahoo.com/d/q?f=nsl1c1p2vk1c6&s=";

	my $ticker = uc($param);
	my @tickers = split(/[\+\s,]/, $ticker);

	#($ticker) = split(/\+/, $ticker) if ($ticker =~ /\+/);	# No tricks!

	return if ($#tickers == -1);

	if ($#tickers > $MAX_TICK) {
		$self->privmsg($nick, sprintf("Too many tickers - doing first %s (unless some are cached).", $MAX_TICK+1));
	}
	my (@temp_t, $cnt);
	my %saw = ();
	foreach my $ticker (@tickers) {

### Debug
printf ("Doing $ticker [%s] [%s]...\n", $STOCK_CACHE{$ticker} ? scalar
localtime($STOCK_CACHE{$ticker}->{'time'}) : "New", $STOCK_CACHE{$ticker} ?
$STOCK_CACHE{$ticker}->{'data'} : "New");

		if ($ticker !~ /^[A-Z\^\.]+$/) {
			printf("Warning: weird chars in '$ticker', stripping\n");	### Debug
			$ticker =~ s/[^A-Z\^\.]//g;
			$self->privmsg($nick, sprintf("Found weird chars, stripped, getting '%s'", $ticker));
		}
		next if (! $ticker);
		next if ($saw{$ticker});
		$saw{$ticker}++;
		if (length($ticker) > 8) {
			printf("Ticker '$ticker' too long\n");				 ### Debug
			$self->privmsg($nick, sprintf("Ticker '$ticker' too long, skipping."));
			next;
		}
		if ((time - $STOCK_CACHE{$ticker}->{'time'}) < 10) {
			printf("Using cached value %s for stock %s.\n", $STOCK_CACHE{$ticker}->{'data'}, $ticker); ### Debug
			$self->privmsg($dest, sprintf("%s (cached)", $STOCK_CACHE{$ticker}->{'data'}));
			next;
		}
		last if ($cnt++ > $MAX_TICK);
		push @temp_t, $ticker;
	}
	@tickers = @temp_t;
	return if ($#tickers == -1);

	# "SUN MICROS","SUNW",5.06,+0.87,"+20.76%",4.56,5.12,4.45,214390656
	# ...but notice the comma in some company names breaks things:
	# "Tesla Motors, Inc.","TSLA",203.25,+0.15,"+0.07%",4346555,N/A,N/A

	$ticker = join ('+', @tickers);

	my $url = sprintf("%s%s", $stock_url, $ticker);
	my $ua = LWP::UserAgent->new;
	$ua->agent("AwLink/$VERSION");
	$ua->timeout(5);
	my $req = HTTP::Request->new(GET => $url);
	my $res = $ua->request($req);
	if ($res->is_success) {
		printf("[%s] [%s]\n", $res->message, $res->content);
		my $content = $res->content;

		my @lines = split(/[\n\r]+/, $content);
		#$content =~ s/[\n\r]//g;
		foreach my $line (@lines) {
			my ($sname, $tick, $curr, $change, $pchange, $vol, $realtime, $rtc) = split(',', $line);
			# Clean up
			$sname =~ s/"//g;
			$tick =~ s/"//g;
			$curr =~ s/"//g;
			$change =~ s/"//g;
			$pchange =~ s/"//g;
			$vol =~ s/"//g;
			$realtime =~ s/"//g;
			$realtime =~ s/\<\/?b\>//g;
			$realtime =~ s/\<\/?i\>//g;
			$realtime =~ s/\<\/?[^\>]+\>//g;
			$realtime =~ s/ \- /\: /g;
			$rtc =~ s/"//g;

			$STOCK_CACHE{$tick}->{'time'} = time;

			if (($curr eq "0.00") && ($change eq "N/A")) {
				$STOCK_CACHE{$tick}->{'data'} = sprintf("Ticker '%s' doesn't seem to exist.", $tick);
				$self->privmsg($dest, $STOCK_CACHE{$tick}->{'data'});
				next;
			}

			my ($realtime_time, $temp_rt) = split(/\s+/, $realtime);

			$realtime_time =~ s/\:$//g;

			printf("[%s] [%s] [%s]\n", $realtime, $temp_rt, $curr);
			
			# If realtime is the same as 'now', just print one value.
			if ("$temp_rt" eq "$curr") {
				$STOCK_CACHE{$tick}->{'data'} = sprintf("%s (%s): %s (%s, %s Vol:%s)",
					$sname, $tick, $curr, $change, $pchange, pp_vol($vol));
			} else {
				$STOCK_CACHE{$tick}->{'data'} = sprintf("%s (%s): %s (%s, %s Vol:%s) [RT @ %s (%s)]",
					$sname, $tick, $curr, $change, $pchange, pp_vol($vol), $realtime, $rtc);
			}
			$self->privmsg($dest, sprintf("%s", $STOCK_CACHE{$tick}->{'data'}));
		}
	} else {
		$self->privmsg($dest, sprintf("Oops, error trying to grab quote (%s: %s [%s])", $res->code, $!, $@));
	}
}

sub pp_vol {
	my $vol = shift;
	my $deg = 0;
	my @DEG = ("", "K", "M", "B");

	while ($vol >= 1000) {
		$deg++;
		$vol /= 1000;
	}
	return sprintf("%0.1f%s", $vol, $DEG[$deg]);
}

#!/usr/bin/perl
# -*- Mode: perl -*-

use strict;
use Getopt::Long;
use Config::IniHash;
use Net::IRC;
use File::Basename;
use URI;
use Web::Scraper;
use Data::Dumper;

my $cfile   = $ENV{HOME} . '/.' . basename($0, '.pl'); # ~/.acme-gazo
my $channel = undef;

# Use no Carp messages.
$SIG{__WARN__} = sub {};

my $opt = GetOptions(
    'file=s'    => \$cfile,
    'channel=s' => \$channel
    );

if ($#ARGV != 0 || ! $opt || $ARGV[0] !~ m|^https?://|o) {
    print STDERR "usage: " . basename($0) . " [--file <config file>] [--channel <channel>] <URL>\n";
    exit 1;
}
my $config = ReadINI($cfile);
my $URI = $ARGV[0];
my $CHANNEL = $channel ? $channel : $config->{defaults}{channel};

my $scr = scraper {
    process 'a', 'href[]' => sub {
	grep /jpg$/, $_->{href};
    };
    result 'href';
};
my $jpgs = $scr->scrape(URI->new($URI));

my $irc = new Net::IRC;
my $conn = $irc->newconn(
    Password => $config->{defaults}{password},
    Nick     => $config->{defaults}{nick},
    Server   => $config->{defaults}{server},
    Port     => $config->{defaults}{port}
    ); 	
sub on_connect {
    my $self = shift;

    $self->join($CHANNEL);
    foreach my $jpg (@{$jpgs}) {
	$self->privmsg($CHANNEL, $jpg);
	sleep(1);
    }
    exit;
}
$conn->add_handler('endofmotd', \&on_connect);
$irc->start;

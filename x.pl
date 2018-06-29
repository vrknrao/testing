#!/usr/bin/perl
use strict;

use LWP::Protocol::Net::Curl ssl_verifyhost => 0, ssl_verifypeer => 0;
use LWP::UserAgent;

my $url="https://build.blr.novell.com/WERMS/patches/201";
my $ua = LWP::UserAgent->new;
my $content = $ua->get($url);
print "$content\n";

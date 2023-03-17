#!/usr/bin/perl

use strict;
use v5.20;

# blow up if a variable is not set
use warnings FATAL => qw/uninitialized/;

use XML::Twig;
use utf8::all;

my $url = "mysql://$ENV{DB_USER}:$ENV{DB_USER_PW}\@$ENV{DB_HOST}/$ENV{DB_NAME}";

my $twig = XML::Twig->new(
    pretty_print => 'nsgmls' # to pretty print attributes
);

$twig->parsefile( $ARGV[0] );

my $camap_api = "https://$ENV{NEST_HOST_PUBLIC}";

say "Running in Scalingo, using public address for Nest backend";
my $camap_bridge_api = $camap_api;

my $config = $twig->root;
$config->set_att(
    database           => $url,
    camap_api          => $camap_api,
    camap_bridge_api   => $camap_bridge_api,
    host               => $ENV{NEKO_HOST_PUBLIC},
    key                => $ENV{PW_HASH_KEY},
    debug              => "0",
    mapbox_server_token => $ENV{MAPBOX_TOKEN},
);

$twig->print_to_file( $ARGV[1] ); # output the twig


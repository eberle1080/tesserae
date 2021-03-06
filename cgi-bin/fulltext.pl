#! /opt/local/bin/perl5.12

# the line below is designed to be modified by configure.pl

use lib '/Users/chris/Desktop/tesserae/perl';	# PERL_PATH

#
# read_table.pl
#
# select two texts for comparison using the big table
#

use strict;
use warnings;

use CGI qw(:standard);

use Getopt::Long;
use POSIX;
use Storable qw(nstore retrieve);
use File::Spec::Functions;

use TessSystemVars;
use EasyProgressBar;

# allow unicode output

binmode STDOUT, ":utf8";

# is the program being run from the web or
# from the command line?

my $query = CGI->new() || die "$!";

print header();

#
# cgi input
#

my $session = $query->param('session')    || die "no session specified from web interface";

#
# create the frameset and redirect to content
# 

print <<END;

<html lang="en">
	<head>
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
		<meta name="author" content="Neil Coffee, Jean-Pierre Koenig, Shakthi Poornima, Chris Forstall, Roelant Ossewaarde">
		<meta name="keywords" content="intertext, text analysis, classics, university at buffalo, latin">
		<meta name="description" content="Intertext analyzer for Latin texts">
		<link href="$url_css/style.css" rel="stylesheet" type="text/css"/>
		<link href="$url_image/favicon.ico" rel="shortcut icon"/>

		<title>Tesserae</title>

	</head>

	<frameset cols="50%,50%">
		<frame name="left" src="$url_cgi/frame.fulltext.pl?session=$session;side=left">
		<frame name="right" src="$url_cgi/frame.fulltext.pl?session=$session;side=right">
	</frameset>
</html>

END

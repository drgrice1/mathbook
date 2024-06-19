#!/usr/bin/env perl

use strict;
use warnings;
use feature 'say';

use Getopt::Long qw(:config bundling);
use Encode qw(decode_utf8);
use Mojo::DOM;

use lib "$ENV{PG_ROOT}/lib";
use WeBWorK::PG::Localize;
use WeBWorK::PG;

my $pg_root = $ENV{PG_ROOT};

my ($showVersion, $source, $sourceFilePath, $seed, $problemUUID, $templateDirectory, $tempDirectory, @extraMacroDirs);
GetOptions(
	'V|version'           => \$showVersion,
	'r|source=s'          => \$source,
	'p|sourceFilePath=s'  => \$sourceFilePath,
	's|seed=s'            => \$seed,
	'u|uuid=s'            => \$problemUUID,
	'e|externalFileDir=s' => \$templateDirectory,
	't|tempDirectory=s'   => \$tempDirectory,
	'm|extraMacroDir=s'   => \@extraMacroDirs
);

if ($showVersion) {
	our $PG_VERSION;
	do "$pg_root/VERSION";
	say $PG_VERSION;
	exit 0;
}

die 'The problem source or sourceFilePath must be provided.' unless defined $source || defined $sourceFilePath;

$templateDirectory =~ s|/?$|/| if $templateDirectory;
$tempDirectory     =~ s|/?$|/| if $tempDirectory;

my $pg = WeBWorK::PG->new(
	showSolutions       => 1,
	showHints           => 1,
	processAnswers      => 1,
	displayMode         => 'PTX',
	language_subroutine => WeBWorK::PG::Localize::getLoc('en'),
	macrosPath          => [
		'.',                     @extraMacroDirs,
		"$pg_root/macros",       "$pg_root/macros/answers",
		"$pg_root/macros/capa",  "$pg_root/macros/contexts",
		"$pg_root/macros/core",  "$pg_root/macros/deprecated",
		"$pg_root/macros/graph", "$pg_root/macros/math",
		"$pg_root/macros/misc",  "$pg_root/macros/parsers",
		"$pg_root/macros/ui"
	],
	problemSeed => $seed // 1234,
	$problemUUID       ? (problemUUID       => $problemUUID)       : (),
	$templateDirectory ? (templateDirectory => $templateDirectory) : (),
	$tempDirectory     ? (tempDirectory     => $tempDirectory)     : (),
	$sourceFilePath    ? (sourceFilePath    => $sourceFilePath)    : (),
	$source            ? (r_source          => \$source)           : ()
);

my $dom = Mojo::DOM->new->xml(1);
for my $answer (sort keys %{ $pg->{answers} }) {
	$dom->append_content($dom->new_tag(
		$answer, map { $_ => ($pg->{answers}{$answer}{$_} // '') } keys %{ $pg->{answers}{$answer} }
	));
}
$dom->wrap_content('<answerhashes></answerhashes>');
my $answerhashXML = $dom->to_string;

say "<webwork>$answerhashXML\n$pg->{body_text}\n</webwork>";

warn "errors:\n$pg->{errors}"     if $pg->{errors};
warn "warnings:\n$pg->{warnings}" if $pg->{warnings};

$pg->free;

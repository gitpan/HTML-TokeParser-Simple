#!/usr/bin/perl -w
use strict;
use warnings;
use Test;

BEGIN {
    chdir 't' if -d 't';
    unshift @INC => '../blib/lib';
    plan tests => 25;
}

use HTML::TokeParser::Simple;

my $p = HTML::TokeParser::Simple->new(\*DATA);
ok( ref $p, 'HTML::TokeParser::Simple' );

my $token = $p->get_tag;
ok( ref $token, 'HTML::TokeParser::Simple::Token' );
my $old_token = copy_array( $token );
ok( $token->is_declaration, '' );
ok( arrays_equal( $old_token, $token ), 1 );
ok( $token->is_start_tag( 'html' ), 1 );
ok( $token->is_tag( 'html' ), 1 );
ok( $token->is_tag, 1 );
ok( $token->return_tag, 'html' );
ok( $token->is_start_tag( 'fake tag' ), '' );

# important to remember that whitespace counts as a token.
$token = $p->get_tag for ( 1 .. 2 );
ok( $token->is_comment, '' );
ok( $token->return_text, '<title>' );
ok( $token->as_is, '<title>' );

$token = $p->get_tag; 

# I need to dig into this.  The behavior is inconsistent with
# get_token, which doesn't require the backslash.

ok( $token->is_end_tag( '/title' ), 1 );
ok( $token->is_end_tag( 'title' ), 1 );
ok( $token->is_end_tag( 'TITLE' ), 1 );
ok( $token->is_end_tag, 1 );

$token = $p->get_tag for 1..2;
$old_token = copy_array( $token );
ok( ref $token->return_attr, 'HASH' );
ok( $token->return_attr()->{'bgcolor'}, '#ffffff' );
ok( $token->return_attr()->{'alink'}, '#0000ff' );
ok( arrays_equal( $old_token, $token ), 1 );

$old_token = copy_array( $token );
ok( arrays_equal( $old_token, $token ), 1 );
my $arrayref = $token->return_attrseq;
ok( ref $arrayref, 'ARRAY' );
ok( scalar @{$arrayref}, 2 );
ok( $arrayref->[0], 'alink' );
ok( $arrayref->[1], 'bgcolor' );

sub copy_array {
	# use this to copy array without copying the reference
	my $aref = shift;
	my @new_array;
	push @new_array => $_ foreach @$aref;
	return \@new_array;
}

sub arrays_equal {
	my ( $aref1, $aref2 ) = @_;
	return @$aref1 == @$aref2; 
	local $_;
	foreach ( 0 .. $#$aref1 ) {
		return $aref1->[$_] eq $aref2->[$_];
	}
	return 1;
}
__DATA__
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
<html>
	<head>
		<!-- This is a comment -->
		<title>This is a title</title>
		<?php 
			print "<!-- this is generated by php -->";
		?>
	</head>
	<body alink="#0000ff" bgcolor="#ffffff">
		<h1>Do not edit this HTML lest the tests fail!!!</h1>
	</body>
</html>

#!/usr/bin/perl -w
use strict;
use warnings;
#use Test::More tests => 55;
use Test::More 'no_plan';

my $CLASS;
BEGIN {
    chdir 't' if -d 't';
    unshift @INC => '../blib/lib';
    $CLASS = 'HTML::TokeParser::Simple';
    use_ok($CLASS) || die;
}
my $TOKEN_CLASS = "${CLASS}::Token";

can_ok($CLASS, 'new');
my $p = $CLASS->new(\*DATA);
isa_ok( $p, $CLASS =>             '... and the return value' );

can_ok($p, 'get_token');
my $token = $p->get_token;
isa_ok( $token, $TOKEN_CLASS =>   '... and the return value' );

can_ok($token, 'is_declaration');
ok( $token->is_declaration,       '... and it should correctly identify one' );

$token = $p->get_token for 1 .. 2;

can_ok($token, 'is_start_tag');
ok( $token->is_start_tag('html'), '... and it should identify the token as a particular start tag' );
ok( $token->is_start_tag,         '... or as a start tag in general');
ok(!$token->is_start_tag('fake'), '... but it should not return false positives');

can_ok($token, 'return_tag');
is( $token->return_tag, 'html',   '... and it should return the correct tag' );

# important to remember that whitespace counts as a token.
$token = $p->get_token for  1 .. 4; 

can_ok($token, 'is_comment');
ok( $token->is_comment,           '... and it should correctly identify a comment' );

can_ok($token, 'return_text');
{
  my $warning;
  local $SIG{__WARN__} = sub { $warning = shift };
  is($token->return_text,
    '<!-- This is a comment -->', '... and it should return the correct text' );
  ok( $warning,                   '... while issuing a warning');                  
  like($warning, qr/return_text\(\) is deprecated.  Use as_is\(\) instead/,
                                  '... with an appropriate error message');
}

can_ok($token, 'as_is');
is( $token->as_is,
  '<!-- This is a comment -->',   '... and it should return the correct text' );

$token = $p->get_token for ( 1..3 ); 

can_ok($token, 'is_text');
ok( $token->is_text,              '... and it should correctly identify text');

$token = $p->get_token;
can_ok($token, 'is_end_tag');
ok( $token->is_end_tag('/title'), '... and it should identify a particular end tag' );
ok( $token->is_end_tag('title'),  '... even without a slash' );
ok( $token->is_end_tag('TITLE'),  '... regardless of case' );
ok( $token->is_end_tag,           '... and should identify the token as just being an end tag' );


$token = $p->get_token for ( 1..2 );

can_ok($token, 'is_process_instruction');
ok( $token->is_process_instruction, '... and it should correctly identify them' );
my $non_start_tag = $token; # squirrel this away for the set_attr test

can_ok($token, 'return_token0');
# diag($token->return_token0);
# more research needed.  This doesn't seem to return everything correctly
ok( $token->return_token0,          '... and it should return something');

do { $token = $p->get_token } until $token->is_start_tag( 'body' );
can_ok($token, 'return_attr');
my $attr = $token->return_attr;
is( ref $attr , 'HASH',           '... and it should return a hashref' );
is( $attr->{'bgcolor'}, '#ffffff','... correctly identifying the bgcolor' );
is( $attr->{'alink'}, '#0000ff',  '... and the alink color' );

can_ok($token, 'return_attrseq');
my $arrayref = $token->return_attrseq;
is( ref $arrayref, 'ARRAY',       '... and it should return an array reference' );
is( scalar @{$arrayref}, 2,       '... with the correct number of elements' );
is( "@$arrayref", 'alink bgcolor','... in the correct order' );

can_ok($token, 'set_attr');
eval{$non_start_tag->set_attr( foo => 'bar' )};
ok($@,                            '... and calling it on a "non start tag" should die');
like($@, qr/set_attr\(\) may only be called on start tags/,
                                  '... with an appropriate error message');

$token->set_attr(foo => 'bar');
is($token->as_is, '<body alink="#0000ff" bgcolor="#ffffff" foo="bar">',
                                  '... but a good token should set the new attribute');
$token->set_attr(bgcolor => 'white');
is($token->as_is, '<body alink="#0000ff" bgcolor="white" foo="bar">',
                                  '... or overwrite an existing one');

is_deeply($token->return_attrseq, [qw{alink bgcolor foo}],
                                  '... and the attribute sequence should be updated');
$attr = {
  alink   => "#0000ff",
  bgcolor => "white",
  foo     => "bar"
};
is_deeply($token->return_attr, $attr,
                                  '... as should the attributes themselves');

can_ok($token, 'delete_attr');
$token->delete_attr('asdf');
is($token->as_is, '<body alink="#0000ff" bgcolor="white" foo="bar">',
                                  '... and deleting a non-existent attribute should be a no-op');
$token->delete_attr('foo');
is($token->as_is, '<body alink="#0000ff" bgcolor="white">',
                                  '... and deleting an existing one should succeed'); 
$token->set_attr('foo', 'bar');
$token->delete_attr('FOO');
is($token->as_is, '<body alink="#0000ff" bgcolor="white">',
                                  '... and deleting should be case-insensitive'); 

do { $token = $p->get_token } until $token->is_start_tag('h1');
my $regex = qr/^h\d$/;
ok($token->is_tag($regex),        'Calling is_tag() with a regex should succeed');
ok(!$token->is_tag(qr/x/),        '... and not return false positives');
ok($token->is_start_tag($regex),  'Calling is_start_tag() with a regex should succeed');
ok(!$token->is_start_tag(qr/x/),  '... and not return false positives');

do { $token = $p->get_token } until $token->is_start_tag('hr');
$token->set_attr('class','fribble');
is($token->as_is, '<hr class="fribble" />',
                                  'Setting attributes on self-closing tags should succeed');
$token->delete_attr('class');
is($token->as_is, '<hr />',
                                  '... as should deleting them');

do { $token = $p->get_token } until $token->is_start_tag('hr');
$token->set_attr('class','fribble');
is($token->as_is, '<hr class="fribble"/>',
                                  'Setting attributes on self-closing tags should succeed');
$token->delete_attr('class');
is($token->as_is, '<hr/>',
                                  '... as should deleting them');


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
	<body alink="#0000ff" BGCOLOR="#ffffff">
		<h1>Do not edit this HTML lest the tests fail!!!</h1>
    <hr class="foo" />
    <hr class="bar"/>
	</body>
</html>

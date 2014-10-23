#!perl -T

use strict;
use Test::More;
eval "use Test::Pod::Coverage 0.08";
plan skip_all => "Test::Pod::Coverage required for testing POD coverage" if $@;

my %exception_for = (
    'HTML::TokeParser::Simple::Token'      => qr/new/,
    'HTML::TokeParser::Simple::Token::Tag' => qr/new/,
);

my @modules = Test::Pod::Coverage::all_modules();
plan tests => scalar @modules;

foreach my $module (@modules) {
    my $exception = $exception_for{$module};
    pod_coverage_ok( $module, $exception ? { trustme => [$exception] } : () );
}

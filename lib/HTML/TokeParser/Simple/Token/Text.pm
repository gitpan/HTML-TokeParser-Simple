package HTML::TokeParser::Simple::Token::Text;

use strict;

use vars qw/ $VERSION $REVISION /;
$REVISION = '$Id: Text.pm,v 1.1 2004/09/19 19:19:23 ovid Exp $';
$VERSION  = '1.0';
use base 'HTML::TokeParser::Simple::Token';

sub as_is {
    return shift->[1];
}

sub is_text { 1 }

1;

__END__

=head1 NAME

HTML::TokeParser::Simple::Token::Text - Text class for C<HTML::TokeParser::Simple::Text>

=head1 SYNOPSIS

 use HTML::TokeParser::Simple;
 my $p = HTML::TokeParser::Simple->new( $somefile );

 while ( my $token = $p->get_token ) {
     # This prints all text in an HTML doc (i.e., it strips the HTML)
     next unless $token->is_text;
     print $token->as_is;
 }

=head1 DESCRIPTION

This is an internal class that users should not worry about.  See the
C<HTML::TokeParser::Simple> documentation for details.

package HTML::TokeParser::Simple::Token::Declaration;

use strict;

use vars qw/ $VERSION $REVISION /;
$REVISION = '$Id: Declaration.pm,v 1.1 2004/09/19 21:12:24 ovid Exp $';
$VERSION  = '1.0';
use base 'HTML::TokeParser::Simple::Token';

sub is_declaration { 1 }

1;

__END__

=head1 NAME

HTML::TokeParser::Simple::Token::Declaration - Token.pm Declaration class.

=head1 SYNOPSIS

 use HTML::TokeParser::Simple;
 my $p = HTML::TokeParser::Simple->new( $somefile );

 while ( my $token = $p->get_token ) {
     # This prints all text in an HTML doc (i.e., it strips the HTML)
     next unless $token->is_text;
     print $token->as_is;
 }

=head1 DESCRIPTION

This is the declaration class for tokens.  C<is_declaration()> will return true
if the token is the DTD at the top of the HTML.

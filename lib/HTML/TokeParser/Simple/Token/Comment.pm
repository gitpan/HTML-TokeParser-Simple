package HTML::TokeParser::Simple::Token::Comment;

use strict;

use vars qw/ $VERSION $REVISION /;
$REVISION = '$Id: Comment.pm,v 1.3 2004/09/25 23:36:53 ovid Exp $';
$VERSION  = '1.0';
use base 'HTML::TokeParser::Simple::Token';

sub is_comment { 1 }

1;

__END__

=head1 NAME

HTML::TokeParser::Simple::Token::Comment - Token.pm comment class.

=head1 SYNOPSIS

 use HTML::TokeParser::Simple;
 my $p = HTML::TokeParser::Simple->new( $somefile );

 while ( my $token = $p->get_token ) {
     # This prints all text in an HTML doc (i.e., it strips the HTML)
     next unless $token->is_text;
     print $token->as_is;
 }

=head1 DESCRIPTION

This is the class for comment tokens.  The only behavioral change is that
C<is_comment()> returns true.

See L<HTML::Parser> for detailed information about comments.

package HTML::TokeParser::Simple::Token;

use strict;
use Carp;

use vars qw/ $VERSION $REVISION /;
$REVISION = '$Id: Token.pm,v 1.4 2004/09/19 21:11:51 ovid Exp $';
$VERSION  = '3.0';

sub new {
    my ($class, $token) = @_;
    croak("This class should not be instantiated") if __PACKAGE__ eq $class;
    return bless $token, $class;
}

sub is_tag         {}
sub is_start_tag   {}
sub is_end_tag     {}
sub is_text        {}
sub is_comment     {}
sub is_declaration {}
sub is_pi          {}
sub is_process_instruction {}

sub rewrite_tag    { shift }
sub delete_attr    {}
sub set_attr       {}
sub get_tag        {}
sub return_tag     {}  # deprecated
sub get_attr       {}
sub return_attr    {}  # deprecated
sub get_attrseq    {}
sub return_attrseq {}  # deprecated
sub get_token0     {}
sub return_token0  {}  # deprecated

# get_foo methods

sub return_text {
    carp('return_text() is deprecated.  Use as_is() instead');
    goto &as_is;
}

sub as_is { return shift->[-1] }

1;

__END__

=head1 NAME

HTML::TokeParser::Simple::Token - Base class for C<HTML::TokeParser::Simple> tokens.

=head1 SYNOPSIS

 use HTML::TokeParser::Simple;
 my $p = HTML::TokeParser::Simple->new( $somefile );

 while ( my $token = $p->get_token ) {
     # This prints all text in an HTML doc (i.e., it strips the HTML)
     next unless $token->is_text;
     print $token->as_is;
 }

=head1 DESCRIPTION

This is the base class for all returned tokens.  It should never be instantiated
directly.  In fact, it will C<croak()> if it is.

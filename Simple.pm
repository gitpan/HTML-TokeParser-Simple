package HTML::TokeParser::Simple;

use strict;
use Carp;
use HTML::TokeParser;
use vars qw/ @ISA $VERSION $AUTOLOAD /;
$VERSION = '2.1';
@ISA = qw/ HTML::TokeParser /;

use constant TOKEN_CLASS => 'HTML::TokeParser::Simple::Token';

# constructors

sub get_token {
    my $self = shift;
    my ( @args ) = @_;
    my $token = $self->SUPER::get_token( @args );
    return unless defined $token;
    bless $token, TOKEN_CLASS;
}

sub get_tag {
    my $self = shift;
    my ( @args ) = @_;
    my $token = $self->SUPER::get_tag( @args );
    return unless defined $token;
    bless $token, TOKEN_CLASS;
}

package HTML::TokeParser::Simple::Token;

use constant GET_TAG     => 1;
use constant GET_TOKEN   => 0;
use constant START_TAG   => 'S';
use constant END_TAG     => 'E';
use constant TEXT        => 'T';
use constant COMMENT     => 'C';
use constant DECLARATION => 'D';
use constant PROCESS_INSTRUCTION => 'PI';

my %token = (
    S => {
        _name   => 'START_TAG',
        tag     => 1,
        attr    => 2,
        attrseq => 3,
        text    => 4
    },
    E => {
        _name => 'END_TAG',
        tag   => 1,
        text  => 2
    },
    T => {
        _name => 'TEXT',
        text  => 1
    },
    C => {
        _name => 'COMMENT',
        text  => 1
    },
    D => {
        _name => 'DECLARATION',
        text  => 1
    },
    PI => {
        _name  => 'PROCESS_INSTRUCTION',
        token0 => 1,
        text   => 2
    }
);

# attribute munging methods

sub set_attr {
    my ($self, $name, $value) = @_;
    $name = lc $name;
    unless ($self->is_start_tag) {
        require Carp;
        Carp::croak('set_attr() may only be called on start tags');
    }
    my $attr        = $self->return_attr;
    my $attrseq = $self->return_attrseq;
    unless (exists $attr->{$name}) {
        push @$attrseq => $name;
    }
    $attr->{$name} = $value;
    $self->rewrite_tag;
}

sub rewrite_tag {
    my $self        = shift;
    return $self unless $self->is_tag;
    my $attr        = $self->return_attr;
    my $attrseq = $self->return_attrseq;

    my $type = $self->[0];
    # capture the final slash if the tag is self-closing
    my ($self_closing) = $self->[ $token{ $type }{ text } ] =~ m{(\s?/)>$};
    $self_closing ||= '';
    
    my $tag = '';
    foreach ( @$attrseq ) {
        next if $_ eq '/'; # is this a bug in HTML::TokeParser?
        $tag .= sprintf qq{ %s="%s"}, $_, $attr->{$_};
    }
    my $first = $self->is_end_tag ? '/' : '';
    $tag = sprintf '<%s%s%s%s>', $first, $self->return_tag, $tag, $self_closing;
    $self->[ $token{ $type }{ text } ] = $tag;
    $self;
}

sub delete_attr {
    my ($self,$name) = @_;
    $name = lc $name;
    unless ($self->is_start_tag) {
        require Carp;
        Carp::croak('set_attr() may only be called on start tags');
    }
    my $attr = $self->return_attr;
    return unless exists $attr->{$name};
    delete $attr->{$name};
    my $attrseq = $self->return_attrseq;
    @$attrseq = grep { $_ ne $name } @$attrseq;
    $self->rewrite_tag;
}

# return_foo methods

sub as_is {
    my ( $self, $method ) = _synch_arrays( shift );
    my $type = $self->[0];
    my $text = $self->[ $token{ $type }{ text } ];
    shift @$self if $method == GET_TAG;
    return $text;
}

sub return_text {
    require Carp;
    Carp::carp('return_text() is deprecated.  Use as_is() instead');
    goto &as_is;
}

sub return_tag {
    my $self = shift;
    if ( $self->_is( START_TAG ) or $self->_is( END_TAG ) ) {
        my $type = $self->[0];
        return $self->[ $token{ $type }{ tag } ];
    }
    return '';
}

sub return_token0 {
    my $self = shift;
    if ( $self->is_process_instruction ) {
        return $self->[ $token{ +PROCESS_INSTRUCTION }{ token0 } ];
    }
    return '';
}

sub return_attr {
    my $self = shift;
    $self->_attr_handler( 'attr', {} );
}

sub return_attrseq {
    my $self = shift;
    $self->_attr_handler( 'attrseq', [] );
}

# is_foo methods

sub is_declaration {
    my $self = shift;
    return $self->_is( DECLARATION );
}

sub is_text {
    my $self = shift;
    return $self->_is( TEXT );
}

sub is_process_instruction {
    my $self = shift;
    return $self->_is( PROCESS_INSTRUCTION );
}

sub is_comment {
    my $self = shift;
    return $self->_is( COMMENT );
}

sub is_tag {
    my $self = shift;
    return $self->is_start_tag( @_ ) || $self->is_end_tag( @_ );
}

sub is_start_tag {
    my ($self) = _synch_arrays( shift );
    return $self->_start_end_handler( START_TAG, @_ );
}

sub is_end_tag {
    my ($self) = _synch_arrays( shift );
    return $self->_start_end_handler( END_TAG, @_ );
}

# private methods

sub _start_end_handler {
    my ( $self, $requested_type, $tag ) = @_;
    $tag ||= '';
    my $result = $self->_is( $requested_type );
    return $result if ! $tag or ! $result;
    if ( 'Regexp' eq ref $tag ) {
        return $self->[$token{ $requested_type }{ tag }] =~ $tag;
    }
    else {
        $tag = lc $tag;
        # strip leading / if they supplied it
        $tag =~ s{^/}{};
        return $self->[$token{ $requested_type }{ tag }] =~ m{^/?$tag$};
    }
}

sub _is {
    my ( $self, $method ) = _synch_arrays( shift );
    my $type   = shift;
    my $result = $self->[0] eq $type;
    # if token was created with something like $p->get_tag, then we
    # unshifted the tag type on the array to synchronize indices with
    # return value of $p->get_token
    shift @$self if $method == GET_TAG;
    return $result;
}

sub _attr_handler {
    my ( $self, $method, $attr ) = _synch_arrays( shift );
    my $request = shift;
    if ( $self->_is( START_TAG ) ) {
        $attr = $self->[ $token{ +START_TAG }{ $request } ];
    }
    shift @$self if $method == GET_TAG;
    return $attr;
}

sub _synch_arrays {
    # if the method is called from a token generated by the get_tag() method,
    # the returned array reference will be identical to a start or end tag
    # token returned by get_token() *except* the first element in the reference
    # will not be an identifier like 'S' or 'E'
    
    my $array_ref = shift;
    my $tag_func  = GET_TOKEN;

    unless ( grep { $array_ref->[0] eq $_ } keys %token ) {
        # created with get_tag() method, so we need
        # to munge the array to match the get_token() array
        # After this is called, and before the method returns, you must
        # use something like the following:
        # shift @$self if $method == GET_TAG;
        $tag_func = GET_TAG;
        if ( '/' ne substr $array_ref->[0], 0, 1 ) {
            unshift @$array_ref, 'S';
        }
        else {
            unshift @$array_ref, 'E';
        }
    }
    return ( $array_ref, $tag_func );
}

1;

__END__

=head1 NAME

HTML::TokeParser::Simple - easy to use HTML::TokeParser interface

=head1 SYNOPSIS

 use HTML::TokeParser::Simple;
 my $p = HTML::TokeParser::Simple->new( $somefile );

 while ( my $token = $p->get_token ) {
     # This prints all text in an HTML doc (i.e., it strips the HTML)
     next unless $token->is_text;
     print $token->as_is;
 }


=head1 DESCRIPTION

C<HTML::TokeParser> is a fairly common method of parsing HTML.  However, the
tokens returned are not exactly intuitive to parse:

 ["S",  $tag, $attr, $attrseq, $text]
 ["E",  $tag, $text]
 ["T",  $text, $is_data]
 ["C",  $text]
 ["D",  $text]
 ["PI", $token0, $text]

To simplify this, C<HTML::TokeParser::Simple> allows the user ask more
intuitive (read: more self-documenting) questions about the tokens returned.
Specifically, there are 7 C<is_foo> type methods and 5 C<return_bar> type
methods.  The C<is_> methods allow you to determine the token type and the
C<return_> methods get the data that you need.

You can also rebuild some tags on the fly.  Frequently, the attributes
associated with start tags need to be altered, added to, or deleted.  This
functionality is built in.

Since this is a subclass of C<HTML::TokeParser>, all C<HTML::TokeParser>
methods are available.  To truly appreciate the power of this module, please
read the documentation for C<HTML::TokeParser> and C<HTML::Parser>.

The following will be brief descriptions of the available methods followed by
examples.

=head1 C<is_> Methods

=over 4

=item * C<is_start_tag([$tag])>

Use this to determine if you have a start tag.  An optional "tag type" may be
passed.  This will allow you to match if it's a I<particular> start tag.  The
supplied tag is case-insensitive.

 if ( $token->is_start_tag( 'font' ) ) { ... }

Optionally, you may pass a regular expression as an argument.  To match all
header (h1, h2, ... h6) tags:

 if ( $token->is_start_tag( qr/^h[123456]$/ ) ) { ... }

=item * C<is_end_tag([$tag])>

Use this to determine if you have an end tag.  An optional "tag type" may be
passed.  This will allow you to match if it's a I<particular> end tag.  The
supplied tag is case-insensitive.

When testing for an end tag, the forward slash on the tag is optional.

 while ( $token = $p->get_token ) {
   if ( $token->is_end_tag( 'form' ) ) { ... }
 }

Or:

 while ( $token = $p->get_token ) {
   if ( $token->is_end_tag( '/form' ) ) { ... }
 }

Optionally, you may pass a regular expression as an argument.

=item * C<is_tag([$tag])>

Use this to determine if you have any tag.  An optional "tag type" may be
passed.  This will allow you to match if it's a I<particular> tag.  The
supplied tag is case-insensitive.

 if ( $token->is_tag ) { ... }

Optionally, you may pass a regular expression as an argument.

=item * C<is_text()>

Use this to determine if you have text.  Note that this is I<not> to be
confused with the C<return_text> (I<deprecated>) method described below!
C<is_text> will identify text that the user typically sees display in the Web
browser.

=item * C<is_comment()>

Are you still reading this?  Nobody reads POD.  Don't you know you're supposed
to go to CLPM, ask a question that's answered in the POD and get flamed?  It's
a rite of passage.

Really.

C<is_comment> is used to identify comments.  See the HTML::Parser documentation
for more information about comments.  There's more than you might think.

=item * C<is_declaration()>

This will match the DTD at the top of your HTML. (You I<do> use DTD's, don't
you?)

=item * C<is_process_instruction()>

Process Instructions are from XML.  This is very handy if you need to parse out
PHP and similar things with a parser.

=back

=head1 The C<return_> methods

=head2 Note:

In case it's not blindingly obvious (I've been bitten by this myself when
writing the tests), you should generally test what type of token you have
B<before> you call some C<return_> methods.  For example, if you have an end
tag, there is no point in calling the C<return_attrseq> method.  Calling an
innapropriate method will return an empty string.

As noted for the C<is_> methods, these methods are case-insensitive after the
C<return_> part.

=over 4

=item * C<return_tag()>

Do you have a start tag or end tag?  This will return the type (lower case).

=item * C<return_attr()>

If you have a start tag, this will return a hash ref with the attribute names
as keys and the values as the values.

=item * C<return_attrseq()>

For a start tag, this is an array reference with the sequence of the
attributes, if any.

=item * C<return_text()>

This method has been deprecated in favor of C<as_is>.  Programmers were getting
confused over the difference between C<is_text>, C<return_text>, and some
parser methods such as C<HTML::TokeParser::get_text> and friends.  This
confusion stems from the fact that your author is a blithering idiot when it
comes to choosing methods names :)

Using this method still succeeds, but will now carp.

=item * C<as_is()>

This is the exact text of whatever the token is representing.

=item * C<return_token0()>

For processing instructions, this will return the token found immediately after
the opening tag.  Example:  For <?php, "php" will be the start of the returned
string.

=back

=head1 Tag munging methods

The C<delete_attr()> and C<set_attr()> methods allow the programmer to rewrite
tag attributes on the fly.  It should be noted that bad HTML will be
"corrected" by this.  Specifically, the new tag will have all attributes
lower-cased with the values properly quoted.

Self-closing tags (e.g. E<lt>hr /E<gt>) are also handled correctly.  Some older
browsers require a space prior to the final slash in a self-closed tag.  If
such a space is detected in the original HTML, it will be preserved.

=over 4

=item * C<delete_attr($name)>

This method attempts to delete the attribute specified.  It will C<croak> if
called on anything other than a start tag.  The argument is case-insensitive,
but must otherwise be an exact match of the attribute you are attempting to
delete.  If the attribute is not found, the method will return without changing
the tag.

 # <body bgcolor="#FFFFFF">
 $token->delete_attr('bgcolor');
 print $token->as_is;
 # <body>
 
After this method is called, if successful, the C<as_is()>, C<return_attr()>
and C<return_attrseq()> methods will all return updated results.
 
=item * C<set_attr($name,$value)>

This method will set the value of an attribute.  If the attribute is not found,
then C<return_attrseq()> will have the new attribute listed at the end.  Two
arguments

 # <p>
 $token->set_attr('class','some_class');
 print $token->as_is;
 # <p class="some_class">

 # <body bgcolor="#FFFFFF">
 $token->set_attr('bgcolor','red');
 print $token->as_is;
 # <body bgcolor="red">

After this method is called, if successful, the C<as_is()>, C<return_attr()>
and C<return_attrseq()> methods will all return updated results.

=item * C<rewrite_tag()>

This method rewrites the tag.  The tag name and the name of all attributes will
be lower-cased.  Values that are not quoted with double quotes will be.  This
may be called on both start or end tags.  Note that both C<set_attr()> and
C<delete_attr()> call this method prior to returning.

If called on a token that is not a tag, it simply returns.  Regardless of how
it is called, it returns the token.

 # <body alink=#0000ff BGCOLOR=#ffffff class='none'>
 $token->rewrite_tag;
 print $token->as_is;
 # <body alink="#0000ff" bgcolor="#ffffff" class="none">

A quick cleanup of sloppy HTML is now the following:

 my $parser = HTML::TokeParser::Simple->new( $ugly_html );
 while (my $token = $parser->get_token) {
     $token->rewrite_tag;
     print $token->as_is;
 }

=head1 Important note:

Some people get confused and try to call parser methods on tokens and token
methods (those described above) on methods.  To prevent this,
C<HTML::TokeParser::Simple> versions 1.4 and above now bless all tokens into a
new class which inherits nothing.  Please keep this in mind while using this
module (and many thanks to PodMaster
L<http://www.perlmonks.org/index.pl?node_id=107642> for pointing out this issue
to me.

=head1 Examples

=head2 Finding comments

For some strange reason, your Pointy-Haired Boss (PHB) is convinced that the
graphics department is making fun of him by embedding rude things about him in
HTML comments.  You need to get all HTML comments from the HTML.

 use strict;
 use HTML::TokeParser::Simple;

 my @html_docs = glob( "*.html" );

 open PHB, "> phbreport.txt" or die "Cannot open phbreport for writing: $!";

 foreach my $doc ( @html_docs ) {
     print "Processing $doc\n";
     my $p = HTML::TokeParser::Simple->new( $doc );
     while ( my $token = $p->get_token ) {
         next unless $token->is_comment;
         print PHB $token->as_is, "\n";
     }
 }

 close PHB;

=head2 Stripping Comments

Uh oh.  Turns out that your PHB was right for a change.  Many of the comments
in the HTML weren't very polite.  Since your entire graphics department was
just fired, it falls on you need to strip those comments from the HTML.

 use strict;
 use HTML::TokeParser::Simple;

 my $new_folder = 'no_comment/';
 my @html_docs  = glob( "*.html" );

 foreach my $doc ( @html_docs ) {
     print "Processing $doc\n";
     my $new_file = "$new_folder$doc";

     open PHB, "> $new_file" or die "Cannot open $new_file for writing: $!";

     my $p = HTML::TokeParser::Simple->new( $doc );
     while ( my $token = $p->get_token ) {
         next if $token->is_comment;
         print PHB $token->as_is;
     }
     close PHB;
 }

=head2 Changing form tags

Your company was foo.com and now is bar.com.  Unfortunately, whoever wrote your
HTML decided to hardcode "http://www.foo.com/" into the C<action> attribute of
the form tags.  You need to change it to "http://www.bar.com/".

 use strict;
 use HTML::TokeParser::Simple;

 my $new_folder = 'new_html/';
 my @html_docs  = glob( "*.html" );

 foreach my $doc ( @html_docs ) {
     print "Processing $doc\n";
     my $new_file = "$new_folder$doc";

     open FILE, "> $new_file" or die "Cannot open $new_file for writing: $!";

     my $p = HTML::TokeParser::Simple->new( $doc );
     while ( my $token = $p->get_token ) {
         if ( $token->is_start_tag('form') ) {
             my $action = $token->return_attr->{action};
             $action =~ s/www\.foo\.com/www.bar.com/;
             $token->set_attr('action', $action);
         }
         print FILE $token->as_is;
     }
     close FILE;
 }

=head1 COPYRIGHT

Copyright (c) 2001 Curtis "Ovid" Poe.  All rights reserved.  This program is
free software; you may redistribute it and/or modify it under the same terms as
Perl itself

=head1 AUTHOR

Curtis "Ovid" Poe L<poec@yahoo.com>

=head1 BUGS

Use of C<$HTML::Parser::VERSION> which is less than 3.25 may result in
incorrect behavior as older versions do not always handle XHTML correctly.  It
is the programmer's responsibility to verify that the behavior of this code
matches the programmer's needs.

Note that C<HTML::Parser> processes text in 512 byte chunks.  This sometimes
will cause strange behavior and cause text to be broken into more than one
token.  You can suppress this behavior with the following command:

 $p->unbroken_text( [$bool] );

See the C<HTML::Parser> documentation and
http://www.perlmonks.org/index.pl?node_id=230667 for more information.

Address bug reports and comments to: L<poec@yahoo.com>.  When sending bug
reports, please provide the version of C<HTML::Parser>, C<HTML::TokeParser>,
C<HTML::TokeParser::Simple>, the version of Perl, and the version of the
operating system you are using.

=cut

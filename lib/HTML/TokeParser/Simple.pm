package HTML::TokeParser::Simple;

use strict;
use Carp;
use HTML::TokeParser;
use HTML::TokeParser::Simple::Token;

use vars qw/ @ISA $VERSION $REVISION /;

$REVISION = '$Id: Simple.pm,v 1.4 2004/09/18 18:35:54 ovid Exp $';
$VERSION  = '3.0';
@ISA = qw/ HTML::TokeParser /;

use constant TOKEN_CLASS => 'HTML::TokeParser::Simple::Token';

# constructors

sub new {
    my ($class, @args) = @_;
    return 1 == @args
        ? $class->SUPER::new(@args)
        : $class->_init(@args);
}

sub _init {
    my ($class, $source_type, $source) = @_;
    my %sources = (
        file   => sub { $source },
        handle => sub { $source },
        string => sub { \$source },
        url    => sub {
            eval "require LWP::Simple";
            croak("Cannot load LWP::Simple: $@") if $@;
            my $content = LWP::Simple::get($source);
            croak"Could not fetch content from ($source)" unless defined $content;
            return \$content;
        },
    );
    unless (exists $sources{$source_type}) {
        croak("Unknown source type ($source_type)");
    }
    return $class->new($sources{$source_type}->());
}

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

C<HTML::TokeParser> is an excellent module that's often used for parsing HTML.
However, the tokens returned are not exactly intuitive to parse:

 ["S",  $tag, $attr, $attrseq, $text]
 ["E",  $tag, $text]
 ["T",  $text, $is_data]
 ["C",  $text]
 ["D",  $text]
 ["PI", $token0, $text]

To simplify this, C<HTML::TokeParser::Simple> allows the user ask more
intuitive (read: more self-documenting) questions about the tokens returned.

You can also rebuild some tags on the fly.  Frequently, the attributes
associated with start tags need to be altered, added to, or deleted.  This
functionality is built in.

Since this is a subclass of C<HTML::TokeParser>, all C<HTML::TokeParser>
methods are available.  To truly appreciate the power of this module, please
read the documentation for C<HTML::TokeParser> and C<HTML::Parser>.

=head1 C<new($source)>

The constructor for C<HTML::TokeParser::Simple> can be used just like
C<HTML::TokeParser>'s constructor:

  my $parser = HTML::TokeParser::Simple->new($filename);
  # or
  my $parser = HTML::TokeParser::Simple->new($filehandle);
  # or
  my $parser = HTML::TokeParser::Simple->new(\$html_string);

=head1 C<new($source_type, $source)>

If you wish to be more explicit, there is a new style of
constructor avaiable.

  my $parser = HTML::TokeParser::Simple->new(file   => $filename);
  # or
  my $parser = HTML::TokeParser::Simple->new(handle => $filehandle);
  # or
  my $parser = HTML::TokeParser::Simple->new(string => $html_string);

Note that you do not have to provide a reference for the string if using the
string constructor.

As a convenience, you can also attempt to fetch the HTML directly from a URL.

  my $parser = HTML::TokeParser::Simple->new(url => 'http://some.url');

This method relies on C<LWP::Simple>.  If this module is not found or the page
cannot be fetched, the constructor will C<croak()>.

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

=item * C<is_pi()>

This is a shorthand for C<is_process_instruction()>.

=back

=head1 The C<get_> methods

=head2 Note:

These were originally C<return_> methods, but that name was not only unwieldy,
but also went against reasonable conventions.  The C<get_> methods listed
below still have C<return_> methods available for backwards compatibility
reasons, but they merely call their C<get_> counterpart.  For example, calling
C<return_tag()> actually calls C<get_tag()> internally.

=over 4

=item * C<get_tag()>

Do you have a start tag or end tag?  This will return the type (lower case).

=item * C<get_attr([$attribute])>

If you have a start tag, this will return a hash ref with the attribute names
as keys and the values as the values.

If you pass in an attribute name, it will return the value for just that
attribute.  Returns C<undef> if the attribute is not found.

=item * C<get_attrseq()>

For a start tag, this is an array reference with the sequence of the
attributes, if any.

=item * C<return_text()>

This method has been heavily deprecated (for a couple of years) in favor of
C<as_is>.  Programmers were getting confused over the difference between
C<is_text>, C<return_text>, and some parser methods such as
C<HTML::TokeParser::get_text> and friends.

Using this method still succeeds, but will now carp and will likely be removed
in the next major release of this module.

=item * C<as_is()>

This is the exact text of whatever the token is representing.

=item * C<get_token0()>

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
 
After this method is called, if successful, the C<as_is()>, C<get_attr()>
and C<get_attrseq()> methods will all return updated results.
 
=item * C<set_attr($name,$value)>

This method will set the value of an attribute.  If the attribute is not found,
then C<get_attrseq()> will have the new attribute listed at the end.  Two
arguments

 # <p>
 $token->set_attr('class','some_class');
 print $token->as_is;
 # <p class="some_class">

 # <body bgcolor="#FFFFFF">
 $token->set_attr('bgcolor','red');
 print $token->as_is;
 # <body bgcolor="red">

After this method is called, if successful, the C<as_is()>, C<get_attr()>
and C<get_attrseq()> methods will all return updated results.

=item * C<set_attr($hashref)>

Under the premise that C<set_> methods should accept what their corresponding
C<get_> methods emit, the following works:

  $tag->set_attr($tag->get_attr);

Theoretically that's a no-op and for purposes of rendering HTML, it shoudld be.
However, internally this calls C<$tag-E<gt>rewrite_tag>, so see that method to
understand how this may affect you.

Of course, this is useless if you want to actually change the attributes, so you
can do this:

  my $attrs = {
    class  => 'headline',
    valign => 'top'
  };
  $token->set_attr($attrs) 
    if $token->is_start_tag('td') 
        &&  
       $token->get_attr('class') eq 'stories';

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

 my $parser = HTML::TokeParser::Simple->new( string => $ugly_html );
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
     my $p = HTML::TokeParser::Simple->new( file => $doc );
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

     my $p = HTML::TokeParser::Simple->new( $file => doc );
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

     my $p = HTML::TokeParser::Simple->new( file => $doc );
     while ( my $token = $p->get_token ) {
         if ( $token->is_start_tag('form') ) {
             my $action = $token->get_attr(action);
             $action =~ s/www\.foo\.com/www.bar.com/;
             $token->set_attr('action', $action);
         }
         print FILE $token->as_is;
     }
     close FILE;
 }

=head1 COPYRIGHT

Copyright (c) 2004 by Curtis "Ovid" Poe.  All rights reserved.  This program is
free software; you may redistribute it and/or modify it under the same terms as
Perl itself

=head1 AUTHOR

Curtis "Ovid" Poe L<eop_divo_sitruc@yahoo.com>

Reverse the name to email the author.

=head1 BUGS

For compatability reasons with C<HTML::TokeParser>, methods that return
references are violating encapsulation and altering the references directly
B<will> alter the state of the object.  Subsequent calls to C<rewrite_tag()>
can thus have unexpected results.  Do not alter these references directly
unless you are following behavior described in these docs.  In the future,
certain methods such as C<get_attr>, C<get_attrseq> and others will likely
return a copy of the reference rather than the original reference.  This
behavior has not yet been changed in order to maintain compatability with
previous versions of this module.  At the present time, your author is not
aware of anyone taking advantage of this "feature," but it's better to be safe
than sorry.

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

Address bug reports and comments to: L<eop_divo_sitruc@yahoo.com>.  When sending bug
reports, please provide the version of C<HTML::Parser>, C<HTML::TokeParser>,
C<HTML::TokeParser::Simple>, the version of Perl, and the version of the
operating system you are using.

Reverse the name to email the author.

=cut

package HTML::TokeParser::Simple::Token::Tag;

use strict;
use Carp;

use vars qw/ $VERSION $REVISION /;
$REVISION = '$Id: Tag.pm,v 1.3 2004/09/19 21:13:48 ovid Exp $';
$VERSION  = '1.1';
use base 'HTML::TokeParser::Simple::Token';

use constant START_TAG   => 'S';
use constant END_TAG     => 'E';

my %TOKEN = (
    S => {
        tag     => 1,
        attr    => 2,
        attrseq => 3,
        text    => 4
    },
    E => {
        tag   => 1,
        text  => 2
    },
);

# in order to maintain the 'drop-in replacement' ability with HTML::TokeParser,
# we cannot alter the array refs.  Thus we must store instance data here.  Ugh.

my %INSTANCE;

sub new {
    my ($class, $object) = @_;
    my $self = bless $object, $class;
    $self->_init;
}

sub _init {
    my $self = shift;
    if (START_TAG eq $self->[0] or END_TAG eq $self->[0]) {
        $INSTANCE{$self}{offset} = 0;
        $INSTANCE{$self}{type}   = $self->[0];
        $INSTANCE{$self}{tag}    = $self->[1];
    }
    else {
        $INSTANCE{$self}{offset} = -1;
        $INSTANCE{$self}{type}   = $self->[0] =~ /\//
            ? END_TAG
            : START_TAG;
        my $tag = $self->[0];
        $tag =~ s/^\///;
        $INSTANCE{$self}{tag}    = $tag;
    }
    return $self;
}

sub _get_offset { return $INSTANCE{+shift}{offset} }
sub _get_type   { return $INSTANCE{+shift}{type}   }
sub _get_text   { return shift->[-1] }

sub _get_tag {
    my $self  = shift;
    return $INSTANCE{$self}{tag};
}

sub _get_attrseq {
    my $self  = shift;
    return [] if END_TAG eq $INSTANCE{$self}{type};
    my $index = $TOKEN{+START_TAG}{attrseq} + $self->_get_offset;
    return $self->[$index];
}

sub _get_attr {
    my $self  = shift;
    return [] if END_TAG eq $INSTANCE{$self}{type};
    my $index = $TOKEN{+START_TAG}{attr} + $self->_get_offset;
    return $self->[$index];
}

sub _set_text   { 
    my $self = shift; 
    $self->[-1] = shift;
    return $self;
}

sub DESTROY     { delete $INSTANCE{+shift} }

sub return_attr    { goto &get_attr }
sub return_attrseq { goto &get_attrseq }
sub return_tag     { goto &get_tag }

# attribute munging methods

sub set_attr {
    my ($self, $name, $value) = @_;
    return 'HASH' eq ref $name
        ? $self->_set_attr_from_hashref($name)
        : $self->_set_attr_from_string($name, $value);
}

sub _set_attr_from_string {
    my ($self, $name, $value) = @_;
    $name = lc $name;
    unless ($self->is_start_tag) {
        require Carp;
        Carp::croak('set_attr() may only be called on start tags');
    }
    my $attr    = $self->get_attr;
    my $attrseq = $self->get_attrseq;
    unless (exists $attr->{$name}) {
        push @$attrseq => $name;
    }
    $attr->{$name} = $value;
    $self->rewrite_tag;
}

sub _set_attr_from_hashref {
    my ($self, $attr_hash) = @_;
    while (my ($attr, $value) = each %$attr_hash) {
        $self->set_attr($attr, $value);
    }
    return $self;
}

sub rewrite_tag {
    my $self    = shift;
    my $attr    = $self->get_attr;
    my $attrseq = $self->get_attrseq;

    # capture the final slash if the tag is self-closing
    my ($self_closing) = $self->_get_text =~ m{(\s?/)>$};
    $self_closing ||= '';
    
    my $tag = '';
    foreach ( @$attrseq ) {
        next if $_ eq '/'; # is this a bug in HTML::TokeParser?
        $tag .= sprintf qq{ %s="%s"} => $_, $attr->{$_};
    }
    my $first = $self->is_end_tag ? '/' : '';
    $tag = sprintf '<%s%s%s%s>', $first, $self->get_tag, $tag, $self_closing;
    $self->_set_text($tag);
    return $self;
}

sub delete_attr {
    my ($self,$name) = @_;
    $name = lc $name;
    unless ($self->is_start_tag) {
        require Carp;
        Carp::croak('set_attr() may only be called on start tags');
    }
    my $attr = $self->get_attr;
    return unless exists $attr->{$name};
    delete $attr->{$name};
    my $attrseq = $self->get_attrseq;
    @$attrseq = grep { $_ ne $name } @$attrseq;
    $self->rewrite_tag;
}

# get_foo methods

sub return_text {
    require Carp;
    Carp::carp('return_text() is deprecated.  Use as_is() instead');
    goto &as_is;
}

sub as_is {
    return shift->_get_text;
}

sub get_tag {
    return shift->_get_tag;
}

sub get_token0 {
    return '';
}

sub get_attr {
    my $self = shift;
    my $attributes = $self->_get_attr;
    return @_ ? $attributes->{lc shift} : $attributes;
}

sub get_attrseq {
    my $self = shift;
    $self->_get_attrseq;
}

# is_foo methods

sub is_tag {
    my $self = shift;
    return $self->is_start_tag( @_ ) || $self->is_end_tag( @_ );
}

sub is_start_tag {
    my $self = shift;
    return unless START_TAG eq $self->_get_type;
    my $tag = shift;
    return $tag
        ? $self->_match_tag($tag)
        : 1;
}

sub is_end_tag {
    my $self = shift;
    return unless END_TAG eq $self->_get_type;
    my $tag = shift;
    return $tag
        ? $self->_match_tag($tag)
        : 1;
}

sub _match_tag {
    my ($self, $tag) = @_;
    if ('Regexp' eq ref $tag) {
        return $self->_get_tag =~ $tag;
    }
    else {
        $tag = lc $tag;
        $tag =~ s/^\///;
        return $self->_get_tag eq $tag;
    }
}

1;

__END__

=head1 NAME

HTML::TokeParser::Simple::Token::Tag - Token.pm tag class.

=head1 SYNOPSIS

 use HTML::TokeParser::Simple;
 my $p = HTML::TokeParser::Simple->new( $somefile );

 while ( my $token = $p->get_token ) {
     # This prints all text in an HTML doc (i.e., it strips the HTML)
     next unless $token->is_text;
     print $token->as_is;
 }

=head1 DESCRIPTION

This class does most of the heavy lifting for C<HTML::TokeParser::Simple>.  See
the C<HTML::TokeParser::Simple> docs for details.

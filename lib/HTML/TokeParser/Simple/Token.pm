package HTML::TokeParser::Simple::Token;

use strict;
use Carp;

use vars qw/ $VERSION $REVISION /;
$REVISION = '$Id: Token.pm,v 1.2 2004/09/18 18:38:42 ovid Exp $';
$VERSION  = '2.0';

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

# the return_foo methods are deprecated, but for backwards compatability,
# we won't be issuing warnings.
foreach my $method_type (qw/tag token0 attr attrseq/) {
    no strict 'refs';
    my ($old_method, $new_method) = (
        "return_$method_type",
        "get_$method_type"
    );
    *$old_method = sub {
        goto &$new_method;
    };
}

# attribute munging methods

sub set_attr {
    my ($self, $name, $value) = @_;
    if ('HASH' eq ref $name) {
        return $self->_set_attr_from_hashref($name);
    }
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
    my $self        = shift;
    return $self unless $self->is_tag;
    my $attr        = $self->get_attr;
    my $attrseq = $self->get_attrseq;

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
    $tag = sprintf '<%s%s%s%s>', $first, $self->get_tag, $tag, $self_closing;
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
    my ( $self, $method ) = _synch_arrays( shift );
    my $type = $self->[0];
    my $text = $self->[ $token{ $type }{ text } ];
    shift @$self if $method == GET_TAG;
    return $text;
}

sub get_tag {
    my $self = shift;
    if ( $self->_is( START_TAG ) or $self->_is( END_TAG ) ) {
        my $type = $self->[0];
        return $self->[ $token{ $type }{ tag } ];
    }
    return '';
}

sub get_token0 {
    my $self = shift;
    if ( $self->is_process_instruction ) {
        return $self->[ $token{ +PROCESS_INSTRUCTION }{ token0 } ];
    }
    return '';
}

sub get_attr {
    my $self = shift;
    my $attributes = $self->_attr_handler( 'attr', {} );
    return @_ ? $attributes->{lc shift} : $attributes;
}

sub get_attrseq {
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

sub is_pi { goto &is_process_instruction }

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

HTML::TokeParser::Simple::Token - Token class for C<HTML::TokeParser::Simple>

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

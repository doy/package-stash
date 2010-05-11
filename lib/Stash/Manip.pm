package Stash::Manip;
use strict;
use warnings;

use Carp qw(confess);
use Scalar::Util qw(reftype);

=head1 NAME

Stash::Manip -

=head1 SYNOPSIS


=head1 DESCRIPTION


=cut

sub new {
    my $class = shift;
    my ($namespace) = @_;
    return bless { package => $namespace }, $class;
}

sub name {
    return $_[0]->{package};
}

sub namespace {
    # NOTE:
    # because of issues with the Perl API 
    # to the typeglob in some versions, we 
    # need to just always grab a new 
    # reference to the hash here. Ideally 
    # we could just store a ref and it would
    # Just Work, but oh well :\    
    no strict 'refs';
    return \%{$_[0]->name . '::'};
}

{
    my %SIGIL_MAP = (
        '$' => 'SCALAR',
        '@' => 'ARRAY',
        '%' => 'HASH',
        '&' => 'CODE',
    );

    sub _deconstruct_variable_name {
        my ($self, $variable) = @_;

        (defined $variable)
            || confess "You must pass a variable name";

        my $sigil = substr($variable, 0, 1, '');

        (defined $sigil)
            || confess "The variable name must include a sigil";

        (exists $SIGIL_MAP{$sigil})
            || confess "I do not recognize that sigil '$sigil'";

        return ($variable, $sigil, $SIGIL_MAP{$sigil});
    }
}

sub add_package_symbol {
    my ($self, $variable, $initial_value) = @_;

    my ($name, $sigil, $type) = ref $variable eq 'HASH'
        ? @{$variable}{qw[name sigil type]}
        : $self->_deconstruct_variable_name($variable);

    my $pkg = $self->name;

    no strict 'refs';
    no warnings 'redefine', 'misc', 'prototype';
    *{$pkg . '::' . $name} = ref $initial_value ? $initial_value : \$initial_value;
}

sub remove_package_glob {
    my ($self, $name) = @_;
    no strict 'refs';
    delete ${$self->name . '::'}{$name};
}

# ... these functions deal with stuff on the namespace level

sub has_package_symbol {
    my ($self, $variable) = @_;

    my ($name, $sigil, $type) = ref $variable eq 'HASH'
        ? @{$variable}{qw[name sigil type]}
        : $self->_deconstruct_variable_name($variable);

    my $namespace = $self->namespace;

    return unless exists $namespace->{$name};

    my $entry_ref = \$namespace->{$name};
    if (reftype($entry_ref) eq 'GLOB') {
        if ( $type eq 'SCALAR' ) {
            return defined ${ *{$entry_ref}{SCALAR} };
        }
        else {
            return defined *{$entry_ref}{$type};
        }
    }
    else {
        # a symbol table entry can be -1 (stub), string (stub with prototype),
        # or reference (constant)
        return $type eq 'CODE';
    }
}

sub get_package_symbol {
    my ($self, $variable) = @_;

    my ($name, $sigil, $type) = ref $variable eq 'HASH'
        ? @{$variable}{qw[name sigil type]}
        : $self->_deconstruct_variable_name($variable);

    my $namespace = $self->namespace;

    # FIXME
    $self->add_package_symbol($variable)
        unless exists $namespace->{$name};

    my $entry_ref = \$namespace->{$name};

    if (ref($entry_ref) eq 'GLOB') {
        return *{$entry_ref}{$type};
    }
    else {
        if ($type eq 'CODE') {
            no strict 'refs';
            return \&{ $self->name . '::' . $name };
        }
        else {
            return undef;
        }
    }
}

sub remove_package_symbol {
    my ($self, $variable) = @_;

    my ($name, $sigil, $type) = ref $variable eq 'HASH'
        ? @{$variable}{qw[name sigil type]}
        : $self->_deconstruct_variable_name($variable);

    # FIXME:
    # no doubt this is grossly inefficient and 
    # could be done much easier and faster in XS

    my ($scalar_desc, $array_desc, $hash_desc, $code_desc) = (
        { sigil => '$', type => 'SCALAR', name => $name },
        { sigil => '@', type => 'ARRAY',  name => $name },
        { sigil => '%', type => 'HASH',   name => $name },
        { sigil => '&', type => 'CODE',   name => $name },
    );

    my ($scalar, $array, $hash, $code);
    if ($type eq 'SCALAR') {
        $array  = $self->get_package_symbol($array_desc)  if $self->has_package_symbol($array_desc);
        $hash   = $self->get_package_symbol($hash_desc)   if $self->has_package_symbol($hash_desc);
        $code   = $self->get_package_symbol($code_desc)   if $self->has_package_symbol($code_desc);
    }
    elsif ($type eq 'ARRAY') {
        $scalar = $self->get_package_symbol($scalar_desc) if $self->has_package_symbol($scalar_desc);
        $hash   = $self->get_package_symbol($hash_desc)   if $self->has_package_symbol($hash_desc);
        $code   = $self->get_package_symbol($code_desc)   if $self->has_package_symbol($code_desc);
    }
    elsif ($type eq 'HASH') {
        $scalar = $self->get_package_symbol($scalar_desc) if $self->has_package_symbol($scalar_desc);
        $array  = $self->get_package_symbol($array_desc)  if $self->has_package_symbol($array_desc);
        $code   = $self->get_package_symbol($code_desc)   if $self->has_package_symbol($code_desc);
    }
    elsif ($type eq 'CODE') {
        $scalar = $self->get_package_symbol($scalar_desc) if $self->has_package_symbol($scalar_desc);
        $array  = $self->get_package_symbol($array_desc)  if $self->has_package_symbol($array_desc);
        $hash   = $self->get_package_symbol($hash_desc)   if $self->has_package_symbol($hash_desc);
    }
    else {
        confess "This should never ever ever happen";
    }

    $self->remove_package_glob($name);

    $self->add_package_symbol($scalar_desc => $scalar) if defined $scalar;
    $self->add_package_symbol($array_desc  => $array)  if defined $array;
    $self->add_package_symbol($hash_desc   => $hash)   if defined $hash;
    $self->add_package_symbol($code_desc   => $code)   if defined $code;
}

sub list_all_package_symbols {
    my ($self, $type_filter) = @_;

    my $namespace = $self->namespace;
    return keys %{$namespace} unless defined $type_filter;

    # NOTE:
    # or we can filter based on 
    # type (SCALAR|ARRAY|HASH|CODE)
    if ($type_filter eq 'CODE') {
        return grep {
            (ref($namespace->{$_})
                ? (ref($namespace->{$_}) eq 'SCALAR')
                : (ref(\$namespace->{$_}) eq 'GLOB'
                   && defined(*{$namespace->{$_}}{CODE})));
        } keys %{$namespace};
    } else {
        return grep { *{$namespace->{$_}}{$type_filter} } keys %{$namespace};
    }
}

=head1 BUGS

No known bugs.

Please report any bugs through RT: email
C<bug-stash-manip at rt.cpan.org>, or browse to
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Stash-Manip>.

=head1 SEE ALSO


=head1 SUPPORT

You can find this documentation for this module with the perldoc command.

    perldoc Stash::Manip

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Stash-Manip>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Stash-Manip>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Stash-Manip>

=item * Search CPAN

L<http://search.cpan.org/dist/Stash-Manip>

=back

=head1 AUTHOR

  Jesse Luehrs <doy at tozt dot net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Jesse Luehrs.

This is free software; you can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;

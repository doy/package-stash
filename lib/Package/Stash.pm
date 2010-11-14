package Package::Stash;
use strict;
use warnings;
# ABSTRACT: routines for manipulating stashes

use XSLoader;
XSLoader::load(
    __PACKAGE__,
    # we need to be careful not to touch $VERSION at compile time, otherwise
    # DynaLoader will assume it's set and check against it, which will cause
    # fail when being run in the checkout without dzil having set the actual
    # $VERSION
    exists $Package::Stash::{VERSION}
        ? ${ $Package::Stash::{VERSION} } : (),
);

use Package::DeprecationManager -deprecations => {
    'Package::Stash::add_package_symbol'        => 0.14,
    'Package::Stash::remove_package_glob'       => 0.14,
    'Package::Stash::has_package_symbol'        => 0.14,
    'Package::Stash::get_package_symbol'        => 0.14,
    'Package::Stash::get_or_add_package_symbol' => 0.14,
    'Package::Stash::remove_package_symbol'     => 0.14,
    'Package::Stash::list_all_package_symbols'  => 0.14,
};

sub add_package_symbol {
    deprecated('add_package_symbol is deprecated, please use add_symbol');
    shift->add_symbol(@_);
}

sub remove_package_glob {
    deprecated('remove_package_glob is deprecated, please use remove_glob');
    shift->remove_glob(@_);
}

sub has_package_symbol {
    deprecated('has_package_symbol is deprecated, please use has_symbol');
    shift->has_symbol(@_);
}

sub get_package_symbol {
    deprecated('get_package_symbol is deprecated, please use get_symbol');
    shift->get_symbol(@_);
}

sub get_or_add_package_symbol {
    deprecated('get_or_add_package_symbol is deprecated, please use get_or_add_symbol');
    shift->get_or_add_symbol(@_);
}

sub remove_package_symbol {
    deprecated('remove_package_symbol is deprecated, please use remove_symbol');
    shift->remove_symbol(@_);
}

sub list_all_package_symbols {
    deprecated('list_all_package_symbols is deprecated, please use list_all_symbols');
    shift->list_all_symbols(@_);
}

=head1 SYNOPSIS

  my $stash = Package::Stash->new('Foo');
  $stash->add_symbol('%foo', {bar => 1});
  # $Foo::foo{bar} == 1
  $stash->has_symbol('$foo') # false
  my $namespace = $stash->namespace;
  *{ $namespace->{foo} }{HASH} # {bar => 1}

=head1 DESCRIPTION

Manipulating stashes (Perl's symbol tables) is occasionally necessary, but
incredibly messy, and easy to get wrong. This module hides all of that behind a
simple API.

NOTE: Most methods in this class require a variable specification that includes
a sigil. If this sigil is absent, it is assumed to represent the IO slot.

=method new $package_name

Creates a new C<Package::Stash> object, for the package given as the only
argument.

=method name

Returns the name of the package that this object represents.

=method namespace

Returns the raw stash itself.

=method add_symbol $variable $value %opts

Adds a new package symbol, for the symbol given as C<$variable>, and optionally
gives it an initial value of C<$value>. C<$variable> should be the name of
variable including the sigil, so

  Package::Stash->new('Foo')->add_symbol('%foo')

will create C<%Foo::foo>.

Valid options (all optional) are C<filename>, C<first_line_num>, and
C<last_line_num>.

C<$opts{filename}>, C<$opts{first_line_num}>, and C<$opts{last_line_num}> can
be used to indicate where the symbol should be regarded as having been defined.
Currently these values are only used if the symbol is a subroutine ('C<&>'
sigil) and only if C<$^P & 0x10> is true, in which case the special C<%DB::sub>
hash is updated to record the values of C<filename>, C<first_line_num>, and
C<last_line_num> for the subroutine. If these are not passed, their values are
inferred (as much as possible) from C<caller> information.

This is especially useful for debuggers and profilers, which use C<%DB::sub> to
determine where the source code for a subroutine can be found.  See
L<http://perldoc.perl.org/perldebguts.html#Debugger-Internals> for more
information about C<%DB::sub>.

=method remove_glob $name

Removes all package variables with the given name, regardless of sigil.

=method has_symbol $variable

Returns whether or not the given package variable (including sigil) exists.

=method get_symbol $variable

Returns the value of the given package variable (including sigil).

=method get_or_add_symbol $variable

Like C<get_symbol>, except that it will return an empty hashref or
arrayref if the variable doesn't exist.

=method remove_symbol $variable

Removes the package variable described by C<$variable> (which includes the
sigil); other variables with the same name but different sigils will be
untouched.

=method list_all_symbols $type_filter

Returns a list of package variable names in the package, without sigils. If a
C<type_filter> is passed, it is used to select package variables of a given
type, where valid types are the slots of a typeglob ('SCALAR', 'CODE', 'HASH',
etc). Note that if the package contained any C<BEGIN> blocks, perl will leave
an empty typeglob in the C<BEGIN> slot, so this will show up if no filter is
used (and similarly for C<INIT>, C<END>, etc).

=head1 BUGS

No known bugs.

Please report any bugs through RT: email
C<bug-package-stash at rt.cpan.org>, or browse to
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Package-Stash>.

=head1 SEE ALSO

=over 4

=item * L<Class::MOP::Package>

This module is a factoring out of code that used to live here

=back

=head1 SUPPORT

You can find this documentation for this module with the perldoc command.

    perldoc Package::Stash

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Package-Stash>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Package-Stash>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Package-Stash>

=item * Search CPAN

L<http://search.cpan.org/dist/Package-Stash>

=back

=head1 AUTHOR

Jesse Luehrs <doy at tozt dot net>

Mostly copied from code from L<Class::MOP::Package>, by Stevan Little and the
Moose Cabal.

=cut

1;

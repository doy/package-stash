#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Package::Stash;

{
    package Foo;
    use constant FOO => 1;
    use constant BAR => \1;
    use constant BAZ => [];
    use constant QUUX => {};
    use constant QUUUX => sub { };
    sub normal { }
    sub stub;
    sub normal_with_proto () { }
    sub stub_with_proto ();

    our $SCALAR;
    our @ARRAY;
    our %HASH;
}

my $stash = Package::Stash->new('Foo');
ok($stash->has_package_symbol('$SCALAR'), '$SCALAR');
ok($stash->has_package_symbol('@ARRAY'), '@ARRAY');
ok($stash->has_package_symbol('%HASH'), '%HASH');
is_deeply(
    [sort $stash->list_all_package_symbols('CODE')],
    [qw(BAR BAZ FOO QUUUX QUUX normal normal_with_proto stub stub_with_proto)],
    "can see all code symbols"
);

done_testing;

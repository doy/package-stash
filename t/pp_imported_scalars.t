#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

BEGIN { $Package::Stash::IMPLEMENTATION = 'PP' }

use Package::Stash;

{
    package Foo::Test::Scalar;
    use vars qw/$xyz/;

    sub xyz { 1 };
    sub abc { 1 };
}

my $ps = Package::Stash->new('Foo::Test::Scalar');
Test::More::ok($ps->has_symbol('$xyz'), "Found imported scalar, even though it is undef.");
Test::More::ok(!$ps->has_symbol('$abc'), "did not find undeclared scalar");

done_testing;

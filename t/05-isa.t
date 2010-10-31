#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Package::Stash;

{
    package Foo;
}

{
    package Bar;
}

my $stash = Package::Stash->new('Foo');
my @ISA = ('Bar');
@{$stash->get_package_symbol('@ISA')} = @ISA;
isa_ok('Foo', 'Bar');

done_testing;

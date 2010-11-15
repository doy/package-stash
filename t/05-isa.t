#!/usr/bin/env perl
use strict;
use warnings;
use lib 't/lib';
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
@{$stash->get_or_add_symbol('@ISA')} = @ISA;
isa_ok('Foo', 'Bar');

done_testing;

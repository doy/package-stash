#!/usr/bin/env perl
use strict;
use warnings;
use lib 't/lib';
use Test::More;

use Package::Stash;

# @ISA magic
{
    my $Foo = Package::Stash->new('ISAFoo');
    $Foo->add_symbol('&foo' => sub { });

    my $Bar = Package::Stash->new('ISABar');
    @{ $Bar->get_or_add_symbol('@ISA') } = ('ISAFoo');
    can_ok('ISABar', 'foo');

    my $Foo2 = Package::Stash->new('ISAFoo2');
    $Foo2->add_symbol('&foo2' => sub { });
    @{ $Bar->get_or_add_symbol('@ISA') } = ('ISAFoo2');
    can_ok('ISABar', 'foo2');
    ok(!Bar->can('foo'));
}

{
    my $main = Package::Stash->new('main');
    $main->add_symbol('$"', '-');
    my @foo = qw(a b c);
    is(eval q["@foo"], 'a-b-c');
}

done_testing;

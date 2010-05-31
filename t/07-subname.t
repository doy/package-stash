#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Package::Stash;

my $foo_stash = Package::Stash->new('Foo');
$foo_stash->add_package_symbol('&foo' => sub { caller(0) });
is((Foo::foo())[3], 'main::__ANON__', "no subname if not requested");

$foo_stash->add_package_symbol('&bar' => sub { caller(0) }, subname => 'bar');
is((Foo::bar())[3], 'Foo::bar', "got the right subname with implicit package");

$foo_stash->add_package_symbol('&baz' => sub { caller(0) }, subname => 'BAZ');
is((Foo::baz())[3], 'Foo::BAZ', "got the right subname with implicit package and different glob name");

$foo_stash->add_package_symbol('&quux' => sub { caller(0) }, subname => 'Bar::quux');
is((Foo::quux())[3], 'Bar::quux', "got the right subname with explicit package");

done_testing;

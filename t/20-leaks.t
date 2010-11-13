#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Fatal;
use Test::Requires 'Test::LeakTrace';

use Package::Stash;
use Symbol;

{
    package Bar;
}

{
    package Baz;
    our $foo;
    sub bar { }
    use constant baz => 1;
    our %quux = (a => 'b');
}

{
    no_leaks_ok {
        Package::Stash->new('Foo');
    } "object construction doesn't leak";
}

{
    no_leaks_ok {
        Package::Stash->new('Bar');
    } "object construction doesn't leak, with an existing package";
}

{
    no_leaks_ok {
        Package::Stash->new('Baz');
    } "object construction doesn't leak, with an existing package with things in it";
}

{
    my $foo = Package::Stash->new('Foo');
    no_leaks_ok {
        $foo->name;
        $foo->namespace;
    } "accessors don't leak";
}

{
    my $foo = Package::Stash->new('Foo');
    leaks_cmp_ok {
        $foo->add_package_symbol('$scalar');
        $foo->add_package_symbol('@array');
        $foo->add_package_symbol('%hash');
        $foo->add_package_symbol('io');
    } '==', 4, "add_package_symbol doesn't leak";
}

{
    my $foo = Package::Stash->new('Foo');
    leaks_cmp_ok {
        $foo->add_package_symbol('$scalar_init' => 1);
        $foo->add_package_symbol('@array_init' => []);
        $foo->add_package_symbol('%hash_init' => {});
        # hmmm, wonder why this coderef isn't treated as a leak
        $foo->add_package_symbol('&code_init' => sub { "foo" });
        $foo->add_package_symbol('io_init' => Symbol::geniosym);
    } '==', 9, "add_package_symbol doesn't leak";
    is(exception {
        is(Foo->code_init, 'foo', "sub installed correctly")
    }, undef, "code_init exists");
}

{
    my $foo = Package::Stash->new('Foo');
    no_leaks_ok {
        $foo->remove_package_symbol('$scalar_init');
        $foo->remove_package_symbol('@array_init');
        $foo->remove_package_symbol('%hash_init');
        $foo->remove_package_symbol('&code_init');
        $foo->remove_package_symbol('io_init');
    } "remove_package_symbol doesn't leak";
}

{
    my $foo = Package::Stash->new('Foo');
    $foo->add_package_symbol("${_}glob") for ('$', '@', '%', '&', '');
    no_leaks_ok {
        $foo->remove_package_glob('glob');
    } "remove_package_glob doesn't leak";
}

{
    my $foo = Package::Stash->new('Foo');
    no_leaks_ok {
        $foo->has_package_symbol('io');
        $foo->has_package_symbol('%hash');
        $foo->has_package_symbol('@array_init');
        $foo->has_package_symbol('$glob');
        $foo->has_package_symbol('&something_else');
    } "has_package_symbol doesn't leak";
}

{
    my $foo = Package::Stash->new('Foo');
    no_leaks_ok {
        $foo->get_package_symbol('io');
        $foo->get_package_symbol('%hash');
        $foo->get_package_symbol('@array_init');
        $foo->get_package_symbol('$glob');
        $foo->get_package_symbol('&something_else');
    } "get_package_symbol doesn't leak";
}

{
    my $foo = Package::Stash->new('Foo');
    ok(!$foo->has_package_symbol('$glob'));
    ok(!$foo->has_package_symbol('@array_init'));
    no_leaks_ok {
        $foo->get_or_add_package_symbol('io');
        $foo->get_or_add_package_symbol('%hash');
        # and why are these not leaks either?
        $foo->get_or_add_package_symbol('@array_init');
        $foo->get_or_add_package_symbol('$glob');
    } "get_or_add_package_symbol doesn't leak";
    ok($foo->has_package_symbol('$glob'));
    is(ref($foo->get_package_symbol('$glob')), 'SCALAR');
    ok($foo->has_package_symbol('@array_init'));
    is(ref($foo->get_package_symbol('@array_init')), 'ARRAY');
}

{
    my $foo = Package::Stash->new('Foo');
    my $baz = Package::Stash->new('Baz');
    no_leaks_ok {
        $foo->list_all_package_symbols;
        $foo->list_all_package_symbols('SCALAR');
        $foo->list_all_package_symbols('CODE');
        $baz->list_all_package_symbols('CODE');
    } "list_all_package_symbols doesn't leak";
}

done_testing;

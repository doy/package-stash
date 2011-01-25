#!/usr/bin/env perl
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Test::Fatal;
use Test::LeakTrace;

BEGIN { $^P |= 0x210 } # PERLDBf_SUBLINE

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
    no_leaks_ok {
        $foo->add_symbol('$scalar');
        $foo->add_symbol('@array');
        $foo->add_symbol('%hash');
        $foo->add_symbol('io');
    } "add_symbol doesn't leak";
}

{
    my $foo = Package::Stash->new('Foo');
    { local $TODO = $Package::Stash::IMPLEMENTATION eq 'PP'
        ? "the pure perl implementation leaks here somehow"
        : undef;
    no_leaks_ok {
        $foo->add_symbol('$scalar_init' => 1);
        $foo->add_symbol('@array_init' => []);
        $foo->add_symbol('%hash_init' => {});
        $foo->add_symbol('&code_init' => sub { "foo" });
        $foo->add_symbol('io_init' => Symbol::geniosym);
    } "add_symbol doesn't leak";
    }
    is(exception {
        is(Foo->code_init, 'foo', "sub installed correctly")
    }, undef, "code_init exists");
}

{
    my $foo = Package::Stash->new('Foo');
    no_leaks_ok {
        $foo->remove_symbol('$scalar_init');
        $foo->remove_symbol('@array_init');
        $foo->remove_symbol('%hash_init');
        $foo->remove_symbol('&code_init');
        $foo->remove_symbol('io_init');
    } "remove_symbol doesn't leak";
}

{
    my $foo = Package::Stash->new('Foo');
    $foo->add_symbol("${_}glob") for ('$', '@', '%', '&', '');
    no_leaks_ok {
        $foo->remove_glob('glob');
    } "remove_glob doesn't leak";
}

{
    my $foo = Package::Stash->new('Foo');
    no_leaks_ok {
        $foo->has_symbol('io');
        $foo->has_symbol('%hash');
        $foo->has_symbol('@array_init');
        $foo->has_symbol('$glob');
        $foo->has_symbol('&something_else');
    } "has_symbol doesn't leak";
}

{
    my $foo = Package::Stash->new('Foo');
    no_leaks_ok {
        $foo->get_symbol('io');
        $foo->get_symbol('%hash');
        $foo->get_symbol('@array_init');
        $foo->get_symbol('$glob');
        $foo->get_symbol('&something_else');
    } "get_symbol doesn't leak";
}

{
    my $foo = Package::Stash->new('Foo');
    ok(!$foo->has_symbol('$glob'));
    ok(!$foo->has_symbol('@array_init'));
    no_leaks_ok {
        $foo->get_or_add_symbol('io');
        $foo->get_or_add_symbol('%hash');
        my @super = ('Exporter');
        @{$foo->get_or_add_symbol('@ISA')} = @super;
        $foo->get_or_add_symbol('$glob');
    } "get_or_add_symbol doesn't leak";
    { local $TODO = ($] < 5.010 || $Package::Stash::IMPLEMENTATION eq 'PP')
        ? "undef scalars aren't visible on 5.8, or from pure perl at all"
        : undef;
    ok($foo->has_symbol('$glob'));
    }
    is(ref($foo->get_symbol('$glob')), 'SCALAR');
    ok($foo->has_symbol('@ISA'));
    is(ref($foo->get_symbol('@ISA')), 'ARRAY');
    is_deeply($foo->get_symbol('@ISA'), ['Exporter']);
    isa_ok('Foo', 'Exporter');
}

{
    my $foo = Package::Stash->new('Foo');
    my $baz = Package::Stash->new('Baz');
    no_leaks_ok {
        $foo->list_all_symbols;
        $foo->list_all_symbols('SCALAR');
        $foo->list_all_symbols('CODE');
        $baz->list_all_symbols('CODE');
    } "list_all_symbols doesn't leak";
}

{
    package Blah;
    use constant 'baz';
}

{
    my $foo = Package::Stash->new('Foo');
    my $blah = Package::Stash->new('Blah');
    no_leaks_ok {
        $foo->get_all_symbols;
        $foo->get_all_symbols('SCALAR');
        $foo->get_all_symbols('CODE');
        $blah->get_all_symbols('CODE');
    } "get_all_symbols doesn't leak";
}

# mimic CMOP::create_anon_class
{
    local $TODO = $] < 5.010 ? "deleting stashes is inherently leaky on 5.8"
                             : undef;
    my $i = 0;
    no_leaks_ok {
        $i++;
        eval "package Quux$i; 1;";
        my $quux = Package::Stash->new("Quux$i");
        $quux->get_or_add_symbol('@ISA');
        delete $::{'Quux' . $i . '::'};
    } "get_symbol doesn't leak during glob expansion";
}

{
    local $TODO = ($Package::Stash::IMPLEMENTATION eq 'PP'
                && $Carp::VERSION ge '1.17')
        ? "Carp is leaky on 5.12.2 apparently?"
        : undef;
    my $foo = Package::Stash->new('Foo');
    no_leaks_ok {
        eval { $foo->get_or_add_symbol('&blorg') };
    } "doesn't leak on errors";
}

done_testing;

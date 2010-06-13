#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Package::Stash;

{
    BEGIN {
        my $stash = Package::Stash->new('Foo');
        my $val = $stash->get_package_symbol('%foo');
        is($val, undef, "got nothing yet");
    }
    {
        no warnings 'void', 'once';
        %Foo::foo;
    }
    BEGIN {
        my $stash = Package::Stash->new('Foo');
        my $val = $stash->get_package_symbol('%foo');
        is(ref($val), 'HASH', "got something");
        $val->{bar} = 1;
        is_deeply($stash->get_package_symbol('%foo'), {bar => 1},
                "got the right variable");
    }
}

{
    BEGIN {
        my $stash = Package::Stash->new('Bar');
        my $val = $stash->get_package_symbol('@foo');
        is($val, undef, "got something");
    }
    {
        no warnings 'void', 'once';
        @Bar::foo;
    }
    BEGIN {
        my $stash = Package::Stash->new('Bar');
        my $val = $stash->get_package_symbol('@foo');
        is(ref($val), 'ARRAY', "got something");
        push @$val, 1;
        is_deeply($stash->get_package_symbol('@foo'), [1],
                "got the right variable");
    }
}

{
    my $stash = Package::Stash->new('Baz');
    my $val = $stash->get_or_add_package_symbol('%foo');
    is(ref($val), 'HASH', "got something");
    $val->{bar} = 1;
    is_deeply($stash->get_or_add_package_symbol('%foo'), {bar => 1},
            "got the right variable");
}

{
    my $stash = Package::Stash->new('Quux');
    my $val = $stash->get_or_add_package_symbol('@foo');
    is(ref($val), 'ARRAY', "got something");
    push @$val, 1;
    is_deeply($stash->get_or_add_package_symbol('@foo'), [1],
            "got the right variable");
}

done_testing;

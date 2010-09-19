#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Package::Stash;

{
    BEGIN {
        my $stash = Package::Stash->new('Hash');
        my $val = $stash->get_package_symbol('%foo');
        is($val, undef, "got nothing yet");
    }
    {
        no warnings 'void', 'once';
        %Hash::foo;
    }
    BEGIN {
        my $stash = Package::Stash->new('Hash');
        my $val = $stash->get_package_symbol('%foo');
        is(ref($val), 'HASH', "got something");
        $val->{bar} = 1;
        is_deeply($stash->get_package_symbol('%foo'), {bar => 1},
                  "got the right variable");
        is_deeply(\%Hash::foo, {bar => 1},
                  "stash has the right variable");
    }
}

{
    BEGIN {
        my $stash = Package::Stash->new('Array');
        my $val = $stash->get_package_symbol('@foo');
        is($val, undef, "got nothing yet");
    }
    {
        no warnings 'void', 'once';
        @Array::foo;
    }
    BEGIN {
        my $stash = Package::Stash->new('Array');
        my $val = $stash->get_package_symbol('@foo');
        is(ref($val), 'ARRAY', "got something");
        push @$val, 1;
        is_deeply($stash->get_package_symbol('@foo'), [1],
                  "got the right variable");
        is_deeply(\@Array::foo, [1],
                  "stash has the right variable");
    }
}

{
    BEGIN {
        my $stash = Package::Stash->new('Scalar');
        my $val = $stash->get_package_symbol('$foo');
        is($val, undef, "got nothing yet");
    }
    {
        no warnings 'void', 'once';
        $Scalar::foo;
    }
    BEGIN {
        my $stash = Package::Stash->new('Scalar');
        my $val = $stash->get_package_symbol('$foo');
        is(ref($val), 'SCALAR', "got something");
        $$val = 1;
        is_deeply($stash->get_package_symbol('$foo'), \1,
                  "got the right variable");
        is($Scalar::foo, 1,
           "stash has the right variable");
    }
}

{
    BEGIN {
        my $stash = Package::Stash->new('Io');
        my $val = $stash->get_package_symbol('FOO');
        is($val, undef, "got nothing yet");
    }
    {
        no warnings 'void', 'once';
        package Io;
        fileno(FOO);
    }
    BEGIN {
        my $stash = Package::Stash->new('Io');
        my $val = $stash->get_package_symbol('FOO');
        isa_ok($val, 'IO');
        my $str = "foo";
        open $val, '<', \$str;
        is(readline($stash->get_package_symbol('FOO')), "foo",
           "got the right variable");
        seek($stash->get_package_symbol('FOO'), 0, 0);
        {
            package Io;
            ::isa_ok(*FOO{IO}, 'IO');
            ::is(<FOO>, "foo",
                 "stash has the right variable");
        }
    }
}

TODO: {
    # making TODO tests at a mixture of BEGIN and runtime is irritating
    my $_TODO;
    BEGIN { $_TODO = "obviously I don't understand this well enough"; }
    BEGIN { $TODO = $_TODO; }
    $TODO = $_TODO;
    BEGIN {
        my $stash = Package::Stash->new('Code');
        my $val = $stash->get_package_symbol('&foo');
        is($val, undef, "got nothing yet");
    }
    {
        no warnings 'void', 'once';
        \&Code::foo;
    }
    BEGIN {
        my $stash = Package::Stash->new('Code');
        my $val = $stash->get_package_symbol('&foo');
        undef $TODO;
        is(ref($val), 'CODE', "got something");
        $TODO = $_TODO;
        SKIP: {
            eval "require PadWalker"
                or skip "needs PadWalker", 1;
            # avoid padwalker segfault
            if (!defined($val)) {
                fail("got the right variable");
            }
            else {
                PadWalker::set_closed_over($val, {'$x' => 1});
                is_deeply({PadWalker::closed_over($stash->get_package_symbol('&foo'))}, {'$x' => 1},
                          "got the right variable");
                is_deeply({PadWalker::closed_over(\&Code::foo)}, {'$x' => 1},
                          "stash has the right variable");
            }
        }
    }
    BEGIN { undef $TODO; }
    undef $TODO;
}

{
    my $stash = Package::Stash->new('Hash::Vivify');
    my $val = $stash->get_or_add_package_symbol('%foo');
    is(ref($val), 'HASH', "got something");
    $val->{bar} = 1;
    is_deeply($stash->get_or_add_package_symbol('%foo'), {bar => 1},
              "got the right variable");
    no warnings 'once';
    is_deeply(\%Hash::Vivify::foo, {bar => 1},
              "stash has the right variable");
}

{
    my $stash = Package::Stash->new('Array::Vivify');
    my $val = $stash->get_or_add_package_symbol('@foo');
    is(ref($val), 'ARRAY', "got something");
    push @$val, 1;
    is_deeply($stash->get_or_add_package_symbol('@foo'), [1],
              "got the right variable");
    no warnings 'once';
    is_deeply(\@Array::Vivify::foo, [1],
              "stash has the right variable");
}

{
    my $stash = Package::Stash->new('Scalar::Vivify');
    my $val = $stash->get_or_add_package_symbol('$foo');
    is(ref($val), 'SCALAR', "got something");
    $$val = 1;
    is_deeply($stash->get_or_add_package_symbol('$foo'), \1,
              "got the right variable");
    no warnings 'once';
    is($Scalar::Vivify::foo, 1,
       "stash has the right variable");
}

{
    BEGIN {
        my $stash = Package::Stash->new('Io::Vivify');
        my $val = $stash->get_or_add_package_symbol('FOO');
        isa_ok($val, 'IO');
        my $str = "foo";
        open $val, '<', \$str;
        is(readline($stash->get_package_symbol('FOO')), "foo",
           "got the right variable");
        seek($stash->get_package_symbol('FOO'), 0, 0);
    }
    {
        package Io::Vivify;
        no warnings 'once';
        ::isa_ok(*FOO{IO}, 'IO');
        ::is(<FOO>, "foo",
             "stash has the right variable");
    }
}

done_testing;

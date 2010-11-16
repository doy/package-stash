#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

sub clear_load {
    delete $Package::{'Stash::'};
    delete $INC{'Package/Stash.pm'};
    delete $INC{'Package/Stash/PP.pm'};
    delete $INC{'Package/Stash/XS.pm'};
}

my $has_xs;

{
    $has_xs = eval "require Package::Stash::XS; 1";
    clear_load;
}

{
    require Package::Stash;
    warn $Package::Stash::IMPLEMENTATION;
    is($Package::Stash::IMPLEMENTATION, $has_xs ? 'XS' : 'PP',
       "autodetected properly");
    can_ok('Package::Stash', 'new', "and got some methods");
    clear_load;
}

{
    $ENV{PACKAGE_STASH_IMPLEMENTATION} = 'PP';
    require Package::Stash;
    is($Package::Stash::IMPLEMENTATION, 'PP',
       "autodetected properly");
    can_ok('Package::Stash', 'new', "and got some methods");
    clear_load;
}

SKIP: {
    skip "no XS", 2 unless $has_xs;
    $ENV{PACKAGE_STASH_IMPLEMENTATION} = 'XS';
    require Package::Stash;
    is($Package::Stash::IMPLEMENTATION, 'XS',
       "autodetected properly");
    can_ok('Package::Stash', 'new', "and got some methods");
    clear_load;
}

{
    $Package::Stash::IMPLEMENTATION = 'PP';
    require Package::Stash;
    is($Package::Stash::IMPLEMENTATION, 'PP',
       "autodetected properly");
    can_ok('Package::Stash', 'new', "and got some methods");
    clear_load;
}

SKIP: {
    skip "no XS", 2 unless $has_xs;
    $Package::Stash::IMPLEMENTATION = 'XS';
    require Package::Stash;
    is($Package::Stash::IMPLEMENTATION, 'XS',
       "autodetected properly");
    can_ok('Package::Stash', 'new', "and got some methods");
    clear_load;
}

done_testing;

package # hide from PAUSE
    Package::Stash;
use strict;
use warnings;

use Package::Stash::PP;

our $IMPLEMENTATION = 'PP';

BEGIN {
    my $ps = Package::Stash::PP->new(__PACKAGE__);
    my $ps_pp = Package::Stash::PP->new('Package::Stash::PP');
    for my $method ($ps_pp->list_all_symbols('CODE')) {
        my $sym = '&' . $method;
        $ps->add_symbol($sym => $ps_pp->get_symbol($sym));
    }
}

1;

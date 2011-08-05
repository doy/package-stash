#!/usr/bin/env perl
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Test::Fatal;

use Package::Stash;

{
    package Foo;
    use constant FOO => 1;
    use constant BAR => \1;
    use constant BAZ => [];
    use constant QUUX => {};
    use constant QUUUX => sub { };
    sub normal { }
    sub stub;
    sub normal_with_proto () { }
    sub stub_with_proto ();

    our $SCALAR;
    our $SCALAR_WITH_VALUE = 1;
    our @ARRAY;
    our %HASH;
}

my $stash = Package::Stash->new('Foo');
{ local $TODO = ($] < 5.010 || $Package::Stash::IMPLEMENTATION eq 'PP')
      ? "undef scalars aren't visible on 5.8, or from pure perl at all"
      : undef;
ok($stash->has_symbol('$SCALAR'), '$SCALAR');
}
ok($stash->has_symbol('$SCALAR_WITH_VALUE'), '$SCALAR_WITH_VALUE');
ok($stash->has_symbol('@ARRAY'), '@ARRAY');
ok($stash->has_symbol('%HASH'), '%HASH');
is_deeply(
    [sort $stash->list_all_symbols('CODE')],
    [qw(BAR BAZ FOO QUUUX QUUX normal normal_with_proto stub stub_with_proto)],
    "can see all code symbols"
);

$stash->add_symbol('%added', {});
ok(!$stash->has_symbol('$added'), '$added');
ok(!$stash->has_symbol('@added'), '@added');
ok($stash->has_symbol('%added'), '%added');

my $constant = $stash->get_symbol('&FOO');
is(ref($constant), 'CODE', "expanded a constant into a coderef");

# ensure get doesn't prevent subsequent vivification (not sure what the deal
# was here)
is(ref($stash->get_symbol('$glob')), '', "nothing yet");
is(ref($stash->get_or_add_symbol('$glob')), 'SCALAR', "got an empty scalar");

my $Bar = Package::Stash->new('Bar');
my $foo = 3;
$foo =~ s/3/4/;
my $bar = 4.5;
$bar =~ s/4/5/;

is(exception { $Bar->add_symbol('$foo', \$foo) }, undef,
   "can add PVIV values");
is(exception { $Bar->add_symbol('$bar', \$bar) }, undef,
   "can add PVNV values");
is(exception { bless \$bar, 'Foo'; $Bar->add_symbol('$bar2', $bar) }, undef,
   "can add PVMG values");
is(exception { $Bar->add_symbol('$baz', qr/foo/) }, undef,
   "can add regex values");
is(exception { undef $bar; $Bar->add_symbol('$quux', \$bar) }, undef,
   "can add undef values that aren't NULL");

use_ok('CompileTime');

{
    package Gets::Deleted;
    sub bar { }
}

{
    my $delete = Package::Stash->new('Gets::Deleted');
    ok($delete->has_symbol('&bar'), "sees the method");
    {
        no strict 'refs';
        delete ${'main::Gets::'}{'Deleted::'};
    }
    ok(!$delete->has_symbol('&bar'), "method goes away when stash is deleted");
}

done_testing;

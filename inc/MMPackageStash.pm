package inc::MMPackageStash;
use Moose;

extends 'Dist::Zilla::Plugin::MakeMaker::Awesome';

# XXX: this is pretty gross, it should be possible to clean this up later
around _build_MakeFile_PL_template => sub {
    my $orig = shift;
    my $self = shift;

    # copied from M::I
    my $can_cc = <<'CAN_CC';
use Config ();
use File::Spec ();

# check if we can run some command
sub can_run {
        my ($cmd) = @_;

        my $_cmd = $cmd;
        return $_cmd if (-x $_cmd or $_cmd = MM->maybe_command($_cmd));

        for my $dir ((split /$Config::Config{path_sep}/, $ENV{PATH}), '.') {
                next if $dir eq '';
                my $abs = File::Spec->catfile($dir, $_[1]);
                return $abs if (-x $abs or $abs = MM->maybe_command($abs));
        }

        return;
}

# can we locate a (the) C compiler
sub can_cc {
        my @chunks = split(/ /, $Config::Config{cc}) or return;

        # $Config{cc} may contain args; try to find out the program part
        while (@chunks) {
                return can_run("@chunks") || (pop(@chunks), next);
        }

        return;
}
CAN_CC

    # copied out of moose
    my $check_conflicts = <<'CHECK_CONFLICTS';
sub check_conflicts {
    my %conflicts = (
        'Class::MOP'                    => '1.08',
        'MooseX::Role::WithOverloading' => '0.08',
        'namespace::clean'              => '0.18',
    );
    my $found = 0;
    for my $mod ( sort keys %conflicts ) {
        eval "require $mod";
        next if $@;

        my $installed = $mod->VERSION();
        if ( $installed le $conflicts{$mod} ) {

            print <<"EOF";

***
    This version of Package::Stash conflicts with the version of
    $mod ($installed) you have installed.

    You will need to upgrade $mod after installing
    this version of Package::Stash.
***

EOF

            $found = 1;
        }
    }

    return unless $found;

    # More or less copied from Module::Build
    return if  $ENV{PERL_MM_USE_DEFAULT};
    return unless -t STDIN && (-t STDOUT || !(-f STDOUT || -c STDOUT));

    sleep 4;
}
CHECK_CONFLICTS

    my $template = $self->$orig(@_);

    $template =~ s/(use ExtUtils::MakeMaker.*)/$1\n\ncheck_conflicts();/;
    $template =~ s/(WriteMakefile\()/delete \$WriteMakefileArgs{PREREQ_PM}{'Package::Stash::XS'}\n  unless can_cc();\n\n$1/;

    return $template . $can_cc . $check_conflicts;
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;

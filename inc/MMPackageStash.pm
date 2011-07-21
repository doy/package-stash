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
                my $abs = File::Spec->catfile($dir, $_[0]);
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

    my $template = $self->$orig(@_);

    my $xs_version = $self->zilla->prereqs->requirements_for('runtime', 'recommends')->as_string_hash->{'Package::Stash::XS'};

    $template =~ s/(WriteMakefile\()/\$WriteMakefileArgs{PREREQ_PM}{'Package::Stash::XS'} = $xs_version\n  if can_cc();\n\n$1/;

    return $template . $can_cc;
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;

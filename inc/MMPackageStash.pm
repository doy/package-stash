package inc::MMPackageStash;
use Moose;

extends 'Dist::Zilla::Plugin::MakeMaker::Awesome';

# XXX: this is pretty gross, it should be possible to clean this up later
around _build_MakeFile_PL_template => sub {
    my $orig = shift;
    my $self = shift;
    my $template = $self->$orig(@_);

    $template =~ s/(use ExtUtils::MakeMaker.*)/$1\n\ncheck_conflicts();/;

    $template .= <<'CHECK_CONFLICTS';
sub check_conflicts {
    my %conflicts = (
        'Class::MOP'                    => '1.08',
        'MooseX::Role::WithOverloading' => '0.08',
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

    return $template;
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;

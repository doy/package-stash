use ExtUtils::MakeMaker;

# NOTE:
# this is a very simple Makefile.PL i only use to build the distribution locally
# while working on it the real Makefile.PL, with all required information like
# dependencies, is generated later by Dist::Zilla

WriteMakefile(
    NAME => 'Package::Stash',
);

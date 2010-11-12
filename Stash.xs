#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

MODULE = Package::Stash  PACKAGE = Package::Stash

SV*
new(class, package_name)
    char *class
    SV *package_name
  INIT:
    HV *instance;
    HV *namespace;
  CODE:
    if (!SvPOK(package_name))
        croak("The constructor argument must be the name of a package");

    instance = newHV();

    hv_store(instance, "name", 4, package_name, 0);
    namespace = gv_stashpv(SvPV_nolen(package_name), GV_ADD);
    hv_store(instance, "namespace", 9, newRV((SV*)namespace), 0);

    RETVAL = sv_bless(newRV((SV*)instance), gv_stashpv(class, 0));
  OUTPUT:
    RETVAL

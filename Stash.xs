#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

HV *_get_namespace(SV *self)
{
    dSP;
    SV *ret;

    PUSHMARK(SP);
    XPUSHs(self);
    PUTBACK;

    call_method("namespace", G_SCALAR);

    SPAGAIN;
    ret = POPs;
    PUTBACK;

    return (HV*)SvRV(ret);
}

MODULE = Package::Stash  PACKAGE = Package::Stash

PROTOTYPES: DISABLE

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

SV*
name(self)
    SV *self
  INIT:
    SV **slot;
  CODE:
    if (!sv_isobject(self))
        croak("Can't call name as a class method");
    slot = hv_fetch((HV*)SvRV(self), "name", 4, 0);
    RETVAL = slot ? SvREFCNT_inc(*slot) : &PL_sv_undef;
  OUTPUT:
    RETVAL

SV*
namespace(self)
    SV *self
  INIT:
    SV **slot;
  CODE:
    if (!sv_isobject(self))
        croak("Can't call namespace as a class method");
    slot = hv_fetch((HV*)SvRV(self), "namespace", 9, 0);
    RETVAL = slot ? SvREFCNT_inc(*slot) : &PL_sv_undef;
  OUTPUT:
    RETVAL

void
remove_package_glob(self, name)
    SV *self
    char *name
  INIT:
    HV *namespace;
  CODE:
    hv_delete(_get_namespace(self), name, strlen(name), G_DISCARD);

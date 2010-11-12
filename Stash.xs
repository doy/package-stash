#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

typedef enum {
    VAR_NONE = 0,
    VAR_SCALAR,
    VAR_ARRAY,
    VAR_HASH,
    VAR_CODE,
    VAR_IO,
    VAR_GLOB,  /* TODO: unimplemented */
    VAR_FORMAT /* TODO: unimplemented */
} vartype_t;

typedef struct {
    vartype_t type;
    char sigil;
    char *name;
} varspec_t;

vartype_t string_to_vartype(char *vartype)
{
    if (strEQ(vartype, "SCALAR")) {
        return VAR_SCALAR;
    }
    else if (strEQ(vartype, "ARRAY")) {
        return VAR_ARRAY;
    }
    else if (strEQ(vartype, "HASH")) {
        return VAR_HASH;
    }
    else if (strEQ(vartype, "CODE")) {
        return VAR_CODE;
    }
    else if (strEQ(vartype, "IO")) {
        return VAR_IO;
    }
    else {
        croak("Type must be one of 'SCALAR', 'ARRAY', 'HASH', 'CODE', or 'IO'");
    }
}

void _deconstruct_variable_name(char *variable, varspec_t *varspec)
{
    if (!variable || !variable[0])
        croak("You must pass a variable name");

    varspec->type = VAR_NONE;

    switch (variable[0]) {
    case '$':
        varspec->type = VAR_SCALAR;
        break;
    case '@':
        varspec->type = VAR_ARRAY;
        break;
    case '%':
        varspec->type = VAR_HASH;
        break;
    case '&':
        varspec->type = VAR_CODE;
        break;
    }

    if (varspec->type != VAR_NONE) {
        varspec->sigil = variable[0];
        varspec->name = &variable[1];
    }
    else {
        varspec->type = VAR_IO;
        varspec->sigil = '\0';
        varspec->name = variable;
    }
}

void _deconstruct_variable_hash(HV *variable, varspec_t *varspec)
{
    SV **val;
    char *type;

    val = hv_fetch(variable, "name", 4, 0);
    if (!val)
        croak("The 'name' key is required in variable specs");

    varspec->name = savesvpv(*val);

    val = hv_fetch(variable, "sigil", 5, 0);
    if (!val)
        croak("The 'sigil' key is required in variable specs");

    varspec->sigil = (SvPV_nolen(*val))[0];

    val = hv_fetch(variable, "type", 4, 0);
    if (!val)
        croak("The 'type' key is required in variable specs");

    varspec->type = string_to_vartype(SvPV_nolen(*val));
}

int _valid_for_type(SV *value, vartype_t type)
{
    svtype sv_type = SvROK(value) ? SvTYPE(SvRV(value)) : SVt_NULL;

    switch (type) {
    case VAR_SCALAR:
        return sv_type == SVt_NULL ||
               sv_type == SVt_IV   ||
               sv_type == SVt_NV   ||
               sv_type == SVt_PV   ||
               sv_type == SVt_RV;
    case VAR_ARRAY:
        return sv_type == SVt_PVAV;
    case VAR_HASH:
        return sv_type == SVt_PVHV;
    case VAR_CODE:
        return sv_type == SVt_PVCV;
    case VAR_IO:
        return sv_type == SVt_PVGV;
    default:
        return 0;
    }
}

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
  PREINIT:
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
  PREINIT:
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
  PREINIT:
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
  PREINIT:
    HV *namespace;
  CODE:
    hv_delete(_get_namespace(self), name, strlen(name), G_DISCARD);

void
list_all_package_symbols(self, vartype=VAR_NONE)
    SV *self
    vartype_t vartype
  PPCODE:
    if (vartype == VAR_NONE) {
        HV *namespace;
        HE *entry;
        int keys;

        namespace = _get_namespace(self);
        keys = hv_iterinit(namespace);
        EXTEND(SP, keys);
        while (entry = hv_iternext(namespace)) {
            mPUSHs(newSVhek(HeKEY_hek(entry)));
        }
    }
    else {
        HV *namespace;
        HE *entry;
        SV *val;
        char *key;
        int len;

        namespace = _get_namespace(self);
        hv_iterinit(namespace);
        while (val = hv_iternextsv(namespace, &key, &len)) {
            GV *gv = (GV*)val;
            if (isGV(gv)) {
                switch (vartype) {
                case VAR_SCALAR:
                    if (GvSV(val))
                        mXPUSHp(key, len);
                    break;
                case VAR_ARRAY:
                    if (GvAV(val))
                        mXPUSHp(key, len);
                    break;
                case VAR_HASH:
                    if (GvHV(val))
                        mXPUSHp(key, len);
                    break;
                case VAR_CODE:
                    if (GvCVu(val))
                        mXPUSHp(key, len);
                    break;
                case VAR_IO:
                    if (GvIO(val))
                        mXPUSHp(key, len);
                    break;
                }
            }
            else if (vartype == VAR_CODE) {
                mXPUSHp(key, len);
            }
        }
    }

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

const char *vartype_to_string(vartype_t type)
{
    switch (type) {
    case VAR_SCALAR:
        return "SCALAR";
    case VAR_ARRAY:
        return "ARRAY";
    case VAR_HASH:
        return "HASH";
    case VAR_CODE:
        return "CODE";
    case VAR_IO:
        return "IO";
    default:
        return "unknown";
    }
}

I32 vartype_to_svtype(vartype_t type)
{
    switch (type) {
    case VAR_SCALAR:
        return SVt_PV; /* or whatever */
    case VAR_ARRAY:
        return SVt_PVAV;
    case VAR_HASH:
        return SVt_PVHV;
    case VAR_CODE:
        return SVt_PVCV;
    case VAR_IO:
        return SVt_PVIO;
    default:
        return SVt_NULL;
    }
}

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
        return sv_type == SVt_PVIO;
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

SV *_get_name(SV *self)
{
    dSP;
    SV *ret;

    PUSHMARK(SP);
    XPUSHs(self);
    PUTBACK;

    call_method("name", G_SCALAR);

    SPAGAIN;
    ret = POPs;
    PUTBACK;

    return ret;
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
add_package_symbol(self, variable, initial=NULL, ...)
    SV *self
    varspec_t variable
    SV *initial
  PREINIT:
    SV *name;
    GV *glob;
  CODE:
    if (initial && !_valid_for_type(initial, variable.type))
        croak("%s is not of type %s",
              SvPV_nolen(initial), vartype_to_string(variable.type));

    name = newSVsv(_get_name(self));
    sv_catpvs(name, "::");
    sv_catpv(name, variable.name);

    /* XXX: come back to this when i feel like reimplementing caller() */
/*
    my $filename = $opts{filename};
    my $first_line_num = $opts{first_line_num};

    (undef, $filename, $first_line_num) = caller
        if not defined $filename;

    my $last_line_num = $opts{last_line_num} || ($first_line_num ||= 0);

    # http://perldoc.perl.org/perldebguts.html#Debugger-Internals
    $DB::sub{$pkg . '::' . $name} = "$filename:$first_line_num-$last_line_num";
*/
/*
    if (items > 2 && (PL_perldb & 0x10) && variable.type == VAR_CODE) {
        int i;
        char *filename = NULL, *name;
        I32 first_line_num, last_line_num;

        if ((items - 3) % 2)
            croak("add_package_symbol: Odd number of elements in %%opts");

        for (i = 3; i < items; i += 2) {
            char *key;
            key = SvPV_nolen(ST(i));
            if (strEQ(key, "filename")) {
                if (!SvPOK(ST(i + 1)))
                    croak("add_package_symbol: filename must be a string");
                filename = SvPV_nolen(ST(i + 1));
            }
            else if (strEQ(key, "first_line_num")) {
                if (!SvIOK(ST(i + 1)))
                    croak("add_package_symbol: first_line_num must be an integer");
                first_line_num = SvIV(ST(i + 1));
            }
            else if (strEQ(key, "last_line_num")) {
                if (!SvIOK(ST(i + 1)))
                    croak("add_package_symbol: last_line_num must be an integer");
                last_line_num = SvIV(ST(i + 1));
            }
        }

        if (!filename) {
        }
    }
*/

    glob = gv_fetchsv(name, GV_ADD, vartype_to_svtype(variable.type));

    if (initial) {
        SV *val;

        if (SvROK(initial)) {
            val = SvRV(initial);
            SvREFCNT_inc(val);
        }
        else {
            val = newSVsv(initial);
        }

        switch (variable.type) {
        case VAR_SCALAR:
            GvSV(glob) = val;
            break;
        case VAR_ARRAY:
            GvAV(glob) = (AV*)val;
            break;
        case VAR_HASH:
            GvHV(glob) = (HV*)val;
            break;
        case VAR_CODE:
            GvCV(glob) = (CV*)val;
            break;
        case VAR_IO:
            GvIOp(glob) = (IO*)val;
            break;
        }
    }

void
remove_package_glob(self, name)
    SV *self
    char *name
  CODE:
    hv_delete(_get_namespace(self), name, strlen(name), G_DISCARD);

int
has_package_symbol(self, variable)
    SV *self
    varspec_t variable
  PREINIT:
    HV *namespace;
    SV **entry;
  CODE:
    namespace = _get_namespace(self);
    entry = hv_fetch(namespace, variable.name, strlen(variable.name), 0);
    if (!entry)
        XSRETURN_UNDEF;

    if (isGV(*entry)) {
        GV *glob = (GV*)(*entry);
        switch (variable.type) {
        case VAR_SCALAR:
            RETVAL = GvSV(glob) ? 1 : 0;
            break;
        case VAR_ARRAY:
            RETVAL = GvAV(glob) ? 1 : 0;
            break;
        case VAR_HASH:
            RETVAL = GvHV(glob) ? 1 : 0;
            break;
        case VAR_CODE:
            RETVAL = GvCV(glob) ? 1 : 0;
            break;
        case VAR_IO:
            RETVAL = GvIO(glob) ? 1 : 0;
            break;
        }
    }
    else {
        RETVAL = (variable.type == VAR_CODE);
    }
  OUTPUT:
    RETVAL

void
remove_package_symbol(self, variable)
    SV *self
    varspec_t variable
  PREINIT:
    HV *namespace;
    SV **entry;
  CODE:
    namespace = _get_namespace(self);
    entry = hv_fetch(namespace, variable.name, strlen(variable.name), 0);
    if (!entry)
        XSRETURN_EMPTY;

    if (isGV(*entry)) {
        GV *glob = (GV*)(*entry);
        switch (variable.type) {
        case VAR_SCALAR:
            GvSV(glob) = Nullsv;
            break;
        case VAR_ARRAY:
            GvAV(glob) = Nullav;
            break;
        case VAR_HASH:
            GvHV(glob) = Nullhv;
            break;
        case VAR_CODE:
            GvCV(glob) = Nullcv;
            break;
        case VAR_IO:
            GvIOp(glob) = Null(IO*);
            break;
        }
    }
    else {
        if (variable.type == VAR_CODE) {
            hv_delete(namespace, variable.name, strlen(variable.name), G_DISCARD);
        }
    }

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

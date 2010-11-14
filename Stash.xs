#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define NEED_newRV_noinc
#define NEED_sv_2pv_flags
#include "ppport.h"

#ifndef gv_fetchsv
#define gv_fetchsv(n,f,t) gv_fetchpv(SvPV_nolen(n), f, t)
#endif

#ifndef mro_method_changed_in
#define mro_method_changed_in(x) PL_sub_generation++
#endif

#ifdef newSVhek
#define newSVhe(he) newSVhek(HeKEY_hek(he))
#else
#define newSVhe(he) newSVpv(HePV(he, PL_na), 0)
#endif

#ifndef savesvpv
#define savesvpv(s) savepv(SvPV_nolen(s))
#endif

/* HACK: scalar slots are always populated on perl < 5.10, so treat undef
 * as nonexistent. this is consistent with the previous behavior of the pure
 * perl version of this module (since this is the behavior that perl sees
 * in all versions */
#if PERL_VERSION < 10
#define GvSVOK(g) (GvSV(g) && SvTYPE(GvSV(g)) != SVt_NULL)
#else
#define GvSVOK(g) GvSV(g)
#endif

#define GvAVOK(g) GvAV(g)
#define GvHVOK(g) GvHV(g)
#define GvCVOK(g) GvCVu(g) /* XXX: should this really be GvCVu? or GvCV? */
#define GvIOOK(g) GvIO(g)

/* see above - don't let scalar slots become unpopulated, this breaks
 * assumptions in core */
#if PERL_VERSION < 10
#define GvSetSV(g,v) do {               \
    SV *_v = (SV*)(v);                  \
    SvREFCNT_dec(GvSV(g));              \
    if ((GvSV(g) = _v ? _v : newSV(0))) \
        GvIMPORTED_SV_on(g);            \
} while (0)
#else
#define GvSetSV(g,v) do {               \
    SvREFCNT_dec(GvSV(g));              \
    if ((GvSV(g) = (SV*)(v)))           \
        GvIMPORTED_SV_on(g);            \
} while (0)
#endif

#define GvSetAV(g,v) do {               \
    SvREFCNT_dec(GvAV(g));              \
    if ((GvAV(g) = (AV*)(v)))           \
        GvIMPORTED_AV_on(g);            \
} while (0)
#define GvSetHV(g,v) do {               \
    SvREFCNT_dec(GvHV(g));              \
    if ((GvHV(g) = (HV*)(v)))           \
        GvIMPORTED_HV_on(g);            \
} while (0)
#define GvSetCV(g,v) do {               \
    SvREFCNT_dec(GvCV(g));              \
    if ((GvCV(g) = (CV*)(v))) {         \
        GvIMPORTED_CV_on(g);            \
        GvASSUMECV_on(g);               \
    }                                   \
    GvCVGEN(g) = 0;                     \
    mro_method_changed_in(GvSTASH(g));  \
} while (0)
#define GvSetIO(g,v) do {               \
    SvREFCNT_dec(GvIO(g));              \
    GvIOp(g) = (IO*)(v);                \
} while (0)

/* XXX: the core implementation of caller() is private, so we need a
 * a reimplementation. luckily, padwalker already has done this. rafl says
 * that there should be a public interface in 5.14, so maybe look into
 * converting to use that at some point */
#include "stolen_bits_of_padwalker.c"

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
    char *name;
} varspec_t;

static U32 name_hash, namespace_hash, type_hash;
static SV *name_key, *namespace_key, *type_key;

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
        varspec->name = &variable[1];
    }
    else {
        varspec->type = VAR_IO;
        varspec->name = variable;
    }
}

void _deconstruct_variable_hash(HV *variable, varspec_t *varspec)
{
    HE *val;
    char *valpv;
    STRLEN len;

    val = hv_fetch_ent(variable, name_key, 0, name_hash);
    if (!val)
        croak("The 'name' key is required in variable specs");

    valpv = HePV(val, len);
    varspec->name = savepvn(valpv, len);
    SAVEFREEPV(varspec->name);

    val = hv_fetch_ent(variable, type_key, 0, type_hash);
    if (!val)
        croak("The 'type' key is required in variable specs");

    valpv = HePV(val, len);
    varspec->type = string_to_vartype(valpv);
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

SV *_get_symbol(SV *self, varspec_t *variable, int vivify)
{
    HV *namespace;
    SV **entry;
    GV *glob;

    namespace = _get_namespace(self);
    entry = hv_fetch(namespace, variable->name, strlen(variable->name), vivify);
    if (!entry)
        return NULL;

    glob = (GV*)(*entry);
    if (!isGV(glob)) {
        SV *namesv;

        namesv = newSVsv(_get_name(self));
        sv_catpvs(namesv, "::");
        sv_catpv(namesv, variable->name);

        /* can't use gv_init here, because it screws up @ISA in a way that I
         * can't reproduce, but that CMOP triggers */
        gv_fetchsv(namesv, GV_ADD, vartype_to_svtype(variable->type));
        SvREFCNT_dec(namesv);
    }

    if (vivify) {
        switch (variable->type) {
        case VAR_SCALAR:
            if (!GvSVOK(glob))
                GvSetSV(glob, newSV(0));
            break;
        case VAR_ARRAY:
            if (!GvAVOK(glob))
                GvSetAV(glob, newAV());
            break;
        case VAR_HASH:
            if (!GvHVOK(glob))
                GvSetHV(glob, newHV());
            break;
        case VAR_CODE:
            croak("Don't know how to vivify CODE variables");
        case VAR_IO:
            if (!GvIOOK(glob))
                GvSetIO(glob, newIO());
            break;
        default:
            croak("Unknown type in vivication");
        }
    }

    switch (variable->type) {
    case VAR_SCALAR:
        return GvSV(glob);
    case VAR_ARRAY:
        return (SV*)GvAV(glob);
    case VAR_HASH:
        return (SV*)GvHV(glob);
    case VAR_CODE:
        return (SV*)GvCV(glob);
    case VAR_IO:
        return (SV*)GvIO(glob);
    default:
        return NULL;
    }
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
    SV *nsref;
  CODE:
    if (!SvPOK(package_name))
        croak("The constructor argument must be the name of a package");

    instance = newHV();

    if (!hv_store(instance, "name", 4, SvREFCNT_inc_simple_NN(package_name), 0)) {
        SvREFCNT_dec(package_name);
        SvREFCNT_dec(instance);
        croak("Couldn't initialize the 'name' key, hv_store failed");
    }
    namespace = gv_stashpv(SvPV_nolen(package_name), GV_ADD);
    nsref = newRV_inc((SV*)namespace);
    if (!hv_store(instance, "namespace", 9, nsref, 0)) {
        SvREFCNT_dec(nsref);
        SvREFCNT_dec(instance);
        croak("Couldn't initialize the 'namespace' key, hv_store failed");
    }

    RETVAL = sv_bless(newRV_noinc((SV*)instance), gv_stashpv(class, 0));
  OUTPUT:
    RETVAL

SV*
name(self)
    SV *self
  PREINIT:
    HE *slot;
  CODE:
    if (!sv_isobject(self))
        croak("Can't call name as a class method");
    slot = hv_fetch_ent((HV*)SvRV(self), name_key, 0, name_hash);
    RETVAL = slot ? SvREFCNT_inc_simple_NN(HeVAL(slot)) : &PL_sv_undef;
  OUTPUT:
    RETVAL

SV*
namespace(self)
    SV *self
  PREINIT:
    HE *slot;
  CODE:
    if (!sv_isobject(self))
        croak("Can't call namespace as a class method");
    slot = hv_fetch_ent((HV*)SvRV(self), namespace_key, 0, namespace_hash);
    RETVAL = slot ? SvREFCNT_inc_simple_NN(HeVAL(slot)) : &PL_sv_undef;
  OUTPUT:
    RETVAL

void
add_symbol(self, variable, initial=NULL, ...)
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

    if (items > 2 && (PL_perldb & 0x10) && variable.type == VAR_CODE) {
        int i;
        char *filename = NULL, *namepv;
        I32 first_line_num = -1, last_line_num = -1;
        STRLEN namelen;
        SV *dbval;
        HV *dbsub;

        if ((items - 3) % 2)
            croak("add_symbol: Odd number of elements in %%opts");

        for (i = 3; i < items; i += 2) {
            char *key;
            key = SvPV_nolen(ST(i));
            if (strEQ(key, "filename")) {
                if (!SvPOK(ST(i + 1)))
                    croak("add_symbol: filename must be a string");
                filename = SvPV_nolen(ST(i + 1));
            }
            else if (strEQ(key, "first_line_num")) {
                if (!SvIOK(ST(i + 1)))
                    croak("add_symbol: first_line_num must be an integer");
                first_line_num = SvIV(ST(i + 1));
            }
            else if (strEQ(key, "last_line_num")) {
                if (!SvIOK(ST(i + 1)))
                    croak("add_symbol: last_line_num must be an integer");
                last_line_num = SvIV(ST(i + 1));
            }
        }

        if (!filename || first_line_num == -1) {
            I32 cxix_from, cxix_to;
            PERL_CONTEXT *cx, *ccstack;
            COP *cop = NULL;

            cx = upcontext(0, &cop, &ccstack, &cxix_from, &cxix_to);
            if (!cop)
                cop = PL_curcop;

            if (!filename)
                filename = CopFILE(cop);
            if (first_line_num == -1)
                first_line_num = cop->cop_line;
        }

        if (last_line_num == -1)
            last_line_num = first_line_num;

        /* http://perldoc.perl.org/perldebguts.html#Debugger-Internals */
        dbsub = get_hv("DB::sub", 1);
        dbval = newSVpvf("%s:%d-%d", filename, first_line_num, last_line_num);
        namepv = SvPV(name, namelen);
        if (!hv_store(dbsub, namepv, namelen, dbval, 0)) {
            warn("Failed to update $DB::sub for subroutine %s", namepv);
            SvREFCNT_dec(dbval);
        }
    }

    /* GV_ADDMULTI rather than GV_ADD because otherwise you get 'used only
     * once' warnings in some situations... i can't reproduce this, but CMOP
     * triggers it */
    glob = gv_fetchsv(name, GV_ADDMULTI, vartype_to_svtype(variable.type));

    if (initial) {
        SV *val;

        if (SvROK(initial)) {
            val = SvRV(initial);
            SvREFCNT_inc_simple_void_NN(val);
        }
        else {
            val = newSVsv(initial);
        }

        switch (variable.type) {
        case VAR_SCALAR:
            GvSetSV(glob, val);
            break;
        case VAR_ARRAY:
            GvSetAV(glob, val);
            break;
        case VAR_HASH:
            GvSetHV(glob, val);
            break;
        case VAR_CODE:
            GvSetCV(glob, val);
            break;
        case VAR_IO:
            GvSetIO(glob, val);
            break;
        }
    }

    SvREFCNT_dec(name);

void
remove_glob(self, name)
    SV *self
    char *name
  CODE:
    hv_delete(_get_namespace(self), name, strlen(name), G_DISCARD);

int
has_symbol(self, variable)
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
            RETVAL = GvSVOK(glob) ? 1 : 0;
            break;
        case VAR_ARRAY:
            RETVAL = GvAVOK(glob) ? 1 : 0;
            break;
        case VAR_HASH:
            RETVAL = GvHVOK(glob) ? 1 : 0;
            break;
        case VAR_CODE:
            RETVAL = GvCVOK(glob) ? 1 : 0;
            break;
        case VAR_IO:
            RETVAL = GvIOOK(glob) ? 1 : 0;
            break;
        }
    }
    else {
        RETVAL = (variable.type == VAR_CODE);
    }
  OUTPUT:
    RETVAL

SV*
get_symbol(self, variable)
    SV *self
    varspec_t variable
  PREINIT:
    SV *val;
  CODE:
    val = _get_symbol(self, &variable, 0);
    if (!val)
        XSRETURN_UNDEF;
    RETVAL = newRV_inc(val);
  OUTPUT:
    RETVAL

SV*
get_or_add_symbol(self, variable)
    SV *self
    varspec_t variable
  PREINIT:
    SV *val;
  CODE:
    val = _get_symbol(self, &variable, 1);
    if (!val)
        XSRETURN_UNDEF;
    RETVAL = newRV_inc(val);
  OUTPUT:
    RETVAL

void
remove_symbol(self, variable)
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
            GvSetSV(glob, NULL);
            break;
        case VAR_ARRAY:
            GvSetAV(glob, NULL);
            break;
        case VAR_HASH:
            GvSetHV(glob, NULL);
            break;
        case VAR_CODE:
            GvSetCV(glob, NULL);
            break;
        case VAR_IO:
            GvSetIO(glob, NULL);
            break;
        }
    }
    else {
        if (variable.type == VAR_CODE) {
            hv_delete(namespace, variable.name, strlen(variable.name), G_DISCARD);
        }
    }

void
list_all_symbols(self, vartype=VAR_NONE)
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
        while ((entry = hv_iternext(namespace))) {
            mPUSHs(newSVhe(entry));
        }
    }
    else {
        HV *namespace;
        SV *val;
        char *key;
        int len;

        namespace = _get_namespace(self);
        hv_iterinit(namespace);
        while ((val = hv_iternextsv(namespace, &key, &len))) {
            GV *gv = (GV*)val;
            if (isGV(gv)) {
                switch (vartype) {
                case VAR_SCALAR:
                    if (GvSVOK(val))
                        mXPUSHp(key, len);
                    break;
                case VAR_ARRAY:
                    if (GvAVOK(val))
                        mXPUSHp(key, len);
                    break;
                case VAR_HASH:
                    if (GvHVOK(val))
                        mXPUSHp(key, len);
                    break;
                case VAR_CODE:
                    if (GvCVOK(val))
                        mXPUSHp(key, len);
                    break;
                case VAR_IO:
                    if (GvIOOK(val))
                        mXPUSHp(key, len);
                    break;
                }
            }
            else if (vartype == VAR_CODE) {
                mXPUSHp(key, len);
            }
        }
    }

BOOT:
    {
        name_key = newSVpvs("name");
        PERL_HASH(name_hash, "name", 4);

        namespace_key = newSVpvs("namespace");
        PERL_HASH(namespace_hash, "namespace", 9);

        type_key = newSVpvs("type");
        PERL_HASH(type_hash, "type", 4);
    }

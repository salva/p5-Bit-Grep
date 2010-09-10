/* -*- Mode: C -*- */

#define PERL_NO_GET_CONTEXT 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

typedef void (*iterate_cb)(pTHX_ UV ix, SV *ele, void *ptr);

static void
iterate(pTHX_ SV *vec, SV **eles, UV size, iterate_cb cb, void *ptr) {
    STRLEN bits_len;
    const char *bits = SvPV_const(vec, bits_len);
    UV bits_size = bits_len * 8;
    UV i = 0;
    if (size > bits_size) size = bits_size;
    while (i < size) {
        char byte = *(bits++);
        if (byte) {
            int j;
            for (j = 0; j < 8; j++) {
                if (i == size) return;
                if ((byte >> j) & 1) (*cb)(aTHX_ i, eles[i], ptr);
                i++;
            }
        }
        else i += 8;
    }
}

static void
bg_sum_cb(pTHX_ UV ix, SV *ele, void *nv) {
    *(NV*)nv += SvNV(ele);
}

struct bg_stats_state {
    UV count;
    NV sum;
    NV sum2;
};

static void
bg_count_and_sum_cb(pTHX_ UV ix, SV *ele, void *state) {
    ((struct bg_stats_state*)state)->count++;
    ((struct bg_stats_state*)state)->sum += SvNV(ele);
}

static void
bg_count_sum_and_sum2_cb(pTHX_ UV ix, SV *ele, void *state) {
    NV nv = SvNV(ele);
    ((struct bg_stats_state*)state)->count++;
    ((struct bg_stats_state*)state)->sum += nv;
    ((struct bg_stats_state*)state)->sum2 += nv * nv;
}

static void
bg_grep_cb(pTHX_ UV ix, SV *ele, void *state) {
    SV **to = (*(SV***)state)++;
    *to = ele;
}


MODULE = Bit::Grep		PACKAGE = Bit::Grep		
PROTOTYPES: DISABLE

void
bg_grep(vec, ...)
    SV *vec;
PREINIT:
    SV **to;
PPCODE:
    to = &(ST(0));
    iterate(aTHX_ vec, &(ST(1)), items - 1, &bg_grep_cb, &to);
    XSRETURN(to - &(ST(0)));
  
NV
bg_sum(vec, ...)
    SV *vec;
CODE:
    RETVAL = 0;
    iterate(aTHX_ vec, &(ST(1)), items - 1, &bg_sum_cb, &RETVAL);
OUTPUT:
    RETVAL

void
bg_count_and_sum(vec, ...)
    SV *vec;
PREINIT:
    struct bg_stats_state state;
PPCODE:
    state.count = 0;
    state.sum   = 0;
    iterate(aTHX_ vec, &(ST(1)), items - 1, &bg_count_and_sum_cb, &state);
    mXPUSHi(state.count);
    mXPUSHn(state.sum);
    XSRETURN(2);

void
bg_count_sum_and_sum2(vec, ...)
    SV *vec;
PREINIT:
    struct bg_stats_state state;
PPCODE:
    state.count = 0;
    state.sum   = 0;
    state.sum2  = 0;
    iterate(aTHX_ vec, &(ST(1)), items - 1, &bg_count_sum_and_sum2_cb, &state);
    mXPUSHi(state.count);
    mXPUSHn(state.sum);
    mXPUSHn(state.sum2);
    XSRETURN(3);

SV *
bg_avg(vec, ...)
    SV *vec;
PREINIT:
    struct bg_stats_state state;
CODE:
    state.count = 0;
    state.sum = 0;
    iterate(aTHX_ vec, &(ST(1)), items -1, &bg_count_and_sum_cb, &state);
    RETVAL = (state.count ? newSVnv(state.sum/state.count) : &PL_sv_undef);
OUTPUT:
    RETVAL

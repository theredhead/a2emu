/* Compile the upstream unit unchanged; snapshot access stays local to this project. */
#include "../../../Vendor/gsplus/gsplus/src/voc.c"
#include "../SnapshotCore.h"

A2_FIELDS(voc,
    A2_FIELD(g_voc_enable),
    A2_FIELD(g_voc_reg1),
    A2_FIELD(g_voc_reg3),
    A2_FIELD(g_voc_reg4),
    A2_FIELD(g_voc_reg5),
    A2_FIELD(g_voc_reg6),
    A2_FIELD(g_voc_last_pal_vbl)
)

/* Compile the upstream unit unchanged; snapshot access stays local to this project. */
#include "../../../Vendor/gsplus/gsplus/src/doc.c"
#include "../SnapshotCore.h"

A2_FIELDS(doc,
    A2_FIELD(doc_ram),
    A2_FIELD(g_doc_sound_ctl),
    A2_FIELD(g_doc_saved_val),
    A2_FIELD(g_doc_num_osc_en),
    A2_FIELD(g_drecip_osc_en_plus_2),
    A2_FIELD(g_doc_vol),
    A2_FIELD(g_doc_saved_ctl),
    A2_FIELD(g_num_osc_interrupting),
    A2_FIELD(g_doc_regs),
    A2_FIELD(doc_reg_e0)
)

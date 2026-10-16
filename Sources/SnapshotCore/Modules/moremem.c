/* Compile the upstream unit unchanged; snapshot access stays local to this project. */
#include "../../../Vendor/gsplus/gsplus/src/moremem.c"
#include "../SnapshotCore.h"

A2_FIELDS(moremem,
    A2_FIELD(g_num_shadow_all_banks),
    A2_FIELD(g_em_emubyte_cnt),
    A2_FIELD(g_paddle_buttons),
    A2_FIELD(g_irq_pending),
    A2_FIELD(g_c023_val),
    A2_FIELD(g_c029_val_some),
    A2_FIELD(g_c02b_val),
    A2_FIELD(g_c02d_int_crom),
    A2_FIELD(g_c033_data),
    A2_FIELD(g_c034_val),
    A2_FIELD(g_c035_shadow_reg),
    A2_FIELD(g_c036_val_speed),
    A2_FIELD(g_c03ef_doc_ptr),
    A2_FIELD(g_c041_val),
    A2_FIELD(g_c046_val),
    A2_FIELD(g_c05x_annuncs),
    A2_FIELD(g_c068_statereg),
    A2_FIELD(g_c06d_val),
    A2_FIELD(g_c06f_val),
    A2_FIELD(g_zipgs_unlock),
    A2_FIELD(g_zipgs_reg_c059),
    A2_FIELD(g_zipgs_reg_c05a),
    A2_FIELD(g_zipgs_reg_c05b),
    A2_FIELD(g_zipgs_reg_c05c),
    A2_FIELD(g_c06c_latched_cyc),
    A2_FIELD(g_slinky_addr),
    A2_FIELD(g_slinky_ram)
)

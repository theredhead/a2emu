/* Compile the upstream unit unchanged; snapshot access stays local to this project. */
#include "../../../Vendor/gsplus/gsplus/src/iwm.c"
#include "../SnapshotCore.h"

extern int g_highest_smartport_unit;

A2_FIELDS(iwm,
    A2_FIELD(g_highest_smartport_unit),
    A2_FIELD(g_fast_disk_emul_en),
    A2_FIELD(g_fast_disk_emul),
    A2_FIELD(g_slow_525_emul_wr),
    A2_FIELD(g_dfcyc_end_emul_wr),
    A2_FIELD(g_fast_disk_unnib),
    A2_FIELD(g_iwm_fake_fast),
    A2_FIELD(g_iwm_motor_on),
    A2_FIELD(g_iwm_dynapro_last_vbl_count),
    A2_FIELD(g_iwm_last_phase_dfcyc),
    A2_FIELD(g_cnt_enable2_handshake),
    A2_FIELD(g_iwm.dfcyc_last_fastemul_read),
    A2_FIELD(g_iwm.state),
    A2_FIELD(g_iwm.motor_off_vbl_count),
    A2_FIELD(g_iwm.forced_sync_bit),
    A2_FIELD(g_iwm.last_rd_bit),
    A2_FIELD(g_iwm.write_val),
    A2_FIELD(g_iwm.wr_last_bit),
    A2_FIELD(g_iwm.wr_qtr_track),
    A2_FIELD(g_iwm.wr_num_bits),
    A2_FIELD(g_iwm.wr_prior_num_bits),
    A2_FIELD(g_iwm.wr_delta),
    A2_FIELD(g_iwm.num_active_writes)
)

/* Compile the upstream unit unchanged; snapshot access stays local to this project. */
#include "../../../Vendor/gsplus/gsplus/src/scc.c"
#include "../SnapshotCore.h"

A2_FIELDS(scc,
    A2_FIELD(g_scc_overflow),
    A2_FIELD(g_scc[0].dcd),
    A2_FIELD(g_scc[0].reg_ptr),
    A2_FIELD(g_scc[0].br_is_zero),
    A2_FIELD(g_scc[0].tx_buf_empty),
    A2_FIELD(g_scc[0].mode),
    A2_FIELD(g_scc[0].reg),
    A2_FIELD(g_scc[0].rx_queue_depth),
    A2_FIELD(g_scc[0].rx_queue),
    A2_FIELD(g_scc[0].in_rdptr),
    A2_FIELD(g_scc[0].in_wrptr),
    A2_FIELD(g_scc[0].in_buf),
    A2_FIELD(g_scc[0].out_rdptr),
    A2_FIELD(g_scc[0].out_wrptr),
    A2_FIELD(g_scc[0].out_buf),
    A2_FIELD(g_scc[0].wantint_rx),
    A2_FIELD(g_scc[0].wantint_tx),
    A2_FIELD(g_scc[0].wantint_zerocnt),
    A2_FIELD(g_scc[0].br_dcycs),
    A2_FIELD(g_scc[0].tx_dcycs),
    A2_FIELD(g_scc[0].rx_dcycs),
    A2_FIELD(g_scc[0].br_event_pending),
    A2_FIELD(g_scc[0].rx_event_pending),
    A2_FIELD(g_scc[0].tx_event_pending),
    A2_FIELD(g_scc[0].char_size),
    A2_FIELD(g_scc[0].baud_rate),
    A2_FIELD(g_scc[0].out_char_dfcyc),
    A2_FIELD(g_scc[1].dcd),
    A2_FIELD(g_scc[1].reg_ptr),
    A2_FIELD(g_scc[1].br_is_zero),
    A2_FIELD(g_scc[1].tx_buf_empty),
    A2_FIELD(g_scc[1].mode),
    A2_FIELD(g_scc[1].reg),
    A2_FIELD(g_scc[1].rx_queue_depth),
    A2_FIELD(g_scc[1].rx_queue),
    A2_FIELD(g_scc[1].in_rdptr),
    A2_FIELD(g_scc[1].in_wrptr),
    A2_FIELD(g_scc[1].in_buf),
    A2_FIELD(g_scc[1].out_rdptr),
    A2_FIELD(g_scc[1].out_wrptr),
    A2_FIELD(g_scc[1].out_buf),
    A2_FIELD(g_scc[1].wantint_rx),
    A2_FIELD(g_scc[1].wantint_tx),
    A2_FIELD(g_scc[1].wantint_zerocnt),
    A2_FIELD(g_scc[1].br_dcycs),
    A2_FIELD(g_scc[1].tx_dcycs),
    A2_FIELD(g_scc[1].rx_dcycs),
    A2_FIELD(g_scc[1].br_event_pending),
    A2_FIELD(g_scc[1].rx_event_pending),
    A2_FIELD(g_scc[1].tx_event_pending),
    A2_FIELD(g_scc[1].char_size),
    A2_FIELD(g_scc[1].baud_rate),
    A2_FIELD(g_scc[1].out_char_dfcyc)
)

int a2_snapshot_serial_idle(void) {
    for (int i = 0; i < 2; i++) {
        if (g_scc[i].sockfd >= 0 || g_scc[i].rdwrfd >= 0 || g_scc[i].unix_dev_fd >= 0) return 0;
    }
    return 1;
}

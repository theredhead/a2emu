/* Compile the upstream unit unchanged; snapshot access stays local to this project. */
#include "../../../Vendor/gsplus/gsplus/src/clock.c"
#include "../SnapshotCore.h"

A2_FIELDS(clock,
    A2_FIELD(g_clk_mode),
    A2_FIELD(g_clk_read),
    A2_FIELD(g_clk_reg1),
    A2_FIELD(g_bram),
    A2_FIELD(g_clk_cur_time),
    A2_FIELD(g_clk_next_vbl_update)
)

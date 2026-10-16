/* Compile the upstream unit unchanged; snapshot access stays local to this project. */
#include "../../../Vendor/gsplus/gsplus/src/paddles.c"
#include "../SnapshotCore.h"

A2_FIELDS(paddles,
    A2_FIELD(g_paddle_trig_dfcyc),
    A2_FIELD(g_paddle_val),
    A2_FIELD(g_paddle_dfcyc)
)

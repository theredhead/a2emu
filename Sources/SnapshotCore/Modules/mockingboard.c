/* Compile the upstream unit unchanged; snapshot access stays local to this project. */
#include "../../../Vendor/gsplus/gsplus/src/mockingboard.c"
#include "../SnapshotCore.h"

A2_FIELDS(mockingboard,
    A2_FIELD(g_mockingboard_last_int_dusec),
    A2_FIELD(g_mockingboard_event_int_dusec),
    A2_FIELD(g_mock_channel_regs)
)

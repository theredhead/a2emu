/* Compile the upstream unit unchanged; snapshot access stays local to this project. */
#include "../../../Vendor/gsplus/gsplus/src/sound.c"
#include "../SnapshotCore.h"

A2_FIELDS(sound,
    A2_FIELD(g_mockingboard),
    A2_FIELD(g_mock_env_vol),
    A2_FIELD(g_mock_noise_bytes),
    A2_FIELD(g_mock_volume),
    A2_FIELD(g_last_mock_vbl_count),
    A2_FIELD(g_last_sound_play_dsamp),
    A2_FIELD(g_c030_fsamps),
    A2_FIELD(g_num_c030_fsamps),
    A2_FIELD(g_c030_state),
    A2_FIELD(g_c030_val),
    A2_FIELD(g_c030_dsamp_last_toggle),
    A2_FIELD(g_doc_dsamps_extra)
)

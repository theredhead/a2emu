#include <AudioToolbox/AudioToolbox.h>

static AudioUnit snapshot_audio_unit;
static OSStatus snapshot_audio_start(AudioUnit unit) {
    snapshot_audio_unit = unit;
    return AudioOutputUnitStart(unit);
}
/* Retain the unit so a restore can discard samples from the previous timeline safely. */
#define AudioOutputUnitStart snapshot_audio_start
#include "../../Vendor/gsplus/gsplus/src/macsnd_driver.c"
#undef AudioOutputUnitStart

extern int g_sound_shm_pos, g_childsnd_pos, g_childsnd_vbl;
extern int g_zeroes_buffered, g_zeroes_seen, g_sound_paused;

void a2_snapshot_reset_audio(void) {
    if (snapshot_audio_unit) AudioOutputUnitStop(snapshot_audio_unit);
    g_macsnd_rd_pos = 0;
    g_macsnd_wr_pos = 0;
    g_macsnd_playing = 0;
    memset(g_macsnd_rebuf, 0, sizeof(g_macsnd_rebuf));
    if (g_sound_shm_addr) memset(g_sound_shm_addr, 0, SOUND_SHM_SAMP_SIZE * SAMPLE_CHAN_SIZE);
    g_sound_shm_pos = 0;
    g_childsnd_pos = 0;
    g_childsnd_vbl = 0;
    g_zeroes_buffered = 0;
    g_zeroes_seen = 0;
    g_sound_paused = 0;
    if (snapshot_audio_unit) AudioOutputUnitStart(snapshot_audio_unit);
}

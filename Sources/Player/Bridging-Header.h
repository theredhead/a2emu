#include "Kegs-Bridging-Header.h"
extern int g_zip_speed_mhz;
extern int g_limit_speed;
extern int g_joystick_type;
#include "HIDGamepad.h"

// Host-side pause/resume resets wall-clock pacing without advancing emulated cycles.
extern double g_dtime_last_vbl;
extern double g_dtime_expected;
extern double g_dtime_end_16ms;

#include "../SnapshotCore/SnapshotCore.h"

void a2_snapshot_reset_audio(void);

// Fresh boot for standalone games; retains mounted disks and configured speed.
void a2_restart_emulation(void);

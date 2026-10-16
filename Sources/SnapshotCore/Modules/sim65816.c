/* Compile the upstream unit unchanged; snapshot access stays local to this project. */
#include "../../../Vendor/gsplus/gsplus/src/sim65816.c"
#include "../SnapshotCore.h"

A2_FIELDS(sim65816,
    A2_FIELD(g_dcycles_end),
    A2_FIELD(g_emul_6502_ind_page_cross_bug),
    A2_FIELD(g_last_vbl_dfcyc),
    A2_FIELD(g_cur_dfcyc),
    A2_FIELD(g_last_vbl_dadjcycs),
    A2_FIELD(g_dadjcycs),
    A2_FIELD(g_wait_pending),
    A2_FIELD(g_stp_pending),
    A2_FIELD(g_io_amt),
    A2_FIELD(g_engine_action),
    A2_FIELD(g_engine_recalc_event),
    A2_FIELD(g_engine_scan_int),
    A2_FIELD(g_engine_doc_int),
    A2_FIELD(g_25sec_cntr),
    A2_FIELD(g_1sec_cntr),
    A2_FIELD(g_dfcyc_scan_int),
    A2_FIELD(g_vbl_count),
    A2_FIELD(g_limit_speed),
    A2_FIELD(g_zip_speed_mhz),
    A2_FIELD(g_video_pixel_dcount),
    A2_FIELD(g_scan_int_events),
    A2_FIELD(engine.dfcyc),
    A2_FIELD(engine.kpc),
    A2_FIELD(engine.acc),
    A2_FIELD(engine.xreg),
    A2_FIELD(engine.yreg),
    A2_FIELD(engine.stack),
    A2_FIELD(engine.dbank),
    A2_FIELD(engine.direct),
    A2_FIELD(engine.psr)
)

/* Encode event links as indices rather than process addresses. */
int a2_snapshot_events(uint64_t times[66], int types[66], int links[66], int restore) {
    Event *events[66];
    for (int i = 0; i < 64; i++) events[i] = &g_event_list[i];
    events[64] = &g_event_start;
    events[65] = &g_event_free;
    for (int i = 0; i < 66; i++) {
        if (restore) {
            if (links[i] < -1 || links[i] >= 64) return 0;
            events[i]->dfcyc = times[i];
            events[i]->type = types[i];
            events[i]->next = links[i] < 0 ? NULL : events[links[i]];
        } else {
            times[i] = events[i]->dfcyc;
            types[i] = events[i]->type;
            links[i] = -1;
            if (events[i]->next) {
                int found = 0;
                for (int j = 0; j < 64; j++) {
                    if (events[i]->next == events[j]) { links[i] = j; found = 1; break; }
                }
                if (!found) return 0;
            }
        }
    }
    return 1;
}
void a2_snapshot_rebuild_engine(void) {
    setup_zip_speeds();
    engine.fplus_ptr = &g_recip_projected_pmhz_fast;
    g_halt_sim = 0;
    g_a2_fatal_err = 0;
    g_dtime_last_vbl = get_dtime();
    g_dtime_expected = g_dtime_last_vbl;
    g_dtime_end_16ms = g_dtime_last_vbl;
}

#include "../../Vendor/gsplus/gsplus/src/defc.h"
#include "../../Vendor/gsplus/gsplus/src/sound.h"

extern byte *g_memory_ptr, *g_slow_memory_ptr;
extern byte doc_ram[], g_slinky_ram[];
extern int g_queued_samps, g_queued_nonsamps;
extern word32 g_mem_size_total, g_c03ef_doc_ptr, g_doc_saved_val, g_c036_val_speed;
extern dword64 g_cur_dfcyc;
extern int g_rom_version;
void a2_snapshot_reset_audio(void);

/* A standalone game's Reset means a fresh boot. A warm reset retains software
 * initialization flags while stopping the DOC, leaving some music drivers silent.
 * Keep BRAM, mounted disk contents, the emulated clock, and speed settings intact. */
void a2_restart_emulation(void) {
    /* Stop peripherals and remove their sound events before discarding register state. */
    do_reset();
    memset(g_memory_ptr, 0, g_mem_size_total);
    memset(g_slow_memory_ptr, 0, 0x20000);
    memset(doc_ram, 0, 0x10000 + 16);
    memset(g_slinky_ram, 0, 0x100000);
    doc_init();
    doc_write_c03c(g_cur_dfcyc, 8);
    g_doc_saved_val = 0;
    g_c03ef_doc_ptr = 0;
    if (g_rom_version >= 3) g_c036_val_speed |= 0x40;
    /* Read the reset vector with the fresh memory and ROM03 power-on flag in place. */
    do_reset();
    g_queued_samps = 0;
    g_queued_nonsamps = 0;
    a2_snapshot_reset_audio();
}

/* Exercise the real macOS ring buffer and render callback without an audio device. */
#include "../../Sources/SnapshotCore/MacSnapshotAudio.c"
extern int g_audio_enable;
void a2_audio_test_enable(void) {
    if (!g_sound_shm_addr) g_sound_shm_addr = calloc(SOUND_SHM_SAMP_SIZE, SAMPLE_CHAN_SIZE);
    g_audio_enable = 1;
}
unsigned long long a2_audio_test_render(int frames) {
    word32 samples[2048] = {0};
    AudioBufferList buffers = {0};
    buffers.mNumberBuffers = 1;
    buffers.mBuffers[0].mNumberChannels = 2;
    buffers.mBuffers[0].mDataByteSize = frames * 4;
    buffers.mBuffers[0].mData = samples;
    audio_callback(NULL, NULL, NULL, 0, frames, &buffers);
    unsigned long long nonzero = 0;
    for (int i = 0; i < frames; i++) if (samples[i] != 0) nonzero++;
    return nonzero;
}
extern Doc_reg g_doc_regs[32];
extern int g_doc_vol, g_doc_num_osc_en;
extern word32 g_doc_sound_ctl;
void a2_audio_test_report(void) {
    int running = 0;
    for (int i = 0; i < 32; i++) if (g_doc_regs[i].running) running++;
    printf("DOC enabled=%d running=%d volume=%d control=%02x\n", g_doc_num_osc_en, running, g_doc_vol, g_doc_sound_ctl);
    fflush(stdout);
}

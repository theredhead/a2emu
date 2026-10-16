#include "../../Vendor/gsplus/gsplus/src/defc.h"
#include "SnapshotCore.h"
#include <stdint.h>
#include <stddef.h>

#ifndef A2_SNAPSHOT_BUILD_ID
#define A2_SNAPSHOT_BUILD_ID "development"
#endif
#define LIMIT (64u * 1024u * 1024u)
#define MODULES(X) X(sim65816) X(moremem) X(adb) X(clock) X(paddles) X(doc) X(sound) X(mockingboard) X(scc) X(iwm) X(video) X(voc)
#define DECLARE(name) extern A2SnapshotField *a2_snapshot_fields_##name(size_t *);
MODULES(DECLARE)
extern int a2_snapshot_events(uint64_t *, int *, int *, int);
extern void a2_snapshot_rebuild_engine(void);
extern int a2_snapshot_serial_idle(void);
extern byte *g_memory_ptr, *g_slow_memory_ptr, *g_rom_fc_ff_ptr;
extern word32 g_mem_size_total;
extern int g_rom_version, g_audio_rate;
extern Iwm g_iwm;
extern word32 g_full_refresh_needed;
extern int g_config_control_panel;

static char error_message[256];
const char *a2_snapshot_error(void) { return error_message; }
static int fail(const char *message) {
    snprintf(error_message, sizeof(error_message), "%s", message);
    return 0;
}

typedef struct {
    byte *bytes;
    size_t length, position;
    int mode, ok; /* 0 validate, 1 save, 2 apply, 3 validate mounted disk layout */
} Stream;

static uint32_t checksum(const byte *bytes, size_t size) {
    uint32_t crc = ~0u;
    for (size_t i = 0; i < size; i++) {
        crc ^= bytes[i];
        for (int bit = 0; bit < 8; bit++) crc = (crc >> 1) ^ (0xedb88320u & (0u - (crc & 1u)));
    }
    return ~crc;
}
static void transfer(Stream *s, void *data, size_t size, int local) {
    if (size == 0) return;
    if (!s->ok || size > s->length - s->position) { s->ok = 0; fail("Snapshot state exceeds its size limit."); return; }
    if (s->mode == 1) memcpy(s->bytes + s->position, data, size);
    else if (s->mode == 2 || local) memcpy(data, s->bytes + s->position, size);
    s->position += size;
}
static void field(Stream *s, const char *name, void *data, size_t size) {
    uint32_t tag = checksum((const byte *)name, strlen(name)), saved_tag = tag;
    uint32_t count = (uint32_t)size, saved_count = count;
    transfer(s, &saved_tag, sizeof(saved_tag), 1);
    transfer(s, &saved_count, sizeof(saved_count), 1);
    if (saved_tag != tag || saved_count != count) { s->ok = 0; return; }
    transfer(s, data, size, 0);
}
static void module(Stream *s, A2SnapshotField *fields, size_t count) {
    for (size_t i = 0; i < count; i++) field(s, fields[i].name, fields[i].data, fields[i].size);
}
static Disk *disk_at(int index) {
    if (index < 2) return &g_iwm.drive35[index];
    if (index < 4) return &g_iwm.drive525[index - 2];
    return &g_iwm.smartport[index - 4];
}
const char *a2_snapshot_disk_path(int slot, int drive) {
    if (slot < 5 || slot > 7 || drive < 0 || drive >= (slot == 7 ? 16 : 2)) return NULL;
    Disk *disk = iwm_get_dsk_from_slot_drive(slot, drive);
    return disk->fd < 0 ? NULL : disk->name_ptr;
}
int a2_snapshot_flush_disks(void) {
    if (!a2_snapshot_serial_idle()) return fail("Disconnect serial and network devices before taking a snapshot.");
    for (int i = 0; i < 20; i++) {
        Disk *disk = disk_at(i);
        if (disk->fd < 0) continue;
        if (disk->dynapro_info_ptr || disk->raw_data || disk->partition_name)
            return fail("Snapshots currently require ordinary disk image files, without host folders or partitions.");
        iwm_flush_disk_to_unix(disk);
        if (disk->wozinfo_ptr && disk->wozinfo_ptr->reparse_needed)
            return fail("The disk is still being rewritten. Pause at an idle point and try again.");
    }
    return 1;
}
void a2_snapshot_eject_disks(void) {
    g_iwm.state = 0;
    for (int i = 0; i < 20; i++) iwm_eject_disk(disk_at(i));
}

typedef struct {
    uint64_t last_read, last_phases, image_start, image_size;
    uint32_t frac_track, fbit_pos, fbit_mult, track_bits;
    int32_t mounted, num_tracks, current_track, image_type, write_prot, write_through;
    int32_t dirty, ejected, phases, volume;
} DiskState;
static void disks(Stream *s) {
    for (int i = 0; i < 20 && s->ok; i++) {
        Disk *d = disk_at(i);
        DiskState state = {0};
        if (s->mode == 1) {
            state.image_start = d->dimage_start;
            state.image_size = d->dimage_size;
            state.last_read = d->dfcyc_last_read;
            state.last_phases = d->dfcyc_last_phases;
            state.frac_track = d->cur_frac_track;
            state.fbit_pos = d->cur_fbit_pos;
            state.fbit_mult = d->fbit_mult;
            state.track_bits = d->cur_track_bits;
            state.mounted = d->fd >= 0;
            state.num_tracks = d->num_tracks;
            state.current_track = d->cur_trk_ptr ? (int32_t)(d->cur_trk_ptr - d->trks) : -1;
            state.image_type = d->image_type;
            state.write_prot = d->write_prot;
            state.write_through = d->write_through_to_unix;
            state.dirty = d->disk_dirty;
            state.ejected = d->just_ejected;
            state.phases = d->last_phases;
            state.volume = d->vol_num;
        }
        transfer(s, &state, sizeof(state), 1);
        if (state.num_tracks < 0 || state.num_tracks > MAX_TRACKS || state.current_track < -1 ||
            (state.current_track >= MAX_TRACKS) || (i >= 4 && state.current_track != -1) || (state.mounted != 0 && state.mounted != 1)) { s->ok = 0; fail("A disk has an invalid track position."); return; }
        if (s->mode == 3 && (state.mounted != (d->fd >= 0) ||
            (state.mounted && (state.num_tracks != d->num_tracks || state.image_type != d->image_type ||
                state.image_start != d->dimage_start || state.image_size != d->dimage_size)))) { s->ok = 0; return; }
        if (s->mode == 2) {
            d->image_type = state.image_type;
            d->dimage_start = state.image_start;
            d->dimage_size = state.image_size;
            d->dfcyc_last_read = state.last_read;
            d->dfcyc_last_phases = state.last_phases;
            d->cur_frac_track = state.frac_track;
            d->cur_fbit_pos = state.fbit_pos;
            d->fbit_mult = state.fbit_mult;
            d->cur_track_bits = state.track_bits;
            d->write_prot = state.write_prot;
            d->write_through_to_unix = state.write_through;
            d->disk_dirty = state.dirty;
            d->just_ejected = state.ejected;
            d->last_phases = state.phases;
            d->vol_num = state.volume;
            d->cur_trk_ptr = state.current_track < 0 ? NULL : &d->trks[state.current_track];
        }
        for (int j = 0; j < state.num_tracks && s->ok; j++) {
            Trk *track = (s->mode == 1 || s->mode == 2 || s->mode == 3) ? &d->trks[j] : NULL;
            uint32_t bits = s->mode == 1 ? track->track_bits : 0;
            uint32_t dirty = s->mode == 1 ? track->dirty : 0;
            transfer(s, &bits, sizeof(bits), 1);
            transfer(s, &dirty, sizeof(dirty), 1);
            if (bits > 1024 * 1024) { s->ok = 0; return; }
            size_t size = (bits + 7) / 8;
            if (s->mode == 3 && (track->track_bits != bits || (size && (!track->raw_bptr || !track->sync_ptr)))) { s->ok = 0; return; }
            transfer(s, track ? track->raw_bptr : NULL, size, 0);
            transfer(s, track ? track->sync_ptr : NULL, size, 0);
            if (s->mode == 2) track->dirty = (word16)dirty;
        }
    }
}

static void machine(Stream *s) {
    size_t count;
#define VISIT(name) { A2SnapshotField *fields = a2_snapshot_fields_##name(&count); module(s, fields, count); }
    MODULES(VISIT)
#undef VISIT
    field(s, "main RAM", g_memory_ptr, g_mem_size_total);
    field(s, "slow RAM", g_slow_memory_ptr, 0x20000);
    uint64_t times[66] = {0};
    int types[66] = {0}, links[66] = {0};
    if (s->mode == 1 && !a2_snapshot_events(times, types, links, 0)) { s->ok = 0; fail("A pending event has an invalid link."); return; }
    transfer(s, times, sizeof(times), 1);
    transfer(s, types, sizeof(types), 1);
    transfer(s, links, sizeof(links), 1);
    int used[64] = {0};
    for (int i = 0; i < 66; i++) {
        if (links[i] < -1 || links[i] >= 64) { s->ok = 0; return; }
    }
    for (int head = 64; head < 66; head++) {
        for (int next = links[head]; next >= 0; next = links[next]) {
            if (used[next]) { s->ok = 0; fail("The pending-event lists overlap or contain a cycle."); return; }
            used[next] = 1;
        }
    }
    if (s->mode == 2 && !a2_snapshot_events(times, types, links, 1)) { s->ok = 0; return; }
    disks(s);
}

typedef struct {
    char magic[8];
    char build[65];
    uint32_t ram, rom, audio_rate, payload_size, crc;
} Header;
static int process(const char *path, int save, int restore) {
    error_message[0] = 0;
    if (g_config_control_panel) return fail("Close the emulator control panel before saving or restoring a snapshot.");
    if (!g_memory_ptr || !g_slow_memory_ptr || !g_rom_fc_ff_ptr) return fail("The emulator is not ready for snapshots.");
    if (!a2_snapshot_serial_idle()) return fail("Snapshots cannot restore active serial or network connections.");
    Header header = {0};
    memcpy(header.magic, "A2STATE1", 8);
    snprintf(header.build, sizeof(header.build), "%s", A2_SNAPSHOT_BUILD_ID);
    header.ram = g_mem_size_total;
    header.rom = checksum(g_rom_fc_ff_ptr, 0x40000);
    header.audio_rate = (uint32_t)g_audio_rate;
    byte *buffer = malloc(LIMIT);
    if (!buffer) return fail("Not enough memory for a snapshot.");
    int result = 0;
    if (save) {
        Stream stream = {buffer, LIMIT, 0, 1, 1};
        machine(&stream);
        if (!stream.ok) { if (!error_message[0]) fail("The current machine or disk state cannot be captured."); goto done; }
        header.payload_size = (uint32_t)stream.position;
        header.crc = checksum(buffer, stream.position);
        FILE *file = fopen(path, "wb");
        if (!file) { fail("Could not create the snapshot state file."); goto done; }
        int written = fwrite(&header, 1, sizeof(header), file) == sizeof(header) &&
            fwrite(buffer, 1, stream.position, file) == stream.position;
        int closed = fclose(file);
        result = written && closed == 0;
        if (!result) { remove(path); fail("Could not finish writing the snapshot."); }
    } else {
        FILE *file = fopen(path, "rb");
        if (!file) { fail("Could not open the snapshot state file."); goto done; }
        Header saved;
        int valid = fread(&saved, 1, sizeof(saved), file) == sizeof(saved);
        if (!valid || memcmp(saved.magic, header.magic, 8) || memcmp(saved.build, header.build, 65) ||
            saved.ram != header.ram || saved.rom != header.rom || saved.audio_rate != header.audio_rate || saved.payload_size > LIMIT) {
            fclose(file); fail("This snapshot requires the same emulator build, ROM, RAM size, and audio rate."); goto done;
        }
        valid = fread(buffer, 1, saved.payload_size, file) == saved.payload_size && fgetc(file) == EOF;
        fclose(file);
        if (!valid || checksum(buffer, saved.payload_size) != saved.crc) { fail("The snapshot is incomplete or damaged."); goto done; }
        Stream stream = {buffer, saved.payload_size, 0, restore ? 3 : 0, 1};
        machine(&stream);
        if (!stream.ok || stream.position != stream.length) { fail("The snapshot state or mounted disk layout is incompatible."); goto done; }
        if (restore) {
            stream.position = 0;
            stream.mode = 2;
            machine(&stream);
            setup_pageinfo();
            a2_snapshot_rebuild_engine();
            g_full_refresh_needed = -1;
        }
        result = 1;
    }
done:
    free(buffer);
    return result;
}
int a2_snapshot_save(const char *path) { return process(path, 1, 0); }
int a2_snapshot_validate(const char *path) { return process(path, 0, 0); }
int a2_snapshot_restore(const char *path) { return process(path, 0, 1); }

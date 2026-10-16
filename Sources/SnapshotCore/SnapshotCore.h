#ifndef A2_SNAPSHOT_CORE_H
#define A2_SNAPSHOT_CORE_H
#include <stddef.h>
#include <stdint.h>
/* Called on the emulation thread, between run_16ms calls. No host pointers are persisted. */
int a2_snapshot_save(const char *path);
int a2_snapshot_validate(const char *path);
int a2_snapshot_restore(const char *path);
const char *a2_snapshot_error(void);
const char *a2_snapshot_disk_path(int slot, int drive);
int a2_snapshot_flush_disks(void);
void a2_snapshot_eject_disks(void);

typedef struct {
    const char *name;
    void *data;
    size_t size;
} A2SnapshotField;
#define A2_FIELD(value) { #value, &(value), sizeof(value) }
#define A2_FIELDS(module, ...) \
    A2SnapshotField *a2_snapshot_fields_##module(size_t *count) { \
        static A2SnapshotField fields[] = { __VA_ARGS__ }; \
        *count = sizeof(fields) / sizeof(fields[0]); \
        return fields; \
    }
#endif

// Exercise the real inventory and removal logic without opening a hardware device.
#include "../../Sources/Player/HIDGamepad.c"
#include <assert.h>
#include <stdio.h>

static Gamepad *fixture(const char *name, float x) {
    Gamepad *pad = calloc(1, sizeof(Gamepad));
    assert(pad);
    // Removal only compares and releases this reference; no IOHID APIs use the fixture object.
    pad->device = (IOHIDDeviceRef)CFDictionaryCreate(NULL, NULL, NULL, 0, NULL, NULL);
    pad->identifier = nextIdentifier++;
    strcpy(pad->product, name);
    pad->values[0] = x;
    return pad;
}

int main(void) {
    unsigned extendedUsages[15];
    for (unsigned i = 0; i < 15; i++) extendedUsages[i] = i + 1;
    Gamepad mapping = {0};
    configureButtons(&mapping, extendedUsages, 15, 0x045e);
    assert(mapping.buttonUsages[2] == 4 && mapping.buttonUsages[3] == 5);
    assert(mapping.buttonUsages[4] == 7 && mapping.buttonUsages[5] == 8);
    assert(mapping.buttonUsages[8] == 12 && mapping.buttonUsages[9] == 11);
    unsigned compactUsages[12];
    for (unsigned i = 0; i < 12; i++) compactUsages[i] = i + 1;
    configureButtons(&mapping, compactUsages, 12, 0x045e);
    assert(mapping.buttonUsages[2] == 3 && mapping.buttonUsages[8] == 8 && mapping.buttonUsages[9] == 7);
    puts("PASS Xbox compact/extended HID descriptors preserve reserved button positions and menu inputs");
    Gamepad *first = fixture("Same model", -1);
    Gamepad *second = fixture("Same model", 1);
    Gamepad *third = fixture("Third pad", 0.5);
    devices = first;
    first->next = second;
    second->next = third;
    uint64_t secondID = second->identifier;
    assert(a2_hid_gamepad_count() == 3);
    assert(a2_hid_gamepad_id(0) != a2_hid_gamepad_id(1));
    assert(a2_hid_gamepad_select(secondID));
    assert(a2_hid_gamepad_value(0) == 1);
    removed(NULL, 0, NULL, first->device);
    assert(a2_hid_gamepad_count() == 2 && a2_hid_gamepad_id(0) == secondID);
    assert(a2_hid_gamepad_connected() && a2_hid_gamepad_value(0) == 1);
    removed(NULL, 0, NULL, second->device);
    assert(!a2_hid_gamepad_connected() && a2_hid_gamepad_value(0) == 0);
    assert(!a2_hid_gamepad_select(secondID));
    assert(a2_hid_gamepad_select(third->identifier));
    assert(a2_hid_gamepad_value(0) == 0.5);
    assert(a2_hid_gamepad_id(-1) == 0 && a2_hid_gamepad_id(10) == 0);
    removed(NULL, 0, NULL, third->device);
    assert(a2_hid_gamepad_count() == 0 && !a2_hid_gamepad_connected());
    puts("PASS actual HID inventory, identical devices, selection, and removal");
    return 0;
}

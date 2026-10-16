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

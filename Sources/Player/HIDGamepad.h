#ifndef A2_HID_GAMEPAD_H
#define A2_HID_GAMEPAD_H
#include <stdint.h>
void a2_hid_gamepad_init(void);
int a2_hid_gamepad_connected(void);
const char *a2_hid_gamepad_name(void);
float a2_hid_gamepad_value(int index);
// Enumerate every matching device, including identical models, by connection ID.
int a2_hid_gamepad_count(void);
uint64_t a2_hid_gamepad_id(int index);
const char *a2_hid_gamepad_name_at(int index);
// A missing ID deselects input instead of silently choosing a different device.
int a2_hid_gamepad_select(uint64_t identifier);
#endif

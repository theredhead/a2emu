#ifndef A2_HID_GAMEPAD_H
#define A2_HID_GAMEPAD_H
void a2_hid_gamepad_init(void);
int a2_hid_gamepad_connected(void);
const char *a2_hid_gamepad_name(void);
float a2_hid_gamepad_value(int index);
#endif

#include <stdint.h>
static int count = 2;
static uint64_t selected;
static int lastX;
void fixture_set_hid_count(int value) { count = value; }
int fixture_last_x(void) { return lastX; }
void a2_hid_gamepad_init(void) {}
int a2_hid_gamepad_count(void) { return count; }
uint64_t a2_hid_gamepad_id(int index) { return index >= 0 && index < count ? 100 + index : 0; }
const char *a2_hid_gamepad_name_at(int index) { return "Direct Test Pad"; }
const char *a2_hid_gamepad_name(void) { return "Direct Test Pad"; }
int a2_hid_gamepad_connected(void) { return selected >= 100 && selected < 100 + count; }
int a2_hid_gamepad_select(uint64_t identifier) {
    selected = identifier;
    return a2_hid_gamepad_connected();
}
float a2_hid_gamepad_value(int index) { return index == 0 ? (selected == 100 ? -1 : 1) : 0; }
void joystick_callback_init(int type) {}
void joystick_callback_update(unsigned buttons, int x, int y) { lastX = x; }
void joystick_update_buttons(void) {}

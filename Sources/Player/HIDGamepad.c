// Direct HID input, including fallback for devices absent from GameController.
// Match only Generic Desktop joystick/gamepad devices, never keyboards or mice.
#include "HIDGamepad.h"
#include <IOKit/hid/IOHIDManager.h>
#include <IOKit/hid/IOHIDUsageTables.h>
#include <string.h>
#include <stdlib.h>
static IOHIDManagerRef manager;
// Device IDs are stable for a connection and are never reused within this process.
typedef struct Gamepad {
    IOHIDDeviceRef device;
    uint64_t identifier;
    char product[256];
    unsigned buttonUsages[6];
    int rightUsesZRz;
    float values[14]; // left XY, right XY, D-pad XY, A/B/X/Y/LB/RB/LT/RT
    struct Gamepad *next;
} Gamepad;

static Gamepad *devices;
static Gamepad *current;
static uint64_t nextIdentifier = 1;

static Gamepad *deviceAtIndex(int index) {
    if (index < 0) return NULL;
    Gamepad *device = devices;
    while (device && index-- > 0) device = device->next;
    return device;
}

static float normalize(IOHIDElementRef element, CFIndex value, int trigger) {
    CFIndex low = IOHIDElementGetLogicalMin(element), high = IOHIDElementGetLogicalMax(element);
    if (high <= low) return 0;
    float result = (float)(value - low) / (float)(high - low);
    if (result < 0) result = 0;
    if (result > 1) result = 1;
    return trigger ? result : result * 2 - 1;
}
static void input(void *context, IOReturn result, void *sender, IOHIDValueRef value) {
    (void)context; (void)sender;
    if (result != kIOReturnSuccess) return;
    IOHIDElementRef element = IOHIDValueGetElement(value);
    IOHIDDeviceRef source = IOHIDElementGetDevice(element);
    Gamepad *pad = devices;
    while (pad && pad->device != source) pad = pad->next;
    if (!pad) return;
    uint32_t page = IOHIDElementGetUsagePage(element), usage = IOHIDElementGetUsage(element);
    CFIndex raw = IOHIDValueGetIntegerValue(value);
    if (page == kHIDPage_Button) {
        for (int i = 0; i < 6; i++) if (pad->buttonUsages[i] == usage) pad->values[6 + i] = raw != 0;
    } else if (page == kHIDPage_GenericDesktop) {
        switch (usage) {
        case kHIDUsage_GD_X: pad->values[0] = normalize(element, raw, 0); break;
        case kHIDUsage_GD_Y: pad->values[1] = -normalize(element, raw, 0); break;
        case kHIDUsage_GD_Rx: pad->values[2] = normalize(element, raw, 0); break;
        case kHIDUsage_GD_Ry: pad->values[3] = -normalize(element, raw, 0); break;
        case kHIDUsage_GD_Z: pad->values[pad->rightUsesZRz ? 2 : 12] = normalize(element, raw, !pad->rightUsesZRz); break;
        case kHIDUsage_GD_Rz: pad->values[pad->rightUsesZRz ? 3 : 13] = normalize(element, raw, !pad->rightUsesZRz) * (pad->rightUsesZRz ? -1 : 1); break;
        case kHIDUsage_GD_Hatswitch: {
            int hat = (int)(raw - IOHIDElementGetLogicalMin(element));
            static const int x[8] = {0,1,1,1,0,-1,-1,-1};
            static const int y[8] = {1,1,0,-1,-1,-1,0,1};
            pad->values[4] = (hat >= 0 && hat < 8) ? x[hat] : 0;
            pad->values[5] = (hat >= 0 && hat < 8) ? y[hat] : 0;
            break;
        }
        }
    } else if (page == kHIDPage_Simulation) {
        if (usage == kHIDUsage_Sim_Accelerator) pad->values[13] = normalize(element, raw, 1);
        if (usage == kHIDUsage_Sim_Brake) pad->values[12] = normalize(element, raw, 1);
    }
}
static void added(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    (void)context; (void)sender;
    if (result != kIOReturnSuccess) return;
    for (Gamepad *existing = devices; existing; existing = existing->next) {
        if (existing->device == device) return;
    }
    Gamepad *pad = calloc(1, sizeof(Gamepad));
    if (!pad) return;
    pad->device = (IOHIDDeviceRef)CFRetain(device);
    pad->identifier = nextIdentifier++;
    Gamepad **tail = &devices;
    while (*tail) tail = &(*tail)->next;
    *tail = pad;
    if (!current) current = pad;
    unsigned foundButtons[32] = {0};
    int count = 0, hasRx = 0, hasRy = 0;
    CFArrayRef elements = IOHIDDeviceCopyMatchingElements(device, NULL, 0);
    if (elements) {
        for (CFIndex i = 0; i < CFArrayGetCount(elements); i++) {
            IOHIDElementRef element = (IOHIDElementRef)CFArrayGetValueAtIndex(elements, i);
            unsigned page = IOHIDElementGetUsagePage(element), usage = IOHIDElementGetUsage(element);
            if (page == kHIDPage_GenericDesktop && usage == kHIDUsage_GD_Rx) hasRx = 1;
            if (page == kHIDPage_GenericDesktop && usage == kHIDUsage_GD_Ry) hasRy = 1;
            if (page == kHIDPage_Button && IOHIDElementGetType(element) == kIOHIDElementTypeInput_Button && count < 32) foundButtons[count++] = usage;
        }
        CFRelease(elements);
    }
    // Xbox Bluetooth reports can have gaps in their button usage numbers.
    for (int i = 0; i < count; i++) for (int j = i + 1; j < count; j++) {
        if (foundButtons[j] < foundButtons[i]) { unsigned t = foundButtons[i]; foundButtons[i] = foundButtons[j]; foundButtons[j] = t; }
    }
    for (int i = 0; i < count && i < 6; i++) pad->buttonUsages[i] = foundButtons[i];
    pad->rightUsesZRz = !hasRx && !hasRy;
    CFTypeRef name = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    strcpy(pad->product, "HID game controller");
    if (name && CFGetTypeID(name) == CFStringGetTypeID()) CFStringGetCString(name, pad->product, sizeof(pad->product), kCFStringEncodingUTF8);
}
static void removed(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    (void)context; (void)result; (void)sender;
    Gamepad **entry = &devices;
    while (*entry) {
        Gamepad *pad = *entry;
        if (pad->device == device) {
            *entry = pad->next;
            if (current == pad) current = NULL;
            CFRelease(pad->device);
            free(pad);
            return;
        }
        entry = &pad->next;
    }
}
void a2_hid_gamepad_init(void) {
    if (manager) return;
    manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!manager) return;
    const void *keys[] = { CFSTR(kIOHIDDeviceUsagePageKey), CFSTR(kIOHIDDeviceUsageKey) };
    int page = kHIDPage_GenericDesktop;
    CFNumberRef pageNumber = CFNumberCreate(NULL, kCFNumberIntType, &page);
    CFMutableArrayRef matches = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
    for (int usage = kHIDUsage_GD_Joystick; usage <= kHIDUsage_GD_GamePad; usage++) {
        CFNumberRef usageNumber = CFNumberCreate(NULL, kCFNumberIntType, &usage);
        const void *vals[] = { pageNumber, usageNumber };
        CFDictionaryRef match = CFDictionaryCreate(NULL, keys, vals, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFArrayAppendValue(matches, match); CFRelease(match); CFRelease(usageNumber);
    }
    IOHIDManagerSetDeviceMatchingMultiple(manager, matches);
    CFRelease(matches); CFRelease(pageNumber);
    IOHIDManagerRegisterDeviceMatchingCallback(manager, added, NULL);
    IOHIDManagerRegisterDeviceRemovalCallback(manager, removed, NULL);
    IOHIDManagerRegisterInputValueCallback(manager, input, NULL);
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    IOHIDManagerOpen(manager, kIOHIDOptionsTypeNone);
}
int a2_hid_gamepad_connected(void) { return current != NULL; }
const char *a2_hid_gamepad_name(void) { return current ? current->product : ""; }
float a2_hid_gamepad_value(int index) {
    return current && index >= 0 && index < 14 ? current->values[index] : 0;
}
int a2_hid_gamepad_count(void) {
    int count = 0;
    for (Gamepad *pad = devices; pad; pad = pad->next) count++;
    return count;
}
uint64_t a2_hid_gamepad_id(int index) {
    Gamepad *pad = deviceAtIndex(index);
    return pad ? pad->identifier : 0;
}
const char *a2_hid_gamepad_name_at(int index) {
    Gamepad *pad = deviceAtIndex(index);
    return pad ? pad->product : "";
}
int a2_hid_gamepad_select(uint64_t identifier) {
    current = NULL;
    for (Gamepad *pad = devices; pad; pad = pad->next) {
        if (pad->identifier == identifier) {
            current = pad;
            return 1;
        }
    }
    return 0;
}

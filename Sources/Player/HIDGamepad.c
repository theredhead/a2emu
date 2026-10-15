// Fallback for controllers that macOS exposes as HID but not GameController.
// Match only Generic Desktop joystick/gamepad devices, never keyboards or mice.
#include "HIDGamepad.h"
#include <IOKit/hid/IOHIDManager.h>
#include <IOKit/hid/IOHIDUsageTables.h>
#include <string.h>
static IOHIDManagerRef manager;
static IOHIDDeviceRef current;
static char product[256];
static unsigned buttonUsages[6];
static int rightUsesZRz;
static float values[14]; // left XY, right XY, D-pad XY, A/B/X/Y/LB/RB/LT/RT

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
    if (result != kIOReturnSuccess || !current) return;
    IOHIDElementRef element = IOHIDValueGetElement(value);
    if (IOHIDElementGetDevice(element) != current) return;
    uint32_t page = IOHIDElementGetUsagePage(element), usage = IOHIDElementGetUsage(element);
    CFIndex raw = IOHIDValueGetIntegerValue(value);
    if (page == kHIDPage_Button) {
        for (int i = 0; i < 6; i++) if (buttonUsages[i] == usage) values[6 + i] = raw != 0;
    } else if (page == kHIDPage_GenericDesktop) {
        switch (usage) {
        case kHIDUsage_GD_X: values[0] = normalize(element, raw, 0); break;
        case kHIDUsage_GD_Y: values[1] = -normalize(element, raw, 0); break;
        case kHIDUsage_GD_Rx: values[2] = normalize(element, raw, 0); break;
        case kHIDUsage_GD_Ry: values[3] = -normalize(element, raw, 0); break;
        case kHIDUsage_GD_Z: values[rightUsesZRz ? 2 : 12] = normalize(element, raw, !rightUsesZRz); break;
        case kHIDUsage_GD_Rz: values[rightUsesZRz ? 3 : 13] = normalize(element, raw, !rightUsesZRz) * (rightUsesZRz ? -1 : 1); break;
        case kHIDUsage_GD_Hatswitch: {
            int hat = (int)(raw - IOHIDElementGetLogicalMin(element));
            static const int x[8] = {0,1,1,1,0,-1,-1,-1};
            static const int y[8] = {1,1,0,-1,-1,-1,0,1};
            values[4] = (hat >= 0 && hat < 8) ? x[hat] : 0;
            values[5] = (hat >= 0 && hat < 8) ? y[hat] : 0;
            break;
        }
        }
    } else if (page == kHIDPage_Simulation) {
        if (usage == kHIDUsage_Sim_Accelerator) values[13] = normalize(element, raw, 1);
        if (usage == kHIDUsage_Sim_Brake) values[12] = normalize(element, raw, 1);
    }
}
static void added(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    (void)context; (void)sender;
    if (result != kIOReturnSuccess || current) return;
    current = (IOHIDDeviceRef)CFRetain(device);
    memset(values, 0, sizeof(values));
    memset(buttonUsages, 0, sizeof(buttonUsages));
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
    for (int i = 0; i < count && i < 6; i++) buttonUsages[i] = foundButtons[i];
    rightUsesZRz = !hasRx && !hasRy;
    CFTypeRef name = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    strcpy(product, "HID game controller");
    if (name && CFGetTypeID(name) == CFStringGetTypeID()) CFStringGetCString(name, product, sizeof(product), kCFStringEncodingUTF8);
}
static void removed(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    (void)context; (void)result; (void)sender;
    if (device == current) { CFRelease(current); current = NULL; memset(values, 0, sizeof(values)); }
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
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    IOHIDManagerOpen(manager, kIOHIDOptionsTypeNone);
}
int a2_hid_gamepad_connected(void) { return current != NULL; }
const char *a2_hid_gamepad_name(void) { return product; }
float a2_hid_gamepad_value(int index) { return index >= 0 && index < 14 ? values[index] : 0; }

import Foundation

/// Access to the process-wide emulator. Call on the main thread, between emulation ticks.
enum EmulatorCore {
    /// Borrowed core storage; valid for the lifetime of the emulator, never freed by Swift.
    typealias Image = UnsafeMutablePointer<Kimage>
    typealias ChangeRect = Change_rect

    static let maximumChangeRects = MAX_CHANGE_RECTS
    static let defaultImageWidth = A2_WINDOW_WIDTH
    static let defaultImageHeight = A2_WINDOW_HEIGHT

    /// Reports core failures without exposing borrowed C strings to callers.
    private static func performSnapshot(_ operation: (UnsafePointer<CChar>?) -> Int32, at url: URL) throws {
        guard url.path.withCString({ operation($0) }) != 0 else {
            throw PlayerManifest.failure(snapshotError)
        }
    }

    static func emulatedImageWidth(_ image: Image?) -> Int32 {
        return video_get_a2_width(image)
    }

    static func emulatedImageHeight(_ image: Image?) -> Int32 {
        return video_get_a2_height(image)
    }

    static func updateModifiers(_ image: Image?, value: UInt32, mask: UInt32) {
        adb_update_c025_mask(image, value, mask)
    }

    /// Opens the existing debugger display without halting or advancing the emulated CPU.
    static func showDebugger() {
        let image = video_get_kimage(1)
        video_set_active(image, 1)
        debugger_redraw_screen(image)
    }

    static func restart() {
        a2_restart_emulation()
    }

    static func mountedDiskPath(slot: Int32, drive: Int32) -> String? {
        guard let path = a2_snapshot_disk_path(slot, drive) else { return nil }
        return String(cString: path)
    }

    static func ejectAllDisks() {
        a2_snapshot_eject_disks()
    }

    static var snapshotError: String {
        return String(cString: a2_snapshot_error())
    }

    static func flushDisks() throws {
        guard a2_snapshot_flush_disks() != 0 else {
            throw PlayerManifest.failure(snapshotError)
        }
    }

    static func resetAudio() {
        a2_snapshot_reset_audio()
    }

    static func restoreSnapshot(at url: URL) throws {
        try performSnapshot(a2_snapshot_restore, at: url)
    }

    static func saveSnapshot(at url: URL) throws {
        try performSnapshot(a2_snapshot_save, at: url)
    }

    static func validateSnapshot(at url: URL) throws {
        try performSnapshot(a2_snapshot_validate, at: url)
    }

    static func copyRequested() -> Int32 {
        return adb_get_copy_requested()
    }

    static func pointerVisibility(_ kimagePtr: Image?, warp warpptr: UnsafeMutablePointer<Int32>?) -> Int32 {
        return adb_get_hide_warp_info(kimagePtr, warpptr)
    }

    static func stopKeyRepeat() {
        adb_kbd_repeat_off()
    }

    static func setKeyboardFocus(_ hasFocus: Bool) {
        adb_mainwin_focus(hasFocus ? 1 : 0)
    }

    static func pasteCharacter(_ key: UInt32) -> Int32 {
        return adb_paste_add_buf(key)
    }

    static func updateKey(
        _ kimagePtr: Image?, keyCode rawA2code: Int32, unicode unicodeC: UInt32, isUp: Bool
    ) {
        adb_physical_key_update(kimagePtr, rawA2code, unicodeC, isUp ? 1 : 0)
    }

    static func updateMouse(
        _ kimagePtr: Image?, x: Int32, y: Int32, buttons buttonStates: Int32,
        validButtons buttonsValid: Int32
    ) -> Int32 {
        return adb_update_mouse(kimagePtr, x, y, buttonStates, buttonsValid)
    }

    static func setROMPath(_ url: URL) {
        url.path.withCString { cfg_file_update_rom($0) }
    }

    static func textScreen() -> String? {
        guard let text = cfg_text_screen_str() else { return nil }
        return String(cString: text)
    }

    static func setConfigurationPath(_ url: URL) {
        url.path.withCString { config_set_config_kegs_name($0) }
    }

    static func writeConfiguration() {
        _ = config_write_config_kegs_file(0)
    }

    static func mountDisk(at url: URL, in address: DriveAddress) {
        url.path.withCString {
            insert_disk(Int32(address.slot), Int32(address.drive), $0, 0, nil, -1, 0)
        }
    }

    static func ejectDisk(slot: Int32, drive: Int32) {
        iwm_eject_disk_by_num(slot, drive)
    }

    @discardableResult
    static func initialize(
        colorDepth mdepth: Int32, screenWidth: Int32, screenHeight: Int32,
        disableScaling noScaleWindow: Int32
    ) -> Int32 {
        return kegs_init(mdepth, screenWidth, screenHeight, noScaleWindow)
    }

    @discardableResult
    static func parseArguments(
        _ argc: Int32, arguments argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?,
        pathComponentsToStrip slashesToFind: Int32
    ) -> Int32 {
        return parse_argv(argc, argv, slashesToFind)
    }

    static func runFrame() -> Int32 {
        return run_16ms()
    }

    static func updateAcceleratorSpeeds() {
        setup_zip_speeds()
    }

    static func invalidateVideo() {
        video_force_reparse()
    }

    static func imageActivity(_ kimagePtr: Image?) -> Int32 {
        return video_get_active(kimagePtr)
    }

    static func image(_ winId: Int32) -> Image? {
        return video_get_kimage(winId)
    }

    static func imageHeight(_ kimagePtr: Image?) -> Int32 {
        return video_get_x_height(kimagePtr)
    }

    static func imageWidth(_ kimagePtr: Image?) -> Int32 {
        return video_get_x_width(kimagePtr)
    }

    static func windowX(_ kimagePtr: Image?) -> Int32 {
        return video_get_x_xpos(kimagePtr)
    }

    static func windowY(_ kimagePtr: Image?) -> Int32 {
        return video_get_x_ypos(kimagePtr)
    }

    static func drawImageChanges(
        into vptr: UnsafeMutableRawPointer?, image kimagePtr: Image?, pixelsPerRow outWidthAct: Int32,
        rect rectptr: UnsafeMutablePointer<ChangeRect>?, index pos: Int32
    ) -> Int32 {
        return video_out_data(vptr, kimagePtr, outWidthAct, rectptr, pos)
    }

    @discardableResult
    static func drawScaledImage(
        into vptr: UnsafeMutableRawPointer?, image kimagePtr: Image?, pixelsPerRow outWidthAct: Int32,
        rect rectptr: UnsafeMutablePointer<ChangeRect>?
    ) -> Int32 {
        return video_out_data_scaled(vptr, kimagePtr, outWidthAct, rectptr)
    }

    static func finishDrawing(_ kimagePtr: Image?) {
        video_out_done(kimagePtr)
    }

    static func imageChanges(_ kimagePtr: Image?) -> Int32 {
        return video_out_query(kimagePtr)
    }

    static func scaleMouseX(_ kimagePtr: Image?, x rawX: Int32, width xWidth: Int32) -> Int32 {
        return video_scale_mouse_x(kimagePtr, rawX, xWidth)
    }

    static func scaleMouseY(_ kimagePtr: Image?, y rawY: Int32, height yHeight: Int32) -> Int32 {
        return video_scale_mouse_y(kimagePtr, rawY, yHeight)
    }

    static func setImageActivity(_ kimagePtr: Image?, active: Int32) {
        video_set_active(kimagePtr, active)
    }

    static func setAlphaMask(_ alphaMask: UInt32) {
        video_set_alpha_mask(alphaMask)
    }

    static func setBlueMask(_ blueMask: UInt32) {
        video_set_blue_mask(blueMask)
    }

    static func setGreenMask(_ greenMask: UInt32) {
        video_set_green_mask(greenMask)
    }

    static func updatePalette() {
        video_set_palette()
    }

    static func setRedMask(_ redMask: UInt32) {
        video_set_red_mask(redMask)
    }

    static func unscaleMouseX(_ kimagePtr: Image?, x a2X: Int32, width xWidth: Int32) -> Int32 {
        return video_unscale_mouse_x(kimagePtr, a2X, xWidth)
    }

    static func unscaleMouseY(_ kimagePtr: Image?, y a2Y: Int32, height yHeight: Int32) -> Int32 {
        return video_unscale_mouse_y(kimagePtr, a2Y, yHeight)
    }

    static func updateImageScale(
        _ kimagePtr: Image?, width outWidth: Int32, height outHeight: Int32, force mustUpdate: Bool
    ) {
        video_update_scale(kimagePtr, outWidth, outHeight, mustUpdate ? 1 : 0)
    }

    static func updateWindowPosition(_ kimagePtr: Image?, x xXpos: Int32, y xYpos: Int32) {
        video_update_xpos_ypos(kimagePtr, xXpos, xYpos)
    }

    static var speedLimit: Int32 {
        get { return g_limit_speed }
        set { g_limit_speed = newValue }
    }

    static var acceleratorSpeedMHz: Int32 {
        get { return g_zip_speed_mhz }
        set { g_zip_speed_mhz = newValue }
    }

    static var joystickType: Int32 {
        get { return g_joystick_type }
        set { g_joystick_type = newValue }
    }

    static var expansionMemoryBytes: UInt32 {
        get { return g_mem_size_exp }
        set { g_mem_size_exp = newValue }
    }

    /// Discards elapsed host time when resuming; emulated cycles remain unchanged.
    static func resetFrameClock() {
        let now = get_dtime()
        g_dtime_last_vbl = now
        g_dtime_expected = now
        g_dtime_end_16ms = now
    }
}

cmake_minimum_required(VERSION 3.20)
if(NOT CMAKE_OSX_DEPLOYMENT_TARGET)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0" CACHE STRING "Minimum macOS version" FORCE)
endif()
project(A2EmuPlayer LANGUAGES C Swift)
# Keep builder and player versions in sync with the player bundle metadata.
execute_process(
    COMMAND /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${CMAKE_SOURCE_DIR}/Sources/Player/Info.plist"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    OUTPUT_VARIABLE A2EMU_VERSION OUTPUT_STRIP_TRAILING_WHITESPACE
    COMMAND_ERROR_IS_FATAL ANY)
add_custom_target(player-source
    COMMAND /bin/bash "${CMAKE_SOURCE_DIR}/scripts/bundle-source.sh"
        "${CMAKE_CURRENT_BINARY_DIR}/Player-Source.zip"
    VERBATIM)
if(NOT CMAKE_OSX_ARCHITECTURES)
    set(CMAKE_OSX_ARCHITECTURES "${CMAKE_SYSTEM_PROCESSOR}")
endif()
add_subdirectory(Vendor/gsplus/gsplus/src EXCLUDE_FROM_ALL)
# Snapshot adapters include upstream units without modifying the vendored checkout.
get_target_property(snapshot_core_sources gsplus_core SOURCES)
foreach(module sim65816 moremem adb clock paddles doc sound mockingboard scc iwm video voc)
    list(REMOVE_ITEM snapshot_core_sources "${module}.c")
    list(APPEND snapshot_core_sources "${CMAKE_SOURCE_DIR}/Sources/SnapshotCore/Modules/${module}.c")
endforeach()
list(APPEND snapshot_core_sources "${CMAKE_SOURCE_DIR}/Sources/SnapshotCore/SnapshotCore.c")
set_property(TARGET gsplus_core PROPERTY SOURCES "${snapshot_core_sources}")
# Pin on-disk machine state to the exact core and adapter sources, across both architectures.
file(GLOB snapshot_schema_files CONFIGURE_DEPENDS
    "${CMAKE_SOURCE_DIR}/Sources/SnapshotCore/*.c" "${CMAKE_SOURCE_DIR}/Sources/SnapshotCore/*.h"
    "${CMAKE_SOURCE_DIR}/Sources/SnapshotCore/Modules/*.c"
    "${CMAKE_SOURCE_DIR}/Vendor/gsplus/gsplus/src/*.c" "${CMAKE_SOURCE_DIR}/Vendor/gsplus/gsplus/src/*.h")
set(snapshot_schema "")
foreach(source IN LISTS snapshot_schema_files)
    file(SHA256 "${source}" source_hash)
    string(APPEND snapshot_schema "${source_hash}")
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${source}")
endforeach()
string(SHA256 snapshot_build_id "${snapshot_schema}")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/Snapshot-Core-ID.txt" "${snapshot_build_id}\n")
target_compile_definitions(gsplus_core PRIVATE A2_SNAPSHOT_BUILD_ID="${snapshot_build_id}")
# Standard .lproj resources are shared by the builder and exported player template.
file(GLOB intl_sources CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/Sources/Shared/Intl/*.swift")
file(GLOB_RECURSE localization_resources CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/Resources/Localizations/*")
# Give zero-initialized C globals explicit storage instead of tentative common
# symbols, whose size-based linker alignment can exceed Mach-O segment alignment.
target_compile_options(gsplus_core PRIVATE -fno-common)
# The legacy MAC joystick branch ignores SDL_INPUT. Compile just this source
# without MAC so it uses the no-device fallback, avoiding global HID access.
set_source_files_properties(Vendor/gsplus/gsplus/src/joystick_driver.c
    DIRECTORY "${CMAKE_SOURCE_DIR}/Vendor/gsplus/gsplus/src"
    PROPERTIES COMPILE_OPTIONS "-UMAC")
add_executable(a2emu-player MACOSX_BUNDLE
    ${intl_sources}
    Sources/Shared/PlayerManifest.swift
    Sources/Shared/DiskImageDevice.swift
    Sources/Shared/PlayerSnapshot.swift
    Sources/Player/EmulatorCore.swift
    Sources/Player/DiskDrops.swift
    Sources/Player/Snapshots.swift
    Sources/Player/SnapshotBrowser.swift
    Sources/Player/EmulatorReset.c
    Sources/Player/HIDGamepad.c
    Sources/Player/JoystickConfigurationView.swift
    Sources/Player/KeypadConfigurationView.swift
    Sources/Player/KeyboardConfigurationView.swift
    Sources/Player/ControllerMapping.swift
    Sources/Player/ControllerHardware.swift
    Sources/Player/GamepadInput.swift
    Sources/Shared/About.swift
    Sources/Player/PlayerMenu.swift
    Sources/Player/PlayerMenuLayout.swift
    Sources/Player/AppDelegate.swift
    Sources/Player/ROMSetup.swift
    Sources/Player/MainView.swift
    Sources/SnapshotCore/MacSnapshotAudio.c)
target_compile_options(a2emu-player PRIVATE
    "$<$<COMPILE_LANGUAGE:Swift>:-target;${CMAKE_OSX_ARCHITECTURES}-apple-macosx${CMAKE_OSX_DEPLOYMENT_TARGET}>"
    "$<$<COMPILE_LANGUAGE:Swift>:-import-objc-header;${CMAKE_SOURCE_DIR}/Sources/Player/Bridging-Header.h;-swift-version;4;-Xcc;-I${CMAKE_SOURCE_DIR}/Vendor/gsplus/gsplus/src>")
target_link_libraries(a2emu-player PRIVATE gsplus_core
    "-framework Cocoa" "-framework GameController" "-framework IOKit" "-framework AudioToolbox" "-framework CoreAudio" "-framework AudioUnit")
set_target_properties(a2emu-player PROPERTIES OUTPUT_NAME "Apple II Player"
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/Sources/Player/Info.plist")
set_property(TARGET a2emu-player APPEND PROPERTY LINK_DEPENDS
    ${localization_resources}
    "${CMAKE_SOURCE_DIR}/Assets/Player.icns"
    "${CMAKE_SOURCE_DIR}/Assets/PlayerIcon.png"
    "${CMAKE_SOURCE_DIR}/Assets/Snapshot.icns")
add_custom_command(TARGET a2emu-player POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_SOURCE_DIR}/Resources/Localizations" "$<TARGET_BUNDLE_DIR:a2emu-player>/Contents/Resources"
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_SOURCE_DIR}/Assets/Snapshot.icns" "$<TARGET_BUNDLE_DIR:a2emu-player>/Contents/Resources/Snapshot.icns"
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_BINARY_DIR}/Snapshot-Core-ID.txt" "$<TARGET_BUNDLE_DIR:a2emu-player>/Contents/Resources/Snapshot-Core-ID.txt"
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_SOURCE_DIR}/Assets/Player.icns" "$<TARGET_BUNDLE_DIR:a2emu-player>/Contents/Resources/Player.icns"
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_SOURCE_DIR}/Vendor/gsplus/LICENSE" "$<TARGET_BUNDLE_DIR:a2emu-player>/Contents/Resources/GSplus-LICENSE.txt"
    COMMAND ${CMAKE_COMMAND} -E rm -f "$<TARGET_FILE_DIR:a2emu-player>/main.d" "$<TARGET_FILE_DIR:a2emu-player>/Apple II Player.d"
    COMMAND ${CMAKE_COMMAND} -E rm -f "$<TARGET_BUNDLE_DIR:a2emu-player>/Contents/Resources/ROM.03" "$<TARGET_BUNDLE_DIR:a2emu-player>/Contents/Resources/ROM.01"
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_SOURCE_DIR}/Assets/PlayerIcon.png" "$<TARGET_BUNDLE_DIR:a2emu-player>/Contents/Resources/PlayerIcon.png"
    COMMAND ${CMAKE_COMMAND} -E rm -f "$<TARGET_BUNDLE_DIR:a2emu-player>/Contents/Resources/Player-Source.zip"
    COMMAND codesign --force --sign - "$<TARGET_BUNDLE_DIR:a2emu-player>")

add_executable(a2emu-builder MACOSX_BUNDLE ${intl_sources} Sources/Shared/DiskImageDevice.swift Sources/Shared/PlayerSnapshot.swift Sources/Shared/About.swift Sources/Builder/IconPicker.swift Sources/Builder/IconEncoder.swift Sources/Builder/Builder.swift Sources/Builder/BlankDiskImage.swift Sources/Builder/PlayerExporter.swift Sources/Shared/PlayerManifest.swift)
target_compile_options(a2emu-builder PRIVATE "$<$<COMPILE_LANGUAGE:Swift>:-target;${CMAKE_OSX_ARCHITECTURES}-apple-macosx${CMAKE_OSX_DEPLOYMENT_TARGET};-swift-version;4>")
target_link_libraries(a2emu-builder PRIVATE "-framework Cocoa" "-framework WebKit")
set_target_properties(a2emu-builder PROPERTIES MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/Sources/Builder/Info.plist.in" OUTPUT_NAME "Apple IIGS Player Builder" MACOSX_BUNDLE_GUI_IDENTIFIER "nl.theredhead.a2emu-wrapper-builder" MACOSX_BUNDLE_BUNDLE_NAME "Apple IIGS Player Builder" MACOSX_BUNDLE_SHORT_VERSION_STRING "${A2EMU_VERSION}" MACOSX_BUNDLE_BUNDLE_VERSION "3" MACOSX_BUNDLE_ICON_FILE "Builder.icns")

target_sources(a2emu-builder PRIVATE Assets/Builder.icns)
set_source_files_properties(Assets/Builder.icns PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
set_property(TARGET a2emu-builder APPEND PROPERTY LINK_DEPENDS
    "${CMAKE_SOURCE_DIR}/Resources/CiderPress-LICENSE.txt"
    "${CMAKE_SOURCE_DIR}/Resources/ProDOS-Boot-NOTICE.txt"
    ${localization_resources}
    "${CMAKE_SOURCE_DIR}/Assets/Builder.icns"
    "${CMAKE_SOURCE_DIR}/Assets/BuilderIcon.png"
    "${CMAKE_SOURCE_DIR}/Assets/PlayerIcon.png"
    "${CMAKE_SOURCE_DIR}/Assets/Snapshot.icns")
add_custom_command(TARGET a2emu-builder POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_SOURCE_DIR}/Resources/CiderPress-LICENSE.txt" "$<TARGET_BUNDLE_DIR:a2emu-builder>/Contents/Resources/CiderPress-LICENSE.txt"
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_SOURCE_DIR}/Resources/ProDOS-Boot-NOTICE.txt" "$<TARGET_BUNDLE_DIR:a2emu-builder>/Contents/Resources/ProDOS-Boot-NOTICE.txt"
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_SOURCE_DIR}/Resources/Localizations" "$<TARGET_BUNDLE_DIR:a2emu-builder>/Contents/Resources"
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_SOURCE_DIR}/Assets/Snapshot.icns" "$<TARGET_BUNDLE_DIR:a2emu-builder>/Contents/Resources/Snapshot.icns"
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_SOURCE_DIR}/Assets/PlayerIcon.png" "$<TARGET_BUNDLE_DIR:a2emu-builder>/Contents/Resources/PlayerIcon.png"
    COMMAND ${CMAKE_COMMAND} -E rm -f "$<TARGET_BUNDLE_DIR:a2emu-builder>/Contents/Resources/Player-Source.zip"
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_SOURCE_DIR}/Assets/BuilderIcon.png" "$<TARGET_BUNDLE_DIR:a2emu-builder>/Contents/Resources/BuilderIcon.png"
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_SOURCE_DIR}/LICENSE" "$<TARGET_BUNDLE_DIR:a2emu-builder>/Contents/Resources/LICENSE.txt"
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_SOURCE_DIR}/Assets/Builder.icns"
        "$<TARGET_BUNDLE_DIR:a2emu-builder>/Contents/Resources/Builder.icns"
    VERBATIM)

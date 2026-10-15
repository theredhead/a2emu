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
# The legacy MAC joystick branch ignores SDL_INPUT. Compile just this source
# without MAC so it uses the no-device fallback, avoiding global HID access.
set_source_files_properties(Vendor/gsplus/gsplus/src/joystick_driver.c
    DIRECTORY "${CMAKE_SOURCE_DIR}/Vendor/gsplus/gsplus/src"
    PROPERTIES COMPILE_OPTIONS "-UMAC")
add_executable(a2emu-player MACOSX_BUNDLE
    Sources/Shared/PlayerManifest.swift
    Sources/Player/About.swift
    Sources/Player/AppDelegate.swift
    Sources/Player/ROMSetup.swift
    Sources/Player/MainView.swift
    Vendor/gsplus/gsplus/src/macsnd_driver.c)
add_dependencies(a2emu-player player-source)
target_compile_options(a2emu-player PRIVATE
    "$<$<COMPILE_LANGUAGE:Swift>:-target;${CMAKE_OSX_ARCHITECTURES}-apple-macosx${CMAKE_OSX_DEPLOYMENT_TARGET}>"
    "$<$<COMPILE_LANGUAGE:Swift>:-import-objc-header;${CMAKE_SOURCE_DIR}/Sources/Player/Bridging-Header.h;-swift-version;4;-Xcc;-I${CMAKE_SOURCE_DIR}/Vendor/gsplus/gsplus/src>")
target_link_libraries(a2emu-player PRIVATE gsplus_core
    "-framework Cocoa" "-framework AudioToolbox" "-framework CoreAudio" "-framework AudioUnit")
set_target_properties(a2emu-player PROPERTIES OUTPUT_NAME "Apple II Player"
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/Sources/Player/Info.plist")
add_custom_command(TARGET a2emu-player POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_SOURCE_DIR}/Assets/Player.icns" "$<TARGET_BUNDLE_DIR:a2emu-player>/Contents/Resources/Player.icns"
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_SOURCE_DIR}/Vendor/gsplus/LICENSE" "$<TARGET_BUNDLE_DIR:a2emu-player>/Contents/Resources/GSplus-LICENSE.txt"
    COMMAND ${CMAKE_COMMAND} -E rm -f "$<TARGET_FILE_DIR:a2emu-player>/main.d" "$<TARGET_FILE_DIR:a2emu-player>/Apple II Player.d"
    COMMAND ${CMAKE_COMMAND} -E rm -f "$<TARGET_BUNDLE_DIR:a2emu-player>/Contents/Resources/ROM.03" "$<TARGET_BUNDLE_DIR:a2emu-player>/Contents/Resources/ROM.01"
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_SOURCE_DIR}/Assets/PlayerIcon.png" "$<TARGET_BUNDLE_DIR:a2emu-player>/Contents/Resources/PlayerIcon.png"
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_BINARY_DIR}/Player-Source.zip" "$<TARGET_BUNDLE_DIR:a2emu-player>/Contents/Resources/Player-Source.zip"
    COMMAND codesign --force --sign - "$<TARGET_BUNDLE_DIR:a2emu-player>")

add_executable(a2emu-builder MACOSX_BUNDLE Sources/Builder/IconPicker.swift Sources/Builder/IconEncoder.swift Sources/Builder/Builder.swift Sources/Builder/PlayerExporter.swift Sources/Shared/PlayerManifest.swift)
target_compile_options(a2emu-builder PRIVATE "$<$<COMPILE_LANGUAGE:Swift>:-target;${CMAKE_OSX_ARCHITECTURES}-apple-macosx${CMAKE_OSX_DEPLOYMENT_TARGET};-swift-version;4>")
target_link_libraries(a2emu-builder PRIVATE "-framework Cocoa" "-framework WebKit")
set_target_properties(a2emu-builder PROPERTIES OUTPUT_NAME "Apple II Wrapper Builder" MACOSX_BUNDLE_GUI_IDENTIFIER "nl.theredhead.a2emu-wrapper-builder" MACOSX_BUNDLE_BUNDLE_NAME "Apple II Wrapper Builder" MACOSX_BUNDLE_SHORT_VERSION_STRING "${A2EMU_VERSION}" MACOSX_BUNDLE_BUNDLE_VERSION "3" MACOSX_BUNDLE_ICON_FILE "Builder.icns")

target_sources(a2emu-builder PRIVATE Assets/Builder.icns)
set_source_files_properties(Assets/Builder.icns PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
add_custom_command(TARGET a2emu-builder POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_SOURCE_DIR}/Assets/Builder.icns"
        "$<TARGET_BUNDLE_DIR:a2emu-builder>/Contents/Resources/Builder.icns"
    VERBATIM)

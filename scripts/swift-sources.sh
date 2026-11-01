#!/bin/bash
# Shared source groups for native tests. Paths follow the same architectural roots as CMake.
shared_sources=()
while IFS= read -r source; do shared_sources+=("$source"); done < <(find Sources/Shared -type f -name '*.swift' | sort)
builder_support_sources=()
while IFS= read -r source; do
  [[ "$source" == Sources/Builder/Application/Builder.swift ]] || builder_support_sources+=("$source")
done < <(find Sources/Builder -type f -name '*.swift' | sort)
player_support_sources=()
while IFS= read -r source; do
  [[ "$source" == Sources/Player/Application/AppDelegate.swift ]] || player_support_sources+=("$source")
done < <(find Sources/Player -type f -name '*.swift' | sort)
controller_sources=()
while IFS= read -r source; do controller_sources+=("$source"); done < <(
  find Sources/Player/Domain/Input Sources/Player/Presentation/Controls Sources/Player/Infrastructure/Preferences -type f -name '*.swift' | sort)
controller_sources+=(Sources/Player/Infrastructure/Input/GameControllerButtons.swift)

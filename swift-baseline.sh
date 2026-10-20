#!/bin/zsh
set -eu
cd "${0:A:h}"
paths=('Sources' 'scripts')
case "${1:-check}" in
  format) xcrun swift-format format --configuration .swift-format --in-place --recursive "${paths[@]}" ;;
  check)
    xcrun swift-format lint --configuration .swift-format --strict --recursive "${paths[@]}"
    swiftlint lint --config .swiftlint.yml --strict --no-cache
    ;;
  *) print -u2 'Usage: swift-baseline.sh [format|check]'; exit 2 ;;
esac

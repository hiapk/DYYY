#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/dyyy-long-press-panel-tests.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
xcrun clang -fobjc-arc -fblocks -Wall -Wextra -Werror -Wno-unused-parameter \
    -Wno-nullability-completeness -I "$project_dir/Sources/Features" -framework Foundation \
    "$project_dir/Sources/Features/DYYYLongPressPanelFilter.m" "$project_dir/tests/DYYYLongPressPanelFilterTests.m" \
    -o "$test_dir/long-press-panel-tests"
"$test_dir/long-press-panel-tests"

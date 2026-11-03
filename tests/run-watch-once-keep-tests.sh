#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/dyyy-watch-once-tests.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
xcrun clang -fobjc-arc -fblocks -Wall -Wextra -Werror -Wno-unused-parameter \
    -I "$project_dir/Sources/Features" -framework Foundation \
    "$project_dir/Sources/Features/DYYYWatchOnceKeepPolicy.m" \
    "$project_dir/tests/DYYYWatchOnceKeepPolicyTests.m" \
    -o "$test_dir/watch-once-tests"
"$test_dir/watch-once-tests"

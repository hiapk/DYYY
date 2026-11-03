#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/dyyy-like-privacy-tests.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
xcrun clang -fobjc-arc -fblocks -Wall -Wextra -Werror -Wno-unused-parameter \
    -Wno-nullability-completeness -I "$project_dir/Sources/Features" -framework Foundation -framework Security -framework CoreGraphics \
    "$project_dir/Sources/Features/DYYYLikePrivacyState.m" "$project_dir/Sources/Features/DYYYLikePrivacyPagePolicy.m" "$project_dir/tests/DYYYLikePrivacyStateTests.m" \
    -o "$test_dir/like-privacy-tests"
"$test_dir/like-privacy-tests"

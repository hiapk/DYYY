#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/dyyy-chat-privacy-tests.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
xcrun clang -fobjc-arc -fblocks -Wall -Wextra -Werror -Wno-unused-parameter \
    -Wno-nullability-completeness -I "$project_dir/Sources/Features" -framework Foundation \
    "$project_dir/Sources/Features/DYYYChatPrivacyGuard.m" "$project_dir/Sources/Features/DYYYAdChapterSkipPolicy.m" \
    "$project_dir/tests/DYYYChatPrivacyGuardTests.m" \
    -o "$test_dir/chat-privacy-tests"
"$test_dir/chat-privacy-tests"

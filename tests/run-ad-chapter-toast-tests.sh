#!/bin/sh
set -eu
: "${THEOS:?请设置 THEOS 后运行广告章节 Toast Hook 测试}"
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/dyyy-ad-toast-tests.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

# 从实际集中头文件提取 Hook 接口，构造只有 Foundation 的宿主环境，不复制维护另一套声明。
python3 - "$project_dir" "$test_dir" <<'PY'
from pathlib import Path
import re
import sys

root, target = map(Path, sys.argv[1:])
source = (root / "DYYYAdChapterSkip.xm").read_text()
headers = (root / "Sources/Core/AwemeHeaders.h").read_text()
names = set(re.findall(r"%hook\s+(\w+)", source))
names.update(("AWEDPlayerComponentAdChapter", "AWEDPlayerAdChapterPlugin", "AWELandscapeAdChapterAutoSkipController"))
declarations = []
for name in sorted(names):
    match = re.search(r"@interface\s+" + re.escape(name) + r"\s*:[\s\S]*?@end", headers)
    if not match:
        raise SystemExit(f"缺少集中声明：{name}")
    declarations.append(match.group())
(target / "AwemeHeaders.h").write_text("#import <Foundation/Foundation.h>\n#import <objc/runtime.h>\n" + "\n".join(declarations))
PY

perl "$THEOS/bin/logos.pl" -c generator=internal "$project_dir/DYYYAdChapterSkip.xm" > "$test_dir/AdChapterHook.mm"
xcrun clang -fobjc-arc -fblocks -Wall -Wextra -Werror -Wno-unused-parameter \
    -Wno-nullability-completeness -I "$test_dir" -I "$project_dir/Sources/Features" \
    -framework Foundation -lc++ "$project_dir/Sources/Features/DYYYAdChapterSkipPolicy.m" \
    "$test_dir/AdChapterHook.mm" "$project_dir/tests/DYYYAdChapterToastHookTests.m" \
    -o "$test_dir/ad-toast-tests"
"$test_dir/ad-toast-tests"

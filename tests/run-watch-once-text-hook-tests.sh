#!/bin/sh
set -eu
: "${THEOS:?请设置 THEOS 后运行文字仅看一次 Hook 测试}"
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/dyyy-watch-once-text-tests.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

python3 - "$project_dir" "$test_dir" <<'PY'
from pathlib import Path
import re
import sys

root, target = map(Path, sys.argv[1:])
source = (root / "DYYYWatchOnceKeep.xm").read_text()
headers = (root / "Sources/Core/AwemeHeaders.h").read_text()
names = set(re.findall(r"%hook\s+(\w+)", source))
names.update(("AWEIMWatchOnceTextMessage", "AWEIMWatchOnceImageDetailInfo", "AWEIMWatchOnceVideoDetailInfo"))
seen, declarations = set(), []

def include(name):
    if name in seen or name in ("NSObject", "UIViewController"):
        return
    match = re.search(r"@interface\s+" + re.escape(name) + r"\s*:\s*(\w+)[\s\S]*?@end", headers)
    if not match:
        raise SystemExit(f"缺少集中声明：{name}")
    include(match.group(1))
    seen.add(name)
    # 模拟宿主只测方法分发；测试中以 NSObject 替换 UIKit 基类，不改变工程头文件。
    declarations.append(match.group().replace(": UIViewController", ": NSObject"))

for name in sorted(names):
    include(name)
(target / "AwemeHeaders.h").write_text("#import <Foundation/Foundation.h>\n#import <objc/runtime.h>\n@class " + ", ".join(sorted(seen)) + ";\n" + "\n".join(declarations))
PY

perl "$THEOS/bin/logos.pl" -c generator=internal "$project_dir/DYYYWatchOnceKeep.xm" > "$test_dir/WatchOnceHook.mm"
xcrun clang -fobjc-arc -fblocks -Wall -Wextra -Werror -Wno-unused-parameter \
    -Wno-nullability-completeness -I "$test_dir" -I "$project_dir/Sources/Features" \
    -framework Foundation -lc++ "$project_dir/Sources/Features/DYYYWatchOnceKeepPolicy.m" \
    "$test_dir/WatchOnceHook.mm" "$project_dir/tests/DYYYWatchOnceTextHookTests.m" \
    -o "$test_dir/watch-once-text-tests"
"$test_dir/watch-once-text-tests"

#!/usr/bin/env python3
"""编译实际的请求头 Hook，覆盖 Logos 在嵌套表达式中处理 %orig 的回归。"""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
theos = os.environ.get("THEOS")
if not theos:
    raise SystemExit("请设置 THEOS 后运行此编译回归检查")
subprocess.run(
    ["perl", str(Path(theos) / "bin/logos.pl"), "-c", "generator=internal", str(root / "DYYYLikePrivacy.xm")],
    stdout=subprocess.DEVNULL, check=True,
)
source = (root / "DYYY.xm").read_text()
start = source.index("- (NSDictionary *)HTTPAdditionalHeaders {")
end = source.index("\n}", start) + 2
fixture = (
    "#import <Foundation/Foundation.h>\n"
    "NSDictionary *DYYYLoginBypassHeadersByReplacingBundleIdentifiers(NSDictionary *headers);\n"
    "%hook NSURLSessionConfiguration\n" + source[start:end] + "\n%end\n"
)
with tempfile.TemporaryDirectory(prefix="dyyy-logos-regression-") as directory:
    path = Path(directory) / "Hook.xm"
    path.write_text(fixture)
    generated = Path(directory) / "Hook.mm"
    with generated.open("w") as output:
        subprocess.run(["perl", str(Path(theos) / "bin/logos.pl"), "-c", "generator=internal", str(path)], stdout=output, check=True)
    subprocess.run(["xcrun", "clang++", "-fobjc-arc", "-fblocks", "-fsyntax-only", str(generated)], check=True)
print("PASS: 喜欢页 Hook 分组初始化与请求头 Hook 的 Logos 编译回归")

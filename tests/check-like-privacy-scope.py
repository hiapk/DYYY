#!/usr/bin/env python3
"""喜欢页保护范围检查：只接入主页分页结构，遮挡层不挂窗口，Hook 选择子须在 IPA 接口快照中核实。"""
from pathlib import Path
import json
import re

root = Path(__file__).resolve().parent.parent
hooks = (root / "DYYYLikePrivacy.xm").read_text()
targets = set(re.findall(r"%hook\s+(\w+)", hooks))
for forbidden in ("UIWindow", "UIScrollView", "UIViewController", "UICollectionViewCell", "UICollectionView"):
    if forbidden in targets:
        raise SystemExit(f"FAIL: 喜欢页保护不应全局 Hook {forbidden}")
for required in ("AWEUserHomeViewControllerV2", "AWERLPageViewController"):
    if required not in targets:
        raise SystemExit(f"FAIL: 必须接入主页分页结构 {required}")
if "numberOfItemsInSection" in hooks:
    raise SystemExit("FAIL: 不应伪造数据源数量，避免原生增量更新数量不一致")

fixture = json.loads((root / "tests/fixtures/aweme-39.8.0-profile-tabs.json").read_text())
# 继承自 UIResponder 的方法由 Logos 以调用父类实现的方式补充。
inherited = {"motionEnded:withEvent:"}
for name, body in re.findall(r"%hook\s+(\w+)(.*?)%end", hooks, re.S):
    if name not in fixture["classes"]:
        raise SystemExit(f"FAIL: {name} 不在 IPA 接口快照中")
    known = fixture["classes"][name]["selectors"]
    for signature in re.findall(r"^[+-]\s*\([^)]*\)([^\n{]+)", body, re.M):
        parts = re.findall(r"(\w+)\s*:", signature)
        selector = ":".join(parts) + ":" if parts else signature.strip().split()[0]
        if selector not in known and selector not in inherited:
            raise SystemExit(f"FAIL: {name}.{selector} 未在 IPA 接口快照中核实")

source = (root / "Sources/Features/DYYYLikePrivacyController.m").read_text()
if re.search(r"\[\s*(?:window|\w*[Ww]indow\w*)\s+(?:addSubview|insertSubview)\s*:", source):
    raise SystemExit("FAIL: 保护层不能挂在 UIWindow 上跨页面显示")
if re.search(r"(?:scroll|page|home|tabList|segment|controller|window)\.(?:frame|bounds|transform|contentSize|contentOffset)\s*=", source):
    raise SystemExit("FAIL: 保护逻辑不能写入宿主几何属性")
if "addSubview:self.cover" not in source or "page.scrollView" not in source:
    raise SystemExit("FAIL: 喜欢页遮挡层应挂在主页分页滚动视图内")
print("PASS: 主页分页范围、窗口与宿主几何边界、IPA 接口快照")

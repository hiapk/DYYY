# DYYY 2.3-4 主页分页喜欢页保护

本文保留 2.3-4 喜欢页修复的历史基线与验收说明。当前源码与包声明版本为 **2.3-8**，本次新增行为及验证范围见 README。

本地 2.3-4 基于 VexCove 的 `DYYY_2.3-0#23` 公开源码。2.3-3 只接入 `AWELikeWorkViewController`，用户真机反馈喜欢页完全不隐藏、摇动无密码框：39.8.0 自己主页的标签页由 `AWERLTabListViewController` 分页承载，喜欢列表并未经过该控制器。2.3-4 改为按主页标签定位喜欢页。

## 版本与目标

- 基线提交：[`ed7abd316a691fba1c24bad069091701b5b94145`](https://github.com/VexCove/DYYY/tree/ed7abd316a691fba1c24bad069091701b5b94145)，该标签也由 [Evilintent1on/DYYY](https://github.com/Evilintent1on/DYYY/tree/DYYY_2.3-0%2323) 保留。
- 保留基线 MIT 许可证及作者信息，沿用本仓库 CI，并加入本地回归检查。
- 用户来源：[TrollStoreX](https://trollstorex.github.io/repo/)，包索引为 `2.3-0`，介绍页标注 #23；重打包二进制与源码的等价性尚未验证。
- 本地包为 `com.huami.dyyy.vita` / `2.3-4`，默认 `SCHEME=roothide`，交付 `iphoneos-arm64e.deb`。
- 目标设备为 RootHide、iOS 16.5、抖音 39.8.0。2.3-4 尚待真机复测。

## IPA 中已核对的接口

- `AWEUserHomeViewControllerV2`：`isCurrentUserProfilePage`、`tabListViewController`、`tabHelper`、`userModel` 与布局/出现/消失生命周期。
- `AWERLTabListViewController`：`pageViewController`、`segmentView`、子列表纵向滚动回调。
- `AWERLPageViewController`：`scrollView`、`selectedIndex`、`addedViewControllers`、`indexForViewController:` 与分页滚动回调。
- `AWERLSegmentView.itemModels` 中的 `AWERLSegmentItemDataModel.title/selectedTitle`，以及兜底的 `AWEUserProfileTabHelper.tabTitles`。
- 精简接口快照位于 `tests/fixtures/aweme-39.8.0-profile-tabs.json`，只保留选择子及类型编码；IPA 不纳入 Git。

## 2.3-4 的展示边界

- 仅在自己的主页生效：按分段标签标题找到“喜欢”的序号，把原生风格空状态遮挡层挂进主页分页滚动视图、喜欢页对应的位置，从分段标签下沿开始覆盖。
- 锁定期间遮挡层常驻喜欢页位置，即使当前停在其他标签，横滑进入喜欢页的整个过渡中也不会露出内容。遮挡层位于主页内部，不覆盖侧栏、设置、底栏和弹出面板。
- 不修改宿主的 frame、bounds、transform、contentSize、单元格或数据源，不全局 Hook UIWindow、UIScrollView、UIViewController。
- 锁定只由真正的离开触发：分页停稳后不在喜欢标签、主页消失且未进入受保护视频、进入后台、切换账号。键盘弹出与布局变化不会取消密码框；只有解锁密码框随切换标签取消，设置页发起的密码框不受影响。
- 解锁后从主页进入视频（导航栈顶或模态中的已知播放器类）保持解锁；视频页退后台后由仅属于该播放器视图的遮挡层保护。
- PIN 与保护状态的 Keychain 格式不变，升级不主动重置原密码。普通配置备份/恢复/清理不修改密码记录。

## 验证

```sh
sh tests/run-like-privacy-tests.sh
python3 tests/check-like-privacy-scope.py
THEOS=/path/to/theos python3 tests/check-logos-header-hook.py
GITHUB_ACTIONS=true make package SCHEME=roothide
```

单元测试覆盖标签识别（数量后缀、富文本、分段数据模型）与遮挡几何；范围检查对照 IPA 接口快照核验全部 Hook 选择子。它们不能替代真机界面验收。

本机使用临时 Theos 与 iOS 18.0 SDK。最低部署版本仍为 iOS 14；通过命令行 `MODULESFLAGS=-fno-modules`、`DYYY_LIBRARIES=substrate` 及显式系统框架规避本机 Command Line Tools 的模块问题，这些环境参数未固化进公共 Makefile。

设备验收见 [检查清单](tests/like-privacy-device-checklist.md)。覆盖安装后需彻底退出抖音再打开。

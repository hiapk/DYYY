# DYYY AI Agent 提示文档

本项目是基于 Theos/Logos 的抖音 UI 调整 Tweak。当前 README 将 **iOS 16.5 / 抖音 39.8.0** 列为开发目标，并明确新增喜欢页保护尚待真机验收；回答需求时请区分开发目标与已验证兼容性，不要沿用旧版本描述。

当前源码与包声明版本为 **2.3-8**，基于 VexCove `2.3-0 #23` 的 `ed7abd316a691fba1c24bad069091701b5b94145`；源码采用 `Sources/` 分层。目标为 RootHide、iOS 16.5、抖音 39.8.0。用户提供了 build 398016 的解密 IPA，主页分页接口已核对；2.3-2 已反馈跨页遮挡问题，2.3-3 只接入 `AWELikeWorkViewController`，用户反馈完全不隐藏、摇动无密码框；2.3-4 改按主页分页标签定位。2.3-8 补齐仅看一次文字的消费状态与上报拦截，保留 2.3-7 广告章节静默提示；新增行为待真机验证。

**版本核验**：区分本地源码声明、上游 Release、fork 发布版本和用户设备实装版本。用户提供不同版本时，先检索 fork 与发布来源；不能仅凭本地版本号判断新版本不存在，或将声明版本直接等同于功能源码版本。

**发布版本与基线分开记录**：用户给出的新版本号可能指本次产物，先明确其含义；本次约定以 2.3-0 #23 开发，首版为 2.3-1，后续修复递增版本。

**版本号同步**：交付新版本时同步 `control`、`Sources/Core/DYYYConstants.h` 的 `DYYY_VERSION`、README 当前版本与验收清单中的设置页版本预期；不能只修改 deb 文件名或构建覆盖参数。历史版本说明保留原版本并标明其历史范围。

**当前修复授权**：用户已说“你定就可以”，授权自行决定当前喜欢页故障的修复细节；在已确认范围内直接完成实现、验证与 RootHide 包交付，不重复确认相同方案。

**已验证源码发布**：用户指出此前修复无法隐藏喜欢页，并已自行重写且真机验证通过。发布时以用户当前源码为准，不覆盖或重新实现；仅提交源码与必要构建配置，排除测试、排查文档、IPA、deb 及中间产物。私有接口存在不能证明实际页面经过该接口，兼容性结论必须有实际调用路径或真机验证支撑。

**开源仓库关系**：发布本项目的修改时应 fork 原始开源仓库，保留上游关联、提交历史与许可证；不要另建失去来源关系的独立仓库。

**本仓库提交身份**：作者与提交者邮箱统一使用 `liangzhaostrive@gmail.com`，不再沿用旧工作邮箱，不自动添加其他作者或 `Co-Authored-By` 署名。历史整理仅合并本人的新增提交，保留上游作者历史与许可证；`.pi/` 是本机代理运行状态，只保留在本地并加入忽略规则，不纳入 Git。

**目标包方案**：用户已明确设备为 iOS 16.5 的 RootHide。默认使用 `SCHEME=roothide`，交付 `iphoneos-arm64e.deb`；不要把 rootless/rootful 包列为此设备的安装选项，交付前核对包架构、安装路径和依赖。

**喜欢页保护回归要求**：用户反馈强黑占位突兀、横向切页时内容闪现、键盘弹起时密码框自动消失。修复应采用抖音原生主题的空列表外观，覆盖切页的完整过渡过程，并将键盘、输入框和临时布局变化与真正离开主页区分开；必须补充过渡过程和密码框生命周期的复现用例。

**喜欢页保护范围**：用户进一步反馈页面观感异常及底部面板被遮挡。提供 IPA 后应先核对该版本的原生喜欢列表接口，将保护层限定在该列表视图树内；不得用跨页面的窗口蒙层覆盖设置、侧边栏或底栏，不得修改宿主的 frame、bounds、transform 或内容尺寸来修正遮挡范围。排查时要区分真实缩放与蒙层越界造成的视觉异常。

**测试目录**：统一使用小写 `tests/`，确认回归用例未被 `.gitignore` 的大小写匹配忽略，确保本地与 CI 执行同一份测试。

## 工程关键点
- **Hook 入口**：`DYYY.xm` 负责 Feed、浮窗、全局透明度与 Tab Bar 高度等通用 Hook；`DYYYSettings.xm` 负责抖音设置页相关 Hook（`AWESettingBaseViewController`、`AWELeftSideBarWeatherLabel` 等）并构造 DYYY 自定义设置。
- **业务核心**：`DYYYManager` 统一处理媒体下载、批量任务、Live Photo/GIF/WebP 转换及保存流程，内部维护 `NSOperationQueue` 与下载任务/回调映射；`DYYYSettingsHelper` 管理设置依赖、入口查找、用户协议弹窗；`DYYYUtils` 处理 IP 属地、颜色、窗口查找、缓存路径等可复用逻辑。
- **UI 组件**：所有自定义视图/弹窗（如 `DYYYBottomAlertView`、`DYYYFloatSpeedButton`、`DYYYAboutDialogView` 等）都有 `.h/.m` 配对文件，并在设置控制器中组合使用。
- **模型/数据**：`CityManager` 负责本地城市映射与 GeoNames 查询；GeoNames 结果缓存逻辑在 `DYYYUtils`；`DYYYConstants.h`、`DYYYSettingsHelper` 中定义的 Key 控制远程 ABTest、依赖关系与通知。
- **AwemeHeaders**：项目依赖的抖音私有类、Category 声明、宏定义都集中在 `AwemeHeaders.h` 中，供整个 tweak 引入。

## 类路径速查（按 UI/功能分组）
- **入口 Hook / 控制器**
  - `DYYY.xm`、`DYYYSettings.xm`：全局 Hook、设置页 Hook。
  - `Sources/Settings/DYYYSettingViewController.(h/m)`：自定义设置主界面。
  - `Sources/Settings/DYYYSettingsHelper.(h/m)`：设置项依赖、入口、协议弹窗。
- **业务/下载**
  - `Sources/Media/DYYYManager.(h/m)`：下载、合成、任务管理、授权。
  - `Sources/Core/CityManager.(h/m)`：城市映射与 GeoNames 查询。
  - `Sources/Core/AWMSafeDispatchTimer.(h/m)`：安全延时定时器。
- **通用工具/常量**
  - `Sources/Core/DYYYUtils.(h/m)`：窗口/颜色/路径等工具。
  - `DYYYConstants.h`：Keys、URL、通知名。
- **设置页复用 UI（按交互类型）**
  - 列表/选择：`Sources/UI/DYYYKeywordListView.(h/m)`、`Sources/UI/DYYYOptionsSelectionView.(h/m)`、`Sources/UI/DYYYFilterSettingsView.(h/m)`。
  - 输入/图标配置：`Sources/UI/DYYYCustomInputView.(h/m)`、`Sources/UI/DYYYIconOptionsDialogView.(h/m)`、`Sources/Settings/DYYYPickerDelegates.(h/m) 中的 DYYYImagePickerDelegate`、`Sources/Settings/DYYYPickerDelegates.(h/m) 中的 DYYYBackupPickerDelegate`。
  - 弹窗/提示：`Sources/UI/DYYYBottomAlertView.(h/m)`、`Sources/UI/DYYYConfirmCloseView.(h/m)`、`Sources/UI/DYYYAboutDialogView.(h/m)`、`Sources/UI/DYYYToast.(h/m)`。
- **浮窗与快捷操作**
  - 漂浮按钮：`Sources/Features/DYYYFloatSpeedButton.(h/m)`、`DYYYFloatClearButton.(h/xm)`。
  - 长按/面板：`DYYYLongPressPanel.xm`、`Sources/UI/DYYYBottomAlertView.(h/m)`（复用提示）。
  - 长按面板原生项目过滤：`Sources/Features/DYYYLongPressPanelFilter.(h/m)`，按类名与文案隐藏推荐、转发到日常、不感兴趣及文本规则项；可用 `sh tests/run-long-press-panel-tests.sh` 验证。
- **私信隐私**
  - `DYYYChatPrivacy.xm`：Hook `TIMXPBAutoFallbackRequest -send`，按请求体字段拦截已读上报（MarkConversationRead 等 6 类）与输入状态（SendInputStatus），以失败回调收尾。
  - `Sources/Features/DYYYChatPrivacyGuard.(h/m)`：请求类型识别与开关（`DYYYDisableReadReceiptUpload`、`DYYYDisableInputStatusUpload`）。
- **仅看一次重复查看（实验）**
  - `DYYYWatchOnceKeep.xm`：接收方文字/图片/视频的消费状态与专用上报 Hook，整组检查运行时接口；文字同时拦 `readState` 的本地 2/4 写入及 `TextWatchEnd`，先记录查询/回填中的真实失效再执行原生处理。媒体仅拦空详情清空模型资源字段，保留正常详情回填与退出清理。
  - `Sources/Features/DYYYWatchOnceKeepPolicy.(h/m)`：默认关闭的 `DYYYKeepWatchOnceMessage`、消息范围、混合批次与异步失败回调；用 `sh tests/run-watch-once-keep-tests.sh` 验证策略。单测与编译通过不能代替真机媒体资源验收。
  - 用户最初反馈「第三次重进显示撤回、第四次提示也消失」，对象是文字且发送方未主动撤回；后续确认当时未开启开关，当前测试正常，不能把最初现象当作开启功能后的故障证据。澄清选项与回归必须包含文字、图片、视频三类，并用 `THEOS=... sh tests/run-watch-once-text-hook-tests.sh` 覆盖至少五次消息对象重建；不得全局屏蔽真实撤回/删除，已消费旧消息不承诺恢复。
  - 排查开关型功能前先确认该次复现时开关是否实际开启，再确认消息类型与版本；未开启时的原生行为不得归因为插件开启后的实现故障。用户后续澄清时必须同步修正先前的根因记录与验收结论。
- **长视频广告章节**
  - `DYYYAdChapterSkip.xm`：放开 `enableAdChapterAutoSkip`/`enableAdChapterPlugin`，并让 `AWECodeGenChapterDataModel.adChapterAutoSkipIndexArray` 返回全部广告章节，复用抖音原生跳过与提示。
  - `Sources/Features/DYYYAdChapterSkipPolicy.(h/m)`：开关 `DYYYAutoSkipAdChapter` 与序号改写规则；与私信隐私一起可用 `sh tests/run-chat-privacy-tests.sh` 验证。
  - 静默跳过只拦竖屏组件、播放器插件和横屏控制器的 `showAdSkipChapterToastWithStartTime:endTime:`，不吞全局 Toast；关闭广告章节开关恢复原生提示。用 `THEOS=... sh tests/run-ad-chapter-toast-tests.sh` 验证实际 Logos Hook 的展示次数、开关恢复与时间参数透传。
- **辅助代理**
  - `Sources/Settings/DYYYPickerDelegates.(h/m) 中的 DYYYImagePickerDelegate`、`Sources/Settings/DYYYPickerDelegates.(h/m) 中的 DYYYBackupPickerDelegate`：统一封装系统 Picker 逻辑。
  - `Sources/UI/DYYYCustomInputView.(h/m)`：文本输入。
- **ABTest / 远程配置**
  - `DYYYABTestHook.(h/xm)`：抖音 ABTest 注入。
- **喜欢页保护**
  - `DYYYLikePrivacy.xm`：自己主页（`AWEUserHomeViewControllerV2`）、分页（`AWERLPageViewController`/`AWERLTabListViewController`）与账号事件接入，不全局拦截窗口、滚动视图或控制器。
  - `Sources/Features/DYYYLikePrivacyController.(h/m)`：主页与喜欢标签识别、分页内遮挡、会话锁定、视频交接、密码输入与设置入口。
  - `Sources/UI/DYYYLikePrivacyCoverView.(h/m)`：原生风格空状态遮挡层与系统摇动事件接收。
  - `Sources/Features/DYYYLikePrivacyPagePolicy.(h/m)`：喜欢标签序号识别与遮挡几何，可独立测试。
  - `Sources/Features/DYYYLikePrivacyState.(h/m)`：Keychain 密码记录、密码校验与浏览会话；可用 `sh tests/run-like-privacy-tests.sh` 在 macOS 上验证。

(按上述分组定位 `.h/.m/.xm` 文件，可快速找到对应 UI 或业务类。若新增类，请将文件放入同类路径并在这里补充。)

## DYYYManager 与 DYYYUtils 职权边界（必须遵守）
- **DYYYManager（业务编排层）**
  - 负责“业务流程”与“任务生命周期”：下载发起/取消、批量任务、进度聚合、回调分发、相册保存、失败收敛、资源清理。
  - 允许维护业务状态与映射（如 downloadID、batchID、progress/completion 字典）。
  - 可以调用 `DYYYUtils` 完成底层工具能力，但不应在这里堆积与业务无关的通用工具。
- **DYYYUtils（无状态工具层）**
  - 负责可复用的通用能力：窗口/控制器查找、文件与缓存路径、媒体格式识别与转换、视频音频合成辅助、颜色与文本渲染、通用提示封装。
  - 方法应尽量“输入明确、输出明确”，不保存下载任务状态，不承担批量流程编排。
  - 不依赖 `DYYYManager`，保持单向依赖：`DYYYManager -> DYYYUtils`。
- **落点判定规则**
  - 需求涉及任务状态机、重试/取消、批次统计、统一收尾：放 `DYYYManager`。
  - 需求可被多个模块复用，且不需要业务上下文状态：放 `DYYYUtils`。
  - 若同一功能同时包含“流程编排 + 工具细节”，编排留在 `DYYYManager`，细节下沉为 `DYYYUtils` 新方法。
- **禁止项**
  - 禁止在 `DYYYUtils` 新增下载任务字典、批量计数器、业务开关同步逻辑。
  - 禁止在 `DYYYManager` 新增纯 UI 颜色算法、通用视图遍历、与下载/保存无关的杂项工具函数。

## 开发规范
### 1. 头文件管理
1. **所有新增的抖音类/方法声明必须写入 `AwemeHeaders.h`**，保持集中管理，避免在其他文件里散落声明。
2. 自定义 `UIView` Category 或辅助宏同样放在 `AwemeHeaders.h`，必要时按功能分段并维持已有注释风格。
3. 外部库统一通过已有 `AwemeHeaders.h` 或对应 `.h` 引入，避免重复 import。

### 2. 类与函数组织
1. 项目内业务类一律使用 `DYYY` 前缀，并拆分 `.h/.m`；Logos Hook 保持在 `.xm` 文件。
2. **禁止随意添加全局 C 函数**。如需新能力，请优先扩展已有类（`DYYYManager`、`DYYYSettingsHelper`、`DYYYUtils` 等）或创建新的 `DYYYXXX` 类。
3. 使用 `#pragma mark` 分隔方法区域，公开方法在 `.h`，实现细节留在 `.m`。

### 3. Hook 实现
1. 使用 Logos 语法 `%hook/%orig/%new`。对敏感类（如 `AWESettingBaseViewController`）需要在 `dealloc` 中清理 KVO/通知（示例：`DYYYRemoveRemoteConfigObserver`）。
2. Hook 中新增的手势、子视图必须通过 `objc_setAssociatedObject` 或弱引用管理生命周期（天气控件入口即参考）。
3. 所有 UI 写操作必须在主线程 `dispatch_async(dispatch_get_main_queue(), ^{ ... })`，避免阻塞抖音线程。

### 4. 设置/远程配置
1. 开关值均来自 `NSUserDefaults`，统一使用 `DYYYGetBool/DYYYGetString` 等宏或 `DYYYSettingsHelper` 提供的方法。
2. 复杂依赖关系写入 `+[DYYYSettingsHelper settingsDependencyConfig]`，包括 `dependencies/conditionalDependencies/conflicts/mutualExclusions/valueDependencies/synchronizations`。
3. 远程配置与 ABTest 常量统一在 `DYYYConstants.h`（如 `DYYY_DEFAULT_ABTEST_URL`、`DYYY_REMOTE_CONFIG_FLAG_KEY`、`DYYY_REMOTE_CONFIG_CHANGED_NOTIFICATION`）；新增配置时保持命名一致并添加注释。

### 5. 下载与媒体处理
1. 与下载、文件系统相关的逻辑集中在 `DYYYManager`，复用单例属性（下载队列、任务映射等）。新增流程必须复用 `finalizeDownloadWithFileURL:success:` / `finalizeDownloadWithID:success:fileURL:` 一类公共清理方法。
2. 操作 `PHPhotoLibrary` 前必定请求授权并回到主线程触发 UI（参考 `+saveMedia:mediaType:completion:`）。
3. 转码/合成任务使用 `dispatch_queue_t` 或 `NSOperationQueue`，并通过回调通知 UI 层，避免阻塞 Hook。

### 6. UI 与交互
1. 所有弹窗、输入框、选择视图均继承自 `UIView` 或自定义控件，负责自己的布局和动画，控制器或 Hook 仅负责组装。
2. 新的设置项请沿用 AWESetting 模型（`AWESettingSectionModel`、`AWESettingItemModel`）的构造方式，保持 icon/identifier/type 配置完整。
3. Toast、提示统一调用 `DYYYToast` / `DYYYBottomAlertView`，不要直接 `UIAlertController`。

### 7. 资源与缓存
1. `DYYYCustomAssetsDirectory`、`NSCache` 等资源缓存均用 `dispatch_once` 初始化。新增缓存时务必限制容量或提供清理策略。
2. 自定义图片命名遵循 `DYYYCustomIconFileNameForButtonName` 中的映射逻辑，保持文件夹结构一致。

### 8. 代码风格
1. 注释与 UI 文案使用简体中文，文案集中在对应视图或 `DYYYConstants` 中。
2. 常量使用 `static const` 或 `#define`，根据是否需要编译期常量选择，命名与现有风格一致（如 `kDYYYGlobalTransparencyDidChangeNotification`）。
3. 统一 clang 格式：4 空格缩进，`@interface` 属性使用 `nonatomic, strong/assign/copy` 顺序。

### 9. 调试与日志
1. 允许在调试时使用 `NSLog(@"[DYYY] ...")`，发布前要确保不会过度刷屏。
2. 关键路径失败时发送 UI 反馈（`DYYYToast showToast:`）并写 log，保证用户可感知。

### 10. 最终检查
- 新增 Hook 是否受开关保护并能恢复默认行为。
- 是否确保弱引用/通知/定时器释放（`AWMSafeDispatchTimer` 用于延时场景）。
- 所有新增抖音类声明已写入 `AwemeHeaders.h`。
- 是否在对应类/文件中添加函数，并补充必要头文件 import。

## 常见工作流示例
1. **新增抖音 UI Hook**
   - 在 `AwemeHeaders.h` 声明目标类/属性。
   - 于 `DYYY.xm` 或 `DYYYSettings.xm` 新增 `%hook`，逻辑用 `NSUserDefaults` 开关控制。
   - 如果需要 UI，则在 `DYYY` 前缀视图中实现并在 Hook 内调用。
2. **扩展设置开关**
   - 在 `DYYYSettingsHelper` 为依赖体系补充 key。
   - 在设置面板中创建 `AWESettingItemModel`，identifier 与 `NSUserDefaults` key 对齐。
   - 按职责边界实现功能：业务流程进 `DYYYManager`，通用无状态能力进 `DYYYUtils`。
3. **新增媒体处理能力**
   - 在 `DYYYManager` 内添加对应实例/类方法，并封装异步流程。
   - 通过现有回调（下载完成、进度回调等）向 UI 传递状态。

## 构建与测试（make）
- 本地验证优先执行 `make clean package`（或至少 `make package`），确认 tweak 能编译并生成 `.deb`。
- 需要安装到设备验证时，执行 `make package INSTALL=1`（依赖 `THEOS_DEVICE_IP` 配置），编译完成后会通过 `after-package` 自动推送并 `dpkg -i`。
- 切换不同包方案（roothide/rootless）时，通过 `make package SCHEME=rootless` 之类的命令指定 `SCHEME`，保持与目标设备一致。
- CI 或无人值守只需运行 `GITHUB_ACTIONS=true make package`，脚本会自动跳过安装并将产物放在 `packages/`。
- 本地机器建议通过 `Makefile.local` 覆盖 `THEOS_DEVICE_IP` 等私有配置，避免直接改主 `Makefile`。
- 每次回答涉及编译/测试的需求前，先说明是否已运行上述 `make` 命令以及结果，避免 AI 漏检构建错误。

## 复查清单（AI 回复前自检）
- 需求涉及的类是否已存在，若无应在 `AwemeHeaders.h` 与对应 `DYYY` 类中创建。
- 逻辑是否保持线程安全（UI→主线程，IO→后台）。
- 是否引用了现有工具（`DYYYUtils`、`DYYYSettingsHelper`、`DYYYToast`），避免重复造轮子。
- 是否描述了用户可见的行为及开关，确保可通过设置界面操作。

遵循以上约定可以保证 tweak 的 Hook 安全性和可维护性，也方便 AI Agent 在回答问题或生成补丁时保持统一风格。

<p align="center">
  <img src="Screenshots/DYYY_poster.png" alt="DYYY Poster" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2014.0%2B-black?style=flat&labelColor=black" />
  <img src="https://img.shields.io/badge/App-%E6%8A%96%E9%9F%B3%E6%9C%80%E6%96%B0%E7%89%88-black?style=flat&labelColor=black" />
</p>

# DYYY

用于调整抖音 UI 的 Theos/Logos Tweak。本地版本为 **2.3-10**，基于 VexCove **2.3-0 #23**。<br>
本次目标环境为 **RootHide / iOS 16.5 / 抖音 39.8.0**；已根据用户提供的解密 IPA 核对原生喜欢页接口，本版修复跨页面遮挡，仍需真机复测，详见 [源码基线与验证说明](SOURCE_BASELINE.md)。<br>
**仅供学习交流，禁止用于商业用途。**

## 目录
- [功能亮点](#功能亮点)
- [使用方式](#使用方式)
- [贡献者](#贡献者)
- [远程配置](#远程配置)
- [解析下载接口](#解析下载接口)
- [构建与打包](#构建与打包)
- [许可证](#许可证)

## 功能亮点
- 2.3-10：修正新旧长按面板、主页菜单和设置入口的书签图标，使用目标 IPA 已确认存在的原生星标资源
- 2.3-9：增加下载重试与图片兼容、下载速度／大小、本地视频／主页书签、密友会话隐藏；四项独立开关默认关闭，端上效果待真机验收
- 2.3-8：补齐仅看一次文字的消费状态与上报拦截，新增五次聊天对象重建回归；文字实际展示待真机验收
- 2.3-7：长视频广告章节自动跳过时隐藏原生跳过提示；包含仅看一次重复查看实验功能，新增行为待真机验收
- 通过 **双指长按** 或 **抖音设置** 进入设置界面
- 支持远程 JSON 批量下发配置
- 解析多种下载接口字段（视频、图片、音频、封面）
- 喜欢页默认空白，摇动并输入 4～6 位数字密码后显示列表

## 使用方式
- 打开抖音后 **双指长按** 进入设置
- 或在 **抖音设置** 中找到 DYYY 入口

### 喜欢页保护（2.3-4 修复版）

1. 在 DYYY「基本设置 → 喜欢页保护」设置并确认 4～6 位数字密码。双指长按设置页也提供同名入口。首次设置成功后自动开启保护。
2. 自己的「喜欢」标签保留，列表默认显示跟随抖音主题的“暂无喜欢的作品”空状态；在该页摇动手机，验证密码后显示内容。
3. 从列表打开视频再返回，保持本次解锁；切换标签、离开个人主页、切换账号或退后台后重新锁定。
4. 修改密码或关闭保护需要原密码。密码不参与配置导出，清除普通配置也不会重置密码。

该功能只控制当前设备的界面显示。若出现「未适配当前页面」提示，当前页面不能视为已受保护；请按 [设备验收清单](tests/like-privacy-device-checklist.md) 检查实际效果。

## 仅看一次重复查看（实验）

在 DYYY「隐私」中开启，默认关闭。尝试保留接收的仅看一次文字、图片和视频，供同一进程内再次查看；不恢复原生已判定失效的消息。关闭后，后续观看按原生消费流程处理，不保证自动补报之前拦截的记录。

目标环境为 **RootHide / iOS 16.5 / 抖音 39.8.0（build 398016）**。此功能尚待真机验收，跨进程保留与资源可用性未获验证，详见[验收清单](tests/watch-once-keep-device-checklist.md)。

## 下载增强、本地书签与密友会话（2.3-9）

四项默认关闭。原生设置入口如下；双指长按设置页也有对应开关和管理入口。

| 功能 | DYYY 设置路径 | 行为 |
| --- | --- | --- |
| 下载重试与图片兼容 | 增强设置 → 媒体保存 | 单视频、单图片和普通图集使用同一资源的 CDN 候选，含首次最多尝试 3 个地址；不删除签名参数、不切低清版本；图片按真实编码保存 |
| 显示下载速度与大小 | 增强设置 → 媒体保存 | 显示已下载／总大小和速度；未知总量明确标注，批量显示“当前文件”数据 |
| 视频／主页本地书签 | 增强设置 → 媒体保存 | 长按视频保存；主页原生菜单保存主页；“管理本地书签”支持搜索、左滑编辑分类与备注、删除 |
| 密友会话隐藏 | 基本设置 → 隐私 | 仅指定真实 UID 的私聊无未读时隐藏，有新消息时显示；管理名单或从对方主页菜单添加 |

书签与会话名单按当前抖音账号隔离，存入本机独立 JSON 文件，不参与普通配置导出。书签不保存媒体 URL，打开时通过宿主内部路由跳转；已删除或不可见的内容不能保证打开。会话隐藏只作用于消息列表，不修改收发、通知、搜索结果或原生未读数，群聊不隐藏；模型或未读信息无法识别时保留显示。

本轮下载增强接入统一视频／图片下载入口及普通图片批次；实况照片配对、音轨合并和独立评论语音下载沿用原有流程。此版本的本地策略测试、模拟宿主 Hook 回归与构建不能代替真机验收；真机需重点检查断网换源与取消、书签跳转、未读出现／读完重进隐藏，以及账号切换。

方案参考 [yxh41 的本地书签实现](https://github.com/yxh41/DYYY/tree/1e4b053d602406503c4f4a13964d166eed6f0809) 与 [ruizhe2013-lgtm 的会话隐藏规则](https://github.com/ruizhe2013-lgtm/DYYY/tree/9a20d7b3e38fc5b3c5c2d6b136f1148b8e9f17a1)，本仓库重新实现并限定为上述范围。

## 贡献者

<table>
  <tr>
    <td align="center"><a href="https://github.com/huami1314"><img src="https://github.com/huami1314.png?size=120" width="100px;" height="100px;" alt="huami1314"/></a><br /><sub><b>huami1314</b></sub></td>
    <td align="center"><a href="https://github.com/Wtrwx"><img src="https://github.com/Wtrwx.png?size=120" width="100px;" height="100px;" alt="Wtrwx"/></a><br /><sub><b>Wtrwx</b></sub></td>
    <td align="center"><a href="https://github.com/lihebgyee"><img src="https://github.com/lihebgyee.png?size=120" width="100px;" height="100px;" alt="lihebgyee"/></a><br /><sub><b>lihebgyee</b></sub></td>
    <td align="center"><a href="https://github.com/wahha2003"><img src="https://github.com/wahha2003.png?size=120" width="100px;" height="100px;" alt="wahha2003"/></a><br /><sub><b>wahha2003</b></sub></td>
    <td align="center"><a href="https://github.com/Nathalie-Annis"><img src="https://github.com/Nathalie-Annis.png?size=120" width="100px;" height="100px;" alt="Nathalie-Annis"/></a><br /><sub><b>Nathalie-Annis</b></sub></td>
  </tr>
  <tr>
    <td align="center"><a href="https://github.com/PaTTeeL"><img src="https://github.com/PaTTeeL.png?size=120" width="100px;" height="100px;" alt="PaTTeeL"/></a><br /><sub><b>PaTTeeL</b></sub></td>
    <td align="center"><a href="https://github.com/lihyee"><img src="https://github.com/lihyee.png?size=120" width="100px;" height="100px;" alt="lihyee"/></a><br /><sub><b>lihyee</b></sub></td>
    <td align="center"><a href="https://github.com/wwg135"><img src="https://github.com/wwg135.png?size=120" width="100px;" height="100px;" alt="wwg135"/></a><br /><sub><b>wwg135</b></sub></td>
    <td align="center"><a href="https://github.com/CW-1024"><img src="https://github.com/CW-1024.png?size=120" width="100px;" height="100px;" alt="CW-1024"/></a><br /><sub><b>CW-1024</b></sub></td>
    <td align="center"><a href="https://github.com/Wangin1996"><img src="https://github.com/Wangin1996.png?size=120" width="100px;" height="100px;" alt="Wangin1996"/></a><br /><sub><b>Wangin1996</b></sub></td>
  </tr>
  <tr>
    <td align="center"><a href="https://github.com/Patickhuang"><img src="https://github.com/Patickhuang.png?size=120" width="100px;" height="100px;" alt="Patickhuang"/></a><br /><sub><b>Patickhuang</b></sub></td>
    <td align="center"><a href="https://github.com/zhaoyuedong"><img src="https://github.com/zhaoyuedong.png?size=120" width="100px;" height="100px;" alt="zhaoyuedong"/></a><br /><sub><b>zhaoyuedong</b></sub></td>
    <td align="center"><a href="https://github.com/Huangbai233"><img src="https://github.com/Huangbai233.png?size=120" width="100px;" height="100px;" alt="Huangbai233"/></a><br /><sub><b>Huangbai233</b></sub></td>
    <td align="center"><a href="https://github.com/fries0710"><img src="https://github.com/fries0710.png?size=120" width="100px;" height="100px;" alt="fries0710"/></a><br /><sub><b>fries0710</b></sub></td>
    <td align="center"><a href="https://github.com/msm8976"><img src="https://github.com/msm8976.png?size=120" width="100px;" height="100px;" alt="msm8976"/></a><br /><sub><b>msm8976</b></sub></td>
  </tr>
  <tr>
    <td align="center"><a href="https://github.com/xiangfeidexiaohuo"><img src="https://github.com/xiangfeidexiaohuo.png?size=120" width="100px;" height="100px;" alt="xiangfeidexiaohuo"/></a><br /><sub><b>xiangfeidexiaohuo</b></sub></td>
    <td align="center"><a href="https://github.com/Mieing"><img src="https://github.com/Mieing.png?size=120" width="100px;" height="100px;" alt="Mieing"/></a><br /><sub><b>Mieing</b></sub></td>
    <td align="center"><a href="https://github.com/invalidunit"><img src="https://github.com/invalidunit.png?size=120" width="100px;" height="100px;" alt="invalidunit"/></a><br /><sub><b>invalidunit</b></sub></td>
    <td align="center"><a href="https://github.com/ways0210"><img src="https://github.com/ways0210.png?size=120" width="100px;" height="100px;" alt="ways0210"/></a><br /><sub><b>ways0210</b></sub></td>
    <td align="center"><a href="https://github.com/woqunimaxr"><img src="https://github.com/woqunimaxr.png?size=120" width="100px;" height="100px;" alt="woqunimaxr"/></a><br /><sub><b>woqunimaxr</b></sub></td>
  </tr>
  <tr>
    <td align="center"><a href="https://github.com/Sini921"><img src="https://github.com/Sini921.png?size=120" width="100px;" height="100px;" alt="Sini921"/></a><br /><sub><b>Sini921</b></sub></td>
    <td align="center"><a href="https://github.com/cbjn"><img src="https://github.com/cbjn.png?size=120" width="100px;" height="100px;" alt="cbjn"/></a><br /><sub><b>cbjn</b></sub></td>
    <td align="center"><a href="https://github.com/huami1214"><img src="https://github.com/huami1214.png?size=120" width="100px;" height="100px;" alt="huami1214"/></a><br /><sub><b>huami1214</b></sub></td>
    <td align="center"><a href="https://github.com/wangliang12138"><img src="https://github.com/wangliang12138.png?size=120" width="100px;" height="100px;" alt="wangliang12138"/></a><br /><sub><b>wangliang12138</b></sub></td>
    <td align="center"><a href="https://github.com/jiuwei95"><img src="https://github.com/jiuwei95.png?size=120" width="100px;" height="100px;" alt="jiuwei95"/></a><br /><sub><b>jiuwei95</b></sub></td>
  </tr>
  <tr>
    <td align="center"><a href="https://github.com/plplpmmmmh"><img src="https://github.com/plplpmmmmh.png?size=120" width="100px;" height="100px;" alt="plplpmmmmh"/></a><br /><sub><b>plplpmmmmh</b></sub></td>
    <td align="center"><a href="https://github.com/zooah212"><img src="https://github.com/zooah212.png?size=120" width="100px;" height="100px;" alt="zooah212"/></a><br /><sub><b>zooah212</b></sub></td>
  </tr>
</table>

## 远程配置

DYYY 可以通过远程 JSON 文件批量应用设置。默认下载地址在 `DYYYConstants.h` 中的 `DYYY_REMOTE_CONFIG_URL`。配置文件示例：

```json
{
    "mode": "DYYY_MODE_PATCH",
    "data": {
        "ExampleKey": true
    }
}
```

`mode` 字段可选，支持 `DYYY_MODE_PATCH` 和 `DYYY_MODE_REPLACE`，若省略则默认为补丁模式 (`DYYY_MODE_PATCH`)。

## 解析下载接口

### 示例1：多清晰度视频（含音频和封面）
```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "video_list": [
      {"url": "https://video.com/hd.mp4", "level": "高清"},
      {"url": "https://video.com/sd.mp4", "level": "标清"}
    ],
    "cover": "https://image.com/cover.jpg",
    "music": "https://audio.com/bgm.mp3",
    "images": [
      "https://image.com/extra1.jpg",
      "https://image.com/extra2.jpg"
    ]
  }
}
```

### 示例2：单个视频资源（含封面）
```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "video_url": "https://video.com/main.mp4",
    "cover": "https://image.com/thumbnail.jpg",
    "music_url": "https://audio.com/soundtrack.mp3"
  }
}
```

### 示例3：纯图片资源
```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "images": [
      "https://image.com/photo1.jpg",
      "https://image.com/photo2.jpg"
    ],
    "pics": "https://image.com/cover.png",
    "img": [
      "https://image.com/additional.jpg"
    ]
  }
}
```

### 示例4：混合资源（视频+图片）
```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "url": "https://video.com/short.mp4",
    "videos": [
      "https://video.com/extra.mp4"
    ],
    "cover": "https://image.com/poster.jpg",
    "images": [
      "https://image.com/screenshot1.png",
      "https://image.com/screenshot2.png"
    ]
  }
}
```

### 示例5：图集与实况
```json
{
  "code": 200,
  "msg": "success",
  "data": {
    "video_list": [
      {"url": "https://image.com/1.jpeg", "level": "【第1张】"},
      {"url": "https://video.com/1_live.mp4", "level": "【第1张实况】"},
      {"url": "https://image.com/2.jpeg", "level": "【第2张】"}
    ],
    "images": [
      "https://image.com/1.jpeg",
      "https://image.com/2.jpeg"
    ],
    "live_videos": [
      "https://video.com/1_live.mp4",
      null
    ],
    "cover": "https://image.com/cover.jpg"
  }
}
```

上例是 2 张图的图集，第 1 张带实况、第 2 张不带。

### 字段说明
| 字段名       | 类型       | 说明                               |
| ------------ | ---------- | ---------------------------------- |
| `video_list` | 对象数组   | 多清晰度选项，含`url`和`level`字段 |
| `videos`     | 字符串数组 | 多个视频资源的URL集合              |
| `video_url`  | 字符串     | 单个视频资源URL（优先使用字段）    |
| `video`      | 字符串     | 单个视频资源URL（备用字段）        |
| `url`        | 字符串     | 通用资源URL（视频优先）            |
| `cover`      | 字符串     | 封面图URL（主字段）                |
| `pics`       | 字符串     | 封面图URL（备用字段）              |
| `music`      | 字符串     | 背景音乐URL（主字段）              |
| `music_url`  | 字符串     | 背景音乐URL（备用字段）            |
| `images`     | 字符串数组 | 附加图片资源集合                   |
| `img`        | 字符串数组 | 附加图片资源集合（备用字段）       |
| `live_videos`| 数组       | 图集各张对应的实况视频，与 `images` 等长，无实况的位置为 `null` |

### `video_list` 行类型的判定规则

行的处理方式由它的 `url` 落在哪个数组决定，与 `level` 文案无关 —— 接口改文案模板不会影响客户端：

| 行 `url` 命中 | 处理 |
| ------------- | ---- |
| `images[]` 或 `img[]` | 按图片保存，落盘 `.jpg` |
| `live_videos[i]` | 与 `images[i]` 配对，存成 iOS 原生实况照片 |
| 都不命中 | 按视频保存，画质行与接口自定义的信息行都走这里 |

同一下标既给出静图行、又给出实况行时，只展示实况行：两行是同一张的两种形态，留着静图行会让人以为选它也能得到实况。因此 `【第2张】` 与 `【第2张实况】` 同时存在时，弹窗里只保留后者。

图集多于一项时会追加一行「保存全部」，文案随构成变化：全为静图是「保存全部图片」，全带实况是「保存全部实况」，两者混合是「保存全部图片和实况」，混合时每张各按自己的形态保存。

## 构建与打包

- 本地验证：

```bash
make clean package
```

- 默认打包为 rootless；切换其他方案：

```bash
make package                 # 默认 rootless
make package SCHEME=rootful
make package SCHEME=roothide
```

- CI/无人值守：

```bash
GITHUB_ACTIONS=true make package
```

## 许可证

详见 `LICENSE`。

## Star 趋势

<p align="center">
    <a href="https://star-history.com/#Wtrwx/DYYY">
        <img src="https://api.star-history.com/svg?repos=Wtrwx/DYYY&type=Date" width="75%" alt="Star History"></a>
</p>

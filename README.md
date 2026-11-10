# 糖葫芦 (THLRedLook)

<p align="left">
  <a href="https://github.com/never88gone/THLRedGuo/stargazers"><img src="https://img.shields.io/github/stars/never88gone/THLRedGuo?style=flat-square&logo=github&color=e02424" alt="GitHub Stars" /></a>
  <a href="https://github.com/never88gone/THLRedGuo/network/members"><img src="https://img.shields.io/github/forks/never88gone/THLRedGuo?style=flat-square&logo=github" alt="GitHub Forks" /></a>
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20tvOS%20%7C%20HarmonyOS%20%7C%20Windows%20%7C%20macOS-blue?style=flat-square" alt="Supported Platforms" />
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.44+-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter SDK" /></a>
  <a href="https://testflight.apple.com/join/rkvvdp7J"><img src="https://img.shields.io/badge/TestFlight-Public%20Beta-black?style=flat-square&logo=apple" alt="Apple TestFlight" /></a>
  <a href="https://t.me/tanghulutvos"><img src="https://img.shields.io/badge/Telegram-Group-26A5E4?style=flat-square&logo=telegram&logoColor=white" alt="Telegram Group" /></a>
</p>

## 项目定位

> ⚠️ **免责声明 (Disclaimer)**：
> 1. **仅供学习研究**：本项目仅供编程技术交流、Flutter 跨平台与 Apple tvOS 原生应用架构研究使用，严禁用于任何商业牟利或侵权用途；
> 2. **纯客户端工具，无内容存储**：本项目为纯本地端侧播放器工具，无需注册登录即可直接使用；开发者不搭建、不运营任何流媒体服务器，不提供、不存储、不分发任何音视频资源；
> 3. **网络数据版权归属**：应用中所有可访问的数据源均来源于第三方网络公开平台，其版权与知识产权均归原版权方所有，请自觉支持正版内容；
> 4. **责任限制**：用户使用本软件及自配数据源产生的一切法律责任及版权纠纷均由使用者自行承担，与本项目及其代码贡献者无关。

**糖葫芦**（工程标识：`THLRedLook`，Android 包名 / Application ID：`com.line.redlook`）是一款基于 **Flutter + Apple tvOS 原生 + HarmonyOS NEXT 原生** 打造的全平台独立流媒体与短剧聚合应用。

应用内无需注册账号或登录。数据请求、签名和解析由设备端 JS 数据源完成，媒体解码、流式解密等底层能力由客户端提供，无需搭建远程中转或中心化代理服务。

## JS 数据源

应用内置官方 `assets/sources/hongguo.js`，也可在数据源管理页面导入兼容的 JS 数据源。iOS、iPadOS 与 tvOS 的浏览和在线播放均通过 JS 数据源工作，用户无需准备或导入 Android APK。

独立导入请使用 [发布版 hongguo.js](https://github.com/never88gone/THLRedGuo/releases/download/official-source/hongguo.js)。

- **iOS / iPadOS**：进入「设置 → JS 数据源插件管理」管理数据源。
- **tvOS**：进入「设置 → 站源管理」查看当前 JS 版本、导入数据源网址和执行诊断。

收藏、历史和播放进度保存在设备端，并可通过 iCloud 在支持的平台间同步。
数据源脚本与应用源码持续同步维护更新，所有网络请求与解析在端侧直接驱动。

---

## 📲 公测与交流

- **🍏 Apple TestFlight 公测**：[加入 TestFlight 公测 (iOS / iPadOS / tvOS)](https://testflight.apple.com/join/rkvvdp7J)
- **💬 Telegram 官方群组**：[https://t.me/tanghulutvos](https://t.me/tanghulutvos) (`@tanghulutvos`)

---

## 界面预览

### 🖥️ 桌面端 (Windows / macOS)

| 桌面端宽屏分栏全景 | 桌面端高清播放与选集 |
| :---: | :---: |
| <img src="assets/screenshots/desktop_overview.png" width="440" alt="桌面端全景" /> | <img src="assets/screenshots/desktop_player.png" width="440" alt="桌面端播放器" /> |

### 📱 移动端 (iOS / Android)

| 首页发现与分类 | 搜索与关键词联想 | 热播短剧排行榜 |
| :---: | :---: | :---: |
| <img src="assets/screenshots/mobile_home.png" width="180" alt="首页发现" /> | <img src="assets/screenshots/mobile_search.png" width="180" alt="搜索联想" /> | <img src="assets/screenshots/mobile_rankings.png" width="180" alt="短剧榜单" /> |

| 剧集详情与选集 | 竖屏沉浸式播放 | 横屏全屏影院模式 |
| :---: | :---: | :---: |
| <img src="assets/screenshots/mobile_detail.png" width="180" alt="剧集详情" /> | <img src="assets/screenshots/mobile_player_portrait.png" width="180" alt="竖屏播放" /> | <img src="assets/screenshots/mobile_player_fullscreen.png" width="260" alt="横屏播放" /> |

### 🔴 鸿蒙原生端 (HarmonyOS NEXT)

| 鸿蒙端首页与流式分页 | 鸿蒙端短剧选集与沉浸播放 |
| :---: | :---: |
| <img src="assets/screenshots/harmonyos_home.png" width="220" alt="鸿蒙端首页" /> | <img src="assets/screenshots/harmonyos_player.png" width="220" alt="鸿蒙端播放器" /> |

### 📺 客厅大屏端 (Apple tvOS)

| tvOS 首页瀑布流 | tvOS 剧集详情与选集 |
| :---: | :---: |
| <img src="assets/screenshots/tvos_home.png" width="380" alt="tvOS首页" /> | <img src="assets/screenshots/tvos_detail.png" width="380" alt="tvOS详情" /> |

| tvOS 热播排行榜 | tvOS 全屏播放与控制层 |
| :---: | :---: |
| <img src="assets/screenshots/tvos_rankings.png" width="380" alt="tvOS榜单" /> | <img src="assets/screenshots/tvos_player.png" width="380" alt="tvOS播放器" /> |

---

## 平台支持矩阵

| 平台 | 架构与特性 | 交付产物 |
| :--- | :--- | :--- |
| **Android / Android TV** | 适配手机、折叠屏与电视大屏，支持竖屏滑动手势、画中画（PiP）浮窗与遥控器焦点导航 | 原生 Flutter + NDK，输出 APK / AAB |
| **iOS / iPadOS** | 原生画中画（PiP）、后台续播、深色模式自适应、双屏折叠设备适配与 iCloud 进度同步 | 支持 TestFlight 一键安装 / IPA |
| **HarmonyOS NEXT** | 华为纯血鸿蒙原生工程（`harmonyos/`），纯 ArkTS + ArkUI 架构，集成 OpenSSL CENC 硬件级流式解密与 AVPlayer 硬解 | 签名 HAP 安装包 |
| **Apple tvOS** | 独立原生大屏工程（`tvos/`），SwiftUI + Siri Remote 焦点引擎 + AVKit 原生渲染 | 独立 Xcode 工程，输出 tvOS IPA |
| **Windows / macOS** | 桌面端大屏自适应分栏视窗，支持 libmpv 硬件解码与键盘方向键快捷操作 | 免安装绿色便携包 / PKG |

---

## 核心功能

- 📺 **全端硬件级解码**：iOS / tvOS / HarmonyOS 原生支持加密短剧边下边解流式播放，多清晰度自适应切换、实时弹幕与连播预加载。
- 📱 **多端手势与画中画**：手机竖屏上下滑换集、长按 3 倍速快进；横屏手势精准调节音量/亮度/进度；支持 iOS 与 Android 系统级画中画（PiP）小窗后台接续。
- 🔍 **分类检索与无限分页**：真人剧、漫剧、AI短剧多分类无缝切换；触底流式无限分页；支持实时联想搜索与本地历史管理。
- 🎬 **剧集详情与多季聚合**：官方系列多季短剧智能聚合展示与快速选集，正序/倒序轻松切换。
- 🗂️ **本地追剧与断点续播**：纯端侧保存追剧收藏，秒级断点续播，支持最近观看记录管理。
- 🔒 **隐私保护与专属空间**：内置九宫格图形手势锁屏、后台多任务防窥虚化及独立私密短剧库。

---

## 构建说明

### Flutter 客户端 (Android / iOS / Windows / macOS)

```bash
# 获取依赖与启动运行
fvm flutter pub get
fvm flutter run

# 构建 Windows x64 发布包 (产物位于 build/windows/x64/runner/Release/)
fvm flutter build windows --release
```

### 鸿蒙原生端 (HarmonyOS NEXT)

```bash
cd harmonyos

# 执行构建并输出签名 HAP (产物位于 entry/build/default/outputs/default/entry-default-signed.hap)
hvigorw --mode module -p module=entry@default -p product=default assembleHap
```

### Apple tvOS 原生端

```bash
cd tvos

# 打开 Xcode 编译或使用 fastlane 打包
open THLRedLook.xcodeproj
```

---

## 📈 Star 历史趋势

<a href="https://star-history.com/#never88gone/THLRedGuo&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=never88gone/THLRedGuo&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=never88gone/THLRedGuo&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=never88gone/THLRedGuo&type=Date" />
 </picture>
</a>

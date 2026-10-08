# DeepSeek Harness Desktop for macOS (DSH Desktop)

[![Platform](https://img.shields.io/badge/platform-macOS%2013.0%2B-lightgrey.svg?style=flat-square)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg?style=flat-square)](https://swift.org)
[![Architecture](https://img.shields.io/badge/arch-Universal%202%20(Intel%20%2B%20Apple%20Silicon)-blue.svg?style=flat-square)](#从源码构建)
[![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat-square)](LICENSE)

[English](README.md) | [中文说明](README.zh-CN.md)

专为本地 [DeepSeek Harness](https://github.com/deepseek-ai) Web 服务 (`dsh web`) 打造的超轻量级 macOS 原生桌面外壳（发布版二进制体积 < 500 KB），基于 Swift、AppKit 与 WebKit (WKWebView) 构建。

旨在完美替代 Windows 端的 WinForms/WebView2 外壳，彻底摆脱传统 Electron 框架动辄 150+ MB 的体积与沉重资源开销。

---

## 核心特性

- **极致轻量与闪电启动**：纯原生二进制体积小于 500 KB，极低内存占用，秒级即开即用。
- **Universal 2 通用二进制**：完美兼容 Apple Silicon (M1/M2/M3/M4) 与 Intel (x86_64) 双架构。
- **现代原生的视觉融合**：采用 `fullSizeContentView` 与沉浸式透明标题栏，自然融入 macOS 系统美学。
- **macOS 原生多标签页**：支持系统原生多标签模式 (`Cmd + T`)，在单个窗口内并行管理多个会话。
- **全局快捷键快速呼出**：随时按下 `Option + Space` 快速显示/隐藏主窗口，呼出时自动聚焦输入框。
- **系统菜单栏 (Menu Bar) 伴侣**：实时显示后端服务器连接状态、快速切换配置方案 (Profile)、一键呼出窗口。
- **双向原生桥接能力 (`WKScriptMessageHandler`)**：
  - 在系统默认终端打开当前工程目录 (`Cmd + Shift + T`)。
  - 在 Finder 中定位并显示项目文件 (`Cmd + Shift + R`)。
  - 独立控制台日志监视窗口 (`Cmd + Shift + L`)，实时捕获 WebKit/插件日志。
- **原生系统通知集成**：Agent 轮次结束或后台任务执行完毕时，发送系统级横幅通知提示。
- **本地服务生命周期守护**：自动探查本地 `dsh` 可执行文件位置，探测端口就绪状态，优雅管理进程退出。

---

## 系统环境要求

- **操作系统**：macOS 13.0 (Ventura) 或更高版本
- **硬件架构**：Apple Silicon (`arm64`) 或 Intel (`x86_64`)
- **后台依赖**：本地已安装可用的 `dsh` CLI 命令（运行于 `http://127.0.0.1:3080`）

---

## 快速安装使用

前往 [GitHub Releases](../../releases) 下载最新版本的 `.dmg` 或 `.app` 安装包。

1. 打开下载好的 `DeepSeek Harness.dmg` 镜像文件。
2. 将 **DeepSeek Harness** 图标拖拽至 `/Applications` (应用程序) 文件夹。
3. 启动应用。若本地已在 3080 端口运行 `dsh web`，将自动即时连接；若未启动，应用将协助就绪。

---

## 从源码构建

### 前置准备

- 已安装 Xcode 15.0+ 或包含 Swift 6.0 工具链的 Command Line Tools。
- macOS 13.0+ SDK 环境。

### 构建指令

克隆代码仓库后，可通过 SPM 或内置构建脚本进行编译：

```bash
git clone https://github.com/your-username/dsh-desktop-macos.git
cd dsh-desktop-macos

# 本地 Intel x86_64 快速构建:
./scripts/build-intel.sh

# Universal 2 (Intel + Apple Silicon) 正式构建:
./scripts/build-universal.sh

# 打包为可分发的 DMG 安装镜像:
./scripts/package-dmg.sh

# 运行轻量自检诊断测试:
swift run DSHDesktopCheck
```

编译生成文件位于：
- 应用程序包：`dist/DSHDesktop.app`
- 可执行二进制：`dist/DSHDesktop.app/Contents/MacOS/DSHDesktop`
- DMG 安装镜像：`dist/DeepSeek Harness.dmg`

---

## 快捷键速查

| 快捷键 | 功能说明 |
|---|---|
| `Option + Space` | 快速呼出 / 隐藏应用主窗口（全局热键） |
| `Cmd + T` | 新建原生会话标签页 |
| `Cmd + R` | 强制刷新 WebKit 视图并清理页面缓存 |
| `Cmd + Shift + T` | 在 Terminal.app 终端中打开当前工作区 |
| `Cmd + Shift + R` | 在 Finder 访达中查看工作区目录 |
| `Cmd + Shift + L` | 打开插件与 WebKit 运行时日志监视器 |
| `Cmd + +` / `Cmd + -` | 页面视图放大 / 缩小 |
| `Cmd + 0` | 恢复默认缩放比例 (90%) |

---

## 架构简要总览

```text
┌─────────────────────────────────────────────────────────────┐
│                       macOS 系统环境                        │
│   (AppKit Event Loop, NotificationCenter, NSWorkspace)     │
└───────────────▲─────────────────────────────▲───────────────┘
                │                             │
    ┌───────────┴──────────────┐  ┌───────────┴──────────────┐
    │     NSApplication        │  │     NSStatusItem         │
    │  (AppDelegate / main)    │  │   (MenuBarController)    │
    └───────────┬──────────────┘  └──────────────────────────┘
                │
    ┌───────────▼──────────────┐
    │  MainWindowController    │
    │  (NSWindow, 原生标签页)  │
    └───────────┬──────────────┘
                │
    ┌───────────▼─────────────────────────────────────────────┐
    │                 WebViewController                       │
    │  ┌───────────────────────────────────────────────────┐  │
    │  │                   WKWebView                       │  │
    │  │  - 地址: http://127.0.0.1:3080                     │  │
    │  │  - 原生桥接: openTerminal, revealInFinder 等      │  │
    │  └───────────────────────────────────────────────────┘  │
    └─────────────────────────────────────────────────────────┘
```

更详细的架构设计与模块分层解析，请参阅 [ARCHITECTURE.md](ARCHITECTURE.md)。

---

## 开源协议

本项目基于 [MIT License](LICENSE) 协议开源。

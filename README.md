# Katib 🎙️ كَاتِب

<p align="center">
  <b>简体中文</b> | <b><a href="README_en.md">English</a></b>
</p>

<p align="center">
  <a href="https://www.apple.com/macos/"><img src="https://img.shields.io/badge/platform-macOS%2014.2%2B-lightgrey.svg" alt="Platform"></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/language-Swift%206-orange.svg" alt="Language"></a>
  <a href="https://developer.apple.com/xcode/swiftui/"><img src="https://img.shields.io/badge/framework-AppKit%20%7C%20SwiftUI-blue.svg" alt="Framework"></a>
  <a href="https://github.com/linrol/katib/releases"><img src="https://img.shields.io/badge/binary-Universal%202%20(Intel%20%2B%20Apple%20Silicon)-success.svg" alt="Universal 2"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License"></a>
</p>

**Katib**（阿拉伯语：**كَاتِب**，意为“书记官 / 记录者”）是一款专为 macOS 打造的**纯端侧离线、全局会议双向实时语音转录与字幕浮窗工具**。

告别昂贵的在线转写 API 与隐私泄露担忧；告别安装配置虚拟音频驱动（如 BlackHole / Soundflower）的繁琐流程。无论是跨国线上会议、技术研讨网课、即时通话还是播客音视频，Katib 都能在本地芯片上毫秒级将声音转化为精准文字！

---

## ✨ 核心特性

- **🧠 SenseVoice 纯端侧神经引擎（无需联网，100% 隐私安全）**：
  - 基于高精度语音大模型 SenseVoice 原生离线推理，由端侧芯片加速；
  - 零网络请求、零云端 API 依赖、商业机密与会议语音 100% 留存在本地设备。
- **🔊 ScreenCaptureKit 系统级音频无感内录**：
  - 直接调用 macOS 官方 `ScreenCaptureKit` 系统内录通道；
  - **彻底告别虚拟声卡**：无需配置 BlackHole、Soundflower 或任何第三方音频驱动，直接截获 Zoom、Teams、腾讯会议、飞书、Google Meet、YouTube 等任意软件的远端人声。
- **🎙️ 双向会话智能监听（Remote + Local）**：
  - **同时听双方**：支持「仅远端音频」、「仅本地麦克风」与「双向混合监听（Both）」三种模式；
  - 远端对方发言（`[Remote]` 蓝标）与本地自身发言（`[Local]` 绿标）独立打标、并行动态转写。
- **💬 灵动悬浮实时字幕 HUD（Live Subtitles）**：
  - 采用半透明毛玻璃悬浮窗设计，支持全屏置顶与跨 Space 漫游；
  - 自由拖拽与调整尺寸，实时滚动呈现双向对话；
  - 一键快速复制所有历史对话文本。
- **⚡ 极致轻量原生体验**：
  - 纯原生 Swift + SwiftUI + AppKit 架构，启动毫秒级响应，CPU 与内存占用极低；
  - 菜单栏托盘轻量常驻，状态指示一目了然。
- **🔄 内置智能增量更新体系**：
  - 启动后自动检查 GitHub 最新 Release，支持一键在菜单栏下载 DMG 并热重启更新。

---

## 🚀 快速安装

### 方式一：直接下载 DMG 安装（推荐）
前往 [GitHub Releases](https://github.com/linrol/katib/releases/latest) 下载最新版本的 `Katib-x.x.x.dmg`，双击拖入 `Applications` 即可。

### 方式二：通过 Homebrew Cask 安装
```bash
brew tap linrol/tap
brew install --cask katib
```

### 方式三：源码一键编译并安装
```bash
git clone https://github.com/linrol/katib.git
cd katib
./scripts/install.sh
```

---

## 🔒 权限要求与系统配置

首次启动 Katib 并开始监听时，macOS 系统将提示以下授权请求（或前往 **系统设置 > 隐私与安全性** 手动开启）：

1. **屏幕录制权限（Screen Recording）**：
   - **用途**：Katib 通过 Apple 官方 `ScreenCaptureKit` 原生接口抓取会议软件（如 Teams、Zoom、浏览器）的输出音频流，**绝不会录制或上传您的任何屏幕图像数据**。
2. **麦克风权限（Microphone）**：
   - **用途**：当开启「本地麦克风」或「双向监听」模式时，用于采集您本人的实时说话音频。

---

## 🛠️ 项目架构

Katib 采用模块化解耦设计：
- **`Sources/KatibKit/Engine/`**：
  - `LocalSenseVoiceEngine`：SenseVoice 本地模型加载与推理调度；
  - `RemoteScreenCaptureEngine`：基于 ScreenCaptureKit 的纯音频流截获器；
  - `LocalMicAudioEngine`：基于 AVAudioEngine 的本地麦克风采集器；
  - `AudioStreamTranscriber`：流式音频切片、VAD 静音检测与动态分词引擎；
  - `Mono16kResampler`：标准 16kHz 单声道重采样器。
- **`Sources/KatibKit/Update/`**：
  - `KatibUpdateManager`：GitHub Release 检查、自动更新与安装。
- **`Sources/KatibKit/UI/`**：
  - `KatibFloatingHUD`：实时无焦点毛玻璃字幕浮窗；
  - `KatibSettingsView`：监听模式设置与配置面板。
- **`Sources/Katib/`**：
  - `KatibApp`、`AppDelegate` 与菜单栏状态栏交互。

---

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 开源协议发布。


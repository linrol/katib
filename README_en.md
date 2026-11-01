# Katib 🎙️ كَاتِب

<p align="center">
  <b><a href="README.md">简体中文</a></b> | <b>English</b>
</p>

<p align="center">
  <a href="https://www.apple.com/macos/"><img src="https://img.shields.io/badge/platform-macOS%2014.2%2B-lightgrey.svg" alt="Platform"></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/language-Swift%206-orange.svg" alt="Language"></a>
  <a href="https://developer.apple.com/xcode/swiftui/"><img src="https://img.shields.io/badge/framework-AppKit%20%7C%20SwiftUI-blue.svg" alt="Framework"></a>
  <a href="https://github.com/linrol/katib/releases"><img src="https://img.shields.io/badge/binary-Universal%202%20(Intel%20%2B%20Apple%20Silicon)-success.svg" alt="Universal 2"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License"></a>
</p>

**Katib** (Arabic: **كَاتِب**, meaning "Scribe / Writer / Transcriber") is a lightweight, fully on-device, and private real-time meeting speech transcription & live subtitles tool designed natively for macOS.

Say goodbye to expensive cloud transcription APIs and privacy risks, and say goodbye to cumbersome virtual audio routing drivers like BlackHole or Soundflower. Whether you are attending international remote meetings, online lectures, podcasts, or video calls, Katib transcribes spoken words into text locally with millisecond latency.

👉 **[Get Katib Pro Lifetime License ($9.99)](https://www.creem.io/payment/prod_7QcjNL9GaMP6RCGo3NNENp)** · One-time purchase, lifetime updates, up to 3 Macs!

---

## ✨ Features

- **🧠 SenseVoice On-Device Neural Engine (Offline & 100% Private)**:
  - Powered by high-accuracy speech model SenseVoice running entirely on local Apple Silicon / Intel processors;
  - Zero cloud dependencies, zero API keys required; commercial secrets and meeting conversations stay strictly on your device.
- **🔊 Driverless Internal Audio Capture via ScreenCaptureKit**:
  - Leverages macOS native `ScreenCaptureKit` to stream system audio directly;
  - **No virtual audio drivers needed**: seamless audio capturing from Zoom, Microsoft Teams, Tencent Meeting, Feishu, Google Meet, YouTube, and any browser.
- **🎙️ Intelligent Bidirectional Transcription (Remote + Local)**:
  - Supports three capture modes: **Remote Only**, **Local Mic**, and **Bidirectional (Both)**;
  - Remote speaker (`[Remote]` Blue tag) and your microphone voice (`[Local]` Green tag) are recognized and tagged concurrently in real-time.
- **💬 Floating Real-Time Subtitles HUD**:
  - Translucent frosted glass floating window that stays on top and floats across Spaces;
  - Freely resizable and draggable;
  - One-click copy for all transcribed sentences.
- **⚡ Native & Lightweight**:
  - Built with pure Swift + SwiftUI + AppKit, near-instant launch, and minimal CPU/memory footprint;
  - Sits unobtrusively in the macOS menu bar.
- **🔄 Built-In Auto Updater**:
  - Checks GitHub Releases automatically on launch and enables one-click download & restart in the menu bar.

---

## ⭐️ Katib Pro Lifetime Benefits

The core of Katib is free and open-source. For power users and frequent meeting attendees, **Katib Pro** unlocks advanced superpowers:

- **🧠 Unlimited Meeting Duration**: Remove free session length limits; transcribe long hours of international meetings continuously in real-time.
- **📄 Meeting Notes & Subtitle Export**: One-click export of transcripts into formatted Markdown/TXT meeting notes and standard SRT bilingual subtitles with timestamps.
- ** Multi-Mac Authorization & Lifetime Device Migration**: One license key supports simultaneous activation on up to **3 personal Macs**, transferrable anytime with lifetime free updates.

👉 **[Upgrade to Katib Pro Lifetime for $9.99 ↗](https://www.creem.io/payment/prod_7QcjNL9GaMP6RCGo3NNENp)**

---

## 🚀 Installation

### Option 1: Direct Download (Recommended)
Download the latest `Katib-x.x.x.dmg` from [GitHub Releases](https://github.com/linrol/katib/releases/latest) and drag it to your `Applications` folder.

### Option 2: Homebrew Cask
```bash
brew tap linrol/tap
brew install --cask katib
```

### Option 3: Build from Source
```bash
git clone https://github.com/linrol/katib.git
cd katib
./scripts/install.sh
```

---

## 🔒 Permissions

When you start Katib for the first time, macOS will ask for the following permissions:

1. **Screen Recording**:
   - **Purpose**: Katib uses Apple's official `ScreenCaptureKit` API to stream audio output from meeting apps. **Katib never records or inspects your screen pixels**.
2. **Microphone**:
   - **Purpose**: Used only when capturing your local voice in "Local Mic" or "Both" mode.

---

## 📄 License

Katib is open-source software licensed under the [MIT License](LICENSE).


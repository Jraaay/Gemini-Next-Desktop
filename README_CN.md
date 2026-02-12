# GeminiNext

<div align="center">
  <img src="resources/logo.svg" alt="GeminiNext Logo" width="120" height="120">

  <h3>更轻快、更纯净、更懂 macOS 的 Gemini 非官方桌面客户端</h3>
  
  <p>
    <img src="https://img.shields.io/badge/Platform-macOS%2014.0%2B-blue?logo=apple&style=flat-square" alt="Platform">
    <img src="https://img.shields.io/badge/Language-Swift-orange?logo=swift&style=flat-square" alt="Language"> <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License">
    <a href="https://github.com/Jraaay/GeminiNext/releases">
      <img src="https://img.shields.io/github/v/release/Jraaay/GeminiNext?style=flat-square" alt="Release">
    </a>
  </p>

  <p>
    <strong>简体中文</strong> |
    <a href="./README.md">English</a>
  </p>
</div>

## 📸 界面预览

<div align="center">
  <p><strong>主界面</strong></p>
  <img src="resources/Main_CN.png" width="600" alt="主界面">
  <br><br>
  <p><strong>设置界面</strong></p>
  <img src="resources/Setting_CN.png" width="600" alt="设置界面">
</div>

## 💡 为什么选择 GeminiNext？

不同于基于 Electron 的庞大应用，GeminiNext 坚持使用原生 SwiftUI 构建。我们拒绝内存占用过高和启动缓慢，致力于提供像系统内置应用一样的丝滑体验。

### 🚀 核心优势

- 极致性能：无 Electron 运行时，内存占用极低，极速启动。
- 无缝集成：全局快捷键配合窗口置顶，让 AI 随时待命。
- 专注体验：自动聚焦输入框、完美兼容 macOS 输入法（IME），告别网页端的交互滞后。

## ✨ 功能特性

### 🖥️ 系统级深度融合

- 全局热键 — 默认 `Ctrl + `` 一键唤起/隐藏，支持自定义。
- 开机自启 — 登录系统自动启动，随时准备对话。
- 持久化登录 — 基于安全容器存储，关闭窗口无需反复登录。

### ⚡ 生产力增强

- 智能置顶 — 支持窗口始终浮于最前。
- 超时重置 — 长时间在后台后自动开启新对话。
- 自动聚焦 — 窗口激活时自动聚焦输入框。

### 🛠️ 高级定制

- 多语言支持 — 界面原生支持多语言，随系统自动切换。
- 自定义 UA — 灵活配置浏览器标识。
- 原生渲染 — 基于高效的 WKWebView。

## 📦 安装指南

### 方式一：直接下载 (推荐)

前往 [Releases](https://github.com/Jraaay/GeminiNext/releases) 下载对应架构的安装包：

* **Apple Silicon (M1/M2/M3/M4)** → `GeminiNext-vX.X.X-arm64.dmg`
* **Intel 处理器** → `GeminiNext-vX.X.X-x86_64.dmg`

### 方式二：从源码构建

若要自行编译，请确保开发环境满足：**macOS 14.0+** 且安装了 **Xcode 16.0+**。

```bash
git clone https://github.com/Jraaay/GeminiNext.git
cd GeminiNext
open GeminiNext.xcodeproj
```

在 Xcode 中选择目标设备，按下 `Cmd + R` 即可运行。

## ⌨️ 快捷键速查

| 快捷键                         | 功能                            |
| ------------------------------ | ------------------------------- |
| <kbd>Ctrl</kbd> + <kbd>`</kbd> | 呼出/隐藏窗口（可在设置中更改） |
| <kbd>Cmd</kbd> + <kbd>R</kbd>  | 刷新页面                        |
| <kbd>Cmd</kbd> + <kbd>[</kbd>  | 后退                            |
| <kbd>Cmd</kbd> + <kbd>]</kbd>  | 前进                            |
| <kbd>Cmd</kbd> + <kbd>W</kbd>  | 隐藏窗口                        |
| <kbd>Cmd</kbd> + <kbd>,</kbd>  | 打开设置                        |

## ⚙️ 设置项

| 选项           | 说明                  | 默认值                         |
| -------------- | --------------------- | ------------------------------ |
| 后台超时时间   | 超时后自动开启新对话  | 10 分钟                        |
| 登录时自动启动 | 开机自动运行          | 关闭                           |
| 窗口始终置顶   | 保持窗口在最前方      | 关闭                           |
| 全局快捷键     | 呼出/隐藏窗口的快捷键 | <kbd>Ctrl</kbd> + <kbd>`</kbd> |
| 语言           | 界面显示语言          | 跟随系统                       |
| User-Agent     | 自定义浏览器标识      | Safari UA                      |

## 🛠️ 技术栈

* **SwiftUI** — 现代化的声明式界面框架
* **WKWebView** — 高性能 Web 渲染引擎
* **Carbon Events** — 底层全局热键注册方案
* **String Catalog** — 苹果官方推荐的多语言管理方案

## 📄 开源协议

本项目基于 [MIT License](./LICENSE) 协议开源。

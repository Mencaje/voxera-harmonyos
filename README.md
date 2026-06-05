# Voxera for HarmonyOS（Voxera 鸿蒙版）2.0

[![License: LGPL v2.1+](https://img.shields.io/badge/License-LGPL%20v2.1%2B-blue.svg)](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html)
[![Platform](https://img.shields.io/badge/Platform-Phone%20%7C%20Tablet%20%7C%202in1%20PC-green.svg)](#1-版本演进与产品范围)
[![Version](https://img.shields.io/badge/Version-2.0.0-orange.svg)](AppScope/app.json5)

**仓库地址：** <https://github.com/Mencaje/voxera-harmonyos>

Voxera 鸿蒙版是在开源引擎 **[Luanti](https://www.luanti.org/)**（[luanti-org/luanti](https://github.com/luanti-org/luanti)）基础上移植、修改而成的 **HarmonyOS / OpenHarmony 全平台**方块沙盒**客户端**。

| 版本 | 支持平台 | 核心变化 |
|------|----------|----------|
| **1.0** | 仅 **2in1 PC**（键鼠） | 首版开源：XComponent 渲染、键鼠单路径、Luanti Lua 主菜单 |
| **2.0** | **手机 + 平板 + 2in1 PC** | 手机全栈自研 ArkUI；触屏交互引擎；合规门控；双构建产物（HarmonyOS / OpenHarmony） |

本 README 是面向贡献者与读者的**完整架构导读**；法律与许可说明见 [`NOTICE.md`](NOTICE.md)、[`COPYING.LESSER`](COPYING.LESSER)。平台速查见 [`docs/PLATFORM.md`](docs/PLATFORM.md)。

---

## 图例：代码归属（阅读下文时请对照）

| 标记 | 含义 |
|------|------|
| **🟦 Luanti** | 上游 Luanti 引擎/客户端源码（LGPL-2.1-or-later），本仓库 `luanti/` 为主体 |
| **🟩 Voxera 移植** | 为鸿蒙全平台新增或修改的衍生代码（仍属 LGPL 衍生作品） |
| **🟧 鸿蒙原生 / ArkTS** | HarmonyOS / OpenHarmony SDK、ArkUI、系统 Ability、NAPI、XComponent 等 |
| **🟪 第三方** | 其他开源组件（如 SDL2 鸿蒙 fork、预编译静态库） |
| **📱 手机自研 UI** | 2.0 新增：ArkUI 组件层，替代手机端大部分 Luanti formspec / tabview |

---

## 目录

1. [版本演进与产品范围](#1-版本演进与产品范围)
2. [全平台能力矩阵（2.0）](#2-全平台能力矩阵20)
3. [总体架构（五层 + 手机原生 UI）](#3-总体架构五层--手机原生-ui)
4. [分平台详解：手机 / 平板 / PC](#4-分平台详解手机--平板--pc)
5. [冷启动：双层启动窗](#5-冷启动双层启动窗)
6. [输入系统：键盘 / 鼠标 / 触屏](#6-输入系统键盘--鼠标--触屏)
7. [手机自研 UI 与 Lua 桥接](#7-手机自研-ui-与-lua-桥接)
8. [手机背包与 Formspec 交互](#8-手机背包与-formspec-交互)
9. [目录与文件导读](#9-目录与文件导读)
10. [Luanti 侧鸿蒙补丁清单](#10-luanti-侧鸿蒙补丁清单)
11. [构建、资源打包与依赖](#11-构建资源打包与依赖)
12. [许可证与上游链接](#12-许可证与上游链接)
13. [附录](#13-附录)

---

## 1. 版本演进与产品范围

### 1.1 从 1.0 到 2.0：发生了什么？

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Voxera 1.0（2025 首版开源）                                                  │
│  ─────────────────────────                                                  │
│  • 目标设备：HarmonyOS PC（2in1）                                            │
│  • 输入：键盘 + 鼠标（ArkUI onKeyPreIme 单路径注入 SDL）                       │
│  • UI：Luanti 内置 Lua 主菜单 / formspec / 暂停菜单（Irrlicht 渲染）          │
│  • 窗口：隐藏系统标题栏 + WindowDecorCapsule 毛玻璃底托                        │
│  • 构建：OpenHarmony API 20，x86_64 模拟器 / ARM 真机                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ 2.0 大更新
┌─────────────────────────────────────────────────────────────────────────────┐
│  Voxera 2.0（当前主线）                                                       │
│  ─────────────────────                                                      │
│  • 目标设备：手机（default）+ 平板（tablet）+ 2in1 PC（2in1）                 │
│  • 手机：整套 ArkUI 自研 UI（主菜单、设置、内容、暂停、控件层）                 │
│  • 手机：C++ 触屏分发（视角/挖掘/放置/快捷栏）+ 虚拟摇杆注入 WASD               │
│  • 手机：背包 toggle、原生文本输入、放大 tooltip、tap-select 背包               │
│  • 平板：沉浸横屏 + 触屏 overlay + 沿用 Luanti Lua UI                        │
│  • PC：保留 1.0 键鼠体验 + zip 拖拽安装                                        │
│  • 合规：法律声明 + 健康游戏声明（三端独立布局）                                │
│  • 构建：双 product — HarmonyOS 6.0.2(22) 商用手机 + OpenHarmony 6.0.0(20) PC │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 产品标识

| 项目 | 说明 |
|------|------|
| **包名** | `com.Voxera.mencaje`（`AppScope/app.json5`） |
| **版本** | **2.0.0**（`versionCode` 1000000） |
| **设备类型** | `default`（手机）、`tablet`（平板）、`2in1`（PC）— 见 `entry/src/main/module.json5` |
| **屏幕方向** | 全局 **横屏**（`orientation: landscape`） |
| **Native ABI** | **arm64-v8a** + **x86_64**（同一 HAP 双架构） |
| **SDK 产物** | `default` product → **HarmonyOS** API 22；`oh` product → **OpenHarmony** API 20 |

### 1.3 平台检测链路

运行时平台由 **ArkTS → C++ → Lua** 三处一致识别：

```
deviceInfo.deviceType（HarmonyOS 系统）
        │
        ▼  Game.ets aboutToAppear（引擎线程启动前）
setDeviceFormFactor()  ──NAPI──▶  ohosSetDeviceFormFactor()
        │                              │
        ▼                              ▼
DeviceFormFactor.current()      ohosApplyClientDefaults()
  Phone / Tablet / Pc2in1         touch_gui、HUD 缩放等
        │                              │
        ▼                              ▼
合规页 / 窗口策略路由            Lua 全局 DEVICE_FORM_FACTOR
```

| `deviceInfo.deviceType` | 归一化值 | `DeviceFormFactor` | 引擎 `touch_gui` |
|-------------------------|----------|--------------------|------------------|
| `default` / 其他 | `phone` | Phone | **true** |
| `tablet` | `tablet` | Tablet | false |
| `2in1` | `2in1` | Pc2in1 | false |

关键文件：🟩 `entry/src/main/ets/util/DeviceFormFactor.ets`、🟩 `luanti/src/porting_ohos.cpp`、🟦 `luanti/src/script/cpp_api/s_base.cpp`（暴露 `DEVICE_FORM_FACTOR` 给 Lua）。

---

## 2. 全平台能力矩阵（2.0）

### 2.1 总览对比表

| 能力 | 📱 手机 | 📱 平板 | 🖥️ PC（2in1） | 说明 |
|------|---------|---------|---------------|------|
| **主菜单 UI** | 📱 **ArkUI 自研** | 🟦 Luanti Lua | 🟦 Luanti Lua | 手机不再显示 Irrlicht tabview |
| **本地游戏列表** | 📱 `PhoneLocalGamePanel` | 🟦 tab_local | 🟦 tab_local | 手机原生世界列表 + 创建/模组 |
| **设置 / 内容 / 关于** | 📱 `PhoneMoreMenuScreen` | 🟦 Lua 对话框 | 🟦 Lua 对话框 | 手机四圆点菜单 |
| **首次游戏安装** | 📱 `PhoneGameInstallPanel` | zip 拖拽 / 选择器 | zip 拖拽 / 选择器 | 手机专用安装门控 |
| **暂停菜单（单人）** | 📱 **ArkUI 原生** | 🟦 Lua formspec | 🟦 Lua formspec | 手机 Esc/四圆点 → 原生卡片 |
| **移动控制** | 虚拟摇杆 + 跳跃键 | 触屏 overlay + 键鼠 | 键盘 WASD | 手机摇杆注入 KEYCODE |
| **视角控制** | 触屏滑动 | 触屏滑动 | 鼠标相对移动 | C++ `ohos_touch_dispatch` |
| **挖掘 / 放置** | 长按挖 / 短按放 | 同左 + 鼠标 | 鼠标左右键 | 非 Luanti TouchControls |
| **快捷栏** | 点击选中 / 长按丢弃 | 滚轮 / 触屏 | 滚轮 | C++ hotbar hit-test |
| **背包** | 📱 按钮 toggle + 放大 UI | 键 / formspec | 键 / formspec | 图标 backpack ↔ xmark |
| **Formspec 文本框** | 📱 原生键盘 overlay | Irrlicht 输入 | Irrlicht 输入 | UI request kind=8 |
| **物品 tooltip** | 放大 1.55× 字体 | 标准 | 标准 | 手机专用缩放 |
| **窗口装饰** | 沉浸全屏 | 沉浸全屏 | 隐藏标题栏 + Capsule | 2in1 专用 `WindowDecorCapsule` |
| **法律 / 健康声明** | 全屏 ArkUI 面板 | 子窗口对话框 | 子窗口对话框 | 三端独立布局 |
| **震动反馈** | ✅ 挖掘时 | ❌ | ❌ | kind=7 |
| **Documents 镜像** | 延迟授权 | 可用 | 可用 | 华为 vs OH fork 检测 |
| **典型构建 product** | `default`（HarmonyOS） | 两者皆可 | `oh`（OpenHarmony） | 见 §11 |

### 2.2 已实现 vs 暂未实现

| 平台 | ✅ 2.0 已实现 | ⏳ 暂未作为主线 / 已知限制 |
|------|--------------|---------------------------|
| **手机** | 自研主菜单、游戏内控件、原生暂停、背包 toggle、tap-select 背包、原生文本输入、放大 tooltip、触屏视角/挖掘/放置、快捷栏 touch、合规门控、HarmonyOS 商用签名脚本 | 多人游戏 UI 仍部分依赖引擎 formspec；ContentDB 在线浏览体验弱于 PC；API 22+ 单独产物未拆包 |
| **平板** | 键鼠 + 触屏 overlay、Luanti 完整 Lua UI、沉浸横屏、合规子窗口 | 无专用平板 ArkUI（有意与 PC 共用 Lua UI）；云真机专项调优未完成 |
| **PC** | 1.0 全部能力保留：键鼠单路径、zip 拖拽、WindowDecorCapsule、相对鼠标、Luanti 完整 UI | 无新增 PC 专属 UI（稳定维护） |

### 2.3 各平台核心收益

| 平台 | 为何这样设计 | 用户收益 |
|------|-------------|----------|
| **手机** | Irrlicht formspec 在小屏上难以操作；Luanti 主菜单 tabview 不适合触屏 | 原生鸿蒙 UI 风格统一、触控友好、性能更好（菜单不占用 GL 线程）、可独立迭代 UI |
| **平板** | 屏幕足够大，Luanti 原生 UI 可用；减少维护两套 UI | 完整 PC 级菜单功能 + 触屏 overlay 补充 |
| **PC** | 1.0 已验证的键鼠路径 | 零学习成本、Mod/Content 全功能、拖拽安装 |

---

## 3. 总体架构（五层 + 手机原生 UI）

从用户操作到像素，应用分为五层；**手机额外叠加第 1.5 层 ArkUI 原生 UI**，与 XComponent 游戏画面并列。

```
┌─────────────────────────────────────────────────────────────────────────┐
│ 🟧 第 0 层：HarmonyOS / OpenHarmony 系统                                 │
│  Start Window · WMS · 多模输入 · 文档目录 · 备份 · 浏览器 · 震动           │
└─────────────────────────────────────────────────────────────────────────┘
                                    ▲
┌─────────────────────────────────────────────────────────────────────────┐
│ 📱 第 1.5 层（仅手机）：ArkUI 原生 UI 叠加层                               │
│  PhoneLocalGamePanel · PhoneGameControls · PhoneInGamePauseOverlay      │
│  PhoneMoreMenuScreen · PhoneFormspecTextInput · 合规 Panel …             │
│  （与 XComponent 同页 zIndex 叠层；通过 JSON 文件 + NAPI 与 Lua 桥接）      │
└─────────────────────────────────────────────────────────────────────────┘
                                    ▲
┌─────────────────────────────────────────────────────────────────────────┐
│ 🟧 第 1 层：HarmonyOS 应用壳 entry/（ArkTS + NAPI + XComponent）         │
│  EntryAbility · Game.ets · LuantiAssets · OhosUiBridge · libentry.so    │
└─────────────────────────────────────────────────────────────────────────┘
                                    ▲ NAPI / XComponent Surface
┌─────────────────────────────────────────────────────────────────────────┐
│ 🟩 第 2 层：Voxera 宿主桥接                                              │
│  luanti_host.cpp · xcomponent_bridge.cpp · porting_ohos.cpp               │
│  ohos_touch_dispatch.cpp（手机触屏）                                      │
└─────────────────────────────────────────────────────────────────────────┘
                                    ▲ SDL OHOS 视频/输入
┌─────────────────────────────────────────────────────────────────────────┐
│ 🟪 第 3 层：SDL2 鸿蒙移植 third_party/ohos_sdl2/                         │
│  XComponent EGL · OHOS KEYCODE · 鼠标/触屏 · 音频 · Voxera 插件桥         │
└─────────────────────────────────────────────────────────────────────────┘
                                    ▲ Irrlicht / GLES2
┌─────────────────────────────────────────────────────────────────────────┐
│ 🟦 第 4 层：Luanti 客户端 luanti/                                        │
│  main · Client · 世界渲染 · builtin Lua · 着色器 · 网络 · 物理           │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.1 运行时线程模型

| 线程 | 归属 | 职责 |
|------|------|------|
| **ArkUI 主线程** | 🟧 | 布局、`Game.ets`、手机原生 UI、资源解压、500ms 轮询、`OhosUiBridge.poll`、键事件 `onKeyPreIme` |
| **Luanti 引擎线程** | 🟦+🟩 | `luanti_host.cpp` 中 `std::thread` 调用 `SDL_Main` → `main()` → 游戏循环 |
| **taskpool 工作线程** | 🟧+🟩 | `VoxeraSyncWorker.userDataCopyTask`：沙箱存档 → Documents 镜像 |

### 3.2 手机 ArkUI ↔ Lua 桥接模型

手机主菜单**不直接调用 Lua C API**，而是：

```
┌──────────────┐    write JSON     ┌─────────────────────┐    read JSON    ┌──────────────┐
│  ArkUI 组件   │ ──────────────▶ │  cacheDir/*.json     │ ◀────────────── │  phone_native │
│  (ETS)       │                   │  (状态文件)           │                 │  _*.lua      │
└──────────────┘                   └─────────────────────┘                 └──────────────┘
       │                                                                          │
       │  NAPI: triggerPhoneGameAction / completeOhosTextInput …                   │
       └──────────────────────────────────▶ porting_ohos ◀─────────────────────────┘
```

| Lua 桥接脚本 | 状态文件 | ArkTS Helper |
|-------------|----------|--------------|
| `phone_native_local.lua` | `phone_local_state.json` | `PhoneLocalGameHelper.ets` |
| `phone_native_settings.lua` | `phone_settings_state.json` | `PhoneSettingsHelper.ets` |
| `phone_native_content.lua` | `phone_content_state.json` | `PhoneContentHelper.ets` |
| `phone_native_install.lua` | — | `PhoneGameInstallHelper.ets` |

---

## 4. 分平台详解：手机 / 平板 / PC

### 4.1 📱 手机（`default` → Phone）

#### 4.1.1 启动后合规门控序列

```
引擎到达主菜单
    → LegalConsentPanel（法律声明确认）
    → HealthyGamingPanel（健康游戏声明）
    → Documents 权限（华为商用机，延迟到此处）
    → 若无已安装 retail 子游戏 → PhoneGameInstallPanel
    → 否则 → PhoneLocalGamePanel（原生主页）
```

#### 4.1.2 手机原生 UI 组件清单

| 组件 | 路径 | 职责 |
|------|------|------|
| **PhoneLocalGamePanel** | `components/PhoneLocalGamePanel.ets` | 主页：世界列表、开始游戏、创建世界、联机入口 |
| **PhoneCreateWorldPanel** | `components/PhoneCreateWorldPanel.ets` | 创建世界（地图生成器、标志、种子） |
| **PhoneSelectModPanel** | `components/PhoneSelectModPanel.ets` | 世界模组配置 |
| **PhoneJoinGameDrawer** | `components/PhoneJoinGameDrawer.ets` | 加入多人游戏抽屉 |
| **PhoneGameInstallPanel** | `components/PhoneGameInstallPanel.ets` | 首装引导 + zip 选择 |
| **PhoneMoreMenuScreen** | `components/PhoneMoreMenuScreen.ets` | 四圆点：关于 / 设置 / 内容 |
| **PhoneAboutTab** | `components/PhoneAboutTab.ets` | 关于页 |
| **PhoneSettingsTab** | `components/PhoneSettingsTab.ets` | 设置（搜索、分页） |
| **PhoneContentTab** | `components/PhoneContentTab.ets` | 已安装内容包 |
| **PhoneGameControls** | `components/PhoneGameControls.ets` | 游戏内：摇杆、跳跃、背包、小地图、暂停 |
| **PhoneInGamePauseOverlay** | `components/PhoneInGamePauseOverlay.ets` | 原生暂停卡片 |
| **PhoneFormspecTextInput** | `components/PhoneFormspecTextInput.ets` | Formspec 编辑框原生键盘 |
| **LegalConsentPanel** | `components/LegalConsentPanel.ets` | 法律声明（手机全屏） |
| **HealthyGamingPanel** | `components/HealthyGamingPanel.ets` | 健康游戏（手机全屏） |

#### 4.1.3 游戏内控件布局（PhoneGameControls）

```
┌────────────────────────────────────────────────────────────────┐
│                                                    [四圆点]  │ ← 暂停菜单
│                                                    [小地图]  │
│                                                    [背包/×]  │ ← toggle 背包
│                                                                │
│                     （XComponent 3D 游戏画面）                   │
│                                                                │
│  [虚拟摇杆]                                        [跳跃键]     │
│  WASD 注入                                                     │
└────────────────────────────────────────────────────────────────┘
```

- **虚拟摇杆**：偏移映射为 `KEYCODE_W/A/S/D` 注入（`injectKeyEvent`），语义等同 PC 键盘
- **跳跃键**：`KEYCODE_SPACE`
- **背包按钮**：关闭时显示 `backpack.svg`；背包打开时显示 `sys.symbol.xmark`；再次点击关闭
- **四圆点**：打开 `PhoneInGamePauseOverlay`（单人）或触发引擎菜单

#### 4.1.4 手机触屏交互（C++ 层）

文件：🟩 `luanti/src/ohos_touch_dispatch.cpp`

| 手势 | 游戏行为 |
|------|----------|
| **滑动** | 相对视角（相机） |
| **短按** | 右击（放置 / 使用） |
| **长按** | 挖掘 |
| **快捷栏点击** | 选中槽位 |
| **快捷栏长按** | 丢弃物品 |

快捷栏热区由 `hud.cpp` 每帧注册矩形供 hit-test。

#### 4.1.5 窗口策略

- `PhoneWindowHelper.ets`：横屏锁定 + 沉浸全屏
- `EntryAbility.ets`：检测到 `phone` / `default` 时应用

---

### 4.2 📱 平板（`tablet` → Tablet）

平板** intentionally 共用 Luanti Lua 主菜单**，差异集中在窗口与输入：

| 特性 | 实现 |
|------|------|
| 窗口 | `TabletWindowHelper.ets` — 横屏 + 沉浸 |
| 触屏 | `Game.ets` 透明 overlay → `injectTouch()` |
| 键鼠 | 同 PC：`onKeyPreIme` → `injectKeyEvent` |
| HUD 缩放 | `hud_scaling = 1.28`（`porting_ohos.cpp`） |
| 合规 | `LegalConsentTablet.ets` / `HealthyGamingDeclarationTablet.ets` 子窗口 |
| 主菜单 | 🟦 标准 Luanti tabview + formspec |

**优势**：完整 Content / Mod / 联机 UI，无需维护第二套平板 UI。  
**限制**：无专用平板布局优化；小控件仍依赖 Luanti Irrlicht 渲染。

---

### 4.3 🖥️ PC / 2in1（`2in1` → Pc2in1）

PC 体验与 **1.0 基本一致**，2.0 未削弱任何 PC 能力：

| 特性 | 实现 |
|------|------|
| 键盘 | `Game.ets` `onKeyPreIme` 单路径 → NAPI → SDL（避免重复字符） |
| 鼠标 | XComponent SDL 主路径 + 相对模式 kind=3 |
| 窗口 | `setWindowDecorVisible(false)` + `WindowDecorCapsule` 毛玻璃底托 |
| 沉浸 | `WindowDecorHelper.setImmersive()` — maximize 模式 |
| 安装 | zip **拖拽**到透明层 + DocumentViewPicker |
| 主菜单 | 🟦 完整 Luanti Lua UI |
| HUD 缩放 | `hud_scaling = 1.48` |

---

## 5. 冷启动：双层启动窗

Voxera 刻意实现 **「视觉连续」的双层冷启动**，避免系统窗消失后出现白屏/闪屏。

### 第 1 层 — 🟧 系统 Start Window

| 配置项 | 文件 | 值 |
|--------|------|-----|
| `startWindowIcon` | `module.json5` | `$media:splash_logo` |
| `startWindowBackground` | 同上 | `$color:start_window_background` |

### 第 2 层 — 🟩 应用内启动遮罩（`Game.ets`）

| 项 | 说明 |
|----|------|
| 状态变量 | `@State showStartupCover: boolean = true` |
| 视觉 | 全屏底色 + 居中 splash logo |
| 关闭条件 | 引擎状态含 `main_menu:` / `phone_local:state` / `in_game:` 等 |

**时间线：**

```
点击图标
  → [第1层] 系统 Start Window
  → EntryAbility.loadContent('pages/Game')
  → [第2层] showStartupCover
  → LuantiAssets.ensureInstalled（代际 v52）
  → setDeviceFormFactor + setAppDataPaths
  → XComponent onLoad → SDL_Main 引擎线程
  → 手机：合规门控 → PhoneLocalGamePanel
  → PC/平板：Luanti 主菜单 → 遮罩关闭
```

---

## 6. 输入系统：键盘 / 鼠标 / 触屏

### 6.1 PC / 平板键盘（单路径）

```
用户按键 → Game.ets handleKeyEvent()
         → NapiInjectKeyEvent(keycode, down)
         → porting_ohos::ohosInjectKeyEvent() → 队列
         → CIrrDeviceSDL::ohosPollPendingKeys()（每帧）
         → SDL 键盘状态 → inputhandler::syncFromSdlKeyboard()
```

设计原因：XComponent SDL 原生键路与 ArkUI IME **易重复**，故 PC **只走 ArkUI 注入**。

### 6.2 鼠标（PC / 平板）

- **主路径**：XComponent → SDL_ohosmouse → Irrlicht
- **相对模式**：SDL 请求 → `ohosPollUiRequest kind=3` → 隐藏系统指针
- **备用 API**：`injectMouseMotion(dx,dy)` 供后续扩展

### 6.3 手机触屏 + 虚拟控件

```
                    ┌─────────────────┐
  触屏滑动/点击      │ ohos_touch_     │     虚拟摇杆/跳跃
  (XComponent)  ──▶ │ dispatch.cpp    │ ◀── injectKeyEvent(WASD/Space)
                    └────────┬────────┘
                             ▼
                    Luanti Client 游戏逻辑
```

### 6.4 默认引擎设置（按平台）

`ohosApplyClientDefaults()` 在 `porting_ohos.cpp`：

| 设置 | 手机 | 平板 | PC |
|------|------|------|-----|
| `touch_gui` | **true** | false | false |
| `touch_controls` | false（自研控件） | false | false |
| `hud_scaling` | 1.48 | 1.28 | 1.48 |
| `pause_on_lost_focus` | false | false | false |

---

## 7. 手机自研 UI 与 Lua 桥接

### 7.1 加载条件

`builtin/mainmenu/content/init.lua`（及 HAP 热更副本）：

```lua
if PLATFORM == "HarmonyOS" and DEVICE_FORM_FACTOR == "phone" then
    -- 加载 phone_native_*.lua，跳过标准 tabview
end
```

### 7.2 强制热更清单

每次启动从 HAP `rawfile/` 覆盖到 `luanti_share`（`LuantiAssets.FORCE_RAW_BUILTIN`）：

- 全部 `phone_native_*.lua`
- `pause_menu/after.lua`、`pause_menu/init.lua`
- 主菜单 Voxera 补丁（`tab_about.lua`、`game_theme.lua` 等）

资源代际：**`ASSETS_GENERATION = 52`**（改 builtin 后须递增）。

---

## 8. 手机背包与 Formspec 交互

### 8.1 背包 Toggle 流程

```
[背包按钮点击]
    → triggerPhoneGameAction(PHONE_GAME_ACTION_INVENTORY)
    → game.cpp 处理：开/关玩家背包 formspec
    → game_formspec.cpp：ohosSetPlayerInventoryOpen(true/false)
    → Game.ets 轮询 isPlayerInventoryOpen()
    → PhoneGameControls：backpack.svg ↔ xmark 图标切换
```

### 8.2 背包 UI 增强（formspec 层）

| 增强 | 实现位置 | 参数 |
|------|----------|------|
| 整体放大 | `guiFormSpecMenu.cpp` | `OHOS_PHONE_FORMSPEC_SLOT_SCALE = 1.40` |
| 字体放大 | 同上 | `OHOS_PHONE_FORMSPEC_FONT_SCALE = 1.32` |
| Tap 选中（非拖拽） | `guiFormSpecMenu.cpp` | 黄色边框选中模式 |
| Tooltip 放大 | 同上 | `OHOS_PHONE_TOOLTIP_FONT_SCALE = 1.55` |
| 快捷栏点击放置 | `game.cpp` / `game_formspec.cpp` | 选中槽位后点击快捷栏替换 |

### 8.3 Formspec 文本输入（kind=8）

```
用户点击 formspec 编辑框
    → modalMenu.cpp：ohosShowTextInputDialog(hint, current, editType)
    → ohosPollUiRequest kind=8
    → OhosUiBridge → PhoneFormspecTextInput 底部 sheet
    → 用户确认 → completeOhosTextInput(text)
    → ohosCompleteTextInput → formspec 字段更新
```

支持：多行（1）、单行（2）、密码（3）。

---

## 9. 目录与文件导读

### 9.1 仓库根目录

| 路径 | 归属 | 说明 |
|------|------|------|
| `AppScope/` | 🟧 | 应用级 bundleName、版本、图标 |
| `entry/` | 🟧+🟩 | **主 HAP 模块**：ArkTS UI、NAPI、rawfile |
| `luanti/` | 🟦+🟩 | Luanti 源码 + `#ifdef __OHOS__` 补丁 |
| `third_party/ohos_sdl2/` | 🟪+🟩 | SDL2 鸿蒙驱动 |
| `scripts/` | 🟩 | 打包、编译、签名脚本 |
| `docs/PLATFORM.md` | 🟩 | 平台矩阵速查 |

### 9.2 `entry/` — 2.0 新增重点

#### ArkTS 手机组件（📱 2.0 新增）

| 文件 | 职责 |
|------|------|
| `components/Phone*.ets` | 手机自研 UI（12+ 组件） |
| `util/Phone*Helper.ets` | Lua JSON 桥接 |
| `util/DeviceFormFactor.ets` | 平台枚举与合规路由 |
| `util/PhoneWindowHelper.ets` | 手机窗口策略 |
| `util/TabletWindowHelper.ets` | 平板窗口策略 |
| `util/OhosPlatformCompat.ets` | 华为 vs OpenHarmony fork |
| `pages/LegalConsent*.ets` | 三端法律声明页 |
| `pages/HealthyGamingDeclaration*.ets` | 三端健康游戏声明 |

#### 配置

| 文件 | 2.0 要点 |
|------|----------|
| `module.json5` | `deviceTypes: ["default", "tablet", "2in1"]`；`VIBRATE` 权限 |
| `syscap.json` | 系统能力声明 |
| `resources/base/media/backpack.svg` | 背包按钮图标 |

### 9.3 `luanti/` — 2.0 新增/修改

#### 新增源文件

| 文件 | 职责 |
|------|------|
| `ohos_touch_dispatch.cpp` | 手机触屏：视角、挖掘、放置、快捷栏 |
| `porting_ohos.cpp/h` | 扩展：form factor、native pause、inventory flag、text input、vibrate |

#### 关键修改

| 文件 | 2.0 修改 |
|------|----------|
| `client/game.cpp` | 手机 game action、native pause 门控、hotbar |
| `client/game_formspec.cpp` | 背包 open 状态、手机 pause 替换 |
| `client/hud.cpp` | 快捷栏 touch 矩形注册 |
| `gui/guiFormSpecMenu.cpp` | 手机 formspec 缩放、tap-select、tooltip |
| `gui/modalMenu.cpp` | 编辑框 → kind=8 文本输入 |
| `script/cpp_api/s_base.cpp` | `DEVICE_FORM_FACTOR` Lua 全局 |

#### 手机 Lua 桥接（builtin）

| 文件 | 职责 |
|------|------|
| `phone_native_local.lua` | 世界列表、创建、Play、模组 |
| `phone_native_settings.lua` | 设置项读写 |
| `phone_native_content.lua` | 内容包管理 |
| `phone_native_install.lua` | 首装 zip |

---

## 10. Luanti 侧鸿蒙补丁清单

### 10.1 ArkTS ↔ 引擎 UI 协作（`OhosUiRequestKind`）

| kind | 名称 | 引擎触发 | ArkTS 行为 | 平台 |
|------|------|----------|------------|------|
| 1 | OpenUrl | ContentDB / 链接 | `startAbility` 浏览器 | 全平台 |
| 2 | PickZip | 安装本地包 | DocumentViewPicker | 全平台 |
| 3 | RelativeMouse | SDL 相对模式 | 隐藏系统指针 | **2in1** |
| 4 | Fullscreen | F11 / 设置 | 沉浸全屏 | 全平台 |
| 5 | OpenLocalPath | 打开存档目录 | 文件管理器 | 全平台 |
| 6 | CopyDir | Documents 镜像 | 目录复制（可阻塞） | 全平台 |
| 7 | Vibrate | 挖掘反馈 | 系统震动 | **手机** |
| 8 | TextInput | Formspec 编辑框 | `PhoneFormspecTextInput` | **手机** |

并行能力：
- **zip 拖拽**：Lua `ohos_set_zip_drop_target` → `Game.ets` 透明 `onDrop`
- **手机 game action**：`triggerPhoneGameAction` — 背包、小地图
- **native pause**：`setNativePauseActive` / `nativePauseExitMenu` / `nativePauseExitOS`

### 10.2 数据路径

| 变量 | 典型路径 | 用途 |
|------|----------|------|
| `path_share` | `{filesDir}/luanti_share` | 只读：builtin、shaders、fonts |
| `path_user` | `{filesDir}/luanti_user` | 可写：世界、mods |
| `path_cache` | `{cacheDir}` | 临时、JSON 桥接状态 |
| 公开镜像 | `Documents/Voxera/user_data` | 用户可见备份 |

### 10.3 NAPI 导出（`LuantiNative.ets`）

| 方法 | 用途 |
|------|------|
| `setDeviceFormFactor` | 平台识别 |
| `setAppDataPaths` / `setPublicUserDataDir` | 路径初始化 |
| `getEngineStatus` / `isInGameWorld` | 状态轮询 |
| `isPlayerInventoryOpen` | 背包按钮图标 |
| `injectKeyEvent` / `injectTouch` | 输入注入 |
| `triggerPhoneGameAction` | 手机游戏内动作 |
| `get/setNativePauseActive` | 原生暂停 |
| `pollOhosUiRequest` / `completeOhos*` | UI 请求闭环 |

---

## 11. 构建、资源打包与依赖

### 11.1 双构建产物

| Product | runtimeOS | SDK | 典型用途 |
|---------|-----------|-----|----------|
| **`default`** | HarmonyOS | 6.0.2 (**API 22**) | 华为商用手机 / 平板 |
| **`oh`** | OpenHarmony | 6.0.0 (**API 20**) | PC 2in1、OH 模拟器、开源 fork |

```bash
# OpenHarmony PC 模拟器
hvigorw assembleHap -p product=oh

# 华为商用手机
hvigorw assembleHap -p product=default
```

### 11.2 环境

- [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/)
- OpenHarmony SDK API 20+ / HarmonyOS SDK API 22（手机）
- Windows 脚本：`scripts/assemble_hap.ps1`

### 11.3 步骤概要

1. **放置原生依赖** — `entry/ohos_deps/<abi>/`（SDL2、Curl、Freetype、LuaJIT…）
2. **（可选）重编 SDL2** — `scripts/build_ohos_sdl2.ps1`
3. **打包游戏资源** — `scripts/pack_luanti_assets.ps1`
4. **编译 HAP** — `hvigorw assembleHap` 或 `scripts/assemble_hap.ps1`
5. **手机调试签名** — `scripts/setup_harmony_phone_signing.ps1`（OpenHarmony 证书无法装华为真机）
6. **递增资源代际** — 改 builtin 后更新 `LuantiAssets.ASSETS_GENERATION`（当前 **52**）

### 11.4 脚本一览

| 脚本 | 职责 |
|------|------|
| `pack_luanti_assets.ps1` | 打包 luanti_assets.zip + rawfile |
| `build_ohos_sdl2.ps1` | 交叉编译 libSDL2.a |
| `assemble_hap.ps1` | 一键 assembleHap |
| `fix_ohos_sdk.ps1` | SDK 路径修正 |
| `setup_harmony_phone_signing.ps1` | 华为手机调试签名 |
| `gen_voxera_icons.py` | 启动图、图标生成 |

---

## 12. 许可证与上游链接

本仓库与 Luanti 引擎采用 **[LGPL-2.1-or-later](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html)**。

| 项目 | 链接 |
|------|------|
| **Luanti** | <https://www.luanti.org/> · <https://github.com/luanti-org/luanti> |
| **SDL2** | <https://www.libsdl.org/> |
| **Voxera 鸿蒙版** | <https://github.com/Mencaje/voxera-harmonyos> |

---

## 13. 附录

### 附录 A：三端启动路径对比

```
                    ┌─── 手机 ───▶ 合规门控 ──▶ PhoneLocalGamePanel ──▶ 进世界 ──▶ PhoneGameControls
点击图标 ──▶ Game.ets ─┼─── 平板 ───▶ Luanti Lua 主菜单 ──▶ 进世界 ──▶ 触屏 overlay + 键鼠
                    └─── PC ────▶ Luanti Lua 主菜单 ──▶ 进世界 ──▶ 键鼠 + WindowDecorCapsule
```

### 附录 B：2.0 新增文件速查

| 类别 | 路径模式 |
|------|----------|
| 手机 UI 组件 | `entry/src/main/ets/components/Phone*.ets` |
| 手机 Helper | `entry/src/main/ets/util/Phone*.ets` |
| 合规页面 | `entry/src/main/ets/pages/LegalConsent*.ets`、`HealthyGaming*.ets` |
| Lua 桥接 | `luanti/builtin/mainmenu/content/phone_native_*.lua` |
| C++ 触屏 | `luanti/src/ohos_touch_dispatch.cpp` |
| 手机资源 | `entry/src/main/resources/base/media/backpack.svg` |

### 附录 C：谁负责什么

| 能力 | 主要负责层 |
|------|------------|
| 方块世界、物理、联机 | 🟦 Luanti |
| PC/平板主菜单 | 🟦 Luanti `builtin/` Lua |
| 手机主菜单 / 暂停 / 控件 | 📱 ArkTS `Phone*.ets` + Lua 桥接 |
| 手机触屏 / 快捷栏 / 背包 | 🟩 `ohos_touch_dispatch` + `guiFormSpecMenu` |
| 路径、设置、UI 请求队列 | 🟩 `porting_ohos.cpp` |
| GPU 渲染 | 🟪 SDL XComponent + 🟦 Irrlicht |
| 权限、合规、资源安装 | 🟩 ArkTS `entry/` |

---

*本文档随 Voxera **2.0** 代码更新；若与实现不一致，以源码为准。欢迎向 [voxera-harmonyos](https://github.com/Mencaje/voxera-harmonyos) 提交 Issue/PR。*

# Voxera for HarmonyOS（Voxera 鸿蒙版）

[![License: LGPL v2.1+](https://img.shields.io/badge/License-LGPL%20v2.1%2B-blue.svg)](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html)

**仓库地址：** <https://github.com/Mencaje/voxera-harmonyos>

Voxera 鸿蒙版是在开源引擎 **[Luanti](https://www.luanti.org/)**（[luanti-org/luanti](https://github.com/luanti-org/luanti)）基础上移植、修改而成的 **HarmonyOS / OpenHarmony PC（2in1）** 方块沙盒**客户端**。本 README 是面向贡献者与读者的**完整架构导读**；法律与许可说明见 [`NOTICE.md`](NOTICE.md)、[`COPYING.LESSER`](COPYING.LESSER)。

---

## 图例：代码归属（阅读下文时请对照）

| 标记 | 含义 |
|------|------|
| **🟦 Luanti** | 上游 Luanti 引擎/客户端源码（LGPL-2.1-or-later），本仓库 `luanti/` 为主体 |
| **🟩 Voxera 移植** | 为鸿蒙 PC 新增或修改的衍生代码（仍属 LGPL 衍生作品） |
| **🟧 鸿蒙原生 / ArkTS** | OpenHarmony SDK、ArkUI、系统 Ability、NAPI、XComponent 等 |
| **🟪 第三方** | 其他开源组件（如 SDL2 鸿蒙 fork、预编译静态库） |

---

## 目录

1. [产品范围与平台](#1-产品范围与平台)
2. [总体架构（五层）](#2-总体架构五层)
3. [冷启动：双层启动窗](#3-冷启动双层启动窗)
4. [键盘与鼠标：完整数据流](#4-键盘与鼠标完整数据流)
5. [目录与文件导读](#5-目录与文件导读)
6. [Luanti 侧鸿蒙补丁清单](#6-luanti-侧鸿蒙补丁清单)
7. [构建、资源打包与依赖](#7-构建资源打包与依赖)
8. [许可证与上游链接](#8-许可证与上游链接)

---

## 1. 产品范围与平台

| 项目 | 说明 |
|------|------|
| **支持** | 仅 **鸿蒙 PC**（`module.json5` → `deviceTypes: ["2in1"]`），**键盘 + 鼠标** |
| **不支持** | 鸿蒙手机、鸿蒙平板；**不以触屏作为正式玩法**（`touch_gui=false`，见 🟩 `porting_ohos.cpp`） |
| **包名** | `com.Voxera.mencaje`（`AppScope/app.json5`） |
| **SDK** | OpenHarmony API **20+**（`build-profile.json5`） |

> **与 GitHub 仓库简介的差异说明：** 若外部简介写「触控优化」，以本仓库 **`docs/PLATFORM.md`** 与 **`module.json5`** 为准：当前正式适配目标是 **PC 键鼠**，非手游式触屏操控。

---

## 2. 总体架构（五层）

从用户操作到像素，应用分为五层；**只有最上（ArkTS 壳）与最下（鸿蒙系统服务）是 🟧 原生**，中间大块游戏逻辑是 **🟦 Luanti**，连接层是 **🟩 Voxera 移植** + **🟪 SDL2 OHOS**。

```
┌─────────────────────────────────────────────────────────────────────────┐
│ 🟧 第 0 层：HarmonyOS 系统                                               │
│  Start Window · 窗口管理(WMS) · 多模输入 · 文档目录 · 备份 · 浏览器      │
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
└─────────────────────────────────────────────────────────────────────────┘
                                    ▲ SDL OHOS 视频/输入
┌─────────────────────────────────────────────────────────────────────────┐
│ 🟪 第 3 层：SDL2 鸿蒙移植 third_party/ohos_sdl2/                         │
│  XComponent EGL · OHOS KEYCODE · 鼠标 · 音频 · Voxera 插件桥             │
└─────────────────────────────────────────────────────────────────────────┘
                                    ▲ Irrlicht / GLES2
┌─────────────────────────────────────────────────────────────────────────┐
│ 🟦 第 4 层：Luanti 客户端 luanti/                                        │
│  main · Client · 世界渲染 · builtin Lua · 着色器 · 网络 · 物理           │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.1 运行时线程模型

| 线程 | 归属 | 职责 |
|------|------|------|
| **ArkUI 主线程** | 🟧 | 布局、`Game.ets`、资源解压触发、500ms 轮询、`OhosUiBridge.poll`、键事件 `onKeyPreIme` |
| **Luanti 引擎线程** | 🟦+🟩 | `luanti_host.cpp` 中 `std::thread` 调用 `SDL_Main` → `main()` → 游戏循环 |
| **taskpool 工作线程** | 🟧+🟩 | `VoxeraSyncWorker.userDataCopyTask`：沙箱存档 → Documents 镜像 |

### 2.2 关键原生组件（🟧）一览

| 鸿蒙/OpenHarmony 组件 | 使用位置 | 用途 |
|------------------------|----------|------|
| **UIAbility / WindowStage** | `EntryAbility.ets` | 应用生命周期、加载 `pages/Game` |
| **ArkUI `XComponent` (SURFACE)** | `Game.ets` | 游戏 GPU 输出 Surface；`libraryname: 'entry'` 加载 `libentry.so` |
| **NAPI (`libentry.so`)** | `napi_init.cpp` | ArkTS ↔ C++：路径、状态、键鼠注入、UI 请求 |
| **OH_NativeXComponent** | `xcomponent_bridge.cpp`, SDL | Surface 创建/销毁/尺寸 |
| **EGL / GLESv3** | SDL + Irrlicht | 3D 渲染 |
| **multimodalInput.pointer** | `Game.ets` | 进世界后隐藏系统鼠标指针 |
| **DocumentViewPicker / DragEvent** | `OhosUiBridge.ets` | 本地 `.zip` 游戏包安装 |
| **fileIo / zlib** | `LuantiAssets.ets` | HAP 资源解压到 `filesDir/luanti_share` |
| **abilityAccessCtrl** | `VoxeraPaths.ets` | `READ_WRITE_DOCUMENTS_DIRECTORY` |
| **taskpool** | `VoxeraPaths.ets` | 后台目录同步 |
| **window.Window** | `WindowDecorHelper.ets` | 2in1 标题按钮区域、沉浸全屏 |
| **BackupExtension** | `EntryBackupAbility.ets` | 系统备份 |

---

## 3. 冷启动：双层启动窗

Voxera 刻意实现 **「视觉连续」的双层冷启动**，避免系统窗消失后出现白屏/闪屏。

### 第 1 层 — 🟧 系统 Start Window（Ability 配置）

| 配置项 | 文件 | 值 |
|--------|------|-----|
| `startWindowIcon` | `entry/src/main/module.json5` | `$media:startIcon` |
| `startWindowBackground` | 同上 | `$color:start_window_background` → `#FFFFFF` |

由 **系统在 ArkUI 首帧之前** 绘制；应用代码**不直接控制**这一层。

### 第 2 层 — 🟩 应用内启动遮罩（`Game.ets`）

| 项 | 说明 |
|----|------|
| 状态变量 | `@State showStartupCover: boolean = true` |
| 视觉 | 全屏白底 `STARTUP_COVER_COLOR` + 居中 `Image($r('app.media.startIcon'))` |
| 尺寸 | `STARTUP_ICON_VP`（vp，与系统窗同图标，可单独调大） |
| 层级 | `zIndex(2)`，盖在 `XComponent` 之上 |
| 关闭条件 | `shouldDismissStartupCover()`：引擎状态含 `main_menu:` / `init_engine:…done` / `video driver:` |

**时间线：**

```
点击图标
  → [第1层] 系统 Start Window（白底 + startIcon）
  → EntryAbility.loadContent('pages/Game')
  → [第2层] showStartupCover（同色同图标，无缝衔接）
  → aboutToAppear: LuantiAssets.ensureInstalled（可能较慢）
  → assetsReady: 挂载 XComponent，原生线程 SDL_Main
  → 引擎就绪: showStartupCover = false → 露出 Luanti 主菜单
```

---

## 4. 键盘与鼠标：完整数据流

### 4.1 设计原则（🟩 为何不用 SDL 直接收键盘）

在鸿蒙 PC 上，**XComponent 的 SDL 原生键路与 ArkUI 焦点/IME 易重复**，导致字符重复。因此 **键盘只走一条路径**：

> **ArkUI `onKeyPreIme` → NAPI `injectKeyEvent` → 队列 → SDL 键盘状态**

`Game.ets` 注释：`Single path: onKeyPreIme only`。

### 4.2 键盘数据流（逐步）

```
用户按下物理键
  │
  ▼ 🟧 ArkUI KeyEvent（HarmonyOS KEYCODE_*，如 W=2039）
Game.ets  handleKeyEvent()
  │  event.type === KeyType.Down / Up
  ▼ 🟧 NAPI
napi_init.cpp  NapiInjectKeyEvent(keycode, down)
  ▼ 🟩
porting_ohos.cpp  ohosInjectKeyEvent()
  │  OHOS_QueueKeyEvent() → g_pendingKeys 队列
  │  ohosKeycodeToScancode()：KEYCODE → SDL_Scancode
  │  ohosUpdateHeldScancode()：维护 g_heldScancodes[]
  ▼ 🟪（每帧由 Irrlicht 设备驱动调用）
CIrrDeviceSDL.cpp  porting::ohosPollPendingKeys()
  │  OHOS_FlushQueuedKeyEvents()
  ▼ 🟪
SDL_ohoskeyboard.c  OHOS_OnKeyDown / OHOS_OnKeyUp
  │  更新 SDL 内部键盘状态
  ▼ 🟦
inputhandler.cpp  MyEventReceiver::syncFromSdlKeyboard()
  │  ohosIsScancodePressed() + SDL_GetKeyboardState()
  │  setKeyDown() → WASD、跳跃、背包等游戏逻辑
  ▼ 🟦
Client / Game 循环处理移动、菜单、聊天等
```

**主菜单与游戏内**均通过 `syncFromSdlKeyboard()` 同步；菜单表单项仍可由 Irrlicht `EET_KEY_INPUT_EVENT` 处理部分快捷键。

### 4.3 鼠标数据流

鼠标有 **两条互补路径**：

#### A. 指针移动 / 按钮（主路径，🟪 SDL ← XComponent）

```
OH_NativeXComponent 鼠标回调
  ▼ 🟪 SDL_ohosmouse.c / SDL_ohosevents.c
SDL 鼠标状态与按钮事件
  ▼ 🟦 Irrlicht MyEventReceiver / 游戏内相机
```

进世界后 **🟧 `pointer.setPointerVisibleSync(false)`**（`Game.ets` `setMouseCapture`）隐藏系统光标，配合 Luanti 相对视角。

#### B. 相对移动注入（备用 API，🟩 已实现、ArkTS 可扩展）

```
Game.ets（可接 onMouse）→ injectMouseMotion(dx,dy)
  → porting_ohos::OHOS_QueueMouseMotion
  → ohosPollPendingMouse → SDL
```

当前 **`Game.ets` 主要用 A + 隐藏指针**；`LuantiNative.injectMouseMotion` 供后续 ArkUI 原始 delta 接入。

#### C. 相对鼠标模式通知（全屏/捕获）

```
SDL 请求相对模式
  ▼ 🟩 ohosOnRelativeMouseModeChanged
porting_ohos  g_relativeMouseUiDirty
  ▼ 轮询 pollOhosUiRequest kind=3
OhosUiBridge  pointer.setPointerVisibleSync(!capture)
```

### 4.4 键位映射表（节选）

| HarmonyOS KEYCODE | 值 | SDL Scancode |
|-------------------|-----|--------------|
| KEYCODE_A … Z | 2017–2042 | SDL_SCANCODE_A … |
| KEYCODE_0 … 9 | 2000–2009 | SDL_SCANCODE_0 … |
| KEYCODE_F1 … F12 | 2090–2101 | SDL_SCANCODE_F1 … |
| KEYCODE_SPACE | 2050 | SDL_SCANCODE_SPACE |
| KEYCODE_ESCAPE | 2070 | SDL_SCANCODE_ESCAPE |
| 方向键 | 2012–2015 | UP/DOWN/LEFT/RIGHT |

完整映射见 🟩 `luanti/src/porting_ohos.cpp` → `ohosKeycodeToScancode()`。

### 4.5 默认输入相关设置（🟩）

`ohosApplyClientDefaults()` 中：

- `touch_gui = false` — 不显示手机虚拟摇杆
- `pause_on_lost_focus = false` — XComponent 焦点不稳定时不每帧弹暂停菜单

---

## 5. 目录与文件导读

### 5.1 仓库根目录

| 路径 | 归属 | 说明 |
|------|------|------|
| `AppScope/` | 🟧 | 应用级 `bundleName`、图标、应用名 |
| `entry/` | 🟧+🟩 | **主 HAP 模块**：ArkTS UI、NAPI、rawfile 游戏资源 |
| `luanti/` | 🟦+🟩 | **Luanti 完整源码树** + 鸿蒙 `#ifdef __OHOS__` 补丁 |
| `third_party/ohos_sdl2/` | 🟪+🟩 | SDL2 官方代码 + `src/core/ohos`、`src/video/ohos` 等鸿蒙驱动 |
| `third_party/cjson/` | 🟪 | Luanti 可选 JSON（OHOS 构建链入） |
| `entry/ohos_deps/<abi>/` | 🟪 | **预编译** curl、freetype、luajit、openal、sdl2、sqlite…（通常不进 Git） |
| `scripts/` | 🟩 | 打包资源、编 SDL2、assemble HAP |
| `docs/PLATFORM.md` | 🟩 | 平台支持说明 |
| `hvigor/`、`build-profile.json5` | 🟧 | DevEco/hvigor 工程配置 |
| `COPYING.LESSER`、`NOTICE.md` | 法律 | LGPL 与衍生声明 |

---

### 5.2 `entry/` — HarmonyOS 应用壳（逐文件）

#### ArkTS / ETS

| 文件 | 归属 | 职责 |
|------|------|------|
| `ets/entryability/EntryAbility.ets` | 🟧 | `UIAbility`：加载 `pages/Game`；2in1 隐藏系统标题栏、`setWindowDecorHeight(64)` |
| `ets/pages/Game.ets` | 🟩 | **主界面**：XComponent、双层启动遮罩、键鼠、轮询引擎状态、zip 拖拽层、窗口胶囊 |
| `ets/pages/Index.ets` | 🟩 | 遗留测试入口（「Launch Luanti」），**非当前冷启动路径** |
| `ets/native/LuantiNative.ets` | 🟩 | `import native from 'libentry.so'` 的 TypeScript 封装 |
| `ets/util/LuantiAssets.ets` | 🟩 | 解压 `rawfile/luanti_assets.zip` → `filesDir/luanti_share`；代际 `v29`；强制热更菜单 Lua/贴图 |
| `ets/util/VoxeraPaths.ets` | 🟩 | 沙箱 `luanti_user` vs `Documents/Voxera/user_data`；权限；迁移与同步调度 |
| `ets/util/VoxeraSyncWorker.ets` | 🟩 | `@Concurrent userDataCopyTask`：后台目录树复制 |
| `ets/util/OhosUiBridge.ets` | 🟩 | 处理引擎 UI 请求：浏览器、选 zip、全屏、打开文件夹、copyDir |
| `ets/util/WindowDecorHelper.ets` | 🟩 | 2in1 标题按钮矩形监听；沉浸全屏（`maximize` 而非普通 layout fullscreen） |
| `ets/components/WindowDecorCapsule.ets` | 🟩 | 进世界后右上角毛玻璃底托（不拦截点击） |
| `ets/entrybackupability/EntryBackupAbility.ets` | 🟧 | 系统备份扩展 Ability |

#### 原生 C++（编译为 `libentry.so`）

| 文件 | 归属 | 职责 |
|------|------|------|
| `cpp/napi_init.cpp` | 🟩 | 注册 NAPI 方法；`constructor` 自动 `napi_module_register` |
| `cpp/xcomponent_bridge.cpp` | 🟩 | `OH_NativeXComponent_RegisterCallback`；转发 Surface 生命周期 |
| `cpp/luanti_host.cpp` | 🟩 | Surface 创建后 **工作线程** `SDL_Main`；`GetEngineStatus` |
| `cpp/luanti_host.h` | 🟩 | 宿主 C API 声明 |
| `cpp/egl_preview.cpp` | 🟩 | `VOXERA_BUILD_LUANTI=OFF` 时 GPU 预览（开发） |
| `cpp/CMakeLists.txt` | 🟩 | `VOXERA_BUILD_LUANTI` 开关；链接 `luanti` 与 NDK 库 |

#### 配置与资源

| 文件 | 归属 | 职责 |
|------|------|------|
| `src/main/module.json5` | 🟧 | **2in1 only**、权限、Start Window、`EntryAbility` |
| `src/main/resources/base/profile/main_pages.json` | 🟧 | 注册 `Index`、`Game` 路由 |
| `src/main/resources/rawfile/luanti_assets.zip` | 🟦 内容 | 打包后的 Luanti 共享资源（脚本生成） |
| `src/main/resources/rawfile/bootstrap_manifest.json` | 🟩 | zip 缺失时的 shader/builtin/texture 列表 |
| `src/main/resources/rawfile/builtin/...` | 🟦+🟩 | 热修用 Lua；含 Voxera 主菜单补丁 |
| `src/main/resources/rawfile/fonts/` | 🟦 | 字体兜底 |
| `src/main/resources/base/element/color.json` | 🟧 | `start_window_background` = `#FFFFFF` |
| `build-profile.json5` | 🟧+🟩 | `externalNativeOptions`：`VOXERA_BUILD_LUANTI=ON`、ABI |

---

### 5.3 `luanti/` — Luanti 引擎（结构 + 鸿蒙相关）

> **🟦 主体**：与上游 Luanti 相同的 `src/`、`builtin/`、`client/shaders/`、`irr/`、`lib/` 等。  
> 以下仅列出 **🟩 鸿蒙移植必知** 或 **Voxera 定制** 部分；其余百万行级代码行为与 [Luanti 文档](https://www.luanti.org/) 一致。

#### 🟩 鸿蒙专用源文件（新增）

| 文件 | 职责 |
|------|------|
| `src/porting_ohos.h` / `porting_ohos.cpp` | **鸿蒙移植核心**：路径、`SDL_Main` 包装、UI 请求队列、键鼠队列、默认设置、中文菜单 gettext、XComponent |
| `src/ohos_bionic_compat.c` | musl 链接 shim（Android NDK 静态库兼容） |
| `cmake/Modules/OHOSLibs.cmake` | 读取 `entry/ohos_deps/<abi>/` 预编译库 |

#### 🟩 修改过的 Luanti 源文件（`#ifdef __OHOS__`）

| 文件 | 修改要点 |
|------|----------|
| `irr/src/CIrrDeviceSDL.cpp` | XComponent 上创建 GL 上下文；每帧 `ohosPollPendingKeys/Mouse`；禁用摇杆；状态上报 |
| `src/client/inputhandler.cpp` | `syncFromSdlKeyboard()` 使用 `ohosIsScancodePressed` |
| `src/client/inputhandler.h` | OHOS 声明 |
| `src/client/game.cpp` | 进世界 `ohosEngineStatusSet("in_game: world")` |
| `src/client/clientlauncher.cpp` | OHOS 启动分支 |
| `src/client/renderingengine.cpp` | 视频驱动状态字符串 |
| `src/client/fontengine.cpp` | 字体加载状态 |
| `src/gui/guiEngine.cpp` | 主菜单脚本、zip 选择、状态 |
| `src/gui/guiFormSpecMenu.cpp` | 表单相关 OHOS |
| `src/script/lua_api/l_mainmenu.cpp` | `core.ohos_set_status`、`core.ohos_set_zip_drop_target` |
| `src/main.cpp` | 启动失败状态 |
| `src/filesys.cpp` | Documents 路径需 UI 复制 |
| `src/httpfetch.cpp` | curl/证书 OHOS 行为 |
| `src/porting.cpp` / `porting.h` | 平台分支 |
| `src/gettext.h` | 菜单翻译 OHOS |
| `CMakeLists.txt` | `OHOS` 工具链、`porting_ohos.cpp` 编入客户端 |

#### 🟩 Voxera 品牌 / 功能 Lua（`builtin/`，属 Luanti 资源树）

| 文件 | 职责 |
|------|------|
| `builtin/mainmenu/game_theme.lua` | 菜单头图 `voxera_menu_header` |
| `builtin/mainmenu/tab_about.lua` | HarmonyOS 显示 Voxera-HarmonyOS 1.0.0、开源说明、萌创匠盒链接 |
| `builtin/mainmenu/content/local_install.lua` | 本地 zip 包安装逻辑 |
| `builtin/mainmenu/content/dlg_local_game.lua` | 本地游戏安装对话框 + `ohos_set_zip_drop_target` |
| `builtin/mainmenu/content/dlg_contentdb.lua` 等 | Content 相关（部分强制从 HAP 热更） |

`LuantiAssets.FORCE_RAW_BUILTIN` 列出每次启动从 HAP **强制覆盖** 的菜单 Lua 路径。

#### 🟦 标准 Luanti 目录（未改或极少改）

| 目录 | 内容 |
|------|------|
| `src/server/` | 服务端（OHOS 构建 `BUILD_SERVER=FALSE` 不编入 HAP） |
| `src/client/` | 客户端渲染、地图、HUD、音效… |
| `src/mapgen/` | 地图生成 |
| `builtin/game/` | 内置游戏逻辑 Lua |
| `builtin/client/` | 客户端 Lua API |
| `client/shaders/` | GLSL 着色器 |
| `irr/` | Irrlicht 渲染设备 |
| `lib/lua/` | Lua 解释器 |
| `textures/`、`games/`、`mods/` | 游戏内容（发行由用户目录或安装包提供） |

---

### 5.4 `third_party/ohos_sdl2/` — SDL2 鸿蒙驱动

| 路径 | 归属 | 职责 |
|------|------|------|
| `src/core/ohos/SDL_ohos.cpp` | 🟪 华为 + 🟩 | SDL 系统初始化 |
| `src/core/ohos/SDL_ohos_xcomponent.cpp` | 🟪+🟩 | **XComponent 与 EGL Surface 绑定** |
| `src/core/ohos/SDL_ohos_voxerabridge.c` | 🟩 | **Voxera 专用**：Luanti 注册 Surface、注入键鼠 |
| `src/video/ohos/SDL_ohoswindow.c` | 🟪 | 从 XComponent 创建 SDL 窗口 |
| `src/video/ohos/SDL_ohosgl.c` | 🟪 | GLES 上下文 |
| `src/video/ohos/SDL_ohoskeyboard.c` | 🟪 | KEYCODE → SDL 键盘 |
| `src/video/ohos/SDL_ohosmouse.c` | 🟪 | XComponent 鼠标事件 |
| `src/video/ohos/SDL_ohosevents.c` | 🟪 | 事件泵 |
| `src/audio/ohos/*` | 🟪 | 音频 |
| `src/filesystem/ohos/SDL_sysfilesystem.c` | 🟪 | 路径 |
| `ohos-project/` | 🟪 | SDL 官方示例 HAP（**非 Voxera 主工程**） |

---

### 5.5 `scripts/` — 工程脚本

| 脚本 | 职责 |
|------|------|
| `pack_luanti_assets.ps1` | 从 `luanti/` 收集 builtin、shaders、fonts、textures → `luanti_assets.zip` + rawfile 清单 |
| `build_ohos_sdl2.ps1` | 交叉编译带 Voxera 符号的 `libSDL2.a` |
| `assemble_hap.ps1` | 设置 SDK/Java，调用 `hvigorw assembleHap` |
| `fix_ohos_sdk.ps1` | 修正本机 SDK 路径 |
| `gen_voxera_icons.py` | 启动图、About 图等品牌资源 |

---

## 6. Luanti 侧鸿蒙补丁清单

### 6.1 ArkTS ↔ 引擎 UI 协作（`OhosUiRequestKind`）

引擎 🟩 `porting_ohos.cpp` 置位请求 → ArkTS `OhosUiBridge.poll` 消费：

| kind | 引擎触发示例 | ArkTS 行为 |
|------|--------------|------------|
| 1 OpenUrl | 打开 ContentDB / 官网 | `startAbility` 系统浏览器 |
| 2 PickZip | 主菜单安装本地包 | `DocumentViewPicker` → 解压到 cache → `completeOhosFilePick` |
| 3 RelativeMouse | SDL 相对鼠标模式 | `setPointerVisibleSync` |
| 4 Fullscreen | F11 / 设置全屏 | `WindowDecorHelper.setImmersive` |
| 5 OpenLocalPath | 打开存档目录 | 文件管理器 / DocumentPicker |
| 6 CopyDir | 写 Documents 路径 | `VoxeraPaths.copyDirectory`（可阻塞引擎最多 15 分钟） |

并行：**拖拽安装** — Lua `core.ohos_set_zip_drop_target(formname)` → `Game.ets` 透明 `onDrop` → `OhosUiBridge.handleZipDrop`。

### 6.2 数据路径（三路径模型）

| 变量 | 典型路径 | 归属 | 用途 |
|------|----------|------|------|
| `path_share` | `{filesDir}/luanti_share` | 🟩 安装 | 只读游戏资源：builtin、shaders、fonts、locale |
| `path_user` | `{filesDir}/luanti_user` | 🟩 | **引擎可写**：世界、mods、sqlite |
| `path_cache` | `{cacheDir}` | 🟧 | 临时 zip、安装 staging |
| 公开镜像 | `Documents/Voxera/user_data` | 🟩+🟧 | 用户备份/文件管理可见；需权限 |

### 6.3 引擎状态字符串（供启动遮罩与调试）

由 🟩 `ohosEngineStatusSet()` 写入，ArkTS `getEngineStatus()` 读取。例如：

- `SDL_Main: enter` / `main_menu: running` / `in_game: world`
- `缺少 builtin/init.lua…`、`OHOS: SDL_GL_CreateContext failed`
- 媒体加载 `VoxeraLoad` 节流日志

---

## 7. 构建、资源打包与依赖

### 7.1 环境

- [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/) + OpenHarmony SDK **API 20+**
- Windows 示例脚本假设 SDK / Java 路径见 `scripts/assemble_hap.ps1`

### 7.2 步骤概要

1. **放置原生依赖**  
   `entry/ohos_deps/arm64-v8a/` 或 `x86_64/`：SDL2、Curl、Freetype、LuaJIT、OpenAL、SQLite、PNG、Vorbis、Zstd 等（见 `OHOSLibs.cmake`）。

2. **（可选）重编 SDL2**  
   `scripts/build_ohos_sdl2.ps1` → `third_party/ohos_sdl2_build/libSDL2.a`

3. **打包游戏资源**  
   `scripts/pack_luanti_assets.ps1` → 更新 `entry/src/main/resources/rawfile/`

4. **编译 HAP**  
   ```bash
   hvigorw assembleHap
   ```
   或 `scripts/assemble_hap.ps1`

5. **修改资源代际**  
   改 builtin/locale 后递增 `LuantiAssets.ASSETS_GENERATION`（当前 **29**）。

### 7.3 CMake 开关

| 开关 | 位置 | 含义 |
|------|------|------|
| `VOXERA_BUILD_LUANTI` | `entry/.../CMakeLists.txt` | ON：链接完整 Luanti；OFF：仅 EGL 预览 |
| `OHOS` / `__OHOS__` | `luanti/CMakeLists.txt` | 鸿蒙工具链与移植代码 |

---

## 8. 许可证与上游链接

### 8.1 许可证

本仓库与 Luanti 引擎采用 **[LGPL-2.1-or-later](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html)**。

| 文件 | 说明 |
|------|------|
| [`COPYING.LESSER`](COPYING.LESSER) | LGPL 全文 |
| [`NOTICE.md`](NOTICE.md) | Voxera 衍生声明与源码获取 |
| [`luanti/LICENSE.txt`](luanti/LICENSE.txt) | Luanti **媒体资源**（纹理、音效等）许可 |

分发 **HAP/二进制** 时须按 LGPL 提供对应源码（本仓库即源码之一）。

### 8.2 上游与致谢

| 项目 | 链接 | 关系 |
|------|------|------|
| **Luanti** | <https://www.luanti.org/> · <https://github.com/luanti-org/luanti> | 🟦 引擎本体 |
| **SDL2** | <https://www.libsdl.org/> | 🟪 多媒体层；本仓库使用鸿蒙移植 fork |
| **Voxera 鸿蒙版** | <https://github.com/Mencaje/voxera-harmonyos> | 🟩 本仓库 |

### 8.3 相关文档

- 平台说明：[`docs/PLATFORM.md`](docs/PLATFORM.md)
- 更细的合规说明：[`NOTICE.md`](NOTICE.md)

---

## 附录 A：一张图串起「从图标到主菜单」

```
[用户] 点击 Voxera 图标
    → 🟧 系统 Start Window
    → 🟧 EntryAbility → Game.ets 第二层遮罩
    → 🟩 LuantiAssets 解压/校验 → setAppDataPaths
    → 🟧 XComponent onLoad → 🟩 Surface → 线程 SDL_Main
    → 🟩 porting_ohos 默认设置 zh_CN、键鼠模式
    → 🟪 SDL OHOS 绑定 XComponent EGL
    → 🟦 Irrlicht OGLES2 + guiEngine 主菜单 Lua
    → 🟩 ohosEngineStatus "main_menu:…" → 遮罩关闭
    → [用户] 看到 Luanti/Voxera 主菜单（键鼠操作）
```

---

## 附录 B：谁负责什么（速查）

| 能力 | 主要负责层 |
|------|------------|
| 方块世界、物理、联机协议 | 🟦 Luanti |
| 主菜单 UI、内置游戏逻辑 | 🟦 Luanti `builtin/` Lua |
| 鸿蒙路径、默认设置、键鼠队列 | 🟩 `porting_ohos.cpp` |
| GPU 画到屏幕 | 🟪 SDL XComponent + 🟦 Irrlicht |
| 安装 HAP 资源、启动遮罩、权限 | 🟩 ArkTS `entry/` |
| 选 zip、浏览器、全屏、文件管理器 | 🟩 `OhosUiBridge` + 🟧 系统 Ability |
| 窗口标题区、沉浸全屏 | 🟩 `WindowDecorHelper` + 🟧 `window` API |

---

*本文档随仓库代码更新；若与实现不一致，以源码为准。欢迎向 [voxera-harmonyos](https://github.com/Mencaje/voxera-harmonyos) 提交 Issue/PR 修正文档。*

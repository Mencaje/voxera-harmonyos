# 平台与操作说明（Voxera 2.0）

> 完整架构导读见根目录 [`README.md`](../README.md)。本文档为**平台矩阵速查**与 GitHub About 文案。

---

## 版本与支持范围

| 版本 | 平台 | 状态 |
|------|------|------|
| **1.0** | 仅 **2in1 PC**（键鼠） | 已 supersede |
| **2.0** | **手机 + 平板 + 2in1 PC** | **当前主线** |

### 设备类型映射

| HarmonyOS `deviceType` | 打包 `deviceTypes` | 运行时枚举 | 典型设备 |
|------------------------|---------------------|------------|----------|
| `default` | `default` | Phone | 华为手机 |
| `tablet` | `tablet` | Tablet | 华为平板 |
| `2in1` | `2in1` | Pc2in1 | 鸿蒙 PC / 二合一 |

- **Native ABI**：`arm64-v8a`（真机 ARM）+ `x86_64`（模拟器 / x86 设备），同一 HAP 双架构
- **屏幕方向**：全局横屏（`module.json5` → `orientation: landscape`）

### 构建产物

| Product | runtimeOS | SDK | 用途 |
|---------|-----------|-----|------|
| `default` | HarmonyOS | 6.0.2 (API 22) | 华为商用手机 / 平板 |
| `oh` | OpenHarmony | 6.0.0 (API 20) | PC 2in1、OH 模拟器 |

---

## 操作方式

| 平台 | 主输入 | 辅助输入 | 主菜单 UI |
|------|--------|----------|-----------|
| **手机** | 虚拟摇杆 + 触屏 | 跳跃键、背包/暂停按钮 | **ArkUI 自研** |
| **平板** | 键盘 + 鼠标（推荐） | 触屏 overlay（视角/交互） | Luanti Lua |
| **PC（2in1）** | 键盘 + 鼠标 | — | Luanti Lua |

---

## 2.0 平台能力对照

| 能力 | 手机 | 平板 | PC |
|------|:----:|:----:|:--:|
| 自研 ArkUI 主菜单 | ✅ | — | — |
| Luanti Lua 主菜单 | — | ✅ | ✅ |
| 原生暂停菜单（单人） | ✅ | — | — |
| 虚拟摇杆 / 跳跃 | ✅ | — | — |
| 触屏视角 / 挖掘 / 放置 | ✅ | ✅ | — |
| 背包 toggle 按钮 | ✅ | — | — |
| Formspec 原生键盘 | ✅ | — | — |
| 快捷栏 touch 选中 | ✅ | ✅ | — |
| zip 拖拽安装 | — | ✅ | ✅ |
| WindowDecorCapsule | — | — | ✅ |
| 震动反馈 | ✅ | — | — |
| 法律 / 健康声明 | ✅ 全屏 | ✅ 子窗口 | ✅ 子窗口 |

图例：✅ 已实现；— 不适用或未单独实现。

---

## 手机 2.0 专有能力摘要

- **PhoneLocalGamePanel**：原生主页（世界列表、创建、联机）
- **PhoneMoreMenuScreen**：设置 / 内容 / 关于（四圆点菜单）
- **PhoneGameControls**：游戏内摇杆、跳跃、背包 toggle、小地图、暂停
- **PhoneInGamePauseOverlay**：原生暂停（继续 / 设置 / 退出）
- **PhoneFormspecTextInput**：背包等 formspec 编辑框的原生键盘
- **C++ 触屏层**（`ohos_touch_dispatch.cpp`）：滑动视角、短按放置、长按挖掘

---

## 暂不作为主线

- HarmonyOS **API 22+** 单独拆分产物（当前 `default` product 已用 22 compileSdk）
- 2in1 商用云真机专项调优
- 平板专用 ArkUI 布局（有意与 PC 共用 Lua UI）

---

## 仓库简介（可复制到 GitHub About）

```
Voxera 鸿蒙版 2.0：基于 Luanti 的全平台方块沙盒客户端。
支持鸿蒙手机（自研 ArkUI）/ 平板 / PC（2in1），键鼠与触屏。
```

英文：

```
Voxera for HarmonyOS 2.0 — Luanti-based voxel sandbox for phone (native ArkUI), tablet & 2in1 PC.
```

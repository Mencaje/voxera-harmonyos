# Voxera for HarmonyOS（Voxera 鸿蒙版）

[![License: LGPL v2.1+](https://img.shields.io/badge/License-LGPL%20v2.1%2B-blue.svg)](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html)

Voxera 鸿蒙版：基于 [Luanti](https://www.luanti.org/) 的方块沙盒客户端，运行于 HarmonyOS / OpenHarmony。适配鸿蒙 PC（2in1），含中文界面、本地 Mod/游戏包安装，并针对鸿蒙窗口、键鼠与触控做了优化。

## 仓库结构

| 目录 | 说明 |
|------|------|
| `entry/` | HarmonyOS 应用壳（ArkTS + NAPI） |
| `luanti/` | Luanti 引擎与客户端（含鸿蒙移植补丁） |
| `third_party/ohos_sdl2/` | SDL2 鸿蒙适配 |
| `entry/ohos_deps/` | 预编译原生依赖（需自行按文档放置，见 `.gitkeep`） |

## 构建要求

- [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/)（OpenHarmony SDK，API 20+）
- HarmonyOS 原生依赖库放入 `entry/ohos_deps/<abi>/`（arm64-v8a / x86_64 等）
- 使用 hvigor 构建：`hvigorw assembleHap`

详细步骤见 `docs/`（如有）或 `entry` 模块内注释。

## 许可证

本仓库与所基于的 [Luanti](https://github.com/luanti-org/luanti) 引擎采用相同协议：

**[GNU Lesser General Public License v2.1 或更高版本（LGPL-2.1-or-later）](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html)**

| 文件 | 说明 |
|------|------|
| [`COPYING.LESSER`](COPYING.LESSER) / [`LICENSE`](LICENSE) | LGPL-2.1 协议全文 |
| [`NOTICE.md`](NOTICE.md) | Voxera 衍生作品声明与 LGPL 源码获取说明 |
| [`luanti/LICENSE.txt`](luanti/LICENSE.txt) | Luanti 纹理、音效等媒体资源许可 |

Voxera 鸿蒙版为 Luanti 的衍生作品；分发二进制时须按 LGPL 向用户提供对应源码。游戏内容与第三方 Mod 可能另有各自许可证。

## 致谢

- [Luanti](https://github.com/luanti-org/luanti) — 开源方块沙盒引擎
- [SDL2](https://www.libsdl.org/) — 跨平台多媒体层

## 链接

- 仓库：<https://github.com/Mencaje/voxera-harmonyos>

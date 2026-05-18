# Voxera for HarmonyOS（Voxera 鸿蒙版）

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

- 本仓库中 **Luanti 引擎及上游资源** 遵循 [Luanti 许可证](luanti/COPYING.LESSER)（LGPL-2.1-or-later 等，见 `luanti/LICENSE.txt`）。
- **Voxera** 鸿蒙壳与移植代码：请以仓库根目录 `LICENSE` 为准（若未单独声明，引擎部分仍受 Luanti 许可约束）。
- 游戏内容与 Mod 可能另有各自许可证。

## 致谢

- [Luanti](https://github.com/luanti-org/luanti) — 开源方块沙盒引擎
- [SDL2](https://www.libsdl.org/) — 跨平台多媒体层

## 链接

- 仓库：<https://github.com/Mencaje/voxera-harmonyos>

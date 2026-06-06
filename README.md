# ramboplay-wine

Nix flake environment for running [Ramboplay (蓝博玩)](https://client.ok-skins.com) — a Red Alert 2 / Yuri's Revenge game launcher — under Wine on Linux.

**结论：WebView2 嵌入浏览器在 Wine 下不可用。后端完全正常，但前端 GUI 无法渲染。**

## Prerequisites

- [Nix](https://nixos.org/download) with flakes enabled
- `ramboply.2.2.6_full.7z` archive placed in this directory

## Quick Start

```bash
nix develop                         # 进入环境（自动解压 + .NET 5 + DXVK + 字体）
wine client/ramboplay.ra2.exe       # 启动后端 + WebView2 窗口
```

后端 API 监听 **`http://localhost:3600`**。

Caddy 反向代理（手动启动）：
```bash
caddy run --config Caddyfile        # 代理 → http://localhost:3601
```

## 架构

Ramboplay 是双层 ASP.NET Core 5.0 应用：

```
ramboplay.ra2.exe (C# WPF 宿主)
  ├── ASP.NET Core 后端 (localhost:3600)
  │   ├── 用户认证 (api.ok-skins.com)
  │   ├── WebSocket 游戏大厅
  │   ├── 地图加载 (200+ 张)
  │   └── 游戏启动 (gamemd.exe)
  └── Edge WebView2 嵌入浏览器
      └── 加载 client.ok-skins.com (远程 SPA 前端)
          └── C# 通过 WebView2 API 注入 auth token
              └── 显示启动器 UI
```

## 运行状态

| 组件 | 状态 | 说明 |
|------|------|------|
| ASP.NET Core 后端 | ✅ 正常 | localhost:3600，完整功能 |
| 用户认证 | ✅ 正常 | 自动登录获取 token |
| 地图加载 | ✅ 正常 | 200+ 张地图 |
| WebSocket 大厅 | ✅ 正常 | 连接游戏服务器 |
| Caddy 反向代理 | ✅ 正常 | localhost:3601 提供远程前端 |
| **WebView2 渲染** | ❌ **不可用** | **见下方详解** |
| Data Protection | ⚠️ 降级 | BCrypt/DPAPI 不可用，不影响功能 |
| Windows Task Scheduler | ⚠️ 未实现 | 根启动器自动启动注册失败 |

## WebView2 故障分析

### 症状

- 大窗口：完全空白（WebView2 容器窗口，渲染器崩溃无法绘制）
- 小弹窗：带图标（C# 层的 `CoreWebView2_ProcessFailed` 错误通知）
- 每个启动周期产生 5-8 个 crash dump 文件（渲染器反复崩溃→重启→崩溃）

### 试错过程

| 尝试 | 配置 | 结果 |
|------|------|------|
| 1 | Wine 11.0 裸跑 | `hostfxr.dll` 缺失 → 安装 .NET 5.0 |
| 2 | Wine 11.0 + .NET 5.0 | 后端运行，WebView2 `RenderProcessExited,Crashed` |
| 3 | + DXVK 2.7.1（D3D11→Vulkan） | GPU 进程启动但崩溃，无渲染器存活 |
| 4 | + `--use-angle=vulkan`（绕过 D3D11） | GPU 进程出现，反复崩溃，每 8 秒 8 个 dump |
| 5 | + `--disable-gpu`（纯软件渲染） | 渲染器进程立即退出，0 个存活 |
| 6 | Wine staging 11.9 + 以上全部 | 同样结果，无改善 |

### 根本原因

`client/webruntimes/msedgewebview2.exe` 是 **原生 Windows Edge WebView2 运行时**（Chromium 内核），其 GPU 渲染管道依赖：

- Windows DirectComposition / DWM
- Windows GPU 进程沙箱
- Direct3D 11/12 底层 API
- Windows 图形驱动模型 (WDDM)

Wine 在这些层面的模拟不完整：

1. **DXVK 路径**（D3D11 → Vulkan）：GPU 进程能启动但初始化后立即崩溃 — ANGLE 的 D3D11 后端与 Wine 的 D3D 实现存在兼容性缺口
2. **Vulkan 直通**（`--use-angle=vulkan`）：GPU 进程能启动但反复崩溃 — Chromium 的 Vulkan 后端需要 Windows 特定的 swapchain/surface 管理
3. **软件渲染**（`--disable-gpu`）：Skia 软件光栅化器在 Wine 下无法初始化帧缓冲 — 渲染器进程直接退出

## 可行的替代方案

1. **Windows 虚拟机 + GPU 直通**
   - 使用 KVM/QEMU + VFIO GPU passthrough
   - 完整原生体验

2. **直接运行游戏**（绕过启动器）
   - `client/Resources/` 包含游戏文件（`game.zip`, `ares.zip` 等）
   - 解压后可尝试 `wine gamemd.exe` 或 Ares 引擎的 `gamemd-spawn.exe`

3. **远程前端 + Caddy 代理**
   - 后端正常 → 如果有人能逆向 WebView2 的 token 注入机制，就可以用本地浏览器
   - 目前 SPA 停留在启动画面（等待 C# 注入 auth token）

## Flake 组件

| 组件 | 版本 | 用途 |
|------|------|------|
| Wine | staging 11.9 | Windows 兼容层 |
| ASP.NET Core | 5.0.17 (x86) | 后端运行时 |
| DXVK | 2.7.1 | D3D11→Vulkan 转换 |
| Caddy | 2.x | 反向代理 |
| CJK Fonts | Source Han Sans + corefonts | 中文渲染 |
| p7zip | — | 解压归档 |

## 目录结构

```
.
├── flake.nix          # Nix 环境
├── flake.lock         # 锁定版本
├── Caddyfile          # 反向代理配置
├── README.md
├── .gitignore
├── client/            # 提取的启动器（gitignored）
├── .wine/             # Wine 前缀（gitignored）
└── ramboply.*.7z      # 原始归档（gitignored）
```

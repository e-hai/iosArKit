# Ar — 实时滤镜相机

iOS 15.6+ | Swift 5.0 | 零外部依赖 | 纯 Apple 原生框架

## 快速开始

```bash
git clone <repo-url> && cd Ar
open Ar.xcodeproj
# 选择 iOS 15.6+ 模拟器 → ⌘R
```

## 架构

```
MVVM + AppRouter（导航协调器）

SplashView → ContentView（滤镜选择 + 拍照入口）
                ├── CameraView（拍摄页面）
                │     ├── AVCaptureSession → CIFilter → Metal MTKView
                │     └── Camera/Filters/（滤镜链子系统）
                └── GalleryView（未来：相册浏览）
```

| 层 | 角色 | 示例 |
|----|------|------|
| View | SwiftUI UI 布局 | `CameraView`, `ContentView` |
| Router | 导航状态中心 | `AppRouter`（`@EnvironmentObject`） |
| Manager | 业务状态和逻辑 | `CameraManager`（`ObservableObject`） |
| Bridge | UIKit/Metal 桥接 | `CameraPreview`（`UIViewRepresentable`） |

## 技术栈

| 框架 | 用途 |
|------|------|
| SwiftUI + Combine | UI + 响应式状态 |
| AVFoundation | 相机采集、视频录制 |
| CoreImage + MetalKit | 实时滤镜 + GPU 渲染 |
| Photos | 相册保存 |
| Swift Testing + XCTest | 单元测试 + UI 测试 |

**零外部依赖**：无 CocoaPods / SPM / Carthage。详见 [`TECH_STACK.md`](TECH_STACK.md)。

## 开发规范

- 面向用户字符串和代码注释必须使用**中文**
- 单元测试使用 `@Test` / `#expect`（Swift Testing），非 XCTest
- 最低 iOS 15.6，禁止使用 `NavigationStack`、`@Observable` 等新 API
- 完整约束见 [`TECH_STACK.md`](TECH_STACK.md)，AI 指令见 [`CLAUDE.md`](CLAUDE.md)

## 文档索引

| 文档 | 说明 |
|------|------|
| [`TECH_STACK.md`](TECH_STACK.md) | 技术栈宪法：HARD/SOFT 约束、架构规范、管线细节 |
| [`CLAUDE.md`](CLAUDE.md) | AI 行为指令：检查清单、禁止重构 |
| [`docs/decisions/`](docs/decisions/) | 架构决策记录（ADR） |

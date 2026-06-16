# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## 约束指令（所有 AI 模型必须遵守）

### 引用文件

在回答任何技术问题或生成代码之前，**必须首先读取 `TECH_STACK.md`** 并遵守其中的所有约束。
TECH_STACK.md 中的 **HARD 约束** 是不可协商的，AI 在任何情况下都不得违反。

### 不可变更的硬约束 (HARD)

| # | 约束 | 说明 |
|---|---|---|
| 1 | **iOS 15.6** 最低部署目标 | 所有 API 必须兼容 iOS 15.6，不可使用 iOS 16+ only API（除非 `#available` 保护 + 回退） |
| 2 | **Swift 5.0** | 不可使用 Swift 5.9+ 语法特性 |
| 3 | **零外部依赖** | 仅使用 Apple 官方框架，禁止 CocoaPods / SPM / Carthage |
| 4 | **NavigationView** 导航 | 使用 `NavigationView` + 隐藏 `NavigationLink`，**禁止**使用 `NavigationStack`（iOS 16+） |
| 5 | **ObservableObject** 响应式 | 使用 `ObservableObject` + `@Published`，**禁止**使用 `@Observable` macro（iOS 17+） |
| 6 | **中文注释 + 中文 UI** | 代码注释必须用中文，UI 字符串必须用中文（String Catalogs 管理） |
| 7 | **目录组织** | 混合模式：核心文件在根目录，功能子系统按文件夹（`FeatureCamera/`、`FeatureGallery/`），通用组件放 `Common/`，文件夹统一 PascalCase |
| 8 | **Swift Testing** 单元测试 | 单元测试使用 `@Test` / `#expect`，不使用 XCTest 的 `XCTestCase` |
| 9 | **MainActor** 隔离 | `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` |
| 10 | **Combine + async/await 分工** | Combine 用于 UI 状态绑定和持续事件流；async/await 仅用于一次性异步操作（权限、相册保存）。两者共存，禁止互相替代 |
| 11 | **UserDefaults 持久化** | 仅使用 `UserDefaults` 存轻量偏好（默认滤镜索引等），禁止 Core Data / SwiftData / 第三方数据库 |

### 每次生成代码前必须检查

1. ✅ 是否使用了 iOS 16+ only 的 API？（若有，用 `#available` 保护 + 提供回退）
2. ✅ 是否正确使用了 `ObservableObject` / `@Published` 模式？
3. ✅ 文件是否放在了正确的目录？
4. ✅ 注释是否为中文？
5. ✅ Combine 是否仅用于 UI/事件流，async/await 是否仅用于一次性异步？

### 禁止的重构行为

- ❌ `NavigationView` → `NavigationStack`
- ❌ `ObservableObject` → `@Observable`
- ❌ 引入任何第三方依赖（含第三方数据库如 GRDB、Realm、FMDB）
- ❌ SwiftUI → UIKit 整体重写
- ❌ Combine → async/await 全面替换（两者按场景分工共存）

---

## Build & Test Commands

```bash
# Build (Debug)
xcodebuild -project Ar.xcodeproj -scheme Ar -configuration Debug build

# Build (Release)
xcodebuild -project Ar.xcodeproj -scheme Ar -configuration Release build

# Run unit tests (Swift Testing framework)
xcodebuild -project Ar.xcodeproj -scheme Ar -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run only ArTests target
xcodebuild -project Ar.xcodeproj -scheme Ar -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArTests test

# Run a single test
xcodebuild -project Ar.xcodeproj -scheme Ar -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArTests/ArTests/testName test

# Run UI tests
xcodebuild -project Ar.xcodeproj -scheme Ar -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArUITests test
```

Adjust `-destination` to match an available simulator (`xcrun simctl list devices`).

## Architecture

**Ar** is an iOS 15.6+ SwiftUI camera app with real-time Core Image filters and Metal-accelerated preview rendering. No external dependencies — pure Apple frameworks.

### App Lifecycle & Navigation

`ArApp.swift` is the `@main` entry point. It shows `SplashView` first (animated "场景滤镜相机" text, 1.5s), then transitions to the main `ContentView` (TabView). An `AppRouter` ObservableObject is injected as an `.environmentObject` at the root and drives all navigation.

Navigation uses a **hidden NavigationLink pattern** (not NavigationStack — the app targets iOS 15+):
1. `AppRouter` holds `@Published` booleans (`isCameraActive`, `isGalleryActive`).
2. `ContentView` contains invisible `NavigationLink` views bound to these booleans via `isActive:`.
3. Views call `router.navigate(to:)` / `router.pop(from:)` to push/pop.
4. `AppRouter` also carries `currentFilterIndex` (0=original, 1=sepia, 2=mono) so the filter choice made on the home screen is propagated to the camera.

### Camera Pipeline

The camera subsystem lives in `FeatureCamera/` and has four responsibilities:

| File | Role |
|---|---|
| `CameraView.swift` | SwiftUI view — UI controls (record/photo/switch camera), reads `router.currentFilterIndex` on appear, passes it to `CameraManager` |
| `CameraManager.swift` | ObservableObject / NSObject — owns the `AVCaptureSession`, processes frames via `AVCaptureVideoDataOutputSampleBufferDelegate`, applies CIFilter in real time, handles photo capture (CGImage → PHPhotoLibrary) and video recording (AVAssetWriter → .mp4 → PHPhotoLibrary) |
| `CameraPreview.swift` | `UIViewRepresentable` wrapping `MTKView` — renders `currentRenderedFrame` (CIImage) to the Metal drawable with aspect-fill scaling via `CGAffineTransform`, using a Metal-backed `CIContext` |
| `CameraAuthorization.swift` | Enum wrapping `AVCaptureDevice.authorizationStatus` — async request + system Settings redirect helper |

**Data flow**: `AVCaptureSession` → `CMSampleBuffer` → `CIImage` (with optional CIFilter applied) → `@Published currentRenderedFrame` → `CameraPreview` Coordinator's `MTKViewDelegate.draw(in:)` → Metal drawable

**Key implementation notes**:
- Camera session runs on a dedicated serial queue (`sessionQueue`), not the main thread.
- Video output connection is locked to `.portrait` orientation; mirroring is toggled for front camera at the connection level (not via manual image transforms).
- `switchCamera()` tears down and rebuilds the entire session (inputs + outputs) rather than using `AVCaptureSession`'s beginConfiguration for a single input swap — this avoids compatibility issues with `canAddInput` checks.
- Recordings are saved to a temp directory, written to the Photos library on finish, then the temp file is deleted.
- MTKView uses `autoResizeDrawable = true` and the Coordinator calculates a scale+translate transform to achieve aspect-fill rendering regardless of the camera's native pixel dimensions.

### Filter System

Current three modes, via `filterIndex`:

| Index | Name | CIFilter |
|-------|------|----------|
| 0 | 原画原色 | None（passthrough） |
| 1 | 复古暖调 | `CISepiaTone`（intensity 0.7） |
| 2 | 黑白电影 | `CIPhotoEffectMono` |

**Planned**: Expand to 8–10 preset filters. Metal pipeline will support LUT color lookup tables, beauty filter, and multi-filter chain (`FeatureCamera/Filters/FilterChain.swift`).

### Directory Organization

**混合模式**：核心文件在根目录，功能子系统按文件夹隔离，通用组件放 `Common/`。文件夹 PascalCase。

```
Ar/
├── ArApp.swift              # @main 入口
├── AppRouter.swift          # 单 Router 管理所有导航
├── ContentView.swift        # 主页：TabView
├── Localizable.xcstrings    # String Catalog 本地化字符串
├── Assets.xcassets/         # 资源（AccentColor、AppIcon 等）
├── Common/                  # 通用复用层
│   ├── ViewModifiers/       # 通用 ViewModifier
│   └── Utilities/           # 工具类型与扩展
│       └── TabBarHider.swift
├── Data/                   # 数据层（基础设施，无 Feature 前缀）
│   ├── Persistence/        # 持久化层
│   │   ├── UserDefaultsStorage.swift
│   │   └── FileStorage.swift
│   ├── Network/            # 网络层
│   │   ├── HTTPClient.swift
│   │   └── APIEndpoint.swift
│   └── Models/             # 全局数据模型
├── FeatureCamera/           # 相机子系统
│   ├── CameraAuthorization.swift
│   ├── CameraManager.swift
│   ├── CameraPreview.swift
│   ├── CameraView.swift
│   └── Filters/             # 滤镜链子系统（扩展中）
├── FeatureEditor/           # 图片/视频编辑子系统
│   ├── PhotoEditorView.swift
│   └── VideoEditorView.swift
├── FeatureGallery/          # 相册浏览（未来扩展）
├── FeatureMe/               # 个人中心与设置
│   ├── ProfileView.swift
│   └── SettingsView.swift
├── FeatureScene/            # 场景选择
│   ├── SceneSelectionView.swift
│   └── SceneType.swift
└── FeatureSplash/           # 启动动画
    └── SplashView.swift
```

新增文件时必须遵守此结构。

### Concurrency Model

- Combine 负责"数据随时间变化"的场景：`@Published` UI 绑定、持续事件流
- async/await 负责"发起一个操作，等它完成"的场景：权限请求、相册保存
- 后台串行队列（`sessionQueue`）用于 AVCaptureSession 帧处理
- 禁止将 Combine 替换为 async/await，反之亦然
- 跨线程 UI 更新必须切换到 `DispatchQueue.main`

### Persistence

- 仅 `UserDefaults` 存轻量偏好（默认滤镜索引、首次启动标记）
- 禁止 Core Data / SwiftData / 第三方数据库
- 结构化数据用 `Codable` + `FileManager` → JSON/Plist

### Testing

- **ArTests**: Uses the **Swift Testing** framework (`@Test`, `#expect`) — not XCTest. Import with `@testable import Ar`.
- **ArUITests**: Uses **XCTest** (XCUIApplication-based UI tests with screenshot attachments).

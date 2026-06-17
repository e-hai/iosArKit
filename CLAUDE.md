# Ar 技术栈规范与 AI 约束

> **本文档为项目的"宪法"级规范，合并自原 CLAUDE.md + TECH_STACK.md。**
> 所有代码变更、架构决策、依赖引入须遵守本文档。**HARD** 约束不可协商。
>
> 版本: 2.1 | 最后更新: 2026-06-17

---

## 一、项目概览

| 项目 | 内容 |
|------|------|
| 名称 | **Ar** — iOS 实时滤镜相机应用 |
| 技术定位 | **纯 Apple 原生框架，零外部依赖**（HARD） |
| 最低部署 | **iOS 15.6**（HARD） |
| Swift 版本 | **5.0**（HARD） |
| 架构 | MVVM + AppRouter（ObservableObject 导航协调器） |
| Bundle ID | Debug `com.eveo.Ar` / Release `com.Ar` |
| Team | WS74WR4265 |
| 目标设备 | iPhone（主）+ iPad（兼容），`TARGETED_DEVICE_FAMILY = 1,2` |

**核心能力**：SwiftUI + Combine 响应式数据流 → AVCaptureSession 相机采集 → CIFilter 实时滤镜 → Metal MTKView 硬件加速渲染 → 拍照/录像保存到 PHPhotoLibrary。

---

## 二、不可变更的硬约束（HARD）

| # | 约束 | 说明 |
|---|------|------|
| 1 | **iOS 15.6 最低部署** | 所有 API 必须兼容，iOS 16+ API 须 `#available` 保护 + 回退 |
| 2 | **Swift 5.0** | 禁止 Swift 5.9+ 语法（如 `@Observable` macro） |
| 3 | **NavigationView** 导航 | 使用 `NavigationView` + 隐藏 `NavigationLink`，**禁止** `NavigationStack`（iOS 16+） |
| 4 | **ObservableObject** 响应式 | 使用 `ObservableObject` + `@Published`，**禁止** `@Observable` macro（iOS 17+） |
| 5 | **零外部依赖** | 仅 Apple 官方框架，禁止 CocoaPods / SPM / Carthage / `.framework` |
| 6 | **允许的框架白名单** | SwiftUI、Combine、AVFoundation、CoreImage、MetalKit、Photos、UIKit、Testing、XCTest；其他须更新本文档 |
| 7 | **MainActor 隔离** | `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` |
| 8 | **中文注释 + 中文 UI** | 注释必须中文；UI 字符串用中文，`.xcstrings` 管理 |
| 9 | **目录组织** | 混合模式：核心文件根目录，功能子系统按文件夹（`FeatureCamera/`），通用组件 `Common/`，PascalCase 命名 |
| 10 | **Combine + async/await 分工** | Combine 用于 UI 状态绑定和持续事件流；async/await 仅用于一次性异步操作（权限、相册保存）；禁止互相替代 |
| 11 | **UserDefaults 持久化** | 仅存轻量偏好，禁止 Core Data / SwiftData / 第三方数据库 |
| 12 | **Swift Testing 单元测试** | `@Test` / `#expect`，不得使用 XCTest 的 `XCTestCase`；UI 测试用 XCTest |
| 13 | **String Catalog** 本地化 | `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`，不用 `.strings` 文件 |

### 禁止的重构行为

- ❌ `NavigationView` → `NavigationStack`
- ❌ `ObservableObject` → `@Observable`
- ❌ 引入任何第三方依赖（含 GRDB、Realm、FMDB 等数据库）
- ❌ SwiftUI → UIKit 整体重写
- ❌ Combine → async/await 全面替换

---

## 三、关键 Build Settings

| 设置 | 值 | 约束 |
|------|-----|------|
| `IPHONEOS_DEPLOYMENT_TARGET` | `15.6` | HARD |
| `SWIFT_VERSION` | `5.0` | HARD |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` | HARD |
| `GENERATE_INFOPLIST_FILE` | `YES` | HARD |
| `LOCALIZATION_PREFERS_STRING_CATALOGS` | `YES` | HARD |
| `ENABLE_USER_SCRIPT_SANDBOXING` | `YES` | SOFT |
| `TARGETED_DEVICE_FAMILY` | `1,2` | SOFT |

**Info.plist 隐私权限**（已配置）：
| Key | 描述 |
|-----|------|
| `NSCameraUsageDescription` | 需要访问您的相机以拍摄照片 |
| `NSMicrophoneUsageDescription` | 录制视频时需要获取声音 |
| `NSPhotoLibraryAddUsageDescription` | 保存照片和视频到相册 |
| `NSPhotoLibraryUsageDescription` | 我们需要访问您的相册，以便您可以选择并上传头像或发送照片 |

---

## 四、架构规范

### 4.1 MVVM + AppRouter

```
View（SwiftUI View）
  → AppRouter / ViewModel（Action）
    → @Published 属性更新（State）
      → View 自动重渲染
```

- **View 层**：SwiftUI View struct，布局 + 交互
- **Router 层**：`AppRouter`（ObservableObject），导航状态，`.environmentObject` 注入
- **ViewModel 层**：`CameraViewModel`、`PhotoEditorViewModel`、`VideoEditorViewModel` 等（ObservableObject），持有业务状态和逻辑
- **Bridge 层**：`UIViewRepresentable` 封装 UIKit/Metal 视图

### 4.2 导航（隐藏 NavigationLink 模式）

```swift
NavigationView { ContentView() }
  .navigationViewStyle(.stack)
  .environmentObject(router)
```

1. `AppRouter` 持有 `@Published Bool`（`isCameraActive`、`isGalleryActive`）
2. `ContentView` 中包含不可见 `NavigationLink`，`isActive:` 绑定到这些 Bool
3. View 调用 `router.navigate(to:)` / `router.pop(from:)`
4. `AppRouter` 携带 `currentFilterIndex`（0/1/2）传播到相机

**导航流**：`SplashView（1.5s）` → `ContentView（TabView 主页）` → `CameraView` / `GalleryView`（未来）

### 4.3 并发模型

| 场景 | 方案 | 示例 |
|------|------|------|
| UI 状态绑定 | Combine（`@Published`） | `CameraViewModel.currentRenderedFrame` 驱动 MTKView |
| 持续事件流 | Combine（Publisher） | 滤镜切换、导航状态变更 |
| 一次性异步 | `async/await` | 权限请求、PHPhotoLibrary 保存 |
| 后台帧处理 | `DispatchQueue`（`sessionQueue`） | AVCaptureSession 帧处理 |

**原则**：Combine 不替代 async/await，反之亦然；跨线程 UI 更新必须切到 `DispatchQueue.main`。

### 4.4 持久化

- 仅 `UserDefaults` 存轻量偏好（默认滤镜索引、首次启动标记）
- 结构化数据（拍摄历史、自定义滤镜配置）用 `Codable` + `FileManager` → JSON/Plist
- 禁止 Core Data / SwiftData / 第三方数据库

---

## 五、相机管线

```
AVCaptureSession → CMSampleBuffer → CIImage（+可选 CIFilter）
  → @Published currentRenderedFrame → CameraPreview（MTKView）
    → Metal Drawable（屏幕渲染）
```

### 文件组织（`FeatureCamera/`）

| 文件 | 职责 |
|------|------|
| `CameraAuthorization.swift` | 权限状态枚举、异步请求、系统设置跳转 |
| `CameraView.swift` | SwiftUI UI（拍照/录像/切换摄像头） |
| `CameraViewModel.swift` | AVCaptureSession 管理、帧处理、CIFilter 应用、拍照/录像、倒计时 |
| `CameraPreview.swift` | UIViewRepresentable 封装 MTKView，Metal 渲染 |

### 关键实现要点

- **线程**：AVCaptureSession 运行在专用串行队列 `sessionQueue`，UI 更新切主线程
- **方向**：`videoOrientation = .portrait`，前置摄像头镜像在 AVCaptureConnection 层设置
- **摄像头切换**：重建式切换（完全移除输入输出后重新添加），不用 `beginConfiguration`
- **拍照**：从视频帧提取 `CGImage` → `PHPhotoLibrary`
- **录像**：`AVAssetWriter` → 临时 `.mp4` → 保存到相册 → 删除临时文件
- **MTKView**：`autoResizeDrawable = true`，Coordinator 计算 scale+translate 实现 aspect-fill

### 滤镜系统

| 索引 | 名称 | CIFilter |
|------|------|----------|
| 0 | 原画原色 | 无（passthrough） |
| 1 | 复古暖调 | `CISepiaTone`（intensity 0.7） |
| 2 | 黑白电影 | `CIPhotoEffectMono` |

**计划扩展**（SOFT）：8–10 种预设滤镜（冷色调、暖色调、高对比度、褪色、宝丽来等），仅预设不开放参数调节。`filterIndex` 演进为 `filterChain: [CIFilter]`，独立为 `FilterChain` 类型。支持 LUT 色彩查找表（`CIColorCube`）和实时美颜（`CIFilter` 组合），由 `FeatureCamera/Filters/` 下的子模块实现。

---

## 六、目录结构

```
Ar/
├── CLAUDE.md                    # 本文档
├── Ar.xcodeproj/
├── Ar/                          # 主应用源码
│   ├── ArApp.swift              # @main 入口
│   ├── AppRouter.swift          # 导航路由
│   ├── ContentView.swift        # 主页 TabView
│   ├── Localizable.xcstrings    # String Catalog
│   ├── Assets.xcassets/         # 资源（颜色、AppIcon、LUT 文件）
│   ├── Common/                  # 通用复用层
│   │   ├── ViewModifiers/       # 通用 ViewModifier
│   │   └── Utilities/           # 工具类型与扩展
│   │       ├── TabBarHider.swift
│   │       └── UIApplication+safeArea.swift
│   ├── Data/                    # 数据层（无 Feature 前缀）
│   │   ├── Persistence/         # UserDefaultsStorage.swift + FileStorage.swift
│   │   ├── Network/             # HTTPClient.swift + APIEndpoint.swift
│   │   └── Models/              # 全局数据模型
│   ├── FeatureCamera/           # 相机子系统
│   │   ├── CameraAuthorization.swift
│   │   ├── CameraViewModel.swift
│   │   ├── CameraPreview.swift
│   │   ├── CameraView.swift
│   │   └── Filters/             # FilterChain、FilterPresets、LUTLoader、BeautyFilter
│   ├── FeatureEditor/           # 图片/视频编辑
│   │   ├── PhotoEditorView.swift
│   │   ├── PhotoEditorViewModel.swift
│   │   ├── VideoEditorView.swift
│   │   └── VideoEditorViewModel.swift
│   ├── FeatureGallery/          # 相册浏览（未来）
│   ├── FeatureMe/               # ProfileView.swift + SettingsView.swift
│   ├── FeatureScene/            # SceneSelectionView.swift + SceneType.swift
│   └── FeatureSplash/           # SplashView.swift
├── ArTests/                     # Swift Testing（@Test / #expect）
│   ├── ArTests.swift
│   ├── CameraTests/
│   └── FilterTests/
└── ArUITests/                   # XCTest（XCUIApplication）
    ├── ArUITests.swift
    └── ArUITestsLaunchTests.swift
```

**新增文件规则**：核心文件 → `Ar/` 根目录；功能子系统 → `Feature<Subsystem>/`；子系统内子模块 → `Feature<Subsystem>/<SubModule>/`；通用组件 → `Common/<Category>/`；测试 → `ArTests/` 或 `ArUITests/`。

---

## 七、代码风格

| 规则 | 说明 |
|------|------|
| **注释**（HARD） | 必须中文（函数说明、行内解释、MARK 分段），文件头部 Xcode 模板保持英文 |
| **UI 字符串**（HARD） | 中文，通过 `.xcstrings`（String Catalog）管理 |
| **命名**（SOFT） | 类型/协议 PascalCase，属性/方法 camelCase，遵循 Swift API Design Guidelines |
| **访问控制**（SOFT） | 默认 `internal`，对外 `public`，内部 `private`/`fileprivate`，`final class` 用于不需子类化类型 |

---

## 八、测试规范

| 测试类型 | 框架 | 命令 |
|---------|------|------|
| 单元测试（HARD） | Swift Testing（`import Testing` + `@Test` + `#expect`） | `xcodebuild ... test` |
| UI 测试（HARD） | XCTest（`import XCTest` + XCUIApplication） | `xcodebuild ... -only-testing:ArUITests test` |

**推荐覆盖**（SOFT）：滤镜映射、CameraViewModel 状态机、权限逻辑、导航路由。

### Build & Test 命令速查

```bash
# Build
xcodebuild -project Ar.xcodeproj -scheme Ar -configuration Debug build
xcodebuild -project Ar.xcodeproj -scheme Ar -configuration Release build

# All tests
xcodebuild -project Ar.xcodeproj -scheme Ar -destination 'platform=iOS Simulator,name=iPhone 16' test

# Unit tests only
xcodebuild -project Ar.xcodeproj -scheme Ar -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArTests test

# Single test
xcodebuild -project Ar.xcodeproj -scheme Ar -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArTests/ArTests/testName test

# UI tests only
xcodebuild -project Ar.xcodeproj -scheme Ar -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArUITests test
```

调整 `-destination` 匹配可用模拟器（`xcrun simctl list devices`）。

---

## 九、AI 行为约束

### 每次生成代码前检查清单

1. ✅ Swift 5.0 语法（非 5.9+）？
2. ✅ 所有 API iOS 15.6 可用？不可用则 `#available` + 回退？
3. ✅ `ObservableObject` + `@Published` 正确使用（非 `@Observable`）？
4. ✅ 文件在正确目录？
5. ✅ 注释和 UI 字符串为中文？
6. ✅ 无外部依赖引入？
7. ✅ Combine 仅用于 UI/事件流，async/await 仅用于一次性异步？

### 版本控制与变更流程

- AI **不得**擅自升级 iOS 部署目标（15.6）或 Swift 版本（5.0）
- 如需升级：更新本文档 → 同步更新 `project.pbxproj` → 团队批准
- 所有 **HARD** 构建配置变更必须同步更新本文档和 `.pbxproj`

### 不确定性处理

不确定 API 在 iOS 15.6 是否可用时：查阅 Apple 文档 → 使用 `#available` 保护 → 提供回退实现 → 注释标注版本依赖。

---

## 附录：当前 Build Settings 快照

```
SWIFT_VERSION = 5.0
IPHONEOS_DEPLOYMENT_TARGET = 15.6
TARGETED_DEVICE_FAMILY = 1,2
SDKROOT = iphoneos
GENERATE_INFOPLIST_FILE = YES
LOCALIZATION_PREFERS_STRING_CATALOGS = YES
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
SWIFT_APPROACHABLE_CONCURRENCY = YES
ENABLE_USER_SCRIPT_SANDBOXING = YES
ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES
ENABLE_PREVIEWS = YES
MARKETING_VERSION = 1.0
CURRENT_PROJECT_VERSION = 1
PRODUCT_BUNDLE_IDENTIFIER = com.eveo.Ar (Debug) / com.Ar (Release)
DEVELOPMENT_TEAM = WS74WR4265
```

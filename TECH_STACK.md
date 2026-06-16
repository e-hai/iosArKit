# Ar 技术栈规范 (Tech Stack Specification)

> **本文档是项目的"宪法"级规范。所有代码变更、架构决策、依赖引入都须遵守本文档的约束。**
>
> 版本: 1.1 | 最后更新: 2026-06-11

---

## 约束层级说明

| 标记 | 含义 |
|---|---|
| **HARD** | 不可协商的硬约束。AI 和开发者在任何情况下都不得违反。违反即视为错误。 |
| **SOFT** | 推荐性约束。可以讨论和调整，但默认应遵守。偏离时需说明理由。 |

---

## 第一章：项目总览

### 1.1 项目身份

- **项目名称**：Ar
- **项目定位**：iOS 实时滤镜相机应用
- **技术定位**：**纯 Apple 原生框架，零外部依赖**（**HARD**）
- **Bundle ID**：Debug=`com.eveo.Ar`，Release=`com.Ar`
- **Development Team**：WS74WR4265

### 1.2 核心能力

- SwiftUI 界面 + Combine 响应式数据流
- AVCaptureSession 相机采集 + CIFilter 实时滤镜
- Metal MTKView 硬件加速预览渲染
- 拍照保存（CGImage → PHPhotoLibrary）+ 视频录制（AVAssetWriter → .mp4）
- UserDefaults 轻量偏好存储（默认滤镜选择等）

---

## 第二章：版本与目标平台

### 2.1 最低部署目标（**HARD**）

```
IPHONEOS_DEPLOYMENT_TARGET = 15.6
```

**任何新代码必须保持 iOS 15.6 向后兼容。**

### 2.2 Swift 版本（**HARD**）

```
SWIFT_VERSION = 5.0
```

### 2.3 目标设备

- iPhone（主目标），支持竖屏 + 横屏
- iPad（兼容目标），支持所有方向

### 2.4 禁止使用的 API（**HARD**）

以下 iOS 16+ / 17+ 专属 API **绝对禁止**在未受保护的情况下使用：

| 禁止 API | 最低要求 | 替代方案 |
|---|---|---|
| `NavigationStack` | iOS 16 | `NavigationView` + 隐藏 `NavigationLink` |
| `NavigationSplitView` | iOS 16 | `NavigationView` |
| `@Observable` macro | iOS 17 | `ObservableObject` + `@Published` |
| `SwiftData` | iOS 17 | `UserDefaults` 存轻量偏好，不使用数据库 |
| `SwiftUI Charts` | iOS 16 | 自定义绘制 |
| `TipKit` | iOS 17 | 无需 |
| `PhotosPicker` (SwiftUI) | iOS 16 | `UIImagePickerController` 桥接 |
| `.scrollPosition()` | iOS 17 | 传统 ScrollView 方案 |

**例外**：如果确实需要 iOS 16+ API，必须使用 `if #available(iOS 16, *)` 保护并提供 iOS 15 回退方案。

### 2.5 构建工具

- Xcode（任意可编译 Swift 5.0 + iOS 15.6 的版本）
- 命令行构建：`xcodebuild -project Ar.xcodeproj -scheme Ar`

---

## 第三章：依赖策略

### 3.1 零外部依赖原则（**HARD**）

**项目不使用任何第三方依赖。** 所有功能仅通过 Apple 官方 SDK 实现。

### 3.2 允许的框架白名单（**HARD**）

只有以下 Apple 框架允许在项目中使用：

| 框架 | 用途 |
|---|---|
| `SwiftUI` | UI 构建 |
| `Combine` | 响应式数据流 |
| `AVFoundation` | 相机采集、视频录制 |
| `CoreImage` | 实时滤镜处理 |
| `MetalKit` | GPU 加速渲染（MTKView） |
| `Photos` | 相册读写 |
| `UIKit` | 桥接（UIViewRepresentable 等） |
| `Testing`（Swift Testing） | 单元测试 |
| `XCTest` | UI 测试 |

**未在列表中列出的框架，默认禁止使用。** 如需引入新的 Apple 框架，必须先更新本文档的白名单。

### 3.3 明确禁止（**HARD**）

- ❌ CocoaPods
- ❌ Swift Package Manager（第三方包）
- ❌ Carthage
- ❌ 任何 GitHub 开源库
- ❌ 手动拖入的 `.framework` / `.xcframework` 文件

### 3.4 例外流程

若确实需要引入外部依赖，必须：
1. 在本文档中记录理由
2. 同步更新 CLAUDE.md
3. 团队讨论通过后方可引入

### 3.6 持久化策略（**HARD**）

- 仅使用 `UserDefaults` 存储轻量用户偏好（如默认滤镜索引、首次启动标记等）
- **禁止**引入 Core Data（API 复杂，超出需求）
- **禁止**引入 SwiftData（需要 iOS 17）
- **禁止**引入任何第三方数据库（GRDB、Realm、FMDB 等）
- 如需存储拍摄历史、自定义滤镜配置等结构化数据，使用 `Codable` + `FileManager` 写入 JSON/Plist 文件

### 3.5 本地化管理

- 使用 `.xcstrings`（String Catalog）管理本地化字符串（**HARD**）
- 不使用传统 `.strings` 文件
- 当前设置：`LOCALIZATION_PREFERS_STRING_CATALOGS = YES`

---

## 第四章：架构规范

### 4.1 整体架构（**HARD**）

```
MVVM + AppRouter（导航协调器）
```

层级划分：
- **View 层**：SwiftUI View struct，负责 UI 布局和用户交互
- **Router 层**：`AppRouter`（ObservableObject），持有导航状态，注入为 `.environmentObject`
- **ViewModel/Manager 层**：`CameraManager` 等（ObservableObject），持有业务状态和逻辑
- **Bridge 层**：`UIViewRepresentable` 封装 UIKit/Metal 视图

### 4.2 响应式模式（**HARD**）

- 使用 `ObservableObject` + `@Published` + `@StateObject` / `@ObservedObject` / `@EnvironmentObject`
- **禁止**使用 `@Observable` macro（需要 iOS 17）
- `AppRouter` 作为全局 `.environmentObject` 注入

### 4.3 导航规范（**HARD**）

**模式**：`NavigationView` + `.navigationViewStyle(.stack)` + 隐藏 `NavigationLink`

```
NavigationView {
    ContentView()
}
.navigationViewStyle(.stack)
.environmentObject(router)
```

**路由驱动**：
1. `AppRouter` 持有 `@Published Bool`（`isCameraActive`, `isGalleryActive`）
2. `ContentView` 中包含不可见 `NavigationLink`，绑定到这些 Bool
3. View 调用 `router.navigate(to:)` / `router.pop(from:)` 进行导航

**禁止**使用 `NavigationStack`（需要 iOS 16）。

### 4.4 Actor 隔离（**HARD**）

项目设置：
```
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
```

所有 View 和 ObservableObject 默认在主 actor 上。后台操作使用专用 `DispatchQueue`。

### 4.5 导航流程

```
SplashView（1.5s 动画）
  → ContentView（主页：滤镜选择 + 相机入口）
    → CameraView（相机拍摄页面）
    → GalleryView（未来扩展：相册浏览）
```

### 4.6 数据流原则（SOFT）

推荐单向数据流：
```
View（用户交互）
  → Router.navigate(to:) / Manager 方法（Action）
    → @Published 属性更新（State）
      → View 自动重渲染
```

### 4.7 并发模型（**HARD**）

Combine 和 async/await 共存，按场景分工：

| 场景 | 方案 | 示例 |
|------|------|------|
| UI 状态绑定 | Combine（`@Published`、`ObservableObject`） | `CameraManager.currentRenderedFrame` 驱动 MTKView 刷新 |
| 持续事件流 | Combine（`Publisher` / `@Published`） | 滤镜切换、导航状态变更 |
| 一次性异步操作 | `async/await` | 相机权限请求、PHPhotoLibrary 保存、AVAssetWriter 完成回调 |
| 后台串行队列 | `DispatchQueue` | AVCaptureSession 帧处理（`sessionQueue`） |

**原则**：
- Combine 负责"数据随时间变化"的场景（状态绑定、事件流）
- async/await 负责"发起一个操作，等它完成"的场景（权限、保存、网络请求）
- 两者不互相替代——禁止将 Combine 全面替换为 async/await，也禁止将 async/await 回调改为 Combine pipeline
- 跨线程 UI 更新必须切换到 `DispatchQueue.main`

---

## 第五章：相机管线规范

### 5.1 管线架构（**HARD**）

```
AVCaptureSession
  → CMSampleBuffer（视频帧）
    → CIImage（+ 可选 CIFilter 滤镜）
      → @Published currentRenderedFrame
        → CameraPreview（MTKView）
          → Metal Drawable（屏幕渲染）
```

### 5.2 文件组织（**HARD**）

相机子系统必须保持在 `FeatureCamera/` 目录下：

| 文件 | 职责 |
|---|---|
| `FeatureCamera/CameraAuthorization.swift` | 相机权限状态枚举、异步请求、系统设置跳转 |
| `FeatureCamera/CameraView.swift` | SwiftUI View：拍照/录像/切换摄像头 UI |
| `FeatureCamera/CameraManager.swift` | ObservableObject + NSObject：AVCaptureSession 管理、帧处理、拍照/录像 |
| `FeatureCamera/CameraPreview.swift` | UIViewRepresentable 封装 MTKView，Metal 渲染 |

新增相机相关文件必须放入 `FeatureCamera/` 目录。

### 5.3 线程模型（**HARD**）

- `AVCaptureSession` 运行在专用串行队列 `sessionQueue`（`"camera.session.pipeline.queue"`）
- 帧处理（滤镜、格式转换）在 `captureOutput(_:didOutput:from:)` 回调中执行
- UI 更新（`currentRenderedFrame` 发布）必须切换到 `DispatchQueue.main`
- 不得在回调中执行耗时同步操作

### 5.4 摄像头切换

- 使用**重建式切换**：完全移除所有输入输出后重新添加
- 不使用 `beginConfiguration` 单输入交换模式（避免 `canAddInput` 兼容性问题）

### 5.5 视频方向

- 固定竖屏输出：`videoOrientation = .portrait`
- 前置摄像头镜像在 `AVCaptureConnection` 层设置

### 5.6 滤镜系统

当前三种模式，通过 `filterIndex` 驱动：

| 索引 | 名称 | CIFilter |
|---|---|---|
| 0 | 原画原色 | 无（passthrough） |
| 1 | 复古暖调 | `CISepiaTone`（intensity 0.7） |
| 2 | 黑白电影 | `CIPhotoEffectMono` |

滤镜在 `captureOutput` 的 `switch filterIndex` 中应用。

**扩展方向**（SOFT）：
- 预设滤镜目标扩展至 **8–10 种**，涵盖常用摄影风格（冷色调、暖色调、高对比度、褪色、宝丽来等）
- 仅预设滤镜，不引入用户自定义参数调节（避免 UI 复杂度失控）
- 新增滤镜需更新 `filterIndex` 枚举映射及相关测试

### 5.7 拍照与录像

- **拍照**：从视频帧 pipeline 中提取 `CGImage`，保存到 `PHPhotoLibrary`
- **录像**：`AVAssetWriter` + `AVAssetWriterInputPixelBufferAdaptor`，写入临时 `.mp4`，完成后保存到相册并删除临时文件

### 5.8 Metal 管线扩展方向（SOFT）

当前 Metal 管线职责：通过 `CGAffineTransform` 做 aspect-fill 缩放渲染。

计划扩展能力：

| 能力 | 描述 | 优先级 |
|------|------|--------|
| **多滤镜链** | 支持多个 CIFilter 顺序叠加（如美颜 → LUT → 风格滤镜），管线需从单滤镜改为滤镜链数组 | 高 |
| **LUT 色彩查找表** | 加载 `.cube` / `.png` LUT 文件，通过 `CIColorCube` / `CIColorCubeWithColorSpace` 应用自定义色彩映射 | 高 |
| **实时美颜** | 使用 `CIFilter` 组合（平滑 + 锐化 + 肤色调整），或 Metal 自定义 Kernel 实现高性能美颜 | 中 |

架构预留原则：
- `CameraManager` 的 `filterIndex`（单索引）需演进为 `filterChain: [CIFilter]`（滤镜数组）
- 滤镜链组合逻辑独立为 `FilterChain` 类型，支持动态增删和重排
- Metal 渲染 Coordinator 保持单一 `CIImage` 输入，滤镜链合并在上游完成
- LUT 文件打包在 `Assets.xcassets` 中，运行时加载到 `CIColorCube`

---

## 第六章：项目结构与文件组织

### 6.1 目录结构（**HARD**）

**组织策略**：混合模式
- 应用级核心文件（`ArApp`、`AppRouter`、`ContentView`）放在 `Ar/` 根目录
- 功能子系统放在独立子目录（如 `FeatureCamera/`）
- 跨功能复用的通用代码放在 `Common/` 目录

**文件夹命名**：PascalCase（如 `FeatureCamera/`、`Filters/`、`Common/`），与 Swift 类型命名一致。

```
Ar/
├── CLAUDE.md                  # AI 约束指令（每次会话自动读取）
├── TECH_STACK.md              # 本文档：完整技术栈规范
├── .gitignore                 # Git 忽略规则
├── Ar.xcodeproj/
├── Ar/                        # 主应用源码
│   ├── ArApp.swift            # @main 入口
│   ├── AppRouter.swift        # 导航路由（单 Router 管理所有导航状态）
│   ├── ContentView.swift      # 主页
│   ├── Assets.xcassets/       # 资源（图片、颜色、AppIcon、LUT 文件）
│   ├── Common/                # 通用复用层
│   │   ├── ViewModifiers/     # 通用 ViewModifier
│   │   └── Utilities/         # 工具类型与扩展
│   │       └── TabBarHider.swift
│   ├── Data/                 # 数据层（基础设施，无 Feature 前缀）
│   │   ├── Persistence/      # 持久化层
│   │   │   ├── UserDefaultsStorage.swift
│   │   │   └── FileStorage.swift
│   │   ├── Network/          # 网络层
│   │   │   ├── HTTPClient.swift
│   │   │   └── APIEndpoint.swift
│   │   └── Models/           # 全局数据模型
│   ├── FeatureCamera/         # 相机子系统
│   │   ├── CameraAuthorization.swift
│   │   ├── CameraManager.swift
│   │   ├── CameraPreview.swift
│   │   ├── CameraView.swift
│   │   └── Filters/           # 滤镜链子系统
│   │       ├── FilterChain.swift       # 滤镜链组合与执行
│   │       ├── FilterPresets.swift     # 预设滤镜定义
│   │       ├── LUTLoader.swift         # LUT 文件加载
│   │       └── BeautyFilter.swift      # 美颜滤镜
│   ├── FeatureEditor/         # 图片/视频编辑子系统
│   │   ├── PhotoEditorView.swift
│   │   └── VideoEditorView.swift
│   ├── FeatureGallery/        # 相册浏览（未来）
│   ├── FeatureMe/             # 个人中心与设置
│   │   ├── ProfileView.swift
│   │   └── SettingsView.swift
│   ├── FeatureScene/          # 场景选择
│   │   ├── SceneSelectionView.swift
│   │   └── SceneType.swift
│   └── FeatureSplash/         # 启动动画
│       └── SplashView.swift
├── ArTests/                   # 单元测试（Swift Testing）
│   ├── ArTests.swift
│   ├── CameraTests/
│   └── FilterTests/
└── ArUITests/                 # UI 测试（XCTest）
    ├── ArUITests.swift
    └── ArUITestsLaunchTests.swift
```

**新增文件规则**：
- 应用级别文件 → `Ar/` 根目录
- 功能子系统 → `Ar/<Feature>/`（如 `FeatureCamera/`）
- 子系统内子模块 → `Ar/<Feature>/<SubModule>/`（如 `FeatureCamera/Filters/`）
- 通用组件 → `Ar/Common/<Category>/`（如 `Common/ViewModifiers/`）
- 测试文件 → `ArTests/` 或 `ArUITests/`，按功能分子目录

### 6.2 文件与文件夹命名（SOFT）

- Swift 源文件使用 `PascalCase.swift`，与主要类型名一致
- 文件夹使用 PascalCase（如 `FeatureCamera/`、`Filters/`、`Common/`），与 Swift 类型命名风格统一
- 每个文件包含一个主要类型 + 相关扩展

### 6.3 新增代码规则（**HARD**）

- 功能子系统放入对应子目录（如 `FeatureCamera/`）
- 应用级别文件放在 `Ar/` 根目录
- 测试文件分别放入 `ArTests/` 和 `ArUITests/`

---

## 第七章：代码风格

### 7.1 注释语言（**HARD**）

**所有代码注释必须使用中文。** 包括：
- 函数/属性说明注释
- 行内解释注释
- `// MARK:` 分段注释

文件头部 Xcode 模板注释保持英文（`// Created by a on YYYY/MM/DD.`）。

### 7.2 UI 语言（**HARD**）

**所有面向用户的 UI 字符串必须使用中文。** 使用 String Catalogs 管理本地化。

示例：
```swift
Text("智能滤镜相机")
Button("开启一致性渲染相机")
```

### 7.3 命名规范（SOFT）

- 类型/协议：`PascalCase`
- 属性/方法/变量：`camelCase`
- 遵循 [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- 避免缩写（`ciContext` 除外，因 Core Image 官方缩写为 CI）

### 7.4 访问控制（SOFT）

- 默认使用 `internal`（不写修饰符）
- 对外接口使用 `public`
- 内部实现使用 `private` / `fileprivate`
- `final class` 用于不需要子类化的类型

---

## 第八章：测试规范

### 8.1 单元测试框架（**HARD**）

**必须使用 Swift Testing 框架**（`import Testing`），不得使用 XCTest 的 `XCTestCase`。

```swift
import Testing
@testable import Ar

struct ArTests {
    @Test func example() async throws {
        #expect(true)
    }
}
```

### 8.2 UI 测试框架（**HARD**）

**必须使用 XCTest 框架**（`import XCTest`）。

### 8.3 测试目标（SOFT）

推荐覆盖：
- 滤镜逻辑（filterIndex → CIFilter 映射）
- 状态转换（CameraManager 状态机）
- CameraAuthorization 权限逻辑
- 导航路由逻辑

### 8.4 测试命令

```bash
# 全部测试
xcodebuild -project Ar.xcodeproj -scheme Ar \
  -destination 'platform=iOS Simulator,name=iPhone 16' test

# 仅单元测试
xcodebuild -project Ar.xcodeproj -scheme Ar \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArTests test

# 仅 UI 测试
xcodebuild -project Ar.xcodeproj -scheme Ar \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ArUITests test
```

---

## 第九章：Xcode Build Settings

### 9.1 关键设置（**HARD**）

以下 Xcode Build Settings 已锁定，不得随意更改：

| 设置项 | 值 | 约束 |
|---|---|---|
| `IPHONEOS_DEPLOYMENT_TARGET` | `15.6` | **HARD** |
| `SWIFT_VERSION` | `5.0` | **HARD** |
| `GENERATE_INFOPLIST_FILE` | `YES` | **HARD** |
| `LOCALIZATION_PREFERS_STRING_CATALOGS` | `YES` | **HARD** |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` | **HARD** |
| `SWIFT_APPROACHABLE_CONCURRENCY` | `YES` | **HARD** |
| `ENABLE_USER_SCRIPT_SANDBOXING` | `YES` | SOFT |
| `TARGETED_DEVICE_FAMILY` | `1,2`（iPhone + iPad） | SOFT |

### 9.2 Info.plist 隐私权限

以下权限描述已在 `project.pbxproj` 中配置（`GENERATE_INFOPLIST_FILE = YES`）：

| Key | 中文描述 |
|---|---|
| `NSCameraUsageDescription` | 需要访问您的相机以拍摄照片 |
| `NSMicrophoneUsageDescription` | 录制视频时需要获取声音 |
| `NSPhotoLibraryAddUsageDescription` | 保存照片和视频到相册 |
| `NSPhotoLibraryUsageDescription` | 我们需要访问您的相册，以便您可以选择并上传头像或发送照片 |

### 9.3 同步规则

所有 **HARD** 构建配置变更必须同时更新：
1. `Ar.xcodeproj/project.pbxproj`
2. 本文档的对应章节

---

## 第十章：AI 行为约束

### 10.1 约束层级（元约束）

本文档中标记为 **HARD** 的规则是 AI **绝对不能违反**的。任何代码生成、重构建议、架构变更都不得破坏 HARD 约束。

### 10.2 版本控制（**HARD**）

AI **不得**：
- 擅自升级最低部署版本（iOS 15.6）
- 擅自升级 Swift 版本
- 使用高于最低版本的 API 而不做兼容处理

### 10.3 禁止的重构行为（**HARD**）

AI **绝对不得**建议或执行以下重构：
- `NavigationView` → `NavigationStack`
- `ObservableObject` / `@Published` → `@Observable` macro
- 引入任何第三方依赖（SPM / CocoaPods / Carthage）
- 将 SwiftUI 改写为 UIKit
- 将 Combine 替换为 async/await（两者可共存）

### 10.4 生成代码前检查清单（**HARD**）

AI 在生成任何代码前**必须**逐项确认：

1. ✅ 是否使用了正确的 Swift 版本语法？（Swift 5.0，非 5.9+）
2. ✅ 是否所有 API 在 iOS 15.6 上可用？（不可用则需 `#available` 保护 + 回退方案）
3. ✅ 是否正确使用了 `ObservableObject` / `@Published` 模式？（非 `@Observable`）
4. ✅ 文件是否放在了正确的目录？（相机文件在 `FeatureCamera/`，测试文件在对应测试目录）
5. ✅ 注释和 UI 字符串是否使用了中文？
6. ✅ 是否引入了任何外部依赖？（若引入，即违反 HARD 约束）

### 10.5 技术债务处理流程

如果需要更新 Swift 版本或 iOS 版本：
1. 必须更新本文档
2. 必须同步更新 CLAUDE.md
3. 需要团队明确批准

### 10.6 不确定性处理

当 AI 不确定某个 API 在 iOS 15.6 上是否可用时：
- 查阅 Apple 官方文档
- 使用 `if #available(iOS 16, *)` 保护调用
- 提供 iOS 15 回退实现
- 在代码注释中标注版本依赖

---

## 附录 A：当前 Build Settings 快照

> 提取自 `Ar.xcodeproj/project.pbxproj`（2026-06-11）

```
SWIFT_VERSION = 5.0
IPHONEOS_DEPLOYMENT_TARGET = 15.6
TARGETED_DEVICE_FAMILY = 1,2
SDKROOT = iphoneos
GENERATE_INFOPLIST_FILE = YES
LOCALIZATION_PREFERS_STRING_CATALOGS = YES
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
SWIFT_APPROACHABLE_CONCURRENCY = YES
SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES
ENABLE_USER_SCRIPT_SANDBOXING = YES
ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES
ENABLE_PREVIEWS = YES
MARKETING_VERSION = 1.0
CURRENT_PROJECT_VERSION = 1
PRODUCT_BUNDLE_IDENTIFIER = com.eveo.Ar (Debug) / com.Ar (Release)
DEVELOPMENT_TEAM = WS74WR4265
```

---

## 附录 B：变更日志

| 日期 | 版本 | 变更内容 |
|---|---|---|
| 2026-06-11 | 1.1 | 新增：持久化策略、并发模型、滤镜/Metal 管线扩展方向，目录组织策略（混合模式 + PascalCase + Common/ + FeatureCamera/Filters/） |
| 2026-06-11 | 1.0 | 初始版本：定义完整技术栈规范，建立 HARD/SOFT 约束体系 |

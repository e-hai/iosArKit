//
//  AppRouter.swift
//  Ar
//
//  Created by a on 2026/6/10.
//

import SwiftUI
import Combine

/// 定义所有可导航的二级/三级页面
enum Screen {
    case camera
    case gallery
    case settings
    case photoPreview
}

/// 底部 Tab 类型
enum TabType: Int {
    case scene    = 0   // 场景 Tab
    case profile  = 1   // 我的 Tab
}

final class AppRouter: ObservableObject {
    // MARK: - 导航状态
    @Published var isCameraActive = false
    @Published var isGalleryActive = false
    @Published var isSettingsActive = false
    @Published var isPhotoPreviewActive = false

    // MARK: - Tab 状态
    @Published var selectedTab: TabType = .scene

    // MARK: - 场景状态
    /// 用户选择的拍摄场景，用于 CameraView 初始化滤镜
    @Published var selectedScene: SceneType?
    /// 统一控制当前全栈应用的滤镜样式（0: 无, 1: 复古, 2: 黑白）
    @Published var currentFilterIndex: Int = 0

    /// 拍照后的图片数据，传给预览/编辑页
    @Published var capturedPhotoImage: UIImage?

    // MARK: - 导航方法

    /// 选择场景并跳转到取景页
    func navigateToCamera(with scene: SceneType) {
        selectedScene = scene
        currentFilterIndex = scene.defaultFilterIndex
        isCameraActive = true
    }

    func navigate(to screen: Screen) {
        switch screen {
        case .camera:        isCameraActive = true
        case .gallery:       isGalleryActive = true
        case .settings:      isSettingsActive = true
        case .photoPreview:  isPhotoPreviewActive = true
        }
    }

    func pop(from screen: Screen) {
        switch screen {
        case .camera:        isCameraActive = false
        case .gallery:       isGalleryActive = false
        case .settings:      isSettingsActive = false
        case .photoPreview:  isPhotoPreviewActive = false
        }
    }
}

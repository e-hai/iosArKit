//
//  SceneType.swift
//  Ar
//
//  Created by a on 2026/6/12.
//

import Foundation

/// 拍摄场景类型，用于导航传参和默认滤镜选择
enum SceneType: String, CaseIterable {
    case scenery       = "scenery"       // Scenery
    case architecture  = "architecture"  // Architecture
    case object        = "object"        // Objects

    /// 场景名称（已本地化）
    var displayName: String {
        switch self {
        case .scenery:      return NSLocalizedString("Scenery", comment: "Scene type: scenery")
        case .architecture: return NSLocalizedString("Architecture", comment: "Scene type: architecture")
        case .object:       return NSLocalizedString("Objects", comment: "Scene type: object")
        }
    }

    /// SF Symbol 图标名称
    var icon: String {
        switch self {
        case .scenery:      return "mountain.2"
        case .architecture: return "building.2"
        case .object:       return "cube.box"
        }
    }

    /// 场景描述（已本地化）
    var sceneDescription: String {
        switch self {
        case .scenery:      return NSLocalizedString("For distant natural landscapes", comment: "Scenery description")
        case .architecture: return NSLocalizedString("For mid-distance architecture and streetscapes", comment: "Architecture description")
        case .object:       return NSLocalizedString("For close-up objects", comment: "Object description")
        }
    }

    /// Recommended Effects标签（已本地化）
    var recommendedEffects: String {
        switch self {
        case .scenery:
            return NSLocalizedString("Sunset · Aurora · Mist · Oil Painting · Vintage Film", comment: "Scenery recommended effects")
        case .architecture:
            return NSLocalizedString("Golden Hour · Neon Night · Rim Light · Geometric · Minimal Lines", comment: "Architecture recommended effects")
        case .object:
            return NSLocalizedString("Soft B&W · Warm Tone · Toy Animation · Food Gloss · Still Life", comment: "Object recommended effects")
        }
    }

    /// 默认滤镜索引（对应 CameraViewModel.filterIndex）
    var defaultFilterIndex: Int {
        switch self {
        case .scenery:      return 1   // 复古暖调（适合Scenery）
        case .architecture: return 2   // 黑白电影（适合Architecture线条）
        case .object:       return 0   // 原画原色（保留Objects真实色彩）
        }
    }
}

//
//  UIApplication+safeArea.swift
//  Ar
//
//  Created by a on 2026/6/17.
//

import UIKit

/// UIApplication 安全区域扩展，避免各 View 重复计算 safeAreaInsets
extension UIApplication {

    /// 顶部安全区域高度（状态栏 + 刘海区域）
    static var safeAreaTop: CGFloat {
        let scenes = shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        return window?.safeAreaInsets.top ?? 0
    }

    /// 底部安全区域高度（Home Indicator 区域）
    static var safeAreaBottom: CGFloat {
        let scenes = shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        return window?.safeAreaInsets.bottom ?? 0
    }
}

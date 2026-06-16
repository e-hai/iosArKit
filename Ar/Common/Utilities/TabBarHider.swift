//
//  TabBarHider.swift
//  Ar
//
//  Created by a on 2026/6/15.
//

import SwiftUI

/// TabBarHider：通过 UIViewRepresentable 找到当前 UITabBarController 并隐藏/显示底部 Tab 栏。
/// 使用方法：在需要隐藏 TabBar 的页面添加 .background(TabBarHider())
struct TabBarHider: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isHidden = true
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            TabBarHider.setTabBarHidden(true)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    /// 设置 TabBar 隐藏/显示（静态方法，可在任意地方调用）
    static func setTabBarHidden(_ hidden: Bool) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        findTabBarController(from: window.rootViewController)?.tabBar.isHidden = hidden
    }

    private static func findTabBarController(from vc: UIViewController?) -> UITabBarController? {
        if let tabBar = vc as? UITabBarController { return tabBar }
        for child in vc?.children ?? [] {
            if let found = findTabBarController(from: child) { return found }
        }
        return nil
    }
}

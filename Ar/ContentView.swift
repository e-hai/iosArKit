//
//  ContentView.swift
//  Ar
//
//  Created by a on 2026/6/1.
//

import SwiftUI

/// 主页：底部 Tab 容器
/// 场景 Tab → 场景选择页 → 取景页
/// 我 Tab → 个人中心 → 设置
struct ContentView: View {
    @EnvironmentObject var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            // Scene Tab
            NavigationView {
                SceneSelectionView()
                    .navigationTitle("Choose a Scene")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Scene", systemImage: "camera.viewfinder")
            }
            .tag(TabType.scene)

            // 我 Tab
            NavigationView {
                ProfileView()
                    .navigationTitle("Me")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Me", systemImage: "person.circle")
            }
            .tag(TabType.profile)
        }
        .accentColor(.orange)  // 选中 Tab 高亮色
    }
}

#Preview {
    ContentView()
        .environmentObject(AppRouter())
}

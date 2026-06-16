//
//  ProfileView.swift
//  Ar
//
//  Created by a on 2026/6/12.
//

import SwiftUI

/// 个人中心页（「我」Tab）
struct ProfileView: View {
    @EnvironmentObject var router: AppRouter
    @State private var photoCount = 0
    @State private var favoriteEffects: [String] = []

    var body: some View {
        List {
            // 用户信息区
            Section {
                HStack(spacing: 16) {
                    // 默认头像占位
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scene Filter Camera")
                            .font(.headline)
                        Text("\(photoCount) photos taken")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            // 收藏特效
            Section(header: Text("Favorite Effects")) {
                if favoriteEffects.isEmpty {
                    Text("No favorites yet. Save effects you love while shooting.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(favoriteEffects, id: \.self) { effect in
                        Label(effect, systemImage: "star.fill")
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        // 隐藏 NavigationLink：触发跳转到设置页
        .background(
            NavigationLink(
                destination: SettingsView(),
                isActive: $router.isSettingsActive
            ) { EmptyView() }
        )
        .onAppear {
            TabBarHider.setTabBarHidden(false)
        }
        // 顶部 bar 设置入口
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    router.navigate(to: .settings)
                }) {
                    Image(systemName: "gearshape")
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        ProfileView()
            .environmentObject(AppRouter())
    }
}

//
//  SceneSelectionView.swift
//  Ar
//
//  Created by a on 2026/6/12.
//

import SwiftUI

/// Scene选择页：展示Scenery/Architecture/Objects三个Scene卡片，点击后进入取景页
struct SceneSelectionView: View {
    @EnvironmentObject var router: AppRouter

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 副标题
                Text("Choose a scene and we'll recommend the best effects for it")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // 三个Scene卡片
                ForEach(SceneType.allCases, id: \.self) { scene in
                    SceneCard(scene: scene)
                        .onTapGesture {
                            router.navigateToCamera(with: scene)
                        }
                }
            }
            .padding()
        }
        // 隐藏 NavigationLink：触发跳转到 CameraView
        .background(
            NavigationLink(
                destination: CameraView(),
                isActive: $router.isCameraActive
            ) { EmptyView() }
        )
        .onAppear {
            TabBarHider.setTabBarHidden(false)
        }
    }
}

// MARK: - Scene卡片

private struct SceneCard: View {
    let scene: SceneType

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 图标 + 标题行
            HStack(spacing: 12) {
                Image(systemName: scene.icon)
                    .font(.system(size: 36))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(cardColor)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(scene.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text(scene.sceneDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }

            // Recommended Effects标签
            HStack(spacing: 4) {
                Text("Recommended Effects")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(scene.recommendedEffects)
                    .font(.caption)
                    .foregroundColor(cardColor)
                    .lineLimit(1)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
        )
    }

    private var cardColor: Color {
        switch scene {
        case .scenery:      return .green
        case .architecture: return .blue
        case .object:       return .orange
        }
    }
}

#Preview {
    NavigationView {
        SceneSelectionView()
            .environmentObject(AppRouter())
    }
}

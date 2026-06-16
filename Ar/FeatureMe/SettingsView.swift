//
//  SettingsView.swift
//  Ar
//
//  Created by a on 2026/6/12.
//

import SwiftUI

/// 设置页（3.3.3）
/// 五项核心功能：个人资料、评价与反馈、用户协议、隐私协议、关于
struct SettingsView: View {
    @EnvironmentObject var router: AppRouter
    @AppStorage("showGrid") private var showGrid = false
    @AppStorage("gridType") private var gridType = 0      // 0: 九宫格, 1: 黄金分割, 2: 水平仪
    @AppStorage("timerDuration") private var timerDuration = 0  // 0: 关闭, 1: 3s, 2: 5s, 3: 10s

    var body: some View {
        List {
            // MARK: - 个人资料
            Section(header: Text("Profile")) {
                NavigationLink(destination: profileEditView) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tap to set nickname and avatar")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Text("Edit Profile")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // MARK: - 评价与反馈
            Section(header: Text("Rating & Feedback")) {
                Button(action: {
                    openAppStoreReview()
                }) {
                    Label("Rate on App Store", systemImage: "star.bubble")
                        .foregroundColor(.primary)
                }

                NavigationLink(destination: feedbackView) {
                    Label("Send Feedback", systemImage: "envelope")
                }
            }

            // MARK: - 构图辅助线
            Section(header: Text("Composition Guides")) {
                Toggle("Show Guides", isOn: $showGrid)

                if showGrid {
                    Picker("Guide Type", selection: $gridType) {
                        Text("Rule of Thirds").tag(0)
                        Text("Golden Ratio").tag(1)
                        Text("Level").tag(2)
                    }
                }
            }
            

            // MARK: - 倒计时拍摄
            Section(header: Text("Timer")) {
                Picker("Timer", selection: $timerDuration) {
                    Text("Close").tag(0)
                    Text("3s").tag(1)
                    Text("5s").tag(2)
                    Text("10s").tag(3)
                }
            }

            // MARK: - 协议
            Section(header: Text("Agreements")) {
                NavigationLink(destination: userAgreementView) {
                    Label("User Agreement", systemImage: "doc.text")
                }

                NavigationLink(destination: privacyAgreementView) {
                    Label("Privacy Agreement", systemImage: "hand.raised")
                }
            }

            // MARK: - 关于
            Section(header: Text("About")) {
                HStack {
                    Text("App Name")
                    Spacer()
                    Text("Scene Filter Camera")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Positioning")
                    Spacer()
                    Text("Focus on Scenery · Architecture · Objects")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Development Team")
                    Spacer()
                    Text("Ar Studio")
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(TabBarHider())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - 子页面：个人资料编辑

    private var profileEditView: some View {
        Form {
            Section(header: Text("Avatar")) {
                HStack {
                    Spacer()
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.vertical, 8)
            }

            Section(header: Text("Nickname")) {
                TextField("Please enter a nickname", text: .constant(""))
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 子页面：意见反馈

    private var feedbackView: some View {
        Form {
            Section(header: Text("Feedback Type")) {
                Picker("Type", selection: .constant(0)) {
                    Text("Feature Suggestion").tag(0)
                    Text("Bug Report").tag(1)
                    Text("Other").tag(2)
                }
            }

            Section(header: Text("Feedback Content")) {
                TextEditor(text: .constant(""))
                    .frame(minHeight: 150)
            }

            Section {
                Button("Submit") {
                    // TODO: 实现反馈提交逻辑
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.orange)
            }
        }
        .navigationTitle("Send Feedback")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 子页面：用户协议

    private var userAgreementView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("User Agreement")
                    .font(.title)
                    .fontWeight(.bold)

                Text("""
                    欢迎使用场景滤镜相机（以下简称"本应用"）。请仔细阅读以下条款：

                    1. 服务说明
                    本应用提供基于场景的实时滤镜拍摄功能，包括但不限于拍照、录像、特效叠加及基础编辑。

                    2. 用户责任
                    用户应遵守相关法律法规，不得利用本应用制作、传播违法内容。

                    3. 知识产权
                    本应用所提供特效、滤镜及相关技术内容的知识产权归开发团队所有。

                    4. 免责声明
                    在适用法律允许的最大范围内，本应用按"现状"提供，不提供任何明示或暗示的担保。

                    5. 协议变更
                    我们保留随时修改本协议的权利，修改后的协议一经发布即生效。
                    """)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("User Agreement")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 子页面：隐私协议

    private var privacyAgreementView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Agreement")
                    .font(.title)
                    .fontWeight(.bold)

                Text("""
                    我们重视您的隐私。本隐私协议说明我们如何收集、使用和保护您的个人信息。

                    1. 信息收集
                    本应用仅在您主动使用时访问相机和相册权限，用于实现拍照和录像功能。
                    我们不会在后台收集您的任何个人信息。

                    2. 权限说明
                    - 相机权限：用于实时取景和拍摄
                    - 麦克风权限：用于录制视频时采集声音
                    - 相册权限：用于保存拍摄的照片和视频

                    3. 数据存储
                    您拍摄的照片和视频仅保存在您的设备本地或您授权的云服务中，
                    我们不会上传或分析您的内容。

                    4. 第三方服务
                    本应用不集成任何第三方数据分析或广告 SDK，
                    不会向第三方共享您的数据。

                    5. 联系我们
                    如您对隐私政策有任何疑问，请通过应用内反馈渠道联系我们。
                    """)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("Privacy Agreement")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 跳转 App Store 评分

    private func openAppStoreReview() {
        // TODO: 替换为真实 App ID
        guard let url = URL(string: "https://apps.apple.com/app/id123456789") else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(AppRouter())
    }
}

//
//  VideoEditorView.swift
//  Ar
//
//  Created by a on 2026/6/16.
//

import SwiftUI
import AVKit

// MARK: - 视频编辑工具类型

enum VideoEditorTool: String, CaseIterable {
    case trim     = "截取"
    case color    = "调色"
    case speed    = "调速"
    case filter   = "特效"
    case text     = "文字"
    case music    = "音乐"

    var icon: String {
        switch self {
        case .trim:   return "scissors"
        case .color:  return "pencil.tip"
        case .speed:  return "speedometer"
        case .filter: return "camera.filters"
        case .text:   return "textformat"
        case .music:  return "music.note"
        }
    }
}

// MARK: - 视频编辑页

struct VideoEditorView: View {
    @EnvironmentObject var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    /// 视频文件 URL
    let videoURL: URL

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTimeValue: Double = 0  // Slider 绑定用
    @State private var durationValue: Double = 0     // 总时长
    @State private var activeTool: VideoEditorTool?
    @State private var showUnsavedAlert = false
    @State private var isExporting = false
    @State private var showExportSuccess = false

    // 编辑状态
    @State private var trimStart: Double = 0
    @State private var trimEnd: Double = 1
    // 注意：trimEnd 在 onAppear 中被设置为 durationValue
    @State private var playbackSpeed: Float = 1.0
    @State private var brightness: Float = 0
    @State private var contrast: Float = 0
    @State private var saturation: Float = 0
    @State private var volume: Float = 1.0
    @State private var bgmIndex: Int = -1  // -1 = 无背景音乐

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部栏
                topBar

                // 视频播放器
                videoPlayerArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 时间轴
                timelineBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                // 工具面板
                if let tool = activeTool {
                    videoToolPanel(for: tool)
                        .transition(.move(edge: .bottom))
                }

                // 底部工具栏
                videoBottomToolbar
                    .padding(.bottom, safeAreaBottom)
                    .background(Color.black.opacity(0.8))
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .background(TabBarHider())
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .alert("放弃修改？", isPresented: $showUnsavedAlert) {
            Button("继续编辑", role: .cancel) { }
            Button("放弃", role: .destructive) {
                router.pop(from: .photoPreview)
            }
        } message: {
            Text("当前有未保存的修改，确定要放弃吗？")
        }
        .alert("导出成功", isPresented: $showExportSuccess) {
            Button("好") {
                router.pop(from: .photoPreview)
            }
        } message: {
            Text("视频已保存到系统相册")
        }
    }

    // MARK: - 顶部栏

    private var topBar: some View {
        HStack {
            Button(action: {
                showUnsavedAlert = true
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }

            Spacer()

            if activeTool != nil {
                Text(activeTool?.rawValue ?? "")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Spacer()

            Button(action: { exportVideo() }) {
                if isExporting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("导出视频")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                        .cornerRadius(20)
                }
            }
            .disabled(isExporting)
        }
        .padding(.horizontal, 16)
        .padding(.top, safeAreaTop)
        .background(Color.black)
    }

    // MARK: - 视频播放器

    private var videoPlayerArea: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .disabled(true)  // 使用自定义控制
                    .aspectRatio(contentMode: .fit)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("无法加载视频")
                        .foregroundColor(.gray)
                }
            }

            // 播放/暂停覆盖按钮
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: togglePlayback) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                }
                Spacer()
            }
        }
    }

    // MARK: - 时间轴

    private var timelineBar: some View {
        VStack(spacing: 4) {
            Slider(value: $currentTimeValue, in: 0...max(durationValue, 1)) { editing in
                if !editing {
                    let time = CMTime(seconds: currentTimeValue, preferredTimescale: 600)
                    player?.seek(to: time)
                }
            }
            .tint(.orange)
            .accentColor(.orange)

            HStack {
                Text(formatDuration(currentTimeValue))
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text(formatDuration(durationValue))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }

    // MARK: - 底部工具栏

    private var videoBottomToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(VideoEditorTool.allCases, id: \.rawValue) { tool in
                    Button(action: {
                        withAnimation {
                            if activeTool == tool {
                                activeTool = nil
                            } else {
                                activeTool = tool
                            }
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: tool.icon)
                                .font(.system(size: 20))
                            Text(tool.rawValue)
                                .font(.caption2)
                        }
                        .foregroundColor(activeTool == tool ? .orange : .white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
    }

    // MARK: - 视频工具面板

    @ViewBuilder
    private func videoToolPanel(for tool: VideoEditorTool) -> some View {
        switch tool {
        case .trim:   trimPanel
        case .color:  videoColorPanel
        case .speed:  speedPanel
        case .filter: videoFilterPanel
        case .text:   videoTextPanel
        case .music:  musicPanel
        }
    }

    private var trimPanel: some View {
        VStack(spacing: 8) {
            Text("拖动滑块选择起止时间")
                .font(.caption)
                .foregroundColor(.gray)

            // 起止双滑块
            VStack(spacing: 4) {
                HStack {
                    Text("开始: \(formatDuration(trimStart))")
                        .font(.caption)
                        .foregroundColor(.white)
                    Spacer()
                }
                Slider(value: $trimStart, in: 0...trimEnd)
                    .tint(.orange)
            }

            VStack(spacing: 4) {
                HStack {
                    Text("结束: \(formatDuration(trimEnd))")
                        .font(.caption)
                        .foregroundColor(.white)
                    Spacer()
                }
                Slider(value: $trimEnd, in: trimStart...durationValue)
                    .tint(.orange)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.9))
    }

    private var videoColorPanel: some View {
        ScrollView {
            VStack(spacing: 12) {
                colorSlider(value: $brightness, label: "亮度", range: -100...100)
                colorSlider(value: $contrast, label: "对比度", range: -100...100)
                colorSlider(value: $saturation, label: "饱和度", range: -100...100)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(height: 200)
        .background(Color.black.opacity(0.9))
    }

    private func colorSlider(value: Binding<Float>, label: String, range: ClosedRange<Float>) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(value.wrappedValue))")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            Slider(value: value, in: range)
                .tint(.orange)
        }
    }

    private var speedPanel: some View {
        HStack(spacing: 16) {
            speedButton(0.5, label: "0.5x")
            speedButton(1.0, label: "1x")
            speedButton(2.0, label: "2x")
            speedButton(4.0, label: "4x")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.9))
    }

    private func speedButton(_ speed: Float, label: String) -> some View {
        Button(action: {
            playbackSpeed = speed
            player?.rate = isPlaying ? speed : 0
        }) {
            Text(label)
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(playbackSpeed == speed ? .black : .white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    playbackSpeed == speed
                        ? Color.white
                        : Color.white.opacity(0.2)
                )
                .cornerRadius(16)
        }
    }

    private var videoFilterPanel: some View {
        VStack(spacing: 12) {
            Text("特效将在导出时应用到视频")
                .font(.caption)
                .foregroundColor(.gray)
            Picker("滤镜", selection: .constant(0)) {
                Text("原画原色").tag(0)
                Text("复古暖调").tag(1)
                Text("黑白电影").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.9))
    }

    private var videoTextPanel: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("输入文字…", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 16))

                Button(action: {}) {
                    Text("添加")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                        .cornerRadius(16)
                }
            }
            .padding(.horizontal, 20)

            Text("文字支持自定义起止时间（M0-4 完整实现）")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.9))
    }

    private var musicPanel: some View {
        VStack(spacing: 12) {
            // 音量调节
            VStack(spacing: 4) {
                HStack {
                    Text("原声音量")
                        .font(.caption)
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(volume * 100))%")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                Slider(value: $volume, in: 0...1)
                    .tint(.orange)
            }
            .padding(.horizontal, 20)

            Divider().background(Color.gray.opacity(0.3))

            // 背景音乐列表
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    musicItem(name: "无", index: -1)
                    musicItem(name: "晨曦", index: 0)
                    musicItem(name: "微风", index: 1)
                    musicItem(name: "城市", index: 2)
                    musicItem(name: "旅程", index: 3)
                    musicItem(name: "夜曲", index: 4)
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.9))
    }

    private func musicItem(name: String, index: Int) -> some View {
        Button(action: { bgmIndex = index }) {
            VStack(spacing: 4) {
                Image(systemName: bgmIndex == index ? "music.note.list" : "music.note")
                    .font(.system(size: 24))
                Text(name)
                    .font(.caption2)
            }
            .foregroundColor(bgmIndex == index ? .orange : .white)
            .frame(width: 64, height: 64)
            .background(bgmIndex == index ? Color.orange.opacity(0.2) : Color.white.opacity(0.1))
            .cornerRadius(12)
        }
    }

    // MARK: - 播放控制

    private func setupPlayer() {
        let asset = AVAsset(url: videoURL)
        let durationCM = asset.duration
        durationValue = CMTimeGetSeconds(durationCM)
        trimEnd = durationValue

        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)

        // 时间观察
        player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { time in
            currentTimeValue = CMTimeGetSeconds(time)
        }
    }

    private func togglePlayback() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
            player?.rate = playbackSpeed
        }
        isPlaying.toggle()
    }

    // MARK: - 导出

    private func exportVideo() {
        guard !isExporting else { return }
        isExporting = true

        // TODO: M0-4 使用 AVAssetExportSession 导出编辑后的视频
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isExporting = false
            showExportSuccess = true
        }
    }

    // MARK: - 时间格式化

    private func formatDuration(_ seconds: Double) -> String {
        guard !seconds.isNaN, !seconds.isInfinite else { return "00:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    // MARK: - Safe Area

    private var safeAreaTop: CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        return window?.safeAreaInsets.top ?? 0
    }

    private var safeAreaBottom: CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        return window?.safeAreaInsets.bottom ?? 0
    }
}

#Preview {
    VideoEditorView(videoURL: URL(fileURLWithPath: ""))
        .environmentObject(AppRouter())
}

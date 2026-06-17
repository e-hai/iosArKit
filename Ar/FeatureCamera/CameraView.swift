//
//  CameraView.swift
//  Ar
//
//  Created by a on 2026/6/1.
//

import SwiftUI

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @EnvironmentObject var router: AppRouter
    @State private var showEffectPicker = false

    @AppStorage("showGrid") private var showGrid = false
    @AppStorage("gridType") private var gridType = 0
    @AppStorage("timerDuration") private var timerDuration = 0

    var body: some View {
        ZStack {
            // 层级 0：相机预览
            CameraPreview(viewModel: viewModel)
                .ignoresSafeArea()

            // 层级 1：构图辅助线
            if showGrid {
                GridOverlayView(gridType: gridType)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // 层级 2：对焦框
            if let focusPoint = viewModel.focusPoint {
                FocusRectangleView(point: focusPoint, isLocked: viewModel.isExposureLocked)
                    .allowsHitTesting(false)
            }

            // 层级 3：倒计时浮层
            if viewModel.isTimerCountingDown {
                CountdownOverlayView(seconds: viewModel.countdownSecondsRemaining)
                    .onTapGesture { cancelCountdown() }
            }

            // 层级 4：控制器 HUD
            VStack(spacing: 0) {
                // 顶部状态栏
                topBarView
                    .padding(.top, UIApplication.safeAreaTop)

                Spacer()

                // 右侧变焦条 + 底部控制区
                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        // 右侧变焦条
                        zoomControlView
                            .padding(.trailing, 8)
                    }
                }

                Spacer()

                // 底部区域
                VStack(spacing: 0) {
                    // 底部次级：前后摄切换
                    HStack {
                        Spacer()
                        Button(action: { viewModel.switchCamera() }) {
                            Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 8)
                    }

                    // 底部控制栏
                    bottomBarView
                }
            }

            // 特效选择浮层
            if showEffectPicker {
                effectPickerOverlay
            }

            // 隐藏 NavigationLink：拍照后直接跳转编辑页
            NavigationLink(
                destination: Group {
                    if let image = viewModel.capturedPhotoImage {
                        PhotoEditorView(inputImage: image)
                    } else {
                        EmptyView()
                    }
                },
                isActive: $router.isPhotoPreviewActive
            ) { EmptyView() }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .background(TabBarHider())
        .onAppear {
            if let scene = router.selectedScene {
                viewModel.scene = scene
            } else {
                viewModel.filterIndex = router.currentFilterIndex
            }
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
            viewModel.cancelAllPendingOperations()
            capturedPhotoCleanup()
        }
        // 拍照完成 → 跳转编辑页
        .onChange(of: viewModel.capturedPhotoImage) { image in
            print("📷 onChange capturedPhotoImage: \(image != nil ? "有图片" : "nil")")
            print("📷   isPhotoPreviewActive 当前值: \(router.isPhotoPreviewActive)")
            if image != nil {
                print("📷   通过 router 跳转到编辑页")
                router.navigate(to: .photoPreview)
            }
        }
        // 旧式兼容：didCapturePhoto 标记清除
        .onChange(of: viewModel.didCapturePhoto) { captured in
            if captured {
                viewModel.didCapturePhoto = false
            }
        }
        .onChange(of: viewModel.didFinishRecording) { finished in
            if finished {
                viewModel.didFinishRecording = false
                router.pop(from: .camera)
            }
        }
    }

    // MARK: - 顶部状态栏

    private var topBarView: some View {
        HStack(spacing: 12) {
            // 返回按钮
            Button(action: {
                viewModel.stop()
                viewModel.capturedPhotoImage = nil
                router.pop(from: .camera)
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }

            // 闪光灯切换
            flashToggleButton

            // 模式切换：HDR / 夜景
            HStack(spacing: 6) {
                hdrToggleButton
                nightModeToggleButton
            }

            Spacer()

            // 设置入口
            Button(action: { router.navigate(to: .settings) }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }

            // 设备信息（电量占位）
            deviceInfoView
        }
        .padding(.horizontal, 12)
    }

    // MARK: - 闪光灯切换

    private var flashToggleButton: some View {
        Button(action: {
            switch viewModel.flashMode {
            case .off:  viewModel.setFlash(.on)
            case .on:   viewModel.setFlash(.auto)
            case .auto: viewModel.setFlash(.off)
            }
        }) {
            Image(systemName: flashIcon)
                .font(.system(size: 14))
                .foregroundColor(flashColor)
                .padding(10)
                .background(Color.black.opacity(0.4))
                .clipShape(Circle())
        }
    }

    private var flashIcon: String {
        switch viewModel.flashMode {
        case .off:  return "bolt.slash.fill"
        case .on:   return "bolt.fill"
        case .auto: return "bolt.badge.a.fill"
        }
    }

    private var flashColor: Color {
        switch viewModel.flashMode {
        case .off:  return .white
        case .on:   return .yellow
        case .auto: return .yellow
        }
    }

    // MARK: - HDR 切换

    private var hdrToggleButton: some View {
        Button(action: {
            switch viewModel.hdrMode {
            case .auto: viewModel.setHDRMode(.on)
            case .on:   viewModel.setHDRMode(.off)
            case .off:  viewModel.setHDRMode(.auto)
            }
        }) {
            Text("HDR")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(hdrTextColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.4))
                .cornerRadius(8)
        }
    }

    private var hdrTextColor: Color {
        switch viewModel.hdrMode {
        case .auto: return .white
        case .on:   return .yellow
        case .off:  return .gray
        }
    }

    // MARK: - 夜景模式切换

    private var nightModeToggleButton: some View {
        Button(action: {
            viewModel.setNightMode(viewModel.nightMode == .off ? .on : .off)
        }) {
            Text("夜景")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(viewModel.nightMode == .on ? .yellow : .white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.4))
                .cornerRadius(8)
        }
    }

    // MARK: - 设备信息

    private var deviceInfoView: some View {
        HStack(spacing: 2) {
            Image(systemName: "battery.25")
                .font(.caption)
            Text("85%")
                .font(.caption2)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.4))
        .cornerRadius(12)
    }

    // MARK: - 右侧变焦控制

    private var zoomControlView: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.availableZoomPresets, id: \.rawValue) { preset in
                Button(action: { viewModel.setZoomPreset(preset) }) {
                    Text(preset.label)
                        .font(.caption)
                        .fontWeight(viewModel.currentZoomFactor == preset.rawValue ? .bold : .regular)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(viewModel.currentZoomFactor == preset.rawValue
                                      ? Color.white.opacity(0.3)
                                      : Color.black.opacity(0.4))
                        )
                }
            }
        }
        .padding(6)
        .background(Color.black.opacity(0.3))
        .cornerRadius(20)
    }

    // MARK: - 底部控制栏

    private var bottomBarView: some View {
        HStack(alignment: .center, spacing: 0) {
            // 模式切换（拍照/录像/全景）
            captureModeSelector
                .padding(.leading, 12)

            Spacer()

            // 快门键
            shutterButton

            Spacer()

            // 特效入口
            Button(action: { showEffectPicker = true }) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .padding(.trailing, 20)
        }
        .padding(.bottom, 30)
        .padding(.horizontal, 4)
    }

    // MARK: - 模式切换

    private var captureModeSelector: some View {
        HStack(spacing: 0) {
            modeButton(title: "拍照", mode: .photo)
            modeButton(title: "录像", mode: .video)
            modeButton(title: "全景", mode: .panorama)
        }
        .background(Color.black.opacity(0.3))
        .cornerRadius(16)
    }

    private func modeButton(title: String, mode: CaptureMode) -> some View {
        Button(action: { viewModel.captureMode = mode }) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(viewModel.captureMode == mode ? .black : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    viewModel.captureMode == mode
                        ? Color.white
                        : Color.clear
                )
                .cornerRadius(12)
        }
    }

    // MARK: - 快门键

    private var shutterButton: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 70, height: 70)
            .overlay(
                Circle()
                    .stroke(Color.black.opacity(0.6), lineWidth: 3)
            )
            .overlay(
                Group {
                    if viewModel.captureMode == .video {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red)
                            .frame(width: 24, height: 24)
                    }
                }
            )
            // 长按连拍
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !viewModel.isBurstCapturing && viewModel.captureMode == .photo {
                            viewModel.startBurstCapture()
                        }
                    }
                    .onEnded { _ in
                        if viewModel.isBurstCapturing {
                            viewModel.stopBurstCapture()
                        }
                    }
            )
            // 点按拍照/录像
            .highPriorityGesture(
                TapGesture()
                    .onEnded {
                        switch viewModel.captureMode {
                        case .video:
                            if viewModel.isRecording {
                                viewModel.stopRecording()
                            } else {
                                viewModel.startRecording()
                            }
                        case .panorama:
                            // 全景占位：暂不实现
                            break
                        default:
                            if timerDuration > 0 {
                                let seconds = [0, 3, 5, 10][timerDuration]
                                viewModel.startCountdown(seconds: seconds)
                            } else {
                                viewModel.capturePhoto()
                            }
                        }
                    }
            )
    }

    // MARK: - 倒计时控制

    private func startCountdown(seconds: Int) {
        viewModel.startCountdown(seconds: seconds)
    }

    /// 拍照完成后清理图片引用（避免下次进入时重复跳转）
    private func capturedPhotoCleanup() {
        viewModel.capturedPhotoImage = nil
    }

    private func cancelCountdown() {
        viewModel.cancelCountdown()
    }

    // MARK: - 特效选择浮层

    private var effectPickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { showEffectPicker = false }

            VStack(spacing: 16) {
                HStack {
                    Text("选择特效")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Button("关闭") { showEffectPicker = false }
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)

                let effects = effectList

                if effects.isEmpty {
                    Text("暂无推荐特效")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(effects, id: \.self) { name in
                                VStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 80, height: 80)
                                        .overlay(
                                            Image(systemName: "camera.filters")
                                                .foregroundColor(.white)
                                        )
                                    Text(name)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Picker("滤镜", selection: $viewModel.filterIndex) {
                    Text("原画原色").tag(0)
                    Text("复古暖调").tag(1)
                    Text("黑白电影").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding(.vertical)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
            )
            .padding(.horizontal, 20)
        }
    }

    private var effectList: [String] {
        guard let scene = router.selectedScene else { return [] }
        return scene.recommendedEffects.components(separatedBy: " · ")
    }
}

// MARK: - 构图辅助线

struct GridOverlayView: View {
    let gridType: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                switch gridType {
                case 0: RuleOfThirdsGrid(size: geometry.size)
                case 1: GoldenRatioGrid(size: geometry.size)
                case 2: LevelGrid(size: geometry.size)
                default: RuleOfThirdsGrid(size: geometry.size)
                }
            }
        }
    }
}

struct RuleOfThirdsGrid: View {
    let size: CGSize

    var body: some View {
        Canvas { context, _ in
            let w = size.width / 3
            let h = size.height / 3

            for i in 1...2 {
                var vPath = Path()
                vPath.move(to: CGPoint(x: w * CGFloat(i), y: 0))
                vPath.addLine(to: CGPoint(x: w * CGFloat(i), y: size.height))
                context.stroke(vPath, with: .color(.white.opacity(0.4)), lineWidth: 0.5)
            }
            for i in 1...2 {
                var hPath = Path()
                hPath.move(to: CGPoint(x: 0, y: h * CGFloat(i)))
                hPath.addLine(to: CGPoint(x: size.width, y: h * CGFloat(i)))
                context.stroke(hPath, with: .color(.white.opacity(0.4)), lineWidth: 0.5)
            }
        }
    }
}

struct GoldenRatioGrid: View {
    let size: CGSize

    var body: some View {
        Canvas { context, _ in
            let phi: CGFloat = 1.618
            let w1 = size.width / (1 + phi)
            let w2 = w1 * phi
            let h1 = size.height / (1 + phi)
            let h2 = h1 * phi

            var v1 = Path()
            v1.move(to: CGPoint(x: w1, y: 0))
            v1.addLine(to: CGPoint(x: w1, y: size.height))
            context.stroke(v1, with: .color(.white.opacity(0.4)), lineWidth: 0.5)

            var v2 = Path()
            v2.move(to: CGPoint(x: w2, y: 0))
            v2.addLine(to: CGPoint(x: w2, y: size.height))
            context.stroke(v2, with: .color(.white.opacity(0.4)), lineWidth: 0.5)

            var hLine1 = Path()
            hLine1.move(to: CGPoint(x: 0, y: h1))
            hLine1.addLine(to: CGPoint(x: size.width, y: h1))
            context.stroke(hLine1, with: .color(.white.opacity(0.4)), lineWidth: 0.5)

            var hLine2 = Path()
            hLine2.move(to: CGPoint(x: 0, y: h2))
            hLine2.addLine(to: CGPoint(x: size.width, y: h2))
            context.stroke(hLine2, with: .color(.white.opacity(0.4)), lineWidth: 0.5)
        }
    }
}

struct LevelGrid: View {
    let size: CGSize

    var body: some View {
        Canvas { context, _ in
            var hLine = Path()
            hLine.move(to: CGPoint(x: 0, y: size.height / 2))
            hLine.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            context.stroke(hLine, with: .color(.white.opacity(0.4)), lineWidth: 0.5)

            var vLine = Path()
            vLine.move(to: CGPoint(x: size.width / 2, y: 0))
            vLine.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            context.stroke(vLine, with: .color(.white.opacity(0.4)), lineWidth: 0.5)

            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.15
            var circle = Path()
            circle.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                         width: radius * 2, height: radius * 2))
            context.stroke(circle, with: .color(.white.opacity(0.4)), lineWidth: 0.5)
        }
    }
}

// MARK: - 对焦框

struct FocusRectangleView: View {
    let point: CGPoint
    let isLocked: Bool

    @State private var animating = false

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 2)
                .stroke(isLocked ? Color.yellow : Color.green, lineWidth: 1.5)
                .frame(width: 60, height: 60)
                .position(
                    x: point.x * geo.size.width,
                    y: point.y * geo.size.height
                )
                .scaleEffect(animating ? 1.0 : 1.3)
                .opacity(animating ? 1.0 : 0.0)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.2)) {
                        animating = true
                    }
                }
        }
    }
}

// MARK: - 倒计时浮层

struct CountdownOverlayView: View {
    let seconds: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            Text("\(seconds)")
                .font(.system(size: 120, weight: .heavy))
                .foregroundColor(.white)
                .shadow(radius: 10)
                .transition(.scale.combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: seconds)
        }
    }
}

#Preview {
    CameraView()
        .environmentObject(AppRouter())
}

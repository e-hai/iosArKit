//
//  PhotoEditorView.swift
//  Ar
//
//  Created by a on 2026/6/16.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import Photos

// MARK: - 编辑工具类型

enum EditorTool: String, CaseIterable {
    case crop     = "裁剪"
    case color    = "调色"
    case filter   = "特效"
    case text     = "文字"
    case sticker  = "贴纸"

    var icon: String {
        switch self {
        case .crop:    return "crop"
        case .color:   return "pencil.tip"
        case .filter:  return "camera.filters"
        case .text:    return "textformat"
        case .sticker: return "shippingbox"
        }
    }
}

// MARK: - 裁剪比例

enum CropAspectRatio: String, CaseIterable {
    case free       = "自由"
    case square     = "1:1"
    case fourThree  = "4:3"
    case nineSixteen = "9:16"
    case sixteenNine = "16:9"

    var ratio: CGFloat? {
        switch self {
        case .free: return nil
        case .square: return 1
        case .fourThree: return 4/3
        case .nineSixteen: return 9/16
        case .sixteenNine: return 16/9
        }
    }
}

// MARK: - 图片编辑状态

struct PhotoEditState {
    // 调色参数：-100 ~ +100（锐度 0~100）
    var brightness: Float = 0
    var contrast: Float = 0
    var saturation: Float = 0
    var warmth: Float = 0
    var highlights: Float = 0
    var shadows: Float = 0
    var sharpness: Float = 0

    // 裁剪/旋转
    var cropAspectRatio: CropAspectRatio = .free
    var rotationAngle: Int = 0       // 0/90/180/270
    var isFlippedHorizontal = false
    var isFlippedVertical = false

    // 特效
    var filterIndex: Int = 0        // 0=原画原色, 1=复古暖调, 2=黑白电影

    // 文字（简单存储）
    var textOverlays: [TextOverlay] = []

    // 是否有未保存的修改
    var hasUnsavedChanges: Bool {
        brightness != 0 || contrast != 0 || saturation != 0 ||
        warmth != 0 || highlights != 0 || shadows != 0 ||
        sharpness != 0 || rotationAngle != 0 ||
        isFlippedHorizontal || isFlippedVertical ||
        filterIndex != 0 || !textOverlays.isEmpty
    }
}

struct TextOverlay: Identifiable {
    let id = UUID()
    var text: String
    var fontSize: CGFloat = 24
    var color: Color = .white
    var position: CGPoint = .init(x: 0.5, y: 0.5)
}

// MARK: - 图片编辑页

struct PhotoEditorView: View {
    @EnvironmentObject var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    /// 原始图片
    let inputImage: UIImage

    @State private var editState = PhotoEditState()
    @State private var activeTool: EditorTool?
    @State private var showUnsavedAlert = false
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var pendingDismiss = false

    // 预览缩放
    @State private var previewScale: CGFloat = 1.0
    @State private var previewOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部栏
                topBar

                // 图片预览区
                imagePreviewArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 工具面板（当前选中工具的控制界面）
                if let tool = activeTool {
                    toolPanel(for: tool)
                        .transition(.move(edge: .bottom))
                }

                // 底部工具栏
                bottomToolbar
                    .padding(.bottom, safeAreaBottom)
                    .background(Color.black.opacity(0.8))
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .background(TabBarHider())
        .alert("放弃修改？", isPresented: $showUnsavedAlert) {
            Button("继续编辑", role: .cancel) { }
            Button("放弃", role: .destructive) {
                router.capturedPhotoImage = nil
                router.pop(from: .photoPreview)
            }
        } message: {
            Text("当前有未保存的修改，确定要放弃吗？")
        }
        .alert("保存成功", isPresented: $showSaveSuccess) {
            Button("返回继续拍摄") {
                router.capturedPhotoImage = nil
                router.pop(from: .photoPreview)
            }
            Button("好的", role: .cancel) {
                router.capturedPhotoImage = nil
                router.pop(from: .photoPreview)
            }
        } message: {
            Text("照片已保存到系统相册")
        }
    }

    // MARK: - 顶部栏

    private var topBar: some View {
        HStack {
            // 返回（检查未保存修改）
            Button(action: {
                if editState.hasUnsavedChanges {
                    showUnsavedAlert = true
                } else {
                    router.pop(from: .photoPreview)
                }
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

            // 保存到相册
            Button(action: { saveEditedPhoto() }) {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("保存到相册")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                        .cornerRadius(20)
                }
            }
            .disabled(isSaving)
        }
        .padding(.horizontal, 16)
        .padding(.top, safeAreaTop)
        .background(Color.black)
    }

    // MARK: - 图片预览区

    private var imagePreviewArea: some View {
        GeometryReader { geo in
            Image(uiImage: inputImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(previewScale)
                .offset(previewOffset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            previewScale = max(1.0, min(5.0, value))
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if previewScale > 1.0 {
                                previewOffset = value.translation
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation {
                        if previewScale > 1.0 {
                            previewScale = 1.0
                            previewOffset = .zero
                        } else {
                            previewScale = 2.0
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - 底部工具栏

    private var bottomToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(EditorTool.allCases, id: \.rawValue) { tool in
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

    // MARK: - 工具面板

    @ViewBuilder
    private func toolPanel(for tool: EditorTool) -> some View {
        switch tool {
        case .crop:    cropPanel
        case .color:   colorPanel
        case .filter:  filterPanel
        case .text:    textPanel
        case .sticker: stickerPanel
        }
    }

    // MARK: 裁剪面板

    private var cropPanel: some View {
        VStack(spacing: 12) {
            // 比例选择
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CropAspectRatio.allCases, id: \.rawValue) { ratio in
                        Button(action: {
                            editState.cropAspectRatio = ratio
                        }) {
                            Text(ratio.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(editState.cropAspectRatio == ratio ? .black : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    editState.cropAspectRatio == ratio
                                        ? Color.white
                                        : Color.white.opacity(0.2)
                                )
                                .cornerRadius(14)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            // 旋转/翻转
            HStack(spacing: 24) {
                rotateButton(angle: 90, icon: "rotate.left", label: "左旋90°")
                rotateButton(angle: -90, icon: "rotate.right", label: "右旋90°")
                flipButton(axis: .horizontal, icon: "arrow.left.and.right.righttriangle", label: "水平翻转")
                flipButton(axis: .vertical, icon: "arrow.up.and.down", label: "垂直翻转")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.9))
    }

    private func rotateButton(angle: Int, icon: String, label: String) -> some View {
        Button(action: {
            editState.rotationAngle = (editState.rotationAngle + angle + 360) % 360
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(.white)
        }
    }

    private func flipButton(axis: FlipAxis, icon: String, label: String) -> some View {
        Button(action: {
            switch axis {
            case .horizontal: editState.isFlippedHorizontal.toggle()
            case .vertical:   editState.isFlippedVertical.toggle()
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(
                axis == .horizontal && editState.isFlippedHorizontal ||
                axis == .vertical && editState.isFlippedVertical
                ? .orange : .white
            )
        }
    }

    enum FlipAxis {
        case horizontal, vertical
    }

    // MARK: 调色面板

    private var colorPanel: some View {
        ScrollView {
            VStack(spacing: 16) {
                colorSlider(value: $editState.brightness, label: "亮度", range: -100...100)
                colorSlider(value: $editState.contrast, label: "对比度", range: -100...100)
                colorSlider(value: $editState.saturation, label: "饱和度", range: -100...100)
                colorSlider(value: $editState.warmth, label: "色温", range: -100...100)
                colorSlider(value: $editState.highlights, label: "高光", range: -100...100)
                colorSlider(value: $editState.shadows, label: "阴影", range: -100...100)
                colorSlider(value: $editState.sharpness, label: "锐度", range: 0...100)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(height: 320)
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
                .accentColor(.orange)
        }
    }

    // MARK: 特效面板

    private var filterPanel: some View {
        VStack(spacing: 12) {
            Picker("滤镜", selection: $editState.filterIndex) {
                Text("原画原色").tag(0)
                Text("复古暖调").tag(1)
                Text("黑白电影").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)

            // 特效缩略图预览
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    filterThumbnail(name: "原画原色", index: 0)
                    filterThumbnail(name: "复古暖调", index: 1)
                    filterThumbnail(name: "黑白电影", index: 2)
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.9))
    }

    private func filterThumbnail(name: String, index: Int) -> some View {
        Button(action: {
            editState.filterIndex = index
        }) {
            VStack(spacing: 4) {
                Image(uiImage: inputImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(editState.filterIndex == index ? Color.orange : Color.clear, lineWidth: 2)
                    )
                Text(name)
                    .font(.caption2)
                    .foregroundColor(editState.filterIndex == index ? .orange : .white)
            }
        }
    }

    // MARK: 文字面板

    private var textPanel: some View {
        VStack(spacing: 12) {
            // 文字输入
            HStack {
                TextField("输入文字…", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 16))

                Button(action: {
                    // TODO: M0-4 添加文字到图片
                }) {
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

            HStack(spacing: 16) {
                Text("字体")
                    .font(.caption)
                    .foregroundColor(.white)
                Text("颜色")
                    .font(.caption)
                    .foregroundColor(.white)
                Text("阴影")
                    .font(.caption)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.9))
    }

    // MARK: 贴纸面板

    private var stickerPanel: some View {
        VStack(spacing: 12) {
            // 贴纸分类
            HStack(spacing: 12) {
                stickerChip(name: "表情")
                stickerChip(name: "标签")
                stickerChip(name: "边框")
                stickerChip(name: "装饰")
                Spacer()
            }
            .padding(.horizontal, 20)

            // 贴纸网格（占位）
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(0..<12) { index in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 64)
                        .overlay(
                            Image(systemName: "shippingbox")
                                .foregroundColor(.white.opacity(0.5))
                        )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.9))
    }

    private func stickerChip(name: String) -> some View {
        Button(action: {}) {
            Text(name)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.2))
                .cornerRadius(12)
        }
    }

    // MARK: - 保存编辑后的图片

    private func saveEditedPhoto() {
        guard !isSaving else { return }
        isSaving = true

        DispatchQueue.global(qos: .userInitiated).async {
            // 用 Core Image 应用编辑参数
            let editedImage = applyEdits(to: inputImage)

            DispatchQueue.main.async {
                UIImageWriteToSavedPhotosAlbum(editedImage, nil, nil, nil)
                isSaving = false
                showSaveSuccess = true
            }
        }
    }

    /// 应用所有编辑参数到原图，返回处理后的 UIImage
    private func applyEdits(to image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        var outputImage = ciImage

        // 1. 应用特效滤镜
        if editState.filterIndex != 0 {
            switch editState.filterIndex {
            case 1:
                if let filter = CIFilter(name: "CISepiaTone") {
                    filter.setValue(outputImage, forKey: kCIInputImageKey)
                    filter.setValue(0.7, forKey: kCIInputIntensityKey)
                    if let out = filter.outputImage { outputImage = out }
                }
            case 2:
                if let filter = CIFilter(name: "CIPhotoEffectMono") {
                    filter.setValue(outputImage, forKey: kCIInputImageKey)
                    if let out = filter.outputImage { outputImage = out }
                }
            default: break
            }
        }

        // 2. 基础调色（使用 CIColorControls 等）
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = outputImage
        colorControls.brightness = editState.brightness / 100.0
        colorControls.contrast = 1.0 + editState.contrast / 100.0
        colorControls.saturation = 1.0 + editState.saturation / 100.0
        if let out = colorControls.outputImage { outputImage = out }

        // 色温
        if editState.warmth != 0 {
            let tempFilter = CIFilter.temperatureAndTint()
            tempFilter.inputImage = outputImage
            let warmthValue = editState.warmth * 5000 / 100
            tempFilter.neutral = CIVector(x: CGFloat(6500 - warmthValue), y: 0)
            if let out = tempFilter.outputImage { outputImage = out }
        }

        // 锐度
        if editState.sharpness > 0 {
            let sharpen = CIFilter.sharpenLuminance()
            sharpen.inputImage = outputImage
            sharpen.sharpness = editState.sharpness / 100.0
            if let out = sharpen.outputImage { outputImage = out }
        }

        // 高光/阴影（使用 CIGammaAdjust 近似模拟）
        if editState.highlights != 0 || editState.shadows != 0 {
            let highlightShadow = CIFilter.highlightShadowAdjust()
            highlightShadow.inputImage = outputImage
            highlightShadow.highlightAmount = 1.0 + editState.highlights / 100.0
            highlightShadow.shadowAmount = 1.0 + editState.shadows / 100.0
            if let out = highlightShadow.outputImage { outputImage = out }
        }

        // 3. 旋转
        if editState.rotationAngle != 0 {
            let angle = CGFloat(editState.rotationAngle) * .pi / 180.0
            outputImage = outputImage.transformed(by: CGAffineTransform(rotationAngle: angle))
        }

        // 4. 翻转
        if editState.isFlippedHorizontal {
            outputImage = outputImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
        }
        if editState.isFlippedVertical {
            outputImage = outputImage.transformed(by: CGAffineTransform(scaleX: 1, y: -1))
        }

        // 渲染回 UIImage
        let rect = outputImage.extent
        if let resultCG = context.createCGImage(outputImage, from: rect) {
            return UIImage(cgImage: resultCG)
        }
        return image
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
    PhotoEditorView(inputImage: UIImage())
        .environmentObject(AppRouter())
}

//
//  PhotoEditorView.swift
//  Ar
//
//  Created by a on 2026/6/16.
//

import SwiftUI

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

// MARK: - 图片编辑页

struct PhotoEditorView: View {
    @EnvironmentObject var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PhotoEditorViewModel

    /// 原始输入图片
    let inputImage: UIImage

    @State private var activeTool: EditorTool?
    @State private var showUnsavedAlert = false
    @State private var pendingDismiss = false

    init(inputImage: UIImage) {
        self.inputImage = inputImage
        _viewModel = StateObject(wrappedValue: PhotoEditorViewModel(inputImage: inputImage))
    }

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
                    .padding(.bottom, UIApplication.safeAreaBottom)
                    .background(Color.black.opacity(0.8))
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .background(TabBarHider())
        .alert("放弃修改？", isPresented: $showUnsavedAlert) {
            Button("继续编辑", role: .cancel) { }
            Button("放弃", role: .destructive) {
                router.pop(from: .photoPreview)
            }
        } message: {
            Text("当前有未保存的修改，确定要放弃吗？")
        }
        .alert("保存成功", isPresented: $viewModel.showSaveSuccess) {
            Button("返回继续拍摄") {
                router.pop(from: .photoPreview)
            }
            Button("好的", role: .cancel) {
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
                if viewModel.editState.hasUnsavedChanges {
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
            Button(action: { viewModel.saveEditedPhoto() }) {
                if viewModel.isSaving {
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
            .disabled(viewModel.isSaving)
        }
        .padding(.horizontal, 16)
        .padding(.top, UIApplication.safeAreaTop)
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
                            viewModel.editState.cropAspectRatio = ratio
                        }) {
                            Text(ratio.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(viewModel.editState.cropAspectRatio == ratio ? .black : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    viewModel.editState.cropAspectRatio == ratio
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
            viewModel.editState.rotationAngle = (viewModel.editState.rotationAngle + angle + 360) % 360
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
            case .horizontal: viewModel.editState.isFlippedHorizontal.toggle()
            case .vertical:   viewModel.editState.isFlippedVertical.toggle()
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(
                axis == .horizontal && viewModel.editState.isFlippedHorizontal ||
                axis == .vertical && viewModel.editState.isFlippedVertical
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
                colorSlider(value: $viewModel.editState.brightness, label: "亮度", range: -100...100)
                colorSlider(value: $viewModel.editState.contrast, label: "对比度", range: -100...100)
                colorSlider(value: $viewModel.editState.saturation, label: "饱和度", range: -100...100)
                colorSlider(value: $viewModel.editState.warmth, label: "色温", range: -100...100)
                colorSlider(value: $viewModel.editState.highlights, label: "高光", range: -100...100)
                colorSlider(value: $viewModel.editState.shadows, label: "阴影", range: -100...100)
                colorSlider(value: $viewModel.editState.sharpness, label: "锐度", range: 0...100)
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
            Picker("滤镜", selection: $viewModel.editState.filterIndex) {
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
            viewModel.editState.filterIndex = index
        }) {
            VStack(spacing: 4) {
                Image(uiImage: inputImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(viewModel.editState.filterIndex == index ? Color.orange : Color.clear, lineWidth: 2)
                    )
                Text(name)
                    .font(.caption2)
                    .foregroundColor(viewModel.editState.filterIndex == index ? .orange : .white)
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

    // MARK: - 保存

    /// 保存编辑后的图片（委托给 ViewModel）
    private func saveEditedPhoto() {
        viewModel.saveEditedPhoto()
    }
}

#Preview {
    PhotoEditorView(inputImage: UIImage())
        .environmentObject(AppRouter())
}

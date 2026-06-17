//
//  PhotoEditorViewModel.swift
//  Ar
//
//  Created by a on 2026/6/17.
//

import Combine
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import Photos

// MARK: - 裁剪比例

/// 裁剪比例枚举
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

// MARK: - 文字叠加

struct TextOverlay: Identifiable {
    let id = UUID()
    var text: String
    var fontSize: CGFloat = 24
    var color: Color = .white
    var position: CGPoint = .init(x: 0.5, y: 0.5)
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

// MARK: - 图片编辑 ViewModel

/// 图片编辑页 ViewModel：管理编辑状态、Core Image 处理管线、保存逻辑
final class PhotoEditorViewModel: ObservableObject {
    @Published var editState = PhotoEditState()
    @Published var isSaving = false
    @Published var showSaveSuccess = false

    /// 原始输入图片
    let inputImage: UIImage

    init(inputImage: UIImage) {
        self.inputImage = inputImage
    }

    // MARK: - 保存编辑后的图片

    /// 应用所有编辑参数并保存到系统相册
    func saveEditedPhoto() {
        guard !isSaving else { return }
        isSaving = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let editedImage = self.applyEdits(to: self.inputImage)

            DispatchQueue.main.async {
                UIImageWriteToSavedPhotosAlbum(editedImage, nil, nil, nil)
                self.isSaving = false
                self.showSaveSuccess = true
            }
        }
    }

    // MARK: - Core Image 处理管线

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

        // 2. 基础调色
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

        // 高光/阴影
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
}

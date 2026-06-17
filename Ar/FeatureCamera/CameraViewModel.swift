//
//  CameraViewModel.swift
//  Ar
//
//  Created by a on 2026/6/1.
//

import Combine
import AVFoundation
import SwiftUI
import CoreImage
import Photos

// MARK: - 拍摄模式

/// 取景模式
enum CaptureMode: Int {
    case photo
    case video
    case panorama  // 占位，暂不实现
}

/// 闪光灯模式
enum FlashMode: Int {
    case off
    case on
    case auto
}

/// HDR 模式
enum HDRMode: Int {
    case auto
    case on
    case off
}

/// 夜景模式
enum NightMode: Int {
    case off
    case on
}

/// 变焦预设档位
enum ZoomPreset: CGFloat, CaseIterable {
    case half = 0.5
    case oneX = 1.0
    case twoX = 2.0

    var label: String {
        switch self {
        case .half: return "0.5"
        case .oneX: return "1x"
        case .twoX: return "2x"
        }
    }
}

/// 相机拍摄 ViewModel：管理 AVCaptureSession、实时滤镜、拍照/录像、倒计时等全部相机业务逻辑
final class CameraViewModel: NSObject, ObservableObject {
    // MARK: - 发布状态
    @Published var currentRenderedFrame: CIImage?
    @Published var isSessionRunning = false
    @Published var isRecording = false
    @Published var didCapturePhoto = false
    @Published var didFinishRecording = false

    // MARK: - 拍摄配置状态
    @Published var captureMode: CaptureMode = .photo
    @Published var flashMode: FlashMode = .off
    @Published var hdrMode: HDRMode = .auto
    @Published var nightMode: NightMode = .off
    @Published var currentZoomFactor: CGFloat = 1.0

    // MARK: - 对焦状态
    @Published var focusPoint: CGPoint?
    @Published var isExposureLocked = false

    // MARK: - 连拍状态
    @Published var isBurstCapturing = false
    @Published var burstPhotoCount = 0

    // MARK: - 倒计时状态
    @Published var isTimerCountingDown = false
    @Published var countdownSecondsRemaining = 0

    // MARK: - 专辑缩略图
    @Published var albumThumbnail: UIImage?

    /// 最近一次拍摄的照片（用于跳转预览/编辑页）
    @Published var capturedPhotoImage: UIImage?

    // MARK: - 配置
    var cameraPosition: AVCaptureDevice.Position = .back
    var filterIndex: Int = 0
    /// 当前拍摄场景（决定默认滤镜）
    var scene: SceneType? {
        didSet {
            if let scene = scene {
                filterIndex = scene.defaultFilterIndex
            }
        }
    }

    /// 当前可用变焦档位（根据硬件能力过滤）
    var availableZoomPresets: [ZoomPreset] {
        guard let device = currentDevice else { return [.oneX, .twoX] }
        if device.minAvailableVideoZoomFactor < 1.0 {
            return ZoomPreset.allCases
        }
        return [.oneX, .twoX]
    }

    // MARK: - 私有属性
    private let session = AVCaptureSession()
    private var currentInput: AVCaptureDeviceInput?
    private let dataOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.pipeline.queue")
    private let ciContext = CIContext()
    private var burstTimer: DispatchSourceTimer?
    /// 倒计时 Timer（Combine）
    private var timerCancellable: AnyCancellable?

    // MARK: - 录像属性
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var videoRecordingURL: URL?
    private var recordingStartTime: CMTime?

    /// 当前活跃设备
    private var currentDevice: AVCaptureDevice? {
        currentInput?.device
    }

    override init() {
        super.init()
        setupPipeline()
        fetchLatestAlbumThumbnail()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    // MARK: - 管线设置

    private func setupPipeline() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()

            if self.session.canSetSessionPreset(.hd1920x1080) {
                self.session.sessionPreset = .hd1920x1080
            }

            if let device = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: cameraPosition
            ),
               let input = try? AVCaptureDeviceInput(device: device) {
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.currentInput = input
                }
            }

            self.dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            self.dataOutput.alwaysDiscardsLateVideoFrames = true
            if self.session.canAddOutput(self.dataOutput) {
                self.session.addOutput(self.dataOutput)
                self.dataOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
            }

            if self.session.canAddOutput(self.photoOutput) {
                self.photoOutput.isHighResolutionCaptureEnabled = true
                self.session.addOutput(self.photoOutput)
            }

            if let connection = self.dataOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = (self.cameraPosition == .front)
                }
            }

            self.session.commitConfiguration()
        }
    }

    // MARK: - 会话控制

    func start() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async { self.isSessionRunning = true }
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async { self.isSessionRunning = false }
            }
        }
    }

    func switchCamera() {
        guard !isRecording else { return }
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let newPosition: AVCaptureDevice.Position = (self.cameraPosition == .back) ? .front : .back

            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
                print("❌ 无法创建新的物理摄像头设备输入")
                return
            }

            let oldInput = self.currentInput
            self.session.beginConfiguration()

            if let old = oldInput {
                self.session.removeInput(old)
            }

            if !self.session.canAddInput(newInput) {
                if self.session.canSetSessionPreset(.high) {
                    self.session.sessionPreset = .high
                }
            }

            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.currentInput = newInput
            } else {
                print("❌ 无法将新摄像头加入到当前会话")
                if let old = oldInput, self.session.canAddInput(old) {
                    self.session.addInput(old)
                    self.currentInput = old
                } else {
                    print("❌ 回滚也失败，会话可能已损坏")
                }
                self.session.commitConfiguration()
                return
            }

            if self.session.canSetSessionPreset(.hd1920x1080) {
                self.session.sessionPreset = .hd1920x1080
            } else if self.session.canSetSessionPreset(.hd1280x720) {
                self.session.sessionPreset = .hd1280x720
            } else if self.session.canSetSessionPreset(.high) {
                self.session.sessionPreset = .high
            }

            if let connection = self.dataOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = (newPosition == .front)
                }
            } else {
                print("⚠️ 未能找到全新的视频输出连接线")
            }

            self.dataOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
            self.session.commitConfiguration()

            try? newDevice.lockForConfiguration()
            if newDevice.isFocusModeSupported(.continuousAutoFocus) {
                newDevice.focusMode = .continuousAutoFocus
            }
            newDevice.unlockForConfiguration()

            DispatchQueue.main.async {
                self.cameraPosition = newPosition
                self.focusPoint = nil
                self.isExposureLocked = false
                print("📸 摄像头成功切换到: \(newPosition == .back ? "后置" : "前置")")
            }
        }
    }

    // MARK: - 拍照

    func capturePhoto() {
        print("📷 capturePhoto() 被调用")
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let settings = AVCapturePhotoSettings()

            switch self.flashMode {
            case .off:  settings.flashMode = .off
            case .on:   settings.flashMode = .on
            case .auto: settings.flashMode = .auto
            }

            settings.isHighResolutionPhotoEnabled = true
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: - 连拍

    func startBurstCapture() {
        guard !isBurstCapturing else { return }

        DispatchQueue.main.async {
            self.isBurstCapturing = true
            self.burstPhotoCount = 0
        }

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            settings.isHighResolutionPhotoEnabled = true

            self.burstTimer?.cancel()
            let timer = DispatchSource.makeTimerSource(queue: self.sessionQueue)
            timer.schedule(deadline: .now(), repeating: .milliseconds(200), leeway: .milliseconds(50))
            timer.setEventHandler { [weak self] in
                guard let self = self, self.isBurstCapturing else {
                    timer.cancel()
                    return
                }
                let burstSettings = AVCapturePhotoSettings(from: settings)
                self.photoOutput.capturePhoto(with: burstSettings, delegate: self)
                DispatchQueue.main.async {
                    self.burstPhotoCount += 1
                }
            }
            self.burstTimer = timer
            timer.resume()
        }
    }

    func stopBurstCapture() {
        guard isBurstCapturing else { return }

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.burstTimer?.cancel()
            self.burstTimer = nil

            DispatchQueue.main.async {
                self.isBurstCapturing = false
            }
        }
    }

    // MARK: - 变焦控制

    func setZoom(factor: CGFloat) {
        guard let device = currentDevice else { return }
        let clampedFactor = min(max(factor, device.minAvailableVideoZoomFactor),
                                device.maxAvailableVideoZoomFactor)

        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clampedFactor
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.currentZoomFactor = clampedFactor
                }
            } catch {
                print("变焦失败: \(error)")
            }
        }
    }

    func setZoomPreset(_ preset: ZoomPreset) {
        setZoom(factor: preset.rawValue)
    }

    // MARK: - 对焦/曝光控制

    func focusAndExpose(at viewPoint: CGPoint, in viewSize: CGSize) {
        guard let device = currentDevice else { return }

        let focusPoint = CGPoint(x: viewPoint.x / viewSize.width,
                                 y: viewPoint.y / viewSize.height)

        guard device.isFocusPointOfInterestSupported,
              device.isExposurePointOfInterestSupported else { return }

        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.focusPointOfInterest = focusPoint
                device.focusMode = .autoFocus
                device.exposurePointOfInterest = focusPoint
                device.exposureMode = .autoExpose
                device.unlockForConfiguration()

                DispatchQueue.main.async {
                    self.focusPoint = focusPoint
                    self.isExposureLocked = false
                }
            } catch {
                print("对焦失败: \(error)")
            }
        }
    }

    func lockFocusAndExposure(at viewPoint: CGPoint, in viewSize: CGSize) {
        guard let device = currentDevice else { return }

        let focusPoint = CGPoint(x: viewPoint.x / viewSize.width,
                                 y: viewPoint.y / viewSize.height)

        guard device.isFocusPointOfInterestSupported,
              device.isExposurePointOfInterestSupported else { return }

        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.focusPointOfInterest = focusPoint
                device.focusMode = .locked
                device.exposurePointOfInterest = focusPoint
                device.exposureMode = .locked
                device.unlockForConfiguration()

                DispatchQueue.main.async {
                    self.focusPoint = focusPoint
                    self.isExposureLocked = true
                }
            } catch {
                print("锁焦失败: \(error)")
            }
        }
    }

    func resetFocusAndExposure() {
        guard let device = currentDevice else { return }

        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                device.unlockForConfiguration()

                DispatchQueue.main.async {
                    self.focusPoint = nil
                    self.isExposureLocked = false
                }
            } catch {
                print("恢复对焦失败: \(error)")
            }
        }
    }

    // MARK: - 闪光灯/手电筒

    func setFlash(_ mode: FlashMode) {
        DispatchQueue.main.async { self.flashMode = mode }
    }

    func setTorch(level: Float) {
        guard let device = currentDevice, device.hasTorch else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                if level > 0 {
                    try device.setTorchModeOn(level: min(level, 1.0))
                } else {
                    device.torchMode = .off
                }
                device.unlockForConfiguration()
            } catch {
                print("手电筒失败: \(error)")
            }
        }
    }

    // MARK: - HDR / 夜景

    func setHDRMode(_ mode: HDRMode) {
        DispatchQueue.main.async { self.hdrMode = mode }
    }

    func setNightMode(_ mode: NightMode) {
        DispatchQueue.main.async { self.nightMode = mode }
    }

    // MARK: - 录像

    func startRecording() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
            self.videoRecordingURL = outputURL

            guard let writer = try? AVAssetWriter(url: outputURL, fileType: .mp4) else { return }
            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 1080,
                AVVideoHeightKey: 1920
            ]
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = true

            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
            if writer.canAdd(input) {
                writer.add(input)
                self.assetWriter = writer
                self.assetWriterInput = input
                self.pixelBufferAdaptor = adaptor
                writer.startWriting()
                self.recordingStartTime = nil
                DispatchQueue.main.async { self.isRecording = true }
            }
        }
    }

    func stopRecording() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.isRecording = false
            self.assetWriterInput?.markAsFinished()
            self.assetWriter?.finishWriting {
                if let url = self.videoRecordingURL {
                    PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                    } completionHandler: { success, _ in
                        if success { try? FileManager.default.removeItem(at: url) }
                        DispatchQueue.main.async {
                            self.didFinishRecording = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - 专辑缩略图

    func fetchLatestAlbumThumbnail() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1

        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        guard let asset = result.firstObject else { return }

        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .fastFormat
        options.resizeMode = .exact

        let targetSize = CGSize(width: 88, height: 88)

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, _ in
            DispatchQueue.main.async {
                self?.albumThumbnail = image
            }
        }
    }

    // MARK: - 倒计时拍摄

    /// 启动倒计时（秒数到达后自动拍照）
    func startCountdown(seconds: Int) {
        isTimerCountingDown = true
        countdownSecondsRemaining = seconds

        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.countdownSecondsRemaining <= 1 {
                    self.isTimerCountingDown = false
                    self.capturePhoto()
                    self.timerCancellable?.cancel()
                    self.timerCancellable = nil
                } else {
                    self.countdownSecondsRemaining -= 1
                }
            }
    }

    /// 取消倒计时
    func cancelCountdown() {
        isTimerCountingDown = false
        countdownSecondsRemaining = 0
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    /// 取消所有待处理操作（View onDisappear 时调用）
    func cancelAllPendingOperations() {
        cancelCountdown()
    }
}

// MARK: - 统一图像渲染管线（视频帧 → 实时滤镜 → 预览/录像）

extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        switch filterIndex {
        case 1:
            if let filter = CIFilter(name: "CISepiaTone") {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filter.setValue(0.7, forKey: kCIInputIntensityKey)
                if let out = filter.outputImage { ciImage = out }
            }
        case 2:
            if let filter = CIFilter(name: "CIPhotoEffectMono") {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                if let out = filter.outputImage { ciImage = out }
            }
        default:
            break
        }

        DispatchQueue.main.async {
            self.currentRenderedFrame = ciImage
        }

        if isRecording, let input = assetWriterInput, input.isReadyForMoreMediaData {
            if recordingStartTime == nil {
                recordingStartTime = timestamp
                assetWriter?.startSession(atSourceTime: timestamp)
            }
            var renderBuffer: CVPixelBuffer?
            CVPixelBufferCreate(kCFAllocatorDefault, Int(ciImage.extent.width), Int(ciImage.extent.height), kCVPixelFormatType_32BGRA, nil, &renderBuffer)
            if let outBuf = renderBuffer {
                ciContext.render(ciImage, to: outBuf)
                pixelBufferAdaptor?.append(outBuf, withPresentationTime: timestamp)
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate（照片拍摄完成回调）

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {

        print("📷 photoOutput 回调触发, error=\(error?.localizedDescription ?? "nil")")

        guard error == nil else {
            print("❌ 拍照失败: \(error!.localizedDescription)")
            DispatchQueue.main.async { self.didCapturePhoto = false }
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("❌ fileDataRepresentation 失败")
            DispatchQueue.main.async { self.didCapturePhoto = false }
            return
        }

        print("📷 图片数据获取成功, size=\(image.size), orientation=\(image.imageOrientation.rawValue)")

        guard let baseCIImage = CIImage(image: image) else {
            print("❌ 无法创建 CIImage")
            DispatchQueue.main.async { self.didCapturePhoto = false }
            return
        }

        var ciImage = baseCIImage.oriented(forExifOrientation: exifOrientation(from: image.imageOrientation))

        if cameraPosition == .front {
            ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
        }

        print("📷 应用滤镜 filterIndex=\(filterIndex)")
        switch filterIndex {
        case 1:
            if let filter = CIFilter(name: "CISepiaTone") {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filter.setValue(0.7, forKey: kCIInputIntensityKey)
                if let out = filter.outputImage { ciImage = out }
            }
        case 2:
            if let filter = CIFilter(name: "CIPhotoEffectMono") {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                if let out = filter.outputImage { ciImage = out }
            }
        default:
            break
        }

        guard let outputCGImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            print("❌ createCGImage 失败")
            DispatchQueue.main.async { self.didCapturePhoto = false }
            return
        }
        let resultImage = UIImage(cgImage: outputCGImage)
        print("📷 最终图片生成成功, size=\(resultImage.size)")

        print("📷 即将设置 capturedPhotoImage")
        DispatchQueue.main.async {
            print("📷 [main] 设置 capturedPhotoImage")
            self.capturedPhotoImage = resultImage
        }

        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: resultImage)
        } completionHandler: { [weak self] success, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                print("📷 [main] 相册保存 didCapturePhoto = \(success)")
                self.didCapturePhoto = success
                if success { self.fetchLatestAlbumThumbnail() }
            }
        }
    }

    private func exifOrientation(from uiOrientation: UIImage.Orientation) -> Int32 {
        switch uiOrientation {
        case .up:            return 1
        case .down:          return 3
        case .left:          return 8
        case .right:         return 6
        case .upMirrored:    return 2
        case .downMirrored:  return 4
        case .leftMirrored:  return 5
        case .rightMirrored: return 7
        @unknown default:    return 1
        }
    }
}

// MARK: - 相册变更观察

extension CameraViewModel: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        fetchLatestAlbumThumbnail()
    }
}

//
//  CameraPreview.swift
//  Ar
//
//  Created by a on 2026/6/1.
//

import SwiftUI
import MetalKit
import CoreImage

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var viewModel: CameraViewModel

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.framebufferOnly = false
        mtkView.enableSetNeedsDisplay = true
        mtkView.autoResizeDrawable = true
        mtkView.delegate = context.coordinator

        mtkView.isOpaque = true
        mtkView.backgroundColor = .black

        // 添加手势识别
        context.coordinator.addGestures(to: mtkView)

        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        DispatchQueue.main.async {
            uiView.setNeedsDisplay()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MTKViewDelegate {
        var parent: CameraPreview
        let ciContext: CIContext
        let commandQueue: MTLCommandQueue?

        init(_ parent: CameraPreview) {
            self.parent = parent
            let device = MTLCreateSystemDefaultDevice()
            self.commandQueue = device?.makeCommandQueue()
            self.ciContext = CIContext(mtlDevice: device!, options: [.workingColorSpace : NSNull()])
            super.init()
        }

        // MARK: - 手势识别（点按对焦 + 长按锁焦）

        func addGestures(to view: MTKView) {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            longPress.minimumPressDuration = 0.5

            view.addGestureRecognizer(tap)
            view.addGestureRecognizer(longPress)
        }

        @objc private func handleTap(_ sender: UITapGestureRecognizer) {
            let location = sender.location(in: sender.view)
            guard let view = sender.view else { return }
            parent.viewModel.focusAndExpose(at: location, in: view.bounds.size)
        }

        @objc private func handleLongPress(_ sender: UILongPressGestureRecognizer) {
            guard sender.state == .began, let view = sender.view else { return }
            parent.viewModel.lockFocusAndExposure(at: sender.location(in: view), in: view.bounds.size)
        }

        // MARK: - MTKViewDelegate

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        }

        func draw(in view: MTKView) {
            guard let currentFrame = parent.viewModel.currentRenderedFrame,
                  let currentDrawable = view.currentDrawable,
                  let commandBuffer = commandQueue?.makeCommandBuffer() else { return }

            let outputTexture = currentDrawable.texture

            let textureWidth = CGFloat(outputTexture.width)
            let textureHeight = CGFloat(outputTexture.height)

            let imageSize = currentFrame.extent.size

            let scaleX = textureWidth / imageSize.width
            let scaleY = textureHeight / imageSize.height
            let scale = max(scaleX, scaleY)

            let targetWidth = imageSize.width * scale
            let targetHeight = imageSize.height * scale
            let targetRect = CGRect(
                x: (textureWidth - targetWidth) / 2,
                y: (textureHeight - targetHeight) / 2,
                width: targetWidth,
                height: targetHeight
            )

            let transformedImage = currentFrame
                .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                .transformed(by: CGAffineTransform(translationX: targetRect.origin.x, y: targetRect.origin.y))

            let drawBounds = CGRect(x: 0, y: 0, width: textureWidth, height: textureHeight)

            ciContext.render(transformedImage,
                             to: outputTexture,
                             commandBuffer: commandBuffer,
                             bounds: drawBounds,
                             colorSpace: CGColorSpaceCreateDeviceRGB())

            commandBuffer.present(currentDrawable)
            commandBuffer.commit()
        }
    }
}

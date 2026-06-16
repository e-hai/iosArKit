//
//  CameraPermission.swift
//  Ar
//
//  Created by a on 2026/6/1.
//
import AVFoundation
import UIKit

enum CameraAuthorization{
    static var status : AVAuthorizationStatus{
        AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    static func request() async -> Bool{
        await AVCaptureDevice.requestAccess(for: .video)
    }
    
    // 🚀 引导用户跳转到系统设置
    @MainActor
    static func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

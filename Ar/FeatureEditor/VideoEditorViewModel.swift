//
//  VideoEditorViewModel.swift
//  Ar
//
//  Created by a on 2026/6/17.
//

import Combine
import SwiftUI
import AVKit

// MARK: - 视频编辑 ViewModel

/// 视频编辑页 ViewModel：管理 AVPlayer 生命周期、播放控制、编辑状态
final class VideoEditorViewModel: ObservableObject {
    // MARK: - 播放状态
    @Published var isPlaying = false
    @Published var currentTimeValue: Double = 0
    @Published var durationValue: Double = 0
    @Published var activeTool: VideoEditorTool?

    // MARK: - 导出状态
    @Published var isExporting = false
    @Published var showExportSuccess = false
    @Published var showUnsavedAlert = false

    // MARK: - 编辑状态
    @Published var trimStart: Double = 0
    @Published var trimEnd: Double = 1
    @Published var playbackSpeed: Float = 1.0
    @Published var brightness: Float = 0
    @Published var contrast: Float = 0
    @Published var saturation: Float = 0
    @Published var volume: Float = 1.0
    @Published var bgmIndex: Int = -1  // -1 = 无背景音乐

    /// 视频文件 URL
    let videoURL: URL

    /// AVPlayer 实例（由 ViewModel 管理生命周期）
    var player: AVPlayer?
    private var timeObserver: Any?

    init(videoURL: URL) {
        self.videoURL = videoURL
    }

    deinit {
        cleanup()
    }

    // MARK: - 播放控制

    /// 初始化播放器
    func setupPlayer() {
        let asset = AVAsset(url: videoURL)
        let durationCM = asset.duration
        durationValue = CMTimeGetSeconds(durationCM)
        trimEnd = durationValue

        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)

        // 移除旧 observer 后重新添加
        removeTimeObserver()
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.currentTimeValue = CMTimeGetSeconds(time)
        }
    }

    /// 播放/暂停切换
    func togglePlayback() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
            player?.rate = playbackSpeed
        }
        isPlaying.toggle()
    }

    /// 跳转到指定时间点
    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime)
    }

    /// 设置播放速度（同时保持当前播放状态）
    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        if isPlaying {
            player?.rate = speed
        }
    }

    // MARK: - 导出

    /// 导出编辑后的视频（暂为占位实现）
    func exportVideo() {
        guard !isExporting else { return }
        isExporting = true

        // TODO: M0-4 使用 AVAssetExportSession 导出编辑后的视频
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.isExporting = false
            self?.showExportSuccess = true
        }
    }

    // MARK: - 生命周期

    /// 清理播放器资源（View onDisappear 或 deinit 时调用）
    func cleanup() {
        removeTimeObserver()
        player?.pause()
        player = nil
    }

    // MARK: - 辅助方法

    /// 时间格式化（秒 → mm:ss）
    func formatDuration(_ seconds: Double) -> String {
        guard !seconds.isNaN, !seconds.isInfinite else { return "00:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    /// 是否有未保存的修改
    var hasUnsavedChanges: Bool {
        trimStart != 0 || trimEnd != durationValue ||
        playbackSpeed != 1.0 || brightness != 0 ||
        contrast != 0 || saturation != 0 ||
        volume != 1.0 || bgmIndex != -1
    }

    // MARK: - 私有方法

    private func removeTimeObserver() {
        if let observer = timeObserver {
            if let player = player {
                player.removeTimeObserver(observer)
            }
            timeObserver = nil
        }
    }
}

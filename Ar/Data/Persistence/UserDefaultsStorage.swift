//
//  UserDefaultsStorage.swift
//  Ar
//
//  Created by a on 2026/6/16.
//

import Foundation
import Combine

/// UserDefaultsStorage：类型安全地读写 UserDefaults。
///
/// 用法：
/// ```swift
/// let storage = UserDefaultsStorage.shared
/// storage.set(1, forKey: "filterIndex")
/// let index: Int = storage.get(forKey: "filterIndex") ?? 0
/// ```
///
/// 对于需要响应式绑定的场景，可使用 `publisher(forKey:)` 监听变化。
final class UserDefaultsStorage {

    // MARK: - 单例

    /// 共享实例，默认使用 `UserDefaults.standard`
    static let shared = UserDefaultsStorage()

    // MARK: - 属性

    private let defaults: UserDefaults

    // MARK: - 初始化

    /// 创建 UserDefaultsStorage 实例
    /// - Parameter defaults: 可注入自定义 UserDefaults（默认 .standard，方便测试）
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - 读写方法

    /// 保存任意 PropertyList 兼容类型的值
    func set(_ value: Any?, forKey key: String) {
        defaults.set(value, forKey: key)
        notificationSubject.send(key)
    }

    /// 读取指定 key 的值，自动转型为 T
    func get<T>(forKey key: String) -> T? {
        return defaults.object(forKey: key) as? T
    }

    /// 读取指定 key 的整数
    func integer(forKey key: String) -> Int {
        return defaults.integer(forKey: key)
    }

    /// 读取指定 key 的布尔值
    func bool(forKey key: String) -> Bool {
        return defaults.bool(forKey: key)
    }

    /// 读取指定 key 的浮点数
    func float(forKey key: String) -> Float {
        return defaults.float(forKey: key)
    }

    /// 读取指定 key 的字符串
    func string(forKey key: String) -> String? {
        return defaults.string(forKey: key)
    }

    /// 删除指定 key
    func remove(forKey key: String) {
        defaults.removeObject(forKey: key)
        notificationSubject.send(key)
    }

    /// 删除所有 UserDefaults 数据（慎用）
    func clearAll() {
        guard let domain = Bundle.main.bundleIdentifier else { return }
        defaults.removePersistentDomain(forName: domain)
    }

    /// 检查 key 是否存在
    func hasKey(_ key: String) -> Bool {
        return defaults.object(forKey: key) != nil
    }

    // MARK: - Combine 支持

    private let notificationSubject = PassthroughSubject<String, Never>()

    /// 返回指定 key 变化的 Publisher
    /// 适用于 Combine 绑定场景
    func publisher(forKey key: String) -> AnyPublisher<Void, Never> {
        return notificationSubject
            .filter { $0 == key }
            .map { _ in }
            .eraseToAnyPublisher()
    }
}

// MARK: - 便捷 Key 定义

extension UserDefaultsStorage {
    /// 所有持久化 key 的定义
    struct Keys {
        /// 默认滤镜索引（0 = 原画原色）
        static let defaultFilterIndex = "defaultFilterIndex"
        /// 首次启动标记
        static let isFirstLaunch = "isFirstLaunch"
        /// 上次选中的场景类型（原始值）
        static let lastSceneType = "lastSceneType"
    }
}

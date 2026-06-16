//
//  FileStorage.swift
//  Ar
//
//  Created by a on 2026/6/16.
//

import Foundation

/// FileStorage：将 Codable 数据以 JSON 格式写入应用沙箱 Documents 目录。
///
/// 用于存储拍摄历史、用户自定义配置等结构化数据。
/// 不适用于大量数据（建议单文件不超过 10MB）。
///
/// 用法：
/// ```swift
/// let storage = FileStorage<[PhotoRecord]>(filename: "photoHistory.json")
/// var records = try? await storage.load()
/// records?.append(PhotoRecord(...))
/// try? await storage.save(records ?? [])
/// ```
struct FileStorage<T: Codable> {

    // MARK: - 属性

    /// 文件名（如 "photoHistory.json"）
    let filename: String

    /// 文件完整路径（Documents/文件名）
    private var fileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(filename)
    }

    // MARK: - 公开方法

    /// 从磁盘加载数据（async/await 版本）
    /// - Returns: 解码后的数据，文件不存在时返回 nil
    func load() async throws -> T? {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try await Task.detached(priority: .background) {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        }.value
    }

    /// 保存数据到磁盘（async/await 版本）
    /// - Parameter value: 要编码保存的数据
    func save(_ value: T) async throws {
        let url = fileURL
        try await Task.detached(priority: .background) {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: .atomic)
        }.value
    }

    /// 删除文件
    func delete() async throws {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try await Task.detached(priority: .background) {
            try FileManager.default.removeItem(at: url)
        }.value
    }

    // MARK: - 同步版本（用于不支持 async 的上下文）

    /// 同步加载（用于 Combine/回调上下文）
    func loadSync() throws -> T? {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// 同步保存（用于 Combine/回调上下文）
    func saveSync(_ value: T) throws {
        let url = fileURL
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: .atomic)
    }
}

//
//  APIEndpoint.swift
//  Ar
//
//  Created by a on 2026/6/16.
//

import Foundation

/// APIEndpoint：网络请求端点定义。
///
/// 使用时扩展本类型添加具体端点：
/// ```swift
/// extension APIEndpoint {
///     static let uploadPhoto = APIEndpoint(path: "/photos/upload", method: .post)
///     static let filters = APIEndpoint(path: "/filters", method: .get)
/// }
/// ```
struct APIEndpoint {

    // MARK: - HTTP 方法

    enum HTTPMethod: String {
        case get    = "GET"
        case post   = "POST"
        case put    = "PUT"
        case patch  = "PATCH"
        case delete = "DELETE"
    }

    // MARK: - 属性

    /// 请求路径（如 "/api/v1/filters"）
    let path: String

    /// HTTP 方法
    let method: HTTPMethod

    /// 请求头（可选）
    var headers: [String: String]

    /// 查询参数（可选）
    let queryItems: [URLQueryItem]

    /// 超时时间（秒，默认 30）
    let timeout: TimeInterval

    // MARK: - 初始化

    init(
        path: String,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        queryItems: [URLQueryItem] = [],
        timeout: TimeInterval = 30
    ) {
        self.path = path
        self.method = method
        self.headers = headers
        self.queryItems = queryItems
        self.timeout = timeout
    }
}

//
//  HTTPClient.swift
//  Ar
//
//  Created by a on 2026/6/16.
//

import Foundation

/// HTTPClient：基于 URLSession 的网络请求客户端。
///
/// 使用 async/await 发起一次性网络请求（符合项目并发分工原则）。
/// 不支持网络状态监听（网络状态变化用 Combine + NWPathMonitor 实现）。
///
/// 用法：
/// ```swift
/// let client = HTTPClient(baseURL: URL(string: "https://api.example.com")!)
/// let photos: [PhotoRecord] = try await client.request(.uploadPhoto, body: data)
/// ```
final class HTTPClient {

    // MARK: - 属性

    /// 基础 URL
    let baseURL: URL

    /// URLSession 实例（可注入，方便测试）
    private let session: URLSession

    /// 默认请求头（如 Authorization token）
    private var defaultHeaders: [String: String] = [:]

    /// JSON 解码器
    private let decoder = JSONDecoder()

    /// JSON 编码器
    private let encoder = JSONEncoder()

    // MARK: - 初始化

    /// 创建 HTTPClient
    /// - Parameters:
    ///   - baseURL: API 基础 URL
    ///   - session: URLSession 实例（默认 .shared）
    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - 请求方法

    /// 发起网络请求，返回解码后的响应
    /// - Parameter endpoint: 端点定义
    /// - Returns: 解码后的 Decodable 数据
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let (data, _) = try await performRequest(endpoint)
        return try decoder.decode(T.self, from: data)
    }

    /// 发起网络请求，不解析响应体
    /// - Parameter endpoint: 端点定义
    func request(_ endpoint: APIEndpoint) async throws {
        let (_, response) = try await performRequest(endpoint)
        try validateResponse(response)
    }

    /// 发起带请求体的网络请求（POST/PUT）
    /// - Parameters:
    ///   - endpoint: 端点定义
    ///   - body: 可编码的请求体
    /// - Returns: 解码后的 Decodable 数据
    func request<T: Decodable, B: Encodable>(_ endpoint: APIEndpoint, body: B) async throws -> T {
        var endpoint = endpoint
        let bodyData = try encoder.encode(body)
        let (data, _) = try await performRequest(endpoint, body: bodyData)
        return try decoder.decode(T.self, from: data)
    }

    /// 上传 Data 数据（如文件/图片）
    /// - Parameters:
    ///   - endpoint: 端点定义
    ///   - data: 要上传的数据
    ///   - contentType: MIME 类型
    /// - Returns: 解码后的 Decodable 数据
    func upload<T: Decodable>(_ endpoint: APIEndpoint, data: Data, contentType: String) async throws -> T {
        var endpoint = endpoint
        endpoint.headers.merge(["Content-Type": contentType]) { $1 }
        let (responseData, _) = try await performRequest(endpoint, body: data)
        return try decoder.decode(T.self, from: responseData)
    }

    // MARK: - 鉴权

    /// 设置 Bearer token
    func setAuthorizationToken(_ token: String) {
        defaultHeaders["Authorization"] = "Bearer \(token)"
    }

    /// 清除鉴权信息
    func clearAuthorization() {
        defaultHeaders.removeValue(forKey: "Authorization")
    }

    // MARK: - 内部方法

    private func performRequest(_ endpoint: APIEndpoint, body: Data? = nil) async throws -> (Data, HTTPURLResponse) {
        // 构建 URL
        guard var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false) else {
            throw HTTPError.invalidURL
        }

        // 添加查询参数
        if !endpoint.queryItems.isEmpty {
            components.queryItems = endpoint.queryItems
        }

        guard let url = components.url else {
            throw HTTPError.invalidURL
        }

        // 构建请求
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = endpoint.timeout
        request.allHTTPHeaderFields = defaultHeaders.merging(endpoint.headers) { $1 }
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = body {
            request.httpBody = body
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        // 发起请求（async/await 一次性操作）
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }

        try validateResponse(httpResponse)
        return (data, httpResponse)
    }

    private func validateResponse(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 401:
            throw HTTPError.unauthorized
        case 403:
            throw HTTPError.forbidden
        case 404:
            throw HTTPError.notFound
        case 500...599:
            throw HTTPError.serverError(response.statusCode)
        default:
            throw HTTPError.unexpectedStatusCode(response.statusCode)
        }
    }
}

// MARK: - HTTP 错误类型

enum HTTPError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case serverError(Int)
    case unexpectedStatusCode(Int)
    case encodingFailed(Error)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse:
            return "无效的服务器响应"
        case .unauthorized:
            return "未授权，请重新登录"
        case .forbidden:
            return "无权限访问"
        case .notFound:
            return "请求的资源不存在"
        case .serverError(let code):
            return "服务器错误（\(code)）"
        case .unexpectedStatusCode(let code):
            return "意外的状态码（\(code)）"
        case .encodingFailed(let error):
            return "请求编码失败：\(error.localizedDescription)"
        case .decodingFailed(let error):
            return "响应解码失败：\(error.localizedDescription)"
        }
    }
}

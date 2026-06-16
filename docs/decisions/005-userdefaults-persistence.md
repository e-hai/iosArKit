# ADR-005: UserDefaults 唯一持久化

## 决策
仅使用 `UserDefaults` 存储轻量偏好，不引入任何数据库。

## 原因
1. 当前持久化需求极轻：默认滤镜索引、首次启动标记等少量键值
2. Core Data 和 SwiftData 的复杂度远超实际需求
3. 第三方数据库违反零外部依赖原则
4. 未来如需结构化存储，用 `Codable` + `FileManager` 处理 JSON/Plist

## 后果
- 禁止引入 Core Data、SwiftData、GRDB、Realm、FMDB
- 拍摄历史等功能如需持久化，使用文件存储
- 无迁移工具可用，数据结构需自行管理

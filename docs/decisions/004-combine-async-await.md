# ADR-004: Combine + async/await 分工

## 决策
Combine 和 async/await 共存，按场景分工：Combine 管 UI 状态绑定和持续事件流，async/await 管一次性异步操作。

## 原因
1. Combine 天然适合 UI 绑定（`@Published` 驱动 SwiftUI 重渲染），不可替代
2. async/await 处理一次性异步（权限请求、相册保存）更简洁
3. 两者解决不同的问题，强行统一会损失各自的优势

## 后果
- Combine → UI/事件流，async/await → 一次性异步
- 禁止将 Combine 全面替换为 async/await
- 跨线程 UI 更新必须切换到 `DispatchQueue.main`

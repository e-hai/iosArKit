# ADR-003: ObservableObject + NavigationView 架构

## 决策
使用 `ObservableObject` + `@Published` 响应式模式 + `NavigationView` + 隐藏 `NavigationLink` 导航。

## 原因
1. `@Observable` macro 需要 iOS 17，不可用
2. `NavigationStack` 需要 iOS 16，不可用
3. `ObservableObject` 在 iOS 15.6 上成熟稳定，Combine 生态完善
4. 隐藏 `NavigationLink` + `AppRouter` 模式提供中心化导航控制

## 后果
- 所有 ViewModel/Manager 必须遵循 `ObservableObject` 协议
- 禁止使用 `@Observable`、`NavigationStack`
- AppRouter 作为单一路由管理器，随子系统增加会膨胀

# ADR-001: iOS 15.6 最低部署目标

## 决策
最低部署目标锁定 iOS 15.6，不使用 iOS 16+ 专属 API（除非 `#available` 保护 + 回退方案）。

## 原因
1. iOS 15 覆盖绝大多数活跃设备，16+ 会丢失大量用户
2. 相机类应用不依赖新系统特性，15.6 功能完备
3. 项目起步即锁定，零迁移成本

## 后果
- `NavigationStack`、`@Observable`、`SwiftData`、`PhotosPicker` 等禁止使用
- 需要在 TECH_STACK.md 维护禁止 API 清单
- 未来升级需团队明确批准

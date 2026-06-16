# ADR-002: 零外部依赖

## 决策
项目仅使用 Apple 官方框架，不引入任何第三方依赖（CocoaPods / SPM / Carthage）。

## 原因
1. 避免供应链风险：第三方库可能被弃用、包含恶意代码或变更许可证
2. 降低维护负担：无需跟踪依赖更新和兼容性
3. Apple 生态已覆盖所有核心需求（AVFoundation、CoreImage、Metal）

## 后果
- 功能实现必须基于 Apple 框架，白名单见 TECH_STACK.md
- 禁止引入第三方数据库（GRDB、Realm、FMDB）
- 团队需要更深入了解 Apple SDK

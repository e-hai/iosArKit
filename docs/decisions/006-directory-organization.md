# ADR-006: 混合目录组织 + PascalCase 命名

## 决策
功能子系统按文件夹组织（`Camera/`、`Gallery/`），通用代码放 `Common/`，文件夹使用 PascalCase 命名。

## 原因
1. 混合模式：核心架构文件快速可查，功能子系统按模块隔离
2. 平铺所有文件在根目录随系统增加不可维护
3. PascalCase 与 Swift 类型命名一致，Xcode 默认风格

## 后果
- 新增功能子系统→ `Ar/<Feature>/`（如 `Camera/Filters/`）
- 通用组件 → `Ar/Common/<Category>/`
- 测试目录镜像源码结构
- 文件夹和文件均 PascalCase

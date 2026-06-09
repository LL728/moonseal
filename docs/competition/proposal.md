# MoonSeal 项目申报书

## 1. 项目名称

MoonSeal：MoonBit 测试充分性与发布质量门禁工具。

## 2. 项目简介

MoonSeal 面向 MoonBit 开源项目的发布前质量检查，提供测试文件发现、包级测试充分性分析、公共接口测试提示、变异测试候选生成和默认发布门禁。项目目标是让 MoonBit 项目在提交、参赛、发布和维护前有一套可重复执行的质量检查。

当前版本不会直接改写源码，也不会替代 `moon test`。它负责回答更靠前的问题：项目中哪些包没有测试，测试文件分布是否合理，公共接口是否缺少测试信号，哪些代码位置适合作为后续变异测试目标。

## 3. 项目方向与适用场景

项目属于软件分析框架和工程质量工具方向，适用于：

- 开源项目发布前检查：在发布前发现无测试包、缺少基础工程材料和门禁失败项。
- 竞赛项目验收：用稳定命令输出测试充分性和质量门禁结果。
- 教学项目评审：帮助学生理解黑盒测试、白盒测试和包级测试覆盖的区别。
- 后续工程演进：为变异测试、质量趋势报告和 CI 集成提供基础数据模型。

## 4. 核心功能

- 扫描 `moon.mod`、`moon.pkg`、`.mbt`、`_test.mbt`、`_wbtest.mbt` 和 `pkg.generated.mbti`。
- 按包统计源码文件、测试文件和公共接口数量。
- 识别黑盒测试与白盒测试。
- 生成布尔、比较符、整数边界和逻辑运算的变异候选。
- 执行默认质量门禁：项目测试数、包级测试、README、许可证声明和 CI workflow。
- 提供 `scan`、`gate`、`mutants`、`explain` 四个 CLI 命令。

## 5. 原创性与差异说明

Mooncakes 公开模块列表中未发现面向 MoonBit 的测试充分性门禁或变异测试候选工具。已有工具更多集中在语法检查、依赖诊断或通用库能力，MoonSeal 选择测试质量这个更成熟的软件工程方向，能够和 MoonBit 的包结构、测试文件命名和接口文件直接结合。

项目首版聚焦“分析和门禁”，不做复杂平台，不做在线服务，也不引入外部依赖。这样的边界能保证项目可构建、可运行、可测试，同时为后续实现自动变异执行和质量趋势对比留下扩展空间。

## 6. 技术路线

MoonSeal 使用 MoonBit 编写核心逻辑，通过 JS backend 读取文件系统。分析流程如下：

1. 读取 `moon.mod` 获取项目基础信息。
2. 递归收集项目文件，排除构建产物和依赖缓存。
3. 通过 `moon.pkg` 建立包列表，通过文件名识别源码、黑盒测试和白盒测试。
4. 读取 `pkg.generated.mbti` 统计公共接口数量。
5. 扫描源码文本，生成稳定的变异候选 ID。
6. 根据默认策略生成质量门禁结果。

## 7. 测试与验收

测试覆盖：

- manifest 与 package import 解析。
- 源码、黑盒测试、白盒测试识别。
- 包级测试充分性统计。
- 公共接口计数。
- 变异候选生成。
- 完整项目、无测试项目、部分包缺测试项目的门禁结果。

验收命令：

```bash
moon info
moon fmt --check
moon test --target js
moon run --target js cmd/main -- scan fixtures/well_tested
moon run --target js cmd/main -- gate fixtures/well_tested
moon run --target js cmd/main -- gate fixtures/untested
moon run --target js cmd/main -- mutants fixtures/mutation_targets
```

## 8. 后续演进路线

- 增加 JSON 输出，便于 CI 平台读取。
- 支持自定义门禁策略。
- 在临时目录中应用单个变异点并运行测试，形成 mutation score。
- 支持对比两次报告，展示测试质量趋势。
- 扩展公共接口与测试文件之间的关联分析。

## 9. 开源协议

项目采用 Apache-2.0 许可证。

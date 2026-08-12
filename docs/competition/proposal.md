# MoonSeal 项目申报书

## 1. 项目名称

MoonSeal：MoonBit 测试充分性与发布质量门禁工具。

## 2. 仓库地址

- GitLink 仓库：https://gitlink.org.cn/LL1266/moonseal
- GitHub 镜像：https://github.com/LL728/moonseal

## 3. 项目简介

MoonSeal 面向 MoonBit 开源项目的发布前质量检查，提供测试文件发现、
包级测试充分性分析、公共接口测试提示、变异测试候选生成和默认发布
门禁。项目目标是让 MoonBit 项目在提交、参赛、发布和维护前有一套可
重复执行的质量检查流程。

当前版本不把源码修改作为用户操作，但可以在隔离的单次运行中应用变异
并调用 `moon test`，随后恢复原文件。它同时解析 MoonBit 覆盖率摘要，
让发布门禁可以基于结构性信号、变异得分和覆盖率阈值做出可重复判断。

## 4. 项目方向与适用场景

项目属于软件工程质量工具方向，适用于以下场景：

- 开源项目发布前检查：提前发现无测试包、缺少基础材料和门禁失败项。
- 竞赛项目验收：用稳定命令输出测试充分性和质量门禁结果。
- 教学项目评审：帮助学生理解黑盒测试、白盒测试和包级测试的差别。
- CI 集成：在多平台上固定 MoonBit 工具链并执行相同的质量门禁。

## 5. 核心功能

- 扫描 `moon.mod`、`moon.pkg`、`.mbt`、`_test.mbt`、
  `_wbtest.mbt` 和 `pkg.generated.mbti`。
- 按包统计源码文件、测试文件和公共接口数量。
- 识别黑盒测试与白盒测试。
- 生成布尔、比较符、整数边界和逻辑运算的变异测试候选。
- 执行默认质量门禁：项目测试数、包级测试、README 文件、根 LICENSE
  文件和 CI workflow。
- 按 `moonseal.json` 执行最小变异得分和最小覆盖率策略。
- 提供动态变异执行、覆盖率摘要解析和 JSON 输出。
- 提供 `scan`、`gate`、`mutants`、`explain` 四个 CLI 命令。

## 6. 原创性与差异说明

MoonSeal 聚焦 MoonBit 仓库中的“测试充分性”问题，而不是通用的代码风
格检查或依赖解析。它直接结合 MoonBit 的包结构、测试命名约定和
 `pkg.generated.mbti` 接口文件，提供更贴近发布环节的工程信号。

项目聚焦“分析、动态质量信号和门禁”，不做在线平台，不引入额外运行
时依赖，也不把门禁结果绑定到特定托管平台。这种取舍保证了项目可构建、
可运行、可测试，并能在 GitHub 与 GitLink 镜像中保持一致。

## 7. 技术路线

MoonSeal 使用 MoonBit 编写核心逻辑，通过 JS backend 读取文件系统。
分析流程如下：

1. 读取 `moon.mod` 获取项目基础信息。
2. 递归收集项目文件，排除构建产物和依赖缓存。
3. 通过 `moon.pkg` 建立包列表，通过文件名识别源码、黑盒测试和白盒
   测试。
4. 读取 `pkg.generated.mbti` 统计公共接口数量。
5. 扫描源码文本，生成稳定的变异候选 ID。
6. 按需逐个应用候选变异并运行 JS 测试，统计 killed/survived。
7. 按需运行 MoonBit coverage 并解析总覆盖率和文件覆盖率。
8. 根据默认或 `moonseal.json` 策略生成质量门禁结果。

## 8. 测试与验收

测试覆盖：

- manifest 与 package import 解析。
- 源码、黑盒测试、白盒测试识别。
- 包级测试充分性统计。
- 公共接口计数。
- 变异候选生成。
- 动态变异执行与覆盖率摘要解析。
- README/LICENSE 文件存在性和策略阈值。
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
moon run --target js cmd/main -- explain fixtures/well_tested
moon run --target js cmd/main -- gate fixtures/well_tested --mutate --coverage
```

## 9. 后续演进路线

- 支持对比两次报告，展示测试质量趋势。
- 扩展公共接口与测试文件之间的关联分析。
- 增加更精细的变异操作和跨后端测试策略。
- 增加跨平台覆盖率格式适配与历史报告归档。

## 10. 开源协议

项目采用 Apache-2.0 许可证。

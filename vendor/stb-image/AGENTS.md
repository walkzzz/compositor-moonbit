# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Overview

**stb-image** (walkzzz/image) — 纯 MoonBit 图像处理库，零 C FFI 依赖。

| 属性 | 值 |
|------|-----|
| 版本 | 0.4.12 (mooncakes) / v29.0.0 (功能迭代) |
| 测试 | 2443 × 4 目标 (native/wasm-gc/js/wasm) |
| API | 334 公开函数 + 69 类型 |
| 格式 | 15 种编解码 (PNG/JPEG/BMP/GIF/QOI/TGA/PSD/HDR/PNM/TIFF/ICO/CUR/ICNS/APNG/WebP) |
| 覆盖率 | 90.4% |

## Project Structure

- MoonBit packages are organized per directory; each directory contains a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in
  `_wbtest.mbt`).

- In the toplevel directory, there is a `moon.mod` file listing module
  metadata.

### 多子包架构

```
src/
├── types/              # 全目标类型 (Image, Image16, ImageF, LoadError 等)
├── pure/               # 纯 MoonBit 后端 (无 C FFI)
│   ├── codec/          #   格式编解码 (15 种格式)
│   ├── color/          #   颜色操作
│   └── util/           #   工具
├── lib/                # 高层封装 (自动格式分派) + 流式解码
├── meta/               # 元数据 (EXIF, PNG meta)
├── process/            # 高级图像处理算法 (7 子包)
│   ├── color/          #   色彩转换/调整/CLAHE/自适应阈值/Retinex/去雾
│   ├── edge/           #   边缘检测/Canny/霍夫/轮廓
│   ├── feature/        #   特征检测: Harris/ORB/SIFT/模板匹配/光流/GLCM/LBP
│   ├── filter/         #   滤波/去噪/图像修复
│   ├── frequency/      #   FFT/DCT/Haar 小波/频率滤波
│   ├── segment/        #   分水岭/SLIC/grabCut/形态学/连通域
│   └── transform/      #   几何变换/透视/Seam Carving/金字塔
├── util/               # 工具函数 (基于 pure 的上层封装)
├── bench.mbt           # 性能基准测试
└── reexport.mbt        # 顶层 API re-export (283 pub fn + 47 pub type)
```

## Core Constraints

> [!WARNING]
> 以下约束不可违反：

- **禁止引入 C FFI 依赖** — 所有代码必须纯 MoonBit 实现，确保四目标可用
- **禁止破坏已有 API** — 新增功能只添加不修改已有签名，保持向后兼容
- **禁止目标条件编译** — 不使用 `target == "native"` 等条件分支，四目标共用代码
- **新增 `pub` 函数须在 `reexport.mbt` 注册** — 保持顶层 API 完整性

## Coding Convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

- New `pub fn`/`pub let`/`pub type` must be re-exported in `src/reexport.mbt`
  to keep the top-level API complete. Ordinary functions use `pub let` alias,
  functions with labeled parameters use `pub fn` wrapper to preserve defaults.
  After adding re-exports, run `moon info` to regenerate `.mbti` and verify the
  new API surface is visible.

- 命名：`snake_case` 函数/变量，`kebab-case` 项目/目录名
- 测试命名：`"函数名: 场景描述"`（测试名称必须唯一，重复会触发 deprecated 警告）
- 错误处理：`raise LoadError::DecodeFailed("msg")`

### MoonBit 关键语法约束

- `@math.atan2/cos/sin/pow/exp/log2/log10` 接受 `Double`，需 `.to_double()` 转入，`Float::from_double()` 转出
- `@math.lnf(Float)` 用于 Float 自然对数；`@math.log` **不存在**
- `@math.sqrt` **不存在**，用 `.sqrt()` 方法
- `not(expr)` 已弃用，用 `!expr`
- `1e10F` / `1e-10F` **无效**，用 `10000000000.0F` / `0.0000000001F`
- `(0..<n).rev()` **不支持**，用手动反向循环
- `is_empty()` 已弃用（Option），用 `x is None`；`is_not_empty()` 不存在，用 `x is Some(_)`
- `clamp` 用标签参数：`.clamp(min=0, max=255)`
- `pub(all) enum/struct` 才允许外部构造
- `Bytes` 不可变，用 `Array[Byte]` 构建后 `Bytes::from_array()`
- 回调中使用 `assert` 需 `raise` 注解，或收集数据在外部断言
- Int × Float 类型不匹配：需 `Float::from_int(n) * float_val`
- `ImageF.data` 是 `Bytes`（IEEE 754 LE），不是 `Array[Float]`；用 `Float::to_le_bytes()` 转换
- `UInt` 与 `Int` 类型不匹配：建议统一用 `Int`
- `<<=` 运算符不支持，用 `x = x << 1`
- Range `.rev()` 在 for 循环中不支持

## Tooling

- `moon fmt` is used to format your code properly.

- `moon ide` provides project navigation helpers like `peek-def`, `outline`, and
  `find-references`. See $moonbit-agent-guide for details.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check tests pass. MoonBit supports snapshot testing; when
  changes affect outputs, run `moon test --update` to refresh snapshots.

- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for results that
  are stable or very unlikely to change. For snapshot tests that record
  structured debugging output, derive `Debug` and use `debug_inspect`, rather
  than deriving `Show` for debugging. For solid, well-defined results (e.g.
  scientific computations), prefer assertion tests. You can use
  `moon coverage analyze > uncovered.log` to see which parts of your code are
  not covered by tests.

## Build & Test

```bash
# 编译检查（四目标）
moon check
moon check --target wasm-gc
moon check --target js
moon check --target wasm

# 运行测试（四目标各 1203）
moon test --target native
moon test --target wasm-gc
moon test --target js
moon test --target wasm

# 重新生成 API 接口
moon info

# 格式化
moon fmt

# 性能基准
moon run --target native
```

## Documents

| 文档 | 说明 |
|------|------|
| [README.md](README.md) | 项目说明（中文） |
| [docs/architecture.md](docs/architecture.md) | 架构图、包依赖关系、设计决策 |
| [docs/api_reference.md](docs/api_reference.md) | 完整 API 参考（283 函数 + 47 类型） |
| [docs/roadmap.md](docs/roadmap.md) | 迭代路线图 |
| [docs/comparison.md](docs/comparison.md) | mooncakes.io 图像库对比 |
| [docs/performance_report.md](docs/performance_report.md) | 性能基准报告 |
| [docs/skill.md](docs/skill.md) | AI 辅助开发技能描述 |
| [docs/changelog.md](docs/changelog.md) | 版本变更历史 |

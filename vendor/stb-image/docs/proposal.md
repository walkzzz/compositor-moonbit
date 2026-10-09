# 项目申报书：walkzzz/image

## 1. 项目名称

**walkzzz/image** — 纯 MoonBit 图像处理库

## 2. 项目简介

`walkzzz/image` 是一个零 C FFI 依赖的纯 MoonBit 图像处理库，覆盖 15 种图像格式的编解码，提供从基础像素操作到高级计算机视觉算法的完整能力。支持 native / wasm-gc / js / wasm 四目标，1203 项测试全通过，代码覆盖率 90.4%。

## 3. 项目方向与适用场景

**方向**：生态库移植（参考 [stb_image.h](https://github.com/nothings/stb)）

**适用场景**：
- MoonBit 桌面/ WebAssembly/ JavaScript 应用中的图像加载、处理和保存
- 无需 C 编译器的跨平台图像库需求
- 计算机视觉算法原型开发（SIFT、ORB、Canny、分水岭等）
- Web 端图像处理（wasm/js 目标）

## 4. 拟实现的核心功能

### 已完成（v5.3.0）

| 类别 | 功能 | 统计 |
|------|------|------|
| 格式编解码 | PNG / JPEG / BMP / GIF / QOI / TGA / PSD / HDR / PNM / TIFF / ICO / CUR / ICNS / APNG / WebP | 15 种格式 |
| 像素深度 | 8-bit `Image`、16-bit `Image16`、HDR 浮点 `ImageF` | 3 种深度 |
| 图像处理 | 缩放(7种滤波器) / 裁剪 / 旋转 / 翻转 / 色彩转换 / 绘制 / 合成 / 混合模式 / 滤波 / 形态学 / 直方图 / 量化 | 100+ 函数 |
| 高级算法 | Canny / Harris / ORB / SIFT / 模板匹配 / 光流 / RANSAC / grabCut / 分水岭 / SLIC / FFT / DCT / Haar 小波 / CLAHE / NLM / Retinex / 去雾 / Seam Carving | 50+ 函数 |
| 元数据 | EXIF 读取/写入 / PNG text chunks | 4 函数 |
| 安全加固 | MAX_IMAGE_DIMENSION 维度守卫 / check_dims 校验 / safe_mul 溢出保护 / 44 项 fuzzing 测试 | 全解码器覆盖 |
| 多目标 | native / wasm-gc / js / wasm 四目标共用纯 MoonBit 代码 | 0 条件编译 |

### 核心指标

- **有效 MoonBit 代码**：9065 LOC
- **公开 API**：286 函数 + 1 常量 + 47 类型
- **测试**：1203 × 4 目标，全通过
- **覆盖率**：90.4%
- **示例**：32 个可运行示例
- **文档**：13 篇技术文档（架构 / API 参考 / 性能报告 / 对比等）

## 5. 技术路线

- **纯 MoonBit 实现**：所有代码用纯 MoonBit 编写，零 C FFI 依赖，确保四目标可用性
- **多子包架构**：types → pure/{codec,color,util} → lib/process/meta/util，依赖单向向下
- **安全优先**：所有解码器入口校验维度溢出，fuzzing 审计，ASan 验证
- **向后兼容**：v1.0 API 冻结，新增功能只添加不修改已有签名
- **四目标测试**：同一套测试在 native / wasm-gc / js / wasm 上均通过

## 6. 测试与文档

- `moon test`：1203 测试 × 4 目标全通过
- `moon check`：四目标编译零错误零警告
- CI：GitHub Actions 自动化四目标 check + test + bench + coverage
- 32 个可运行示例覆盖全部 API 场景
- 完整 API 参考文档（docs/api_reference.md）
- 性能基准报告（46 项基准，docs/performance_report.md）
- 架构文档、贡献指南、路线图

## 7. 参考项目

| 属性 | 值 |
|------|-----|
| 原项目 | [stb](https://github.com/nothings/stb) — `stb_image.h` |
| 原作者 | Sean Barrett (@nothings) |
| 原许可证 | MIT / Public Domain |
| 原语言 | C（单头文件库） |
| 移植范围 | 15 种格式编解码 + 像素深度 + 基础操作（纯 MoonBit 重写） |
| 新增能力 | 50+ 高级 CV 算法、流式解码、安全加固、四目标支持 |

## 8. GitHub 仓库

https://github.com/toadium/stb-image

## 9. Gitlink 仓库

https://www.gitlink.org.cn/walkzzz/stb-image

## 10. mooncakes.io 发布

`moon add walkzzz/image`

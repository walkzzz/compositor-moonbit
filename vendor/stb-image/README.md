<div align="center">

# image

**纯 MoonBit 图像处理库** · 零 C 依赖 · 四目标原生支持

[English](README.en.md) · 简体中文

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.20260819-blue)](https://www.moonbitlang.com/)
[![OSC2026](https://img.shields.io/badge/OSC2026-参赛项目-orange)](https://www.gitlink.org.cn/competitions/track1_2026MoonBit)
[![Targets](https://img.shields.io/badge/targets-native%20%7C%20wasm--gc%20%7C%20js%20%7C%20wasm-success)]()
[![Tests](https://img.shields.io/badge/tests-1725-brightgreen)]()
[![Coverage](https://img.shields.io/badge/coverage-91.2%25-brightgreen)]()
[![Functions](https://img.shields.io/badge/API-1100%2B%20functions%20%2B%20187%20types-blueviolet)]()
[![Version](https://img.shields.io/badge/version-0.6.0-orange)]()

[亮点](#-亮点) · [格式支持](#-格式支持) · [快速上手](#-快速上手) · [功能一览](#-功能一览) · [多目标](#-多目标支持) · [包结构](#-包结构) · [文档](#-文档) · [构建](#-构建与测试) · [贡献](#-贡献)

</div>

---

## 📖 简介

`image` 是一个纯 MoonBit 实现的图像处理库，**无任何 C FFI 依赖**。覆盖 15 种格式的解码与编码，提供从基础像素操作到高级计算机视觉算法的完整能力。安装：`moon add walkzzz/image`。

> 详细说明（版本映射、格式检测、多目标、核心约束）见 [docs/notes.md](docs/notes.md)。

## 🏆 OSC 2026 参赛声明

本项目参与 **2026 MoonBit 国产基础软件开源大赛（OSC 2026）**。AI 辅助说明：本项目在开发过程中使用了 AI 编程助手辅助完成代码生成、测试编写、文档撰写和重构工作。所有 AI 生成代码均经过人工审查、测试验证和逻辑确认，确保代码质量、正确性和可维护性。详细 AI 使用范围见 [docs/skill.md](docs/skill.md)。

---

## ✨ 亮点

| | 特性 | 说明 |
|---|---|---|
| 🟢 | **零 C 依赖** | 全部纯 MoonBit 实现，无需 C 编译器，部署极简 |
| 🟢 | **四目标支持** | native / wasm-gc / js / wasm 共用同一代码库，无条件编译 |
| 🟢 | **格式覆盖广** | PNG / JPEG / BMP / GIF / QOI / TGA / PSD / HDR / PNM / TIFF / ICO / CUR / ICNS / APNG / WebP — 含独家 PSD、HDR |
| 🟢 | **像素深度全** | 8 位 `Image`、16 位 `Image16`、HDR 浮点 `ImageF` |
| 🟢 | **900+ 个 API** | 从基础 I/O 到 FFT、Canny、分水岭、SLIC、ORB、SIFT、SIFT 匹配、RANSAC 单应性、grabCut、流式解码、光流、模板匹配、WebP lossy 编解码、OCR 全链路（数字/英文/中文/表格/手写体/多语言混合）等高级算法 |
| 🟢 | **OCR 全链路** | 预处理→文本检测→字符分割→特征提取→分类器→数字/英文/中文OCR→表格识别→后处理→文档理解→手写体→多语言混合，36 个模块文件 |
| 🟢 | **流式解码** | 逐行 / 分块 / 指定通道回调（当前为全量解码后逐行分发，v5.0 计划增量解码） |
| 🟢 | **安全加固** | MAX_IMAGE_DIMENSION(65535) 维度守卫 + check_dims 全解码器入口校验 + safe_mul 溢出保护 |
| 🟢 | **多子包架构** | 8 个子包职责清晰，编译并行化，可独立测试 |

---

## 🖼️ 格式支持

| 格式 | 解码 | 编码 | 备注 |
|:----:|:----:|:----:|------|
| PNG | ✅ | ✅ | 8/16-bit，Adam7 隔行扫描 |
| JPEG | ✅ | ✅ | baseline，可调质量 |
| BMP | ✅ | ✅ | 1/4/8/16/24/32-bit |
| GIF | ✅ | ✅ | 动画 GIF 解码/编码 |
| QOI | ✅ | ✅ | Quite OK Image |
| TGA | ✅ | ✅ | 含 RLE |
| PSD | ✅ | — | Photoshop 文档（独家） |
| HDR | ✅ | ✅ | IEEE 754 浮点（独家） |
| PNM | ✅ | ✅ | PPM / PGM |
| TIFF | ✅ | ✅ | 解码仅支持无压缩（LZW/PackBits/Deflate 尚未实现） |
| ICO | ✅ | ✅ | 单尺寸/多尺寸 |
| CUR | ✅ | ✅ | Windows 光标 |
| ICNS | ✅ | ✅ | macOS 图标 |
| APNG | ✅ | ✅ | 动画 PNG |
| WebP | ✅ (lossless) | ✅ (lossy VP8) | lossless (VP8L) 解码 + lossy (VP8) 编码；注意：lossy 编码结果不可被本库解码 |

---

## 🚀 快速上手

### 安装

```bash
moon add walkzzz/image
```

### 最小示例

```moonbit
// 从字节解码
let img : Image = load_from_bytes(png_bytes)
println("width=\{img.width}, height=\{img.height}, channels=\{img.channels}")

// 编码为 PNG 字节
let out : Bytes = write_png_to_bytes(img)

// 缩放（7 种滤波器 × 4 种边缘模式）
let resized : Image = resize(img, 128, 128)

// 自动检测格式并解码
let any : Image = decode_any(data, req_channels=Some(3))

// 加载动画 GIF
let anim : GifAnimation = load_gif_from_bytes(gif_bytes)
println("frames=\{anim.frames.length()}, delays=\{anim.delays}")

// 查询图像信息（不解码像素）
let info : ImageInfo? = info_from_bytes(data)

// 流式解码：逐行回调（当前为全量解码后逐行分发）
decode_stream(data, fn(row, y) {
  // 处理第 y 行像素 row : Array[Array[Int]]
})
```

### 错误处理

```moonbit
try {
  let img = load_from_bytes(data)
} catch {
  LoadError::FileIO(msg) => println("文件IO错误: \{msg}")
  LoadError::DecodeFailed(msg) => println("解码失败: \{msg}")
  LoadError::UnsupportedFormat(msg) => println("不支持的格式: \{msg}")
}
```

### 高级示例：SIFT 特征匹配

```moonbit
// 检测 SIFT 特征
let kp1 = sift_detect(img1)
let kp2 = sift_detect(img2)

// L2 距离 + Lowe 比率测试匹配
let matches = sift_match(kp1, kp2, ratio_threshold=0.75)

// RANSAC 鲁棒单应性估计
let homography = ransac_homography(matches, threshold=5.0, iterations=1000)
```

### 完整示例集

`src/examples/` 包含 **32 个示例**，覆盖全部 API 场景。详见 [docs/examples.md](docs/examples.md)。

---

## 🧰 功能一览

900+ 个公开 API 按分类概览，详见 [docs/features.md](docs/features.md)。完整签名见 [docs/api_reference.md](docs/api_reference.md)。

### OCR 功能（v7.0 - v9.4）

| 模块 | 功能 | 版本 |
|------|------|------|
| **预处理** | Sauvola/Niblack/Otsu 二值化、文档增强、倾斜校正、版面分析 | v7.0 |
| **文本检测** | 连通域分析、投影分析、文本行检测、字符分割 | v7.1 |
| **字符分割** | 滴水算法、粘连字符检测、连通域分割、后处理 | v7.2 |
| **特征提取** | HOG、LBP、投影特征、网格特征、统计特征、组合特征 | v7.3 |
| **分类器** | KNN、模板匹配、4种距离度量、特征归一化/标准化 | v7.4 |
| **数字 OCR** | 0-9 数字识别、7段显示模板 | v7.5 |
| **英文 OCR** | 数字+大写字母+小写字母、36+字符模板 | v8.0 |
| **后处理** | 词典匹配、N-gram 语言模型、拼写纠错、混淆字符纠错 | v8.1 |
| **中文 OCR** | 100 常用字基础、500+ 常用字完善、部件分解 | v8.2/v9.0 |
| **表格识别** | 表格线检测、结构分析、单元格提取 | v8.3 |
| **准确率提升** | Hu 矩、训练数据管理、特征增广、集成学习 | v9.1 |
| **文档理解** | 版面分析、阅读顺序、标题正文分类、14种元素类型 | v9.2 |
| **手写体识别** | 多变体模板、灵活分割、倾斜校正、多变体投票 | v9.3 |
| **多语言混合** | 语言检测、中英混排、50+标点模板、自动语言检测 | v9.4 |

## 🎯 多目标支持

| 目标 | 后端 | 测试 | 状态 |
|:----:|:----:|:----:|:----:|
| **native** | 纯 MoonBit | 1700 | ✅ |
| **wasm-gc** | 纯 MoonBit | 1700 | ✅ |
| **js** | 纯 MoonBit | 1700 | ✅ |
| **wasm** | 纯 MoonBit | 1700 | ✅ |

---

## 📦 包结构

```
src/
├── types/              # 全目标类型 (Image, Image16, ImageF, LoadError 等)
├── pure/               # 纯 MoonBit 后端 (无 C FFI)
│   ├── codec/          #   格式编解码 (15 种格式)
│   ├── color/          #   颜色操作
│   └── util/           #   工具
├── lib/                # 高层封装 (自动格式分派)
├── meta/               # 元数据 (EXIF, PNG meta)
├── process/            # 高级图像处理算法 (8 子包)
│   ├── color/          #   色彩转换/调整/CLAHE/自适应阈值/Retinex/去雾
│   ├── edge/           #   边缘检测/Canny/霍夫/轮廓
│   ├── feature/        #   特征检测: Harris/ORB/SIFT/模板匹配/光流/GLCM/LBP
│   ├── filter/         #   滤波/去噪/图像修复
│   ├── frequency/      #   FFT/DCT/Haar 小波/频率滤波
│   ├── segment/        #   分水岭/SLIC/grabCut/形态学/连通域
│   ├── transform/      #   几何变换/透视/Seam Carving/金字塔
│   └── ocr/            #   OCR 全链路 (19 个模块)
│       ├── 预处理      #     binarization/document_enhance/deskew/layout_analysis
│       ├── 检测分割    #     connected_components/projection_analysis/char_segmentation
│       ├── 特征分类    #     feature_extraction/classifier
│       ├── 识别引擎    #     digit_ocr/english_ocr/chinese_ocr/advanced_chinese_ocr
│       ├── 后处理      #     postprocess/table_recognition/document_understanding
│       └── 扩展        #     ocr_accuracy/handwriting_ocr/multilingual_ocr
├── examples/           # 示例代码 (32 个示例，覆盖全部 API)
├── util/               # 工具函数 (基于 pure 的上层封装)
├── bench.mbt           # 性能基准测试
└── reexport.mbt        # 顶层 API re-export (231 pub fn + 187 pub type)
```

---

## 📄 文档

| 文档 | 说明 |
|------|------|
| [docs/architecture.md](docs/architecture.md) | 架构图、包依赖关系、设计决策 |
| [docs/api_reference.md](docs/api_reference.md) | 完整 API 参考（900+ 函数 + 187 类型） |
| [docs/roadmap.md](docs/roadmap.md) | 迭代路线图 |
| [docs/comparison.md](docs/comparison.md) | mooncakes.io 图像库对比 |
| [docs/performance_report.md](docs/performance_report.md) | 性能基准报告（46 项基准） |
| [docs/notes.md](docs/notes.md) | 使用说明与核心约束 |
| [docs/examples.md](docs/examples.md) | 完整示例集（32 个示例） |
| [docs/features.md](docs/features.md) | 功能一览（900+ API 分类概览） |
| [docs/contributing.md](docs/contributing.md) | 贡献指南（开发环境/流程/规范） |
| [docs/skill.md](docs/skill.md) | AI 辅助开发技能描述 |
| [docs/changelog.md](docs/changelog.md) | 版本变更历史 |

---

## 🔧 构建与测试

```bash
# 编译检查（四目标）
moon check
moon check --target wasm-gc
moon check --target js
moon check --target wasm

# 运行测试（1700）
moon test --target native
moon test --target wasm-gc
moon test --target js
moon test --target wasm

# 运行性能基准测试
moon run --target native

# 重新生成 API 接口
moon info
```

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！详见 [docs/contributing.md](docs/contributing.md)。

---

## 📄 许可证

[MIT](LICENSE) — 自由使用、修改、分发。

---

## 🔗 移植说明

### 原项目信息

| 属性 | 值 |
|------|-----|
| 原项目 | [stb](https://github.com/nothings/stb) — `stb_image.h` |
| 原作者 | Sean Barrett (@nothings) |
| 原许可证 | MIT / Public Domain |
| 原语言 | C (单头文件库) |
| 移植目标 | MoonBit (纯语言，零 C FFI) |

### 移植范围

本项目以 `stb_image.h` 为参考基础，将其核心图像编解码能力用纯 MoonBit 重新实现：

- **格式编解码**：PNG / JPEG / BMP / GIF / QOI / TGA / PSD / HDR / PNM / TIFF / ICO / CUR / ICNS / APNG / WebP — 15 种格式
- **像素深度**：8 位 `Image`、16 位 `Image16`、HDR 浮点 `ImageF`
- **基础操作**：缩放 / 裁剪 / 旋转 / 翻转 / 色彩转换 / 通道操作 / 绘制 / 合成

### 超越原项目的扩展

在移植基础上，本项目新增了大量**原 `stb_image.h` 不具备**的高级能力：

- **流式解码** — 逐行 / 分块回调接口（当前为全量解码后逐行分发）
- **计算机视觉算法** — Canny / Harris / ORB / SIFT / 模板匹配 / 光流 / RANSAC / grabCut
- **频域分析** — FFT / DCT / Haar 小波 / 频率滤波
- **图像分割** — 分水岭 / SLIC 超像素 / K-means / 连通域
- **高级滤波** — 双边 / NLM 去噪 / CLAHE / Retinex / 去雾 / 图像修复
- **特征描述** — LBP / GLCM 纹理 / Hu 矩 / 感知哈希
- **WebP lossy (VP8) 编码** — 原项目不支持 WebP
- **OCR 全链路** — 预处理/文本检测/字符分割/特征提取/分类器/数字OCR/英文OCR/中文OCR/表格识别/后处理
- **OCR 扩展** — 完善中文OCR(500+字)/准确率提升(Hu矩/集成学习)/文档理解/手写体识别/多语言混合识别
- **安全加固** — 维度溢出守卫（check_dims + MAX_IMAGE_DIMENSION）+ 溢出安全乘法（safe_mul）+ 全解码器入口校验

### 与原项目的差异

| 方面 | stb_image.h | 本项目 |
|------|-------------|--------|
| 语言 | C | MoonBit |
| 依赖 | C 编译器 | 零 C 依赖 |
| 目标 | native | native / wasm-gc / js / wasm |
| 格式数 | 7 | 15 |
| API 数 | ~30 | 900+ |
| 高级算法 | 无 | 50+ |
| 内存安全 | 手动 | GC 管理 |

---

## 🙏 致谢

- **[stb](https://github.com/nothings/stb)** — 原始 C 实现的参考基础
- **[MoonBit](https://www.moonbitlang.com/)** — 纯 MoonBit 语言与工具链
- **[OpenCV](https://opencv.org/)** — 高级算法参考（ORB/Canny/Harris/光流等）

---

<div align="center">

如果这个项目对你有帮助，欢迎 ⭐ Star 支持一下！

</div>

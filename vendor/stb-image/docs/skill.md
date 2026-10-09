---
name: image
description: MoonBit 图像处理库 — 纯 MoonBit 实现，多目标支持（native/wasm-gc/js/wasm 均使用纯 MoonBit），完整图像解码/编码/缩放/处理能力，1203 测试 × 4 目标 (native/wasm-gc/js/wasm)。
---

# image 包使用指南

纯 MoonBit 图像处理库，纯 MoonBit 实现，无 C FFI 依赖。

## 用途

纯 MoonBit 图像处理库，提供完整的图像加载/写入/缩放/处理能力。多目标支持：四目标 (native/wasm-gc/js/wasm) 均使用纯 MoonBit（`src/pure/{codec,color,util}/`）。覆盖 PNG/JPEG/BMP/GIF/QOI/ICO/ICNS/TGA/PSD/HDR/PNM/TIFF/APNG/WebP 等 15 种格式，以及裁剪/旋转/翻转/色彩/滤波/直方图/量化/ORB/模板匹配/光流/图像修复等图像处理操作。

## 快速开始

```moonbit
// 从内存字节加载
let img : Image = load_from_bytes(png_bytes)
println("width=\{img.width}, height=\{img.height}, channels=\{img.channels}")

// 从内存字节加载，强制 RGBA
let img2 : Image = load_from_bytes(png_bytes, req_channels=Some(4))

// 编码为 PNG 字节
let out : Bytes = write_png_to_bytes(img)

// 缩放
let resized : Image = resize(img, 128, 128)

// 自动检测格式并解码
let any : Image = decode_any(data, req_channels=Some(3))

// 加载动画 GIF
let anim : GifAnimation = load_gif_from_bytes(gif_bytes)
println("frames=\{anim.frames.length()}")

// 读取 EXIF 元数据
let exif : ExifInfo? = read_exif_from_bytes(jpeg_bytes)
```

## API 概览

### 类型（47 个）

| 类型 | 说明 |
|------|------|
| `Image` | 8位解码结果 `{ width, height, channels, data : Bytes }` |
| `Image16` | 16位解码结果（UInt16 little-endian） |
| `ImageF` | HDR 浮点解码结果（IEEE 754 little-endian） |
| `ImageInfo` | 图像信息 `{ width, height, channels }`，不含像素数据 |
| `GifAnimation` | 动画 GIF `{ frames : Array[Image], delays : Array[Int] }` |
| `LoadError` | 错误类型 `{ FileIO, UnsupportedFormat, DecodeFailed, EncodeFailed }` |
| `ImageFormat` | 格式枚举 `{ Png, Jpeg, Bmp, Gif, Tga, Psd, Hdr, Pnm, Qoi, Webp, Unknown }` |
| `ResizeFilter` | 缩放滤波器 `{ Default, Box, Triangle, CubicBSPline, CatmullROM, Mitchell, PointSample }` |
| `ResizeEdge` | 缩放边缘模式 `{ Clamp, Reflect, Wrap, Zero }` |
| `ExifInfo` | EXIF 元数据 `{ make, model, date_time : String, orientation : Int }` |
| `PngTextChunk` | PNG 文本块 `{ keyword, text : String }` |
| `SiftKeypoint` | SIFT 关键点 `{ x, y, octave, layer, scale, angle }` |
| `SiftDescriptor` | SIFT 描述子 `{ keypoint, descriptor : Array[Float] }`（128 维） |
| `SiftMatch` | SIFT 匹配结果 `{ idx1, idx2, distance }` |
| `StreamInfo` | 流式解码信息 `{ width, height, channels }` |

### 加载（3 函数）

`load_from_bytes`、`load_f_from_bytes`、`load_gif_from_bytes` — `load_from_bytes` 支持 `req_channels? : Int?` 可选参数

### 写入（5 函数）

`write_png_to_bytes` / `write_bmp_to_bytes` / `write_tga_to_bytes` / `write_jpeg_to_bytes` / `write_hdr_to_bytes`

### 缩放（1 函数）

`resize` — 支持 `filter? : ResizeFilter` 和 `edge? : ResizeEdge` 可选参数

### 格式检测（3 函数）

`detect_format` / `decode_any` / `is_supported_format`

### 编解码（18 函数）

- QOI：`decode_qoi` / `encode_qoi`
- ICO/ICNS/CUR：`encode_ico` / `encode_ico_sizes` / `encode_icns` / `decode_cur` / `encode_cur`
- GIF：`encode_gif` / `encode_gif_animation`
- PNM：`encode_ppm` / `encode_pgm` / `encode_pnm`
- TIFF：`decode_tiff` / `encode_tiff`
- APNG：`decode_apng` / `encode_apng`
- WebP：`decode_webp`（lossless VP8L）/ `encode_webp_lossy`（lossy VP8）

### 图像处理（19+ 函数）

- 变换：`crop` / `crop_16` / `crop_f` / `rotate_90` / `rotate_180` / `rotate_270` / `flip_horizontal`
- 色彩：`to_grayscale` / `to_rgb` / `to_rgba` / `premultiply_alpha` / `unpremultiply_alpha`
- 绘制：`draw_copy` / `draw_over`

### 色彩调整（8 函数）

`adjust_brightness` / `adjust_contrast` / `adjust_gamma` / `invert` / `rgb_to_hsv` / `hsv_to_rgb` / `rgb_to_hsl` / `hsl_to_rgb`

### 滤波（6 函数）

`box_blur` / `gaussian_blur` / `sharpen` / `edge_detect_sobel` / `edge_detect_laplacian` / `edge_detect_prewitt`

### 几何（2 函数）

`warp_affine`（仿射变换+双线性插值）/ `rotate`（任意角度旋转）

### 直方图（3 函数）

`histogram` / `histogram_equalize` / `histogram_normalize`

### 量化（2 函数）

`floyd_steinberg`（误差扩散抖动）/ `median_cut`（中位切分量化）

### ORB 特征检测（3 函数）

`orb_detect`（FAST-9 + rBRIEF 256位描述子）/ `orb_hamming`（汉明距离）/ `orb_match`（特征匹配）

### 模板匹配（2 函数）

`template_match`（6种方法：SqDiff/CCorr/CCoeff + 归一化）/ `template_match_best`（最佳匹配）

### 图像修复（2 函数）

`inpaint`（扩散法，Laplace方程迭代）/ `inpaint_fast`（距离加权快速法）

### 光流（2 函数）

`lucas_kanade`（稀疏光流，特征点跟踪）/ `horn_schunck`（密集光流场）

### SIFT 特征检测（1 函数）

`sift_detect`（DoG金字塔+128维描述子，尺度不变特征）

### SIFT 匹配 + RANSAC（2 函数）

`sift_match`（L2距离+Lowe比率测试）/ `ransac_homography`（RANSAC单应性矩阵估计，DLT）

### grabCut 分割（1 函数）

`grab_cut`（交互式前景提取，GMM+ICM优化）

### 安全（3 函数 + 1 常量）

`check_dims`（维度校验，raise LoadError）/ `safe_mul`（溢出安全乘法，返回 Int?）/ `safe_mul3`（溢出安全三乘，返回 Int?）/ `MAX_IMAGE_DIMENSION`（常量 65535，单边最大像素数）

### 流式解码（3 函数）

`decode_stream`（逐行回调）/ `decode_stream_chunked`（分块回调）/ `decode_stream_channels`（指定通道）

### 高级算法（40+ 函数）

- 边缘：`canny_edge` / `hough_lines` / `hough_circles` / `find_contours`
- 特征：`harris_corners` / `good_features_to_track` / `gabor_filter` / `lbp`
- 分割：`watershed` / `slic` / `kmeans_segment` / `connected_components` / `grab_cut`
- 频域：`fft_2d` / `dct_2d` / `haar_transform_2d` / `freq_filter`
- 形态学：`erode` / `dilate` / `morph_open` / `morph_close` / `skeletonize`
- 去噪：`bilateral_filter` / `nlm_denoise` / `haar_denoise` / `dehaze`
- 质量：`mse` / `psnr` / `ssim` / `compute_glcm`

### 元数据（4 函数）

`read_exif_from_bytes` / `read_png_text_chunks` / `create_exif_segment` / `write_exif_to_bytes`

### 查询（4 函数）

`info_from_bytes`、`is_16_bit_from_bytes`、`is_hdr_from_bytes`、`failure_reason`

### 配置（8 函数）

`set_flip_vertically_on_load`、`flip_vertically_on_write`、`set_unpremultiply_on_load`、`convert_iphone_png_to_rgb`、`hdr_to_ldr_gamma/scale`、`ldr_to_hdr_gamma/scale`

## 最小示例

```moonbit
let bmp = b"\x42\x4D\x3A\x00\x00\x00\x00\x00\x00\x00\x36\x00\x00\x00\x28\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01\x00\x18\x00\x00\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xFF\x00"
let img = load_from_bytes(bmp)
assert_eq(img.width, 1)
assert_eq(img.height, 1)
assert_eq(img.channels, 3)
```

## 错误处理

```moonbit
try {
  let img = load_from_bytes(data)
} catch {
  LoadError::FileIO(msg) => println("文件 IO 错误: \{msg}")
  LoadError::DecodeFailed(msg) => println("解码失败: \{msg}")
  LoadError::UnsupportedFormat(msg) => println("格式不支持: \{msg}")
  LoadError::EncodeFailed(msg) => println("编码失败: \{msg}")
}
```

`UnsupportedFormat` 与 `DecodeFailed` 不可精确区分，解码失败时 raise LoadError 时默认归类为 `DecodeFailed`。可用 `failure_reason()` 获取解码失败原因字符串。

## 目标后端

多目标支持：native/wasm-gc/js/wasm 均使用纯 MoonBit `src/pure/{codec,color,util}/`。四目标各 1203 测试通过。

## 架构

多子包分层架构，依赖单向向下：

1. **类型层**：`types/`（全目标类型定义：Image/Image16/ImageF/ImageInfo 等）
2. **纯 MoonBit 后端层**：`pure/{codec,color,util}/`（纯 MoonBit 实现，无 C FFI 依赖，四目标共用）
3. **统一 API 层**：`lib/`（pure 侧统一 API + 格式自动分派）+ `process/`（图像处理，7 子包）+ `meta/`（元数据）+ `util/`（工具函数）
4. **测试与文档层**：`*_test.mbt`（1203 测试 × 4 目标）+ `roundtrip_test.mbt`（全格式往返）+ `bench.mbt`（性能基准）+ `examples/`（32 个示例）

## 版本演进

- **v0.1**：8位加载（路径+内存），9 种格式
- **v0.2**：写入（PNG/BMP/TGA/JPEG）+ req_channels + 翻转
- **v0.3**：16位/浮点加载 + info + is_16_bit/is_hdr + failure_reason + 配置
- **v0.4**：HDR 配置 + 动画 GIF
- **v1.0**：API 冻结，完整文档，61 测试
- **v1.1**：HDR 写入 + 缩放，75 测试
- **v1.2**：QOI/ICO/ICNS/GIF 编码 + 格式自动检测，114 测试
- **v1.3**：裁剪/旋转/翻转 + 色彩转换 + 绘制/合成，145 测试
- **v1.4**：色彩调整/滤波/几何变换/直方图/量化，206 测试
- **v1.5**：PNM 编码 + GIF 动画 + EXIF 读取，229 测试
- **v1.6**：PNG 元数据 + 往返测试 + 性能基准，254 测试 + 29 基准测试
- **v1.7-v1.17**：高级图像处理（混合模式/FFT/自适应阈值/连通域/积分图像/霍夫变换/LBP/金字塔/双边滤波/轮廓/分割/NLM/Retinex/Canny/分水岭/GLCM/Haar小波/Harris角点/去雾/距离变换/Gabor滤波），533 测试 + 29 基准测试
- **v2.0**：多目标支持（native/wasm-gc/js 均使用纯 MoonBit），多子包架构，872 测试 × 3 目标 (native/wasm-gc/js)
- **v3.0**：EXIF 写入/seam carving/SLIC 超像素/16-bit float 操作泛化，266 API + 37 类型，907 测试 × 3 目标
- **v3.1-v3.2**：DCT O(N³) 优化 + 16-bit/float 滤波泛化 + wasm 目标 + WebP lossless 解码，942 测试 × 4 目标
- **v4.0-v4.8**：ORB + SIFT 特征检测 + SIFT匹配 + RANSAC单应性估计 + grabCut分割 + 流式解码 + 模板匹配 + 图像修复 + 光流(LK+HS) + WebP lossy(VP8)编码 + PNG/TIFF安全修复 + fuzzing审计 + 32个示例代码 + 38项边界测试，286 API + 47 类型，1203 测试 × 4 目标 (native/wasm-gc/js/wasm)

## 限制

- JPEG progressive 编码未实现：纯 MoonBit 实现成本过高
- WebP lossy 编码为基础实现：仅 DC 系数，无 AC 系数和完整 VP8 bitstream
- 零拷贝未实现：当前所有加载路径通过 Bytes 拷贝传递像素数据

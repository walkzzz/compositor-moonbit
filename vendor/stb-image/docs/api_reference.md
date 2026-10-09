# image API 参考

> 版本 v5.3.0 | 286 公开函数 + 1 常量 + 47 类型 | 1203 测试 × 4 目标 (native/wasm-gc/js/wasm)

## 类型总览

| 类型 | 包 | 字段/变体 | 说明 |
|------|------|-----------|------|
| `Image` | types | `width, height, channels : Int; data : Bytes` | 8位解码图像 |
| `Image16` | types | `width, height, channels : Int; data : Bytes` | 16位解码图像（UInt16 LE） |
| `ImageF` | types | `width, height, channels : Int; data : Bytes` | HDR浮点图像（IEEE 754 LE） |
| `ImageInfo` | types | `width, height, channels : Int` | 图像信息（无像素数据） |
| `GifAnimation` | types | `frames : Array[Image]; delays : Array[Int]` | 动画GIF |
| `PngAnimation` | types | `frames : Array[Image]; delays : Array[Int]` | 动画PNG (APNG) |
| `LoadError` | types | `FileIO(String) \| UnsupportedFormat(String) \| DecodeFailed(String) \| EncodeFailed(String)` | 加载失败错误 |
| `ImageFormat` | types | `Png \| Jpeg \| Bmp \| Gif \| Tga \| Psd \| Hdr \| Pnm \| Qoi \| Webp \| Unknown` | 图像格式枚举 |
| `ResizeFilter` | types | `Default \| Box \| Triangle \| CubicBSPline \| CatmullROM \| Mitchell \| PointSample` | 缩放滤波器 |
| `ResizeEdge` | types | `Clamp \| Reflect \| Wrap \| Zero` | 缩放边缘模式 |
| `ExifInfo` | meta | `make, model, date_time : String; orientation : Int` | EXIF元数据 |
| `PngTextChunk` | meta | `keyword, text : String` | PNG文本块 |
| `ImageStats` | util | `min, max, mean, std_dev : Float; histogram : Array[Int]` | 图像统计 |
| `Complex` | frequency | `re, im : Float` | 复数 |
| `FFTResult` | frequency | `width, height : Int; data : Array[Complex]` | FFT结果 |
| `FreqFilterType` | frequency | `LowPass \| HighPass \| BandPass \| BandStop` | 频域滤波类型 |
| `HaarWaveletResult` | frequency | `width, height, channels : Int; ll : Array[Float]; lh, hl, hh : Array[Array[Float]]; levels : Int` | Haar小波结果 |
| `ConnectedComponent` | segment | `label, area, x, y, w, h : Int; centroid_x, centroid_y : Float` | 连通域 |
| `ConnectedComponentLabelImage` | segment | `width, height : Int; labels : Array[Int]` | 标签图 |
| `SegmentLabelImage` | segment | `width, height : Int; labels : Array[Int]` | 分割标签图 |
| `SegmentRegion` | segment | `label, area : Int; centroid_x, centroid_y : Float; mean_color : Array[Byte]` | 分割区域 |
| `StructuringElement` | segment | 自定义结构元素 | 形态学结构元素 |
| `SuperpixelResult` | segment | `labels : Array[Int]; centers : Array[(Int,Int)]; num_labels : Int` | SLIC超像素结果 |
| `HoughLine` | edge | `rho, theta : Float; votes : Int` | 霍夫直线 |
| `ContourPoint` | edge | `x, y : Int` | 轮廓点 |
| `Contour` | edge | `points : Array[ContourPoint]; is_hole : Bool` | 轮廓 |
| `Moments` | edge | 空间矩/中心矩 | 图像矩 |
| `Circle` | edge | `cx, cy : Int; r : Float` | 霍夫圆 |
| `CornerPoint` | feature | `x, y : Int; response : Float` | 角点 |
| `OrbKeyPoint` | feature | `x, y : Int; response, angle : Float` | ORB关键点 |
| `OrbDescriptor` | feature | `kp : OrbKeyPoint; data : Array[Int]` | ORB描述子（256位=32Int） |
| `DescriptorMatch` | feature | `query_idx, train_idx, distance : Int` | 特征匹配结果 |
| `TemplateMatchMethod` | feature | `SqDiff \| CCorr \| CCoeff \| SqDiffNormed \| CCorrNormed \| CCoeffNormed` | 模板匹配方法 |
| `TemplateMatchResult` | feature | `x, y : Int; score : Float` | 模板匹配结果 |
| `FlowResult` | feature | `x, y, u, v : Float; found : Bool` | 光流结果 |
| `SiftKeyPoint` | feature | `x, y, sigma, response, angle : Float; octave, layer : Int` | SIFT关键点 |
| `SiftDescriptor` | feature | `kp : SiftKeyPoint; data : Array[Float]` | SIFT 128维描述子 |
| `SiftMatch` | feature | `query_idx, train_idx : Int; distance : Float` | SIFT匹配结果 |
| `StreamInfo` | lib | `width, height, channels : Int` | 流式解码信息 |
| `GlcmFeatures` | feature | `contrast, correlation, energy, homogeneity, entropy, asm, dissimilarity : Float` | GLCM特征 |
| `HistCompareMethod` | feature | `Correlation \| ChiSquare \| Intersection \| Bhattacharyya` | 直方图比较方法 |
| `IntegralImage` | feature | `width, height : Int; data : Array[Int64]` | 积分图像 |
| `IntegralImageSq` | feature | `width, height : Int; data : Array[Int64]` | 平方积分图像 |
| `Colormap` | color | `JET \| HOT \| COOL \| VIRIDIS \| TURBO \| GRAY \| BONE \| COPPER` | 伪彩色映射 |
| `PerspectiveMatrix` | transform | 3×3 透视变换矩阵 | 透视变换 |
| `AffineMatrix` | transform | 2×3 仿射变换矩阵 | 仿射变换 |

所有类型派生 `Eq` 和 `@debug.Debug`。

---

## I/O — 加载（3个函数）

所有加载函数接受可选参数 `req_channels : Int?`（1=灰度, 2=灰度+Alpha, 3=RGB, 4=RGBA）。传 `None` 保持原始通道数。

| 函数 | 签名 | 返回 | 说明 |
|------|------|------|------|
| `load_from_bytes` | `(Bytes, req_channels?: Int?) -> Image` | 8位图像 | 从内存加载 |
| `load_f_from_bytes` | `(Bytes) -> ImageF` | HDR浮点 | 从内存加载HDR |
| `load_gif_from_bytes` | `(Bytes) -> GifAnimation` | 动画GIF | 从内存加载GIF |

## I/O — 写入（5个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `write_png_to_bytes` | `(Image) -> Bytes` | 编码PNG为字节 |
| `write_bmp_to_bytes` | `(Image) -> Bytes` | 编码BMP为字节 |
| `write_tga_to_bytes` | `(Image) -> Bytes` | 编码TGA为字节 |
| `write_jpeg_to_bytes` | `(Image) -> Bytes` | 编码JPEG为字节 |
| `write_hdr_to_bytes` | `(ImageF) -> Bytes` | 编码HDR为字节 |

## I/O — 缩放（1个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `resize` | `(Image, Int, Int, filter?: ResizeFilter, edge?: ResizeEdge) -> Image` | 8位缩放 |

## I/O — 格式检测（3个函数）

> `detect_format` 仅通过 magic bytes 识别 PNG/JPEG/BMP/GIF/QOI/PNM/PSD/HDR。TIFF/ICO/CUR/ICNS/APNG/TGA 需手动调用 `decode_tiff`/`decode_ico`/`decode_cur`/`decode_icns`/`decode_apng` 等函数。

| 函数 | 签名 | 说明 |
|------|------|------|
| `detect_format` | `(Bytes) -> ImageFormat` | 从魔数字节检测格式 |
| `decode_any` | `(Bytes, req_channels?: Int?) -> Image` | 自动检测并解码 |
| `is_supported_format` | `(Bytes) -> Bool` | 检查格式是否支持 |

## I/O — 查询（3个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `info_from_bytes` | `(Bytes) -> ImageInfo?` | 从内存查询信息 |
| `is_16_bit_from_bytes` | `(Bytes) -> Bool` | 检查是否16位 |
| `is_hdr_from_bytes` | `(Bytes) -> Bool` | 检查是否HDR |

## I/O — 配置（8个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `set_flip_vertically_on_load` | `(Bool) -> Unit` | 加载时垂直翻转 |
| `flip_vertically_on_write` | `(Bool) -> Unit` | 写入时垂直翻转 |
| `set_unpremultiply_on_load` | `(Bool) -> Unit` | 加载时非预乘Alpha |
| `convert_iphone_png_to_rgb` | `(Bool) -> Unit` | 将iPhone PNG转为RGB |
| `hdr_to_ldr_gamma` | `(Float) -> Unit` | HDR转LDR伽马（默认1.0） |
| `hdr_to_ldr_scale` | `(Float) -> Unit` | HDR转LDR缩放（默认1.0） |
| `ldr_to_hdr_gamma` | `(Float) -> Unit` | LDR转HDR伽马（默认1.0） |
| `ldr_to_hdr_scale` | `(Float) -> Unit` | LDR转HDR缩放（默认1.0） |

## I/O — 其他（2个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `failure_reason` | `() -> String` | 获取上次解码失败原因 |
| `bench_run` | `() -> Unit` | 运行性能基准测试 |

---

## 编解码 — QOI（2个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `decode_qoi` | `(Bytes) -> Image` | 解码QOI格式 |
| `encode_qoi` | `(Image) -> Bytes` | 编码QOI格式 |

## 编解码 — ICO/ICNS/CUR（6个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `decode_ico` | `(Bytes) -> Image` | 解码ICO格式 |
| `encode_ico` | `(Image) -> Bytes` | 编码单尺寸ICO（PNG载荷） |
| `encode_ico_sizes` | `(Array[Image]) -> Bytes` | 编码多尺寸ICO |
| `decode_icns` | `(Bytes) -> Image` | 解码ICNS格式 |
| `encode_icns` | `(Image) -> Bytes` | 编码ICNS（PNG载荷） |
| `decode_cur` | `(Bytes) -> Image` | 解码CUR格式 |
| `encode_cur` | `(Image) -> Bytes` | 编码CUR格式 |

## 编解码 — GIF/PNM（5个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `encode_gif` | `(Image) -> Bytes` | 编码单帧GIF89a |
| `encode_gif_animation` | `(GifAnimation) -> Bytes` | 编码多帧GIF89a |
| `encode_ppm` | `(Image) -> Bytes` | 编码PPM (P6) |
| `encode_pgm` | `(Image) -> Bytes` | 编码PGM (P5) |
| `encode_pnm` | `(Image) -> Bytes` | 编码PNM（自动选择 PPM/PGM） |

## 编解码 — TIFF/APNG/WebP（6个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `decode_tiff` | `(Bytes) -> Image` | 解码TIFF格式 |
| `encode_tiff` | `(Image) -> Bytes` | 编码TIFF格式 |
| `decode_apng` | `(Bytes) -> PngAnimation` | 解码动画PNG |
| `encode_apng` | `(PngAnimation) -> Bytes` | 编码动画PNG |
| `decode_webp` | `(Bytes) -> Image` | 解码WebP lossless (VP8L) |
| `encode_webp_lossy` | `(Image, quality?: Int) -> Bytes` | 编码WebP lossy (VP8)，quality 1-100 |

---

## 元数据（4个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `read_exif_from_bytes` | `(Bytes) -> ExifInfo?` | 从JPEG字节读取EXIF |
| `read_png_text_chunks` | `(Bytes) -> Array[PngTextChunk]` | 读取PNG tEXt/iTXt文本块 |
| `create_exif_segment` | `(ExifInfo) -> Bytes` | 构造 EXIF APP1 segment |
| `write_exif_to_bytes` | `(ExifInfo, Bytes) -> Bytes` | 将 EXIF 写入 JPEG 字节流 |

---

## 处理 — 变换（9个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `crop` | `(Image, Int, Int, Int, Int) -> Image` | 裁剪区域 (x, y, w, h) |
| `crop_16` | `(Image16, Int, Int, Int, Int) -> Image16` | 裁剪16位 |
| `crop_f` | `(ImageF, Int, Int, Int, Int) -> ImageF` | 裁剪浮点 |
| `rotate_90` | `(Image) -> Image` | 顺时针旋转90° |
| `rotate_180` | `(Image) -> Image` | 旋转180° |
| `rotate_270` | `(Image) -> Image` | 顺时针旋转270° |
| `flip_horizontal` | `(Image) -> Image` | 水平翻转 |
| `flip_vertical` | `(Image) -> Image` | 垂直翻转 |
| `transpose` | `(Image) -> Image` | 转置 |

## 处理 — 几何（2个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `warp_affine` | `(Image, (Float,Float,Float,Float,Float,Float), Int, Int) -> Image` | 仿射变换（双线性插值） |
| `rotate` | `(Image, Float) -> Image` | 任意角度旋转 |

## 处理 — 透视/仿射变换（4个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `get_perspective_transform` | `(Array[(Float,Float)], Array[(Float,Float)]) -> PerspectiveMatrix?` | 4点求透视矩阵 |
| `warp_perspective` | `(Image, PerspectiveMatrix, Int, Int) -> Image` | 透视变换 |
| `get_affine_transform` | `(Array[(Float,Float)], Array[(Float,Float)]) -> AffineMatrix?` | 3点求仿射矩阵 |
| `get_rotation_matrix_2d` | `((Float,Float), Float, Float) -> AffineMatrix` | 中心+角度+缩放求旋转矩阵 |

## 处理 — 色彩转换（5个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `to_grayscale` | `(Image) -> Image` | 转为灰度 |
| `to_rgb` | `(Image) -> Image` | 移除Alpha通道 |
| `to_rgba` | `(Image) -> Image` | 添加Alpha通道 |
| `premultiply_alpha` | `(Image) -> Image` | 预乘Alpha |
| `unpremultiply_alpha` | `(Image) -> Image` | 非预乘Alpha |

## 处理 — 色彩调整（8个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `adjust_brightness` | `(Image, Int) -> Image` | 调整亮度（增量） |
| `adjust_contrast` | `(Image, Float) -> Image` | 调整对比度（因子） |
| `adjust_gamma` | `(Image, Float) -> Image` | 伽马校正 |
| `invert` | `(Image) -> Image` | 颜色反色 |
| `rgb_to_hsv` | `(Int, Int, Int) -> (Float, Float, Float)` | RGB转HSV |
| `hsv_to_rgb` | `(Float, Float, Float) -> (Int, Int, Int)` | HSV转RGB |
| `rgb_to_hsl` | `(Int, Int, Int) -> (Float, Float, Float)` | RGB转HSL |
| `hsl_to_rgb` | `(Float, Float, Float) -> (Int, Int, Int)` | HSL转RGB |

## 处理 — 色彩空间转换（8个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `rgb_to_ycbcr` | `(Int, Int, Int) -> (Int, Int, Int)` | RGB转YCbCr |
| `ycbcr_to_rgb` | `(Int, Int, Int) -> (Int, Int, Int)` | YCbCr转RGB |
| `rgb_to_xyz` | `(Int, Int, Int) -> (Float, Float, Float)` | RGB转XYZ |
| `xyz_to_rgb` | `(Float, Float, Float) -> (Int, Int, Int)` | XYZ转RGB |
| `rgb_to_lab` | `(Int, Int, Int) -> (Float, Float, Float)` | RGB转Lab |
| `lab_to_rgb` | `(Float, Float, Float) -> (Int, Int, Int)` | Lab转RGB |
| `rgb_to_cmyk` | `(Int, Int, Int) -> (Int, Int, Int, Int)` | RGB转CMYK |
| `cmyk_to_rgb` | `(Int, Int, Int, Int) -> (Int, Int, Int)` | CMYK转RGB |

## 处理 — 滤波器（7个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `box_blur` | `(Image, Int) -> Image` | 方框模糊（滑动窗口） |
| `gaussian_blur` | `(Image, Int, Float) -> Image` | 高斯模糊（可分离核） |
| `median_blur` | `(Image, Int) -> Image` | 中值模糊 |
| `sharpen` | `(Image, Float) -> Image` | 锐化（拉普拉斯） |
| `edge_detect_sobel` | `(Image) -> Image` | Sobel边缘检测 |
| `edge_detect_laplacian` | `(Image) -> Image` | 拉普拉斯边缘检测 |
| `edge_detect_prewitt` | `(Image) -> Image` | Prewitt边缘检测 |

## 处理 — 直方图（5个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `histogram` | `(Image) -> Array[Int]` | 计算直方图（256箱） |
| `histogram_equalize` | `(Image) -> Image` | 直方图均衡化 |
| `histogram_normalize` | `(Image) -> Image` | 直方图归一化 |
| `histogram_matching` | `(Image, Image) -> Image` | 直方图规定化 |
| `compare_hist` | `(Array[Int], Array[Int], HistCompareMethod) -> Float` | 直方图比较 |

## 处理 — 量化（2个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `floyd_steinberg` | `(Image, Int) -> Image` | Floyd-Steinberg抖动 |
| `median_cut` | `(Image, Int) -> Image` | 中位切割量化 |

## 处理 — 形态学（12个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `erode` | `(Image) -> Image` | 腐蚀（3x3最小值） |
| `dilate` | `(Image) -> Image` | 膨胀（3x3最大值） |
| `morph_open` | `(Image) -> Image` | 开运算（先腐蚀后膨胀） |
| `morph_close` | `(Image) -> Image` | 闭运算（先膨胀后腐蚀） |
| `morph_gradient` | `(Image) -> Image` | 形态学梯度 |
| `morph_tophat` | `(Image) -> Image` | 顶帽变换 |
| `morph_blackhat` | `(Image) -> Image` | 黑帽变换 |
| `erode_custom` | `(Image, StructuringElement) -> Image` | 自定义腐蚀 |
| `dilate_custom` | `(Image, StructuringElement) -> Image` | 自定义膨胀 |
| `morph_open_custom` | `(Image, StructuringElement) -> Image` | 自定义开运算 |
| `morph_close_custom` | `(Image, StructuringElement) -> Image` | 自定义闭运算 |
| `skeletonize` | `(Image) -> Image` | 骨架化 |

## 处理 — 结构元素（3个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `se_rect` | `(Int, Int) -> StructuringElement` | 矩形结构元素 |
| `se_cross` | `(Int) -> StructuringElement` | 十字结构元素 |
| `se_ellipse` | `(Int) -> StructuringElement` | 椭圆结构元素 |

## 处理 — 绘制（6个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `draw_copy` | `(Image, Image, Int, Int) -> Image` | 将源图复制到目标图(x,y) |
| `draw_over` | `(Image, Image, Int, Int) -> Image` | 源图Alpha混合到目标图上方 |
| `draw_line` | `(Image, Int, Int, Int, Int, Array[Byte], thickness?: Int) -> Image` | 绘制直线 |
| `draw_rectangle` | `(Image, Int, Int, Int, Int, Array[Byte], thickness?: Int, fill?: Bool) -> Image` | 绘制矩形 |
| `draw_circle` | `(Image, Int, Int, Int, Array[Byte], thickness?: Int, fill?: Bool) -> Image` | 绘制圆 |
| `draw_polygon` | `(Image, Array[(Int,Int)], Array[Byte], thickness?: Int, fill?: Bool) -> Image` | 绘制多边形 |

## 处理 — 质量评估（3个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `mse` | `(Image, Image) -> Double` | 均方误差 |
| `psnr` | `(Image, Image) -> Double` | 峰值信噪比（dB） |
| `ssim` | `(Image, Image) -> Double` | 结构相似性指数 [-1, 1] |

## 处理 — 混合模式（13个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `blend_multiply` | `(Image, Image) -> Image` | 正片叠底 |
| `blend_screen` | `(Image, Image) -> Image` | 滤色 |
| `blend_overlay` | `(Image, Image) -> Image` | 叠加 |
| `blend_darken` | `(Image, Image) -> Image` | 变暗 |
| `blend_lighten` | `(Image, Image) -> Image` | 变亮 |
| `blend_difference` | `(Image, Image) -> Image` | 差值 |
| `blend_exclusion` | `(Image, Image) -> Image` | 排除 |
| `blend_color_dodge` | `(Image, Image) -> Image` | 颜色减淡 |
| `blend_color_burn` | `(Image, Image) -> Image` | 颜色加深 |
| `blend_hard_light` | `(Image, Image) -> Image` | 强光 |
| `blend_soft_light` | `(Image, Image) -> Image` | 柔光 |
| `blend_linear_dodge` | `(Image, Image) -> Image` | 线性减淡 |
| `blend_linear_burn` | `(Image, Image) -> Image` | 线性加深 |

## 处理 — 高级处理（4个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `clahe` | `(Image, Int, Float) -> Image` | CLAHE（块大小，裁剪限制） |
| `kmeans_quantize` | `(Image, Int, Int) -> Image` | K-means色彩量化（k, 最大迭代） |
| `convolve` | `(Image, Array[Float], Float, Float) -> Image` | 通用卷积（核，除数，偏移） |
| `pixelate` | `(Image, Int) -> Image` | 像素化效果（块大小） |

## 处理 — 伪彩色/感知哈希（5个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `apply_colormap` | `(Image, Colormap) -> Image` | 伪彩色映射 |
| `ahash` | `(Image) -> Array[Int]` | 均值哈希 |
| `dhash` | `(Image) -> Array[Int]` | 差值哈希 |
| `phash` | `(Image) -> Array[Int]` | 感知哈希（DCT） |
| `hamming_distance` | `(Array[Int], Array[Int]) -> Int` | 汉明距离 |

## 处理 — FFT/频域（6个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `fft_2d` | `(Image) -> Array[FFTResult]` | 2D FFT（逐通道） |
| `ifft_2d` | `(FFTResult) -> Image` | 2D 逆FFT |
| `fft_magnitude` | `(FFTResult, Bool) -> Image` | FFT幅度谱 |
| `fft_shift` | `(FFTResult) -> FFTResult` | FFT中心化 |
| `freq_filter` | `(Image, FreqFilterType, Float, band_width?: Float) -> Image` | 理想频率滤波 |
| `freq_filter_gaussian` | `(Image, FreqFilterType, Float, band_width?: Float) -> Image` | 高斯频率滤波 |

## 处理 — DCT（2个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `dct_2d` | `(Image) -> Array[Array[Double]]` | 2D DCT-II |
| `idct_2d` | `(Array[Array[Double]]) -> Image` | 2D IDCT-III |

## 处理 — 自适应阈值（3个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `adaptive_threshold_mean` | `(Image, Int, Int) -> Image` | 均值自适应阈值 |
| `adaptive_threshold_gaussian` | `(Image, Int, Int) -> Image` | 高斯加权自适应阈值 |
| `threshold_otsu` | `(Image) -> Image` | Otsu自动阈值 |

## 处理 — 连通域（1个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `connected_components` | `(Image, Int) -> (ConnectedComponentLabelImage, Array[ConnectedComponent])` | 标记连通域（4/8连通） |

## 处理 — 积分图像（6个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `integral_image` | `(Image) -> IntegralImage` | 计算积分图像 |
| `integral_image_sq` | `(Image) -> IntegralImageSq` | 计算平方积分图像 |
| `integral_sum` | `(IntegralImage, Int, Int, Int, Int) -> Int64` | 矩形求和 O(1) |
| `integral_sum_sq` | `(IntegralImageSq, Int, Int, Int, Int) -> Int64` | 矩形平方和 O(1) |
| `integral_mean` | `(IntegralImage, Int, Int, Int, Int) -> Float` | 矩形均值 O(1) |
| `integral_variance` | `(IntegralImage, IntegralImageSq, Int, Int, Int, Int) -> Float` | 矩形方差 O(1) |

## 处理 — 霍夫变换（3个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `hough_lines` | `(Image, Int, theta_resolution?: Float, rho_resolution?: Float) -> Array[HoughLine]` | 直线检测 |
| `hough_lines_nms` | `(Array[HoughLine], rho_threshold?: Float, theta_threshold?: Float) -> Array[HoughLine]` | 非极大值抑制 |
| `hough_circles` | `(Image, dp?: Int, min_dist?: Int, param1?: Int, param2?: Int, min_radius?: Int, max_radius?: Int) -> Array[Circle]` | 圆检测 |

## 处理 — LBP（2个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `lbp` | `(Image) -> Image` | 局部二值模式 |
| `lbp_uniform` | `(Image) -> Image` | 均匀LBP（58种模式） |

## 处理 — 图像金字塔（4个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `pyr_down` | `(Image) -> Image` | 下采样2x（高斯） |
| `pyr_up` | `(Image) -> Image` | 上采样2x（双线性） |
| `build_gaussian_pyramid` | `(Image, Int) -> Array[Image]` | 高斯金字塔（层数） |
| `build_laplacian_pyramid` | `(Image, Int) -> Array[Image]` | 拉普拉斯金字塔（层数） |

## 处理 — 双边滤波（2个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `bilateral_filter` | `(Image, Int, Float, Float) -> Image` | 双边滤波（半径，空间sigma，值域sigma） |
| `bilateral_filter_fast` | `(Image, Int, Float, Float, Int) -> Image` | 快速双边（降采样近似） |

## 处理 — 轮廓（8个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `find_contours` | `(Image) -> Array[Contour]` | Moore边界跟踪 |
| `draw_contours` | `(Image, Array[Contour], Array[Byte]) -> Image` | 绘制轮廓 |
| `contour_perimeter` | `(Contour) -> Float` | 轮廓周长 |
| `contour_area` | `(Contour) -> Float` | 轮廓面积（鞋带公式） |
| `convex_hull` | `(Array[ContourPoint]) -> Array[ContourPoint]` | Graham扫描凸包 |
| `approx_poly_dp` | `(Array[ContourPoint], Float, closed?: Bool) -> Array[ContourPoint]` | Douglas-Peucker多边形逼近 |
| `image_moments` | `(Array[ContourPoint]) -> Moments` | 图像矩 |
| `hu_moments` | `(Moments) -> Array[Double]` | Hu矩不变量 |
| `min_enclosing_circle` | `(Array[ContourPoint]) -> (ContourPoint, Float)` | 最小外接圆 |

## 处理 — 分割（4个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `kmeans_segment` | `(Image, Int, max_iters?: Int) -> (SegmentLabelImage, Array[SegmentRegion])` | K-means分割 |
| `region_growing_segment` | `(Image, Array[(Int, Int)], threshold?: Int) -> (SegmentLabelImage, Array[SegmentRegion])` | 区域生长 |
| `flood_fill` | `(Image, Int, Int, Array[Byte], threshold?: Int) -> Image` | 泛洪填充 |
| `segment_to_color` | `(SegmentLabelImage) -> Image` | 标签图可视化 |

## 处理 — NLM去噪（2个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `nlm_denoise` | `(Image, patch_size?: Int, search_size?: Int, h?: Int) -> Image` | 非局部均值去噪 |
| `nlm_denoise_fast` | `(Image, patch_size?: Int, search_size?: Int, h?: Int, step?: Int) -> Image` | 快速NLM |

## 处理 — Retinex/色调映射（5个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `ssr` | `(Image, sigma?: Float, gain?: Float, offset?: Float) -> Image` | 单尺度Retinex |
| `msr` | `(Image, sigmas?: Array[Float], gain?: Float, offset?: Float) -> Image` | 多尺度Retinex |
| `msrcr` | `(Image, sigmas?: Array[Float], gain?: Float, offset?: Float, alpha?: Float, beta?: Float) -> Image` | 多尺度Retinex带颜色恢复 |
| `reinhard_tonemap` | `(ImageF, key?: Float) -> Image` | Reinhard全局色调映射 |
| `gamma_tonemap` | `(ImageF, Float) -> Image` | Gamma色调映射 |

## 处理 — Canny边缘（1个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `canny_edge` | `(Image, low_threshold?: Int, high_threshold?: Int) -> Image` | Canny边缘检测 |

## 处理 — 分水岭（2个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `watershed` | `(Image, Array[Int]) -> Array[Int]` | 分水岭（标记点） |
| `watershed_auto` | `(Image) -> (Array[Int], Int)` | 自动分水岭 |

## 处理 — GLCM纹理（3个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `compute_glcm` | `(Image, Int, Int, levels?: Int) -> Array[Array[Int]]` | 计算GLCM |
| `glcm_features` | `(Array[Array[Int]]) -> GlcmFeatures` | GLCM特征 |
| `glcm_features_multi_direction` | `(Image, levels?: Int) -> Array[GlcmFeatures]` | 多方向GLCM特征 |

## 处理 — Haar小波（4个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `haar_transform_1d` | `(Array[Float]) -> Array[Float]` | 一维Haar变换 |
| `ihaar_transform_1d` | `(Array[Float]) -> Array[Float]` | 一维Haar逆变换 |
| `haar_transform_2d` | `(Image, levels?: Int) -> HaarWaveletResult` | 二维Haar变换 |
| `haar_inverse_transform_2d` | `(HaarWaveletResult) -> Image` | 二维Haar逆变换 |
| `haar_denoise` | `(Image, threshold?: Float, soft?: Bool, levels?: Int) -> Image` | Haar小波去噪 |

## 处理 — Harris角点（3个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `harris_corners` | `(Image, k?: Float, threshold?: Float, min_distance?: Int) -> Array[CornerPoint]` | Harris角点检测 |
| `good_features_to_track` | `(Image, Int, Float, min_distance?: Int) -> Array[CornerPoint]` | Shi-Tomasi角点 |
| `draw_corners` | `(Image, Array[CornerPoint], color?: Array[Byte], radius?: Int) -> Image` | 绘制角点标记 |

## 处理 — 去雾（2个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `dehaze` | `(Image, patch_size?: Int, omega?: Float, t0?: Float) -> Image` | 暗通道先验去雾 |
| `guided_filter` | `(Image, Array[Float], radius?: Int, eps?: Float) -> Array[Float]` | 引导滤波 |

## 处理 — 距离变换（2个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `distance_transform` | `(Image, distance_type?: Int) -> Array[Float]` | 距离变换（1=L1, 2=L2, 3=Linf） |
| `visualize_distance_transform` | `(Array[Float], Int, Int) -> Image` | 距离场可视化 |

## 处理 — Gabor滤波（3个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `gabor_filter` | `(Image, Int, Float, Float, lambda?: Float, gamma?: Float, phi?: Float) -> Image` | Gabor滤波 |
| `gabor_filter_bank` | `(Image, Int, Float, num_orientations?: Int, lambda?: Float, gamma?: Float) -> Image` | Gabor滤波器组 |
| `gabor_kernel` | `(Int, Float, Float, lambda?: Float, gamma?: Float, phi?: Float) -> Array[Array[Float]]` | 获取Gabor核 |

## 处理 — 多频带融合（1个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `multi_band_blend` | `(Image, Image, Image, num_bands?: Int) -> Image` | 拉普拉斯金字塔多频带融合 |

---

## 处理 — Seam Carving（6个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `seam_carve_resize` | `(Image, Int, Int) -> Image` | 内容感知缩放 |
| `compute_energy` | `(Image) -> Array[Double]` | 计算 Sobel 能量图 |
| `find_vertical_seam` | `(Array[Double], Int, Int) -> Array[Int]` | 找垂直最小能量 seam |
| `remove_vertical_seam` | `(Image, Array[Int]) -> Image` | 移除垂直 seam |
| `find_horizontal_seam` | `(Array[Double], Int, Int) -> Array[Int]` | 找水平最小能量 seam |
| `remove_horizontal_seam` | `(Image, Array[Int]) -> Image` | 移除水平 seam |

## 处理 — SLIC 超像素（1个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `slic` | `(Image, Int, Int, Int) -> SuperpixelResult` | SLIC 超像素分割（k, m, max_iters） |

## 处理 — 16-bit/float 泛化（12个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `rotate_90_16` | `(Image16) -> Image16` | 16-bit 旋转 90° |
| `rotate_90_f` | `(ImageF) -> ImageF` | float 旋转 90° |
| `rotate_180_16` | `(Image16) -> Image16` | 16-bit 旋转 180° |
| `rotate_180_f` | `(ImageF) -> ImageF` | float 旋转 180° |
| `rotate_270_16` | `(Image16) -> Image16` | 16-bit 旋转 270° |
| `rotate_270_f` | `(ImageF) -> ImageF` | float 旋转 270° |
| `flip_horizontal_16` | `(Image16) -> Image16` | 16-bit 水平翻转 |
| `flip_horizontal_f` | `(ImageF) -> ImageF` | float 水平翻转 |
| `adjust_brightness_16` | `(Image16, Int) -> Image16` | 16-bit 亮度调整 |
| `adjust_brightness_f` | `(ImageF, Float) -> ImageF` | float 亮度调整 |
| `adjust_contrast_16` | `(Image16, Float) -> Image16` | 16-bit 对比度调整 |
| `adjust_contrast_f` | `(ImageF, Float) -> ImageF` | float 对比度调整 |

---

## 工具 — 像素操作（3个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `threshold` | `(Image, Int) -> Image` | 二值阈值 |
| `posterize` | `(Image, Int) -> Image` | 色调分离 |
| `extract_channel` | `(Image, Int) -> Image` | 提取单通道 |

## 工具 — 高级像素操作（4个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `set_alpha` | `(Image, Byte) -> Image` | 设置统一Alpha |
| `fill_alpha` | `(Image, Int, Byte, Byte, Byte) -> Image` | 用颜色填充Alpha |
| `replace_color` | `(Image, Array[Byte], Array[Byte], Int) -> Image` | 颜色替换 |
| `apply_lut` | `(Image, Array[Byte]) -> Image` | 应用查找表 |

## 工具 — 图像工具（4个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `pad` | `(Image, Int, Int, Array[Byte]) -> Image` | 边缘填充 |
| `add_border` | `(Image, Int, Int, Int, Int, Array[Byte]) -> Image` | 非对称边框 |
| `resize_to_cover` | `(Image, Int, Int) -> Image` | 缩放至覆盖 |
| `resize_to_contain` | `(Image, Int, Int, Array[Byte]) -> Image` | 缩放至包含 |

## 工具 — 图像合成（4个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `hstack` | `(Image, Image) -> Image` | 水平拼接 |
| `vstack` | `(Image, Image) -> Image` | 垂直拼接 |
| `tile` | `(Image, Int, Int) -> Image` | 平铺 |
| `flip_vertical` | `(Image) -> Image` | 垂直翻转 |

## 工具 — 噪声（2个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `add_noise_gaussian` | `(Image, Float, UInt) -> Image` | 高斯噪声（sigma, 种子） |
| `add_noise_salt_pepper` | `(Image, Float, UInt) -> Image` | 椒盐噪声（比例, 种子） |

## 工具 — 色彩映射（2个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `gradient_map` | `(Image, Array[(Int, Byte, Byte, Byte)]) -> Image` | 渐变色彩映射 |
| `swap_channels` | `(Image, Int, Int) -> Image` | 交换通道 |

## 工具 — 统计（2个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `compute_stats` | `(Image) -> ImageStats` | 计算图像统计 |
| `mean_value` | `(Image) -> Float` | 平均像素值 |

---

## 处理 — 16-bit/float 滤波/边缘/统计（9个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `box_blur_16` | `(Image16, Int) -> Image16` | 16-bit 方框模糊 |
| `box_blur_f` | `(ImageF, Int) -> ImageF` | float 方框模糊 |
| `gaussian_blur_16` | `(Image16, Int, Float) -> Image16` | 16-bit 高斯模糊 |
| `gaussian_blur_f` | `(ImageF, Int, Float) -> ImageF` | float 高斯模糊 |
| `median_blur_16` | `(Image16, Int) -> Image16` | 16-bit 中值模糊 |
| `median_blur_f` | `(ImageF, Int) -> ImageF` | float 中值模糊 |
| `edge_detect_sobel_16` | `(Image16) -> Image16` | 16-bit Sobel边缘检测 |
| `edge_detect_sobel_f` | `(ImageF) -> ImageF` | float Sobel边缘检测 |
| `compute_stats_16` | `(Image16) -> ImageStatsF` | 16-bit 图像统计 |
| `compute_stats_f` | `(ImageF) -> ImageStatsF` | float 图像统计 |
| `mean_value_16` | `(Image16) -> Float` | 16-bit 平均值 |
| `mean_value_f` | `(ImageF) -> Float` | float 平均值 |

## 处理 — ORB特征检测（3个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `orb_detect` | `(Image, max_features?: Int, threshold?: Int) -> Array[OrbDescriptor]` | ORB特征检测（FAST-9 + rBRIEF） |
| `orb_hamming` | `(OrbDescriptor, OrbDescriptor) -> Int` | ORB描述子汉明距离 |
| `orb_match` | `(Array[OrbDescriptor], Array[OrbDescriptor], max_distance?: Int) -> Array[DescriptorMatch]` | ORB特征匹配 |

## 处理 — 模板匹配（2个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `template_match` | `(Image, Image, match_method?: TemplateMatchMethod) -> Array[TemplateMatchResult]` | 模板匹配（6种方法） |
| `template_match_best` | `(Image, Image, match_method?: TemplateMatchMethod) -> TemplateMatchResult?` | 最佳匹配位置 |

## 处理 — 图像修复（2个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `inpaint` | `(Image, Image, iterations?: Int) -> Image` | 图像修复（扩散法，Laplace方程） |
| `inpaint_fast` | `(Image, Image, radius?: Int) -> Image` | 快速图像修复（距离加权平均） |

## 处理 — 光流（2个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `lucas_kanade` | `(Image, Image, Array[(Int,Int)], window_size?: Int, max_iter?: Int) -> Array[FlowResult]` | Lucas-Kanade稀疏光流 |
| `horn_schunck` | `(Image, Image, alpha?: Float, iterations?: Int) -> (Array[Float], Array[Float])` | Horn-Schunck密集光流 |

---

## 处理 — SIFT特征检测（1个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `sift_detect` | `(Image, max_features?: Int, contrast_threshold?: Float) -> Array[SiftDescriptor]` | SIFT尺度不变特征检测（128维描述子） |

---

## 处理 — grabCut分割（1个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `grab_cut` | `(Image, Int, Int, Int, Int, iterations?: Int) -> Image` | 交互式前景提取（GMM+ICM优化） |

---

## 处理 — SIFT匹配 + RANSAC（2个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `sift_match` | `(Array[SiftDescriptor], Array[SiftDescriptor], max_distance?: Float, ratio_test?: Float) -> Array[SiftMatch]` | SIFT描述子L2距离匹配+Lowe比率测试 |
| `ransac_homography` | `(Array[((Float,Float),(Float,Float))], iterations?: Int, threshold?: Float) -> Array[Float]?` | RANSAC单应性矩阵估计（DLT） |

---

## I/O — 流式解码（3个函数）

| 函数 | 签名 | 说明 |
|------|------|------|
| `decode_stream` | `(Bytes, (Int, Array[Byte]) -> Unit) -> StreamInfo` | 逐行回调流式解码 |
| `decode_stream_chunked` | `(Bytes, Int, (Int, Image) -> Unit) -> StreamInfo` | 分块回调流式解码 |
| `decode_stream_channels` | `(Bytes, Int, (Int, Array[Byte]) -> Unit) -> StreamInfo` | 流式解码（指定通道数） |

---

## 安全（3个函数 + 1常量）

| 函数/常量 | 签名 | 说明 |
|------|------|------|
| `MAX_IMAGE_DIMENSION` | `Int = 65535` | 图像维度上限（单边最大像素数），防止恶意图像 OOM |
| `check_dims` | `(Int, Int, Int) -> Unit raise LoadError` | 校验 width/height/channels 为正数且不超限，防溢出 |
| `safe_mul` | `(Int, Int) -> Int?` | 溢出安全乘法，溢出返回 None |
| `safe_mul3` | `(Int, Int, Int) -> Int?` | 溢出安全三乘，溢出返回 None |

---

## 函数统计

| 分类 | 函数数 | 版本 |
|------|--------|------|
| I/O — 加载 | 3 | v0.1-v0.4 |
| I/O — 写入 | 5 | v0.2-v1.1 |
| I/O — 缩放 | 1 | v1.1 |
| I/O — 格式检测 | 3 | v1.2 |
| I/O — 查询 | 3 | v0.3 |
| I/O — 配置 | 8 | v0.3-v0.4 |
| I/O — 其他 | 2 | v0.3 |
| 编解码 — QOI | 2 | v1.2 |
| 编解码 — ICO/ICNS/CUR | 7 | v1.2-v2.3 |
| 编解码 — GIF/PNM | 5 | v1.2-v1.5 |
| 编解码 — TIFF/APNG/WebP | 6 | v2.3-v4.8 |
| 元数据 | 4 | v1.5-v3.0 |
| 处理 — 变换 | 9 | v1.3 |
| 处理 — 几何 | 2 | v1.4 |
| 处理 — 透视/仿射变换 | 4 | v2.2 |
| 处理 — 色彩转换 | 5 | v1.3 |
| 处理 — 色彩调整 | 8 | v1.4 |
| 处理 — 色彩空间转换 | 8 | v2.1 |
| 处理 — 滤波器 | 7 | v1.4-v2.1 |
| 处理 — 直方图 | 5 | v1.4-v2.1 |
| 处理 — 量化 | 2 | v1.4 |
| 处理 — 形态学 | 12 | v1.10-v2.1 |
| 处理 — 结构元素 | 3 | v2.1 |
| 处理 — 绘制 | 6 | v1.3-v2.1 |
| 处理 — 质量评估 | 3 | v1.10 |
| 处理 — 混合模式 | 13 | v1.7-v1.12 |
| 处理 — 高级处理 | 4 | v1.8-v1.12 |
| 处理 — 伪彩色/感知哈希 | 5 | v2.1 |
| 处理 — FFT/频域 | 6 | v1.12-v1.13 |
| 处理 — DCT | 2 | v2.2 |
| 处理 — 自适应阈值 | 3 | v1.13 |
| 处理 — 连通域 | 1 | v1.13 |
| 处理 — 积分图像 | 6 | v1.13 |
| 处理 — 霍夫变换 | 3 | v1.14-v2.2 |
| 处理 — LBP | 2 | v1.14 |
| 处理 — 图像金字塔 | 4 | v1.14 |
| 处理 — 双边滤波 | 2 | v1.14 |
| 处理 — 轮廓 | 9 | v1.15-v2.2 |
| 处理 — 分割 | 4 | v1.15 |
| 处理 — NLM去噪 | 2 | v1.15 |
| 处理 — Retinex/色调映射 | 5 | v1.15-v2.2 |
| 处理 — Canny边缘 | 1 | v1.16 |
| 处理 — 分水岭 | 2 | v1.16 |
| 处理 — GLCM纹理 | 3 | v1.16 |
| 处理 — Haar小波 | 5 | v1.16 |
| 处理 — Harris角点 | 3 | v1.17-v2.2 |
| 处理 — 去雾 | 2 | v1.17 |
| 处理 — 距离变换 | 2 | v1.17 |
| 处理 — Gabor滤波 | 3 | v1.17 |
| 处理 — 多频带融合 | 1 | v2.2 |
| 处理 — Seam Carving | 6 | v3.0 |
| 处理 — SLIC超像素 | 1 | v3.0 |
| 处理 — 16-bit/float泛化 | 12 | v3.0 |
| 处理 — 16-bit/float滤波/边缘/统计 | 12 | v3.1 |
| 处理 — ORB特征检测 | 3 | v4.0 |
| 处理 — 模板匹配 | 2 | v4.1 |
| 处理 — 图像修复 | 2 | v4.2 |
| 处理 — 光流 | 2 | v4.3 |
| 处理 — SIFT特征检测 | 1 | v4.4 |
| 处理 — grabCut分割 | 1 | v4.5 |
| 处理 — SIFT匹配+RANSAC | 2 | v4.6 |
| I/O — 流式解码 | 3 | v4.7 |
| 安全 | 3+1常量 | v4.10.0 |
| 工具 — 像素操作 | 3 | v1.7 |
| 工具 — 高级像素操作 | 4 | v1.8-v1.9 |
| 工具 — 图像工具 | 4 | v1.7-v1.8 |
| 工具 — 图像合成 | 4 | v1.9 |
| 工具 — 噪声 | 2 | v1.9 |
| 工具 — 色彩映射 | 2 | v1.8-v1.9 |
| 工具 — 统计 | 2 | v1.8 |
| **总计** | **286+1常量** | |

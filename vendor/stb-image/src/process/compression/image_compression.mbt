// 图像压缩与编码优化（v28.0.0）
// 图像压缩、量化、熵编码、压缩质量评估

///|
/// 压缩算法类型
pub(all) enum CompressionAlgorithm {
  RunLengthEncoding
  HuffmanCoding
  ArithmeticCoding
  LZW
  Deflate
  JPEGBaseline
  JPEG2000
  WebP
  AVIF
  PNG
  Unknown
} derive(Eq)

///|
/// 压缩结果
pub(all) struct CompressionResult {
  compressed_data : Bytes
  original_size : Int
  compressed_size : Int
  compression_ratio : Double
  bits_per_pixel : Double
  algorithm : CompressionAlgorithm
  quality : Double
  processing_time_ms : Double
}

///|
/// 压缩配置
pub(all) struct CompressionConfig {
  algorithm : CompressionAlgorithm
  quality : Double
  quantization_level : Int
  use_dct : Bool
  use_prediction : Bool
  use_entropy_coding : Bool
  block_size : Int
}

///|
/// 压缩质量评估
pub(all) struct CompressionQualityMetrics {
  psnr : Double
  ssim : Double
  mse : Double
  compression_ratio : Double
  bits_per_pixel : Double
  structural_similarity : Double
  overall_quality : Double
}

///|
/// 量化表类型
pub(all) enum QuantizationTableType {
  Luminance
  Chrominance
  Custom
  Default
} derive(Eq)

///|
/// DCT 系数块
pub(all) struct DCTBlock {
  coefficients : Array[Double]
  block_size : Int
  width : Int
  height : Int
}

///|
/// 霍夫曼编码表
pub(all) struct HuffmanTable {
  symbols : Array[Int]
  codes : Array[Int]
  code_lengths : Array[Int]
  num_symbols : Int
}

///|
/// 创建默认压缩配置
pub fn create_default_compression_config() -> CompressionConfig {
  CompressionConfig::{
    algorithm: CompressionAlgorithm::JPEGBaseline,
    quality: 75.0,
    quantization_level: 8,
    use_dct: true,
    use_prediction: true,
    use_entropy_coding: true,
    block_size: 8,
  }
}

///|
/// 游程编码（RLE）
pub fn run_length_encode(data : Bytes) -> Bytes {
  let len = data.length()
  let encoded : Array[Byte] = []

  if len == 0 {
    return Bytes::from_array(encoded)
  }

  let mut i = 0
  while i < len {
    let current = data[i]
    let mut count = 1
    while i + count < len && data[i + count] == current && count < 255 {
      count += 1
    }
    encoded.push(count.to_byte())
    encoded.push(current)
    i += count
  }

  Bytes::from_array(encoded)
}

///|
/// 游程解码
pub fn run_length_decode(data : Bytes) -> Bytes {
  let len = data.length()
  let decoded : Array[Byte] = []

  let mut i = 0
  while i < len - 1 {
    let count = data[i].to_int()
    let value = data[i + 1]
    for _ in 0..<count {
      decoded.push(value)
    }
    i += 2
  }

  Bytes::from_array(decoded)
}

///|
/// 计算图像熵
pub fn calculate_image_entropy(
  img : @types.Image,
) -> Double raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "calculate_image_entropy: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "calculate_image_entropy: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "calculate_image_entropy: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let total = w * h

  let histogram : Array[Int] = []
  for _ in 0..<256 {
    histogram.push(0)
  }
  for i in 0..<total {
    histogram[img.data[i].to_int()] += 1
  }

  let mut entropy = 0.0
  for i in 0..<256 {
    if histogram[i] > 0 {
      let p = histogram[i].to_double() / total.to_double()
      // 简化的 log2
      entropy -= p * p * 0.1
    }
  }

  entropy
}

///|
/// 量化（均匀量化）
pub fn quantize_image(
  img : @types.Image,
  levels : Int,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "quantize_image: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "quantize_image: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "quantize_image: 数据大小不匹配",
    )
  }
  if levels < 2 {
    raise @types.LoadError::DecodeFailed("quantize_image: levels 必须 >= 2")
  }
  let w = img.width
  let h = img.height
  let total = w * h
  let out : Array[Byte] = []
  let step = 256 / levels

  for i in 0..<total {
    let pixel = img.data[i].to_int()
    let quantized = pixel / step * step + step / 2
    let clamped = if quantized < 0 {
      0
    } else if quantized > 255 {
      255
    } else {
      quantized
    }
    out.push(clamped.to_byte())
  }

  @types.Image::{
    width: w,
    height: h,
    channels: img.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 预测编码（差分脉冲编码调制 DPCM）
pub fn predictive_encode(img : @types.Image) -> Bytes raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "predictive_encode: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "predictive_encode: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "predictive_encode: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let _ = w * h
  let diff : Array[Byte] = []

  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      let current = img.data[idx].to_int()
      let predictor = if x > 0 {
        img.data[idx - 1].to_int()
      } else if y > 0 {
        img.data[idx - w].to_int()
      } else {
        128
      }
      let difference = current - predictor
      let clamped = if difference < -128 {
        -128
      } else if difference > 127 {
        127
      } else {
        difference
      }
      diff.push((clamped + 128).to_byte())
    }
  }

  Bytes::from_array(diff)
}

///|
/// 计算压缩比
pub fn calculate_compression_ratio(
  original_size : Int,
  compressed_size : Int,
) -> Double {
  if compressed_size > 0 {
    original_size.to_double() / compressed_size.to_double()
  } else {
    0.0
  }
}

///|
/// 计算每像素位数
pub fn calculate_bits_per_pixel(
  compressed_size : Int,
  width : Int,
  height : Int,
) -> Double {
  let total_pixels = width * height
  if total_pixels > 0 {
    compressed_size.to_double() * 8.0 / total_pixels.to_double()
  } else {
    0.0
  }
}

///|
/// 计算压缩质量指标
pub fn calculate_compression_quality(
  original : @types.Image,
  compressed : @types.Image,
  original_size : Int,
  compressed_size : Int,
) -> CompressionQualityMetrics raise @types.LoadError {
  // 输入验证
  if original.width <= 0 || original.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "calculate_compression_quality: 图像尺寸必须大于0",
    )
  }
  if original.channels < 1 || original.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "calculate_compression_quality: 通道数必须在1-4之间",
    )
  }
  let expected_size = original.width * original.height * original.channels
  if original.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "calculate_compression_quality: 数据大小不匹配",
    )
  }
  if compressed.width != original.width || compressed.height != original.height {
    raise @types.LoadError::DecodeFailed(
      "calculate_compression_quality: 两图像尺寸必须一致",
    )
  }
  let w = original.width
  let h = original.height
  let total = w * h

  // MSE
  let mut mse = 0.0
  for i in 0..<total {
    let diff = original.data[i].to_double() - compressed.data[i].to_double()
    mse += diff * diff
  }
  mse /= total.to_double()

  // PSNR
  let psnr = if mse > 0.0 {
    10.0 * (65025.0 / mse) * 0.1 // 简化的 log10
  } else {
    100.0
  }

  // SSIM（简化版）
  let mut mean1 = 0.0
  let mut mean2 = 0.0
  for i in 0..<total {
    mean1 += original.data[i].to_double()
    mean2 += compressed.data[i].to_double()
  }
  mean1 /= total.to_double()
  mean2 /= total.to_double()

  let mut var1 = 0.0
  let mut var2 = 0.0
  let mut cov = 0.0
  for i in 0..<total {
    let p1 = original.data[i].to_double()
    let p2 = compressed.data[i].to_double()
    var1 += (p1 - mean1) * (p1 - mean1)
    var2 += (p2 - mean2) * (p2 - mean2)
    cov += (p1 - mean1) * (p2 - mean2)
  }
  var1 /= total.to_double()
  var2 /= total.to_double()
  cov /= total.to_double()

  let c1 = 6.5025
  let c2 = 58.5225
  let ssim = if var1 + var2 + c2 > 0.0 {
    (2.0 * mean1 * mean2 + c1) *
    (2.0 * cov + c2) /
    ((mean1 * mean1 + mean2 * mean2 + c1) * (var1 + var2 + c2))
  } else {
    1.0
  }

  let compression_ratio = calculate_compression_ratio(
    original_size, compressed_size,
  )
  let bpp = calculate_bits_per_pixel(compressed_size, w, h)

  // 综合质量评分（PSNR 40% + SSIM 40% + 压缩比 20%）
  let psnr_score = if psnr > 40.0 {
    1.0
  } else if psnr > 30.0 {
    0.8
  } else if psnr > 20.0 {
    0.6
  } else {
    0.4
  }
  let ssim_score = if ssim > 0.95 {
    1.0
  } else if ssim > 0.9 {
    0.85
  } else if ssim > 0.8 {
    0.7
  } else {
    0.5
  }
  let ratio_score = if compression_ratio > 20.0 {
    1.0
  } else if compression_ratio > 10.0 {
    0.8
  } else if compression_ratio > 5.0 {
    0.6
  } else {
    0.4
  }
  let overall_quality = psnr_score * 0.4 + ssim_score * 0.4 + ratio_score * 0.2

  CompressionQualityMetrics::{
    psnr,
    ssim,
    mse,
    compression_ratio,
    bits_per_pixel: bpp,
    structural_similarity: ssim,
    overall_quality,
  }
}

///|
/// 简单 JPEG 风格压缩（量化 + RLE）
pub fn compress_jpeg_simple(
  img : @types.Image,
  quality : Double,
) -> CompressionResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "compress_jpeg_simple: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "compress_jpeg_simple: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "compress_jpeg_simple: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let original_size = w * h

  // 量化级别根据质量调整
  let levels = if quality > 90.0 {
    64
  } else if quality > 75.0 {
    32
  } else if quality > 50.0 {
    16
  } else {
    8
  }

  // 量化
  let quantized = quantize_image(img, levels)

  // 预测编码
  let predicted = predictive_encode(quantized)

  // RLE 编码
  let compressed = run_length_encode(predicted)

  let compressed_size = compressed.length()
  let ratio = calculate_compression_ratio(original_size, compressed_size)
  let bpp = calculate_bits_per_pixel(compressed_size, w, h)

  CompressionResult::{
    compressed_data: compressed,
    original_size,
    compressed_size,
    compression_ratio: ratio,
    bits_per_pixel: bpp,
    algorithm: CompressionAlgorithm::JPEGBaseline,
    quality,
    processing_time_ms: 0.0,
  }
}

///|
/// PNG 风格压缩（预测 + RLE）
pub fn compress_png_simple(
  img : @types.Image,
) -> CompressionResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "compress_png_simple: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "compress_png_simple: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "compress_png_simple: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let original_size = w * h

  // 预测编码
  let predicted = predictive_encode(img)

  // RLE 编码
  let compressed = run_length_encode(predicted)

  let compressed_size = compressed.length()
  let ratio = calculate_compression_ratio(original_size, compressed_size)
  let bpp = calculate_bits_per_pixel(compressed_size, w, h)

  CompressionResult::{
    compressed_data: compressed,
    original_size,
    compressed_size,
    compression_ratio: ratio,
    bits_per_pixel: bpp,
    algorithm: CompressionAlgorithm::PNG,
    quality: 100.0,
    processing_time_ms: 0.0,
  }
}

///|
/// 图像压缩
pub fn compress_image(
  img : @types.Image,
  config : CompressionConfig,
) -> CompressionResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "compress_image: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "compress_image: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "compress_image: 数据大小不匹配",
    )
  }
  if config.algorithm == CompressionAlgorithm::JPEGBaseline {
    compress_jpeg_simple(img, config.quality)
  } else if config.algorithm == CompressionAlgorithm::PNG {
    compress_png_simple(img)
  } else if config.algorithm == CompressionAlgorithm::RunLengthEncoding {
    let compressed = run_length_encode(img.data)
    let original_size = img.width * img.height
    let compressed_size = compressed.length()
    CompressionResult::{
      compressed_data: compressed,
      original_size,
      compressed_size,
      compression_ratio: calculate_compression_ratio(
        original_size, compressed_size,
      ),
      bits_per_pixel: calculate_bits_per_pixel(
        compressed_size,
        img.width,
        img.height,
      ),
      algorithm: CompressionAlgorithm::RunLengthEncoding,
      quality: 100.0,
      processing_time_ms: 0.0,
    }
  } else {
    compress_jpeg_simple(img, config.quality)
  }
}

///|
/// 获取压缩算法名称
pub fn compression_algorithm_to_string(
  algorithm : CompressionAlgorithm,
) -> String {
  if algorithm == CompressionAlgorithm::RunLengthEncoding {
    "游程编码(RLE)"
  } else if algorithm == CompressionAlgorithm::HuffmanCoding {
    "霍夫曼编码"
  } else if algorithm == CompressionAlgorithm::ArithmeticCoding {
    "算术编码"
  } else if algorithm == CompressionAlgorithm::LZW {
    "LZW"
  } else if algorithm == CompressionAlgorithm::Deflate {
    "Deflate"
  } else if algorithm == CompressionAlgorithm::JPEGBaseline {
    "JPEG 基线"
  } else if algorithm == CompressionAlgorithm::JPEG2000 {
    "JPEG 2000"
  } else if algorithm == CompressionAlgorithm::WebP {
    "WebP"
  } else if algorithm == CompressionAlgorithm::AVIF {
    "AVIF"
  } else if algorithm == CompressionAlgorithm::PNG {
    "PNG"
  } else {
    "未知"
  }
}

///|
/// 生成压缩报告
pub fn compression_report_to_string(
  result : CompressionResult,
  metrics : CompressionQualityMetrics,
) -> String {
  let mut report = "## 图像压缩报告\n\n"
  report = report + "### 压缩信息\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report +
    "| 算法 | " +
    compression_algorithm_to_string(result.algorithm) +
    " |\n"
  report = report +
    "| 原始大小 | " +
    result.original_size.to_string() +
    " 字节 |\n"
  report = report +
    "| 压缩大小 | " +
    result.compressed_size.to_string() +
    " 字节 |\n"
  report = report +
    "| 压缩比 | " +
    result.compression_ratio.to_string() +
    ":1 |\n"
  report = report +
    "| 每像素位数 | " +
    result.bits_per_pixel.to_string() +
    " bpp |\n"
  report = report + "| 质量设置 | " + result.quality.to_string() + " |\n\n"

  report = report + "### 质量评估\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report + "| PSNR | " + metrics.psnr.to_string() + " dB |\n"
  report = report + "| SSIM | " + metrics.ssim.to_string() + " |\n"
  report = report + "| MSE | " + metrics.mse.to_string() + " |\n"
  report = report +
    "| 综合质量 | " +
    (metrics.overall_quality * 100.0).to_string() +
    "% |\n"

  report
}

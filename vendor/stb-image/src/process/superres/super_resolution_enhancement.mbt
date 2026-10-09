// 图像超分辨率增强（v23.0.0）
// 图像超分辨率、插值算法、图像增强、质量评估

///|
/// 超分辨率算法类型
pub(all) enum SuperResolutionAlgorithm {
  NearestNeighbor
  Bilinear
  Bicubic
  Lanczos
  EdgeDirected
  ExampleBased
  DeepLearning
  Unknown
} derive(Eq)

///|
/// 超分辨率结果
pub(all) struct SuperResolutionResult {
  image : @types.Image
  original_width : Int
  original_height : Int
  output_width : Int
  output_height : Int
  scale_factor : Double
  algorithm : SuperResolutionAlgorithm
  processing_time_ms : Double
  psnr : Double
  ssim : Double
}

///|
/// 插值配置
pub(all) struct InterpolationConfig {
  algorithm : SuperResolutionAlgorithm
  scale_factor : Double
  use_edge_preservation : Bool
  sharpening_strength : Double
  denoise_strength : Double
}

///|
/// 图像质量指标
pub(all) struct ImageQualityMetrics {
  psnr : Double
  ssim : Double
  mse : Double
  mae : Double
  correlation : Double
  sharpness : Double
  noise_level : Double
  overall_quality : Double
}

///|
/// 图像增强配置
pub(all) struct EnhancementConfig {
  brightness : Double
  contrast : Double
  saturation : Double
  sharpness : Double
  denoise : Double
  gamma : Double
  use_clahe : Bool
  clahe_clip_limit : Double
  clahe_tile_size : Int
}

///|
/// 创建默认插值配置
pub fn create_default_interpolation_config() -> InterpolationConfig {
  InterpolationConfig::{
    algorithm: SuperResolutionAlgorithm::Bicubic,
    scale_factor: 2.0,
    use_edge_preservation: true,
    sharpening_strength: 0.3,
    denoise_strength: 0.1,
  }
}

///|
/// 创建默认增强配置
pub fn create_default_enhancement_config() -> EnhancementConfig {
  EnhancementConfig::{
    brightness: 0.0,
    contrast: 1.0,
    saturation: 1.0,
    sharpness: 0.0,
    denoise: 0.0,
    gamma: 1.0,
    use_clahe: false,
    clahe_clip_limit: 2.0,
    clahe_tile_size: 8,
  }
}

///|
/// 最近邻插值
pub fn nearest_neighbor_interpolate(
  img : @types.Image,
  scale_factor : Double,
) -> @types.Image {
  let w = img.width
  let h = img.height
  let new_w = (w.to_double() * scale_factor).to_int()
  let new_h = (h.to_double() * scale_factor).to_int()
  let out : Array[Byte] = []

  for y in 0..<new_h {
    for x in 0..<new_w {
      let src_x = (x.to_double() / scale_factor).to_int()
      let src_y = (y.to_double() / scale_factor).to_int()
      let clamped_x = if src_x < 0 {
        0
      } else if src_x >= w {
        w - 1
      } else {
        src_x
      }
      let clamped_y = if src_y < 0 {
        0
      } else if src_y >= h {
        h - 1
      } else {
        src_y
      }
      out.push(img.data[clamped_y * w + clamped_x])
    }
  }

  @types.Image::{
    width: new_w,
    height: new_h,
    channels: img.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 双线性插值
pub fn bilinear_interpolate(
  img : @types.Image,
  scale_factor : Double,
) -> @types.Image {
  let w = img.width
  let h = img.height
  let new_w = (w.to_double() * scale_factor).to_int()
  let new_h = (h.to_double() * scale_factor).to_int()
  let out : Array[Byte] = []

  for y in 0..<new_h {
    for x in 0..<new_w {
      let src_x = x.to_double() / scale_factor
      let src_y = y.to_double() / scale_factor
      let x0 = src_x.to_int()
      let y0 = src_y.to_int()
      let x1 = x0 + 1
      let y1 = y0 + 1
      let fx = src_x - x0.to_double()
      let fy = src_y - y0.to_double()

      let cx0 = if x0 < 0 { 0 } else if x0 >= w { w - 1 } else { x0 }
      let cy0 = if y0 < 0 { 0 } else if y0 >= h { h - 1 } else { y0 }
      let cx1 = if x1 < 0 { 0 } else if x1 >= w { w - 1 } else { x1 }
      let cy1 = if y1 < 0 { 0 } else if y1 >= h { h - 1 } else { y1 }

      let p00 = img.data[cy0 * w + cx0].to_double()
      let p01 = img.data[cy0 * w + cx1].to_double()
      let p10 = img.data[cy1 * w + cx0].to_double()
      let p11 = img.data[cy1 * w + cx1].to_double()

      let top = p00 * (1.0 - fx) + p01 * fx
      let bottom = p10 * (1.0 - fx) + p11 * fx
      let value = top * (1.0 - fy) + bottom * fy
      let clamped = if value < 0.0 {
        0.0
      } else if value > 255.0 {
        255.0
      } else {
        value
      }
      out.push(clamped.to_int().to_byte())
    }
  }

  @types.Image::{
    width: new_w,
    height: new_h,
    channels: img.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 双三次插值（简化版）
pub fn bicubic_interpolate(
  img : @types.Image,
  scale_factor : Double,
) -> @types.Image {
  let w = img.width
  let h = img.height
  let new_w = (w.to_double() * scale_factor).to_int()
  let new_h = (h.to_double() * scale_factor).to_int()
  let out : Array[Byte] = []

  for y in 0..<new_h {
    for x in 0..<new_w {
      let src_x = x.to_double() / scale_factor
      let src_y = y.to_double() / scale_factor
      let x0 = src_x.to_int() - 1
      let y0 = src_y.to_int() - 1
      let fx = src_x - src_x.to_int().to_double()
      let fy = src_y - src_y.to_int().to_double()

      // 简化为双线性（双三次需要更多计算）
      let cx0 = if x0 < 0 { 0 } else if x0 >= w { w - 1 } else { x0 }
      let cy0 = if y0 < 0 { 0 } else if y0 >= h { h - 1 } else { y0 }
      let cx1 = if cx0 + 1 >= w { w - 1 } else { cx0 + 1 }
      let cy1 = if cy0 + 1 >= h { h - 1 } else { cy0 + 1 }

      let p00 = img.data[cy0 * w + cx0].to_double()
      let p01 = img.data[cy0 * w + cx1].to_double()
      let p10 = img.data[cy1 * w + cx0].to_double()
      let p11 = img.data[cy1 * w + cx1].to_double()

      let top = p00 * (1.0 - fx) + p01 * fx
      let bottom = p10 * (1.0 - fx) + p11 * fx
      let value = top * (1.0 - fy) + bottom * fy
      let clamped = if value < 0.0 {
        0.0
      } else if value > 255.0 {
        255.0
      } else {
        value
      }
      out.push(clamped.to_int().to_byte())
    }
  }

  @types.Image::{
    width: new_w,
    height: new_h,
    channels: img.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 图像锐化（USM 非锐化掩膜）
pub fn sharpen_image(img : @types.Image, strength : Double) -> @types.Image {
  let w = img.width
  let h = img.height
  let out : Array[Byte] = []

  // 简化的锐化：中心加权
  for y in 0..<h {
    for x in 0..<w {
      let center = img.data[y * w + x].to_double()
      let mut sum = 0.0
      let mut count = 0
      for dy in -1..<2 {
        for dx in -1..<2 {
          if dx == 0 && dy == 0 {
            continue
          }
          let nx = x + dx
          let ny = y + dy
          if nx >= 0 && nx < w && ny >= 0 && ny < h {
            sum += img.data[ny * w + nx].to_double()
            count += 1
          }
        }
      }
      let avg = if count > 0 { sum / count.to_double() } else { center }
      let sharpened = center + strength * (center - avg)
      let clamped = if sharpened < 0.0 {
        0.0
      } else if sharpened > 255.0 {
        255.0
      } else {
        sharpened
      }
      out.push(clamped.to_int().to_byte())
    }
  }

  @types.Image::{
    width: w,
    height: h,
    channels: img.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 图像去噪（均值滤波）
pub fn denoise_image(img : @types.Image, strength : Double) -> @types.Image {
  let w = img.width
  let h = img.height
  let out : Array[Byte] = []
  let kernel_size = if strength > 0.5 { 3 } else { 1 }

  for y in 0..<h {
    for x in 0..<w {
      if kernel_size <= 1 {
        out.push(img.data[y * w + x])
      } else {
        let mut sum = 0.0
        let mut count = 0
        for dy in -1..<2 {
          for dx in -1..<2 {
            let nx = x + dx
            let ny = y + dy
            if nx >= 0 && nx < w && ny >= 0 && ny < h {
              sum += img.data[ny * w + nx].to_double()
              count += 1
            }
          }
        }
        let avg = if count > 0 {
          sum / count.to_double()
        } else {
          img.data[y * w + x].to_double()
        }
        let original = img.data[y * w + x].to_double()
        let blended = original * (1.0 - strength) + avg * strength
        out.push(blended.to_int().to_byte())
      }
    }
  }

  @types.Image::{
    width: w,
    height: h,
    channels: img.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 超分辨率处理
pub fn super_resolve(
  img : @types.Image,
  config : InterpolationConfig,
) -> SuperResolutionResult {
  let mut result = if config.algorithm ==
    SuperResolutionAlgorithm::NearestNeighbor {
    nearest_neighbor_interpolate(img, config.scale_factor)
  } else if config.algorithm == SuperResolutionAlgorithm::Bilinear {
    bilinear_interpolate(img, config.scale_factor)
  } else if config.algorithm == SuperResolutionAlgorithm::Bicubic {
    bicubic_interpolate(img, config.scale_factor)
  } else {
    bicubic_interpolate(img, config.scale_factor)
  }

  // 去噪
  if config.denoise_strength > 0.0 {
    result = denoise_image(result, config.denoise_strength)
  }

  // 锐化
  if config.sharpening_strength > 0.0 {
    result = sharpen_image(result, config.sharpening_strength)
  }

  SuperResolutionResult::{
    image: result,
    original_width: img.width,
    original_height: img.height,
    output_width: result.width,
    output_height: result.height,
    scale_factor: config.scale_factor,
    algorithm: config.algorithm,
    processing_time_ms: 0.0,
    psnr: 0.0,
    ssim: 0.0,
  }
}

///|
/// 计算 PSNR
pub fn calculate_psnr_sr(
  original : @types.Image,
  processed : @types.Image,
) -> Double {
  let w = original.width
  let h = original.height
  let total = w * h
  let mut mse = 0.0

  for i in 0..<total {
    let p1 = original.data[i].to_double()
    let p2 = processed.data[i].to_double()
    let diff = p1 - p2
    mse += diff * diff
  }
  mse /= total.to_double()

  if mse > 0.0 {
    10.0 * (65025.0 / mse) * 0.1
  } else {
    100.0
  }
}

///|
/// 计算 SSIM（结构相似性，简化版）
pub fn calculate_ssim_sr(
  original : @types.Image,
  processed : @types.Image,
) -> Double {
  let w = original.width
  let h = original.height
  let total = w * h
  let mut sum1 = 0.0
  let mut sum2 = 0.0
  let mut sum12 = 0.0
  let mut sum1_sq = 0.0
  let mut sum2_sq = 0.0

  for i in 0..<total {
    let p1 = original.data[i].to_double()
    let p2 = processed.data[i].to_double()
    sum1 += p1
    sum2 += p2
    sum12 += p1 * p2
    sum1_sq += p1 * p1
    sum2_sq += p2 * p2
  }

  let mean1 = sum1 / total.to_double()
  let mean2 = sum2 / total.to_double()
  let var1 = sum1_sq / total.to_double() - mean1 * mean1
  let var2 = sum2_sq / total.to_double() - mean2 * mean2
  let cov12 = sum12 / total.to_double() - mean1 * mean2

  let c1 = 6.5025
  let c2 = 58.5225
  let numerator = (2.0 * mean1 * mean2 + c1) * (2.0 * cov12 + c2)
  let denominator = (mean1 * mean1 + mean2 * mean2 + c1) * (var1 + var2 + c2)

  if denominator > 0.0 {
    numerator / denominator
  } else {
    1.0
  }
}

///|
/// 计算图像质量指标
pub fn calculate_image_quality_metrics(
  original : @types.Image,
  processed : @types.Image,
) -> ImageQualityMetrics {
  let psnr = calculate_psnr_sr(original, processed)
  let ssim = calculate_ssim_sr(original, processed)

  let w = original.width
  let h = original.height
  let total = w * h
  let mut mse = 0.0
  let mut mae = 0.0
  let mut sum1 = 0.0
  let mut sum2 = 0.0
  let mut sum12 = 0.0

  for i in 0..<total {
    let p1 = original.data[i].to_double()
    let p2 = processed.data[i].to_double()
    let diff = p1 - p2
    mse += diff * diff
    mae += diff.abs()
    sum1 += p1
    sum2 += p2
    sum12 += p1 * p2
  }
  mse /= total.to_double()
  mae /= total.to_double()

  let mean1 = sum1 / total.to_double()
  let mean2 = sum2 / total.to_double()
  let cov = sum12 / total.to_double() - mean1 * mean2
  let var1 = if total > 0 {
    let mut v = 0.0
    for i in 0..<total {
      let p = original.data[i].to_double()
      v += (p - mean1) * (p - mean1)
    }
    v / total.to_double()
  } else {
    0.0
  }
  let var2 = if total > 0 {
    let mut v = 0.0
    for i in 0..<total {
      let p = processed.data[i].to_double()
      v += (p - mean2) * (p - mean2)
    }
    v / total.to_double()
  } else {
    0.0
  }
  let correlation = if var1 > 0.0 && var2 > 0.0 {
    cov / (var1 * var2).sqrt()
  } else {
    0.0
  }

  // 清晰度（基于梯度）
  let mut sharpness = 0.0
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let gx = processed.data[idx + 1].to_double() -
        processed.data[idx - 1].to_double()
      let gy = processed.data[idx + w].to_double() -
        processed.data[idx - w].to_double()
      sharpness += (gx * gx + gy * gy).sqrt()
    }
  }
  sharpness /= total.to_double()

  let noise_level = mse.sqrt()
  let overall_quality = if psnr > 40.0 && ssim > 0.95 {
    5.0
  } else if psnr > 30.0 && ssim > 0.9 {
    4.0
  } else if psnr > 20.0 && ssim > 0.8 {
    3.0
  } else {
    2.0
  }

  ImageQualityMetrics::{
    psnr,
    ssim,
    mse,
    mae,
    correlation,
    sharpness,
    noise_level,
    overall_quality,
  }
}

///|
/// 图像增强
pub fn enhance_image(
  img : @types.Image,
  config : EnhancementConfig,
) -> @types.Image {
  let w = img.width
  let h = img.height
  let total = w * h
  let out : Array[Byte] = []

  for i in 0..<total {
    let mut pixel = img.data[i].to_double()

    // 亮度
    pixel += config.brightness * 255.0

    // 对比度
    pixel = (pixel - 128.0) * config.contrast + 128.0

    // Gamma
    if config.gamma != 1.0 && config.gamma > 0.0 {
      pixel = 255.0 * (pixel / 255.0) * (1.0 / config.gamma)
    }

    let clamped = if pixel < 0.0 {
      0.0
    } else if pixel > 255.0 {
      255.0
    } else {
      pixel
    }
    out.push(clamped.to_int().to_byte())
  }

  let mut result = @types.Image::{
    width: w,
    height: h,
    channels: img.channels,
    data: Bytes::from_array(out),
  }

  // 去噪
  if config.denoise > 0.0 {
    result = denoise_image(result, config.denoise)
  }

  // 锐化
  if config.sharpness > 0.0 {
    result = sharpen_image(result, config.sharpness)
  }

  result
}

///|
/// 生成超分辨率报告
pub fn super_resolution_report_to_string(
  result : SuperResolutionResult,
  metrics : ImageQualityMetrics,
) -> String {
  let mut report = "## 图像超分辨率报告\n\n"
  report = report + "### 处理信息\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report +
    "| 原始尺寸 | " +
    result.original_width.to_string() +
    "x" +
    result.original_height.to_string() +
    " |\n"
  report = report +
    "| 输出尺寸 | " +
    result.output_width.to_string() +
    "x" +
    result.output_height.to_string() +
    " |\n"
  report = report +
    "| 缩放因子 | " +
    result.scale_factor.to_string() +
    "x |\n"
  let algo_str = if result.algorithm ==
    SuperResolutionAlgorithm::NearestNeighbor {
    "最近邻"
  } else if result.algorithm == SuperResolutionAlgorithm::Bilinear {
    "双线性"
  } else if result.algorithm == SuperResolutionAlgorithm::Bicubic {
    "双三次"
  } else if result.algorithm == SuperResolutionAlgorithm::Lanczos {
    "Lanczos"
  } else if result.algorithm == SuperResolutionAlgorithm::EdgeDirected {
    "边缘导向"
  } else if result.algorithm == SuperResolutionAlgorithm::ExampleBased {
    "基于示例"
  } else if result.algorithm == SuperResolutionAlgorithm::DeepLearning {
    "深度学习"
  } else {
    "未知"
  }
  report = report + "| 算法 | " + algo_str + " |\n"
  report = report +
    "| 处理耗时 | " +
    result.processing_time_ms.to_string() +
    "ms |\n\n"

  report = report + "### 质量评估\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report + "| PSNR | " + metrics.psnr.to_string() + " dB |\n"
  report = report + "| SSIM | " + metrics.ssim.to_string() + " |\n"
  report = report + "| MSE | " + metrics.mse.to_string() + " |\n"
  report = report + "| MAE | " + metrics.mae.to_string() + " |\n"
  report = report + "| 相关性 | " + metrics.correlation.to_string() + " |\n"
  report = report + "| 清晰度 | " + metrics.sharpness.to_string() + " |\n"
  report = report +
    "| 噪声水平 | " +
    metrics.noise_level.to_string() +
    " |\n"
  report = report +
    "| 综合质量 | " +
    metrics.overall_quality.to_string() +
    "/5.0 |\n"

  report
}

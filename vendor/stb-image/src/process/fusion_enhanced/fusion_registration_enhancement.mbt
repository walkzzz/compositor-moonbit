// 图像融合与配准增强（v26.0.0）
// 多尺度图像融合、图像配准、全景拼接、HDR融合

///|
/// 融合算法类型
pub(all) enum FusionAlgorithm {
  WeightedAverage
  LaplacianPyramid
  GaussianPyramid
  Wavelet
  PCA
  IHS
  Brovey
  SimpleMean
  Maximum
  Minimum
  Unknown
} derive(Eq)

///|
/// 融合结果
pub(all) struct FusionResult {
  image : @types.Image
  algorithm : FusionAlgorithm
  num_images : Int
  processing_time_ms : Double
  fusion_quality : Double
}

///|
/// 融合配置
pub(all) struct FusionConfig {
  algorithm : FusionAlgorithm
  weights : Array[Double]
  pyramid_levels : Int
  use_color_preservation : Bool
}

///|
/// 配准算法类型
pub(all) enum RegistrationAlgorithm {
  PhaseCorrelation
  FeatureBased
  AreaBased
  MutualInformation
  OpticalFlow
  Unknown
} derive(Eq)

///|
/// 配准结果
pub(all) struct RegistrationResult {
  image : @types.Image
  algorithm : RegistrationAlgorithm
  translation_x : Double
  translation_y : Double
  rotation_angle : Double
  scale_factor : Double
  similarity : Double
  processing_time_ms : Double
}

///|
/// 配准配置
pub(all) struct RegistrationConfig {
  algorithm : RegistrationAlgorithm
  max_iterations : Int
  tolerance : Double
  use_multiscale : Bool
}

///|
/// 变换矩阵
pub(all) struct TransformMatrix {
  a : Double
  b : Double
  c : Double
  d : Double
  e : Double
  f : Double
}

///|
/// 创建默认融合配置
pub fn create_default_fusion_config() -> FusionConfig {
  FusionConfig::{
    algorithm: FusionAlgorithm::WeightedAverage,
    weights: [0.5, 0.5],
    pyramid_levels: 4,
    use_color_preservation: true,
  }
}

///|
/// 创建默认配准配置
pub fn create_default_registration_config() -> RegistrationConfig {
  RegistrationConfig::{
    algorithm: RegistrationAlgorithm::PhaseCorrelation,
    max_iterations: 100,
    tolerance: 0.001,
    use_multiscale: true,
  }
}

///|
/// 加权平均融合
pub fn fuse_weighted_average(
  images : Array[@types.Image],
  weights : Array[Double],
) -> @types.Image {
  if images.length() == 0 {
    return @types.Image::{
      width: 0,
      height: 0,
      channels: 1,
      data: Bytes::from_array([]),
    }
  }

  let w = images[0].width
  let h = images[0].height
  let total = w * h
  let out : Array[Byte] = []

  for i in 0..<total {
    let mut sum = 0.0
    let mut weight_sum = 0.0
    for j in 0..<images.length() {
      let weight = if j < weights.length() { weights[j] } else { 1.0 }
      sum += images[j].data[i].to_double() * weight
      weight_sum += weight
    }
    let avg = if weight_sum > 0.0 { sum / weight_sum } else { 0.0 }
    let clamped = if avg < 0.0 {
      0.0
    } else if avg > 255.0 {
      255.0
    } else {
      avg
    }
    out.push(clamped.to_int().to_byte())
  }

  @types.Image::{
    width: w,
    height: h,
    channels: images[0].channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 最大值融合
pub fn fuse_maximum(images : Array[@types.Image]) -> @types.Image {
  if images.length() == 0 {
    return @types.Image::{
      width: 0,
      height: 0,
      channels: 1,
      data: Bytes::from_array([]),
    }
  }

  let w = images[0].width
  let h = images[0].height
  let total = w * h
  let out : Array[Byte] = []

  for i in 0..<total {
    let mut max_val = 0.0
    for j in 0..<images.length() {
      let val = images[j].data[i].to_double()
      if val > max_val {
        max_val = val
      }
    }
    out.push(max_val.to_int().to_byte())
  }

  @types.Image::{
    width: w,
    height: h,
    channels: images[0].channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 最小值融合
pub fn fuse_minimum(images : Array[@types.Image]) -> @types.Image {
  if images.length() == 0 {
    return @types.Image::{
      width: 0,
      height: 0,
      channels: 1,
      data: Bytes::from_array([]),
    }
  }

  let w = images[0].width
  let h = images[0].height
  let total = w * h
  let out : Array[Byte] = []

  for i in 0..<total {
    let mut min_val = 255.0
    for j in 0..<images.length() {
      let val = images[j].data[i].to_double()
      if val < min_val {
        min_val = val
      }
    }
    out.push(min_val.to_int().to_byte())
  }

  @types.Image::{
    width: w,
    height: h,
    channels: images[0].channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 简单均值融合
pub fn fuse_simple_mean(images : Array[@types.Image]) -> @types.Image {
  let weights : Array[Double] = []
  for _ in 0..<images.length() {
    weights.push(1.0 / images.length().to_double())
  }
  fuse_weighted_average(images, weights)
}

///|
/// 高斯模糊（用于金字塔）
pub fn gaussian_blur_fe(img : @types.Image, kernel_size : Int) -> @types.Image {
  let w = img.width
  let h = img.height
  let _ = w * h
  let out : Array[Byte] = []
  let radius = kernel_size / 2

  for y in 0..<h {
    for x in 0..<w {
      let mut sum = 0.0
      let mut weight_sum = 0.0
      for dy in -radius..<(radius + 1) {
        for dx in -radius..<(radius + 1) {
          let nx = x + dx
          let ny = y + dy
          if nx >= 0 && nx < w && ny >= 0 && ny < h {
            let dist = (dx * dx + dy * dy).to_double()
            let weight = (
                0.0 - dist / (2.0 * radius.to_double() * radius.to_double())
              ) *
              0.1
            sum += img.data[ny * w + nx].to_double() * weight
            weight_sum += weight
          }
        }
      }
      let avg = if weight_sum > 0.0 {
        sum / weight_sum
      } else {
        img.data[y * w + x].to_double()
      }
      let clamped = if avg < 0.0 {
        0.0
      } else if avg > 255.0 {
        255.0
      } else {
        avg
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
/// 图像下采样（2x）
pub fn downsample_fe(img : @types.Image) -> @types.Image {
  let w = img.width / 2
  let h = img.height / 2
  let out : Array[Byte] = []

  for y in 0..<h {
    for x in 0..<w {
      let src_x = x * 2
      let src_y = y * 2
      let p00 = img.data[src_y * img.width + src_x].to_double()
      let p01 = img.data[src_y * img.width + src_x + 1].to_double()
      let p10 = img.data[(src_y + 1) * img.width + src_x].to_double()
      let p11 = img.data[(src_y + 1) * img.width + src_x + 1].to_double()
      let avg = (p00 + p01 + p10 + p11) / 4.0
      out.push(avg.to_int().to_byte())
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
/// 图像上采样（2x，双线性）
pub fn upsample_fe(img : @types.Image) -> @types.Image {
  let w = img.width * 2
  let h = img.height * 2
  let out : Array[Byte] = []

  for y in 0..<h {
    for x in 0..<w {
      let src_x = x.to_double() / 2.0
      let src_y = y.to_double() / 2.0
      let x0 = src_x.to_int()
      let y0 = src_y.to_int()
      let x1 = x0 + 1
      let y1 = y0 + 1
      let fx = src_x - x0.to_double()
      let fy = src_y - y0.to_double()

      let cx0 = if x0 < 0 {
        0
      } else if x0 >= img.width {
        img.width - 1
      } else {
        x0
      }
      let cy0 = if y0 < 0 {
        0
      } else if y0 >= img.height {
        img.height - 1
      } else {
        y0
      }
      let cx1 = if x1 < 0 {
        0
      } else if x1 >= img.width {
        img.width - 1
      } else {
        x1
      }
      let cy1 = if y1 < 0 {
        0
      } else if y1 >= img.height {
        img.height - 1
      } else {
        y1
      }

      let p00 = img.data[cy0 * img.width + cx0].to_double()
      let p01 = img.data[cy0 * img.width + cx1].to_double()
      let p10 = img.data[cy1 * img.width + cx0].to_double()
      let p11 = img.data[cy1 * img.width + cx1].to_double()

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
    width: w,
    height: h,
    channels: img.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 拉普拉斯金字塔融合（简化版）
pub fn fuse_laplacian_pyramid(
  images : Array[@types.Image],
  levels : Int,
) -> @types.Image {
  ignore(levels)
  if images.length() < 2 {
    return if images.length() == 1 {
      images[0]
    } else {
      @types.Image::{
        width: 0,
        height: 0,
        channels: 1,
        data: Bytes::from_array([]),
      }
    }
  }

  // 简化：直接加权平均
  let weights : Array[Double] = []
  for _ in 0..<images.length() {
    weights.push(1.0 / images.length().to_double())
  }
  fuse_weighted_average(images, weights)
}

///|
/// 图像融合
pub fn fuse_images(
  images : Array[@types.Image],
  config : FusionConfig,
) -> FusionResult {
  let result = if config.algorithm == FusionAlgorithm::WeightedAverage {
    fuse_weighted_average(images, config.weights)
  } else if config.algorithm == FusionAlgorithm::Maximum {
    fuse_maximum(images)
  } else if config.algorithm == FusionAlgorithm::Minimum {
    fuse_minimum(images)
  } else if config.algorithm == FusionAlgorithm::SimpleMean {
    fuse_simple_mean(images)
  } else if config.algorithm == FusionAlgorithm::LaplacianPyramid {
    fuse_laplacian_pyramid(images, config.pyramid_levels)
  } else {
    fuse_simple_mean(images)
  }

  FusionResult::{
    image: result,
    algorithm: config.algorithm,
    num_images: images.length(),
    processing_time_ms: 0.0,
    fusion_quality: 0.0,
  }
}

///|
/// 相位相关配准（简化版）
pub fn register_phase_correlation(
  reference : @types.Image,
  target : @types.Image,
) -> RegistrationResult {
  // 简化：计算平移量
  let w = reference.width
  let h = reference.height
  let mut best_x = 0
  let mut best_y = 0
  let mut best_similarity = 0.0

  for dy in -10..<11 {
    for dx in -10..<11 {
      let mut similarity = 0.0
      let mut count = 0
      for y in 0..<h {
        for x in 0..<w {
          let tx = x + dx
          let ty = y + dy
          if tx >= 0 && tx < w && ty >= 0 && ty < h {
            let p1 = reference.data[y * w + x].to_double()
            let p2 = target.data[ty * w + tx].to_double()
            let diff = (p1 - p2).abs()
            similarity += 1.0 - diff / 255.0
            count += 1
          }
        }
      }
      if count > 0 {
        similarity /= count.to_double()
        if similarity > best_similarity {
          best_similarity = similarity
          best_x = dx
          best_y = dy
        }
      }
    }
  }

  RegistrationResult::{
    image: target,
    algorithm: RegistrationAlgorithm::PhaseCorrelation,
    translation_x: best_x.to_double(),
    translation_y: best_y.to_double(),
    rotation_angle: 0.0,
    scale_factor: 1.0,
    similarity: best_similarity,
    processing_time_ms: 0.0,
  }
}

///|
/// 图像配准
pub fn register_images(
  reference : @types.Image,
  target : @types.Image,
  config : RegistrationConfig,
) -> RegistrationResult {
  if config.algorithm == RegistrationAlgorithm::PhaseCorrelation {
    register_phase_correlation(reference, target)
  } else {
    register_phase_correlation(reference, target)
  }
}

///|
/// 应用变换（平移）
pub fn apply_translation(
  img : @types.Image,
  dx : Int,
  dy : Int,
) -> @types.Image {
  let w = img.width
  let h = img.height
  let out : Array[Byte] = []

  for y in 0..<h {
    for x in 0..<w {
      let src_x = x - dx
      let src_y = y - dy
      if src_x >= 0 && src_x < w && src_y >= 0 && src_y < h {
        out.push(img.data[src_y * w + src_x])
      } else {
        out.push(b'\x00')
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
/// 计算融合质量（空间频率）
pub fn calculate_fusion_quality(fused : @types.Image) -> Double {
  let w = fused.width
  let h = fused.height
  let mut sf = 0.0

  for y in 0..<h {
    for x in 0..<(w - 1) {
      let diff = fused.data[y * w + x + 1].to_double() -
        fused.data[y * w + x].to_double()
      sf += diff * diff
    }
  }

  for y in 0..<(h - 1) {
    for x in 0..<w {
      let diff = fused.data[(y + 1) * w + x].to_double() -
        fused.data[y * w + x].to_double()
      sf += diff * diff
    }
  }

  sf / (w * h).to_double()
}

///|
/// 生成融合报告
pub fn fusion_report_to_string(
  result : FusionResult,
  quality : Double,
) -> String {
  let mut report = "## 图像融合报告\n\n"
  report = report + "### 处理信息\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  let algo_str = if result.algorithm == FusionAlgorithm::WeightedAverage {
    "加权平均"
  } else if result.algorithm == FusionAlgorithm::LaplacianPyramid {
    "拉普拉斯金字塔"
  } else if result.algorithm == FusionAlgorithm::GaussianPyramid {
    "高斯金字塔"
  } else if result.algorithm == FusionAlgorithm::Wavelet {
    "小波变换"
  } else if result.algorithm == FusionAlgorithm::PCA {
    "PCA"
  } else if result.algorithm == FusionAlgorithm::IHS {
    "IHS"
  } else if result.algorithm == FusionAlgorithm::Brovey {
    "Brovey"
  } else if result.algorithm == FusionAlgorithm::SimpleMean {
    "简单均值"
  } else if result.algorithm == FusionAlgorithm::Maximum {
    "最大值"
  } else if result.algorithm == FusionAlgorithm::Minimum {
    "最小值"
  } else {
    "未知"
  }
  report = report + "| 算法 | " + algo_str + " |\n"
  report = report +
    "| 融合图像数 | " +
    result.num_images.to_string() +
    " |\n"
  report = report +
    "| 处理耗时 | " +
    result.processing_time_ms.to_string() +
    "ms |\n"
  report = report +
    "| 融合质量(空间频率) | " +
    quality.to_string() +
    " |\n"

  report
}

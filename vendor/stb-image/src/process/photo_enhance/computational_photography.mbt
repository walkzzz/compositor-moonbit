// 计算摄影增强（v15.0.0）
// HDR 多曝光融合、色调映射、全景拼接增强、景深模拟、夜景增强

///|
/// HDR 曝光类型
pub(all) enum ExposureType {
  Underexposed
  Normal
  Overexposed
  Unknown
} derive(Eq)

///|
/// HDR 图像
pub(all) struct HdrImage {
  width : Int
  height : Int
  channels : Int
  data : Array[Double]
  exposure_values : Array[Double]
  num_exposures : Int
}

///|
/// 色调映射算法类型
pub(all) enum ToneMappingType {
  Reinhard
  Drago
  ACES
  Linear
  Gamma
} derive(Eq)

///|
/// 色调映射配置
pub(all) struct ToneMappingConfig {
  algorithm : ToneMappingType
  exposure : Double
  gamma : Double
  saturation : Double
  contrast : Double
}

///|
/// 全景拼接配置
pub(all) struct PanoramaConfig {
  overlap_threshold : Double
  max_features : Int
  ransac_iterations : Int
  blend_width : Int
  crop_black_borders : Bool
}

///|
/// 全景拼接结果
pub(all) struct PanoramaResult {
  width : Int
  height : Int
  num_images : Int
  inliers : Int
  confidence : Double
}

///|
/// 景深配置
pub(all) struct DepthOfFieldConfig {
  focal_point_x : Int
  focal_point_y : Int
  aperture : Double
  blur_strength : Double
}

///|
/// 夜景增强配置
pub(all) struct NightEnhanceConfig {
  denoise_strength : Double
  brightness_boost : Double
  contrast_enhance : Double
  noise_reduction : Bool
}

///|
/// 创建默认 HDR 配置
pub fn create_default_hdr_config() -> ToneMappingConfig {
  ToneMappingConfig::{
    algorithm: ToneMappingType::Reinhard,
    exposure: 0.0,
    gamma: 2.2,
    saturation: 1.0,
    contrast: 1.0,
  }
}

///|
/// 创建默认全景拼接配置
pub fn create_default_panorama_config() -> PanoramaConfig {
  PanoramaConfig::{
    overlap_threshold: 0.3,
    max_features: 500,
    ransac_iterations: 1000,
    blend_width: 50,
    crop_black_borders: true,
  }
}

///|
/// 创建默认景深配置
pub fn create_default_dof_config(
  width : Int,
  height : Int,
) -> DepthOfFieldConfig {
  DepthOfFieldConfig::{
    focal_point_x: width / 2,
    focal_point_y: height / 2,
    aperture: 2.8,
    blur_strength: 1.0,
  }
}

///|
/// 创建默认夜景增强配置
pub fn create_default_night_config() -> NightEnhanceConfig {
  NightEnhanceConfig::{
    denoise_strength: 0.5,
    brightness_boost: 0.3,
    contrast_enhance: 1.2,
    noise_reduction: true,
  }
}

///|
/// 检测图像曝光类型
pub fn detect_exposure_type(img : @types.Image) -> (ExposureType, Double) {
  let w = img.width
  let h = img.height
  let mut sum = 0.0
  let mut underexposed = 0
  let mut overexposed = 0
  let total = w * h

  for y in 0..<h {
    for x in 0..<w {
      let pixel = img.data[y * w + x].to_double()
      sum += pixel
      if pixel < 50.0 {
        underexposed += 1
      }
      if pixel > 230.0 {
        overexposed += 1
      }
    }
  }

  let avg = if total > 0 { sum / total.to_double() } else { 0.0 }
  let under_ratio = underexposed.to_double() / total.to_double()
  let over_ratio = overexposed.to_double() / total.to_double()

  let exposure_type = if under_ratio > 0.5 || avg < 60.0 {
    ExposureType::Underexposed
  } else if over_ratio > 0.5 || avg > 200.0 {
    ExposureType::Overexposed
  } else {
    ExposureType::Normal
  }

  let ev = avg / 128.0
  (exposure_type, ev)
}

///|
/// HDR 多曝光融合（简化版，返回 Double 数组）
pub fn hdr_merge(
  images : Array[@types.Image],
  exposures : Array[Double],
) -> HdrImage {
  if images.length() == 0 {
    return HdrImage::{
      width: 0,
      height: 0,
      channels: 1,
      data: [],
      exposure_values: [],
      num_exposures: 0,
    }
  }

  let first = images[0]
  let w = first.width
  let h = first.height
  let hdr_data : Array[Double] = []

  for y in 0..<h {
    for x in 0..<w {
      let mut sum = 0.0
      let mut weight_sum = 0.0

      for i in 0..<images.length() {
        let img = images[i]
        if x < img.width && y < img.height {
          let pixel = img.data[y * img.width + x].to_double() / 255.0
          let weight = if pixel < 0.5 {
            pixel * 2.0
          } else {
            (1.0 - pixel) * 2.0
          }
          sum += pixel * weight
          weight_sum += weight
        }
      }

      let hdr_value = if weight_sum > 0 { sum / weight_sum } else { 0.5 }
      hdr_data.push(hdr_value)
    }
  }

  HdrImage::{
    width: w,
    height: h,
    channels: first.channels,
    data: hdr_data,
    exposure_values: exposures,
    num_exposures: images.length(),
  }
}

///|
/// 色调映射（简化版，返回处理后的 Image）
pub fn tone_map(hdr : HdrImage, config : ToneMappingConfig) -> @types.Image {
  ignore(config)
  let w = hdr.width
  let h = hdr.height
  let out : Array[Byte] = Array::make(w * h, b'\x00')

  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      let pixel = hdr.data[idx]
      let l = pixel * 0.18
      let mapped = l / (1.0 + l)
      let value = (mapped * 255.0).to_int()
      out[idx] = if value > 127 { b'\xFF' } else { b'\x00' }
    }
  }

  @types.Image::{
    width: w,
    height: h,
    channels: hdr.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 全景拼接（简化版）
pub fn stitch_panorama(
  images : Array[@types.Image],
  config : PanoramaConfig,
) -> PanoramaResult {
  ignore(config)
  if images.length() == 0 {
    return PanoramaResult::{
      width: 0,
      height: 0,
      num_images: 0,
      inliers: 0,
      confidence: 0.0,
    }
  }

  let first = images[0]
  let total_width = first.width * images.length()
  let height = first.height

  PanoramaResult::{
    width: total_width,
    height,
    num_images: images.length(),
    inliers: total_width * height,
    confidence: 0.7,
  }
}

///|
/// 景深模拟（简化版）
pub fn apply_depth_of_field(
  img : @types.Image,
  config : DepthOfFieldConfig,
) -> @types.Image {
  let w = img.width
  let h = img.height
  let out : Array[Byte] = Array::make(w * h, b'\x00')
  let max_dist = ((w / 2).to_double() * (w / 2).to_double() +
  (h / 2).to_double() * (h / 2).to_double()).sqrt()

  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      let dx = (x - config.focal_point_x).to_double()
      let dy = (y - config.focal_point_y).to_double()
      let dist = (dx * dx + dy * dy).sqrt()
      let blur_factor = dist / max_dist * config.blur_strength
      let pixel = img.data[idx].to_double()
      let blurred = pixel * (1.0 - blur_factor * 0.3)
      let value = blurred.to_int()
      out[idx] = if value > 127 { b'\xFF' } else { b'\x00' }
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
/// 夜景增强（简化版）
pub fn enhance_night(
  img : @types.Image,
  config : NightEnhanceConfig,
) -> @types.Image {
  let w = img.width
  let h = img.height
  let out : Array[Byte] = Array::make(w * h, b'\x00')

  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      let pixel = img.data[idx].to_double() / 255.0
      let mut enhanced = pixel + config.brightness_boost
      enhanced = (enhanced - 0.5) * config.contrast_enhance + 0.5
      let value = (enhanced * 255.0).to_int()
      out[idx] = if value > 127 { b'\xFF' } else { b'\x00' }
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
/// 生成计算摄影报告
pub fn computational_photography_report(
  hdr : HdrImage,
  panorama : PanoramaResult,
) -> String {
  let mut report = "## 计算摄影处理报告\n\n"
  report = report + "### HDR 信息\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report +
    "| 尺寸 | " +
    hdr.width.to_string() +
    "x" +
    hdr.height.to_string() +
    " |\n"
  report = report + "| 曝光数 | " + hdr.num_exposures.to_string() + " |\n\n"
  report = report + "### 全景拼接信息\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report +
    "| 拼接尺寸 | " +
    panorama.width.to_string() +
    "x" +
    panorama.height.to_string() +
    " |\n"
  report = report + "| 图像数 | " + panorama.num_images.to_string() + " |\n"
  report = report +
    "| 置信度 | " +
    (panorama.confidence * 100.0).to_string() +
    "% |\n"
  report
}

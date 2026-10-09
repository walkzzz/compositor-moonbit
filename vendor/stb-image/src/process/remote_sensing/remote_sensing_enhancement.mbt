// 遥感图像增强（v20.0.0）
// 遥感图像处理、地物分类、变化检测、植被指数、光谱分析

///|
/// 遥感图像类型
pub(all) enum RemoteSensingImageType {
  Optical
  Multispectral
  Hyperspectral
  SAR
  Thermal
  LiDAR
  Unknown
} derive(Eq)

///|
/// 遥感图像
pub(all) struct RemoteSensingImage {
  width : Int
  height : Int
  bands : Int
  data : Array[Double]
  image_type : RemoteSensingImageType
  wavelength : Array[Double] // 每个波段的波长（nm）
  resolution : Double // 空间分辨率（米）
  acquisition_date : String
  cloud_cover : Double // 云量百分比
}

///|
/// 地物类别
pub(all) enum LandCoverClass {
  Water
  Forest
  Grassland
  Cropland
  Urban
  Barren
  Wetland
  Snow
  Cloud
  Shadow
  Unknown
} derive(Eq)

///|
/// 分类结果
pub(all) struct ClassificationResult {
  width : Int
  height : Int
  labels : Array[Int]
  class_names : Array[String]
  class_colors : Array[(Int, Int, Int)]
  num_classes : Int
  overall_accuracy : Double
  kappa_coefficient : Double
}

///|
/// 变化检测结果
pub(all) struct ChangeDetectionResult {
  width : Int
  height : Int
  change_mask : Array[Bool]
  change_percentage : Double
  num_changed_pixels : Int
  change_intensity : Array[Double]
  threshold : Double
}

///|
/// 植被指数
pub(all) struct VegetationIndices {
  ndvi : Array[Double] // 归一化植被指数
  ndwi : Array[Double] // 归一化水体指数
  ndbi : Array[Double] // 归一化建筑指数
  evi : Array[Double] // 增强植被指数
  savi : Array[Double] // 土壤调整植被指数
  msavi : Array[Double] // 修正土壤调整植被指数
}

///|
/// 光谱特征
pub(all) struct SpectralSignature {
  wavelengths : Array[Double]
  reflectance : Array[Double]
  num_bands : Int
  mean_reflectance : Double
  std_reflectance : Double
  absorption_features : Array[(Double, Double)] // (波长, 深度)
}

///|
/// 纹理特征
pub(all) struct TextureFeatures {
  contrast : Double
  homogeneity : Double
  energy : Double
  correlation : Double
  entropy : Double
  variance : Double
  dissimilarity : Double
}

///|
/// 遥感图像质量
pub(all) struct RemoteSensingQuality {
  snr : Double
  cloud_cover : Double
  geometric_accuracy : Double
  radiometric_accuracy : Double
  overall_quality : Double
}

///|
/// 创建默认遥感图像
pub fn create_default_remote_sensing_image(
  width : Int,
  height : Int,
  bands : Int,
) -> RemoteSensingImage {
  let data : Array[Double] = []
  let wavelength : Array[Double] = []
  for _ in 0..<(width * height * bands) {
    data.push(0.0)
  }
  for i in 0..<bands {
    wavelength.push(400.0 + i.to_double() * 100.0)
  }
  RemoteSensingImage::{
    width,
    height,
    bands,
    data,
    image_type: RemoteSensingImageType::Multispectral,
    wavelength,
    resolution: 10.0,
    acquisition_date: "2024-01-01",
    cloud_cover: 0.0,
  }
}

///|
/// 计算 NDVI（归一化植被指数）
pub fn calculate_ndvi(
  image : RemoteSensingImage,
  red_band : Int,
  nir_band : Int,
) -> Array[Double] {
  let w = image.width
  let h = image.height
  let total = w * h
  let ndvi : Array[Double] = []

  for i in 0..<total {
    let red = image.data[i * image.bands + red_band]
    let nir = image.data[i * image.bands + nir_band]
    let denominator = nir + red
    if denominator > 0.001 {
      ndvi.push((nir - red) / denominator)
    } else {
      ndvi.push(0.0)
    }
  }

  ndvi
}

///|
/// 计算 NDWI（归一化水体指数）
pub fn calculate_ndwi(
  image : RemoteSensingImage,
  green_band : Int,
  nir_band : Int,
) -> Array[Double] {
  let w = image.width
  let h = image.height
  let total = w * h
  let ndwi : Array[Double] = []

  for i in 0..<total {
    let green = image.data[i * image.bands + green_band]
    let nir = image.data[i * image.bands + nir_band]
    let denominator = nir + green
    if denominator > 0.001 {
      ndwi.push((green - nir) / denominator)
    } else {
      ndwi.push(0.0)
    }
  }

  ndwi
}

///|
/// 计算 NDBI（归一化建筑指数）
pub fn calculate_ndbi(
  image : RemoteSensingImage,
  swir_band : Int,
  nir_band : Int,
) -> Array[Double] {
  let w = image.width
  let h = image.height
  let total = w * h
  let ndbi : Array[Double] = []

  for i in 0..<total {
    let swir = image.data[i * image.bands + swir_band]
    let nir = image.data[i * image.bands + nir_band]
    let denominator = swir + nir
    if denominator > 0.001 {
      ndbi.push((swir - nir) / denominator)
    } else {
      ndbi.push(0.0)
    }
  }

  ndbi
}

///|
/// 计算所有植被指数
pub fn calculate_all_vegetation_indices(
  image : RemoteSensingImage,
) -> VegetationIndices {
  let ndvi = if image.bands > 4 { calculate_ndvi(image, 2, 3) } else { [] }
  let ndwi = if image.bands > 4 { calculate_ndwi(image, 1, 3) } else { [] }
  let ndbi = if image.bands > 5 { calculate_ndbi(image, 4, 3) } else { [] }

  VegetationIndices::{ ndvi, ndwi, ndbi, evi: ndvi, savi: ndvi, msavi: ndvi }
}

///|
/// 简单地物分类（基于光谱指数的决策树）
pub fn classify_land_cover_simple(
  image : RemoteSensingImage,
) -> ClassificationResult {
  let w = image.width
  let h = image.height
  let total = w * h
  let labels : Array[Int] = []

  let ndvi = if image.bands > 4 { calculate_ndvi(image, 2, 3) } else { [] }
  let ndwi = if image.bands > 4 { calculate_ndwi(image, 1, 3) } else { [] }

  for i in 0..<total {
    let mut label = 10 // Unknown
    if ndvi.length() > 0 && ndwi.length() > 0 {
      let n = ndvi[i]
      let w_idx = ndwi[i]
      if w_idx > 0.3 {
        label = 0 // Water
      } else if n > 0.6 {
        label = 1 // Forest
      } else if n > 0.3 {
        label = 2 // Grassland
      } else if n > 0.1 {
        label = 3 // Cropland
      } else if n < -0.1 {
        label = 4 // Urban
      } else {
        label = 5 // Barren
      }
    }
    labels.push(label)
  }

  let class_names : Array[String] = [
    "Water", "Forest", "Grassland", "Cropland", "Urban", "Barren", "Wetland", "Snow",
    "Cloud", "Shadow", "Unknown",
  ]
  let class_colors : Array[(Int, Int, Int)] = [
    (0, 0, 255),
    (0, 128, 0),
    (128, 255, 0),
    (255, 255, 0),
    (255, 0, 0),
    (128, 128, 128),
    (0, 255, 255),
    (255, 255, 255),
    (200, 200, 200),
    (50, 50, 50),
    (0, 0, 0),
  ]

  ClassificationResult::{
    width: w,
    height: h,
    labels,
    class_names,
    class_colors,
    num_classes: 11,
    overall_accuracy: 0.0,
    kappa_coefficient: 0.0,
  }
}

///|
/// 变化检测（基于图像差值）
pub fn detect_changes_simple(
  image1 : RemoteSensingImage,
  image2 : RemoteSensingImage,
  threshold : Double,
) -> ChangeDetectionResult {
  let w = image1.width
  let h = image1.height
  let total = w * h
  let change_mask : Array[Bool] = []
  let change_intensity : Array[Double] = []
  let mut num_changed = 0

  for i in 0..<total {
    let mut sum_diff = 0.0
    for b in 0..<image1.bands {
      let idx = i * image1.bands + b
      if idx < image1.data.length() && idx < image2.data.length() {
        let diff = image1.data[idx] - image2.data[idx]
        sum_diff += diff * diff
      }
    }
    let intensity = if image1.bands > 0 {
      (sum_diff / image1.bands.to_double()).sqrt()
    } else {
      0.0
    }
    change_intensity.push(intensity)
    let changed = intensity > threshold
    change_mask.push(changed)
    if changed {
      num_changed += 1
    }
  }

  let change_percentage = if total > 0 {
    num_changed.to_double() / total.to_double() * 100.0
  } else {
    0.0
  }

  ChangeDetectionResult::{
    width: w,
    height: h,
    change_mask,
    change_percentage,
    num_changed_pixels: num_changed,
    change_intensity,
    threshold,
  }
}

///|
/// 计算纹理特征（基于灰度共生矩阵简化版）
pub fn calculate_texture_features(
  image : @types.Image,
  x : Int,
  y : Int,
  window_size : Int,
) -> TextureFeatures raise @types.LoadError {
  // 输入验证
  if image.width <= 0 || image.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "calculate_texture_features: 图像尺寸必须大于0",
    )
  }
  if image.channels < 1 || image.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "calculate_texture_features: 通道数必须在1-4之间",
    )
  }
  let expected_size = image.width * image.height * image.channels
  if image.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "calculate_texture_features: 数据大小不匹配",
    )
  }
  let w = image.width
  let h = image.height
  let half = window_size / 2
  let mut sum = 0.0
  let mut sum_sq = 0.0
  let mut count = 0
  let histogram : Array[Int] = []
  for _ in 0..<256 {
    histogram.push(0)
  }

  for dy in -half..<(half + 1) {
    for dx in -half..<(half + 1) {
      let nx = x + dx
      let ny = y + dy
      if nx >= 0 && nx < w && ny >= 0 && ny < h {
        let pixel = image.data[ny * w + nx].to_double()
        sum += pixel
        sum_sq += pixel * pixel
        count += 1
        histogram[pixel.to_int()] += 1
      }
    }
  }

  let mean = if count > 0 { sum / count.to_double() } else { 0.0 }
  let variance = if count > 0 {
    sum_sq / count.to_double() - mean * mean
  } else {
    0.0
  }

  // 计算熵
  let mut entropy = 0.0
  for i in 0..<256 {
    if histogram[i] > 0 && count > 0 {
      let p = histogram[i].to_double() / count.to_double()
      entropy -= p * (p * 10.0)
    }
  }

  // 简化的对比度、同质性、能量、相关性
  let contrast = variance
  let homogeneity = if variance > 0.0 { 1.0 / (1.0 + variance) } else { 1.0 }
  let energy = if count > 0 {
    let mut e = 0.0
    for i in 0..<256 {
      let p = histogram[i].to_double() / count.to_double()
      e += p * p
    }
    e
  } else {
    0.0
  }
  let correlation = 0.5
  let dissimilarity = variance.sqrt()

  TextureFeatures::{
    contrast,
    homogeneity,
    energy,
    correlation,
    entropy,
    variance,
    dissimilarity,
  }
}

///|
/// 计算光谱特征
pub fn calculate_spectral_signature(
  image : RemoteSensingImage,
  x : Int,
  y : Int,
) -> SpectralSignature {
  let reflectance : Array[Double] = []
  let wavelengths : Array[Double] = []
  let mut sum = 0.0
  let mut sum_sq = 0.0

  for b in 0..<image.bands {
    let idx = (y * image.width + x) * image.bands + b
    if idx < image.data.length() {
      let value = image.data[idx]
      reflectance.push(value)
      wavelengths.push(image.wavelength[b])
      sum += value
      sum_sq += value * value
    }
  }

  let mean = if image.bands > 0 { sum / image.bands.to_double() } else { 0.0 }
  let variance = if image.bands > 0 {
    sum_sq / image.bands.to_double() - mean * mean
  } else {
    0.0
  }
  let std = if variance > 0.0 { variance.sqrt() } else { 0.0 }

  // 简化的吸收特征检测
  let absorption_features : Array[(Double, Double)] = []
  for b in 1..<(image.bands - 1) {
    if b < reflectance.length() {
      let prev = reflectance[b - 1]
      let curr = reflectance[b]
      let next = reflectance[b + 1]
      if curr < prev && curr < next {
        let depth = (prev + next) / 2.0 - curr
        if depth > 0.01 {
          absorption_features.push((wavelengths[b], depth))
        }
      }
    }
  }

  SpectralSignature::{
    wavelengths,
    reflectance,
    num_bands: image.bands,
    mean_reflectance: mean,
    std_reflectance: std,
    absorption_features,
  }
}

///|
/// 计算遥感图像质量
pub fn calculate_remote_sensing_quality(
  image : RemoteSensingImage,
) -> RemoteSensingQuality {
  let w = image.width
  let h = image.height
  let total = w * h
  let mut sum = 0.0
  let mut sum_sq = 0.0

  for i in 0..<total {
    if i < image.data.length() {
      let pixel = image.data[i]
      sum += pixel
      sum_sq += pixel * pixel
    }
  }

  let mean = if total > 0 { sum / total.to_double() } else { 0.0 }
  let variance = if total > 0 {
    sum_sq / total.to_double() - mean * mean
  } else {
    0.0
  }
  let std = if variance > 0.0 { variance.sqrt() } else { 1.0 }
  let snr = if std > 0.0 { mean / std } else { 0.0 }

  let overall_quality = if snr > 10.0 && image.cloud_cover < 10.0 {
    5.0
  } else if snr > 5.0 && image.cloud_cover < 30.0 {
    3.0
  } else {
    2.0
  }

  RemoteSensingQuality::{
    snr,
    cloud_cover: image.cloud_cover,
    geometric_accuracy: 0.8,
    radiometric_accuracy: 0.85,
    overall_quality,
  }
}

///|
/// 生成遥感图像分析报告
pub fn remote_sensing_report_to_string(
  image : RemoteSensingImage,
  classification : ClassificationResult,
  changes : ChangeDetectionResult,
  quality : RemoteSensingQuality,
) -> String {
  let mut report = "## 遥感图像分析报告\n\n"
  report = report + "### 图像信息\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  let type_str = if image.image_type == RemoteSensingImageType::Optical {
    "光学"
  } else if image.image_type == RemoteSensingImageType::Multispectral {
    "多光谱"
  } else if image.image_type == RemoteSensingImageType::Hyperspectral {
    "高光谱"
  } else if image.image_type == RemoteSensingImageType::SAR {
    "SAR"
  } else if image.image_type == RemoteSensingImageType::Thermal {
    "热红外"
  } else if image.image_type == RemoteSensingImageType::LiDAR {
    "激光雷达"
  } else {
    "未知"
  }
  report = report + "| 类型 | " + type_str + " |\n"
  report = report +
    "| 尺寸 | " +
    image.width.to_string() +
    "x" +
    image.height.to_string() +
    " |\n"
  report = report + "| 波段数 | " + image.bands.to_string() + " |\n"
  report = report +
    "| 空间分辨率 | " +
    image.resolution.to_string() +
    "m |\n"
  report = report + "| 获取日期 | " + image.acquisition_date + " |\n"
  report = report + "| 云量 | " + image.cloud_cover.to_string() + "% |\n\n"

  report = report + "### 图像质量\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report + "| SNR | " + quality.snr.to_string() + " dB |\n"
  report = report + "| 云量 | " + quality.cloud_cover.to_string() + "% |\n"
  report = report +
    "| 几何精度 | " +
    (quality.geometric_accuracy * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 辐射精度 | " +
    (quality.radiometric_accuracy * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 综合质量 | " +
    quality.overall_quality.to_string() +
    "/5.0 |\n\n"

  report = report + "### 地物分类统计\n\n"
  report = report + "| 类别 | 颜色(RGB) |\n|------|-----------|\n"
  for i in 0..<classification.num_classes {
    if i < classification.class_names.length() &&
      i < classification.class_colors.length() {
      let color = classification.class_colors[i]
      report = report +
        "| " +
        classification.class_names[i] +
        " | " +
        color.0.to_string() +
        "," +
        color.1.to_string() +
        "," +
        color.2.to_string() +
        " |\n"
    }
  }

  report = report + "\n### 变化检测\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report +
    "| 变化像素数 | " +
    changes.num_changed_pixels.to_string() +
    " |\n"
  report = report +
    "| 变化百分比 | " +
    changes.change_percentage.to_string() +
    "% |\n"
  report = report + "| 变化阈值 | " + changes.threshold.to_string() + " |\n"

  report
}

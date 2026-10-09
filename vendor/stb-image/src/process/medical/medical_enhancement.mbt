// 医学图像增强（v19.0.0）
// 医学图像分割、配准、增强、DICOM 处理、病灶检测

///|
/// 医学图像类型
pub(all) enum MedicalImageType {
  CT
  MRI
  XRay
  Ultrasound
  PET
  SPECT
  Mammography
  Fluoroscopy
  Unknown
} derive(Eq)

///|
/// 医学图像
pub(all) struct MedicalImage {
  width : Int
  height : Int
  slices : Int
  data : Array[Double]
  image_type : MedicalImageType
  pixel_spacing_x : Double
  pixel_spacing_y : Double
  slice_thickness : Double
  window_center : Double
  window_width : Double
}

///|
/// 感兴趣区域（ROI）
pub(all) struct RegionOfInterest {
  id : Int
  name : String
  x : Int
  y : Int
  width : Int
  height : Int
  slice : Int
  volume : Double
  mean_intensity : Double
  std_intensity : Double
  confidence : Double
}

///|
/// 病灶
pub(all) struct Lesion {
  id : Int
  lesion_type : String
  x : Double
  y : Double
  z : Double
  diameter : Double
  volume : Double
  intensity : Double
  margin : String // "well_defined" / "ill_defined" / "spiculated"
  shape : String // "round" / "oval" / "irregular"
  density : String // "solid" / "cystic" / "mixed" / "calcified"
  confidence : Double
  birads_category : Int // BI-RADS 1-6
}

///|
/// 医学图像配准结果
pub(all) struct MedicalRegistrationResult {
  transformation : Array[Double] // 4x4 变换矩阵
  similarity : Double
  iterations : Int
  converged : Bool
  registration_type : String // "rigid" / "affine" / "deformable"
}

///|
/// 医学图像分割配置
pub(all) struct MedicalSegmentationConfig {
  method_type : String // "threshold" / "region_growing" / "level_set" / "watershed"
  lower_threshold : Double
  upper_threshold : Double
  seed_points : Array[(Int, Int, Int)]
  smoothness : Double
  curvature_weight : Double
}

///|
/// 窗宽窗位配置
pub(all) struct WindowLevelConfig {
  center : Double
  width : Double
  preset : String // "brain" / "lung" / "abdomen" / "bone" / "soft_tissue" / "custom"
}

///|
/// 医学图像质量指标
pub(all) struct MedicalImageQuality {
  snr : Double // 信噪比
  cnr : Double // 对比噪声比
  sharpness : Double
  noise_level : Double
  artifact_score : Double
  overall_quality : Double // 1-5 分
}

///|
/// 创建默认医学分割配置
pub fn create_default_medical_segmentation_config() -> MedicalSegmentationConfig {
  MedicalSegmentationConfig::{
    method_type: "threshold",
    lower_threshold: 0.0,
    upper_threshold: 255.0,
    seed_points: [],
    smoothness: 1.0,
    curvature_weight: 1.0,
  }
}

///|
/// 创建默认窗宽窗位配置
pub fn create_default_window_level(preset : String) -> WindowLevelConfig {
  if preset == "brain" {
    WindowLevelConfig::{ center: 40.0, width: 80.0, preset }
  } else if preset == "lung" {
    WindowLevelConfig::{ center: -600.0, width: 1500.0, preset }
  } else if preset == "abdomen" {
    WindowLevelConfig::{ center: 40.0, width: 400.0, preset }
  } else if preset == "bone" {
    WindowLevelConfig::{ center: 300.0, width: 1500.0, preset }
  } else if preset == "soft_tissue" {
    WindowLevelConfig::{ center: 50.0, width: 350.0, preset }
  } else {
    WindowLevelConfig::{ center: 128.0, width: 256.0, preset: "custom" }
  }
}

///|
/// 应用窗宽窗位
pub fn apply_window_level_medical(
  image : MedicalImage,
  config : WindowLevelConfig,
) -> @types.Image {
  let w = image.width
  let h = image.height
  let out : Array[Byte] = []
  let lower = config.center - config.width / 2.0
  let upper = config.center + config.width / 2.0

  for i in 0..<(w * h) {
    let pixel = image.data[i]
    let normalized = if upper > lower {
      (pixel - lower) / (upper - lower)
    } else {
      0.5
    }
    let clamped = if normalized < 0.0 {
      0.0
    } else if normalized > 1.0 {
      1.0
    } else {
      normalized
    }
    let value = (clamped * 255.0).to_int()
    out.push(if value > 127 { b'\xFF' } else { b'\x00' })
  }

  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

///|
/// 医学图像阈值分割
pub fn medical_threshold_segmentation(
  image : MedicalImage,
  lower : Double,
  upper : Double,
) -> Array[Bool] {
  let total = image.width * image.height * image.slices
  let mask : Array[Bool] = []

  for i in 0..<total {
    let pixel = image.data[i]
    mask.push(pixel >= lower && pixel <= upper)
  }

  mask
}

///|
/// 区域生长分割
pub fn region_growing_segmentation(
  image : MedicalImage,
  seed_x : Int,
  seed_y : Int,
  seed_z : Int,
  threshold : Double,
) -> Array[Bool] {
  let w = image.width
  let h = image.height
  let s = image.slices
  let total = w * h * s
  let mask : Array[Bool] = []
  for _ in 0..<total {
    mask.push(false)
  }

  let seed_idx = seed_z * w * h + seed_y * w + seed_x
  if seed_idx < 0 || seed_idx >= total {
    return mask
  }

  let seed_value = image.data[seed_idx]
  let queue_x : Array[Int] = [seed_x]
  let queue_y : Array[Int] = [seed_y]
  let queue_z : Array[Int] = [seed_z]
  mask[seed_idx] = true
  let mut queue_idx = 0

  while queue_idx < queue_x.length() {
    let cx = queue_x[queue_idx]
    let cy = queue_y[queue_idx]
    let cz = queue_z[queue_idx]
    queue_idx += 1

    // 6 邻域
    let neighbors = [
      (cx + 1, cy, cz),
      (cx - 1, cy, cz),
      (cx, cy + 1, cz),
      (cx, cy - 1, cz),
      (cx, cy, cz + 1),
      (cx, cy, cz - 1),
    ]

    for _tup0 in neighbors {
      let (nx, ny, nz) = _tup0
      if nx < 0 || nx >= w || ny < 0 || ny >= h || nz < 0 || nz >= s {
        continue
      }
      let nidx = nz * w * h + ny * w + nx
      if mask[nidx] {
        continue
      }
      let nvalue = image.data[nidx]
      if (nvalue - seed_value).abs() < threshold {
        mask[nidx] = true
        queue_x.push(nx)
        queue_y.push(ny)
        queue_z.push(nz)
      }
    }
  }

  mask
}

///|
/// 计算 ROI 统计信息
pub fn calculate_roi_stats(
  image : MedicalImage,
  mask : Array[Bool],
) -> (Double, Double, Int) {
  let mut sum = 0.0
  let mut sum_sq = 0.0
  let mut count = 0

  for i in 0..<mask.length() {
    if mask[i] && i < image.data.length() {
      let pixel = image.data[i]
      sum += pixel
      sum_sq += pixel * pixel
      count += 1
    }
  }

  let mean = if count > 0 { sum / count.to_double() } else { 0.0 }
  let variance = if count > 0 {
    sum_sq / count.to_double() - mean * mean
  } else {
    0.0
  }
  let std = if variance > 0.0 { variance.sqrt() } else { 0.0 }

  (mean, std, count)
}

///|
/// 简单病灶检测（基于强度和形状）
pub fn detect_lesions_simple(
  image : MedicalImage,
  min_diameter : Double,
  max_diameter : Double,
) -> Array[Lesion] {
  let lesions : Array[Lesion] = []
  let w = image.width
  let h = image.height

  // 简化版：基于局部最大值的病灶检测
  let mut lesion_id = 0
  for y in 5..<(h - 5) {
    for x in 5..<(w - 5) {
      let idx = y * w + x
      let pixel = image.data[idx]
      if pixel < 100.0 {
        continue
      }

      // 检查是否为局部最大值
      let mut is_local_max = true
      for dy in -3..<4 {
        for dx in -3..<4 {
          if dx == 0 && dy == 0 {
            continue
          }
          let neighbor = image.data[(y + dy) * w + (x + dx)]
          if neighbor > pixel {
            is_local_max = false
          }
        }
      }

      if is_local_max {
        // 估算直径
        let mut diameter = 0.0
        for r in 1..<10 {
          let mut all_above = true
          for dy in -r..<(r + 1) {
            for dx in -r..<(r + 1) {
              let nx = x + dx
              let ny = y + dy
              if nx >= 0 && nx < w && ny >= 0 && ny < h {
                if image.data[ny * w + nx] < pixel * 0.5 {
                  all_above = false
                }
              }
            }
          }
          if all_above {
            diameter = r.to_double() * 2.0
          }
        }

        if diameter >= min_diameter && diameter <= max_diameter {
          lesions.push(Lesion::{
            id: lesion_id,
            lesion_type: "nodule",
            x: x.to_double(),
            y: y.to_double(),
            z: 0.0,
            diameter,
            volume: diameter * diameter * diameter * 3.14159 / 6.0,
            intensity: pixel,
            margin: "well_defined",
            shape: "round",
            density: "solid",
            confidence: 0.7,
            birads_category: 3,
          })
          lesion_id += 1
        }
      }
    }
  }

  lesions
}

///|
/// 医学图像配准（简化版互信息）
pub fn medical_image_registration(
  fixed : MedicalImage,
  moving : MedicalImage,
  max_iterations : Int,
) -> MedicalRegistrationResult {
  let transformation : Array[Double] = [
    1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0,
  ]

  let mut similarity = 0.0
  let mut converged = false
  let mut iterations = 0

  for iter in 0..<max_iterations {
    iterations = iter + 1
    // 简化版：计算归一化互相关
    let mut sum_fixed = 0.0
    let mut sum_moving = 0.0
    let mut sum_product = 0.0
    let mut sum_fixed_sq = 0.0
    let mut sum_moving_sq = 0.0
    let count = if fixed.data.length() < moving.data.length() {
      fixed.data.length()
    } else {
      moving.data.length()
    }

    for i in 0..<count {
      let f = fixed.data[i]
      let m = moving.data[i]
      sum_fixed += f
      sum_moving += m
      sum_product += f * m
      sum_fixed_sq += f * f
      sum_moving_sq += m * m
    }

    let mean_f = sum_fixed / count.to_double()
    let mean_m = sum_moving / count.to_double()
    let cov = sum_product / count.to_double() - mean_f * mean_m
    let var_f = sum_fixed_sq / count.to_double() - mean_f * mean_f
    let var_m = sum_moving_sq / count.to_double() - mean_m * mean_m
    let ncc = if var_f > 0.0 && var_m > 0.0 {
      cov / (var_f * var_m).sqrt()
    } else {
      0.0
    }

    if (ncc - similarity).abs() < 0.001 {
      converged = true
      similarity = ncc
      break
    }
    similarity = ncc
  }

  MedicalRegistrationResult::{
    transformation,
    similarity,
    iterations,
    converged,
    registration_type: "rigid",
  }
}

///|
/// 计算医学图像质量指标
pub fn calculate_medical_image_quality(
  image : MedicalImage,
) -> MedicalImageQuality {
  let w = image.width
  let h = image.height
  let total = w * h

  // 计算 SNR
  let mut sum = 0.0
  let mut sum_sq = 0.0
  for i in 0..<total {
    let pixel = image.data[i]
    sum += pixel
    sum_sq += pixel * pixel
  }
  let mean = sum / total.to_double()
  let variance = sum_sq / total.to_double() - mean * mean
  let std = if variance > 0.0 { variance.sqrt() } else { 1.0 }
  let snr = if std > 0.0 { mean / std } else { 0.0 }

  // 计算清晰度（基于梯度）
  let mut sharpness = 0.0
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let gx = image.data[idx + 1] - image.data[idx - 1]
      let gy = image.data[idx + w] - image.data[idx - w]
      sharpness += (gx * gx + gy * gy).sqrt()
    }
  }
  sharpness /= total.to_double()

  let noise_level = std
  let cnr = snr * 0.8
  let artifact_score = 1.0
  let overall_quality = if snr > 10.0 && sharpness > 5.0 {
    5.0
  } else if snr > 5.0 {
    3.0
  } else {
    2.0
  }

  MedicalImageQuality::{
    snr,
    cnr,
    sharpness,
    noise_level,
    artifact_score,
    overall_quality,
  }
}

///|
/// 生成医学图像报告
pub fn medical_image_report_to_string(
  image : MedicalImage,
  lesions : Array[Lesion],
  quality : MedicalImageQuality,
) -> String {
  let mut report = "## 医学图像分析报告\n\n"
  report = report + "### 图像信息\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  let type_str = if image.image_type == MedicalImageType::CT {
    "CT"
  } else if image.image_type == MedicalImageType::MRI {
    "MRI"
  } else if image.image_type == MedicalImageType::XRay {
    "X-Ray"
  } else if image.image_type == MedicalImageType::Ultrasound {
    "超声"
  } else if image.image_type == MedicalImageType::PET {
    "PET"
  } else if image.image_type == MedicalImageType::SPECT {
    "SPECT"
  } else if image.image_type == MedicalImageType::Mammography {
    "乳腺钼靶"
  } else if image.image_type == MedicalImageType::Fluoroscopy {
    "透视"
  } else {
    "未知"
  }
  report = report + "| 类型 | " + type_str + " |\n"
  report = report +
    "| 尺寸 | " +
    image.width.to_string() +
    "x" +
    image.height.to_string() +
    "x" +
    image.slices.to_string() +
    " |\n"
  report = report +
    "| 窗宽窗位 | " +
    image.window_center.to_string() +
    "/" +
    image.window_width.to_string() +
    " |\n\n"

  report = report + "### 图像质量\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report + "| SNR | " + quality.snr.to_string() + " dB |\n"
  report = report + "| CNR | " + quality.cnr.to_string() + " |\n"
  report = report + "| 清晰度 | " + quality.sharpness.to_string() + " |\n"
  report = report +
    "| 噪声水平 | " +
    quality.noise_level.to_string() +
    " |\n"
  report = report +
    "| 综合质量 | " +
    quality.overall_quality.to_string() +
    "/5.0 |\n\n"

  if lesions.length() > 0 {
    report = report + "### 检测到的病灶\n\n"
    report = report +
      "| ID | 类型 | 位置(X,Y,Z) | 直径 | 体积 | 强度 | 形状 | 密度 | 置信度 | BI-RADS |\n"
    report = report +
      "|----|------|-------------|------|------|------|------|------|--------|---------|\n"
    for lesion in lesions {
      report = report +
        "| " +
        lesion.id.to_string() +
        " | " +
        lesion.lesion_type +
        " | " +
        lesion.x.to_string() +
        "," +
        lesion.y.to_string() +
        "," +
        lesion.z.to_string() +
        " | " +
        lesion.diameter.to_string() +
        " | " +
        lesion.volume.to_string() +
        " | " +
        lesion.intensity.to_string() +
        " | " +
        lesion.shape +
        " | " +
        lesion.density +
        " | " +
        (lesion.confidence * 100.0).to_string() +
        "% | " +
        lesion.birads_category.to_string() +
        " |\n"
    }
  } else {
    report = report + "### 病灶检测\n\n未检测到明显病灶。\n"
  }

  report
}

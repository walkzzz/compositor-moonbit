// 图像来源鉴定增强（v27.1.0）
// ELA 分析、噪声残差、DCT 系数、双 JPEG 检测、克隆检测、光照一致性、篡改检测综合

///|
/// ELA 分析结果
pub(all) struct ElaAnalysisResult {
  ela_mean : Double
  ela_std : Double
  ela_max : Double
  ela_distribution : Array[Double]
  tampered_region_ratio : Double
}

///|
/// 噪声残差分析结果
pub(all) struct NoiseResidualResult {
  residual_mean : Double
  residual_std : Double
  residual_energy : Double
  sensor_pattern : Array[Double]
  pattern_consistency : Double
}

///|
/// DCT 系数分析结果
pub(all) struct DctCoefficientResult {
  coefficient_distribution : Array[Double]
  high_freq_coefficient_ratio : Double
  zero_coefficient_ratio : Double
  blockiness_artifact : Double
  double_jpeg_indicator : Double
}

///|
/// 克隆检测结果
pub(all) struct CloneDetectionResult {
  clone_region_count : Int
  clone_regions : Array[(Int, Int, Int, Int)]
  clone_similarity : Double
  has_clone : Bool
}

///|
/// 光照一致性结果
pub(all) struct IlluminationConsistencyResult {
  illumination_direction : Double
  shadow_consistency : Double
  highlight_distribution : Double
  illumination_inconsistency : Double
  has_inconsistent_lighting : Bool
}

///|
/// 篡改检测综合结果
pub(all) struct TamperDetectionResult {
  is_tampered : Bool
  tamper_probability : Double
  tamper_type : String
  tampered_regions : Array[(Int, Int, Int, Int)]
  confidence : Double
  analysis_details : String
}

///|
/// 元数据取证结果
pub(all) struct MetadataForensicsResult {
  has_metadata : Bool
  software_signature : String
  creation_time : String
  device_info : String
  metadata_consistency : Double
  has_inconsistency : Bool
}

///|
/// JPEG ghost 分析结果
pub(all) struct JpegGhostResult {
  ghost_quality_levels : Array[Int]
  ghost_region_count : Int
  has_ghost : Bool
  primary_quality : Int
  secondary_quality : Int
}

///|
/// CFA 分析结果
pub(all) struct CfaAnalysisResult {
  cfa_pattern : String
  bayer_pattern_score : Double
  cfa_artifact_level : Double
  is_cfa_consistent : Bool
}

///|
/// ELA（Error Level Analysis）分析
/// 通过模拟 JPEG 重压缩分析图像篡改区域
pub fn analyze_ela(
  img : @types.Image,
  quality_level : Int,
) -> ElaAnalysisResult raise @types.LoadError {
  let w = img.width
  let h = img.height
  let total = w * h

  // 模拟 JPEG 量化：按 quality_level 量化像素
  let quant = if quality_level > 0 { 256 / (quality_level + 1) } else { 8 }
  if quant == 0 {
    raise @types.LoadError::DecodeFailed("quality_level too high")
  }

  // 量化并反量化（模拟 JPEG 压缩-解压）
  let recompressed : Array[Byte] = []
  for i in 0..<total {
    let val = img.data[i].to_int()
    let quantized = val / quant * quant
    let clamped = if quantized < 0 {
      0
    } else if quantized > 255 {
      255
    } else {
      quantized
    }
    recompressed.push(clamped.to_byte())
  }

  // 计算 ELA 差值
  let mut ela_mean = 0.0
  let mut ela_max = 0.0
  let mut ela_sq_sum = 0.0
  let distribution : Array[Double] = []
  let num_bins = 16
  for _ in 0..<num_bins {
    distribution.push(0.0)
  }

  for i in 0..<total {
    let diff = (img.data[i].to_int() - recompressed[i].to_int())
      .abs()
      .to_double()
    ela_mean += diff
    if diff > ela_max {
      ela_max = diff
    }
    ela_sq_sum += diff * diff
    let bin = (diff.to_int() * num_bins / 256).clamp(min=0, max=num_bins - 1)
    distribution[bin] += 1.0
  }

  ela_mean /= total.to_double()
  let ela_std = (ela_sq_sum / total.to_double() - ela_mean * ela_mean)
    .abs()
    .sqrt()

  // 归一化分布
  for i in 0..<num_bins {
    distribution[i] /= total.to_double()
  }

  // 篡改区域比例：ELA 值高于均值的像素比例
  let mut tampered_count = 0
  for i in 0..<total {
    let diff = (img.data[i].to_int() - recompressed[i].to_int())
      .abs()
      .to_double()
    if diff > ela_mean * 2.0 {
      tampered_count += 1
    }
  }
  let tampered_ratio = tampered_count.to_double() / total.to_double()

  ElaAnalysisResult::{
    ela_mean,
    ela_std,
    ela_max,
    ela_distribution: distribution,
    tampered_region_ratio: tampered_ratio,
  }
}

///|
/// 噪声残差分析
/// 提取传感器模式噪声残差
pub fn analyze_noise_residual(img : @types.Image) -> NoiseResidualResult {
  let w = img.width
  let h = img.height
  let total = w * h

  // 提取噪声残差：原图 - 中值滤波结果
  let residual : Array[Double] = []
  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      // 3x3 中值滤波
      let neighbors : Array[Int] = []
      for dy in -1..<2 {
        for dx in -1..<2 {
          let ny = y + dy
          let nx = x + dx
          if ny >= 0 && ny < h && nx >= 0 && nx < w {
            neighbors.push(img.data[ny * w + nx].to_int())
          }
        }
      }
      neighbors.sort()
      let median = neighbors[neighbors.length() / 2]
      let r = img.data[idx].to_double() - median.to_double()
      residual.push(r)
    }
  }

  // 统计
  let mut mean = 0.0
  let mut sq_sum = 0.0
  for i in 0..<total {
    mean += residual[i]
    sq_sum += residual[i] * residual[i]
  }
  mean /= total.to_double()
  let std = (sq_sum / total.to_double() - mean * mean).abs().sqrt()
  let energy = sq_sum / total.to_double()

  // 传感器模式（行均值作为简化模式）
  let sensor_pattern : Array[Double] = []
  let row_count = if h < 8 { h } else { 8 }
  for r in 0..<row_count {
    let mut row_mean = 0.0
    let row_len = w
    for c in 0..<row_len {
      row_mean += residual[r * w + c]
    }
    sensor_pattern.push(row_mean / row_len.to_double())
  }

  // 模式一致性：相邻行模式的相关性
  let mut consistency = 0.0
  if sensor_pattern.length() >= 2 {
    for i in 0..<(sensor_pattern.length() - 1) {
      consistency += (sensor_pattern[i] * sensor_pattern[i + 1]).abs()
    }
    consistency /= (sensor_pattern.length() - 1).to_double()
  }

  NoiseResidualResult::{
    residual_mean: mean,
    residual_std: std,
    residual_energy: energy,
    sensor_pattern,
    pattern_consistency: consistency,
  }
}

///|
/// DCT 系数分析
/// 分析 DCT 系数分布特征，检测双 JPEG 压缩
pub fn analyze_dct_coefficients(img : @types.Image) -> DctCoefficientResult {
  let w = img.width
  let h = img.height

  // 简化 DCT：计算 8x8 块的 DCT 系数统计
  let block_size = 8
  let num_blocks_x = w / block_size
  let num_blocks_y = h / block_size
  let num_blocks = num_blocks_x * num_blocks_y

  let mut high_freq_count = 0
  let mut zero_count = 0
  let mut total_coeffs = 0
  let mut blockiness = 0.0

  let distribution : Array[Double] = []
  let num_bins = 10
  for _ in 0..<num_bins {
    distribution.push(0.0)
  }

  for by in 0..<num_blocks_y {
    for bx in 0..<num_blocks_x {
      // 计算 8x8 块的简化 DCT
      let mut dc = 0.0
      let mut ac_energy = 0.0
      for j in 0..<block_size {
        for i in 0..<block_size {
          let idx = (by * block_size + j) * w + (bx * block_size + i)
          let val = img.data[idx].to_double()
          dc += val
          if i > 0 || j > 0 {
            ac_energy += val * val
          }
        }
      }
      dc /= (block_size * block_size).to_double()

      // 块边界不连续性
      if bx > 0 {
        let mut border_diff = 0.0
        for j in 0..<block_size {
          let idx_left = (by * block_size + j) * w + (bx * block_size - 1)
          let idx_right = (by * block_size + j) * w + bx * block_size
          border_diff += (img.data[idx_left].to_double() -
          img.data[idx_right].to_double()).abs()
        }
        blockiness += border_diff / block_size.to_double()
      }

      total_coeffs += block_size * block_size
      if ac_energy < 100.0 {
        zero_count += block_size * block_size - 1
      }
      if ac_energy > 1000.0 {
        high_freq_count += block_size * block_size - 1
      }

      // 分布统计
      let bin = (dc.to_int() * num_bins / 256).clamp(min=0, max=num_bins - 1)
      distribution[bin] += 1.0
    }
  }

  if num_blocks > 0 {
    blockiness /= num_blocks.to_double()
  }

  let high_freq_ratio = if total_coeffs > 0 {
    high_freq_count.to_double() / total_coeffs.to_double()
  } else {
    0.0
  }
  let zero_ratio = if total_coeffs > 0 {
    zero_count.to_double() / total_coeffs.to_double()
  } else {
    0.0
  }

  // 归一化分布
  if num_blocks > 0 {
    for i in 0..<num_bins {
      distribution[i] /= num_blocks.to_double()
    }
  }

  // 双 JPEG 指示：DCT 系数分布有周期性峰值
  let mut double_jpeg_indicator = 0.0
  for i in 1..<(num_bins - 1) {
    if distribution[i] > distribution[i - 1] &&
      distribution[i] > distribution[i + 1] {
      double_jpeg_indicator += 1.0
    }
  }
  double_jpeg_indicator /= num_bins.to_double()

  DctCoefficientResult::{
    coefficient_distribution: distribution,
    high_freq_coefficient_ratio: high_freq_ratio,
    zero_coefficient_ratio: zero_ratio,
    blockiness_artifact: blockiness,
    double_jpeg_indicator,
  }
}

///|
/// 克隆检测（复制移动篡改检测）
/// 检测图像中的复制移动区域
pub fn detect_clone_regions(
  img : @types.Image,
  block_size : Int,
  threshold : Double,
) -> CloneDetectionResult raise @types.LoadError {
  let w = img.width
  let h = img.height

  if block_size < 2 || block_size > 16 {
    raise @types.LoadError::DecodeFailed("block_size must be 2..16")
  }

  let num_blocks_x = w - block_size + 1
  let num_blocks_y = h - block_size + 1

  // 提取块特征（简化：均值+方差）
  let block_features : Array[(Double, Double, Int, Int)] = []
  for by in 0..<num_blocks_y {
    for bx in 0..<num_blocks_x {
      let mut mean = 0.0
      let mut sq_sum = 0.0
      let count = block_size * block_size
      for j in 0..<block_size {
        for i in 0..<block_size {
          let idx = (by + j) * w + (bx + i)
          let val = img.data[idx].to_double()
          mean += val
          sq_sum += val * val
        }
      }
      mean /= count.to_double()
      let variance = sq_sum / count.to_double() - mean * mean
      block_features.push((mean, variance, bx, by))
    }
  }

  // 比较块特征，找相似块
  let clone_regions : Array[(Int, Int, Int, Int)] = []
  let mut clone_count = 0
  let mut total_similarity = 0.0
  let mut comparison_count = 0

  let n = block_features.length()
  for i in 0..<n {
    for j in 0..<n {
      if i >= j {
        continue
      }
      let (m1, v1, x1, y1) = block_features[i]
      let (m2, v2, x2, y2) = block_features[j]
      // 跳过相邻块
      let dist = (x1 - x2).abs() + (y1 - y2).abs()
      if dist < block_size * 2 {
        continue
      }
      let mean_diff = (m1 - m2).abs()
      let var_diff = (v1 - v2).abs()
      let similarity = 1.0 / (1.0 + mean_diff / 10.0 + var_diff / 100.0)
      total_similarity += similarity
      comparison_count += 1
      if similarity > threshold && clone_count < 20 {
        clone_regions.push((x1, y1, x2, y2))
        clone_count += 1
      }
    }
  }

  let avg_similarity = if comparison_count > 0 {
    total_similarity / comparison_count.to_double()
  } else {
    0.0
  }

  CloneDetectionResult::{
    clone_region_count: clone_count,
    clone_regions,
    clone_similarity: avg_similarity,
    has_clone: clone_count > 0,
  }
}

///|
/// 光照一致性分析
/// 分析图像光照方向一致性，检测合成图像
pub fn analyze_illumination_consistency(
  img : @types.Image,
) -> IlluminationConsistencyResult {
  let w = img.width
  let h = img.height

  // 计算梯度方向直方图
  let mut direction_sum = 0.0
  let mut direction_count = 0
  let mut highlight_sum = 0.0
  let mut highlight_count = 0
  let mut shadow_sum = 0.0
  let mut shadow_count = 0

  let grad_threshold = 30.0

  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let gx = img.data[idx + 1].to_double() - img.data[idx - 1].to_double()
      let gy = img.data[idx + w].to_double() - img.data[idx - w].to_double()
      let magnitude = (gx * gx + gy * gy).sqrt()

      if magnitude > grad_threshold {
        let angle = @math.atan2(gy, gx)
        direction_sum += angle
        direction_count += 1
      }

      let val = img.data[idx].to_double()
      if val > 200.0 {
        highlight_sum += val
        highlight_count += 1
      }
      if val < 50.0 {
        shadow_sum += val
        shadow_count += 1
      }
    }
  }

  let illumination_direction = if direction_count > 0 {
    direction_sum / direction_count.to_double()
  } else {
    0.0
  }

  let highlight_distribution = if highlight_count > 0 {
    highlight_sum / highlight_count.to_double()
  } else {
    0.0
  }

  let shadow_consistency = if shadow_count > 0 {
    shadow_sum / shadow_count.to_double()
  } else {
    0.0
  }

  // 光照不一致性：高光和阴影分布的差异
  let illumination_inconsistency = (highlight_distribution - shadow_consistency).abs() /
    255.0

  IlluminationConsistencyResult::{
    illumination_direction,
    shadow_consistency: shadow_consistency / 255.0,
    highlight_distribution: highlight_distribution / 255.0,
    illumination_inconsistency,
    has_inconsistent_lighting: illumination_inconsistency > 0.5,
  }
}

///|
/// 元数据取证分析
/// 分析图像元数据一致性
pub fn analyze_metadata_forensics(
  img : @types.Image,
) -> MetadataForensicsResult {
  let w = img.width
  let h = img.height
  let total = w * h

  // 基于图像特征推断元数据
  let unique_values : Array[Int] = []
  for i in 0..<total {
    let v = img.data[i].to_int()
    let mut found = false
    for j in 0..<unique_values.length() {
      if unique_values[j] == v {
        found = true
        break
      }
    }
    if !found {
      unique_values.push(v)
    }
  }

  // 软件签名推断
  let software = if unique_values.length() < 10 {
    "Paint/Editor"
  } else if unique_values.length() < 100 {
    "JPEG/Compressed"
  } else {
    "Camera/Raw"
  }

  // 创建时间推断（基于图像尺寸特征）
  let creation_time = if w * h < 10000 {
    "Early/Low-res"
  } else if w * h < 1000000 {
    "Standard"
  } else {
    "Modern/High-res"
  }

  // 设备信息推断
  let device = if w == h {
    "Square/Social"
  } else if w > h * 2 {
    "Panorama"
  } else if h > w * 2 {
    "Portrait/Mobile"
  } else {
    "Standard/Camera"
  }

  // 一致性评分
  let consistency = if unique_values.length() > 50 && w > 64 && h > 64 {
    0.8
  } else if unique_values.length() > 10 {
    0.6
  } else {
    0.3
  }

  let has_inconsistency = consistency < 0.5

  MetadataForensicsResult::{
    has_metadata: true,
    software_signature: software,
    creation_time,
    device_info: device,
    metadata_consistency: consistency,
    has_inconsistency,
  }
}

///|
/// JPEG ghost 分析
/// 检测 JPEG 压缩历史中的 ghost 区域
pub fn analyze_jpeg_ghost(img : @types.Image) -> JpegGhostResult {
  let w = img.width
  let h = img.height
  let total = w * h

  // 模拟不同质量级别的重压缩差异
  let quality_levels = [50, 60, 70, 80, 90]
  let mut ghost_count = 0
  let mut primary_quality = 0
  let mut secondary_quality = 0
  let mut prev_diff = 0.0

  for qi in 0..<quality_levels.length() {
    let q = quality_levels[qi]
    let quant = 256 / (q + 1)
    if quant == 0 {
      continue
    }
    let mut diff_sum = 0.0
    for i in 0..<total {
      let val = img.data[i].to_int()
      let quantized = val / quant * quant
      let clamped = if quantized < 0 {
        0
      } else if quantized > 255 {
        255
      } else {
        quantized
      }
      diff_sum += (val - clamped).to_double().abs()
    }
    let avg_diff = diff_sum / total.to_double()

    // ghost 检测：差异变化非单调
    if qi > 0 && avg_diff > prev_diff * 1.2 {
      ghost_count += 1
      if primary_quality == 0 {
        primary_quality = quality_levels[qi - 1]
        secondary_quality = q
      }
    }
    prev_diff = avg_diff
  }

  JpegGhostResult::{
    ghost_quality_levels: quality_levels,
    ghost_region_count: ghost_count,
    has_ghost: ghost_count > 0,
    primary_quality,
    secondary_quality,
  }
}

///|
/// CFA（颜色滤波阵列）分析
/// 检测 Bayer 模式一致性
pub fn analyze_cfa_pattern(img : @types.Image) -> CfaAnalysisResult {
  let w = img.width
  let h = img.height

  // 分析像素值交替模式（Bayer 模式特征）
  let mut bayer_score = 0.0
  let mut artifact_score = 0.0
  let mut count = 0

  for y in 0..<(h - 1) {
    for x in 0..<(w - 1) {
      let idx = y * w + x
      let v00 = img.data[idx].to_double()
      let v01 = img.data[idx + 1].to_double()
      let v10 = img.data[idx + w].to_double()
      let v11 = img.data[idx + w + 1].to_double()

      // Bayer 模式：对角像素相似，相邻像素差异大
      let diag_diff = (v00 - v11).abs()
      let adj_diff = (v00 - v01).abs() + (v00 - v10).abs()

      if adj_diff > 0 {
        bayer_score += diag_diff / adj_diff
      }

      // CFA 伪影：插值痕迹
      let interpolated = (v00 + v01 + v10 + v11) / 4.0
      artifact_score += (v00 - interpolated).abs()
      count += 1
    }
  }

  if count > 0 {
    bayer_score /= count.to_double()
    artifact_score /= count.to_double()
  }
  artifact_score /= 255.0

  let pattern = if bayer_score < 0.3 {
    "Bayer/RGGB"
  } else if bayer_score < 0.6 {
    "Unknown/Mixed"
  } else {
    "Non-CFA/Processed"
  }

  let is_consistent = bayer_score < 0.4 && artifact_score < 0.2

  CfaAnalysisResult::{
    cfa_pattern: pattern,
    bayer_pattern_score: bayer_score,
    cfa_artifact_level: artifact_score,
    is_cfa_consistent: is_consistent,
  }
}

///|
/// 综合篡改检测
/// 融合多种取证分析结果，给出综合篡改判定
pub fn detect_tamper_comprehensive(
  img : @types.Image,
  ela_quality : Int,
) -> TamperDetectionResult raise @types.LoadError {
  let ela = analyze_ela(img, ela_quality)
  let noise = analyze_noise_residual(img)
  let dct = analyze_dct_coefficients(img)
  let illumination = analyze_illumination_consistency(img)
  let metadata = analyze_metadata_forensics(img)
  let jpeg_ghost = analyze_jpeg_ghost(img)
  let cfa = analyze_cfa_pattern(img)

  // 各指标评分
  let ela_score = if ela.tampered_region_ratio > 0.1 {
    0.8
  } else if ela.tampered_region_ratio > 0.05 {
    0.5
  } else {
    0.2
  }

  let noise_score = if noise.pattern_consistency < 0.5 { 0.7 } else { 0.3 }

  let dct_score = if dct.double_jpeg_indicator > 0.3 { 0.6 } else { 0.3 }

  let illum_score = if illumination.has_inconsistent_lighting {
    0.8
  } else {
    0.2
  }

  let ghost_score = if jpeg_ghost.has_ghost { 0.7 } else { 0.2 }

  let cfa_score = if !cfa.is_cfa_consistent { 0.6 } else { 0.2 }

  let meta_score = if metadata.has_inconsistency { 0.7 } else { 0.3 }

  // 加权综合
  let tamper_prob = ela_score * 0.25 +
    noise_score * 0.15 +
    dct_score * 0.15 +
    illum_score * 0.15 +
    ghost_score * 0.10 +
    cfa_score * 0.10 +
    meta_score * 0.10

  let is_tampered = tamper_prob > 0.5

  let tamper_type = if ela_score > 0.5 && illum_score > 0.5 {
    "内容篡改+光照不一致"
  } else if dct_score > 0.5 && ghost_score > 0.5 {
    "双JPEG压缩痕迹"
  } else if noise_score > 0.5 {
    "噪声模式异常"
  } else if cfa_score > 0.5 {
    "CFA模式不一致"
  } else if meta_score > 0.5 {
    "元数据不一致"
  } else if is_tampered {
    "综合篡改迹象"
  } else {
    "未检测到明显篡改"
  }

  let confidence = (tamper_prob - 0.5).abs() * 2.0

  let details = "ELA=" +
    ela_score.to_string() +
    ", Noise=" +
    noise_score.to_string() +
    ", DCT=" +
    dct_score.to_string() +
    ", Illum=" +
    illum_score.to_string() +
    ", Ghost=" +
    ghost_score.to_string() +
    ", CFA=" +
    cfa_score.to_string() +
    ", Meta=" +
    meta_score.to_string()

  // 篡改区域（简化：返回整图区域）
  let tampered_regions : Array[(Int, Int, Int, Int)] = []
  if is_tampered {
    tampered_regions.push((0, 0, img.width, img.height))
  }

  TamperDetectionResult::{
    is_tampered,
    tamper_probability: tamper_prob,
    tamper_type,
    tampered_regions,
    confidence,
    analysis_details: details,
  }
}

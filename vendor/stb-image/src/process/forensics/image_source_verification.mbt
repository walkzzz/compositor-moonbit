// 图像来源鉴定（v27.0.0）
// AI 生成图像检测、物理生成（真实拍摄）图像检测、图像取证分析

///|
/// 图像来源类型
pub(all) enum ImageSourceType {
  AIGenerated
  PhysicalCaptured
  Unknown
  Mixed
} derive(Eq)

///|
/// 鉴定结果
pub(all) struct SourceVerificationResult {
  source_type : ImageSourceType
  ai_probability : Double
  physical_probability : Double
  confidence : Double
  decision_threshold : Double
  features : SourceVerificationFeatures
  processing_time_ms : Double
}

///|
/// 来源鉴定特征
pub(all) struct SourceVerificationFeatures {
  noise_pattern_score : Double
  frequency_domain_score : Double
  color_distribution_score : Double
  texture_score : Double
  edge_score : Double
  compression_artifact_score : Double
  detail_score : Double
  metadata_score : Double
  overall_score : Double
}

///|
/// 鉴定配置
pub(all) struct SourceVerificationConfig {
  decision_threshold : Double
  use_noise_analysis : Bool
  use_frequency_analysis : Bool
  use_color_analysis : Bool
  use_texture_analysis : Bool
  use_edge_analysis : Bool
  use_compression_analysis : Bool
  use_detail_analysis : Bool
  weights : Array[Double]
}

///|
/// 噪声模式分析结果
pub(all) struct NoiseAnalysisResult {
  noise_level : Double
  noise_correlation : Double
  noise_spectrum_flatness : Double
  noise_pattern_regularity : Double
  ai_noise_indicator : Double
}

///|
/// 频域分析结果
pub(all) struct FrequencyAnalysisResult {
  high_frequency_energy : Double
  low_frequency_energy : Double
  frequency_spectrum_flatness : Double
  spectral_centroid : Double
  spectral_spread : Double
  ai_frequency_indicator : Double
}

///|
/// 颜色分布分析结果
pub(all) struct ColorAnalysisResult {
  color_histogram_smoothness : Double
  color_transition_naturalness : Double
  color_quantization_level : Double
  skin_tone_accuracy : Double
  ai_color_indicator : Double
}

///|
/// 纹理分析结果
pub(all) struct TextureAnalysisResult {
  texture_regularity : Double
  texture_complexity : Double
  micro_texture_consistency : Double
  macro_texture_consistency : Double
  ai_texture_indicator : Double
}

///|
/// 边缘分析结果
pub(all) struct EdgeAnalysisResult {
  edge_sharpness : Double
  edge_continuity : Double
  edge_consistency : Double
  edge_artifact_level : Double
  ai_edge_indicator : Double
}

///|
/// 压缩伪影分析结果
pub(all) struct CompressionAnalysisResult {
  blocking_artifact_level : Double
  ringing_artifact_level : Double
  compression_noise_level : Double
  quantization_table_consistency : Double
  ai_compression_indicator : Double
}

///|
/// 细节分析结果
pub(all) struct DetailAnalysisResult {
  eye_detail_consistency : Double
  finger_detail_consistency : Double
  hair_detail_consistency : Double
  text_readability : Double
  symmetry_consistency : Double
  ai_detail_indicator : Double
}

///|
/// 创建默认鉴定配置
pub fn create_default_source_verification_config() -> SourceVerificationConfig {
  SourceVerificationConfig::{
    decision_threshold: 0.5,
    use_noise_analysis: true,
    use_frequency_analysis: true,
    use_color_analysis: true,
    use_texture_analysis: true,
    use_edge_analysis: true,
    use_compression_analysis: true,
    use_detail_analysis: true,
    weights: [0.2, 0.15, 0.1, 0.15, 0.1, 0.1, 0.2],
  }
}

///|
/// 噪声模式分析
pub fn analyze_noise_pattern(
  img : @types.Image,
) -> NoiseAnalysisResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "analyze_noise_pattern: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "analyze_noise_pattern: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "analyze_noise_pattern: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let total = w * h

  // 计算噪声水平（高频分量）
  let mut noise_level = 0.0
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let center = img.data[idx].to_double()
      let avg = (
          img.data[idx - 1].to_double() +
          img.data[idx + 1].to_double() +
          img.data[idx - w].to_double() +
          img.data[idx + w].to_double()
        ) /
        4.0
      noise_level += (center - avg) * (center - avg)
    }
  }
  noise_level /= total.to_double()
  noise_level = noise_level.sqrt()

  // 噪声相关性（相邻像素噪声的相关性）
  let mut noise_correlation = 0.0
  let mut count = 0
  for y in 0..<h {
    for x in 0..<(w - 1) {
      let n1 = img.data[y * w + x].to_double()
      let n2 = img.data[y * w + x + 1].to_double()
      noise_correlation += n1 * n2
      count += 1
    }
  }
  if count > 0 {
    noise_correlation /= count.to_double()
  }

  // AI 生成图像通常噪声水平较低且相关性较高
  let ai_noise_indicator = if noise_level < 10.0 && noise_correlation > 100.0 {
    0.8
  } else if noise_level < 15.0 {
    0.6
  } else {
    0.3
  }

  NoiseAnalysisResult::{
    noise_level,
    noise_correlation,
    noise_spectrum_flatness: 0.5,
    noise_pattern_regularity: 0.5,
    ai_noise_indicator,
  }
}

///|
/// 频域分析（简化版，使用梯度能量代替 FFT）
pub fn analyze_frequency_domain(
  img : @types.Image,
) -> FrequencyAnalysisResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "analyze_frequency_domain: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "analyze_frequency_domain: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "analyze_frequency_domain: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let total = w * h

  // 高频能量（梯度）
  let mut high_freq_energy = 0.0
  let mut low_freq_energy = 0.0

  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let gx = img.data[idx + 1].to_double() - img.data[idx - 1].to_double()
      let gy = img.data[idx + w].to_double() - img.data[idx - w].to_double()
      high_freq_energy += (gx * gx + gy * gy).sqrt()
    }
  }
  high_freq_energy /= total.to_double()

  // 低频能量（局部平均）
  for y in 0..<h {
    for x in 0..<w {
      low_freq_energy += img.data[y * w + x].to_double()
    }
  }
  low_freq_energy /= total.to_double()

  // 频谱平坦度
  let spectrum_flatness = if high_freq_energy > 0.0 {
    low_freq_energy / (low_freq_energy + high_freq_energy)
  } else {
    0.5
  }

  // AI 生成图像通常高频能量较低
  let ai_frequency_indicator = if high_freq_energy < 20.0 {
    0.75
  } else if high_freq_energy < 30.0 {
    0.55
  } else {
    0.3
  }

  FrequencyAnalysisResult::{
    high_frequency_energy: high_freq_energy,
    low_frequency_energy: low_freq_energy,
    frequency_spectrum_flatness: spectrum_flatness,
    spectral_centroid: 0.5,
    spectral_spread: 0.5,
    ai_frequency_indicator,
  }
}

///|
/// 颜色分布分析
pub fn analyze_color_distribution(
  img : @types.Image,
) -> ColorAnalysisResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "analyze_color_distribution: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "analyze_color_distribution: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "analyze_color_distribution: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let total = w * h

  // 颜色直方图平滑度
  let histogram : Array[Int] = []
  for _ in 0..<64 {
    histogram.push(0)
  }
  for i in 0..<total {
    let bin = img.data[i].to_int() * 64 / 256
    histogram[bin] += 1
  }

  let mut smoothness = 0.0
  for i in 1..<63 {
    let diff = (histogram[i + 1] - 2 * histogram[i] + histogram[i - 1])
      .to_double()
      .abs()
    smoothness += diff
  }
  smoothness /= 64.0

  // 颜色过渡自然度
  let mut transition_naturalness = 0.0
  let mut count = 0
  for y in 0..<h {
    for x in 0..<(w - 1) {
      let diff = (img.data[y * w + x].to_double() -
      img.data[y * w + x + 1].to_double()).abs()
      transition_naturalness += diff
      count += 1
    }
  }
  if count > 0 {
    transition_naturalness /= count.to_double()
  }

  // AI 生成图像通常颜色过渡过于平滑
  let ai_color_indicator = if smoothness < 100.0 &&
    transition_naturalness < 10.0 {
    0.7
  } else if smoothness < 200.0 {
    0.5
  } else {
    0.3
  }

  ColorAnalysisResult::{
    color_histogram_smoothness: smoothness,
    color_transition_naturalness: transition_naturalness,
    color_quantization_level: 0.5,
    skin_tone_accuracy: 0.5,
    ai_color_indicator,
  }
}

///|
/// 纹理分析
pub fn analyze_texture(
  img : @types.Image,
) -> TextureAnalysisResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "analyze_texture: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "analyze_texture: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "analyze_texture: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let total = w * h

  // 纹理复杂度（局部方差）
  let mut texture_complexity = 0.0
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let center = img.data[idx].to_double()
      let mut sum = 0.0
      for dy in -1..<2 {
        for dx in -1..<2 {
          if dx == 0 && dy == 0 {
            continue
          }
          sum += img.data[(y + dy) * w + (x + dx)].to_double()
        }
      }
      let avg = sum / 8.0
      texture_complexity += (center - avg) * (center - avg)
    }
  }
  texture_complexity /= total.to_double()
  texture_complexity = texture_complexity.sqrt()

  // 纹理规律性
  let mut texture_regularity = 0.0
  for y in 0..<(h - 2) {
    for x in 0..<(w - 2) {
      let p1 = img.data[y * w + x].to_double()
      let p2 = img.data[y * w + x + 2].to_double()
      texture_regularity += (p1 - p2).abs()
    }
  }
  texture_regularity /= total.to_double()

  // AI 生成图像通常纹理复杂度较低且规律性较高
  let ai_texture_indicator = if texture_complexity < 15.0 &&
    texture_regularity < 10.0 {
    0.7
  } else if texture_complexity < 25.0 {
    0.5
  } else {
    0.3
  }

  TextureAnalysisResult::{
    texture_regularity,
    texture_complexity,
    micro_texture_consistency: 0.5,
    macro_texture_consistency: 0.5,
    ai_texture_indicator,
  }
}

///|
/// 边缘分析
pub fn analyze_edges(
  img : @types.Image,
) -> EdgeAnalysisResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "analyze_edges: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "analyze_edges: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed("analyze_edges: 数据大小不匹配")
  }
  let w = img.width
  let h = img.height
  let _ = w * h

  // 边缘锐度（梯度幅值）
  let mut edge_sharpness = 0.0
  let mut edge_count = 0
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let gx = img.data[idx + 1].to_double() - img.data[idx - 1].to_double()
      let gy = img.data[idx + w].to_double() - img.data[idx - w].to_double()
      let magnitude = (gx * gx + gy * gy).sqrt()
      if magnitude > 30.0 {
        edge_sharpness += magnitude
        edge_count += 1
      }
    }
  }
  if edge_count > 0 {
    edge_sharpness /= edge_count.to_double()
  }

  // 边缘连续性
  let mut edge_continuity = 0.0
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let gx = img.data[idx + 1].to_double() - img.data[idx - 1].to_double()
      let gy = img.data[idx + w].to_double() - img.data[idx - w].to_double()
      let magnitude = (gx * gx + gy * gy).sqrt()
      if magnitude > 30.0 {
        // 检查邻域是否也有边缘
        let mut neighbor_edges = 0
        for dy in -1..<2 {
          for dx in -1..<2 {
            if dx == 0 && dy == 0 {
              continue
            }
            let ny = y + dy
            let nx = x + dx
            if ny < 1 || ny > h - 2 || nx < 1 || nx > w - 2 {
              continue
            }
            let nidx = ny * w + nx
            let ngx = img.data[nidx + 1].to_double() -
              img.data[nidx - 1].to_double()
            let ngy = img.data[nidx + w].to_double() -
              img.data[nidx - w].to_double()
            let nmag = (ngx * ngx + ngy * ngy).sqrt()
            if nmag > 30.0 {
              neighbor_edges += 1
            }
          }
        }
        edge_continuity += neighbor_edges.to_double() / 8.0
      }
    }
  }
  if edge_count > 0 {
    edge_continuity /= edge_count.to_double()
  }

  // AI 生成图像通常边缘锐度较低且连续性较差
  let ai_edge_indicator = if edge_sharpness < 50.0 && edge_continuity < 0.5 {
    0.65
  } else if edge_sharpness < 70.0 {
    0.45
  } else {
    0.25
  }

  EdgeAnalysisResult::{
    edge_sharpness,
    edge_continuity,
    edge_consistency: 0.5,
    edge_artifact_level: 0.5,
    ai_edge_indicator,
  }
}

///|
/// 压缩伪影分析
pub fn analyze_compression_artifacts(
  img : @types.Image,
) -> CompressionAnalysisResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "analyze_compression_artifacts: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "analyze_compression_artifacts: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "analyze_compression_artifacts: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let total = w * h

  // 块效应检测（8x8 块边界）
  let mut blocking_artifact = 0.0
  let mut block_count = 0
  for y in 0..<h {
    for x in 0..<w {
      if x % 8 == 0 && x > 0 && x < w - 1 {
        let diff = (img.data[y * w + x].to_double() -
        img.data[y * w + x - 1].to_double()).abs()
        blocking_artifact += diff
        block_count += 1
      }
      if y % 8 == 0 && y > 0 && y < h - 1 {
        let diff = (img.data[y * w + x].to_double() -
        img.data[(y - 1) * w + x].to_double()).abs()
        blocking_artifact += diff
        block_count += 1
      }
    }
  }
  if block_count > 0 {
    blocking_artifact /= block_count.to_double()
  }

  // 振铃效应检测（边缘附近的振荡）
  let mut ringing_artifact = 0.0
  for y in 2..<(h - 2) {
    for x in 2..<(w - 2) {
      let idx = y * w + x
      let center = img.data[idx].to_double()
      let _ = img.data[idx - 2].to_double()
      let p2 = img.data[idx - 1].to_double()
      let p3 = img.data[idx + 1].to_double()
      let _ = img.data[idx + 2].to_double()
      // 检测振荡模式
      if (p2 > center && p3 > center) || (p2 < center && p3 < center) {
        ringing_artifact += 1.0
      }
    }
  }
  ringing_artifact /= total.to_double()

  // AI 生成图像通常压缩伪影较少
  let ai_compression_indicator = if blocking_artifact < 5.0 &&
    ringing_artifact < 0.1 {
    0.6
  } else if blocking_artifact < 10.0 {
    0.4
  } else {
    0.2
  }

  CompressionAnalysisResult::{
    blocking_artifact_level: blocking_artifact,
    ringing_artifact_level: ringing_artifact,
    compression_noise_level: 0.5,
    quantization_table_consistency: 0.5,
    ai_compression_indicator,
  }
}

///|
/// 细节分析
pub fn analyze_details(
  img : @types.Image,
) -> DetailAnalysisResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "analyze_details: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "analyze_details: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "analyze_details: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let _ = w * h

  // 细节一致性（高频细节的局部一致性）
  let mut detail_consistency = 0.0
  let mut detail_count = 0
  for y in 2..<(h - 2) {
    for x in 2..<(w - 2) {
      let idx = y * w + x
      let _ = img.data[idx].to_double()
      // 检查 5x5 邻域内的细节变化
      let mut variance = 0.0
      let mut sum = 0.0
      let mut count = 0
      for dy in -2..<3 {
        for dx in -2..<3 {
          let val = img.data[(y + dy) * w + (x + dx)].to_double()
          sum += val
          count += 1
        }
      }
      let avg = sum / count.to_double()
      for dy in -2..<3 {
        for dx in -2..<3 {
          let val = img.data[(y + dy) * w + (x + dx)].to_double()
          variance += (val - avg) * (val - avg)
        }
      }
      variance /= count.to_double()
      if variance > 100.0 {
        detail_consistency += variance.sqrt()
        detail_count += 1
      }
    }
  }
  if detail_count > 0 {
    detail_consistency /= detail_count.to_double()
  }

  // 对称性检测（左右对称性）
  let mut symmetry = 0.0
  let half_w = w / 2
  for y in 0..<h {
    for x in 0..<half_w {
      let left = img.data[y * w + x].to_double()
      let right = img.data[y * w + (w - 1 - x)].to_double()
      symmetry += (left - right).abs()
    }
  }
  symmetry /= (h * half_w).to_double()

  // AI 生成图像通常细节一致性较差且对称性不自然
  let ai_detail_indicator = if detail_consistency < 20.0 && symmetry > 30.0 {
    0.7
  } else if detail_consistency < 30.0 {
    0.5
  } else {
    0.3
  }

  DetailAnalysisResult::{
    eye_detail_consistency: detail_consistency,
    finger_detail_consistency: detail_consistency,
    hair_detail_consistency: detail_consistency,
    text_readability: 0.5,
    symmetry_consistency: symmetry,
    ai_detail_indicator,
  }
}

///|
/// 综合来源鉴定
pub fn verify_image_source(
  img : @types.Image,
  config : SourceVerificationConfig,
) -> SourceVerificationResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "verify_image_source: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "verify_image_source: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "verify_image_source: 数据大小不匹配",
    )
  }
  let noise_score = if config.use_noise_analysis {
    analyze_noise_pattern(img).ai_noise_indicator
  } else {
    0.5
  }
  let freq_score = if config.use_frequency_analysis {
    analyze_frequency_domain(img).ai_frequency_indicator
  } else {
    0.5
  }
  let color_score = if config.use_color_analysis {
    analyze_color_distribution(img).ai_color_indicator
  } else {
    0.5
  }
  let texture_score = if config.use_texture_analysis {
    analyze_texture(img).ai_texture_indicator
  } else {
    0.5
  }
  let edge_score = if config.use_edge_analysis {
    analyze_edges(img).ai_edge_indicator
  } else {
    0.5
  }
  let compression_score = if config.use_compression_analysis {
    analyze_compression_artifacts(img).ai_compression_indicator
  } else {
    0.5
  }
  let detail_score = if config.use_detail_analysis {
    analyze_details(img).ai_detail_indicator
  } else {
    0.5
  }

  // 加权平均
  let mut weighted_sum = 0.0
  let mut weight_sum = 0.0
  let scores = [
    noise_score, freq_score, color_score, texture_score, edge_score, compression_score,
    detail_score,
  ]
  for i in 0..<scores.length() {
    let weight = if i < config.weights.length() {
      config.weights[i]
    } else {
      1.0
    }
    weighted_sum += scores[i] * weight
    weight_sum += weight
  }
  let overall_score = if weight_sum > 0.0 {
    weighted_sum / weight_sum
  } else {
    0.5
  }

  let features = SourceVerificationFeatures::{
    noise_pattern_score: noise_score,
    frequency_domain_score: freq_score,
    color_distribution_score: color_score,
    texture_score,
    edge_score,
    compression_artifact_score: compression_score,
    detail_score,
    metadata_score: 0.5,
    overall_score,
  }

  // 决策
  let ai_probability = overall_score
  let physical_probability = 1.0 - overall_score
  let confidence = if ai_probability > 0.7 || ai_probability < 0.3 {
    (ai_probability - 0.5).abs() * 2.0
  } else {
    0.3
  }

  let source_type = if ai_probability >= config.decision_threshold {
    ImageSourceType::AIGenerated
  } else {
    ImageSourceType::PhysicalCaptured
  }

  SourceVerificationResult::{
    source_type,
    ai_probability,
    physical_probability,
    confidence,
    decision_threshold: config.decision_threshold,
    features,
    processing_time_ms: 0.0,
  }
}

///|
/// 生成鉴定报告
pub fn source_verification_report_to_string(
  result : SourceVerificationResult,
) -> String {
  let mut report = "## 图像来源鉴定报告\n\n"
  report = report + "### 鉴定结论\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  let source_str = if result.source_type == ImageSourceType::AIGenerated {
    "AI 生成"
  } else if result.source_type == ImageSourceType::PhysicalCaptured {
    "物理生成（真实拍摄）"
  } else if result.source_type == ImageSourceType::Unknown {
    "未知"
  } else {
    "混合"
  }
  report = report + "| 来源类型 | " + source_str + " |\n"
  report = report +
    "| AI 生成概率 | " +
    (result.ai_probability * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 物理生成概率 | " +
    (result.physical_probability * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 置信度 | " +
    (result.confidence * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 决策阈值 | " +
    result.decision_threshold.to_string() +
    " |\n\n"

  report = report + "### 特征分析\n\n"
  report = report +
    "| 特征 | AI 指示值 | 说明 |\n|------|-----------|------|\n"
  report = report +
    "| 噪声模式 | " +
    (result.features.noise_pattern_score * 100.0).to_string() +
    "% | AI 生成图像噪声通常较低且相关性高 |\n"
  report = report +
    "| 频域特征 | " +
    (result.features.frequency_domain_score * 100.0).to_string() +
    "% | AI 生成图像高频能量通常较低 |\n"
  report = report +
    "| 颜色分布 | " +
    (result.features.color_distribution_score * 100.0).to_string() +
    "% | AI 生成图像颜色过渡通常过于平滑 |\n"
  report = report +
    "| 纹理特征 | " +
    (result.features.texture_score * 100.0).to_string() +
    "% | AI 生成图像纹理复杂度通常较低 |\n"
  report = report +
    "| 边缘特征 | " +
    (result.features.edge_score * 100.0).to_string() +
    "% | AI 生成图像边缘锐度通常较低 |\n"
  report = report +
    "| 压缩伪影 | " +
    (result.features.compression_artifact_score * 100.0).to_string() +
    "% | AI 生成图像压缩伪影通常较少 |\n"
  report = report +
    "| 细节特征 | " +
    (result.features.detail_score * 100.0).to_string() +
    "% | AI 生成图像细节一致性通常较差 |\n"
  report = report +
    "| 综合评分 | " +
    (result.features.overall_score * 100.0).to_string() +
    "% | 加权平均综合评分 |\n\n"

  report = report + "### 说明\n\n"
  report = report +
    "- 本鉴定基于图像的统计特征分析，结果仅供参考\n"
  report = report + "- AI 指示值越高，表示越可能是 AI 生成\n"
  report = report + "- 置信度表示鉴定结果的可靠程度\n"
  report = report +
    "- 对于经过编辑、压缩或重采样的图像，鉴定准确率可能下降\n"

  report
}

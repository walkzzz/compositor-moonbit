// 图像风格迁移增强（v24.0.0）
// 图像风格迁移、艺术风格化、颜色转移、纹理合成

///|
/// 风格迁移算法类型
pub(all) enum StyleTransferAlgorithm {
  ColorTransfer
  TextureSynthesis
  NeuralStyle
  FastStyle
  CycleGAN
  AdaIN
  Cartoon
  OilPainting
  Watercolor
  Sketch
  Unknown
} derive(Eq)

///|
/// 风格迁移结果
pub(all) struct StyleTransferResult {
  image : @types.Image
  content_image_path : String
  style_image_path : String
  algorithm : StyleTransferAlgorithm
  style_strength : Double
  content_strength : Double
  processing_time_ms : Double
  iterations : Int
}

///|
/// 风格迁移配置
pub(all) struct StyleTransferConfig {
  algorithm : StyleTransferAlgorithm
  style_strength : Double
  content_strength : Double
  iterations : Int
  learning_rate : Double
  use_color_preservation : Bool
  resolution : Int
}

///|
/// 颜色统计信息
pub(all) struct ColorStatistics {
  mean_r : Double
  mean_g : Double
  mean_b : Double
  std_r : Double
  std_g : Double
  std_b : Double
  min_r : Double
  min_g : Double
  min_b : Double
  max_r : Double
  max_g : Double
  max_b : Double
}

///|
/// 纹理特征
pub(all) struct StyleTransferTextureFeatures {
  contrast : Double
  homogeneity : Double
  energy : Double
  correlation : Double
  entropy : Double
  coarseness : Double
  directionality : Double
  regularity : Double
}

///|
/// 艺术风格类型
pub(all) enum ArtStyle {
  Impressionist
  Cubist
  Surrealist
  Abstract
  PopArt
  Minimalist
  Baroque
  Renaissance
  Modern
  Contemporary
  Unknown
} derive(Eq)

///|
/// 创建默认风格迁移配置
pub fn create_default_style_transfer_config() -> StyleTransferConfig {
  StyleTransferConfig::{
    algorithm: StyleTransferAlgorithm::ColorTransfer,
    style_strength: 0.5,
    content_strength: 0.5,
    iterations: 100,
    learning_rate: 0.01,
    use_color_preservation: true,
    resolution: 512,
  }
}

///|
/// 计算颜色统计信息
pub fn calculate_color_statistics(
  img : @types.Image,
) -> ColorStatistics raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "calculate_color_statistics: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "calculate_color_statistics: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "calculate_color_statistics: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let total = w * h
  let mut sum_r = 0.0
  let mut sum_g = 0.0
  let mut sum_b = 0.0
  let mut min_r = 255.0
  let mut min_g = 255.0
  let mut min_b = 255.0
  let mut max_r = 0.0
  let mut max_g = 0.0
  let mut max_b = 0.0

  for i in 0..<total {
    let pixel = img.data[i].to_double()
    // 简化：单通道灰度
    sum_r += pixel
    sum_g += pixel
    sum_b += pixel
    if pixel < min_r {
      min_r = pixel
    }
    if pixel < min_g {
      min_g = pixel
    }
    if pixel < min_b {
      min_b = pixel
    }
    if pixel > max_r {
      max_r = pixel
    }
    if pixel > max_g {
      max_g = pixel
    }
    if pixel > max_b {
      max_b = pixel
    }
  }

  let mean_r = sum_r / total.to_double()
  let mean_g = sum_g / total.to_double()
  let mean_b = sum_b / total.to_double()

  let mut var_r = 0.0
  let mut var_g = 0.0
  let mut var_b = 0.0
  for i in 0..<total {
    let pixel = img.data[i].to_double()
    var_r += (pixel - mean_r) * (pixel - mean_r)
    var_g += (pixel - mean_g) * (pixel - mean_g)
    var_b += (pixel - mean_b) * (pixel - mean_b)
  }
  var_r /= total.to_double()
  var_g /= total.to_double()
  var_b /= total.to_double()

  ColorStatistics::{
    mean_r,
    mean_g,
    mean_b,
    std_r: var_r.sqrt(),
    std_g: var_g.sqrt(),
    std_b: var_b.sqrt(),
    min_r,
    min_g,
    min_b,
    max_r,
    max_g,
    max_b,
  }
}

///|
/// 颜色转移（Reinhard 方法）
pub fn color_transfer(
  content : @types.Image,
  style : @types.Image,
  strength : Double,
) -> @types.Image raise @types.LoadError {
  // 输入验证：content
  if content.width <= 0 || content.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "color_transfer: 图像尺寸必须大于0",
    )
  }
  if content.channels < 1 || content.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "color_transfer: 通道数必须在1-4之间",
    )
  }
  let content_expected = content.width * content.height * content.channels
  if content.data.length() != content_expected {
    raise @types.LoadError::DecodeFailed(
      "color_transfer: 数据大小不匹配",
    )
  }
  // 输入验证：style
  if style.width <= 0 || style.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "color_transfer: 图像尺寸必须大于0",
    )
  }
  if style.channels < 1 || style.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "color_transfer: 通道数必须在1-4之间",
    )
  }
  let style_expected = style.width * style.height * style.channels
  if style.data.length() != style_expected {
    raise @types.LoadError::DecodeFailed(
      "color_transfer: 数据大小不匹配",
    )
  }
  let content_stats = calculate_color_statistics(content)
  let style_stats = calculate_color_statistics(style)

  let w = content.width
  let h = content.height
  let total = w * h
  let out : Array[Byte] = []

  for i in 0..<total {
    let pixel = content.data[i].to_double()
    // 标准化
    let normalized = if content_stats.std_r > 0.0 {
      (pixel - content_stats.mean_r) / content_stats.std_r
    } else {
      0.0
    }
    // 转移到风格分布
    let transferred = normalized * style_stats.std_r + style_stats.mean_r
    // 混合
    let blended = pixel * (1.0 - strength) + transferred * strength
    let clamped = if blended < 0.0 {
      0.0
    } else if blended > 255.0 {
      255.0
    } else {
      blended
    }
    out.push(clamped.to_int().to_byte())
  }

  @types.Image::{
    width: w,
    height: h,
    channels: content.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 计算纹理特征（GLCM 简化版）
pub fn calculate_texture_features(
  img : @types.Image,
) -> StyleTransferTextureFeatures raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "calculate_texture_features: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "calculate_texture_features: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "calculate_texture_features: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let _ = w * h

  // 计算灰度共生矩阵（简化：水平方向）
  let glcm_size = 16
  let glcm : Array[Double] = []
  for _ in 0..<(glcm_size * glcm_size) {
    glcm.push(0.0)
  }

  for y in 0..<h {
    for x in 0..<(w - 1) {
      let i = img.data[y * w + x].to_int() * glcm_size / 256 % glcm_size
      let j = img.data[y * w + x + 1].to_int() * glcm_size / 256 % glcm_size
      glcm[i * glcm_size + j] += 1.0
    }
  }

  // 归一化
  let glcm_total = (w - 1) * h
  if glcm_total > 0 {
    for i in 0..<(glcm_size * glcm_size) {
      glcm[i] /= glcm_total.to_double()
    }
  }

  // 计算特征
  let mut contrast = 0.0
  let mut homogeneity = 0.0
  let mut energy = 0.0
  let mut correlation = 0.0
  let mut entropy = 0.0

  let mut mean_i = 0.0
  let mut mean_j = 0.0
  for i in 0..<glcm_size {
    for j in 0..<glcm_size {
      let p = glcm[i * glcm_size + j]
      mean_i += i.to_double() * p
      mean_j += j.to_double() * p
    }
  }

  for i in 0..<glcm_size {
    for j in 0..<glcm_size {
      let p = glcm[i * glcm_size + j]
      let diff = (i - j).to_double()
      contrast += diff * diff * p
      homogeneity += p / (1.0 + diff * diff)
      energy += p * p
      correlation += (i.to_double() - mean_i) * (j.to_double() - mean_j) * p
      if p > 0.0 {
        entropy -= p * p * 0.1
      }
    }
  }

  StyleTransferTextureFeatures::{
    contrast,
    homogeneity,
    energy,
    correlation,
    entropy,
    coarseness: 1.0 / (1.0 + contrast),
    directionality: 0.5,
    regularity: homogeneity * energy,
  }
}

///|
/// 卡通化效果
pub fn cartoonize(
  img : @types.Image,
  strength : Double,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "cartoonize: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "cartoonize: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed("cartoonize: 数据大小不匹配")
  }
  let w = img.width
  let h = img.height
  let _ = w * h
  let out : Array[Byte] = []

  // 简化：边缘检测 + 色彩量化
  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      let center = img.data[idx].to_double()

      // 边缘检测（Sobel 简化）
      let mut gx = 0.0
      let mut gy = 0.0
      if x > 0 && x < w - 1 && y > 0 && y < h - 1 {
        gx = img.data[(y + 1) * w + (x - 1)].to_double() +
          2.0 * img.data[y * w + (x - 1)].to_double() +
          img.data[(y - 1) * w + (x - 1)].to_double() -
          img.data[(y + 1) * w + (x + 1)].to_double() -
          2.0 * img.data[y * w + (x + 1)].to_double() -
          img.data[(y - 1) * w + (x + 1)].to_double()
        gy = img.data[(y - 1) * w + (x + 1)].to_double() +
          2.0 * img.data[(y - 1) * w + x].to_double() +
          img.data[(y - 1) * w + (x - 1)].to_double() -
          img.data[(y + 1) * w + (x + 1)].to_double() -
          2.0 * img.data[(y + 1) * w + x].to_double() -
          img.data[(y + 1) * w + (x - 1)].to_double()
      }
      let edge = (gx * gx + gy * gy).sqrt()

      // 色彩量化（减少色阶）
      let levels = 8.0
      let quantized = (center / 255.0 * levels).to_int().to_double() /
        levels *
        255.0

      // 混合：边缘变暗，量化色彩
      let edge_factor = if edge > 30.0 { strength } else { 0.0 }
      let result = quantized * (1.0 - edge_factor) + 0.0 * edge_factor
      let clamped = if result < 0.0 {
        0.0
      } else if result > 255.0 {
        255.0
      } else {
        result
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
/// 油画效果
pub fn oil_painting(
  img : @types.Image,
  radius : Int,
  intensity_levels : Int,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "oil_painting: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "oil_painting: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed("oil_painting: 数据大小不匹配")
  }
  let w = img.width
  let h = img.height
  let _ = w * h
  let out : Array[Byte] = []

  for y in 0..<h {
    for x in 0..<w {
      // 统计邻域内的强度直方图
      let histogram : Array[Int] = []
      let sum_histogram : Array[Double] = []
      for _ in 0..<intensity_levels {
        histogram.push(0)
        sum_histogram.push(0.0)
      }

      for dy in -radius..<(radius + 1) {
        for dx in -radius..<(radius + 1) {
          let nx = x + dx
          let ny = y + dy
          if nx >= 0 && nx < w && ny >= 0 && ny < h {
            let pixel = img.data[ny * w + nx].to_double()
            let level = (pixel / 255.0 * intensity_levels.to_double()).to_int()
            let clamped_level = if level < 0 {
              0
            } else if level >= intensity_levels {
              intensity_levels - 1
            } else {
              level
            }
            histogram[clamped_level] += 1
            sum_histogram[clamped_level] += pixel
          }
        }
      }

      // 找到最频繁的强度级别
      let mut max_count = 0
      let mut max_level = 0
      for i in 0..<intensity_levels {
        if histogram[i] > max_count {
          max_count = histogram[i]
          max_level = i
        }
      }

      // 输出该级别的平均值
      let result = if max_count > 0 {
        sum_histogram[max_level] / max_count.to_double()
      } else {
        img.data[y * w + x].to_double()
      }
      let clamped = if result < 0.0 {
        0.0
      } else if result > 255.0 {
        255.0
      } else {
        result
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
/// 素描效果
pub fn sketch_effect(
  img : @types.Image,
  strength : Double,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "sketch_effect: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "sketch_effect: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed("sketch_effect: 数据大小不匹配")
  }
  let w = img.width
  let h = img.height
  let _ = w * h
  let out : Array[Byte] = []

  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      let _ = img.data[idx].to_double()

      // 边缘检测
      let mut gx = 0.0
      let mut gy = 0.0
      if x > 0 && x < w - 1 && y > 0 && y < h - 1 {
        gx = img.data[(y + 1) * w + (x - 1)].to_double() +
          2.0 * img.data[y * w + (x - 1)].to_double() +
          img.data[(y - 1) * w + (x - 1)].to_double() -
          img.data[(y + 1) * w + (x + 1)].to_double() -
          2.0 * img.data[y * w + (x + 1)].to_double() -
          img.data[(y - 1) * w + (x + 1)].to_double()
        gy = img.data[(y - 1) * w + (x + 1)].to_double() +
          2.0 * img.data[(y - 1) * w + x].to_double() +
          img.data[(y - 1) * w + (x - 1)].to_double() -
          img.data[(y + 1) * w + (x + 1)].to_double() -
          2.0 * img.data[(y + 1) * w + x].to_double() -
          img.data[(y + 1) * w + (x - 1)].to_double()
      }
      let edge = (gx * gx + gy * gy).sqrt()

      // 反色：边缘为黑色，背景为白色
      let sketch_value = 255.0 - edge * strength
      let clamped = if sketch_value < 0.0 {
        0.0
      } else if sketch_value > 255.0 {
        255.0
      } else {
        sketch_value
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
/// 风格迁移处理
pub fn style_transfer(
  content : @types.Image,
  style : @types.Image,
  config : StyleTransferConfig,
) -> StyleTransferResult raise @types.LoadError {
  // 输入验证：content
  if content.width <= 0 || content.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "style_transfer: 图像尺寸必须大于0",
    )
  }
  if content.channels < 1 || content.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "style_transfer: 通道数必须在1-4之间",
    )
  }
  let content_expected = content.width * content.height * content.channels
  if content.data.length() != content_expected {
    raise @types.LoadError::DecodeFailed(
      "style_transfer: 数据大小不匹配",
    )
  }
  // 输入验证：style
  if style.width <= 0 || style.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "style_transfer: 图像尺寸必须大于0",
    )
  }
  if style.channels < 1 || style.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "style_transfer: 通道数必须在1-4之间",
    )
  }
  let style_expected = style.width * style.height * style.channels
  if style.data.length() != style_expected {
    raise @types.LoadError::DecodeFailed(
      "style_transfer: 数据大小不匹配",
    )
  }
  let result = if config.algorithm == StyleTransferAlgorithm::ColorTransfer {
    color_transfer(content, style, config.style_strength)
  } else if config.algorithm == StyleTransferAlgorithm::Cartoon {
    cartoonize(content, config.style_strength)
  } else if config.algorithm == StyleTransferAlgorithm::OilPainting {
    oil_painting(content, 3, 8)
  } else if config.algorithm == StyleTransferAlgorithm::Sketch {
    sketch_effect(content, config.style_strength)
  } else {
    color_transfer(content, style, config.style_strength)
  }

  StyleTransferResult::{
    image: result,
    content_image_path: "",
    style_image_path: "",
    algorithm: config.algorithm,
    style_strength: config.style_strength,
    content_strength: config.content_strength,
    processing_time_ms: 0.0,
    iterations: config.iterations,
  }
}

///|
/// 生成风格迁移报告
pub fn style_transfer_report_to_string(
  result : StyleTransferResult,
  content_stats : ColorStatistics,
  style_stats : ColorStatistics,
  texture : StyleTransferTextureFeatures,
) -> String {
  let mut report = "## 图像风格迁移报告\n\n"
  report = report + "### 处理信息\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  let algo_str = if result.algorithm == StyleTransferAlgorithm::ColorTransfer {
    "颜色转移"
  } else if result.algorithm == StyleTransferAlgorithm::TextureSynthesis {
    "纹理合成"
  } else if result.algorithm == StyleTransferAlgorithm::NeuralStyle {
    "神经风格"
  } else if result.algorithm == StyleTransferAlgorithm::FastStyle {
    "快速风格"
  } else if result.algorithm == StyleTransferAlgorithm::CycleGAN {
    "CycleGAN"
  } else if result.algorithm == StyleTransferAlgorithm::AdaIN {
    "AdaIN"
  } else if result.algorithm == StyleTransferAlgorithm::Cartoon {
    "卡通化"
  } else if result.algorithm == StyleTransferAlgorithm::OilPainting {
    "油画"
  } else if result.algorithm == StyleTransferAlgorithm::Watercolor {
    "水彩"
  } else if result.algorithm == StyleTransferAlgorithm::Sketch {
    "素描"
  } else {
    "未知"
  }
  report = report + "| 算法 | " + algo_str + " |\n"
  report = report +
    "| 风格强度 | " +
    result.style_strength.to_string() +
    " |\n"
  report = report +
    "| 内容强度 | " +
    result.content_strength.to_string() +
    " |\n"
  report = report + "| 迭代次数 | " + result.iterations.to_string() + " |\n"
  report = report +
    "| 处理耗时 | " +
    result.processing_time_ms.to_string() +
    "ms |\n\n"

  report = report + "### 颜色统计\n\n"
  report = report +
    "| 指标 | 内容图 | 风格图 |\n|------|--------|--------|\n"
  report = report +
    "| 均值 | " +
    content_stats.mean_r.to_string() +
    " | " +
    style_stats.mean_r.to_string() +
    " |\n"
  report = report +
    "| 标准差 | " +
    content_stats.std_r.to_string() +
    " | " +
    style_stats.std_r.to_string() +
    " |\n"
  report = report +
    "| 最小值 | " +
    content_stats.min_r.to_string() +
    " | " +
    style_stats.min_r.to_string() +
    " |\n"
  report = report +
    "| 最大值 | " +
    content_stats.max_r.to_string() +
    " | " +
    style_stats.max_r.to_string() +
    " |\n\n"

  report = report + "### 纹理特征\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report + "| 对比度 | " + texture.contrast.to_string() + " |\n"
  report = report + "| 同质性 | " + texture.homogeneity.to_string() + " |\n"
  report = report + "| 能量 | " + texture.energy.to_string() + " |\n"
  report = report + "| 相关性 | " + texture.correlation.to_string() + " |\n"
  report = report + "| 熵 | " + texture.entropy.to_string() + " |\n"
  report = report + "| 粗糙度 | " + texture.coarseness.to_string() + " |\n"

  report
}

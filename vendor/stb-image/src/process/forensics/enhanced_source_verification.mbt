// 图像来源鉴定增强（v27.1.0）
// 增强准确性：UI 元素检测、文字区域检测、几何形状分析、颜色量化分析、智能决策引擎

///|
/// 增强鉴定结果
pub(all) struct EnhancedVerificationResult {
  source_type : ImageSourceType
  ai_probability : Double
  physical_probability : Double
  confidence : Double
  decision_threshold : Double
  basic_features : SourceVerificationFeatures
  enhanced_features : EnhancedVerificationFeatures
  ui_detection : UIDetectionResult
  text_detection : TextDetectionResult
  geometry_analysis : GeometryAnalysisResult
  color_quantization : ColorQuantizationResult
  decision_reason : String
  processing_time_ms : Double
}

///|
/// 增强鉴定特征
pub(all) struct EnhancedVerificationFeatures {
  ui_indicator : Double
  text_indicator : Double
  geometry_indicator : Double
  color_quantization_indicator : Double
  solid_area_indicator : Double
  edge_direction_indicator : Double
  pixel_distribution_indicator : Double
  overall_enhanced_score : Double
}

///|
/// UI 检测结果
pub(all) struct UIDetectionResult {
  has_window_border : Bool
  has_toolbar : Bool
  has_button_like_elements : Bool
  ui_element_count : Int
  ui_area_ratio : Double
  horizontal_line_count : Int
  vertical_line_count : Int
  ui_indicator : Double
}

///|
/// 文字检测结果
pub(all) struct TextDetectionResult {
  text_area_count : Int
  text_area_ratio : Double
  dense_edge_region_count : Int
  small_edge_density : Double
  text_like_region_ratio : Double
  text_indicator : Double
}

///|
/// 几何分析结果
pub(all) struct GeometryAnalysisResult {
  horizontal_edge_ratio : Double
  vertical_edge_ratio : Double
  diagonal_edge_ratio : Double
  rectangle_like_region_count : Int
  straight_line_count : Int
  geometry_regularity : Double
  geometry_indicator : Double
}

///|
/// 颜色量化结果
pub(all) struct ColorQuantizationResult {
  unique_color_count : Int
  color_quantization_level : Double
  top_color_ratio : Double
  top_10_color_ratio : Double
  color_palette_size : Int
  color_quantization_indicator : Double
}

///|
/// 增强鉴定配置
pub(all) struct EnhancedVerificationConfig {
  use_ui_detection : Bool
  use_text_detection : Bool
  use_geometry_analysis : Bool
  use_color_quantization : Bool
  use_solid_area_analysis : Bool
  use_edge_direction_analysis : Bool
  basic_weight : Double
  enhanced_weight : Double
  decision_threshold : Double
}

///|
/// 创建默认增强鉴定配置
pub fn create_default_enhanced_verification_config() -> EnhancedVerificationConfig {
  EnhancedVerificationConfig::{
    use_ui_detection: true,
    use_text_detection: true,
    use_geometry_analysis: true,
    use_color_quantization: true,
    use_solid_area_analysis: true,
    use_edge_direction_analysis: true,
    basic_weight: 0.4,
    enhanced_weight: 0.6,
    decision_threshold: 0.5,
  }
}

///|
/// UI 元素检测
pub fn detect_ui_elements(
  img : @types.Image,
) -> UIDetectionResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_ui_elements: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "detect_ui_elements: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "detect_ui_elements: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let total = w * h

  // 检测水平长线（窗口边框、工具栏分隔线）
  let mut horizontal_lines = 0
  for y in 0..<h {
    let mut run_length = 0
    for x in 0..<w {
      let idx = y * w + x
      // 检测边缘像素
      let is_edge = if x > 0 && x < w - 1 {
        let diff = (img.data[idx].to_double() - img.data[idx - 1].to_double()).abs()
        diff > 20.0
      } else {
        false
      }
      if is_edge {
        run_length += 1
      } else {
        if run_length > w / 4 {
          horizontal_lines += 1
        }
        run_length = 0
      }
    }
    if run_length > w / 4 {
      horizontal_lines += 1
    }
  }

  // 检测垂直长线
  let mut vertical_lines = 0
  for x in 0..<w {
    let mut run_length = 0
    for y in 0..<h {
      let idx = y * w + x
      let is_edge = if y > 0 && y < h - 1 {
        let diff = (img.data[idx].to_double() - img.data[idx - w].to_double()).abs()
        diff > 20.0
      } else {
        false
      }
      if is_edge {
        run_length += 1
      } else {
        if run_length > h / 4 {
          vertical_lines += 1
        }
        run_length = 0
      }
    }
    if run_length > h / 4 {
      vertical_lines += 1
    }
  }

  // 检测窗口边框（图像四周的边框）
  let has_window_border = horizontal_lines >= 2 && vertical_lines >= 2

  // 检测工具栏（顶部的密集水平线条区域）
  let has_toolbar = horizontal_lines >= 3

  // UI 区域比例（有边缘的区域比例）
  let mut ui_area = 0
  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      let mut has_edge = false
      if x > 0 && x < w - 1 {
        if (img.data[idx].to_double() - img.data[idx - 1].to_double()).abs() >
          20.0 {
          has_edge = true
        }
      }
      if y > 0 && y < h - 1 {
        if (img.data[idx].to_double() - img.data[idx - w].to_double()).abs() >
          20.0 {
          has_edge = true
        }
      }
      if has_edge {
        ui_area += 1
      }
    }
  }
  let ui_area_ratio = ui_area.to_double() / total.to_double()

  // 按钮状元素检测（小矩形区域）
  let button_like = horizontal_lines >= 4 && vertical_lines >= 4

  // UI 指示值：UI 元素越多，越可能是屏幕截图（物理生成）
  let ui_indicator = if has_window_border && has_toolbar {
    0.9
  } else if horizontal_lines >= 3 || vertical_lines >= 3 {
    0.7
  } else if horizontal_lines >= 2 || vertical_lines >= 2 {
    0.5
  } else {
    0.2
  }

  UIDetectionResult::{
    has_window_border,
    has_toolbar,
    has_button_like_elements: button_like,
    ui_element_count: horizontal_lines + vertical_lines,
    ui_area_ratio,
    horizontal_line_count: horizontal_lines,
    vertical_line_count: vertical_lines,
    ui_indicator,
  }
}

///|
/// 文字区域检测
pub fn detect_text_regions(
  img : @types.Image,
) -> TextDetectionResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_text_regions: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "detect_text_regions: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "detect_text_regions: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let total = w * h

  // 检测密集小边缘区域（文字特征）
  let mut dense_edge_regions = 0
  let block_size = 16
  let blocks_x = w / block_size
  let blocks_y = h / block_size

  for by in 0..<blocks_y {
    for bx in 0..<blocks_x {
      let mut edge_count = 0
      for y in 0..<block_size {
        for x in 0..<block_size {
          let px = bx * block_size + x
          let py = by * block_size + y
          if px > 0 && px < w - 1 && py > 0 && py < h - 1 {
            let idx = py * w + px
            let gx = (img.data[idx + 1].to_double() -
            img.data[idx - 1].to_double()).abs()
            let gy = (img.data[idx + w].to_double() -
            img.data[idx - w].to_double()).abs()
            if gx > 15.0 || gy > 15.0 {
              edge_count += 1
            }
          }
        }
      }
      let edge_density = edge_count.to_double() /
        (block_size * block_size).to_double()
      // 文字区域通常边缘密度在 0.15-0.5 之间
      if edge_density > 0.15 && edge_density < 0.6 {
        dense_edge_regions += 1
      }
    }
  }

  let text_area_ratio = dense_edge_regions.to_double() /
    (blocks_x * blocks_y).to_double()

  // 小边缘密度（全局）
  let mut small_edges = 0
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let gx = (img.data[idx + 1].to_double() - img.data[idx - 1].to_double()).abs()
      let gy = (img.data[idx + w].to_double() - img.data[idx - w].to_double()).abs()
      let mag = (gx * gx + gy * gy).sqrt()
      if mag > 10.0 && mag < 80.0 {
        small_edges += 1
      }
    }
  }
  let small_edge_density = small_edges.to_double() / total.to_double()

  // 文字指示值：文字区域越多，越可能是屏幕截图（物理生成）
  let text_indicator = if text_area_ratio > 0.15 {
    0.85
  } else if text_area_ratio > 0.08 {
    0.65
  } else if text_area_ratio > 0.03 {
    0.45
  } else {
    0.2
  }

  TextDetectionResult::{
    text_area_count: dense_edge_regions,
    text_area_ratio,
    dense_edge_region_count: dense_edge_regions,
    small_edge_density,
    text_like_region_ratio: text_area_ratio,
    text_indicator,
  }
}

///|
/// 几何形状分析
pub fn analyze_geometry(
  img : @types.Image,
) -> GeometryAnalysisResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "analyze_geometry: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "analyze_geometry: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "analyze_geometry: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height

  // 边缘方向分析
  let mut horizontal_edges = 0
  let mut vertical_edges = 0
  let mut diagonal_edges = 0
  let mut total_edges = 0

  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let gx = img.data[idx + 1].to_double() - img.data[idx - 1].to_double()
      let gy = img.data[idx + w].to_double() - img.data[idx - w].to_double()
      let mag = (gx * gx + gy * gy).sqrt()
      if mag > 20.0 {
        total_edges += 1
        let abs_gx = gx.abs()
        let abs_gy = gy.abs()
        if abs_gx > abs_gy * 2.0 {
          horizontal_edges += 1
        } else if abs_gy > abs_gx * 2.0 {
          vertical_edges += 1
        } else {
          diagonal_edges += 1
        }
      }
    }
  }

  let horizontal_ratio = if total_edges > 0 {
    horizontal_edges.to_double() / total_edges.to_double()
  } else {
    0.0
  }
  let vertical_ratio = if total_edges > 0 {
    vertical_edges.to_double() / total_edges.to_double()
  } else {
    0.0
  }
  let diagonal_ratio = if total_edges > 0 {
    diagonal_edges.to_double() / total_edges.to_double()
  } else {
    0.0
  }

  // 几何规则性：水平+垂直边缘比例越高，越规则（UI 界面特征）
  let geometry_regularity = horizontal_ratio + vertical_ratio

  // 矩形状区域检测（规则的水平垂直线条交叉）
  let rectangle_regions = if geometry_regularity > 0.7 {
    total_edges / 100
  } else {
    0
  }

  // 几何指示值：几何越规则，越可能是屏幕截图（物理生成）
  let geometry_indicator = if geometry_regularity > 0.8 {
    0.85
  } else if geometry_regularity > 0.65 {
    0.65
  } else if geometry_regularity > 0.5 {
    0.45
  } else {
    0.25
  }

  GeometryAnalysisResult::{
    horizontal_edge_ratio: horizontal_ratio,
    vertical_edge_ratio: vertical_ratio,
    diagonal_edge_ratio: diagonal_ratio,
    rectangle_like_region_count: rectangle_regions,
    straight_line_count: horizontal_edges + vertical_edges,
    geometry_regularity,
    geometry_indicator,
  }
}

///|
/// 颜色量化分析
pub fn analyze_color_quantization(
  img : @types.Image,
) -> ColorQuantizationResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "analyze_color_quantization: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "analyze_color_quantization: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "analyze_color_quantization: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let total = w * h

  // 统计唯一颜色数量（量化到 64 级）
  let color_histogram : Array[Int] = []
  for _ in 0..<64 {
    color_histogram.push(0)
  }
  for i in 0..<total {
    let bin = img.data[i].to_int() * 64 / 256
    color_histogram[bin] += 1
  }

  let mut unique_colors = 0
  for i in 0..<64 {
    if color_histogram[i] > 0 {
      unique_colors += 1
    }
  }

  // 顶部颜色比例
  let sorted_colors : Array[Int] = []
  for i in 0..<64 {
    sorted_colors.push(color_histogram[i])
  }
  // 冒泡排序
  for i in 0..<64 {
    for j in 0..<(64 - i - 1) {
      if sorted_colors[j] < sorted_colors[j + 1] {
        let temp = sorted_colors[j]
        sorted_colors[j] = sorted_colors[j + 1]
        sorted_colors[j + 1] = temp
      }
    }
  }

  let top_color_ratio = if total > 0 {
    sorted_colors[0].to_double() / total.to_double()
  } else {
    0.0
  }
  let mut top_10_sum = 0
  for i in 0..<10 {
    top_10_sum += sorted_colors[i]
  }
  let top_10_ratio = if total > 0 {
    top_10_sum.to_double() / total.to_double()
  } else {
    0.0
  }

  // 颜色量化级别：唯一颜色越少，量化越严重（UI 界面特征）
  let quantization_level = 1.0 - unique_colors.to_double() / 64.0

  // 颜色调色板大小（估计）
  let palette_size = unique_colors

  // 颜色量化指示值：颜色越集中，越可能是屏幕截图（物理生成）
  let color_quantization_indicator = if top_10_ratio > 0.8 {
    0.85
  } else if top_10_ratio > 0.65 {
    0.65
  } else if top_10_ratio > 0.5 {
    0.45
  } else {
    0.25
  }

  ColorQuantizationResult::{
    unique_color_count: unique_colors,
    color_quantization_level: quantization_level,
    top_color_ratio,
    top_10_color_ratio: top_10_ratio,
    color_palette_size: palette_size,
    color_quantization_indicator,
  }
}

///|
/// 纯色区域分析
pub fn analyze_solid_areas(img : @types.Image) -> Double raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "analyze_solid_areas: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "analyze_solid_areas: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "analyze_solid_areas: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let _ = w * h
  let block_size = 8
  let mut solid_blocks = 0
  let total_blocks = w / block_size * (h / block_size)

  for by in 0..<(h / block_size) {
    for bx in 0..<(w / block_size) {
      let mut min_val = 255
      let mut max_val = 0
      for y in 0..<block_size {
        for x in 0..<block_size {
          let px = bx * block_size + x
          let py = by * block_size + y
          let val = img.data[py * w + px].to_int()
          if val < min_val {
            min_val = val
          }
          if val > max_val {
            max_val = val
          }
        }
      }
      if max_val - min_val < 10 {
        solid_blocks += 1
      }
    }
  }

  let solid_ratio = if total_blocks > 0 {
    solid_blocks.to_double() / total_blocks.to_double()
  } else {
    0.0
  }

  // 纯色区域指示值：纯色区域越多，越可能是屏幕截图（物理生成）
  if solid_ratio > 0.5 {
    0.8
  } else if solid_ratio > 0.35 {
    0.6
  } else if solid_ratio > 0.2 {
    0.4
  } else {
    0.2
  }
}

///|
/// 边缘方向分析
pub fn analyze_edge_directions(
  img : @types.Image,
) -> Double raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "analyze_edge_directions: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "analyze_edge_directions: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "analyze_edge_directions: 数据大小不匹配",
    )
  }
  let geometry = analyze_geometry(img)
  // 水平+垂直边缘比例越高，越可能是 UI 界面（物理生成）
  let hv_ratio = geometry.horizontal_edge_ratio + geometry.vertical_edge_ratio
  if hv_ratio > 0.8 {
    0.8
  } else if hv_ratio > 0.65 {
    0.6
  } else if hv_ratio > 0.5 {
    0.4
  } else {
    0.2
  }
}

///|
/// 像素值分布分析
pub fn analyze_pixel_distribution(
  img : @types.Image,
) -> Double raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "analyze_pixel_distribution: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "analyze_pixel_distribution: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "analyze_pixel_distribution: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let total = w * h

  // 计算像素值分布的熵
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
      entropy -= p * p * 0.1 // 简化的 log2
    }
  }

  // 像素分布越集中（熵越低），越可能是 UI 界面（物理生成）
  if entropy < 0.5 {
    0.75
  } else if entropy < 1.0 {
    0.55
  } else if entropy < 1.5 {
    0.35
  } else {
    0.2
  }
}

///|
/// 智能决策引擎
pub fn intelligent_decision(
  basic_result : SourceVerificationResult,
  ui_result : UIDetectionResult,
  text_result : TextDetectionResult,
  geometry_result : GeometryAnalysisResult,
  color_result : ColorQuantizationResult,
  solid_indicator : Double,
  edge_dir_indicator : Double,
  pixel_dist_indicator : Double,
  config : EnhancedVerificationConfig,
) -> (ImageSourceType, Double, Double, Double, String) {
  // 增强特征的物理生成指示值（值越高越可能是物理生成）
  let enhanced_physical_score = ui_result.ui_indicator * 0.25 +
    text_result.text_indicator * 0.20 +
    geometry_result.geometry_indicator * 0.15 +
    color_result.color_quantization_indicator * 0.15 +
    solid_indicator * 0.10 +
    edge_dir_indicator * 0.08 +
    pixel_dist_indicator * 0.07

  // 基础特征的 AI 生成指示值
  let basic_ai_score = basic_result.ai_probability

  // 加权融合
  let final_ai_score = basic_ai_score * config.basic_weight +
    (1.0 - enhanced_physical_score) * config.enhanced_weight
  let final_physical_score = 1.0 - final_ai_score

  // 智能决策规则
  let mut decision_reason = ""
  let mut source_type = ImageSourceType::Unknown
  let mut confidence = 0.0

  // 强 UI 特征判定
  if ui_result.has_window_border &&
    ui_result.has_toolbar &&
    text_result.text_area_ratio > 0.05 {
    source_type = ImageSourceType::PhysicalCaptured
    confidence = 0.9
    decision_reason = "检测到窗口边框、工具栏和文字区域，强烈判定为屏幕截图（物理生成）"
  } else if ui_result.ui_element_count >= 6 &&
    geometry_result.geometry_regularity > 0.7 {
    source_type = ImageSourceType::PhysicalCaptured
    confidence = 0.8
    decision_reason = "检测到大量 UI 元素和规则几何形状，判定为屏幕截图（物理生成）"
  } else if text_result.text_area_ratio > 0.1 &&
    color_result.top_10_color_ratio > 0.7 {
    source_type = ImageSourceType::PhysicalCaptured
    confidence = 0.75
    decision_reason = "检测到大量文字区域和集中的颜色分布，判定为屏幕截图（物理生成）"
  } else if enhanced_physical_score > 0.65 {
    source_type = ImageSourceType::PhysicalCaptured
    confidence = 0.7
    decision_reason = "增强特征综合评分偏向物理生成，判定为物理生成"
  } else if final_ai_score >= config.decision_threshold &&
    enhanced_physical_score < 0.4 {
    source_type = ImageSourceType::AIGenerated
    confidence = if final_ai_score > 0.7 { 0.75 } else { 0.55 }
    decision_reason = "基础特征和增强特征均偏向 AI 生成，判定为 AI 生成"
  } else if final_ai_score >= config.decision_threshold {
    source_type = ImageSourceType::AIGenerated
    confidence = 0.45
    decision_reason = "基础特征偏向 AI 生成，但增强特征存在不确定性，低置信度判定为 AI 生成"
  } else {
    source_type = ImageSourceType::PhysicalCaptured
    confidence = 0.55
    decision_reason = "综合特征偏向物理生成，判定为物理生成"
  }

  (
    source_type, final_ai_score, final_physical_score, confidence, decision_reason,
  )
}

///|
/// 增强图像来源鉴定
pub fn verify_image_source_enhanced(
  img : @types.Image,
  config : EnhancedVerificationConfig,
) -> EnhancedVerificationResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "verify_image_source_enhanced: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "verify_image_source_enhanced: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "verify_image_source_enhanced: 数据大小不匹配",
    )
  }
  // 基础鉴定
  let basic_config = create_default_source_verification_config()
  let basic_result = verify_image_source(img, basic_config)

  // UI 检测
  let ui_result = if config.use_ui_detection {
    detect_ui_elements(img)
  } else {
    UIDetectionResult::{
      has_window_border: false,
      has_toolbar: false,
      has_button_like_elements: false,
      ui_element_count: 0,
      ui_area_ratio: 0.0,
      horizontal_line_count: 0,
      vertical_line_count: 0,
      ui_indicator: 0.5,
    }
  }

  // 文字检测
  let text_result = if config.use_text_detection {
    detect_text_regions(img)
  } else {
    TextDetectionResult::{
      text_area_count: 0,
      text_area_ratio: 0.0,
      dense_edge_region_count: 0,
      small_edge_density: 0.0,
      text_like_region_ratio: 0.0,
      text_indicator: 0.5,
    }
  }

  // 几何分析
  let geometry_result = if config.use_geometry_analysis {
    analyze_geometry(img)
  } else {
    GeometryAnalysisResult::{
      horizontal_edge_ratio: 0.5,
      vertical_edge_ratio: 0.5,
      diagonal_edge_ratio: 0.0,
      rectangle_like_region_count: 0,
      straight_line_count: 0,
      geometry_regularity: 1.0,
      geometry_indicator: 0.5,
    }
  }

  // 颜色量化分析
  let color_result = if config.use_color_quantization {
    analyze_color_quantization(img)
  } else {
    ColorQuantizationResult::{
      unique_color_count: 32,
      color_quantization_level: 0.5,
      top_color_ratio: 0.1,
      top_10_color_ratio: 0.5,
      color_palette_size: 32,
      color_quantization_indicator: 0.5,
    }
  }

  // 纯色区域分析
  let solid_indicator = if config.use_solid_area_analysis {
    analyze_solid_areas(img)
  } else {
    0.5
  }

  // 边缘方向分析
  let edge_dir_indicator = if config.use_edge_direction_analysis {
    analyze_edge_directions(img)
  } else {
    0.5
  }

  // 像素值分布分析
  let pixel_dist_indicator = analyze_pixel_distribution(img)

  // 增强特征综合评分
  let enhanced_overall = ui_result.ui_indicator * 0.25 +
    text_result.text_indicator * 0.20 +
    geometry_result.geometry_indicator * 0.15 +
    color_result.color_quantization_indicator * 0.15 +
    solid_indicator * 0.10 +
    edge_dir_indicator * 0.08 +
    pixel_dist_indicator * 0.07

  let enhanced_features = EnhancedVerificationFeatures::{
    ui_indicator: ui_result.ui_indicator,
    text_indicator: text_result.text_indicator,
    geometry_indicator: geometry_result.geometry_indicator,
    color_quantization_indicator: color_result.color_quantization_indicator,
    solid_area_indicator: solid_indicator,
    edge_direction_indicator: edge_dir_indicator,
    pixel_distribution_indicator: pixel_dist_indicator,
    overall_enhanced_score: enhanced_overall,
  }

  // 智能决策
  let (source_type, ai_prob, physical_prob, confidence, reason) = intelligent_decision(
    basic_result, ui_result, text_result, geometry_result, color_result, solid_indicator,
    edge_dir_indicator, pixel_dist_indicator, config,
  )

  EnhancedVerificationResult::{
    source_type,
    ai_probability: ai_prob,
    physical_probability: physical_prob,
    confidence,
    decision_threshold: config.decision_threshold,
    basic_features: basic_result.features,
    enhanced_features,
    ui_detection: ui_result,
    text_detection: text_result,
    geometry_analysis: geometry_result,
    color_quantization: color_result,
    decision_reason: reason,
    processing_time_ms: 0.0,
  }
}

///|
/// 生成增强鉴定报告
pub fn enhanced_verification_report_to_string(
  result : EnhancedVerificationResult,
) -> String {
  let mut report = "## 图像来源鉴定报告（增强版）\n\n"
  report = report + "### 鉴定结论\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  let source_str = if result.source_type == ImageSourceType::AIGenerated {
    "AI 生成"
  } else if result.source_type == ImageSourceType::PhysicalCaptured {
    "物理生成（真实拍摄/屏幕截图）"
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
  report = report + "| 决策依据 | " + result.decision_reason + " |\n\n"

  report = report + "### 基础特征分析\n\n"
  report = report + "| 特征 | AI 指示值 |\n|------|-----------|\n"
  report = report +
    "| 噪声模式 | " +
    (result.basic_features.noise_pattern_score * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 频域特征 | " +
    (result.basic_features.frequency_domain_score * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 颜色分布 | " +
    (result.basic_features.color_distribution_score * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 纹理特征 | " +
    (result.basic_features.texture_score * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 边缘特征 | " +
    (result.basic_features.edge_score * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 压缩伪影 | " +
    (result.basic_features.compression_artifact_score * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 细节特征 | " +
    (result.basic_features.detail_score * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 基础综合 | " +
    (result.basic_features.overall_score * 100.0).to_string() +
    "% |\n\n"

  report = report + "### 增强特征分析\n\n"
  report = report +
    "| 特征 | 物理生成指示值 | 说明 |\n|------|---------------|------|\n"
  report = report +
    "| UI 元素检测 | " +
    (result.enhanced_features.ui_indicator * 100.0).to_string() +
    "% | 窗口边框/工具栏/按钮检测 |\n"
  report = report +
    "| 文字区域检测 | " +
    (result.enhanced_features.text_indicator * 100.0).to_string() +
    "% | 密集小边缘区域检测 |\n"
  report = report +
    "| 几何形状分析 | " +
    (result.enhanced_features.geometry_indicator * 100.0).to_string() +
    "% | 水平/垂直边缘比例 |\n"
  report = report +
    "| 颜色量化分析 | " +
    (result.enhanced_features.color_quantization_indicator * 100.0).to_string() +
    "% | 颜色集中度/调色板大小 |\n"
  report = report +
    "| 纯色区域分析 | " +
    (result.enhanced_features.solid_area_indicator * 100.0).to_string() +
    "% | 大面积纯色区域比例 |\n"
  report = report +
    "| 边缘方向分析 | " +
    (result.enhanced_features.edge_direction_indicator * 100.0).to_string() +
    "% | 水平+垂直边缘占比 |\n"
  report = report +
    "| 像素分布分析 | " +
    (result.enhanced_features.pixel_distribution_indicator * 100.0).to_string() +
    "% | 像素值分布熵 |\n"
  report = report +
    "| 增强综合 | " +
    (result.enhanced_features.overall_enhanced_score * 100.0).to_string() +
    "% | 加权综合评分 |\n\n"

  report = report + "### UI 检测详情\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report +
    "| 窗口边框 | " +
    (if result.ui_detection.has_window_border {
      "检测到"
    } else {
      "未检测到"
    }) +
    " |\n"
  report = report +
    "| 工具栏 | " +
    (if result.ui_detection.has_toolbar { "检测到" } else { "未检测到" }) +
    " |\n"
  report = report +
    "| 按钮状元素 | " +
    (if result.ui_detection.has_button_like_elements {
      "检测到"
    } else {
      "未检测到"
    }) +
    " |\n"
  report = report +
    "| UI 元素总数 | " +
    result.ui_detection.ui_element_count.to_string() +
    " |\n"
  report = report +
    "| 水平线条数 | " +
    result.ui_detection.horizontal_line_count.to_string() +
    " |\n"
  report = report +
    "| 垂直线条数 | " +
    result.ui_detection.vertical_line_count.to_string() +
    " |\n"
  report = report +
    "| UI 区域比例 | " +
    (result.ui_detection.ui_area_ratio * 100.0).to_string() +
    "% |\n\n"

  report = report + "### 文字检测详情\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report +
    "| 文字区域数 | " +
    result.text_detection.text_area_count.to_string() +
    " |\n"
  report = report +
    "| 文字区域比例 | " +
    (result.text_detection.text_area_ratio * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 小边缘密度 | " +
    (result.text_detection.small_edge_density * 100.0).to_string() +
    "% |\n\n"

  report = report + "### 几何分析详情\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report +
    "| 水平边缘比例 | " +
    (result.geometry_analysis.horizontal_edge_ratio * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 垂直边缘比例 | " +
    (result.geometry_analysis.vertical_edge_ratio * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 对角边缘比例 | " +
    (result.geometry_analysis.diagonal_edge_ratio * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 几何规则性 | " +
    (result.geometry_analysis.geometry_regularity * 100.0).to_string() +
    "% |\n\n"

  report = report + "### 颜色量化详情\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report +
    "| 唯一颜色数(64级) | " +
    result.color_quantization.unique_color_count.to_string() +
    " |\n"
  report = report +
    "| 顶部颜色比例 | " +
    (result.color_quantization.top_color_ratio * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 前10颜色比例 | " +
    (result.color_quantization.top_10_color_ratio * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 调色板大小 | " +
    result.color_quantization.color_palette_size.to_string() +
    " |\n\n"

  report = report + "### 说明\n\n"
  report = report +
    "- 本鉴定基于基础统计特征 + 增强特征（UI/文字/几何/颜色）综合分析\n"
  report = report +
    "- 增强特征专门针对屏幕截图/数字渲染图进行优化\n"
  report = report +
    "- 物理生成指示值越高，表示越可能是真实拍摄或屏幕截图\n"
  report = report + "- 置信度表示鉴定结果的可靠程度\n"
  report = report +
    "- 对于经过编辑、压缩或重采样的图像，鉴定准确率可能下降\n"

  report
}

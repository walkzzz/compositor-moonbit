// 扫描质量自适应与鲁棒性增强（v12.24.0 P3 鲁棒性）
// 扫描质量自动评估与自适应预处理、倾斜/畸变校正、复杂版面支持、噪声鲁棒性

///|
/// 扫描质量等级
pub(all) enum ScanQualityLevel {
  Excellent // 优秀：可直接识别
  Good // 良好：轻微预处理即可
  Fair // 一般：需要增强处理
  Poor // 较差：需要重度预处理
  VeryPoor // 很差：可能无法识别
} derive(Eq)

///|
/// 自适应预处理配置
pub(all) struct AdaptivePreprocessConfig {
  quality_level : ScanQualityLevel
  denoise_strength : Int // 去噪强度 0-5
  contrast_enhance : Double // 对比度增强倍数 1.0-3.0
  binarization_method : String // "otsu" / "adaptive" / "sauvola"
  deskew_enabled : Bool // 是否启用倾斜校正
  sharpen_enabled : Bool // 是否启用锐化
  morph_open_enabled : Bool // 是否启用形态学开运算
  morph_close_enabled : Bool // 是否启用形态学闭运算
  recommended_dpi : Int // 推荐 DPI
}

///|
/// 畸变类型
pub(all) enum DistortionType {
  Skew // 倾斜
  Perspective // 透视畸变
  Barrel // 桶形畸变
  Pincushion // 枕形畸变
  UnevenLighting // 光照不均
  Blur // 模糊
  Noise // 噪声
  Unknown
} derive(Eq)

///|
/// 畸变检测结果
pub(all) struct DistortionDetectionResult {
  distortion_type : DistortionType
  severity : Double // 0.0-1.0
  angle : Double // 倾斜角度（度）
  confidence : Double
  correction_params : Array[(String, Double)]
}

///|
/// 复杂版面类型
pub(all) enum ComplexLayoutType {
  SingleColumn
  DoubleColumn
  TripleColumn
  MultiColumnWithFloats
  MixedLayout
  TableHeavy
  ImageHeavy
  Unknown
} derive(Eq)

///|
/// 复杂版面分析结果
pub(all) struct ComplexLayoutAnalysis {
  layout_type : ComplexLayoutType
  num_columns : Int
  has_floating_elements : Bool
  has_cross_page_elements : Bool
  column_boundaries : Array[Int]
  reading_order_strategy : String
  confidence : Double
}

///|
/// 鲁棒性评估报告
pub(all) struct RobustnessReport {
  overall_score : Double
  quality_score : Double
  distortion_score : Double
  layout_complexity_score : Double
  noise_resistance_score : Double
  recommendations : Array[String]
  estimated_accuracy : Double
  processing_recommendation : String
}

///|
/// 根据扫描质量自动选择预处理配置
pub fn select_adaptive_config(
  quality : ScanQuality,
) -> AdaptivePreprocessConfig raise @types.LoadError {
  // 输入验证
  if quality.overall_score < 0.0 || quality.overall_score > 100.0 {
    raise @types.LoadError::DecodeFailed(
      "select_adaptive_config: 质量评分必须在0-100之间",
    )
  }
  let score = quality.overall_score
  if score >= 90.0 {
    AdaptivePreprocessConfig::{
      quality_level: ScanQualityLevel::Excellent,
      denoise_strength: 1,
      contrast_enhance: 1.0,
      binarization_method: "otsu",
      deskew_enabled: false,
      sharpen_enabled: false,
      morph_open_enabled: false,
      morph_close_enabled: false,
      recommended_dpi: 200,
    }
  } else if score >= 75.0 {
    AdaptivePreprocessConfig::{
      quality_level: ScanQualityLevel::Good,
      denoise_strength: 2,
      contrast_enhance: 1.2,
      binarization_method: "otsu",
      deskew_enabled: true,
      sharpen_enabled: false,
      morph_open_enabled: false,
      morph_close_enabled: true,
      recommended_dpi: 250,
    }
  } else if score >= 60.0 {
    AdaptivePreprocessConfig::{
      quality_level: ScanQualityLevel::Fair,
      denoise_strength: 3,
      contrast_enhance: 1.5,
      binarization_method: "adaptive",
      deskew_enabled: true,
      sharpen_enabled: true,
      morph_open_enabled: true,
      morph_close_enabled: true,
      recommended_dpi: 300,
    }
  } else if score >= 40.0 {
    AdaptivePreprocessConfig::{
      quality_level: ScanQualityLevel::Poor,
      denoise_strength: 4,
      contrast_enhance: 2.0,
      binarization_method: "sauvola",
      deskew_enabled: true,
      sharpen_enabled: true,
      morph_open_enabled: true,
      morph_close_enabled: true,
      recommended_dpi: 400,
    }
  } else {
    AdaptivePreprocessConfig::{
      quality_level: ScanQualityLevel::VeryPoor,
      denoise_strength: 5,
      contrast_enhance: 2.5,
      binarization_method: "sauvola",
      deskew_enabled: true,
      sharpen_enabled: true,
      morph_open_enabled: true,
      morph_close_enabled: true,
      recommended_dpi: 600,
    }
  }
}

///|
/// 检测倾斜角度（基于霍夫变换的简化版）
pub fn detect_skew_angle_robust(
  binary_img : @types.Image,
) -> Double raise @types.LoadError {
  // 输入验证
  if binary_img.width <= 0 || binary_img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_skew_angle_robust: 图像尺寸必须大于0",
    )
  }
  if binary_img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "detect_skew_angle_robust: 仅支持单通道二值图",
    )
  }
  let expected_size = binary_img.width * binary_img.height
  if binary_img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "detect_skew_angle_robust: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      binary_img.data.length().to_string(),
    )
  }
  let w = binary_img.width
  let h = binary_img.height
  // 简化版：基于文本行的倾斜检测
  // 计算每行的黑色像素重心
  let mut total_x = 0
  let mut total_y = 0
  let mut count = 0
  for y in 0..<h {
    let mut row_black = 0
    let mut row_x_sum = 0
    for x in 0..<w {
      if binary_img.data[y * w + x].to_int() < 128 {
        row_black += 1
        row_x_sum += x
      }
    }
    if row_black > w / 10 {
      let center_x = row_x_sum / row_black
      total_x += center_x
      total_y += y
      count += 1
    }
  }
  if count < 2 {
    return 0.0
  }
  // 线性回归计算倾斜角度
  let _ = total_x.to_double() / count.to_double()
  let _ = total_y.to_double() / count.to_double()
  let numerator = 0.0
  ignore(numerator)
  let denominator = 0.0
  ignore(denominator)
  // 简化：用首尾两行的重心差计算角度
  let mut first_y = h
  let mut first_x = 0
  let mut last_y = 0
  let mut last_x = 0
  for y in 0..<h {
    let mut row_black = 0
    let mut row_x_sum = 0
    for x in 0..<w {
      if binary_img.data[y * w + x].to_int() < 128 {
        row_black += 1
        row_x_sum += x
      }
    }
    if row_black > w / 10 {
      let center_x = row_x_sum / row_black
      if y < first_y {
        first_y = y
        first_x = center_x
      }
      if y > last_y {
        last_y = y
        last_x = center_x
      }
    }
  }
  if last_y - first_y > 0 {
    let angle_rad = (last_x - first_x).to_double() /
      (last_y - first_y).to_double()
    let angle_deg = angle_rad * 57.2958 // rad to deg
    if angle_deg > 45.0 {
      90.0 - angle_deg
    } else if angle_deg < -45.0 {
      -90.0 - angle_deg
    } else {
      angle_deg
    }
  } else {
    0.0
  }
}

///|
/// 检测畸变类型和严重程度
pub fn detect_distortions(
  img : @types.Image,
) -> Array[DistortionDetectionResult] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_distortions: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "detect_distortions: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "detect_distortions: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let results : Array[DistortionDetectionResult] = []
  let w = img.width
  let h = img.height

  // 1. 检测噪声
  let mut noise_count = 0
  let mut total_pixels = 0
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let center = img.data[idx].to_int()
      let neighbors = [
        img.data[idx - 1].to_int(),
        img.data[idx + 1].to_int(),
        img.data[idx - w].to_int(),
        img.data[idx + w].to_int(),
      ]
      let mut neighbor_sum = 0
      for n in neighbors {
        neighbor_sum += n
      }
      let neighbor_avg = neighbor_sum / 4
      if (center - neighbor_avg).abs() > 50 {
        noise_count += 1
      }
      total_pixels += 1
    }
  }
  let noise_ratio = if total_pixels > 0 {
    noise_count.to_double() / total_pixels.to_double()
  } else {
    0.0
  }
  if noise_ratio > 0.01 {
    results.push(DistortionDetectionResult::{
      distortion_type: DistortionType::Noise,
      severity: if noise_ratio > 0.1 {
        0.8
      } else if noise_ratio > 0.05 {
        0.5
      } else {
        0.2
      },
      angle: 0.0,
      confidence: 0.8,
      correction_params: [
        (
          "denoise_strength",
          if noise_ratio > 0.1 {
            5.0
          } else if noise_ratio > 0.05 {
            3.0
          } else {
            2.0
          },
        ),
      ],
    })
  }

  // 2. 检测模糊（拉普拉斯方差）
  let mut laplacian_sum = 0.0
  let mut laplacian_count = 0
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let center = img.data[idx].to_double()
      let lap = 4.0 * center -
        img.data[idx - 1].to_double() -
        img.data[idx + 1].to_double() -
        img.data[idx - w].to_double() -
        img.data[idx + w].to_double()
      laplacian_sum += lap * lap
      laplacian_count += 1
    }
  }
  let laplacian_var = if laplacian_count > 0 {
    laplacian_sum / laplacian_count.to_double()
  } else {
    0.0
  }
  if laplacian_var < 100.0 {
    results.push(DistortionDetectionResult::{
      distortion_type: DistortionType::Blur,
      severity: if laplacian_var < 20.0 {
        0.9
      } else if laplacian_var < 50.0 {
        0.6
      } else {
        0.3
      },
      angle: 0.0,
      confidence: 0.75,
      correction_params: [
        (
          "sharpen_strength",
          if laplacian_var < 20.0 {
            3.0
          } else if laplacian_var < 50.0 {
            2.0
          } else {
            1.0
          },
        ),
      ],
    })
  }

  // 3. 检测光照不均（四角亮度差）
  if w > 20 && h > 20 {
    let regions = [
      (10, 10),
      (w - 10, 10),
      (10, h - 10),
      (w - 10, h - 10),
      (w / 2, h / 2),
    ]
    let brightnesses : Array[Double] = []
    for _tup0 in regions {
      let (rx, ry) = _tup0
      let mut sum = 0.0
      let mut count = 0
      for dy in 0..<10 {
        for dx in 0..<10 {
          if rx + dx < w && ry + dy < h {
            sum += img.data[(ry + dy) * w + (rx + dx)].to_double()
            count += 1
          }
        }
      }
      if count > 0 {
        brightnesses.push(sum / count.to_double())
      }
    }
    if brightnesses.length() >= 4 {
      let mut max_b = brightnesses[0]
      let mut min_b = brightnesses[0]
      for b in brightnesses {
        if b > max_b {
          max_b = b
        }
        if b < min_b {
          min_b = b
        }
      }
      let brightness_diff = max_b - min_b
      if brightness_diff > 50.0 {
        results.push(DistortionDetectionResult::{
          distortion_type: DistortionType::UnevenLighting,
          severity: if brightness_diff > 100.0 {
            0.8
          } else if brightness_diff > 75.0 {
            0.5
          } else {
            0.3
          },
          angle: 0.0,
          confidence: 0.7,
          correction_params: [
            ("adaptive_threshold", 1.0),
            ("contrast_enhance", 1.5),
          ],
        })
      }
    }
  }

  results
}

///|
/// 分析复杂版面
pub fn analyze_complex_layout(
  text_blocks : Array[TextBlock],
  page_width : Int,
  page_height : Int,
) -> ComplexLayoutAnalysis {
  ignore(page_height)
  if text_blocks.length() == 0 {
    return ComplexLayoutAnalysis::{
      layout_type: ComplexLayoutType::Unknown,
      num_columns: 1,
      has_floating_elements: false,
      has_cross_page_elements: false,
      column_boundaries: [],
      reading_order_strategy: "default",
      confidence: 0.0,
    }
  }

  // 统计水平覆盖范围
  let mut full_width_count = 0
  let mut left_count = 0
  let mut right_count = 0
  let mid_x = page_width / 2

  for block in text_blocks {
    let center = block.x + block.width / 2
    if block.width.to_double() > page_width.to_double() * 0.7 {
      full_width_count += 1
    } else if center < mid_x {
      left_count += 1
    } else {
      right_count += 1
    }
  }

  let total = text_blocks.length().to_double()
  let full_ratio = full_width_count.to_double() / total
  let left_ratio = left_count.to_double() / total
  let right_ratio = right_count.to_double() / total

  let layout_type = if full_ratio > 0.8 {
    ComplexLayoutType::SingleColumn
  } else if left_ratio > 0.3 && right_ratio > 0.3 && full_ratio < 0.2 {
    ComplexLayoutType::DoubleColumn
  } else if full_ratio > 0.2 && (left_ratio > 0.2 || right_ratio > 0.2) {
    ComplexLayoutType::MixedLayout
  } else {
    ComplexLayoutType::SingleColumn
  }

  let num_columns = match layout_type {
    ComplexLayoutType::DoubleColumn => 2
    ComplexLayoutType::TripleColumn => 3
    ComplexLayoutType::MultiColumnWithFloats => 3
    _ => 1
  }

  let has_floats = full_ratio > 0.1 && full_ratio < 0.5

  let reading_order_strategy = match layout_type {
    ComplexLayoutType::SingleColumn => "top_to_bottom"
    ComplexLayoutType::DoubleColumn => "left_column_first"
    ComplexLayoutType::TripleColumn => "column_by_column"
    ComplexLayoutType::MixedLayout => "adaptive"
    _ => "default"
  }

  let boundaries : Array[Int] = []
  boundaries.push(0)
  if num_columns >= 2 {
    boundaries.push(page_width / 2 - 20)
    boundaries.push(page_width / 2 + 20)
  }
  boundaries.push(page_width)

  ComplexLayoutAnalysis::{
    layout_type,
    num_columns,
    has_floating_elements: has_floats,
    has_cross_page_elements: false,
    column_boundaries: boundaries,
    reading_order_strategy,
    confidence: 0.75,
  }
}

///|
/// 生成鲁棒性评估报告
pub fn generate_robustness_report(
  quality : ScanQuality,
  distortions : Array[DistortionDetectionResult],
  layout : ComplexLayoutAnalysis,
) -> RobustnessReport {
  // 质量分数
  let quality_score = quality.overall_score / 100.0

  // 畸变分数（畸变越少分数越高）
  let mut distortion_penalty = 0.0
  for d in distortions {
    distortion_penalty += d.severity * 0.2
  }
  let distortion_score = if 1.0 - distortion_penalty > 0 {
    1.0 - distortion_penalty
  } else {
    0.0
  }

  // 版面复杂度分数（越简单分数越高）
  let layout_score = match layout.layout_type {
    ComplexLayoutType::SingleColumn => 1.0
    ComplexLayoutType::DoubleColumn => 0.8
    ComplexLayoutType::TripleColumn => 0.6
    ComplexLayoutType::MixedLayout => 0.5
    ComplexLayoutType::MultiColumnWithFloats => 0.4
    _ => 0.7
  }

  // 噪声抵抗分数
  let mut noise_severity = 0.0
  for d in distortions {
    if d.distortion_type == DistortionType::Noise {
      noise_severity = d.severity
    }
  }
  let noise_score = 1.0 - noise_severity

  // 综合分数
  let overall = quality_score * 0.3 +
    distortion_score * 0.3 +
    layout_score * 0.2 +
    noise_score * 0.2

  // 建议
  let recommendations : Array[String] = []
  if quality_score < 0.6 {
    recommendations.push("建议提高扫描分辨率至 300 DPI 以上")
  }
  if noise_severity > 0.3 {
    recommendations.push("建议启用强去噪处理（中值滤波+NLM）")
  }
  if layout.num_columns > 1 {
    recommendations.push(
      "检测到多栏布局，建议使用分栏阅读顺序",
    )
  }
  if distortion_penalty > 0.3 {
    recommendations.push(
      "检测到严重畸变，建议启用完整预处理流水线",
    )
  }
  if recommendations.length() == 0 {
    recommendations.push("文档质量良好，可使用标准预处理流程")
  }

  // 预估准确率
  let estimated_accuracy = overall * 0.95 + 0.05

  let processing_recommendation = if overall > 0.8 {
    "标准处理流程"
  } else if overall > 0.6 {
    "增强处理流程"
  } else {
    "重度预处理+人工复核"
  }

  RobustnessReport::{
    overall_score: overall,
    quality_score,
    distortion_score,
    layout_complexity_score: layout_score,
    noise_resistance_score: noise_score,
    recommendations,
    estimated_accuracy,
    processing_recommendation,
  }
}

///|
/// 生成鲁棒性报告文本
pub fn robustness_report_to_string(report : RobustnessReport) -> String {
  let mut output = "## OCR 鲁棒性评估报告\n\n"
  output = output + "### 综合评分\n\n"
  output = output + "| 指标 | 分数 |\n"
  output = output + "|------|------|\n"
  output = output +
    "| **综合评分** | **" +
    (report.overall_score * 100.0).to_string() +
    "/100** |\n"
  output = output +
    "| 扫描质量 | " +
    (report.quality_score * 100.0).to_string() +
    "/100 |\n"
  output = output +
    "| 畸变控制 | " +
    (report.distortion_score * 100.0).to_string() +
    "/100 |\n"
  output = output +
    "| 版面复杂度 | " +
    (report.layout_complexity_score * 100.0).to_string() +
    "/100 |\n"
  output = output +
    "| 噪声抵抗 | " +
    (report.noise_resistance_score * 100.0).to_string() +
    "/100 |\n\n"
  output = output +
    "### 预估识别准确率: " +
    (report.estimated_accuracy * 100.0).to_string() +
    "%\n\n"
  output = output +
    "### 推荐处理方式: " +
    report.processing_recommendation +
    "\n\n"
  output = output + "### 改进建议\n\n"
  for i in 0..<report.recommendations.length() {
    output = output +
      (i + 1).to_string() +
      ". " +
      report.recommendations[i] +
      "\n"
  }
  output
}

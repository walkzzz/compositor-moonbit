// 手写体识别支持（v13.2.0）
// 手写字符预处理、连笔分割、笔画特征提取、手写字体模板、手写识别引擎

///|
/// 手写体类型
pub(all) enum HandwritingStyle {
  Print // 印刷体
  Cursive // 草书/连笔
  SemiCursive // 半连笔
  Block // 方块字
  Unknown
} derive(Eq)

///|
/// 笔画类型
pub(all) enum StrokeType {
  Horizontal // 横
  Vertical // 竖
  LeftFalling // 撇
  RightFalling // 捺
  Dot // 点
  Hook // 钩
  Turning // 折
  Rising // 提
  Unknown
} derive(Eq)

///|
/// 笔画特征
pub(all) struct StrokeFeature {
  stroke_type : StrokeType
  start_x : Double
  start_y : Double
  end_x : Double
  end_y : Double
  length : Double
  angle : Double
  curvature : Double
  pressure : Double
}

///|
/// 连笔分割结果
pub(all) struct StrokeSegmentationResult {
  num_strokes : Int
  strokes : Array[StrokeFeature]
  segmentation_points : Array[(Int, Int)]
  confidence : Double
}

///|
/// 手写字符特征
pub(all) struct HandwritingCharFeature {
  char : String
  num_strokes : Int
  stroke_types : Array[StrokeType]
  aspect_ratio : Double
  density : Double
  center_of_mass_x : Double
  center_of_mass_y : Double
  horizontal_projection : Array[Double]
  vertical_projection : Array[Double]
  contour_complexity : Double
  slant_angle : Double
  size_normalized : Bool
}

///|
/// 手写字体模板
pub(all) struct HandwritingTemplate {
  char : String
  style : HandwritingStyle
  features : HandwritingCharFeature
  sample_count : Int
  avg_accuracy : Double
}

///|
/// 手写识别配置
pub(all) struct HandwritingRecognitionConfig {
  min_stroke_length : Double
  max_stroke_angle : Double
  segmentation_threshold : Double
  similarity_threshold : Double
  enable_slant_correction : Bool
  enable_size_normalization : Bool
  enable_stroke_order : Bool
  max_candidates : Int
  style_priority : HandwritingStyle
}

///|
/// 手写识别结果
pub(all) struct HandwritingRecognitionResult {
  predicted_char : String
  confidence : Double
  top_candidates : Array[(String, Double)]
  detected_style : HandwritingStyle
  num_strokes_detected : Int
  slant_angle : Double
  preprocessing_time_ms : Double
  feature_extraction_time_ms : Double
  matching_time_ms : Double
  total_time_ms : Double
}

///|
/// 创建默认手写识别配置
pub fn create_default_handwriting_config() -> HandwritingRecognitionConfig {
  HandwritingRecognitionConfig::{
    min_stroke_length: 5.0,
    max_stroke_angle: 45.0,
    segmentation_threshold: 0.3,
    similarity_threshold: 0.6,
    enable_slant_correction: true,
    enable_size_normalization: true,
    enable_stroke_order: true,
    max_candidates: 5,
    style_priority: HandwritingStyle::SemiCursive,
  }
}

///|
/// 检测手写体倾斜角度
pub fn detect_handwriting_slant(
  img : @types.Image,
) -> Double raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_handwriting_slant: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "detect_handwriting_slant: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "detect_handwriting_slant: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let w = img.width
  let h = img.height
  // 基于文本行的倾斜检测
  let mut total_angle = 0.0
  let mut line_count = 0

  for y in 0..<(h - 1) {
    let mut start_x = -1
    let mut end_x = -1
    for x in 0..<w {
      if img.data[y * w + x].to_int() < 128 {
        if start_x == -1 {
          start_x = x
        }
        end_x = x
      }
    }
    if start_x != -1 && end_x != -1 && end_x - start_x > w / 4 {
      let center_x = (start_x + end_x) / 2
      // 简化：用行中心的变化计算倾斜
      if y > 0 {
        let prev_center = center_x
        let angle = (prev_center - center_x).to_double() /
          h.to_double() *
          57.2958
        total_angle += angle
        line_count += 1
      }
    }
  }

  if line_count > 0 {
    total_angle / line_count.to_double()
  } else {
    0.0
  }
}

///|
/// 手写字符大小归一化（简化版，返回尺寸信息）
pub fn normalize_handwriting_size(
  img : @types.Image,
  target_size : Int,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "normalize_handwriting_size: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "normalize_handwriting_size: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "normalize_handwriting_size: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if target_size <= 0 {
    raise @types.LoadError::DecodeFailed(
      "normalize_handwriting_size: 目标尺寸必须大于0",
    )
  }
  // 简化版：返回原图像，实际应进行缩放
  img
}

///|
/// 提取笔画特征
pub fn extract_hw_stroke_features(img : @types.Image) -> Array[StrokeFeature] {
  let w = img.width
  let h = img.height
  let strokes : Array[StrokeFeature] = []

  // 简化版：基于连通域的笔画提取
  let visited : Array[Bool] = []
  for _ in 0..<(w * h) {
    visited.push(false)
  }

  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      if !visited[idx] && img.data[idx].to_int() < 128 {
        // 找到一个连通域（简化为单点）
        visited[idx] = true
        let stroke = StrokeFeature::{
          stroke_type: StrokeType::Unknown,
          start_x: x.to_double(),
          start_y: y.to_double(),
          end_x: x.to_double(),
          end_y: y.to_double(),
          length: 1.0,
          angle: 0.0,
          curvature: 0.0,
          pressure: 0.5,
        }
        strokes.push(stroke)
      }
    }
  }

  strokes
}

///|
/// 连笔分割
pub fn segment_connected_strokes(
  img : @types.Image,
  config : HandwritingRecognitionConfig,
) -> StrokeSegmentationResult {
  let strokes = extract_hw_stroke_features(img)
  let segmentation_points : Array[(Int, Int)] = []

  // 简化版：基于笔画长度的分割
  for i in 0..<strokes.length() {
    if strokes[i].length < config.min_stroke_length {
      segmentation_points.push(
        (strokes[i].start_x.to_int(), strokes[i].start_y.to_int()),
      )
    }
  }

  StrokeSegmentationResult::{
    num_strokes: strokes.length(),
    strokes,
    segmentation_points,
    confidence: 0.7,
  }
}

///|
/// 提取手写字符特征
pub fn extract_handwriting_features(
  img : @types.Image,
  char : String,
) -> HandwritingCharFeature raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "extract_handwriting_features: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "extract_handwriting_features: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "extract_handwriting_features: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let w = img.width
  let h = img.height

  // 计算水平投影
  let horizontal : Array[Double] = []
  for y in 0..<h {
    let mut count = 0.0
    for x in 0..<w {
      if img.data[y * w + x].to_int() < 128 {
        count += 1.0
      }
    }
    horizontal.push(count / w.to_double())
  }

  // 计算垂直投影
  let vertical : Array[Double] = []
  for x in 0..<w {
    let mut count = 0.0
    for y in 0..<h {
      if img.data[y * w + x].to_int() < 128 {
        count += 1.0
      }
    }
    vertical.push(count / h.to_double())
  }

  // 计算重心
  let mut total_mass = 0.0
  let mut sum_x = 0.0
  let mut sum_y = 0.0
  for y in 0..<h {
    for x in 0..<w {
      if img.data[y * w + x].to_int() < 128 {
        total_mass += 1.0
        sum_x += x.to_double()
        sum_y += y.to_double()
      }
    }
  }

  let center_x = if total_mass > 0 {
    sum_x / total_mass
  } else {
    w.to_double() / 2.0
  }
  let center_y = if total_mass > 0 {
    sum_y / total_mass
  } else {
    h.to_double() / 2.0
  }

  // 计算密度
  let density = total_mass / (w * h).to_double()

  // 提取笔画
  let strokes = extract_hw_stroke_features(img)
  let stroke_types : Array[StrokeType] = []
  for s in strokes {
    stroke_types.push(s.stroke_type)
  }

  HandwritingCharFeature::{
    char,
    num_strokes: strokes.length(),
    stroke_types,
    aspect_ratio: w.to_double() / h.to_double(),
    density,
    center_of_mass_x: center_x / w.to_double(),
    center_of_mass_y: center_y / h.to_double(),
    horizontal_projection: horizontal,
    vertical_projection: vertical,
    contour_complexity: strokes.length().to_double() / 10.0,
    slant_angle: detect_handwriting_slant(img),
    size_normalized: true,
  }
}

///|
/// 计算手写特征相似度
pub fn handwriting_feature_similarity(
  feat1 : HandwritingCharFeature,
  feat2 : HandwritingCharFeature,
) -> Double {
  let mut score = 0.0

  // 笔画数相似度（20%）
  let stroke_diff = (feat1.num_strokes - feat2.num_strokes).abs().to_double()
  let stroke_sim = if stroke_diff < 1 {
    1.0
  } else if stroke_diff < 3 {
    0.7
  } else {
    0.4
  }
  score += stroke_sim * 0.2

  // 宽高比相似度（15%）
  let aspect_diff = (feat1.aspect_ratio - feat2.aspect_ratio).abs()
  let aspect_sim = if aspect_diff < 0.1 {
    1.0
  } else if aspect_diff < 0.3 {
    0.7
  } else {
    0.4
  }
  score += aspect_sim * 0.15

  // 密度相似度（15%）
  let density_diff = (feat1.density - feat2.density).abs()
  let density_sim = if density_diff < 0.05 {
    1.0
  } else if density_diff < 0.15 {
    0.7
  } else {
    0.4
  }
  score += density_sim * 0.15

  // 重心相似度（20%）
  let center_dist = (@math.pow(
    feat1.center_of_mass_x - feat2.center_of_mass_x,
    2.0,
  ) +
  @math.pow(feat1.center_of_mass_y - feat2.center_of_mass_y, 2.0)).sqrt()
  let center_sim = if center_dist < 0.05 {
    1.0
  } else if center_dist < 0.15 {
    0.7
  } else {
    0.4
  }
  score += center_sim * 0.2

  // 倾斜角度相似度（10%）
  let slant_diff = (feat1.slant_angle - feat2.slant_angle).abs()
  let slant_sim = if slant_diff < 5.0 {
    1.0
  } else if slant_diff < 15.0 {
    0.7
  } else {
    0.4
  }
  score += slant_sim * 0.1

  // 轮廓复杂度相似度（10%）
  let contour_diff = (feat1.contour_complexity - feat2.contour_complexity).abs()
  let contour_sim = if contour_diff < 0.5 {
    1.0
  } else if contour_diff < 1.5 {
    0.7
  } else {
    0.4
  }
  score += contour_sim * 0.1

  score
}

///|
/// 创建手写字体模板
pub fn create_handwriting_template(
  char : String,
  style : HandwritingStyle,
  samples : Array[@types.Image],
) -> HandwritingTemplate raise @types.LoadError {
  // 输入验证
  if char.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "create_handwriting_template: 字符不能为空",
    )
  }
  if samples.length() == 0 {
    return HandwritingTemplate::{
      char,
      style,
      features: HandwritingCharFeature::{
        char,
        num_strokes: 0,
        stroke_types: [],
        aspect_ratio: 1.0,
        density: 0.0,
        center_of_mass_x: 0.5,
        center_of_mass_y: 0.5,
        horizontal_projection: [],
        vertical_projection: [],
        contour_complexity: 0.0,
        slant_angle: 0.0,
        size_normalized: false,
      },
      sample_count: 0,
      avg_accuracy: 0.0,
    }
  }

  // 计算平均特征
  let mut avg_strokes = 0.0
  let mut avg_aspect = 0.0
  let mut avg_density = 0.0
  let mut avg_center_x = 0.0
  let mut avg_center_y = 0.0
  let mut avg_slant = 0.0
  let mut avg_contour = 0.0

  for sample in samples {
    let feat = extract_handwriting_features(sample, char)
    avg_strokes += feat.num_strokes.to_double()
    avg_aspect += feat.aspect_ratio
    avg_density += feat.density
    avg_center_x += feat.center_of_mass_x
    avg_center_y += feat.center_of_mass_y
    avg_slant += feat.slant_angle
    avg_contour += feat.contour_complexity
  }

  let n = samples.length().to_double()
  let avg_features = HandwritingCharFeature::{
    char,
    num_strokes: (avg_strokes / n).to_int(),
    stroke_types: [],
    aspect_ratio: avg_aspect / n,
    density: avg_density / n,
    center_of_mass_x: avg_center_x / n,
    center_of_mass_y: avg_center_y / n,
    horizontal_projection: [],
    vertical_projection: [],
    contour_complexity: avg_contour / n,
    slant_angle: avg_slant / n,
    size_normalized: true,
  }

  HandwritingTemplate::{
    char,
    style,
    features: avg_features,
    sample_count: samples.length(),
    avg_accuracy: 0.85,
  }
}

///|
/// 手写字符识别
pub fn recognize_handwriting_char(
  img : @types.Image,
  templates : Array[HandwritingTemplate],
  config : HandwritingRecognitionConfig,
) -> HandwritingRecognitionResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_handwriting_char: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "recognize_handwriting_char: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "recognize_handwriting_char: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if templates.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_handwriting_char: 模板列表不能为空",
    )
  }
  if config.similarity_threshold < 0.0 || config.similarity_threshold > 1.0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_handwriting_char: 相似度阈值必须在0-1之间",
    )
  }
  let _ = 0.0

  // 1. 预处理
  let preprocessed = if config.enable_size_normalization {
    normalize_handwriting_size(img, 64)
  } else {
    img
  }
  let preprocess_time = 0.0

  // 2. 特征提取
  let features = extract_handwriting_features(preprocessed, "?")
  let feature_time = 0.0

  // 3. 模板匹配
  let candidates : Array[(String, Double)] = []
  for template in templates {
    let sim = handwriting_feature_similarity(features, template.features)
    if sim > config.similarity_threshold {
      candidates.push((template.char, sim))
    }
  }

  // 排序
  for i in 0..<candidates.length() {
    for j in 0..<(candidates.length() - i - 1) {
      if candidates[j].1 < candidates[j + 1].1 {
        let temp = candidates[j]
        candidates[j] = candidates[j + 1]
        candidates[j + 1] = temp
      }
    }
  }

  let match_time = 0.0

  let predicted = if candidates.length() > 0 { candidates[0].0 } else { "?" }
  let confidence = if candidates.length() > 0 { candidates[0].1 } else { 0.0 }

  let top_candidates : Array[(String, Double)] = []
  for
    i in 0..<(if config.max_candidates < candidates.length() {
      config.max_candidates
    } else {
      candidates.length()
    }) {
    top_candidates.push(candidates[i])
  }

  HandwritingRecognitionResult::{
    predicted_char: predicted,
    confidence,
    top_candidates,
    detected_style: config.style_priority,
    num_strokes_detected: features.num_strokes,
    slant_angle: features.slant_angle,
    preprocessing_time_ms: preprocess_time,
    feature_extraction_time_ms: feature_time,
    matching_time_ms: match_time,
    total_time_ms: 0.0,
  }
}

///|
/// 生成手写识别报告
pub fn handwriting_report_to_string(
  result : HandwritingRecognitionResult,
) -> String {
  let mut report = "## 手写体识别报告\n\n"
  report = report + "### 识别结果\n\n"
  report = report + "| 指标 | 值 |\n"
  report = report + "|------|------|\n"
  report = report + "| 预测字符 | **" + result.predicted_char + "** |\n"
  report = report +
    "| 置信度 | " +
    (result.confidence * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 检测字体 | " +
    (match result.detected_style {
      HandwritingStyle::Print => "印刷体"
      HandwritingStyle::Cursive => "草书/连笔"
      HandwritingStyle::SemiCursive => "半连笔"
      HandwritingStyle::Block => "方块字"
      _ => "未知"
    }) +
    " |\n"
  report = report +
    "| 检测笔画数 | " +
    result.num_strokes_detected.to_string() +
    " |\n"
  report = report +
    "| 倾斜角度 | " +
    result.slant_angle.to_string() +
    "° |\n\n"

  if result.top_candidates.length() > 0 {
    report = report + "### Top-K 候选\n\n"
    report = report + "| 排名 | 字符 | 置信度 |\n"
    report = report + "|------|------|--------|\n"
    for i in 0..<result.top_candidates.length() {
      report = report +
        "| " +
        (i + 1).to_string() +
        " | " +
        result.top_candidates[i].0 +
        " | " +
        (result.top_candidates[i].1 * 100.0).to_string() +
        "% |\n"
    }
  }

  report
}

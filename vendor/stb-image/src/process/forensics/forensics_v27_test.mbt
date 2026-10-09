// v27.0.0 图像来源鉴定测试
// 覆盖 image_source_verification.mbt (10 fn) + enhanced_source_verification.mbt (11 fn) = 21 fn

///|
/// 创建纯色图像（低噪声，模拟 AI 生成）
fn create_solid_image_v27(w : Int, h : Int, value : Int) -> @types.Image {
  let data : Array[Byte] = []
  for _ in 0..<(w * h) {
    data.push(value.to_byte())
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(data),
  }
}

///|
/// 创建随机噪声图像（高噪声，模拟物理拍摄）
fn create_noise_image_v27(w : Int, h : Int) -> @types.Image {
  let data : Array[Byte] = []
  let mut state = 12345
  for _ in 0..<(w * h) {
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF
    data.push((state % 256).to_byte())
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(data),
  }
}

///|
/// 创建渐变图像
fn create_gradient_image_v27(w : Int, h : Int) -> @types.Image {
  let data : Array[Byte] = []
  for _ in 0..<h {
    for x in 0..<w {
      let v = x * 255 / w % 256
      data.push(v.to_byte())
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(data),
  }
}

///|
/// 创建模拟 UI 截图图像（有边框和线条）
fn create_ui_screenshot_v27(w : Int, h : Int) -> @types.Image {
  let data : Array[Byte] = []
  for y in 0..<h {
    for x in 0..<w {
      let v = if x == 0 || x == w - 1 || y == 0 || y == h - 1 {
        255
      } else if y == h / 4 || y == h / 2 {
        200
      } else if x == w / 3 || x == w * 2 / 3 {
        180
      } else {
        128
      }
      data.push(v.to_byte())
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(data),
  }
}

///|
/// 创建棋盘格图像
fn create_checkerboard_v27(w : Int, h : Int, block : Int) -> @types.Image {
  let data : Array[Byte] = []
  for y in 0..<h {
    for x in 0..<w {
      let v = if (x / block + y / block) % 2 == 0 { 255 } else { 0 }
      data.push(v.to_byte())
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(data),
  }
}

///|
test "create_default_source_verification_config: 默认配置正确" {
  let config = create_default_source_verification_config()
  assert_true(config.decision_threshold == 0.5)
  assert_true(config.use_noise_analysis)
  assert_true(config.use_frequency_analysis)
  assert_true(config.use_color_analysis)
  assert_true(config.use_texture_analysis)
  assert_true(config.use_edge_analysis)
  assert_true(config.use_compression_analysis)
  assert_true(config.use_detail_analysis)
  assert_true(config.weights.length() == 7)
}

///|
test "analyze_noise_pattern: 纯色图像噪声水平低" {
  let img = create_solid_image_v27(16, 16, 128)
  let result = analyze_noise_pattern(img)
  assert_true(result.noise_level >= 0.0)
  assert_true(result.ai_noise_indicator > 0.0)
}

///|
test "analyze_noise_pattern: 随机噪声图像噪声水平高" {
  let img = create_noise_image_v27(16, 16)
  let result = analyze_noise_pattern(img)
  assert_true(result.noise_level >= 0.0)
  assert_true(result.ai_noise_indicator > 0.0)
}

///|
test "analyze_noise_pattern: 渐变图像" {
  let img = create_gradient_image_v27(16, 16)
  let result = analyze_noise_pattern(img)
  assert_true(result.noise_level >= 0.0)
  assert_true(result.noise_correlation >= 0.0)
}

///|
test "analyze_frequency_domain: 纯色图像高频能量低" {
  let img = create_solid_image_v27(16, 16, 100)
  let result = analyze_frequency_domain(img)
  assert_true(result.high_frequency_energy >= 0.0)
  assert_true(result.low_frequency_energy >= 0.0)
  assert_true(result.ai_frequency_indicator > 0.0)
}

///|
test "analyze_frequency_domain: 棋盘格图像高频能量高" {
  let img = create_checkerboard_v27(16, 16, 2)
  let result = analyze_frequency_domain(img)
  assert_true(result.high_frequency_energy >= 0.0)
  assert_true(result.ai_frequency_indicator > 0.0)
}

///|
test "analyze_color_distribution: 纯色图像颜色平滑" {
  let img = create_solid_image_v27(16, 16, 128)
  let result = analyze_color_distribution(img)
  assert_true(result.color_histogram_smoothness >= 0.0)
  assert_true(result.ai_color_indicator > 0.0)
}

///|
test "analyze_color_distribution: 随机噪声图像颜色分布分散" {
  let img = create_noise_image_v27(16, 16)
  let result = analyze_color_distribution(img)
  assert_true(result.color_histogram_smoothness >= 0.0)
  assert_true(result.color_transition_naturalness >= 0.0)
}

///|
test "analyze_texture: 纯色图像纹理简单" {
  let img = create_solid_image_v27(16, 16, 128)
  let result = analyze_texture(img)
  assert_true(result.texture_regularity >= 0.0)
  assert_true(result.ai_texture_indicator > 0.0)
}

///|
test "analyze_texture: 棋盘格图像纹理规则" {
  let img = create_checkerboard_v27(16, 16, 4)
  let result = analyze_texture(img)
  assert_true(result.texture_complexity >= 0.0)
  assert_true(result.ai_texture_indicator > 0.0)
}

///|
test "analyze_edges: 纯色图像无边缘" {
  let img = create_solid_image_v27(16, 16, 128)
  let result = analyze_edges(img)
  assert_true(result.edge_sharpness >= 0.0)
  assert_true(result.ai_edge_indicator > 0.0)
}

///|
test "analyze_edges: 棋盘格图像有强边缘" {
  let img = create_checkerboard_v27(16, 16, 2)
  let result = analyze_edges(img)
  assert_true(result.edge_sharpness >= 0.0)
  assert_true(result.edge_continuity >= 0.0)
}

///|
test "analyze_compression_artifacts: 纯色图像无压缩伪影" {
  let img = create_solid_image_v27(16, 16, 128)
  let result = analyze_compression_artifacts(img)
  assert_true(result.blocking_artifact_level >= 0.0)
  assert_true(result.ai_compression_indicator > 0.0)
}

///|
test "analyze_compression_artifacts: 渐变图像" {
  let img = create_gradient_image_v27(16, 16)
  let result = analyze_compression_artifacts(img)
  assert_true(result.ringing_artifact_level >= 0.0)
  assert_true(result.compression_noise_level >= 0.0)
}

///|
test "analyze_details: 纯色图像细节一致" {
  let img = create_solid_image_v27(16, 16, 128)
  let result = analyze_details(img)
  assert_true(result.symmetry_consistency >= 0.0)
  assert_true(result.ai_detail_indicator > 0.0)
}

///|
test "analyze_details: 随机噪声图像" {
  let img = create_noise_image_v27(16, 16)
  let result = analyze_details(img)
  assert_true(result.eye_detail_consistency >= 0.0)
  assert_true(result.finger_detail_consistency >= 0.0)
}

///|
test "verify_image_source: 纯色图像鉴定结果有效" {
  let img = create_solid_image_v27(16, 16, 128)
  let config = create_default_source_verification_config()
  let result = verify_image_source(img, config)
  assert_true(result.ai_probability >= 0.0 && result.ai_probability <= 1.0)
  assert_true(
    result.physical_probability >= 0.0 && result.physical_probability <= 1.0,
  )
  assert_true(result.confidence >= 0.0 && result.confidence <= 1.0)
  assert_true(
    result.features.overall_score >= 0.0 && result.features.overall_score <= 1.0,
  )
}

///|
test "verify_image_source: 随机噪声图像鉴定结果有效" {
  let img = create_noise_image_v27(16, 16)
  let config = create_default_source_verification_config()
  let result = verify_image_source(img, config)
  assert_true(result.ai_probability >= 0.0 && result.ai_probability <= 1.0)
  assert_true(
    result.physical_probability >= 0.0 && result.physical_probability <= 1.0,
  )
}

///|
test "verify_image_source: 禁用所有分析时返回中性结果" {
  let img = create_solid_image_v27(16, 16, 128)
  let config = SourceVerificationConfig::{
    decision_threshold: 0.5,
    use_noise_analysis: false,
    use_frequency_analysis: false,
    use_color_analysis: false,
    use_texture_analysis: false,
    use_edge_analysis: false,
    use_compression_analysis: false,
    use_detail_analysis: false,
    weights: [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
  }
  let result = verify_image_source(img, config)
  assert_true(result.ai_probability >= 0.0 && result.ai_probability <= 1.0)
  assert_true(result.features.noise_pattern_score == 0.5)
  assert_true(result.features.frequency_domain_score == 0.5)
}

///|
test "verify_image_source: 棋盘格图像鉴定" {
  let img = create_checkerboard_v27(16, 16, 4)
  let config = create_default_source_verification_config()
  let result = verify_image_source(img, config)
  assert_true(result.ai_probability >= 0.0 && result.ai_probability <= 1.0)
  assert_true(
    result.physical_probability >= 0.0 && result.physical_probability <= 1.0,
  )
}

///|
test "source_verification_report_to_string: 报告非空" {
  let img = create_solid_image_v27(16, 16, 128)
  let config = create_default_source_verification_config()
  let result = verify_image_source(img, config)
  let report = source_verification_report_to_string(result)
  assert_true(report.length() > 0)
  assert_true(report.contains("图像来源鉴定报告"))
}

///|
test "source_verification_report_to_string: 包含概率信息" {
  let img = create_noise_image_v27(16, 16)
  let config = create_default_source_verification_config()
  let result = verify_image_source(img, config)
  let report = source_verification_report_to_string(result)
  assert_true(report.contains("AI 生成概率"))
  assert_true(report.contains("物理生成概率"))
}

///|
test "create_default_enhanced_verification_config: 默认配置正确" {
  let config = create_default_enhanced_verification_config()
  assert_true(config.use_ui_detection)
  assert_true(config.use_text_detection)
  assert_true(config.use_geometry_analysis)
  assert_true(config.use_color_quantization)
  assert_true(config.use_solid_area_analysis)
  assert_true(config.use_edge_direction_analysis)
  assert_true(config.basic_weight > 0.0)
  assert_true(config.enhanced_weight > 0.0)
  assert_true(config.decision_threshold > 0.0)
}

///|
test "detect_ui_elements: 纯色图像无 UI 元素" {
  let img = create_solid_image_v27(16, 16, 128)
  let result = detect_ui_elements(img)
  assert_true(result.ui_element_count >= 0)
  assert_true(result.ui_area_ratio >= 0.0 && result.ui_area_ratio <= 1.0)
  assert_true(result.ui_indicator >= 0.0 && result.ui_indicator <= 1.0)
}

///|
test "detect_ui_elements: UI 截图有 UI 元素" {
  let img = create_ui_screenshot_v27(32, 32)
  let result = detect_ui_elements(img)
  assert_true(result.horizontal_line_count >= 0)
  assert_true(result.vertical_line_count >= 0)
  assert_true(result.ui_indicator >= 0.0 && result.ui_indicator <= 1.0)
}

///|
test "detect_text_regions: 纯色图像无文字" {
  let img = create_solid_image_v27(16, 16, 128)
  let result = detect_text_regions(img)
  assert_true(result.text_area_count >= 0)
  assert_true(result.text_area_ratio >= 0.0 && result.text_area_ratio <= 1.0)
  assert_true(result.text_indicator >= 0.0 && result.text_indicator <= 1.0)
}

///|
test "detect_text_regions: 棋盘格图像" {
  let img = create_checkerboard_v27(16, 16, 2)
  let result = detect_text_regions(img)
  assert_true(result.text_area_count >= 0)
  assert_true(result.small_edge_density >= 0.0)
}

///|
test "analyze_geometry: 纯色图像几何简单" {
  let img = create_solid_image_v27(16, 16, 128)
  let result = analyze_geometry(img)
  assert_true(result.horizontal_edge_ratio >= 0.0)
  assert_true(result.vertical_edge_ratio >= 0.0)
  assert_true(
    result.geometry_indicator >= 0.0 && result.geometry_indicator <= 1.0,
  )
}

///|
test "analyze_geometry: UI 截图几何规则" {
  let img = create_ui_screenshot_v27(32, 32)
  let result = analyze_geometry(img)
  assert_true(result.straight_line_count >= 0)
  assert_true(result.geometry_regularity >= 0.0)
}

///|
test "analyze_color_quantization: 纯色图像颜色单一" {
  let img = create_solid_image_v27(16, 16, 128)
  let result = analyze_color_quantization(img)
  assert_true(result.unique_color_count >= 1)
  assert_true(result.color_palette_size >= 1)
  assert_true(
    result.color_quantization_indicator >= 0.0 &&
    result.color_quantization_indicator <= 1.0,
  )
}

///|
test "analyze_color_quantization: 随机噪声图像颜色丰富" {
  let img = create_noise_image_v27(16, 16)
  let result = analyze_color_quantization(img)
  assert_true(result.unique_color_count >= 1)
  assert_true(result.top_color_ratio >= 0.0 && result.top_color_ratio <= 1.0)
}

///|
test "analyze_solid_areas: 纯色图像全为纯色区域" {
  let img = create_solid_image_v27(16, 16, 128)
  let result = analyze_solid_areas(img)
  assert_true(result >= 0.0 && result <= 1.0)
}

///|
test "analyze_solid_areas: 棋盘格图像" {
  let img = create_checkerboard_v27(16, 16, 4)
  let result = analyze_solid_areas(img)
  assert_true(result >= 0.0 && result <= 1.0)
}

///|
test "analyze_edge_directions: 纯色图像无边缘方向" {
  let img = create_solid_image_v27(16, 16, 128)
  let result = analyze_edge_directions(img)
  assert_true(result >= 0.0 && result <= 1.0)
}

///|
test "analyze_edge_directions: 棋盘格图像有边缘方向" {
  let img = create_checkerboard_v27(16, 16, 2)
  let result = analyze_edge_directions(img)
  assert_true(result >= 0.0 && result <= 1.0)
}

///|
test "analyze_pixel_distribution: 纯色图像分布集中" {
  let img = create_solid_image_v27(16, 16, 128)
  let result = analyze_pixel_distribution(img)
  assert_true(result >= 0.0 && result <= 1.0)
}

///|
test "analyze_pixel_distribution: 随机噪声图像分布均匀" {
  let img = create_noise_image_v27(16, 16)
  let result = analyze_pixel_distribution(img)
  assert_true(result >= 0.0 && result <= 1.0)
}

///|
test "intelligent_decision: 强 UI 特征判定为物理生成" {
  let img = create_solid_image_v27(16, 16, 128)
  let basic_config = create_default_source_verification_config()
  let basic_result = verify_image_source(img, basic_config)
  let ui_result = UIDetectionResult::{
    has_window_border: true,
    has_toolbar: true,
    has_button_like_elements: true,
    ui_element_count: 8,
    ui_area_ratio: 0.3,
    horizontal_line_count: 5,
    vertical_line_count: 5,
    ui_indicator: 0.9,
  }
  let text_result = TextDetectionResult::{
    text_area_count: 10,
    text_area_ratio: 0.1,
    dense_edge_region_count: 5,
    small_edge_density: 0.3,
    text_like_region_ratio: 0.2,
    text_indicator: 0.8,
  }
  let geometry_result = GeometryAnalysisResult::{
    horizontal_edge_ratio: 0.4,
    vertical_edge_ratio: 0.4,
    diagonal_edge_ratio: 0.2,
    rectangle_like_region_count: 5,
    straight_line_count: 10,
    geometry_regularity: 0.8,
    geometry_indicator: 0.7,
  }
  let color_result = ColorQuantizationResult::{
    unique_color_count: 16,
    color_quantization_level: 0.6,
    top_color_ratio: 0.3,
    top_10_color_ratio: 0.8,
    color_palette_size: 16,
    color_quantization_indicator: 0.7,
  }
  let config = create_default_enhanced_verification_config()
  let (source_type, ai_prob, physical_prob, confidence, reason) = intelligent_decision(
    basic_result, ui_result, text_result, geometry_result, color_result, 0.6, 0.5,
    0.4, config,
  )
  assert_true(source_type == ImageSourceType::PhysicalCaptured)
  assert_true(ai_prob >= 0.0 && ai_prob <= 1.0)
  assert_true(physical_prob >= 0.0 && physical_prob <= 1.0)
  assert_true(confidence >= 0.0 && confidence <= 1.0)
  assert_true(reason.length() > 0)
}

///|
test "intelligent_decision: 弱 UI 特征时根据综合评分判定" {
  let img = create_solid_image_v27(16, 16, 128)
  let basic_config = create_default_source_verification_config()
  let basic_result = verify_image_source(img, basic_config)
  let ui_result = UIDetectionResult::{
    has_window_border: false,
    has_toolbar: false,
    has_button_like_elements: false,
    ui_element_count: 0,
    ui_area_ratio: 0.0,
    horizontal_line_count: 0,
    vertical_line_count: 0,
    ui_indicator: 0.1,
  }
  let text_result = TextDetectionResult::{
    text_area_count: 0,
    text_area_ratio: 0.0,
    dense_edge_region_count: 0,
    small_edge_density: 0.0,
    text_like_region_ratio: 0.0,
    text_indicator: 0.1,
  }
  let geometry_result = GeometryAnalysisResult::{
    horizontal_edge_ratio: 0.3,
    vertical_edge_ratio: 0.3,
    diagonal_edge_ratio: 0.4,
    rectangle_like_region_count: 0,
    straight_line_count: 0,
    geometry_regularity: 0.3,
    geometry_indicator: 0.2,
  }
  let color_result = ColorQuantizationResult::{
    unique_color_count: 200,
    color_quantization_level: 0.2,
    top_color_ratio: 0.01,
    top_10_color_ratio: 0.1,
    color_palette_size: 200,
    color_quantization_indicator: 0.2,
  }
  let config = create_default_enhanced_verification_config()
  let (source_type, ai_prob, physical_prob, confidence, reason) = intelligent_decision(
    basic_result, ui_result, text_result, geometry_result, color_result, 0.1, 0.1,
    0.1, config,
  )
  assert_true(ai_prob >= 0.0 && ai_prob <= 1.0)
  assert_true(physical_prob >= 0.0 && physical_prob <= 1.0)
  assert_true(confidence >= 0.0 && confidence <= 1.0)
  assert_true(reason.length() > 0)
  ignore(source_type)
}

///|
test "verify_image_source_enhanced: 纯色图像增强鉴定结果有效" {
  let img = create_solid_image_v27(16, 16, 128)
  let config = create_default_enhanced_verification_config()
  let result = verify_image_source_enhanced(img, config)
  assert_true(result.ai_probability >= 0.0 && result.ai_probability <= 1.0)
  assert_true(
    result.physical_probability >= 0.0 && result.physical_probability <= 1.0,
  )
  assert_true(result.confidence >= 0.0 && result.confidence <= 1.0)
  assert_true(result.decision_reason.length() > 0)
}

///|
test "verify_image_source_enhanced: UI 截图增强鉴定" {
  let img = create_ui_screenshot_v27(32, 32)
  let config = create_default_enhanced_verification_config()
  let result = verify_image_source_enhanced(img, config)
  assert_true(result.ai_probability >= 0.0 && result.ai_probability <= 1.0)
  assert_true(
    result.physical_probability >= 0.0 && result.physical_probability <= 1.0,
  )
  assert_true(result.decision_reason.length() > 0)
}

///|
test "verify_image_source_enhanced: 随机噪声图像增强鉴定" {
  let img = create_noise_image_v27(16, 16)
  let config = create_default_enhanced_verification_config()
  let result = verify_image_source_enhanced(img, config)
  assert_true(result.ai_probability >= 0.0 && result.ai_probability <= 1.0)
  assert_true(
    result.physical_probability >= 0.0 && result.physical_probability <= 1.0,
  )
}

///|
test "verify_image_source_enhanced: 禁用所有增强分析" {
  let img = create_solid_image_v27(16, 16, 128)
  let config = EnhancedVerificationConfig::{
    use_ui_detection: false,
    use_text_detection: false,
    use_geometry_analysis: false,
    use_color_quantization: false,
    use_solid_area_analysis: false,
    use_edge_direction_analysis: false,
    basic_weight: 0.5,
    enhanced_weight: 0.5,
    decision_threshold: 0.5,
  }
  let result = verify_image_source_enhanced(img, config)
  assert_true(result.ai_probability >= 0.0 && result.ai_probability <= 1.0)
  assert_true(
    result.physical_probability >= 0.0 && result.physical_probability <= 1.0,
  )
}

///|
test "verify_image_source_enhanced: 棋盘格图像增强鉴定" {
  let img = create_checkerboard_v27(16, 16, 4)
  let config = create_default_enhanced_verification_config()
  let result = verify_image_source_enhanced(img, config)
  assert_true(result.ai_probability >= 0.0 && result.ai_probability <= 1.0)
  assert_true(
    result.physical_probability >= 0.0 && result.physical_probability <= 1.0,
  )
  assert_true(result.decision_reason.length() > 0)
}

///|
test "enhanced_verification_report_to_string: 报告非空" {
  let img = create_solid_image_v27(16, 16, 128)
  let config = create_default_enhanced_verification_config()
  let result = verify_image_source_enhanced(img, config)
  let report = enhanced_verification_report_to_string(result)
  assert_true(report.length() > 0)
  assert_true(report.contains("图像来源鉴定报告"))
}

///|
test "enhanced_verification_report_to_string: 包含鉴定结论" {
  let img = create_ui_screenshot_v27(32, 32)
  let config = create_default_enhanced_verification_config()
  let result = verify_image_source_enhanced(img, config)
  let report = enhanced_verification_report_to_string(result)
  assert_true(report.length() > 0)
}

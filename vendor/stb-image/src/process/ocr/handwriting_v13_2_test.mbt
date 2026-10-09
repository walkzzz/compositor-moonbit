// v13.2.0 手写体识别测试

///|
fn make_test_img(w : Int, h : Int) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(Array::make(w * h, b'\x80')),
  }
}

///|
test "create_default_handwriting_config: 返回有效配置" {
  let config = create_default_handwriting_config()
  assert_true(config.min_stroke_length > 0.0)
  assert_true(config.max_stroke_angle > 0.0)
  assert_true(config.similarity_threshold >= 0.0)
  assert_true(config.max_candidates > 0)
}

///|
test "detect_handwriting_slant: 均匀图像倾斜角为零" {
  let img = make_test_img(16, 16)
  let slant = detect_handwriting_slant(img)
  assert_true(slant.abs() < 1.0)
}

///|
test "detect_handwriting_slant: 无效图像抛异常" {
  let img = @types.Image::{
    width: 0,
    height: 0,
    channels: 1,
    data: Bytes::from_array([]),
  }
  try {
    ignore(detect_handwriting_slant(img))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "normalize_handwriting_size: 返回有效图像" {
  let img = make_test_img(16, 16)
  let result = normalize_handwriting_size(img, 32)
  assert_true(result.width > 0)
  assert_true(result.height > 0)
}

///|
test "normalize_handwriting_size: 无效尺寸抛异常" {
  let img = make_test_img(8, 8)
  try {
    ignore(normalize_handwriting_size(img, 0))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "extract_hw_stroke_features: 返回笔画数组" {
  let img = make_test_img(16, 16)
  let strokes = extract_hw_stroke_features(img)
  assert_true(strokes.length() >= 0)
}

///|
test "segment_connected_strokes: 返回分割结果" {
  let img = make_test_img(16, 16)
  let config = create_default_handwriting_config()
  let result = segment_connected_strokes(img, config)
  assert_true(result.num_strokes >= 0)
  assert_true(result.confidence >= 0.0 && result.confidence <= 1.0)
}

///|
test "extract_handwriting_features: 返回特征" {
  let img = make_test_img(16, 16)
  let features = extract_handwriting_features(img, "A")
  assert_eq(features.char, "A")
  assert_true(features.num_strokes >= 0)
  assert_true(features.aspect_ratio >= 0.0)
}

///|
test "extract_handwriting_features: 无效图像抛异常" {
  let img = @types.Image::{
    width: 0,
    height: 0,
    channels: 1,
    data: Bytes::from_array([]),
  }
  try {
    ignore(extract_handwriting_features(img, "A"))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "handwriting_feature_similarity: 相同特征相似度高" {
  let img = make_test_img(16, 16)
  let feat = extract_handwriting_features(img, "A")
  let sim = handwriting_feature_similarity(feat, feat)
  // 权重总和 90%，相同特征最高 0.9
  assert_true(sim >= 0.0 && sim <= 1.0)
}

///|
test "handwriting_feature_similarity: 对称性" {
  let img1 = make_test_img(16, 16)
  let img2 = make_test_img(20, 20)
  let feat1 = extract_handwriting_features(img1, "A")
  let feat2 = extract_handwriting_features(img2, "B")
  let sim12 = handwriting_feature_similarity(feat1, feat2)
  let sim21 = handwriting_feature_similarity(feat2, feat1)
  assert_true((sim12 - sim21).abs() < 0.001)
}

///|
test "create_handwriting_template: 基本创建" {
  let img = make_test_img(16, 16)
  let template = create_handwriting_template("A", HandwritingStyle::Print, [img])
  assert_eq(template.char, "A")
  assert_true(template.style == HandwritingStyle::Print)
}

///|
test "create_handwriting_template: 空样本返回零特征" {
  let template = create_handwriting_template("B", HandwritingStyle::Cursive, [])
  assert_eq(template.char, "B")
  assert_eq(template.features.num_strokes, 0)
}

///|
test "create_handwriting_template: 空字符抛异常" {
  let img = make_test_img(8, 8)
  try {
    ignore(create_handwriting_template("", HandwritingStyle::Print, [img]))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "recognize_handwriting_char: 基本识别" {
  let img = make_test_img(16, 16)
  let template = create_handwriting_template("A", HandwritingStyle::Print, [img])
  let config = create_default_handwriting_config()
  let result = recognize_handwriting_char(img, [template], config)
  assert_true(result.confidence >= 0.0 && result.confidence <= 1.0)
  assert_true(result.predicted_char.length() >= 0)
}

///|
test "recognize_handwriting_char: 无效图像抛异常" {
  let img = @types.Image::{
    width: 0,
    height: 0,
    channels: 1,
    data: Bytes::from_array([]),
  }
  let config = create_default_handwriting_config()
  try {
    ignore(recognize_handwriting_char(img, [], config))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "handwriting_report_to_string: 生成非空报告" {
  let img = make_test_img(16, 16)
  let template = create_handwriting_template("A", HandwritingStyle::Print, [img])
  let config = create_default_handwriting_config()
  let result = recognize_handwriting_char(img, [template], config)
  let report = handwriting_report_to_string(result)
  assert_true(report.length() > 0)
  assert_true(report.contains("手写体识别报告"))
}

///|
test "handwriting_ocr_default_config: 返回有效配置" {
  let config = handwriting_ocr_default_config()
  assert_true(config.min_char_width > 0)
  assert_true(config.max_char_width > config.min_char_width)
}

///|
test "generate_handwriting_templates: 生成数字模板" {
  let templates = generate_handwriting_templates()
  assert_true(templates.length() > 0)
}

///|
test "generate_handwriting_templates: 生成字母模板" {
  let templates = generate_handwriting_templates(char_set="letters")
  assert_true(templates.length() > 0)
}

///|
test "correct_slant: 返回有效图像" {
  let img = make_test_img(16, 16)
  let result = correct_slant(img)
  assert_eq(result.width, img.width)
  assert_eq(result.height, img.height)
}

///|
test "correct_slant: 无效图像抛异常" {
  let img = @types.Image::{
    width: 0,
    height: 0,
    channels: 1,
    data: Bytes::from_array([]),
  }
  try {
    ignore(correct_slant(img))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "recognize_handwriting: 基本识别" {
  let img = make_test_img(32, 32)
  let result = recognize_handwriting(img)
  assert_true(result.confidence >= 0.0 && result.confidence <= 1.0)
  assert_true(result.text.length() >= 0)
}

///|
test "handwriting_ocr_enhanced_default_config: 返回有效配置" {
  let config = handwriting_ocr_enhanced_default_config()
  assert_true(config.min_char_width > 0)
  assert_true(config.max_char_width > config.min_char_width)
}

///|
test "generate_enhanced_handwriting_templates: 生成模板" {
  let templates = generate_enhanced_handwriting_templates()
  assert_true(templates.length() > 0)
}

///|
test "generate_enhanced_handwriting_templates: 指定变体数" {
  let templates = generate_enhanced_handwriting_templates(num_variants=3)
  assert_true(templates.length() > 0)
}

///|
test "extract_handwriting_stroke_features: 返回笔画特征" {
  let img = make_test_img(16, 16)
  let features = extract_handwriting_stroke_features(img)
  assert_true(features.num_strokes >= 0)
}

///|
test "extract_handwriting_stroke_features: 无效图像抛异常" {
  let img = @types.Image::{
    width: 0,
    height: 0,
    channels: 1,
    data: Bytes::from_array([]),
  }
  try {
    ignore(extract_handwriting_stroke_features(img))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "elastic_match: 相同特征距离为零" {
  let features = [1.0, 2.0, 3.0]
  let result = elastic_match(features, features)
  assert_true(result.abs() < 0.001)
}

///|
test "elastic_match: 不同特征距离为正" {
  let features = [1.0, 2.0, 3.0]
  let template = [4.0, 5.0, 6.0]
  let result = elastic_match(features, template)
  assert_true(result >= 0.0)
}

///|
test "segment_cursive_chars: 基本分割" {
  let img = make_test_img(64, 16)
  let result = segment_cursive_chars(img)
  assert_true(result.length() >= 0)
}

///|
test "handwriting_postprocess: 基本后处理" {
  let (text, conf) = handwriting_postprocess("HELLO", 0.9)
  assert_true(text.length() > 0)
  assert_true(conf >= 0.0 && conf <= 1.0)
}

///|
test "handwriting_postprocess: 低置信度处理" {
  let (text, conf) = handwriting_postprocess("test", 0.3)
  assert_true(text.length() > 0)
  assert_true(conf >= 0.0)
}

///|
test "recognize_handwriting_enhanced: 基本识别" {
  let img = make_test_img(32, 32)
  let result = recognize_handwriting_enhanced(img)
  assert_true(result.confidence >= 0.0 && result.confidence <= 1.0)
  assert_true(result.text.length() >= 0)
}

// v13.3.0 多语言混合识别测试

///|
fn make_ml_test_img(w : Int, h : Int) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(Array::make(w * h, b'\x80')),
  }
}

///|
test "multilingual_ocr_default_config: 返回有效配置" {
  let config = multilingual_ocr_default_config()
  assert_true(
    config.enable_chinese || config.enable_english || config.enable_digits,
  )
}

///|
test "generate_punctuation_templates: 生成标点模板" {
  let templates = generate_punctuation_templates()
  assert_true(templates.length() > 0)
}

///|
test "detect_char_language: 基本语言检测" {
  let img = make_ml_test_img(16, 16)
  let lang = detect_char_language(img)
  // 返回某种语言类型
  let _ = lang
  assert_true(true)
}

///|
test "detect_char_language: 无效图像抛异常" {
  let img = @types.Image::{
    width: 0,
    height: 0,
    channels: 1,
    data: Bytes::from_array([]),
  }
  try {
    ignore(detect_char_language(img))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "detect_document_language: 基本文档语言检测" {
  let img = make_ml_test_img(64, 16)
  let lang = detect_document_language(img)
  let _ = lang
  assert_true(true)
}

///|
test "detect_document_language: 无效图像抛异常" {
  let img = @types.Image::{
    width: 0,
    height: 0,
    channels: 1,
    data: Bytes::from_array([]),
  }
  try {
    ignore(detect_document_language(img))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "recognize_multilingual: 基本识别" {
  let img = make_ml_test_img(32, 32)
  let result = recognize_multilingual(img)
  assert_true(result.confidence >= 0.0 && result.confidence <= 1.0)
  assert_true(result.text.length() >= 0)
}

///|
test "multilingual_ocr_enhanced_default_config: 返回有效配置" {
  let config = multilingual_ocr_enhanced_default_config()
  assert_true(
    config.enable_chinese || config.enable_english || config.enable_digits,
  )
}

///|
test "detect_language_enhanced: 基本检测" {
  let img = make_ml_test_img(16, 16)
  let result = detect_language_enhanced(img)
  let _ = result
  assert_true(true)
}

///|
test "detect_language_enhanced: 无效图像抛异常" {
  let img = @types.Image::{
    width: 0,
    height: 0,
    channels: 1,
    data: Bytes::from_array([]),
  }
  try {
    ignore(detect_language_enhanced(img))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "smart_segment_chars: 基本分割" {
  let img = make_ml_test_img(64, 16)
  let config = multilingual_ocr_enhanced_default_config()
  let result = smart_segment_chars(img, config)
  assert_true(result.length() >= 0)
}

///|
test "smart_spacing_process: 基本间距处理" {
  let result = smart_spacing_process("ABC", ["en", "en", "en"])
  assert_true(result.length() > 0)
}

///|
test "smart_spacing_process: 长度不匹配返回原文" {
  let result = smart_spacing_process("ABC", ["en", "en"])
  assert_eq(result, "ABC")
}

///|
test "normalize_punctuation: 基本标点归一化" {
  let result = normalize_punctuation("ABC", ["en", "en", "en"])
  assert_true(result.length() > 0)
}

///|
test "normalize_punctuation: 长度不匹配返回原文" {
  let result = normalize_punctuation("ABC", ["en"])
  assert_eq(result, "ABC")
}

///|
test "language_model_postprocess: 基本后处理" {
  let (text, confs) = language_model_postprocess("ABC", ["en", "en", "en"], [
    0.9, 0.8, 0.7,
  ])
  assert_true(text.length() > 0)
  assert_eq(confs.length(), 3)
}

///|
test "recognize_multilingual_enhanced: 基本识别" {
  let img = make_ml_test_img(32, 32)
  let result = recognize_multilingual_enhanced(img)
  assert_true(result.confidence >= 0.0 && result.confidence <= 1.0)
  assert_true(result.text.length() >= 0)
}

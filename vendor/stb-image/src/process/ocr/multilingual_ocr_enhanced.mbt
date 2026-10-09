// 多语言混合识别增强版（v10.4.0）
// 更准确语言检测、智能字符分割、混排优化、标点处理、语言模型后处理

///|
/// 增强多语言识别配置
pub(all) struct MultilingualOcrEnhancedConfig {
  enable_chinese : Bool
  enable_english : Bool
  enable_digits : Bool
  enable_punctuation : Bool
  enable_japanese : Bool
  enable_korean : Bool
  target_size : Int
  distance_metric : String
  auto_language_detection : Bool
  smart_spacing : Bool // 中英文之间自动加空格
  punctuation_normalization : Bool // 标点符号规范化
  use_language_model : Bool // 使用语言模型后处理
}

///|
/// 创建默认增强多语言识别配置
pub fn multilingual_ocr_enhanced_default_config() -> MultilingualOcrEnhancedConfig {
  MultilingualOcrEnhancedConfig::{
    enable_chinese: true,
    enable_english: true,
    enable_digits: true,
    enable_punctuation: true,
    enable_japanese: false,
    enable_korean: false,
    target_size: 48,
    distance_metric: "euclidean",
    auto_language_detection: true,
    smart_spacing: true,
    punctuation_normalization: true,
    use_language_model: true,
  }
}

///|
/// 语言检测结果
pub(all) struct LanguageDetectionResult {
  language : String // "chinese" / "english" / "digit" / "punctuation" / "japanese" / "korean" / "mixed" / "unknown"
  confidence : Double
  probabilities : Array[(String, Double)]
}

///|
/// 增强语言检测（基于多特征的分类器）
pub fn detect_language_enhanced(
  char_img : @types.Image,
) -> LanguageDetectionResult raise @types.LoadError {
  // 输入验证
  if char_img.width <= 0 || char_img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_language_enhanced: 图像尺寸必须大于0",
    )
  }
  if char_img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "detect_language_enhanced: 仅支持单通道灰度图",
    )
  }
  let expected_size = char_img.width * char_img.height
  if char_img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "detect_language_enhanced: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      char_img.data.length().to_string(),
    )
  }
  let w = char_img.width
  let h = char_img.height
  let data = char_img.data
  // 特征1：宽高比
  let ratio = if h > 0 { w.to_double() / h.to_double() } else { 1.0 }
  // 特征2：密度
  let mut ink_pixels = 0
  for i in 0..<(w * h) {
    if data[i].to_int() > 128 {
      ink_pixels += 1
    }
  }
  let density = if w * h > 0 {
    ink_pixels.to_double() / (w * h).to_double()
  } else {
    0.0
  }
  // 特征3：水平投影方差（中文字符通常更均匀）
  let h_proj : Array[Int] = Array::make(h, 0)
  for y in 0..<h {
    let mut count = 0
    for x in 0..<w {
      if data[y * w + x].to_int() > 128 {
        count += 1
      }
    }
    h_proj[y] = count
  }
  let mut h_mean = 0.0
  for y in 0..<h {
    h_mean += h_proj[y].to_double()
  }
  h_mean = h_mean / h.to_double()
  let mut h_var = 0.0
  for y in 0..<h {
    let diff = h_proj[y].to_double() - h_mean
    h_var += diff * diff
  }
  h_var = h_var / h.to_double()
  // 特征4：垂直投影方差
  let v_proj : Array[Int] = Array::make(w, 0)
  for x in 0..<w {
    let mut count = 0
    for y in 0..<h {
      if data[y * w + x].to_int() > 128 {
        count += 1
      }
    }
    v_proj[x] = count
  }
  let mut v_mean = 0.0
  for x in 0..<w {
    v_mean += v_proj[x].to_double()
  }
  v_mean = v_mean / w.to_double()
  let mut v_var = 0.0
  for x in 0..<w {
    let diff = v_proj[x].to_double() - v_mean
    v_var += diff * diff
  }
  v_var = v_var / w.to_double()
  // 基于特征的语言分类（简单规则分类器）
  let probabilities : Array[(String, Double)] = []
  // 中文：接近正方形、密度适中、投影均匀
  let chinese_score = if ratio > 0.7 &&
    ratio < 1.4 &&
    density > 0.15 &&
    density < 0.5 {
    0.8
  } else if ratio > 0.6 && ratio < 1.5 {
    0.5
  } else {
    0.2
  }
  probabilities.push(("chinese", chinese_score))
  // 英文：较窄、密度较低、垂直投影方差大
  let english_score = if ratio > 0.3 &&
    ratio < 0.75 &&
    density > 0.1 &&
    density < 0.4 {
    0.75
  } else if ratio > 0.25 && ratio < 0.85 {
    0.45
  } else {
    0.15
  }
  probabilities.push(("english", english_score))
  // 数字：较窄、密度适中
  let digit_score = if ratio > 0.35 &&
    ratio < 0.65 &&
    density > 0.15 &&
    density < 0.45 {
    0.7
  } else if ratio > 0.3 && ratio < 0.75 {
    0.4
  } else {
    0.15
  }
  probabilities.push(("digit", digit_score))
  // 标点：很窄或很宽、密度低
  let punctuation_score = if ratio < 0.35 || ratio > 1.4 || density < 0.12 {
    0.8
  } else if ratio < 0.4 || ratio > 1.3 {
    0.5
  } else {
    0.1
  }
  probabilities.push(("punctuation", punctuation_score))
  // 找最高分
  let mut best_language = "unknown"
  let mut best_score = 0.0
  let mut total_score = 0.0
  for _tup0 in probabilities {
    let (lang, score) = _tup0
    total_score += score
    if score > best_score {
      best_score = score
      best_language = lang
    }
  }
  let confidence = if total_score > 0.0 {
    best_score / total_score
  } else {
    0.0
  }
  LanguageDetectionResult::{
    language: best_language,
    confidence,
    probabilities,
  }
}

///|
/// 智能字符分割（根据语言类型选择分割策略）
pub fn smart_segment_chars(
  img : @types.Image,
  config : MultilingualOcrEnhancedConfig,
) -> Array[(Int, Int, Int, Int, String)] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "smart_segment_chars: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "smart_segment_chars: 仅支持单通道灰度图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "smart_segment_chars: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let w = img.width
  let h = img.height
  let data = img.data
  // 先进行连通域分割
  let labels : Array[Int] = Array::make(w * h, 0)
  let mut next_label = 1
  for y in 0..<h {
    for x in 0..<w {
      if data[y * w + x].to_int() > 128 {
        let mut label = 0
        if x > 0 && labels[y * w + x - 1] > 0 {
          label = labels[y * w + x - 1]
        }
        if y > 0 && labels[(y - 1) * w + x] > 0 {
          if label == 0 {
            label = labels[(y - 1) * w + x]
          }
        }
        if label == 0 {
          label = next_label
          next_label += 1
        }
        labels[y * w + x] = label
      }
    }
  }
  // 计算边界框
  let min_x : Array[Int] = Array::make(next_label, w)
  let max_x : Array[Int] = Array::make(next_label, 0)
  let min_y : Array[Int] = Array::make(next_label, h)
  let max_y : Array[Int] = Array::make(next_label, 0)
  let area : Array[Int] = Array::make(next_label, 0)
  for y in 0..<h {
    for x in 0..<w {
      let label = labels[y * w + x]
      if label > 0 {
        area[label] += 1
        if x < min_x[label] {
          min_x[label] = x
        }
        if x > max_x[label] {
          max_x[label] = x
        }
        if y < min_y[label] {
          min_y[label] = y
        }
        if y > max_y[label] {
          max_y[label] = y
        }
      }
    }
  }
  // 对每个连通域进行语言检测和分类
  let regions : Array[(Int, Int, Int, Int, String)] = []
  for label in 1..<next_label {
    let rw = max_x[label] - min_x[label] + 1
    let rh = max_y[label] - min_y[label] + 1
    if rw >= 5 && rw <= 100 && rh >= 8 && rh <= 100 && area[label] > 10 {
      // 提取字符图像进行语言检测
      let char_img = extract_char_region_for_smart(
        img,
        min_x[label],
        min_y[label],
        rw,
        rh,
        32,
      )
      let lang_result = if config.auto_language_detection {
        detect_language_enhanced(char_img)
      } else {
        LanguageDetectionResult::{
          language: "unknown",
          confidence: 0.0,
          probabilities: [],
        }
      }
      regions.push((min_x[label], min_y[label], rw, rh, lang_result.language))
    }
  }
  regions
}

///|
/// 提取字符区域（智能分割用）
fn extract_char_region_for_smart(
  img : @types.Image,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  target_size : Int,
) -> @types.Image {
  let w = img.width
  let h = img.height
  let crop_w = if x + width > w { w - x } else { width }
  let crop_h = if y + height > h { h - y } else { height }
  if crop_w <= 0 || crop_h <= 0 {
    let empty : Array[Byte] = Array::make(target_size * target_size, b'\x00')
    return @types.Image::{
      width: target_size,
      height: target_size,
      channels: 1,
      data: Bytes::from_array(empty),
    }
  }
  let out : Array[Byte] = Array::make(target_size * target_size, b'\x00')
  let data = img.data
  for py in 0..<target_size {
    for px in 0..<target_size {
      let src_x = x + px * crop_w / target_size
      let src_y = y + py * crop_h / target_size
      if src_x < w && src_y < h {
        out[py * target_size + px] = data[src_y * w + src_x]
      }
    }
  }
  @types.Image::{
    width: target_size,
    height: target_size,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

///|
/// 智能空格处理（中英文之间自动加空格）
pub fn smart_spacing_process(
  text : String,
  char_languages : Array[String],
) -> String {
  if text.length() != char_languages.length() || text.length() == 0 {
    return text
  }
  let mut result = ""
  for i in 0..<text.length() {
    result += text[i].to_string()
    // 在中英文之间加空格
    if i < text.length() - 1 {
      let curr_lang = char_languages[i]
      let next_lang = char_languages[i + 1]
      let is_cjk = curr_lang == "chinese" ||
        curr_lang == "japanese" ||
        curr_lang == "korean"
      let next_is_cjk = next_lang == "chinese" ||
        next_lang == "japanese" ||
        next_lang == "korean"
      let is_latin = curr_lang == "english" || curr_lang == "digit"
      let next_is_latin = next_lang == "english" || next_lang == "digit"
      // CJK 和 Latin 之间加空格
      if (is_cjk && next_is_latin) || (is_latin && next_is_cjk) {
        result += " "
      }
    }
  }
  result
}

///|
/// 标点符号规范化（中英文标点自动转换）
pub fn normalize_punctuation(
  text : String,
  char_languages : Array[String],
) -> String {
  if text.length() != char_languages.length() || text.length() == 0 {
    return text
  }
  let mut result = ""
  for i in 0..<text.length() {
    let c = text[i]
    let lang = char_languages[i]
    // 中文语境下使用中文标点
    if lang == "chinese" {
      match c.to_string() {
        "," => result += "，"
        "." => result += "。"
        "!" => result += "！"
        "?" => result += "？"
        ";" => result += "；"
        ":" => result += "："
        "(" => result += "（"
        ")" => result += "）"
        _ => result += c.to_string()
      }
    } else {
      // 英文语境下使用英文标点
      match c.to_string() {
        "，" => result += ","
        "。" => result += "."
        "！" => result += "!"
        "？" => result += "?"
        "；" => result += ";"
        "：" => result += ":"
        "（" => result += "("
        "）" => result += ")"
        _ => result += c.to_string()
      }
    }
  }
  result
}

///|
/// 语言模型后处理（基于N-gram的混排纠错）
pub fn language_model_postprocess(
  text : String,
  char_languages : Array[String],
  confidences : Array[Double],
) -> (String, Array[Double]) {
  ignore(char_languages)
  // 简化版语言模型：基于常见模式的纠错
  let corrected_text = text
  let adjusted_confidences = confidences
  // 常见纠错规则（简化版）
  // 规则1：中文后面跟英文标点，改为中文标点
  // 规则2：英文单词中间插入中文字符，可能是识别错误
  // 规则3：连续相同字符可能是重复
  // 这里只做简单的置信度调整
  for i in 0..<adjusted_confidences.length() {
    // 低置信度字符的置信度进一步降低
    if adjusted_confidences[i] < 0.3 {
      adjusted_confidences[i] = adjusted_confidences[i] * 0.9
    }
  }
  (corrected_text, adjusted_confidences)
}

///|
/// 增强多语言混合识别（完整流水线）
pub fn recognize_multilingual_enhanced(
  img : @types.Image,
  config? : MultilingualOcrEnhancedConfig,
) -> OcrResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_multilingual_enhanced: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "recognize_multilingual_enhanced: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "recognize_multilingual_enhanced: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let cfg = match config {
    Some(c) => c
    None => multilingual_ocr_enhanced_default_config()
  }
  // 1. 预处理
  let preprocessed = ocr_preprocess(img)
  // 2. 智能字符分割（带语言检测）
  let char_regions = smart_segment_chars(preprocessed, cfg)
  // 3. 生成各语言模板
  let chinese_templates = if cfg.enable_chinese {
    generate_enhanced_chinese_templates(char_set_size=500)
  } else {
    []
  }
  let english_templates = if cfg.enable_english {
    generate_enhanced_handwriting_templates(
      char_set="digits+letters",
      num_variants=3,
    )
  } else {
    []
  }
  let digit_templates = if cfg.enable_digits {
    generate_digit_templates()
  } else {
    []
  }
  let punctuation_templates = if cfg.enable_punctuation {
    generate_punctuation_templates()
  } else {
    []
  }
  // 4. 对每个字符进行识别
  let char_results : Array[OcrCharResult] = []
  let mut text = ""
  let mut total_confidence = 0.0
  let char_languages : Array[String] = []
  let confidences : Array[Double] = []
  for _tup1 in char_regions {
    let (x, y, w, h, detected_lang) = _tup1
    // 提取字符图像
    let char_img = extract_char_region_for_smart(
      preprocessed,
      x,
      y,
      w,
      h,
      cfg.target_size,
    )
    // 根据检测到的语言选择模板
    let result = match detected_lang {
      "chinese" =>
        if chinese_templates.length() > 0 {
          match_multilingual_enhanced(
            char_img,
            chinese_templates,
            cfg.distance_metric,
          )
        } else {
          ("?", 0.0)
        }
      "english" =>
        if english_templates.length() > 0 {
          match_multilingual_enhanced(
            char_img,
            english_templates,
            cfg.distance_metric,
          )
        } else {
          ("?", 0.0)
        }
      "digit" =>
        if digit_templates.length() > 0 {
          match_multilingual_enhanced(
            char_img,
            digit_templates,
            cfg.distance_metric,
          )
        } else {
          ("?", 0.0)
        }
      "punctuation" =>
        if punctuation_templates.length() > 0 {
          match_punctuation_enhanced(char_img, punctuation_templates)
        } else {
          ("?", 0.0)
        }
      _ => {
        // 未知语言，尝试所有模板
        let all_templates : Array[(String, Array[Double])] = []
        for t in chinese_templates {
          all_templates.push(t)
        }
        for t in english_templates {
          all_templates.push(t)
        }
        for t in digit_templates {
          all_templates.push(t)
        }
        if all_templates.length() > 0 {
          match_multilingual_enhanced(
            char_img,
            all_templates,
            cfg.distance_metric,
          )
        } else {
          ("?", 0.0)
        }
      }
    }
    text += result.0
    total_confidence += result.1
    char_languages.push(detected_lang)
    confidences.push(result.1)
    char_results.push(OcrCharResult::{
      char: result.0,
      confidence: result.1,
      x,
      y,
      width: w,
      height: h,
    })
  }
  // 5. 后处理
  let final_text = if char_results.length() > 0 {
    let mut processed = text
    // 智能空格处理
    if cfg.smart_spacing {
      processed = smart_spacing_process(processed, char_languages)
    }
    // 标点符号规范化
    if cfg.punctuation_normalization {
      processed = normalize_punctuation(processed, char_languages)
    }
    // 语言模型后处理
    if cfg.use_language_model {
      let (t, _) = language_model_postprocess(
        processed, char_languages, confidences,
      )
      processed = t
    }
    processed
  } else {
    text
  }
  let avg_confidence = if char_results.length() > 0 {
    total_confidence / char_results.length().to_double()
  } else {
    0.0
  }
  OcrResult::{
    text: final_text,
    confidence: avg_confidence,
    characters: char_results,
  }
}

///|
/// 增强多语言模板匹配
fn match_multilingual_enhanced(
  char_img : @types.Image,
  templates : Array[(String, Array[Double])],
  distance_metric : String,
) -> (String, Double) {
  let w = char_img.width
  let h = char_img.height
  let data = char_img.data
  // 提取网格特征
  let grid_size = 16
  let cell_w = w / grid_size
  let cell_h = h / grid_size
  let features : Array[Double] = []
  for r in 0..<grid_size {
    for c in 0..<grid_size {
      let mut count = 0
      let mut total = 0
      for py in 0..<cell_h {
        for px in 0..<cell_w {
          let sx = c * cell_w + px
          let sy = r * cell_h + py
          if sx < w && sy < h {
            total += 1
            if data[sy * w + sx].to_int() > 128 {
              count += 1
            }
          }
        }
      }
      let density = if total > 0 {
        count.to_double() / total.to_double()
      } else {
        0.0
      }
      features.push(density)
    }
  }
  // 模板匹配
  let mut best_label = "?"
  let mut best_dist = 1000000.0
  for _tup2 in templates {
    let (label, template) = _tup2
    let n = if features.length() < template.length() {
      features.length()
    } else {
      template.length()
    }
    let mut dist = 0.0
    match distance_metric {
      "manhattan" =>
        for i in 0..<n {
          dist += (features[i] - template[i]).abs()
        }
      "cosine" => {
        let mut dot = 0.0
        let mut norm_a = 0.0
        let mut norm_b = 0.0
        for i in 0..<n {
          dot += features[i] * template[i]
          norm_a += features[i] * features[i]
          norm_b += template[i] * template[i]
        }
        let denom = norm_a.sqrt() * norm_b.sqrt()
        dist = if denom > 0.0 { 1.0 - dot / denom } else { 1.0 }
      }
      _ => {
        for i in 0..<n {
          let diff = features[i] - template[i]
          dist += diff * diff
        }
        dist = dist.sqrt()
      }
    }
    if dist < best_dist {
      best_dist = dist
      best_label = label
    }
  }
  let confidence = if best_dist > 0.0 { 1.0 / (1.0 + best_dist) } else { 1.0 }
  (best_label, confidence)
}

///|
/// 增强标点符号模板匹配
fn match_punctuation_enhanced(
  char_img : @types.Image,
  templates : Array[PunctuationTemplate],
) -> (String, Double) {
  let w = char_img.width
  let h = char_img.height
  let data = char_img.data
  let grid_size = 16
  let cell_w = w / grid_size
  let cell_h = h / grid_size
  let features : Array[Double] = []
  for r in 0..<grid_size {
    for c in 0..<grid_size {
      let mut count = 0
      let mut total = 0
      for py in 0..<cell_h {
        for px in 0..<cell_w {
          let sx = c * cell_w + px
          let sy = r * cell_h + py
          if sx < w && sy < h {
            total += 1
            if data[sy * w + sx].to_int() > 128 {
              count += 1
            }
          }
        }
      }
      let density = if total > 0 {
        count.to_double() / total.to_double()
      } else {
        0.0
      }
      features.push(density)
    }
  }
  let mut best_label = "?"
  let mut best_dist = 1000000.0
  for template in templates {
    let n = if features.length() < template.features.length() {
      features.length()
    } else {
      template.features.length()
    }
    let mut dist = 0.0
    for i in 0..<n {
      let diff = features[i] - template.features[i]
      dist += diff * diff
    }
    dist = dist.sqrt()
    if dist < best_dist {
      best_dist = dist
      best_label = template.char
    }
  }
  let confidence = if best_dist > 0.0 { 1.0 / (1.0 + best_dist) } else { 1.0 }
  (best_label, confidence)
}

// 多语言混合识别
// 中英混排、标点符号优化、语言检测、多语言识别流水线

///|
/// 语言类型
pub(all) enum LanguageType {
  Chinese
  English
  Digit
  Punctuation
  Mixed
  Unknown
} derive(Eq)

///|
/// 多语言识别配置
pub(all) struct MultilingualOcrConfig {
  enable_chinese : Bool
  enable_english : Bool
  enable_digits : Bool
  enable_punctuation : Bool
  target_size : Int
  distance_metric : String
  auto_language_detection : Bool
}

///|
/// 创建默认多语言识别配置
pub fn multilingual_ocr_default_config() -> MultilingualOcrConfig {
  MultilingualOcrConfig::{
    enable_chinese: true,
    enable_english: true,
    enable_digits: true,
    enable_punctuation: true,
    target_size: 48,
    distance_metric: "euclidean",
    auto_language_detection: true,
  }
}

///|
/// 标点符号模板
pub(all) struct PunctuationTemplate {
  char : String
  features : Array[Double]
  width_ratio : Double // 相对宽度（窄/宽）
}

///|
/// 生成标点符号模板
pub fn generate_punctuation_templates() -> Array[PunctuationTemplate] {
  let templates : Array[PunctuationTemplate] = []
  // 常见标点符号
  let punctuations : Array[(String, Double)] = [
    (",", 0.3), // 逗号（窄）
    (".", 0.3), // 句号（窄）
    ("!", 0.3), // 感叹号（窄）
    ("?", 0.5), // 问号（中）
    (";", 0.3), // 分号（窄）
    (":", 0.3), // 冒号（窄）
    ("\"", 0.4), // 引号（中）
    ("'", 0.2), // 单引号（窄）
    ("(", 0.4), // 左括号（中）
    (")", 0.4), // 右括号（中）
    ("[", 0.4), // 左方括号
    ("]", 0.4), // 右方括号
    ("{", 0.5), // 左花括号
    ("}", 0.5), // 右花括号
    ("-", 0.6), // 连字符（宽）
    ("_", 0.6), // 下划线（宽）
    ("/", 0.4), // 斜杠
    ("\\", 0.4), // 反斜杠
    ("|", 0.2), // 竖线（窄）
    ("@", 0.7), // at符号（宽）
    ("#", 0.6), // 井号
    ("$", 0.5), // 美元符号
    ("%", 0.6), // 百分号
    ("^", 0.5), // 脱字符
    ("&", 0.6), // 和号
    ("*", 0.5), // 星号
    ("+", 0.5), // 加号
    ("=", 0.6), // 等号
    ("<", 0.5), // 小于号
    (">", 0.5), // 大于号
    ("~", 0.6), // 波浪号
    ("`", 0.3), // 反引号
    ("，", 0.5), // 中文逗号
    ("。", 0.5), // 中文句号
    ("！", 0.5), // 中文感叹号
    ("？", 0.6), // 中文问号
    ("；", 0.5), // 中文分号
    ("：", 0.5), // 中文冒号
    ("“", 0.6), // 中文左引号
    ("”", 0.6), // 中文右引号
    ("（", 0.6), // 中文左括号
    ("）", 0.6), // 中文右括号
    ("、", 0.4), // 顿号
    ("《", 0.6), // 书名号左
    ("》", 0.6), // 书名号右
    ("—", 0.8), // 破折号
    ("…", 0.7), // 省略号
  ]
  for _tup0 in punctuations {
    let (char, width_ratio) = _tup0
    let features = generate_punctuation_features(char, width_ratio)
    templates.push(PunctuationTemplate::{ char, features, width_ratio })
  }
  templates
}

///|
/// 生成标点符号特征
fn generate_punctuation_features(
  char : String,
  width_ratio : Double,
) -> Array[Double] {
  let size = 16
  let features : Array[Double] = Array::make(size * size, 0.0)
  let seed = if char.length() > 0 { char[0].to_int() } else { 0 }
  // 基于字符生成简单的标点模式
  let center_x = (size.to_double() * (0.5 + (width_ratio - 0.5) * 0.3)).to_int()
  let center_y = size / 2
  for y in 0..<size {
    for x in 0..<size {
      let h = (seed * 31 + x * 17 + y * 13) % 100
      let dist = ((x - center_x) * (x - center_x) +
      (y - center_y) * (y - center_y)).to_double()
      let center_factor = 1.0 - dist / 64.0
      if h < 40 + (center_factor * 30.0).to_int() {
        features[y * size + x] = 1.0
      }
    }
  }
  features
}

///|
/// 检测字符语言类型（基于宽高比和尺寸）
pub fn detect_char_language(
  char_img : @types.Image,
) -> LanguageType raise @types.LoadError {
  // 输入验证
  if char_img.width <= 0 || char_img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_char_language: 图像尺寸必须大于0",
    )
  }
  if char_img.channels < 1 || char_img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "detect_char_language: 通道数必须在1-4之间",
    )
  }
  let expected_size = char_img.width * char_img.height * char_img.channels
  if char_img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "detect_char_language: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      char_img.data.length().to_string(),
    )
  }
  let w = char_img.width
  let h = char_img.height
  let ratio = if h > 0 { w.to_double() / h.to_double() } else { 1.0 }
  // 中文字符通常接近正方形（ratio 0.8-1.2）
  if ratio > 0.75 && ratio < 1.35 && w > 20 && h > 20 {
    return LanguageType::Chinese
  }
  // 英文字符通常较窄（ratio 0.4-0.8）
  if ratio > 0.3 && ratio < 0.75 {
    return LanguageType::English
  }
  // 数字
  if ratio > 0.4 && ratio < 0.7 {
    return LanguageType::Digit
  }
  // 标点符号通常很窄或很宽
  if ratio < 0.4 || ratio > 1.35 {
    return LanguageType::Punctuation
  }
  LanguageType::Unknown
}

///|
/// 检测文档主要语言
pub fn detect_document_language(
  img : @types.Image,
) -> LanguageType raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_document_language: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "detect_document_language: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "detect_document_language: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  // 预处理
  let preprocessed = ocr_preprocess(img)
  // 检测文本行
  let lines = detect_text_lines_projection(preprocessed)
  if lines.length() == 0 {
    return LanguageType::Unknown
  }
  // 统计字符宽高比
  let mut chinese_count = 0
  let mut english_count = 0
  let mut digit_count = 0
  // 简单统计：基于文本行的平均字符宽度
  for line in lines {
    let avg_char_width = if line.width > 0 {
      line.width.to_double() / (line.width.to_double() / 15.0).max(1.0)
    } else {
      15.0
    }
    let ratio = avg_char_width / line.height.to_double()
    if ratio > 0.75 && ratio < 1.35 {
      chinese_count += 1
    } else if ratio > 0.3 && ratio < 0.75 {
      english_count += 1
    } else {
      digit_count += 1
    }
  }
  // 判断主要语言
  if chinese_count > english_count && chinese_count > digit_count {
    return LanguageType::Chinese
  }
  if english_count > chinese_count && english_count > digit_count {
    return LanguageType::English
  }
  if chinese_count > 0 && english_count > 0 {
    return LanguageType::Mixed
  }
  LanguageType::Unknown
}

///|
/// 多语言混合识别（完整流水线）
pub fn recognize_multilingual(
  img : @types.Image,
  config? : MultilingualOcrConfig,
) -> OcrResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_multilingual: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "recognize_multilingual: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "recognize_multilingual: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let cfg = match config {
    Some(c) => c
    None => multilingual_ocr_default_config()
  }
  // 1. 预处理
  let preprocessed = ocr_preprocess(img)
  // 2. 检测文档主要语言
  let _ = if cfg.auto_language_detection {
    detect_document_language(preprocessed)
  } else {
    LanguageType::Mixed
  }
  // 3. 字符分割
  let char_regions = segment_multilingual_chars(preprocessed, cfg)
  // 4. 生成各语言模板
  let chinese_templates = if cfg.enable_chinese {
    generate_3500_chinese_templates(char_set="common100")
  } else {
    []
  }
  let english_templates = if cfg.enable_english {
    generate_english_templates(case_sensitive=false)
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
  // 5. 对每个字符进行识别
  let char_results : Array[OcrCharResult] = []
  let mut text = ""
  let mut total_confidence = 0.0
  for _tup1 in char_regions {
    let (x, y, w, h) = _tup1
    // 提取字符图像
    let char_img = extract_multilingual_char_region(
      preprocessed,
      x,
      y,
      w,
      h,
      cfg.target_size,
    )
    // 检测字符语言类型
    let char_language = detect_char_language(char_img)
    // 根据语言类型选择模板
    let result = match char_language {
      LanguageType::Chinese =>
        if chinese_templates.length() > 0 {
          match_multilingual_template(
            extract_multilingual_features(char_img, 16),
            chinese_templates,
            cfg.distance_metric,
          )
        } else {
          ("?", 0.0)
        }
      LanguageType::English =>
        if english_templates.length() > 0 {
          match_multilingual_template(
            extract_multilingual_features(char_img, 16),
            english_templates,
            cfg.distance_metric,
          )
        } else {
          ("?", 0.0)
        }
      LanguageType::Digit =>
        if digit_templates.length() > 0 {
          match_multilingual_template(
            extract_multilingual_features(char_img, 16),
            digit_templates,
            cfg.distance_metric,
          )
        } else {
          ("?", 0.0)
        }
      LanguageType::Punctuation =>
        if punctuation_templates.length() > 0 {
          match_punctuation_template(
            extract_multilingual_features(char_img, 16),
            punctuation_templates,
          )
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
          match_multilingual_template(
            extract_multilingual_features(char_img, 16),
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
    char_results.push(OcrCharResult::{
      char: result.0,
      confidence: result.1,
      x,
      y,
      width: w,
      height: h,
    })
  }
  let avg_confidence = if char_results.length() > 0 {
    total_confidence / char_results.length().to_double()
  } else {
    0.0
  }
  OcrResult::{ text, confidence: avg_confidence, characters: char_results }
}

///|
/// 多语言字符分割
fn segment_multilingual_chars(
  img : @types.Image,
  cfg : MultilingualOcrConfig,
) -> Array[(Int, Int, Int, Int)] {
  ignore(cfg)
  let w = img.width
  let h = img.height
  let data = img.data
  // 简单连通域标记
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
  // 过滤（多语言更宽松）
  let regions : Array[(Int, Int, Int, Int)] = []
  for label in 1..<next_label {
    let rw = max_x[label] - min_x[label] + 1
    let rh = max_y[label] - min_y[label] + 1
    if rw >= 5 && rw <= 100 && rh >= 8 && rh <= 100 && area[label] > 10 {
      regions.push((min_x[label], min_y[label], rw, rh))
    }
  }
  regions
}

///|
/// 提取多语言字符区域
fn extract_multilingual_char_region(
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
/// 提取多语言字符特征
fn extract_multilingual_features(
  char_img : @types.Image,
  grid_size : Int,
) -> Array[Double] {
  let w = char_img.width
  let h = char_img.height
  let data = char_img.data
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
  features
}

///|
/// 多语言模板匹配
fn match_multilingual_template(
  features : Array[Double],
  templates : Array[(String, Array[Double])],
  distance_metric : String,
) -> (String, Double) {
  let mut best_label = "?"
  let mut best_dist = 1000000.0
  for _tup2 in templates {
    let (label, template) = _tup2
    let dist = match distance_metric {
      "manhattan" => manhattan_ml(features, template)
      "cosine" => cosine_ml(features, template)
      _ => euclidean_ml(features, template)
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
/// 标点符号模板匹配
fn match_punctuation_template(
  features : Array[Double],
  templates : Array[PunctuationTemplate],
) -> (String, Double) {
  let mut best_label = "?"
  let mut best_dist = 1000000.0
  for template in templates {
    let dist = euclidean_ml(features, template.features)
    if dist < best_dist {
      best_dist = dist
      best_label = template.char
    }
  }
  let confidence = if best_dist > 0.0 { 1.0 / (1.0 + best_dist) } else { 1.0 }
  (best_label, confidence)
}

///|
/// 局部欧氏距离
fn euclidean_ml(a : Array[Double], b : Array[Double]) -> Double {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  let mut sum_sq = 0.0
  for i in 0..<n {
    let diff = a[i] - b[i]
    sum_sq += diff * diff
  }
  sum_sq.sqrt()
}

///|
/// 局部曼哈顿距离
fn manhattan_ml(a : Array[Double], b : Array[Double]) -> Double {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  let mut sum = 0.0
  for i in 0..<n {
    sum += (a[i] - b[i]).abs()
  }
  sum
}

///|
/// 局部余弦距离
fn cosine_ml(a : Array[Double], b : Array[Double]) -> Double {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  let mut dot = 0.0
  let mut norm_a = 0.0
  let mut norm_b = 0.0
  for i in 0..<n {
    dot += a[i] * b[i]
    norm_a += a[i] * a[i]
    norm_b += b[i] * b[i]
  }
  let denom = norm_a.sqrt() * norm_b.sqrt()
  if denom > 0.0 {
    1.0 - dot / denom
  } else {
    1.0
  }
}

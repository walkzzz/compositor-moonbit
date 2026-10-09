// 手写体识别
// 手写体专用模板、灵活的字符分割、手写体识别流水线

///|
/// 手写体识别配置
pub(all) struct HandwritingOcrConfig {
  min_char_width : Int
  max_char_width : Int
  min_char_height : Int
  max_char_height : Int
  target_size : Int
  distance_metric : String
  flexibility : Double // 0.0-1.0，越高越灵活
  use_slant_correction : Bool
}

///|
/// 创建默认手写体识别配置
pub fn handwriting_ocr_default_config() -> HandwritingOcrConfig {
  HandwritingOcrConfig::{
    min_char_width: 8,
    max_char_width: 80,
    min_char_height: 10,
    max_char_height: 100,
    target_size: 48,
    distance_metric: "euclidean",
    flexibility: 0.7,
    use_slant_correction: true,
  }
}

///|
/// 生成手写体数字模板（更灵活的形状）
pub fn generate_handwriting_templates(
  char_set? : String = "digits",
) -> Array[(String, Array[Double])] {
  let templates : Array[(String, Array[Double])] = []
  let chars = if char_set == "digits+letters" {
    [
      "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E",
      "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
      "U", "V", "W", "X", "Y", "Z",
    ]
  } else {
    ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
  }
  for char in chars {
    // 生成多个变体（手写体有多种写法）
    for variant in 0..<3 {
      let template = generate_handwriting_char_template(char, variant)
      let label = char + "_v" + variant.to_string()
      templates.push((label, template))
    }
  }
  templates
}

///|
/// 生成手写体字符模板（带变体）
fn generate_handwriting_char_template(
  char : String,
  variant : Int,
) -> Array[Double] {
  let size = 16
  let features : Array[Double] = Array::make(size * size, 0.0)
  let seed = if char.length() > 0 {
    char[0].to_int() + variant * 100
  } else {
    0
  }
  // 手写体特征：更随机、更灵活的形状
  for y in 0..<size {
    for x in 0..<size {
      // 基础哈希
      let h1 = (seed * 31 + x * 17 + y * 13) % 100
      // 变体哈希
      let h2 = (seed * 7 + (x + variant * 3) * 11 + (y + variant * 2) * 19) %
        100
      // 中心权重（手写体通常居中但有偏移）
      let center_x = 8 + (variant - 1) * 2
      let center_y = 8 + variant % 2 * 2
      let center_dist = ((x - center_x) * (x - center_x) +
      (y - center_y) * (y - center_y)).to_double()
      let center_factor = 1.0 - center_dist / 128.0
      // 手写体灵活性：更宽松的阈值
      let threshold = 35 + (center_factor * 30.0).to_int() + h2 / 5
      if h1 < threshold {
        features[y * size + x] = 1.0
      }
    }
  }
  features
}

///|
/// 倾斜校正（手写体专用）
pub fn correct_slant(
  img : @types.Image,
  max_slant? : Double = 15.0,
) -> @types.Image raise @types.LoadError {
  ignore(max_slant)
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "correct_slant: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "correct_slant: 仅支持单通道灰度图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "correct_slant: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  // 简化版：检测主要倾斜角度并校正
  let angle = estimate_slant_angle(img)
  if angle.abs() > 1.0 {
    rotate_document(img, -angle)
  } else {
    img
  }
}

///|
/// 估计倾斜角度（手写体专用）
fn estimate_slant_angle(img : @types.Image) -> Double {
  let w = img.width
  let h = img.height
  let data = img.data
  // 简化：基于垂直投影的倾斜估计
  let mut best_angle = 0.0
  let mut best_score = 0.0
  let mut angle = -15.0
  while angle <= 15.0 {
    let angle_rad = angle * 3.141592653589793 / 180.0
    let cos_a = @math.cos(angle_rad)
    let sin_a = @math.sin(angle_rad)
    // 计算旋转后的垂直投影方差
    let projection : Array[Int] = Array::make(w, 0)
    for y in 0..<h {
      for x in 0..<w {
        if data[y * w + x].to_int() > 128 {
          let new_x = ((x.to_double() - w.to_double() / 2.0) * cos_a -
          (y.to_double() - h.to_double() / 2.0) * sin_a +
          w.to_double() / 2.0).to_int()
          if new_x >= 0 && new_x < w {
            projection[new_x] += 1
          }
        }
      }
    }
    // 计算方差
    let mut sum = 0
    let mut sum_sq = 0
    for i in 0..<w {
      sum += projection[i]
      sum_sq += projection[i] * projection[i]
    }
    let mean = sum.to_double() / w.to_double()
    let variance = sum_sq.to_double() / w.to_double() - mean * mean
    if variance > best_score {
      best_score = variance
      best_angle = angle
    }
    angle += 1.0
  }
  best_angle
}

///|
/// 手写体字符分割（更宽松的参数）
fn segment_handwriting_chars(
  img : @types.Image,
  cfg : HandwritingOcrConfig,
) -> Array[(Int, Int, Int, Int)] {
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
  // 过滤（手写体更宽松）
  let regions : Array[(Int, Int, Int, Int)] = []
  for label in 1..<next_label {
    let rw = max_x[label] - min_x[label] + 1
    let rh = max_y[label] - min_y[label] + 1
    // 手写体过滤：更宽松的宽高比
    let ratio = if rh > 0 { rw.to_double() / rh.to_double() } else { 0.0 }
    let min_ratio = 0.3 * (1.0 + cfg.flexibility)
    let max_ratio = 3.0 * (1.0 + cfg.flexibility)
    if rw >= cfg.min_char_width &&
      rw <= cfg.max_char_width &&
      rh >= cfg.min_char_height &&
      rh <= cfg.max_char_height &&
      ratio > min_ratio &&
      ratio < max_ratio &&
      area[label] > 15 {
      regions.push((min_x[label], min_y[label], rw, rh))
    }
  }
  regions
}

///|
/// 手写体识别（完整流水线）
pub fn recognize_handwriting(
  img : @types.Image,
  config? : HandwritingOcrConfig,
) -> OcrResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_handwriting: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "recognize_handwriting: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "recognize_handwriting: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let cfg = match config {
    Some(c) => c
    None => handwriting_ocr_default_config()
  }
  // 配置验证
  if cfg.min_char_width <= 0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_handwriting: min_char_width必须大于0",
    )
  }
  if cfg.max_char_width < cfg.min_char_width {
    raise @types.LoadError::DecodeFailed(
      "recognize_handwriting: max_char_width不能小于min_char_width",
    )
  }
  if cfg.target_size <= 0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_handwriting: target_size必须大于0",
    )
  }
  // 1. 预处理
  let mut preprocessed = ocr_preprocess(img)
  // 2. 倾斜校正（手写体专用）
  if cfg.use_slant_correction {
    preprocessed = correct_slant(preprocessed)
  }
  // 3. 字符分割（手写体更宽松）
  let char_regions = segment_handwriting_chars(preprocessed, cfg)
  // 4. 生成手写体模板
  let templates = generate_handwriting_templates(char_set="digits")
  // 5. 对每个字符进行识别
  let char_results : Array[OcrCharResult] = []
  let mut text = ""
  let mut total_confidence = 0.0
  for _tup0 in char_regions {
    let (x, y, w, h) = _tup0
    // 提取字符图像
    let char_img = extract_handwriting_char_region(
      preprocessed,
      x,
      y,
      w,
      h,
      cfg.target_size,
    )
    // 提取特征
    let features = extract_handwriting_char_features(char_img, 16)
    // 模板匹配（多变体投票）
    let result = match_handwriting_template(
      features,
      templates,
      cfg.distance_metric,
    )
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
/// 提取手写体字符区域
fn extract_handwriting_char_region(
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
/// 提取手写体字符特征
fn extract_handwriting_char_features(
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
/// 手写体模板匹配（多变体投票）
fn match_handwriting_template(
  features : Array[Double],
  templates : Array[(String, Array[Double])],
  distance_metric : String,
) -> (String, Double) {
  // 收集所有变体的预测
  let label_votes : Array[(String, Double)] = []
  for _tup1 in templates {
    let (label_full, template) = _tup1
    let dist = match distance_metric {
      "manhattan" => manhattan_hw(features, template)
      "cosine" => cosine_hw(features, template)
      _ => euclidean_hw(features, template)
    }
    // 提取基础标签（去掉变体后缀）
    // 提取基础标签（去掉变体后缀 _v0, _v1, _v2）
    // 简化：取第一个字符作为基础标签（数字0-9）
    let base_label = if label_full.length() > 0 {
      label_full[0].to_string()
    } else {
      label_full
    }
    let confidence = if dist > 0.0 { 1.0 / (1.0 + dist) } else { 1.0 }
    // 投票
    let mut found = false
    for i in 0..<label_votes.length() {
      if label_votes[i].0 == base_label {
        label_votes[i] = (base_label, label_votes[i].1 + confidence)
        found = true
      }
    }
    if !found {
      label_votes.push((base_label, confidence))
    }
  }
  // 找得票最多的标签
  let mut best_label = "?"
  let mut best_votes = 0.0
  for _tup2 in label_votes {
    let (label, votes) = _tup2
    if votes > best_votes {
      best_votes = votes
      best_label = label
    }
  }
  let total_votes = if templates.length() > 0 {
    templates.length().to_double() / 3.0
  } else {
    1.0
  }
  let confidence = best_votes / total_votes
  (best_label, confidence)
}

///|
/// 局部欧氏距离
fn euclidean_hw(a : Array[Double], b : Array[Double]) -> Double {
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
fn manhattan_hw(a : Array[Double], b : Array[Double]) -> Double {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  let mut sum = 0.0
  for i in 0..<n {
    sum += (a[i] - b[i]).abs()
  }
  sum
}

///|
/// 局部余弦距离
fn cosine_hw(a : Array[Double], b : Array[Double]) -> Double {
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

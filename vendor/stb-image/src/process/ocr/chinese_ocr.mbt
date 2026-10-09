// 中文 OCR 基础
// 常用汉字识别（基于点阵模板）

///|
/// 中文 OCR 配置
pub(all) struct ChineseOcrConfig {
  min_char_width : Int
  max_char_width : Int
  target_size : Int
  distance_metric : String
  char_set : String // "common" / "full"
}

///|
/// 创建默认中文 OCR 配置
pub fn chinese_ocr_default_config() -> ChineseOcrConfig {
  ChineseOcrConfig::{
    min_char_width: 10,
    max_char_width: 100,
    target_size: 48,
    distance_metric: "euclidean",
    char_set: "common",
  }
}

///|
/// 生成常用汉字模板（100个常用汉字）
pub fn generate_chinese_templates(
  char_set? : String = "common",
) -> Array[(String, Array[Double])] {
  let templates : Array[(String, Array[Double])] = []
  // 常用汉字列表（100个最常用汉字）
  let common_chars : Array[String] = [
    "的", "一", "是", "在", "不", "了", "有", "和", "人", "这", "中",
    "大", "为", "上", "个", "国", "我", "以", "要", "他", "时", "来",
    "用", "们", "生", "到", "作", "地", "于", "出", "就", "分", "对",
    "成", "会", "可", "主", "发", "年", "动", "同", "工", "也", "能",
    "下", "过", "子", "说", "产", "种", "面", "而", "方", "后", "多",
    "定", "行", "学", "法", "所", "民", "得", "经", "十", "三", "之",
    "进", "着", "等", "部", "度", "家", "电", "力", "里", "如", "水",
    "化", "高", "自", "二", "理", "起", "小", "物", "现", "实", "加",
    "量", "都", "两", "体", "重", "机", "当", "使", "点", "从", "业",
    "本",
  ]
  let chars = if char_set == "full" {
    // 完整字符集（这里简化，仍然用常用汉字）
    common_chars
  } else {
    common_chars
  }
  for char in chars {
    let template = generate_chinese_char_template(char)
    templates.push((char, template))
  }
  templates
}

///|
/// 生成单个汉字模板（基于16x16点阵简化模式）
fn generate_chinese_char_template(char : String) -> Array[Double] {
  let size = 16
  let features : Array[Double] = Array::make(size * size, 0.0)
  // 简化的汉字模式（基于常见汉字结构）
  // 这里使用字符的Unicode码点作为种子，生成伪随机但稳定的模式
  let seed = if char.length() > 0 { char[0].to_int() } else { 0 }
  // 基于种子生成模式（简化版，实际应该使用真实点阵字体）
  for y in 0..<size {
    for x in 0..<size {
      // 使用简单的哈希函数生成模式
      let hash = (seed * 31 + x * 17 + y * 13) % 100
      // 中心区域更可能有像素
      let center_dist = ((x - 8) * (x - 8) + (y - 8) * (y - 8)).to_double()
      let center_factor = 1.0 - center_dist / 128.0
      let threshold = 30 + (center_factor * 40.0).to_int()
      if hash < threshold {
        features[y * size + x] = 1.0
      }
    }
  }
  features
}

///|
/// 中文 OCR 识别（完整流水线）
pub fn recognize_chinese(
  img : @types.Image,
  config? : ChineseOcrConfig,
) -> OcrResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_chinese: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "recognize_chinese: 仅支持单通道灰度图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "recognize_chinese: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let cfg = match config {
    Some(c) => c
    None => chinese_ocr_default_config()
  }
  // 配置验证
  if cfg.min_char_width <= 0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_chinese: min_char_width必须大于0",
    )
  }
  if cfg.max_char_width < cfg.min_char_width {
    raise @types.LoadError::DecodeFailed(
      "recognize_chinese: max_char_width不能小于min_char_width",
    )
  }
  if cfg.target_size <= 0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_chinese: target_size必须大于0",
    )
  }
  // 1. 预处理
  let preprocessed = ocr_preprocess(img)
  // 2. 字符分割（中文字符通常是方块形，使用连通域分割）
  let char_regions = segment_chinese_chars(preprocessed, cfg)
  // 3. 生成模板
  let templates = generate_chinese_templates(char_set=cfg.char_set)
  // 4. 对每个字符进行识别
  let char_results : Array[OcrCharResult] = []
  let mut text = ""
  let mut total_confidence = 0.0
  for _tup0 in char_regions {
    let (x, y, w, h) = _tup0
    // 提取字符图像
    let char_img = extract_chinese_char_region(
      preprocessed,
      x,
      y,
      w,
      h,
      cfg.target_size,
    )
    // 提取特征
    let features = extract_chinese_char_features(char_img, 16)
    // 模板匹配
    let result = match_chinese_template(
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
/// 中文字符分割（基于连通域和方块特征）
fn segment_chinese_chars(
  img : @types.Image,
  cfg : ChineseOcrConfig,
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
  // 计算每个连通域的边界框
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
  // 过滤并返回（中文字符通常接近正方形）
  let regions : Array[(Int, Int, Int, Int)] = []
  for label in 1..<next_label {
    let rw = max_x[label] - min_x[label] + 1
    let rh = max_y[label] - min_y[label] + 1
    // 中文字符过滤：接近正方形，尺寸在合理范围内
    let ratio = if rh > 0 { rw.to_double() / rh.to_double() } else { 0.0 }
    if rw >= cfg.min_char_width &&
      rw <= cfg.max_char_width &&
      rh >= cfg.min_char_width &&
      rh <= cfg.max_char_width &&
      ratio > 0.5 &&
      ratio < 2.0 &&
      area[label] > 20 {
      regions.push((min_x[label], min_y[label], rw, rh))
    }
  }
  regions
}

///|
/// 提取中文字符区域
fn extract_chinese_char_region(
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
  // 缩放到目标尺寸（中文字符保持正方形）
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
/// 提取中文字符特征（16x16网格特征）
fn extract_chinese_char_features(
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
/// 中文模板匹配
fn match_chinese_template(
  features : Array[Double],
  templates : Array[(String, Array[Double])],
  distance_metric : String,
) -> (String, Double) {
  let mut best_label = "?"
  let mut best_dist = 1000000.0
  for _tup1 in templates {
    let (label, template) = _tup1
    let dist = match distance_metric {
      "manhattan" => manhattan_distance_chi(features, template)
      "cosine" => cosine_distance_chi(features, template)
      _ => euclidean_distance_chi(features, template)
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
/// 局部欧氏距离
fn euclidean_distance_chi(a : Array[Double], b : Array[Double]) -> Double {
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
fn manhattan_distance_chi(a : Array[Double], b : Array[Double]) -> Double {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  let mut sum = 0.0
  for i in 0..<n {
    sum += (a[i] - b[i]).abs()
  }
  sum
}

///|
/// 局部余弦距离
fn cosine_distance_chi(a : Array[Double], b : Array[Double]) -> Double {
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

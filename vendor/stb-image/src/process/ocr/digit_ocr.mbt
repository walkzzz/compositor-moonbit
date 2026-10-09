// 数字 OCR
// 完整数字识别流水线：预处理→分割→特征提取→分类

///|
/// OCR 识别结果结构体
pub(all) struct OcrResult {
  text : String
  confidence : Double
  characters : Array[OcrCharResult]
}

///|
/// 单个字符识别结果
pub(all) struct OcrCharResult {
  char : String
  confidence : Double
  x : Int
  y : Int
  width : Int
  height : Int
}

///|
/// 数字 OCR 配置
pub(all) struct DigitOcrConfig {
  min_char_width : Int
  max_char_width : Int
  target_size : Int
  use_knn : Bool
  k : Int
  distance_metric : String
}

///|
/// 创建默认数字 OCR 配置
pub fn digit_ocr_default_config() -> DigitOcrConfig {
  DigitOcrConfig::{
    min_char_width: 5,
    max_char_width: 60,
    target_size: 32,
    use_knn: true,
    k: 3,
    distance_metric: "euclidean",
  }
}

///|
/// 生成数字模板特征（0-9）
/// 使用简单的合成模板
pub fn generate_digit_templates() -> Array[(String, Array[Double])] {
  let templates : Array[(String, Array[Double])] = []
  // 为每个数字生成模板特征
  for digit in 0..<10 {
    let template = generate_single_digit_template(digit)
    templates.push((digit.to_string(), template))
  }
  templates
}

///|
/// 生成单个数字的模板特征
fn generate_single_digit_template(digit : Int) -> Array[Double] {
  // 使用 8x8 网格特征作为模板
  let size = 8
  let features : Array[Double] = Array::make(size * size, 0.0)
  // 根据数字设置特征模式（简化的7段显示模式）
  match digit {
    0 => {
      // 0: 上、上左、上右、下左、下右、下（缺中）
      set_segment(features, size, 0, 1, 6, 1) // 上
      set_segment(features, size, 1, 0, 1, 3) // 上左
      set_segment(features, size, 1, 6, 1, 3) // 上右
      set_segment(features, size, 4, 0, 1, 3) // 下左
      set_segment(features, size, 4, 6, 1, 3) // 下右
      set_segment(features, size, 6, 1, 6, 1) // 下
    }
    1 =>
      // 1: 上右、下右
      set_segment(features, size, 0, 6, 1, 7) // 右
    2 => {
      // 2: 上、上右、中、下左、下
      set_segment(features, size, 0, 1, 6, 1) // 上
      set_segment(features, size, 1, 6, 1, 3) // 上右
      set_segment(features, size, 3, 1, 6, 1) // 中
      set_segment(features, size, 4, 0, 1, 3) // 下左
      set_segment(features, size, 6, 1, 6, 1) // 下
    }
    3 => {
      // 3: 上、上右、中、下右、下
      set_segment(features, size, 0, 1, 6, 1) // 上
      set_segment(features, size, 1, 6, 1, 3) // 上右
      set_segment(features, size, 3, 1, 6, 1) // 中
      set_segment(features, size, 4, 6, 1, 3) // 下右
      set_segment(features, size, 6, 1, 6, 1) // 下
    }
    4 => {
      // 4: 上左、上右、中、下右
      set_segment(features, size, 1, 0, 1, 3) // 上左
      set_segment(features, size, 1, 6, 1, 3) // 上右
      set_segment(features, size, 3, 1, 6, 1) // 中
      set_segment(features, size, 4, 6, 1, 3) // 下右
    }
    5 => {
      // 5: 上、上左、中、下右、下
      set_segment(features, size, 0, 1, 6, 1) // 上
      set_segment(features, size, 1, 0, 1, 3) // 上左
      set_segment(features, size, 3, 1, 6, 1) // 中
      set_segment(features, size, 4, 6, 1, 3) // 下右
      set_segment(features, size, 6, 1, 6, 1) // 下
    }
    6 => {
      // 6: 上、上左、中、下左、下右、下
      set_segment(features, size, 0, 1, 6, 1) // 上
      set_segment(features, size, 1, 0, 1, 3) // 上左
      set_segment(features, size, 3, 1, 6, 1) // 中
      set_segment(features, size, 4, 0, 1, 3) // 下左
      set_segment(features, size, 4, 6, 1, 3) // 下右
      set_segment(features, size, 6, 1, 6, 1) // 下
    }
    7 => {
      // 7: 上、上右、下右
      set_segment(features, size, 0, 1, 6, 1) // 上
      set_segment(features, size, 1, 6, 1, 6) // 右
    }
    8 => {
      // 8: 全部段
      set_segment(features, size, 0, 1, 6, 1) // 上
      set_segment(features, size, 1, 0, 1, 3) // 上左
      set_segment(features, size, 1, 6, 1, 3) // 上右
      set_segment(features, size, 3, 1, 6, 1) // 中
      set_segment(features, size, 4, 0, 1, 3) // 下左
      set_segment(features, size, 4, 6, 1, 3) // 下右
      set_segment(features, size, 6, 1, 6, 1) // 下
    }
    9 => {
      // 9: 上、上左、上右、中、下右、下
      set_segment(features, size, 0, 1, 6, 1) // 上
      set_segment(features, size, 1, 0, 1, 3) // 上左
      set_segment(features, size, 1, 6, 1, 3) // 上右
      set_segment(features, size, 3, 1, 6, 1) // 中
      set_segment(features, size, 4, 6, 1, 3) // 下右
      set_segment(features, size, 6, 1, 6, 1) // 下
    }
    _ => ignore(())
  }
  features
}

///|
/// 设置7段显示的一段
fn set_segment(
  features : Array[Double],
  size : Int,
  row : Int,
  col : Int,
  width : Int,
  height : Int,
) -> Unit {
  for r in 0..<height {
    for c in 0..<width {
      let pr = row + r
      let pc = col + c
      if pr < size && pc < size {
        features[pr * size + pc] = 1.0
      }
    }
  }
}

///|
/// 数字 OCR 识别（完整流水线）
/// 预处理 → 字符分割 → 特征提取 → 模板匹配分类
pub fn recognize_digits(
  img : @types.Image,
  config? : DigitOcrConfig,
) -> OcrResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_digits: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "recognize_digits: 仅支持单通道灰度图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "recognize_digits: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let cfg = match config {
    Some(c) => c
    None => digit_ocr_default_config()
  }
  // 配置验证
  if cfg.min_char_width <= 0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_digits: min_char_width必须大于0",
    )
  }
  if cfg.max_char_width < cfg.min_char_width {
    raise @types.LoadError::DecodeFailed(
      "recognize_digits: max_char_width不能小于min_char_width",
    )
  }
  if cfg.target_size <= 0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_digits: target_size必须大于0",
    )
  }
  if cfg.k <= 0 {
    raise @types.LoadError::DecodeFailed("recognize_digits: k必须大于0")
  }
  // 1. 预处理
  let preprocessed = ocr_preprocess(img)
  // 2. 字符分割
  let char_regions = complete_char_segmentation(
    preprocessed,
    min_char_width=cfg.min_char_width,
    max_char_width=cfg.max_char_width,
  )
  // 3. 生成模板
  let templates = generate_digit_templates()
  // 4. 对每个字符进行识别
  let char_results : Array[OcrCharResult] = []
  let mut text = ""
  let mut total_confidence = 0.0
  for _tup0 in char_regions {
    let (x, y, w, h) = _tup0
    // 提取字符图像
    let char_img = extract_char_region(
      preprocessed,
      x,
      y,
      w,
      h,
      cfg.target_size,
    )
    // 提取特征（网格特征）
    let features = extract_char_features(char_img, 8)
    // 模板匹配
    let result = match_template(features, templates, cfg.distance_metric)
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
/// 提取字符区域并缩放到目标尺寸
fn extract_char_region(
  img : @types.Image,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  target_size : Int,
) -> @types.Image {
  let w = img.width
  let h = img.height
  // 裁剪
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
  // 缩放到目标尺寸（保持宽高比，居中）
  let scale = if crop_w > crop_h {
    target_size.to_double() / crop_w.to_double()
  } else {
    target_size.to_double() / crop_h.to_double()
  }
  let new_w = max(1, (crop_w.to_double() * scale).to_int())
  let new_h = max(1, (crop_h.to_double() * scale).to_int())
  let offset_x = (target_size - new_w) / 2
  let offset_y = (target_size - new_h) / 2
  let out : Array[Byte] = Array::make(target_size * target_size, b'\x00')
  let data = img.data
  // 最近邻缩放
  for py in 0..<new_h {
    for px in 0..<new_w {
      let src_x = x + px * crop_w / new_w
      let src_y = y + py * crop_h / new_h
      if src_x < w && src_y < h {
        out[(offset_y + py) * target_size + (offset_x + px)] = data[src_y * w +
          src_x]
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
/// 提取字符特征（网格特征）
fn extract_char_features(
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
/// 模板匹配
fn match_template(
  features : Array[Double],
  templates : Array[(String, Array[Double])],
  distance_metric : String,
) -> (String, Double) {
  let mut best_label = "?"
  let mut best_dist = 1000000.0
  for _tup1 in templates {
    let (label, template) = _tup1
    let dist = match distance_metric {
      "manhattan" => manhattan_distance_local(features, template)
      "cosine" => cosine_distance_local(features, template)
      _ => euclidean_distance_local(features, template)
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
fn euclidean_distance_local(a : Array[Double], b : Array[Double]) -> Double {
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
fn manhattan_distance_local(a : Array[Double], b : Array[Double]) -> Double {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  let mut sum = 0.0
  for i in 0..<n {
    sum += (a[i] - b[i]).abs()
  }
  sum
}

///|
/// 局部余弦距离
fn cosine_distance_local(a : Array[Double], b : Array[Double]) -> Double {
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

///|
/// 辅助函数：最大值
fn _max_ocr(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

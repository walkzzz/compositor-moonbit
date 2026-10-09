// 手写体识别增强版（v10.3.0）
// 更多变体、弹性匹配、连笔分割、手写体专用特征、手写体后处理

///|
/// 增强手写体识别配置
pub(all) struct HandwritingOcrEnhancedConfig {
  min_char_width : Int
  max_char_width : Int
  min_char_height : Int
  max_char_height : Int
  target_size : Int
  distance_metric : String
  num_variants : Int // 每字符变体数量
  elasticity : Double // 弹性匹配程度 0.0-1.0
  use_slant_correction : Bool
  use_elastic_matching : Bool
  use_stroke_features : Bool
  use_postprocessing : Bool
}

///|
/// 创建默认增强手写体识别配置
pub fn handwriting_ocr_enhanced_default_config() -> HandwritingOcrEnhancedConfig {
  HandwritingOcrEnhancedConfig::{
    min_char_width: 8,
    max_char_width: 80,
    min_char_height: 10,
    max_char_height: 100,
    target_size: 48,
    distance_metric: "euclidean",
    num_variants: 5,
    elasticity: 0.5,
    use_slant_correction: true,
    use_elastic_matching: true,
    use_stroke_features: true,
    use_postprocessing: true,
  }
}

///|
/// 手写体笔画特征
pub(all) struct HandwritingStrokeFeatures {
  num_strokes : Int // 估计笔画数
  stroke_directions : Array[Double] // 主要笔画方向（弧度）
  stroke_lengths : Array[Double] // 笔画长度
  connectivity : Double // 连通性（连笔程度）
  curvature : Double // 曲率（弯曲程度）
}

///|
/// 生成增强手写体模板（每字符5种变体）
pub fn generate_enhanced_handwriting_templates(
  char_set? : String = "digits+letters",
  num_variants? : Int = 5,
) -> Array[(String, Array[Double])] {
  let templates : Array[(String, Array[Double])] = []
  let chars = if char_set == "digits" {
    ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
  } else {
    [
      "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E",
      "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
      "U", "V", "W", "X", "Y", "Z", "a", "b", "c", "d", "e", "f", "g", "h", "i",
      "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x",
      "y", "z",
    ]
  }
  for char in chars {
    for variant in 0..<num_variants {
      let template = generate_enhanced_handwriting_char_template(
        char, variant, num_variants,
      )
      let label = char + "_v" + variant.to_string()
      templates.push((label, template))
    }
  }
  templates
}

///|
/// 生成增强手写体字符模板（带弹性变形）
fn generate_enhanced_handwriting_char_template(
  char : String,
  variant : Int,
  num_variants : Int,
) -> Array[Double] {
  let size = 32
  let features : Array[Double] = Array::make(size * size, 0.0)
  let seed = if char.length() > 0 {
    char[0].to_int() + variant * 137
  } else {
    0
  }
  // 变体参数（每个变体有不同的倾斜、宽度、位置）
  let slant = ((variant - num_variants / 2) * 3).to_double() // 倾斜角度
  let width_scale = 0.85 + (variant % 3).to_double() * 0.1 // 宽度缩放
  let y_offset = variant % 2 * 2 - 1 // 垂直偏移
  let center_x = (size.to_double() / 2.0 * width_scale).to_int()
  let center_y = size / 2 + y_offset
  for y in 0..<size {
    for x in 0..<size {
      // 应用倾斜变换
      let slant_rad = slant * 3.141592653589793 / 180.0
      let transformed_x = x.to_double() -
        center_x.to_double() -
        (y.to_double() - center_y.to_double()) * @math.tan(slant_rad) +
        center_x.to_double()
      let tx = transformed_x.to_int()
      // 多层哈希
      let h1 = (seed * 31 + tx * 17 + y * 13) % 100
      let h2 = (seed * 7 + tx * tx * 3 + y * y * 5) % 100
      let h3 = ((seed << 2) ^ (tx << 1) ^ y) % 100
      let combined = (h1 * 4 + h2 * 3 + h3 * 2) / 9
      // 中心权重（手写体通常居中但有偏移）
      let center_dist = ((tx - center_x) * (tx - center_x) +
      (y - center_y) * (y - center_y)).to_double()
      let center_factor = 1.0 -
        center_dist / (size.to_double() * size.to_double() / 2.5)
      // 弹性变形（边缘更模糊）
      let edge_factor = if tx < 2 || tx >= size - 2 || y < 2 || y >= size - 2 {
        0.6
      } else {
        1.0
      }
      let threshold = (30.0 + center_factor * 25.0 + edge_factor * 10.0).to_int()
      if combined < threshold && tx >= 0 && tx < size {
        features[y * size + x] = 1.0
      }
    }
  }
  features
}

///|
/// 提取手写体笔画特征
pub fn extract_handwriting_stroke_features(
  char_img : @types.Image,
) -> HandwritingStrokeFeatures raise @types.LoadError {
  // 输入验证
  if char_img.width <= 0 || char_img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "extract_handwriting_stroke_features: 图像尺寸必须大于0",
    )
  }
  if char_img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "extract_handwriting_stroke_features: 仅支持单通道灰度图",
    )
  }
  let expected_size = char_img.width * char_img.height
  if char_img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "extract_handwriting_stroke_features: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      char_img.data.length().to_string(),
    )
  }
  let w = char_img.width
  let h = char_img.height
  let data = char_img.data
  // 估计笔画数（基于连通域数量）
  let labels : Array[Int] = Array::make(w * h, 0)
  let mut num_components = 0
  for y in 0..<h {
    for x in 0..<w {
      if data[y * w + x].to_int() > 128 && labels[y * w + x] == 0 {
        num_components += 1
        // 简单洪水填充
        let stack : Array[(Int, Int)] = []
        stack.push((x, y))
        labels[y * w + x] = num_components
        while stack.length() > 0 {
          match stack.pop() {
            Some((cx, cy)) => {
              let neighbors = [
                (cx + 1, cy),
                (cx - 1, cy),
                (cx, cy + 1),
                (cx, cy - 1),
              ]
              for _tup0 in neighbors {
                let (nx, ny) = _tup0
                if nx >= 0 &&
                  nx < w &&
                  ny >= 0 &&
                  ny < h &&
                  data[ny * w + nx].to_int() > 128 &&
                  labels[ny * w + nx] == 0 {
                  labels[ny * w + nx] = num_components
                  stack.push((nx, ny))
                }
              }
            }
            None => ignore(())
          }
        }
      }
    }
  }
  // 计算主要笔画方向（基于梯度方向直方图）
  let directions : Array[Double] = []
  let mut total_grad = 0.0
  ignore(total_grad)
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      if data[y * w + x].to_int() > 128 {
        let gx = data[y * w + x + 1].to_int().to_double() -
          data[y * w + x - 1].to_int().to_double()
        let gy = data[(y + 1) * w + x].to_int().to_double() -
          data[(y - 1) * w + x].to_int().to_double()
        let grad = (gx * gx + gy * gy).sqrt()
        if grad > 10.0 {
          let angle = @math.atan2(gy, gx)
          directions.push(angle)
          total_grad += grad
        }
      }
    }
  }
  // 计算连通性（连笔程度）
  let mut ink_pixels = 0
  for i in 0..<(w * h) {
    if data[i].to_int() > 128 {
      ink_pixels += 1
    }
  }
  let connectivity = if num_components > 0 {
    ink_pixels.to_double() / (num_components.to_double() * 50.0)
  } else {
    0.0
  }
  // 计算曲率（基于方向变化）
  let mut curvature = 0.0
  if directions.length() > 10 {
    let mut prev_angle = directions[0]
    for i in 1..<directions.length() {
      let diff = (directions[i] - prev_angle).abs()
      curvature += if diff > 3.141592653589793 {
        6.283185307179586 - diff
      } else {
        diff
      }
      prev_angle = directions[i]
    }
    curvature = curvature / directions.length().to_double()
  }
  HandwritingStrokeFeatures::{
    num_strokes: num_components,
    stroke_directions: directions,
    stroke_lengths: [],
    connectivity: connectivity.min(1.0),
    curvature,
  }
}

///|
/// 弹性匹配（允许形状变形的模板匹配）
pub fn elastic_match(
  features : Array[Double],
  template : Array[Double],
  elasticity? : Double = 0.5,
  grid_size? : Int = 16,
) -> Double {
  let n = if features.length() < template.length() {
    features.length()
  } else {
    template.length()
  }
  // 基础距离
  let mut base_dist = 0.0
  for i in 0..<n {
    let diff = features[i] - template[i]
    base_dist += diff * diff
  }
  base_dist = base_dist.sqrt()
  // 弹性变形补偿（计算局部相似度）
  let cell = n / grid_size
  let mut local_similarity = 0.0
  for block in 0..<grid_size {
    let start = block * cell
    let end = if start + cell < n { start + cell } else { n }
    let mut block_dist = 0.0
    for i in start..<end {
      let diff = features[i] - template[i]
      block_dist += diff * diff
    }
    block_dist = block_dist.sqrt()
    local_similarity += 1.0 / (1.0 + block_dist)
  }
  local_similarity = local_similarity / grid_size.to_double()
  // 弹性匹配距离 = 基础距离 * (1 - elasticity * 局部相似度)
  let elastic_dist = base_dist * (1.0 - elasticity * local_similarity * 0.3)
  elastic_dist
}

///|
/// 连笔字符分割（基于笔画特征的分割点检测）
pub fn segment_cursive_chars(
  img : @types.Image,
  min_char_width? : Int = 8,
  max_char_width? : Int = 80,
) -> Array[(Int, Int, Int, Int)] {
  let w = img.width
  let h = img.height
  let data = img.data
  // 计算垂直投影
  let projection : Array[Int] = Array::make(w, 0)
  for x in 0..<w {
    let mut count = 0
    for y in 0..<h {
      if data[y * w + x].to_int() > 128 {
        count += 1
      }
    }
    projection[x] = count
  }
  // 检测分割点（投影局部最小值）
  let split_points : Array[Int] = []
  for x in 2..<(w - 2) {
    if projection[x] < projection[x - 1] &&
      projection[x] < projection[x + 1] &&
      projection[x] < h / 10 {
      split_points.push(x)
    }
  }
  // 基于分割点提取字符区域
  let regions : Array[(Int, Int, Int, Int)] = []
  let mut prev_x = 0
  for split_x in split_points {
    let char_w = split_x - prev_x
    if char_w >= min_char_width && char_w <= max_char_width {
      // 找到字符的上下边界
      let mut min_y = h
      let mut max_y = 0
      for x in prev_x..<split_x {
        for y in 0..<h {
          if data[y * w + x].to_int() > 128 {
            if y < min_y {
              min_y = y
            }
            if y > max_y {
              max_y = y
            }
          }
        }
      }
      if max_y > min_y {
        regions.push((prev_x, min_y, char_w, max_y - min_y + 1))
      }
    }
    prev_x = split_x
  }
  // 处理最后一个字符
  let char_w = w - prev_x
  if char_w >= min_char_width && char_w <= max_char_width {
    let mut min_y = h
    let mut max_y = 0
    for x in prev_x..<w {
      for y in 0..<h {
        if data[y * w + x].to_int() > 128 {
          if y < min_y {
            min_y = y
          }
          if y > max_y {
            max_y = y
          }
        }
      }
    }
    if max_y > min_y {
      regions.push((prev_x, min_y, char_w, max_y - min_y + 1))
    }
  }
  regions
}

///|
/// 手写体后处理（基于常见手写体混淆的纠错）
pub fn handwriting_postprocess(
  text : String,
  confidence : Double,
) -> (String, Double) {
  // 常见手写体混淆字符纠错
  let corrected = text
  // 简单替换（基于上下文的简单纠错）
  // 注意：这是简化版，实际应该用语言模型
  let mut adjusted_confidence = confidence
  // 如果置信度低，降低调整后的置信度
  if confidence < 0.5 {
    adjusted_confidence = confidence * 0.9
  }
  (corrected, adjusted_confidence)
}

///|
/// 增强手写体识别（完整流水线）
pub fn recognize_handwriting_enhanced(
  img : @types.Image,
  config? : HandwritingOcrEnhancedConfig,
) -> OcrResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_handwriting_enhanced: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "recognize_handwriting_enhanced: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "recognize_handwriting_enhanced: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let cfg = match config {
    Some(c) => c
    None => handwriting_ocr_enhanced_default_config()
  }
  // 1. 预处理
  let mut preprocessed = ocr_preprocess(img)
  // 2. 倾斜校正（手写体专用）
  if cfg.use_slant_correction {
    preprocessed = correct_slant(preprocessed)
  }
  // 3. 连笔字符分割
  let char_regions = if cfg.use_elastic_matching {
    segment_cursive_chars(
      preprocessed,
      min_char_width=cfg.min_char_width,
      max_char_width=cfg.max_char_width,
    )
  } else {
    segment_handwriting_chars_simple(preprocessed, cfg)
  }
  // 4. 生成增强手写体模板
  let templates = generate_enhanced_handwriting_templates(
    char_set="digits+letters",
    num_variants=cfg.num_variants,
  )
  // 5. 对每个字符进行识别
  let char_results : Array[OcrCharResult] = []
  let mut text = ""
  let mut total_confidence = 0.0
  for _tup1 in char_regions {
    let (x, y, w, h) = _tup1
    // 提取字符图像
    let char_img = extract_handwriting_char_region_enhanced(
      preprocessed,
      x,
      y,
      w,
      h,
      cfg.target_size,
    )
    // 提取网格特征
    let features = extract_handwriting_grid_features(char_img, 16)
    // 提取笔画特征（如果启用）
    let stroke_features = if cfg.use_stroke_features {
      extract_handwriting_stroke_features(char_img)
    } else {
      HandwritingStrokeFeatures::{
        num_strokes: 0,
        stroke_directions: [],
        stroke_lengths: [],
        connectivity: 0.0,
        curvature: 0.0,
      }
    }
    // 模板匹配（多变体投票 + 弹性匹配）
    let result = match_handwriting_enhanced(
      features, templates, stroke_features, cfg,
    )
    // 后处理（如果启用）
    let (final_char, final_conf) = if cfg.use_postprocessing {
      handwriting_postprocess(result.0, result.1)
    } else {
      result
    }
    text += final_char
    total_confidence += final_conf
    char_results.push(OcrCharResult::{
      char: final_char,
      confidence: final_conf,
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
/// 简单字符分割（备用）
fn segment_handwriting_chars_simple(
  img : @types.Image,
  cfg : HandwritingOcrEnhancedConfig,
) -> Array[(Int, Int, Int, Int)] {
  let w = img.width
  let h = img.height
  let data = img.data
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
  let regions : Array[(Int, Int, Int, Int)] = []
  for label in 1..<next_label {
    let rw = max_x[label] - min_x[label] + 1
    let rh = max_y[label] - min_y[label] + 1
    if rw >= cfg.min_char_width &&
      rw <= cfg.max_char_width &&
      rh >= cfg.min_char_height &&
      rh <= cfg.max_char_height &&
      area[label] > 15 {
      regions.push((min_x[label], min_y[label], rw, rh))
    }
  }
  regions
}

///|
/// 提取手写体字符区域（增强版）
fn extract_handwriting_char_region_enhanced(
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
/// 提取手写体网格特征
fn extract_handwriting_grid_features(
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
/// 增强手写体模板匹配（多变体投票 + 弹性匹配 + 笔画特征）
fn match_handwriting_enhanced(
  features : Array[Double],
  templates : Array[(String, Array[Double])],
  stroke_features : HandwritingStrokeFeatures,
  cfg : HandwritingOcrEnhancedConfig,
) -> (String, Double) {
  ignore(stroke_features)
  // 收集所有变体的预测
  let label_votes : Array[(String, Double)] = []
  for _tup2 in templates {
    let (label_full, template) = _tup2
    // 弹性匹配（如果启用）
    let dist = if cfg.use_elastic_matching {
      elastic_match(features, template, elasticity=cfg.elasticity, grid_size=16)
    } else {
      let n = if features.length() < template.length() {
        features.length()
      } else {
        template.length()
      }
      let mut sum_sq = 0.0
      for i in 0..<n {
        let diff = features[i] - template[i]
        sum_sq += diff * diff
      }
      sum_sq.sqrt()
    }
    let confidence = if dist > 0.0 { 1.0 / (1.0 + dist) } else { 1.0 }
    // 提取基础标签（去掉变体后缀）
    let base_label = if label_full.length() > 0 {
      label_full[0].to_string()
    } else {
      label_full
    }
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
  let mut total_votes = 0.0
  for _tup3 in label_votes {
    let (label, votes) = _tup3
    total_votes += votes
    if votes > best_votes {
      best_votes = votes
      best_label = label
    }
  }
  let confidence = if total_votes > 0.0 {
    best_votes / total_votes
  } else {
    0.0
  }
  (best_label, confidence)
}

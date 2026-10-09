// OCR 准确率提升增强版（v10.1.0）
// Zernike矩、Gabor特征、加权KNN、置信度校准、多尺度融合

///|
/// 准确率提升配置
pub(all) struct OcrAccuracyEnhancedConfig {
  use_zernike_moments : Bool
  use_gabor_features : Bool
  use_directional_features : Bool
  use_weighted_knn : Bool
  use_confidence_calibration : Bool
  use_multi_scale : Bool
  knn_k : Int
  scales : Array[Int] // 多尺度识别的尺寸列表
}

///|
/// 创建默认准确率提升配置
pub fn ocr_accuracy_enhanced_default_config() -> OcrAccuracyEnhancedConfig {
  OcrAccuracyEnhancedConfig::{
    use_zernike_moments: true,
    use_gabor_features: true,
    use_directional_features: true,
    use_weighted_knn: true,
    use_confidence_calibration: true,
    use_multi_scale: false,
    knn_k: 5,
    scales: [24, 32, 48],
  }
}

///|
/// 提取 Zernike 矩特征（旋转不变性，前6阶）
pub fn extract_zernike_moments(
  char_img : @types.Image,
  max_order? : Int = 4,
) -> Array[Double] raise @types.LoadError {
  // 输入验证
  if char_img.width <= 0 || char_img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "extract_zernike_moments: 图像尺寸必须大于0",
    )
  }
  if char_img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "extract_zernike_moments: 仅支持单通道灰度图",
    )
  }
  let expected_size = char_img.width * char_img.height
  if char_img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "extract_zernike_moments: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      char_img.data.length().to_string(),
    )
  }
  if max_order <= 0 {
    raise @types.LoadError::DecodeFailed(
      "extract_zernike_moments: 最大阶数必须大于0",
    )
  }
  let w = char_img.width
  let h = char_img.height
  let data = char_img.data
  let features : Array[Double] = []
  // 计算质心
  let mut sum_x = 0.0
  let mut sum_y = 0.0
  let mut total = 0.0
  for y in 0..<h {
    for x in 0..<w {
      if data[y * w + x].to_int() > 128 {
        sum_x += x.to_double()
        sum_y += y.to_double()
        total += 1.0
      }
    }
  }
  let cx = if total > 0.0 { sum_x / total } else { w.to_double() / 2.0 }
  let cy = if total > 0.0 { sum_y / total } else { h.to_double() / 2.0 }
  // 计算半径（归一化）
  let max_r = w.to_double().max(h.to_double()) / 2.0
  // 计算 Zernike 矩（简化版：前几阶的径向矩）
  for n in 0..<(max_order + 1) {
    for m in 0..<(n + 1) {
      if (n - m) % 2 == 0 {
        let mut z_real = 0.0
        let mut z_imag = 0.0
        for y in 0..<h {
          for x in 0..<w {
            if data[y * w + x].to_int() > 128 {
              // 归一化坐标
              let nx = (x.to_double() - cx) / max_r
              let ny = (y.to_double() - cy) / max_r
              let r = (nx * nx + ny * ny).sqrt()
              let theta = @math.atan2(ny, nx)
              if r <= 1.0 {
                // 简化的径向多项式
                let mut radial = 0.0
                let k_max = (n - m) / 2
                for k in 0..<(k_max + 1) {
                  let sign = if k % 2 == 0 { 1.0 } else { -1.0 }
                  let numerator = factorial(n - k)
                  let denominator = factorial(k) *
                    factorial((n + m) / 2 - k) *
                    factorial((n - m) / 2 - k)
                  if denominator > 0.0 {
                    radial += sign *
                      numerator /
                      denominator *
                      @math.pow(r, (n - 2 * k).to_double())
                  }
                }
                z_real += radial * @math.cos(m.to_double() * theta)
                z_imag += radial * @math.sin(m.to_double() * theta)
              }
            }
          }
        }
        // 归一化
        let magnitude = (z_real * z_real + z_imag * z_imag).sqrt()
        features.push(magnitude / (w * h).to_double())
      }
    }
  }
  features
}

///|
/// 计算阶乘
fn factorial(n : Int) -> Double {
  let mut result = 1.0
  for i in 1..<(n + 1) {
    result *= i.to_double()
  }
  result
}

///|
/// 提取 Gabor 特征（多方向多频率）
pub fn extract_gabor_ocr_features(
  char_img : @types.Image,
  num_orientations? : Int = 4,
  num_frequencies? : Int = 2,
) -> Array[Double] {
  let w = char_img.width
  let h = char_img.height
  let data = char_img.data
  let features : Array[Double] = []
  // 对每个方向和频率计算 Gabor 响应能量
  for o in 0..<num_orientations {
    let theta = o.to_double() * 3.141592653589793 / num_orientations.to_double()
    for f in 0..<num_frequencies {
      let frequency = (f + 1).to_double() * 0.1
      let _ = 1.0 / (frequency * 2.0)
      // 计算 Gabor 滤波响应（简化版：统计方向能量）
      let mut energy = 0.0
      let mut count = 0
      for y in 2..<(h - 2) {
        for x in 2..<(w - 2) {
          if data[y * w + x].to_int() > 128 {
            // 计算该方向的梯度能量
            let dx = @math.cos(theta)
            let dy = @math.sin(theta)
            let x1 = (x.to_double() + dx).to_int()
            let y1 = (y.to_double() + dy).to_int()
            let x2 = (x.to_double() - dx).to_int()
            let y2 = (y.to_double() - dy).to_int()
            if x1 >= 0 &&
              x1 < w &&
              y1 >= 0 &&
              y1 < h &&
              x2 >= 0 &&
              x2 < w &&
              y2 >= 0 &&
              y2 < h {
              let g1 = data[y1 * w + x1].to_int().to_double()
              let g2 = data[y2 * w + x2].to_int().to_double()
              let grad = (g1 - g2).abs()
              energy += grad * grad * frequency
              count += 1
            }
          }
        }
      }
      let avg_energy = if count > 0 { energy / count.to_double() } else { 0.0 }
      features.push(avg_energy / 255.0)
    }
  }
  features
}

///|
/// 提取方向特征（8个方向的笔画密度）
pub fn extract_directional_features(char_img : @types.Image) -> Array[Double] {
  let w = char_img.width
  let h = char_img.height
  let data = char_img.data
  let features : Array[Double] = []
  // 8个方向：0°(水平)、45°、90°(垂直)、135°、180°、225°、270°、315°
  let directions : Array[(Double, Double)] = [
    (1.0, 0.0), // 0° 水平
    (0.707, 0.707), // 45°
    (0.0, 1.0), // 90° 垂直
    (-0.707, 0.707), // 135°
    (-1.0, 0.0), // 180°
    (-0.707, -0.707), // 225°
    (0.0, -1.0), // 270°
    (0.707, -0.707), // 315°
  ]
  for _tup0 in directions {
    let (dx, dy) = _tup0
    let mut energy = 0.0
    let mut count = 0
    for y in 2..<(h - 2) {
      for x in 2..<(w - 2) {
        if data[y * w + x].to_int() > 128 {
          let x1 = (x.to_double() + dx * 2.0).to_int()
          let y1 = (y.to_double() + dy * 2.0).to_int()
          let x2 = (x.to_double() - dx * 2.0).to_int()
          let y2 = (y.to_double() - dy * 2.0).to_int()
          if x1 >= 0 &&
            x1 < w &&
            y1 >= 0 &&
            y1 < h &&
            x2 >= 0 &&
            x2 < w &&
            y2 >= 0 &&
            y2 < h {
            let g1 = data[y1 * w + x1].to_int().to_double()
            let g2 = data[y2 * w + x2].to_int().to_double()
            energy += (g1 - g2).abs()
            count += 1
          }
        }
      }
    }
    let avg = if count > 0 { energy / count.to_double() } else { 0.0 }
    features.push(avg / 255.0)
  }
  features
}

///|
/// 加权 KNN 分类（距离加权投票）
pub fn weighted_knn_classify(
  features : Array[Double],
  training_data : Array[(String, Array[Double])],
  k? : Int = 5,
  distance_metric? : String = "euclidean",
) -> (String, Double, Array[(String, Double)]) {
  // 计算所有训练样本的距离
  let distances : Array[(String, Double)] = []
  for _tup1 in training_data {
    let (label, sample) = _tup1
    let dist = calculate_distance(features, sample, distance_metric)
    distances.push((label, dist))
  }
  // 按距离排序（冒泡排序）
  for _ in 0..<distances.length() {
    for j in 0..<(distances.length() - 1) {
      if distances[j].1 > distances[j + 1].1 {
        let temp = distances[j]
        distances[j] = distances[j + 1]
        distances[j + 1] = temp
      }
    }
  }
  // 取前 k 个最近邻
  let k_actual = if k < distances.length() { k } else { distances.length() }
  // 距离加权投票
  let votes : Array[(String, Double)] = []
  for i in 0..<k_actual {
    let (label, dist) = distances[i]
    let weight = if dist > 0.001 { 1.0 / dist } else { 1000.0 }
    let mut found = false
    for j in 0..<votes.length() {
      if votes[j].0 == label {
        votes[j] = (label, votes[j].1 + weight)
        found = true
      }
    }
    if !found {
      votes.push((label, weight))
    }
  }
  // 找得票最多的标签
  let mut best_label = "?"
  let mut best_votes = 0.0
  let mut total_votes = 0.0
  for _tup2 in votes {
    let (label, v) = _tup2
    total_votes += v
    if v > best_votes {
      best_votes = v
      best_label = label
    }
  }
  let confidence = if total_votes > 0.0 {
    best_votes / total_votes
  } else {
    0.0
  }
  (best_label, confidence, votes)
}

///|
/// 计算距离
fn calculate_distance(
  a : Array[Double],
  b : Array[Double],
  metric : String,
) -> Double {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  match metric {
    "manhattan" => {
      let mut sum = 0.0
      for i in 0..<n {
        sum += (a[i] - b[i]).abs()
      }
      sum
    }
    "cosine" => {
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
    _ => {
      let mut sum_sq = 0.0
      for i in 0..<n {
        let diff = a[i] - b[i]
        sum_sq += diff * diff
      }
      sum_sq.sqrt()
    }
  }
}

///|
/// 置信度校准（基于距离分布的 Platt 缩放简化版）
pub fn calibrate_confidence_enhanced(
  raw_confidence : Double,
  distance_distribution : Array[Double],
) -> Double {
  if distance_distribution.length() == 0 {
    return raw_confidence
  }
  // 计算距离分布的统计量
  let mut mean = 0.0
  let mut min_dist = 1000000.0
  let mut max_dist = 0.0
  for d in distance_distribution {
    mean += d
    if d < min_dist {
      min_dist = d
    }
    if d > max_dist {
      max_dist = d
    }
  }
  mean = mean / distance_distribution.length().to_double()
  // 基于距离分布的校准
  let range = if max_dist > min_dist { max_dist - min_dist } else { 1.0 }
  let normalized_mean = (mean - min_dist) / range
  // 如果平均距离较小，说明匹配质量高，提升置信度
  let calibration_factor = 1.0 + (1.0 - normalized_mean) * 0.3
  let calibrated = raw_confidence * calibration_factor
  if calibrated > 1.0 {
    1.0
  } else if calibrated < 0.0 {
    0.0
  } else {
    calibrated
  }
}

///|
/// 多尺度识别融合（不同尺寸下的识别结果加权融合）
pub fn multi_scale_recognize(
  char_img : @types.Image,
  templates : Array[(String, Array[Double])],
  scales : Array[Int],
  distance_metric? : String = "euclidean",
) -> (String, Double) {
  let _ = char_img.width
  let _ = char_img.height
  let _ = char_img.data
  // 对每个尺度进行识别
  let all_results : Array[(String, Double)] = []
  for scale in scales {
    // 缩放到目标尺寸
    let scaled = resize_char_image(char_img, scale, scale)
    // 提取特征
    let features = extract_grid_features(scaled, 16)
    // 模板匹配
    let mut best_label = "?"
    let mut best_dist = 1000000.0
    for _tup3 in templates {
      let (label, template) = _tup3
      let dist = calculate_distance(features, template, distance_metric)
      if dist < best_dist {
        best_dist = dist
        best_label = label
      }
    }
    let confidence = if best_dist > 0.0 { 1.0 / (1.0 + best_dist) } else { 1.0 }
    all_results.push((best_label, confidence))
  }
  // 加权融合（所有尺度等权）
  let votes : Array[(String, Double)] = []
  for _tup4 in all_results {
    let (label, conf) = _tup4
    let mut found = false
    for i in 0..<votes.length() {
      if votes[i].0 == label {
        votes[i] = (label, votes[i].1 + conf)
        found = true
      }
    }
    if !found {
      votes.push((label, conf))
    }
  }
  // 找得票最多的
  let mut best_label = "?"
  let mut best_votes = 0.0
  let mut total = 0.0
  for _tup5 in votes {
    let (label, v) = _tup5
    total += v
    if v > best_votes {
      best_votes = v
      best_label = label
    }
  }
  let confidence = if total > 0.0 { best_votes / total } else { 0.0 }
  (best_label, confidence)
}

///|
/// 缩放字符图像
fn resize_char_image(
  img : @types.Image,
  new_w : Int,
  new_h : Int,
) -> @types.Image {
  let w = img.width
  let h = img.height
  let data = img.data
  let out : Array[Byte] = Array::make(new_w * new_h, b'\x00')
  for y in 0..<new_h {
    for x in 0..<new_w {
      let src_x = x * w / new_w
      let src_y = y * h / new_h
      if src_x < w && src_y < h {
        out[y * new_w + x] = data[src_y * w + src_x]
      }
    }
  }
  @types.Image::{
    width: new_w,
    height: new_h,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

///|
/// 提取网格特征
fn extract_grid_features(
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
/// 组合多种特征（网格+HOG+LBP+Zernike+Gabor+方向特征）
pub fn extract_combined_enhanced_features(
  char_img : @types.Image,
  config : OcrAccuracyEnhancedConfig,
) -> Array[Double] raise @types.LoadError {
  // 输入验证
  if char_img.width <= 0 || char_img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "extract_combined_enhanced_features: 图像尺寸必须大于0",
    )
  }
  if char_img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "extract_combined_enhanced_features: 仅支持单通道灰度图",
    )
  }
  let expected_size = char_img.width * char_img.height
  if char_img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "extract_combined_enhanced_features: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      char_img.data.length().to_string(),
    )
  }
  let features : Array[Double] = []
  // 网格特征（基础）
  let grid = extract_grid_features(char_img, 16)
  for f in grid {
    features.push(f)
  }
  // Zernike 矩（旋转不变）
  if config.use_zernike_moments {
    let zernike = extract_zernike_moments(char_img, max_order=4)
    for f in zernike {
      features.push(f)
    }
  }
  // Gabor 特征（多方向多频率）
  if config.use_gabor_features {
    let gabor = extract_gabor_ocr_features(
      char_img,
      num_orientations=4,
      num_frequencies=2,
    )
    for f in gabor {
      features.push(f)
    }
  }
  // 方向特征（8方向）
  if config.use_directional_features {
    let directional = extract_directional_features(char_img)
    for f in directional {
      features.push(f)
    }
  }
  features
}

///|
/// 增强 OCR 识别（完整准确率提升流水线）
pub fn recognize_ocr_enhanced(
  img : @types.Image,
  templates : Array[(String, Array[Double])],
  config? : OcrAccuracyEnhancedConfig,
) -> OcrResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_ocr_enhanced: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "recognize_ocr_enhanced: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "recognize_ocr_enhanced: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if templates.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_ocr_enhanced: 模板列表不能为空",
    )
  }
  let cfg = match config {
    Some(c) => c
    None => ocr_accuracy_enhanced_default_config()
  }
  // 1. 预处理
  let preprocessed = ocr_preprocess(img)
  // 2. 字符分割
  let char_regions = segment_chars_for_enhanced(preprocessed)
  // 3. 对每个字符进行识别
  let char_results : Array[OcrCharResult] = []
  let mut text = ""
  let mut total_confidence = 0.0
  for _tup6 in char_regions {
    let (x, y, w, h) = _tup6
    // 提取字符图像
    let char_img = extract_char_region_for_enhanced(
      preprocessed, x, y, w, h, 48,
    )
    // 多尺度识别（如果启用）
    let result = if cfg.use_multi_scale {
      multi_scale_recognize(
        char_img,
        templates,
        cfg.scales,
        distance_metric="euclidean",
      )
    } else {
      // 单尺度识别
      let features = extract_combined_enhanced_features(char_img, cfg)
      // 加权 KNN（如果启用）
      if cfg.use_weighted_knn {
        let (label, conf, _) = weighted_knn_classify(
          features,
          templates,
          k=cfg.knn_k,
          distance_metric="euclidean",
        )
        // 置信度校准（如果启用）
        let final_conf = if cfg.use_confidence_calibration {
          let dists : Array[Double] = []
          for _tup7 in templates {
            let (_, sample) = _tup7
            dists.push(calculate_distance(features, sample, "euclidean"))
          }
          calibrate_confidence_enhanced(conf, dists)
        } else {
          conf
        }
        (label, final_conf)
      } else {
        // 简单模板匹配
        let mut best_label = "?"
        let mut best_dist = 1000000.0
        for _tup8 in templates {
          let (label, template) = _tup8
          let dist = calculate_distance(features, template, "euclidean")
          if dist < best_dist {
            best_dist = dist
            best_label = label
          }
        }
        let conf = if best_dist > 0.0 { 1.0 / (1.0 + best_dist) } else { 1.0 }
        (best_label, conf)
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
/// 字符分割（增强版用）
fn segment_chars_for_enhanced(
  img : @types.Image,
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
    if rw >= 5 && rw <= 100 && rh >= 8 && rh <= 100 && area[label] > 10 {
      regions.push((min_x[label], min_y[label], rw, rh))
    }
  }
  regions
}

///|
/// 提取字符区域（增强版用）
fn extract_char_region_for_enhanced(
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

// OCR 准确率提升
// 更多特征提取、集成学习、训练数据管理、置信度校准

///|
/// 训练样本数据集
pub(all) struct TrainingDataset {
  samples : Array[TrainingSample]
  labels : Array[String]
  num_samples : Int
  num_classes : Int
}

///|
/// 集成分类器配置
pub(all) struct EnsembleConfig {
  use_knn : Bool
  use_template : Bool
  use_svm_like : Bool
  knn_k : Int
  voting_method : String // "majority" / "weighted" / "confidence"
}

///|
/// 创建默认集成配置
pub fn ensemble_default_config() -> EnsembleConfig {
  EnsembleConfig::{
    use_knn: true,
    use_template: true,
    use_svm_like: true,
    knn_k: 3,
    voting_method: "weighted",
  }
}

///|
/// 创建空训练数据集
pub fn dataset_create() -> TrainingDataset {
  TrainingDataset::{ samples: [], labels: [], num_samples: 0, num_classes: 0 }
}

///|
/// 添加样本到数据集
pub fn dataset_add_sample(
  dataset : TrainingDataset,
  features : Array[Double],
  label : String,
) -> TrainingDataset {
  let new_samples = dataset.samples
  new_samples.push(TrainingSample::{ features, label })
  let new_labels = dataset.labels
  let mut found = false
  for l in new_labels {
    if l == label {
      found = true
    }
  }
  if !found {
    new_labels.push(label)
  }
  TrainingDataset::{
    samples: new_samples,
    labels: new_labels,
    num_samples: new_samples.length(),
    num_classes: new_labels.length(),
  }
}

///|
/// 数据集统计信息
pub fn dataset_stats(
  dataset : TrainingDataset,
) -> (Int, Int, Array[(String, Int)]) {
  let class_counts : Array[(String, Int)] = []
  for label in dataset.labels {
    let mut count = 0
    for sample in dataset.samples {
      if sample.label == label {
        count += 1
      }
    }
    class_counts.push((label, count))
  }
  (dataset.num_samples, dataset.num_classes, class_counts)
}

///|
/// 特征增广（添加噪声、缩放、平移）
pub fn augment_features(
  features : Array[Double],
  noise_level? : Double = 0.05,
) -> Array[Double] {
  let augmented : Array[Double] = []
  for i in 0..<features.length() {
    // 添加高斯噪声（简化为均匀噪声）
    let noise = (pseudo_random(i) - 0.5) * 2.0 * noise_level
    let new_val = features[i] + noise
    let clamped = if new_val < 0.0 {
      0.0
    } else if new_val > 1.0 {
      1.0
    } else {
      new_val
    }
    augmented.push(clamped)
  }
  augmented
}

///|
/// 伪随机数生成（基于索引的确定性随机）
fn pseudo_random(seed : Int) -> Double {
  let x = (seed * 1103515245 + 12345) % 1073741824
  x.to_double() / 1073741824.0
}

///|
/// Hu 矩特征（7个不变矩）
pub fn hu_moments_features(
  img : @types.Image,
) -> Array[Double] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "hu_moments_features: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "hu_moments_features: 仅支持单通道图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "hu_moments_features: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let w = img.width
  let h = img.height
  let data = img.data
  // 计算零阶和一阶矩
  let mut m00 = 0.0
  let mut m10 = 0.0
  let mut m01 = 0.0
  for y in 0..<h {
    for x in 0..<w {
      let val = data[y * w + x].to_int().to_double() / 255.0
      m00 += val
      m10 += x.to_double() * val
      m01 += y.to_double() * val
    }
  }
  if m00 == 0.0 {
    return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
  }
  // 质心
  let x_bar = m10 / m00
  let y_bar = m01 / m00
  // 计算中心矩
  let mut mu20 = 0.0
  let mut mu02 = 0.0
  let mut mu11 = 0.0
  let mut mu30 = 0.0
  let mut mu03 = 0.0
  let mut mu21 = 0.0
  let mut mu12 = 0.0
  for y in 0..<h {
    for x in 0..<w {
      let val = data[y * w + x].to_int().to_double() / 255.0
      let dx = x.to_double() - x_bar
      let dy = y.to_double() - y_bar
      mu20 += dx * dx * val
      mu02 += dy * dy * val
      mu11 += dx * dy * val
      mu30 += dx * dx * dx * val
      mu03 += dy * dy * dy * val
      mu21 += dx * dx * dy * val
      mu12 += dx * dy * dy * val
    }
  }
  // 归一化中心矩
  let eta20 = mu20 / (m00 * m00)
  let eta02 = mu02 / (m00 * m00)
  let eta11 = mu11 / (m00 * m00)
  let eta30 = mu30 /
    (m00 * m00 * m00 * m00 * m00 * m00 * m00 * m00 * m00 * m00).sqrt()
  let eta03 = mu03 /
    (m00 * m00 * m00 * m00 * m00 * m00 * m00 * m00 * m00 * m00).sqrt()
  let eta21 = mu21 /
    (m00 * m00 * m00 * m00 * m00 * m00 * m00 * m00 * m00 * m00).sqrt()
  let eta12 = mu12 /
    (m00 * m00 * m00 * m00 * m00 * m00 * m00 * m00 * m00 * m00).sqrt()
  // Hu 不变矩
  let h1 = eta20 + eta02
  let h2 = (eta20 - eta02) * (eta20 - eta02) + 4.0 * eta11 * eta11
  let h3 = (eta30 - 3.0 * eta12) * (eta30 - 3.0 * eta12) +
    (3.0 * eta21 - eta03) * (3.0 * eta21 - eta03)
  let h4 = (eta30 + eta12) * (eta30 + eta12) + (eta21 + eta03) * (eta21 + eta03)
  let h5 = (eta30 - 3.0 * eta12) *
    (eta30 + eta12) *
    (
      (eta30 + eta12) * (eta30 + eta12) -
      3.0 * (eta21 + eta03) * (eta21 + eta03)
    ) +
    (3.0 * eta21 - eta03) *
    (eta21 + eta03) *
    (
      3.0 * (eta30 + eta12) * (eta30 + eta12) -
      (eta21 + eta03) * (eta21 + eta03)
    )
  let h6 = (eta20 - eta02) *
    ((eta30 + eta12) * (eta30 + eta12) - (eta21 + eta03) * (eta21 + eta03)) +
    4.0 * eta11 * (eta30 + eta12) * (eta21 + eta03)
  let h7 = (3.0 * eta21 - eta03) *
    (eta30 + eta12) *
    (
      (eta30 + eta12) * (eta30 + eta12) -
      3.0 * (eta21 + eta03) * (eta21 + eta03)
    ) -
    (eta30 - 3.0 * eta12) *
    (eta21 + eta03) *
    (
      3.0 * (eta30 + eta12) * (eta30 + eta12) -
      (eta21 + eta03) * (eta21 + eta03)
    )
  [h1, h2, h3, h4, h5, h6, h7]
}

///|
/// 集成分类器预测（多分类器投票）
pub fn ensemble_predict(
  features : Array[Double],
  knn_classifier : KnnClassifier,
  templates : Array[(String, Array[Double])],
  config? : EnsembleConfig,
) -> ClassificationResult raise @types.LoadError {
  // 输入验证
  if features.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "ensemble_predict: 特征向量不能为空",
    )
  }

  let cfg = match config {
    Some(c) => c
    None => ensemble_default_config()
  }
  // 收集所有分类器的预测
  let predictions : Array[(String, Double)] = []
  // KNN 预测
  if cfg.use_knn {
    let knn_result = knn_predict(knn_classifier, features) catch {
      _ => ClassificationResult::{ label: "?", confidence: 0.0, top_k: [] }
    }
    predictions.push((knn_result.label, knn_result.confidence))
  }
  // 模板匹配预测
  if cfg.use_template {
    let mut best_label = "?"
    let mut best_dist = 1000000.0
    for _tup0 in templates {
      let (label, template) = _tup0
      let dist = euclidean_distance_ensemble(features, template)
      if dist < best_dist {
        best_dist = dist
        best_label = label
      }
    }
    let confidence = if best_dist > 0.0 { 1.0 / (1.0 + best_dist) } else { 1.0 }
    predictions.push((best_label, confidence))
  }
  // SVM-like 预测（简化版：基于距离的线性分类）
  if cfg.use_svm_like {
    // 简化：使用最近邻作为SVM-like预测
    if templates.length() > 0 {
      let mut best_label = "?"
      let mut best_dist = 1000000.0
      for _tup1 in templates {
        let (label, template) = _tup1
        let dist = manhattan_distance_ensemble(features, template)
        if dist < best_dist {
          best_dist = dist
          best_label = label
        }
      }
      let confidence = if best_dist > 0.0 {
        1.0 / (1.0 + best_dist)
      } else {
        1.0
      }
      predictions.push((best_label, confidence))
    }
  }
  // 投票
  let label_votes : Array[(String, Double)] = []
  for _tup2 in predictions {
    let (label, conf) = _tup2
    let mut found = false
    for i in 0..<label_votes.length() {
      if label_votes[i].0 == label {
        let weight = match cfg.voting_method {
          "majority" => 1.0
          "confidence" => conf
          _ => conf
        }
        label_votes[i] = (label, label_votes[i].1 + weight)
        found = true
      }
    }
    if !found {
      let weight = match cfg.voting_method {
        "majority" => 1.0
        "confidence" => conf
        _ => conf
      }
      label_votes.push((label, weight))
    }
  }
  // 找得票最多的标签
  let mut best_label = "?"
  let mut best_votes = 0.0
  for _tup3 in label_votes {
    let (label, votes) = _tup3
    if votes > best_votes {
      best_votes = votes
      best_label = label
    }
  }
  let total_votes = if predictions.length() > 0 {
    predictions.length().to_double()
  } else {
    1.0
  }
  let confidence = best_votes / total_votes
  ClassificationResult::{ label: best_label, confidence, top_k: predictions }
}

///|
/// 局部欧氏距离
fn euclidean_distance_ensemble(a : Array[Double], b : Array[Double]) -> Double {
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
fn manhattan_distance_ensemble(a : Array[Double], b : Array[Double]) -> Double {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  let mut sum = 0.0
  for i in 0..<n {
    sum += (a[i] - b[i]).abs()
  }
  sum
}

///|
/// 组合多种特征（网格+HOG+LBP+Hu矩）
pub fn extract_combined_ocr_features(
  img : @types.Image,
) -> Array[Double] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "extract_combined_ocr_features: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "extract_combined_ocr_features: 仅支持单通道灰度图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "extract_combined_ocr_features: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  // 网格特征
  let grid = grid_features(img, grid_rows=8, grid_cols=8)
  // HOG 特征
  let hog = hog_features(img, cell_size=8, num_bins=9)
  // LBP 特征（降采样）
  let lbp = lbp_features(img, radius=1, num_points=8, num_bins=64)
  // Hu 矩特征
  let hu = hu_moments_features(img)
  // 组合
  let combined : Array[Double] = []
  for f in grid.features {
    combined.push(f)
  }
  for f in hog.features {
    combined.push(f)
  }
  for i in 0..<lbp.features.length() {
    if i < 64 {
      combined.push(lbp.features[i])
    }
  }
  for f in hu {
    combined.push(f)
  }
  combined
}

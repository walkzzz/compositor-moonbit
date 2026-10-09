// 简单分类器
// KNN、模板匹配、距离度量、分类结果

///|
/// 分类结果结构体
pub(all) struct ClassificationResult {
  label : String
  confidence : Double
  top_k : Array[(String, Double)]
}

///|
/// 训练样本结构体
pub(all) struct TrainingSample {
  features : Array[Double]
  label : String
}

///|
/// KNN 分类器
pub(all) struct KnnClassifier {
  samples : Array[TrainingSample]
  k : Int
  distance_metric : String
}

///|
/// 模板匹配分类器
pub(all) struct TemplateMatcher {
  templates : Array[(String, Array[Double])]
  distance_metric : String
}

///|
/// 距离度量类型
pub(all) enum DistanceMetric {
  Euclidean
  Manhattan
  Cosine
  Chebyshev
} derive(Eq)

///|
/// 计算欧氏距离
pub fn euclidean_distance(
  a : Array[Double],
  b : Array[Double],
) -> Double raise @types.LoadError {
  // 输入验证
  if a.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "euclidean_distance: 向量a不能为空",
    )
  }
  if b.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "euclidean_distance: 向量b不能为空",
    )
  }

  let n = if a.length() < b.length() { a.length() } else { b.length() }
  let mut sum_sq = 0.0
  for i in 0..<n {
    let diff = a[i] - b[i]
    sum_sq += diff * diff
  }
  sum_sq.sqrt()
}

///|
/// 计算曼哈顿距离
pub fn manhattan_distance(
  a : Array[Double],
  b : Array[Double],
) -> Double raise @types.LoadError {
  // 输入验证
  if a.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "manhattan_distance: 向量a不能为空",
    )
  }
  if b.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "manhattan_distance: 向量b不能为空",
    )
  }

  let n = if a.length() < b.length() { a.length() } else { b.length() }
  let mut sum = 0.0
  for i in 0..<n {
    sum += (a[i] - b[i]).abs()
  }
  sum
}

///|
/// 计算余弦相似度（返回距离 = 1 - 相似度）
pub fn cosine_distance(
  a : Array[Double],
  b : Array[Double],
) -> Double raise @types.LoadError {
  // 输入验证
  if a.length() == 0 {
    raise @types.LoadError::DecodeFailed("cosine_distance: 向量a不能为空")
  }
  if b.length() == 0 {
    raise @types.LoadError::DecodeFailed("cosine_distance: 向量b不能为空")
  }

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
/// 计算切比雪夫距离
pub fn chebyshev_distance(
  a : Array[Double],
  b : Array[Double],
) -> Double raise @types.LoadError {
  // 输入验证
  if a.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "chebyshev_distance: 向量a不能为空",
    )
  }
  if b.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "chebyshev_distance: 向量b不能为空",
    )
  }

  let n = if a.length() < b.length() { a.length() } else { b.length() }
  let mut max_diff = 0.0
  for i in 0..<n {
    let diff = (a[i] - b[i]).abs()
    if diff > max_diff {
      max_diff = diff
    }
  }
  max_diff
}

///|
/// 计算距离（根据度量类型）
pub fn compute_distance(
  a : Array[Double],
  b : Array[Double],
  metric : DistanceMetric,
) -> Double raise @types.LoadError {
  // 输入验证
  if a.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "compute_distance: 向量a不能为空",
    )
  }
  if b.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "compute_distance: 向量b不能为空",
    )
  }

  match metric {
    DistanceMetric::Euclidean => euclidean_distance(a, b)
    DistanceMetric::Manhattan => manhattan_distance(a, b)
    DistanceMetric::Cosine => cosine_distance(a, b)
    DistanceMetric::Chebyshev => chebyshev_distance(a, b)
  }
}

///|
/// 创建 KNN 分类器
pub fn knn_create(
  k? : Int = 3,
  distance_metric? : String = "euclidean",
) -> KnnClassifier raise @types.LoadError {
  // 输入验证
  if k <= 0 {
    raise @types.LoadError::DecodeFailed("knn_create: k必须大于0")
  }

  KnnClassifier::{ samples: [], k, distance_metric }
}

///|
/// 添加训练样本
pub fn knn_add_sample(
  classifier : KnnClassifier,
  features : Array[Double],
  label : String,
) -> KnnClassifier raise @types.LoadError {
  // 输入验证
  if features.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "knn_add_sample: 特征向量不能为空",
    )
  }
  if label.length() == 0 {
    raise @types.LoadError::DecodeFailed("knn_add_sample: 标签不能为空")
  }

  let new_samples = classifier.samples
  new_samples.push(TrainingSample::{ features, label })
  KnnClassifier::{
    samples: new_samples,
    k: classifier.k,
    distance_metric: classifier.distance_metric,
  }
}

///|
/// 批量添加训练样本
pub fn knn_add_samples(
  classifier : KnnClassifier,
  samples : Array[(Array[Double], String)],
) -> KnnClassifier raise @types.LoadError {
  // 输入验证
  if samples.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "knn_add_samples: 样本列表不能为空",
    )
  }

  let new_samples = classifier.samples
  for _tup0 in samples {
    let (features, label) = _tup0
    new_samples.push(TrainingSample::{ features, label })
  }
  KnnClassifier::{
    samples: new_samples,
    k: classifier.k,
    distance_metric: classifier.distance_metric,
  }
}

///|
/// KNN 预测
pub fn knn_predict(
  classifier : KnnClassifier,
  features : Array[Double],
) -> ClassificationResult raise @types.LoadError {
  // 输入验证
  if features.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "knn_predict: 特征向量不能为空",
    )
  }
  if classifier.samples.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "knn_predict: 分类器没有训练样本",
    )
  }

  let metric = match classifier.distance_metric {
    "manhattan" => DistanceMetric::Manhattan
    "cosine" => DistanceMetric::Cosine
    "chebyshev" => DistanceMetric::Chebyshev
    _ => DistanceMetric::Euclidean
  }
  // 计算所有样本的距离
  let distances : Array[(Double, String)] = []
  for sample in classifier.samples {
    let dist = compute_distance(features, sample.features, metric)
    distances.push((dist, sample.label))
  }
  // 按距离排序（冒泡排序，简单实现）
  for _ in 0..<distances.length() {
    for j in 0..<(distances.length() - 1) {
      if distances[j].0 > distances[j + 1].0 {
        let temp = distances[j]
        distances[j] = distances[j + 1]
        distances[j + 1] = temp
      }
    }
  }
  // 取前 k 个最近邻
  let k = if classifier.k < distances.length() {
    classifier.k
  } else {
    distances.length()
  }
  let top_k : Array[(String, Double)] = []
  let label_votes : Array[(String, Int)] = []
  for i in 0..<k {
    let (dist, label) = distances[i]
    let confidence = if dist > 0.0 { 1.0 / (1.0 + dist) } else { 1.0 }
    top_k.push((label, confidence))
    // 投票
    let mut found = false
    for j in 0..<label_votes.length() {
      if label_votes[j].0 == label {
        label_votes[j] = (label, label_votes[j].1 + 1)
        found = true
      }
    }
    if !found {
      label_votes.push((label, 1))
    }
  }
  // 找得票最多的标签
  let mut best_label = ""
  let mut best_votes = 0
  for _tup1 in label_votes {
    let (label, votes) = _tup1
    if votes > best_votes {
      best_votes = votes
      best_label = label
    }
  }
  let confidence = if k > 0 {
    best_votes.to_double() / k.to_double()
  } else {
    0.0
  }
  ClassificationResult::{ label: best_label, confidence, top_k }
}

///|
/// 创建模板匹配分类器
pub fn template_matcher_create(
  distance_metric? : String = "euclidean",
) -> TemplateMatcher {
  // 输入验证：distance_metric 不做强制验证，使用默认值兜底
  TemplateMatcher::{ templates: [], distance_metric }
}

///|
/// 添加模板
pub fn template_matcher_add(
  matcher : TemplateMatcher,
  label : String,
  template : Array[Double],
) -> TemplateMatcher raise @types.LoadError {
  // 输入验证
  if template.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "template_matcher_add: 模板特征向量不能为空",
    )
  }
  if label.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "template_matcher_add: 标签不能为空",
    )
  }

  let new_templates = matcher.templates
  new_templates.push((label, template))
  TemplateMatcher::{
    templates: new_templates,
    distance_metric: matcher.distance_metric,
  }
}

///|
/// 模板匹配预测
pub fn template_matcher_predict(
  matcher : TemplateMatcher,
  features : Array[Double],
) -> ClassificationResult raise @types.LoadError {
  // 输入验证
  if features.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "template_matcher_predict: 特征向量不能为空",
    )
  }
  if matcher.templates.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "template_matcher_predict: 模板匹配器没有模板",
    )
  }

  let metric = match matcher.distance_metric {
    "manhattan" => DistanceMetric::Manhattan
    "cosine" => DistanceMetric::Cosine
    "chebyshev" => DistanceMetric::Chebyshev
    _ => DistanceMetric::Euclidean
  }
  // 计算与所有模板的距离
  let distances : Array[(Double, String)] = []
  for _tup2 in matcher.templates {
    let (label, template) = _tup2
    let dist = compute_distance(features, template, metric)
    distances.push((dist, label))
  }
  // 按距离排序
  for _ in 0..<distances.length() {
    for j in 0..<(distances.length() - 1) {
      if distances[j].0 > distances[j + 1].0 {
        let temp = distances[j]
        distances[j] = distances[j + 1]
        distances[j + 1] = temp
      }
    }
  }
  // 返回最佳匹配
  let top_k : Array[(String, Double)] = []
  let n = if 5 < distances.length() { 5 } else { distances.length() }
  for i in 0..<n {
    let (dist, label) = distances[i]
    let confidence = if dist > 0.0 { 1.0 / (1.0 + dist) } else { 1.0 }
    top_k.push((label, confidence))
  }
  if distances.length() > 0 {
    let (best_dist, best_label) = distances[0]
    let confidence = if best_dist > 0.0 { 1.0 / (1.0 + best_dist) } else { 1.0 }
    ClassificationResult::{ label: best_label, confidence, top_k }
  } else {
    ClassificationResult::{ label: "", confidence: 0.0, top_k: [] }
  }
}

///|
/// 特征归一化（Min-Max 归一化到 [0, 1]）
pub fn normalize_features(
  features : Array[Double],
) -> Array[Double] raise @types.LoadError {
  // 输入验证
  if features.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "normalize_features: 特征向量不能为空",
    )
  }
  let mut min_val = features[0]
  let mut max_val = features[0]
  for v in features {
    if v < min_val {
      min_val = v
    }
    if v > max_val {
      max_val = v
    }
  }
  let range = max_val - min_val
  let normalized : Array[Double] = []
  if range > 0.0 {
    for v in features {
      normalized.push((v - min_val) / range)
    }
  } else {
    for _ in features {
      normalized.push(0.0)
    }
  }
  normalized
}

///|
/// 特征标准化（Z-score 标准化，均值0，标准差1）
pub fn standardize_features(
  features : Array[Double],
) -> Array[Double] raise @types.LoadError {
  // 输入验证
  if features.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "standardize_features: 特征向量不能为空",
    )
  }
  // 计算均值
  let mut sum = 0.0
  for v in features {
    sum += v
  }
  let mean = sum / features.length().to_double()
  // 计算标准差
  let mut sum_sq = 0.0
  for v in features {
    let diff = v - mean
    sum_sq += diff * diff
  }
  let std = if sum_sq > 0.0 {
    (sum_sq / features.length().to_double()).sqrt()
  } else {
    1.0
  }
  // 标准化
  let standardized : Array[Double] = []
  for v in features {
    standardized.push((v - mean) / std)
  }
  standardized
}

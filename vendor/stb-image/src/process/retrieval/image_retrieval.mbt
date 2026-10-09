// 图像检索（v12.13.0）
// 基于特征的图像检索、相似度计算、图像数据库管理

///|
/// 图像特征描述子
pub(all) struct ImageFeature {
  image_id : String
  features : Array[Double] // 特征向量
  width : Int
  height : Int
}

///|
/// 检索结果
pub(all) struct SearchResult {
  image_id : String
  similarity : Double
  rank : Int
}

///|
/// 图像数据库
pub(all) struct ImageDatabase {
  features : Array[ImageFeature]
  index : Array[String] // image_id 列表
}

///|
/// 创建空的图像数据库
pub fn image_database_new() -> ImageDatabase {
  ImageDatabase::{ features: [], index: [] }
}

///|
/// 计算颜色直方图特征（简化版）
fn compute_color_histogram(
  img : @types.Image,
  bins? : Int = 16,
) -> Array[Double] {
  let num_bins = bins
  let w = img.width
  let h = img.height
  let channels = img.channels
  // 每个通道的直方图
  let hist_size = num_bins * channels
  let histogram : Array[Double] = []
  for _ in 0..<hist_size {
    histogram.push(0.0)
  }
  let total_pixels = (w * h).to_double()
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      for c in 0..<channels {
        let val = img.data[idx + c].to_double()
        let bin_idx = (val / 256.0 * num_bins.to_double())
          .to_int()
          .min(num_bins - 1)
          .max(0)
        histogram[c * num_bins + bin_idx] += 1.0
      }
    }
  }
  // 归一化
  for i in 0..<hist_size {
    histogram[i] = histogram[i] / total_pixels
  }
  histogram
}

///|
/// 计算图像的平均颜色特征
fn compute_average_color(img : @types.Image) -> Array[Double] {
  let w = img.width
  let h = img.height
  let channels = img.channels
  let result : Array[Double] = []
  for c in 0..<channels {
    let mut sum = 0.0
    for y in 0..<h {
      for x in 0..<w {
        let idx = (y * w + x) * channels
        sum += img.data[idx + c].to_double()
      }
    }
    result.push(sum / (w * h).to_double() / 255.0)
  }
  result
}

///|
/// 计算图像的综合特征（颜色直方图 + 平均颜色）
pub fn extract_image_features(
  img : @types.Image,
  image_id : String,
) -> ImageFeature {
  let hist = compute_color_histogram(img, bins=16)
  let avg_color = compute_average_color(img)
  // 合并特征
  let combined : Array[Double] = []
  for v in hist {
    combined.push(v)
  }
  for v in avg_color {
    combined.push(v)
  }
  ImageFeature::{
    image_id,
    features: combined,
    width: img.width,
    height: img.height,
  }
}

///|
/// 计算余弦相似度
fn cosine_similarity(a : Array[Double], b : Array[Double]) -> Double {
  let len = a.length().min(b.length())
  let mut dot = 0.0
  let mut norm_a = 0.0
  let mut norm_b = 0.0
  for i in 0..<len {
    dot += a[i] * b[i]
    norm_a += a[i] * a[i]
    norm_b += b[i] * b[i]
  }
  let denom = norm_a.sqrt() * norm_b.sqrt()
  if denom < 0.000001 {
    return 0.0
  }
  dot / denom
}

///|
/// 计算欧氏距离
fn euclidean_distance(a : Array[Double], b : Array[Double]) -> Double {
  let len = a.length().min(b.length())
  let mut sum = 0.0
  for i in 0..<len {
    let diff = a[i] - b[i]
    sum += diff * diff
  }
  sum.sqrt()
}

///|
/// 计算直方图交集相似度
fn histogram_intersection(a : Array[Double], b : Array[Double]) -> Double {
  let len = a.length().min(b.length())
  let mut intersection = 0.0
  let mut sum_a = 0.0
  for i in 0..<len {
    intersection += a[i].min(b[i])
    sum_a += a[i]
  }
  if sum_a < 0.000001 {
    return 0.0
  }
  intersection / sum_a
}

///|
/// 向图像数据库添加图像
pub fn database_add_image(
  db : ImageDatabase,
  feature : ImageFeature,
) -> ImageDatabase {
  let new_features : Array[ImageFeature] = []
  for f in db.features {
    new_features.push(f)
  }
  new_features.push(feature)
  let new_index : Array[String] = []
  for id in db.index {
    new_index.push(id)
  }
  new_index.push(feature.image_id)
  ImageDatabase::{ features: new_features, index: new_index }
}

///|
/// 从数据库中移除图像
pub fn database_remove_image(
  db : ImageDatabase,
  image_id : String,
) -> ImageDatabase {
  let new_features : Array[ImageFeature] = []
  let new_index : Array[String] = []
  for i in 0..<db.features.length() {
    if db.features[i].image_id != image_id {
      new_features.push(db.features[i])
      new_index.push(db.index[i])
    }
  }
  ImageDatabase::{ features: new_features, index: new_index }
}

///|
/// 搜索相似图像
pub fn search_similar_images(
  db : ImageDatabase,
  query : ImageFeature,
  top_k? : Int = 5,
  method_type? : String = "cosine",
) -> Array[SearchResult] {
  let k = top_k
  let search_method = method_type
  // 计算所有相似度
  let scores : Array[(String, Double)] = []
  for f in db.features {
    let similarity = match search_method {
      "cosine" => cosine_similarity(query.features, f.features)
      "euclidean" => {
        let dist = euclidean_distance(query.features, f.features)
        1.0 / (1.0 + dist)
      }
      "histogram" => histogram_intersection(query.features, f.features)
      _ => cosine_similarity(query.features, f.features)
    }
    scores.push((f.image_id, similarity))
  }
  // 简单排序（冒泡排序，按相似度降序）
  for i in 0..<scores.length() {
    for j in 0..<(scores.length() - i - 1) {
      if scores[j].1 < scores[j + 1].1 {
        let temp = scores[j]
        scores[j] = scores[j + 1]
        scores[j + 1] = temp
      }
    }
  }
  // 返回 top_k
  let results : Array[SearchResult] = []
  let count = k.min(scores.length())
  for i in 0..<count {
    results.push(SearchResult::{
      image_id: scores[i].0,
      similarity: scores[i].1,
      rank: i + 1,
    })
  }
  results
}

///|
/// 计算两张图像的相似度
pub fn image_similarity(
  img1 : @types.Image,
  img2 : @types.Image,
  method_type? : String = "cosine",
) -> Double {
  let f1 = extract_image_features(img1, "query")
  let f2 = extract_image_features(img2, "target")
  let search_method = method_type
  match search_method {
    "cosine" => cosine_similarity(f1.features, f2.features)
    "euclidean" => {
      let dist = euclidean_distance(f1.features, f2.features)
      1.0 / (1.0 + dist)
    }
    "histogram" => histogram_intersection(f1.features, f2.features)
    _ => cosine_similarity(f1.features, f2.features)
  }
}

///|
/// 批量提取特征
pub fn batch_extract_features(
  images : Array[(@types.Image, String)],
) -> Array[ImageFeature] {
  let results : Array[ImageFeature] = []
  for _tup0 in images {
    let (img, id) = _tup0
    results.push(extract_image_features(img, id))
  }
  results
}

///|
/// 获取数据库大小
pub fn database_size(db : ImageDatabase) -> Int {
  db.features.length()
}

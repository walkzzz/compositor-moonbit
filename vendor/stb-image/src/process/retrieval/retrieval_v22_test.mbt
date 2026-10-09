// v22.0.0 图像检索增强测试 - retrieval 模块
// 基于特征的图像检索、CBIR、颜色直方图/LBP/HOG 特征、相似度度量

///|
fn make_retrieval_img(w : Int, h : Int, value : Byte) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(Array::make(w * h, value)),
  }
}

///|
fn make_varied_retrieval_img(w : Int, h : Int) -> @types.Image {
  let arr : Array[Byte] = []
  for i in 0..<(w * h) {
    arr.push((i % 256).to_byte())
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(arr),
  }
}

///|
fn make_rgb_retrieval_img(w : Int, h : Int) -> @types.Image {
  let arr : Array[Byte] = []
  for i in 0..<(w * h) {
    arr.push((i * 3 % 256).to_byte())
    arr.push(((i * 3 + 1) % 256).to_byte())
    arr.push(((i * 3 + 2) % 256).to_byte())
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 3,
    data: Bytes::from_array(arr),
  }
}

// ==================== image_retrieval.mbt 测试 ====================

///|
test "image_database_new: 创建空数据库" {
  let db = image_database_new()
  assert_eq(db.features.length(), 0)
  assert_eq(db.index.length(), 0)
}

///|
test "database_size: 空数据库大小为0" {
  let db = image_database_new()
  assert_eq(database_size(db), 0)
}

///|
test "extract_image_features: 基本特征提取" {
  let img = make_retrieval_img(4, 4, b'\x80')
  let feat = extract_image_features(img, "test_img")
  assert_eq(feat.image_id, "test_img")
  assert_eq(feat.width, 4)
  assert_eq(feat.height, 4)
  assert_true(feat.features.length() > 0)
}

///|
test "extract_image_features: RGB图像特征提取" {
  let img = make_rgb_retrieval_img(4, 4)
  let feat = extract_image_features(img, "rgb_img")
  assert_eq(feat.image_id, "rgb_img")
  assert_eq(feat.width, 4)
  assert_eq(feat.height, 4)
  assert_true(feat.features.length() > 0)
}

///|
test "database_add_image: 添加图像到数据库" {
  let img = make_retrieval_img(4, 4, b'\x80')
  let feat = extract_image_features(img, "img1")
  let db = image_database_new()
  let db2 = database_add_image(db, feat)
  assert_eq(database_size(db2), 1)
  assert_eq(db2.index[0], "img1")
}

///|
test "database_add_image: 添加多张图像" {
  let img1 = make_retrieval_img(4, 4, b'\x80')
  let img2 = make_retrieval_img(4, 4, b'\xFF')
  let feat1 = extract_image_features(img1, "img1")
  let feat2 = extract_image_features(img2, "img2")
  let db = image_database_new()
  let db2 = database_add_image(db, feat1)
  let db3 = database_add_image(db2, feat2)
  assert_eq(database_size(db3), 2)
}

///|
test "database_remove_image: 移除图像" {
  let img1 = make_retrieval_img(4, 4, b'\x80')
  let img2 = make_retrieval_img(4, 4, b'\xFF')
  let feat1 = extract_image_features(img1, "img1")
  let feat2 = extract_image_features(img2, "img2")
  let db = image_database_new()
  let db2 = database_add_image(db, feat1)
  let db3 = database_add_image(db2, feat2)
  assert_eq(database_size(db3), 2)
  let db4 = database_remove_image(db3, "img1")
  assert_eq(database_size(db4), 1)
}

///|
test "database_remove_image: 移除不存在的图像" {
  let img1 = make_retrieval_img(4, 4, b'\x80')
  let feat1 = extract_image_features(img1, "img1")
  let db = image_database_new()
  let db2 = database_add_image(db, feat1)
  let db3 = database_remove_image(db2, "nonexistent")
  assert_eq(database_size(db3), 1)
}

///|
test "search_similar_images: 基本搜索" {
  let img1 = make_retrieval_img(4, 4, b'\x80')
  let img2 = make_retrieval_img(4, 4, b'\x81')
  let img3 = make_retrieval_img(4, 4, b'\xFF')
  let feat1 = extract_image_features(img1, "img1")
  let feat2 = extract_image_features(img2, "img2")
  let feat3 = extract_image_features(img3, "img3")
  let db = image_database_new()
  let db2 = database_add_image(db, feat1)
  let db3 = database_add_image(db2, feat2)
  let db4 = database_add_image(db3, feat3)
  let query = extract_image_features(img1, "query")
  let results = search_similar_images(db4, query, top_k=2)
  assert_true(results.length() <= 2)
  if results.length() > 0 {
    assert_eq(results[0].rank, 1)
  }
}

///|
test "search_similar_images: 空数据库搜索" {
  let img = make_retrieval_img(4, 4, b'\x80')
  let query = extract_image_features(img, "query")
  let db = image_database_new()
  let results = search_similar_images(db, query, top_k=5)
  assert_eq(results.length(), 0)
}

///|
test "search_similar_images: 余弦方法" {
  let img1 = make_retrieval_img(4, 4, b'\x80')
  let img2 = make_retrieval_img(4, 4, b'\x80')
  let feat1 = extract_image_features(img1, "img1")
  let feat2 = extract_image_features(img2, "img2")
  let db = image_database_new()
  let db2 = database_add_image(db, feat1)
  let db3 = database_add_image(db2, feat2)
  let query = extract_image_features(img1, "query")
  let results = search_similar_images(db3, query, top_k=2, method_type="cosine")
  assert_true(results.length() > 0)
  assert_true(results[0].similarity >= 0.0)
}

///|
test "search_similar_images: 欧氏距离方法" {
  let img1 = make_retrieval_img(4, 4, b'\x80')
  let img2 = make_retrieval_img(4, 4, b'\xFF')
  let feat1 = extract_image_features(img1, "img1")
  let feat2 = extract_image_features(img2, "img2")
  let db = image_database_new()
  let db2 = database_add_image(db, feat1)
  let db3 = database_add_image(db2, feat2)
  let query = extract_image_features(img1, "query")
  let results = search_similar_images(
    db3,
    query,
    top_k=2,
    method_type="euclidean",
  )
  assert_true(results.length() > 0)
  assert_true(results[0].similarity >= 0.0)
}

///|
test "search_similar_images: 直方图交集方法" {
  let img1 = make_retrieval_img(4, 4, b'\x80')
  let img2 = make_retrieval_img(4, 4, b'\x80')
  let feat1 = extract_image_features(img1, "img1")
  let feat2 = extract_image_features(img2, "img2")
  let db = image_database_new()
  let db2 = database_add_image(db, feat1)
  let db3 = database_add_image(db2, feat2)
  let query = extract_image_features(img1, "query")
  let results = search_similar_images(
    db3,
    query,
    top_k=2,
    method_type="histogram",
  )
  assert_true(results.length() > 0)
  assert_true(results[0].similarity >= 0.0)
}

///|
test "image_similarity: 相同图像相似度" {
  let img1 = make_retrieval_img(4, 4, b'\x80')
  let img2 = make_retrieval_img(4, 4, b'\x80')
  let sim = image_similarity(img1, img2)
  assert_true(sim >= 0.0)
  assert_true(sim <= 1.0 + 0.0001)
}

///|
test "image_similarity: 不同图像相似度" {
  let img1 = make_retrieval_img(4, 4, b'\x00')
  let img2 = make_retrieval_img(4, 4, b'\xFF')
  let sim = image_similarity(img1, img2)
  assert_true(sim >= 0.0)
  assert_true(sim <= 1.0 + 0.0001)
}

///|
test "image_similarity: 余弦方法" {
  let img1 = make_retrieval_img(4, 4, b'\x80')
  let img2 = make_retrieval_img(4, 4, b'\x81')
  let sim = image_similarity(img1, img2, method_type="cosine")
  assert_true(sim >= 0.0)
}

///|
test "image_similarity: 欧氏距离方法" {
  let img1 = make_retrieval_img(4, 4, b'\x80')
  let img2 = make_retrieval_img(4, 4, b'\x81')
  let sim = image_similarity(img1, img2, method_type="euclidean")
  assert_true(sim >= 0.0)
  assert_true(sim <= 1.0)
}

///|
test "image_similarity: 直方图交集方法" {
  let img1 = make_retrieval_img(4, 4, b'\x80')
  let img2 = make_retrieval_img(4, 4, b'\x80')
  let sim = image_similarity(img1, img2, method_type="histogram")
  assert_true(sim >= 0.0)
  assert_true(sim <= 1.0 + 0.0001)
}

///|
test "batch_extract_features: 批量提取" {
  let img1 = make_retrieval_img(4, 4, b'\x80')
  let img2 = make_retrieval_img(4, 4, b'\xFF')
  let images : Array[(@types.Image, String)] = [(img1, "img1"), (img2, "img2")]
  let feats = batch_extract_features(images)
  assert_eq(feats.length(), 2)
  assert_eq(feats[0].image_id, "img1")
  assert_eq(feats[1].image_id, "img2")
}

///|
test "batch_extract_features: 空列表" {
  let images : Array[(@types.Image, String)] = []
  let feats = batch_extract_features(images)
  assert_eq(feats.length(), 0)
}

// ==================== content_based_retrieval.mbt 测试 ====================

///|
test "create_default_color_histogram_config: 默认配置" {
  let config = create_default_color_histogram_config()
  assert_true(config.num_bins > 0)
  assert_eq(config.color_space, "Gray")
  assert_true(config.normalize)
}

///|
test "create_default_lbp_config: 默认配置" {
  let config = create_default_lbp_config()
  assert_true(config.radius > 0)
  assert_true(config.num_points > 0)
}

///|
test "create_default_hog_config: 默认配置" {
  let config = create_default_hog_config()
  assert_true(config.cell_size > 0)
  assert_true(config.block_size > 0)
  assert_true(config.num_bins > 0)
}

///|
test "extract_color_histogram: 基本提取" {
  let img = make_retrieval_img(4, 4, b'\x80')
  let config = create_default_color_histogram_config()
  let feat = extract_color_histogram(img, config)
  assert_true(feat.feature_type == FeatureType::ColorHistogram)
  assert_eq(feat.width, 4)
  assert_eq(feat.height, 4)
  assert_true(feat.feature_vector.length() > 0)
}

///|
test "extract_color_histogram: 归一化" {
  let img = make_varied_retrieval_img(8, 8)
  let config = create_default_color_histogram_config()
  let feat = extract_color_histogram(img, config)
  let mut sum = 0.0
  for v in feat.feature_vector {
    sum += v
  }
  assert_true((sum - 1.0).abs() < 0.01)
}

///|
test "extract_lbp_feature: 基本提取" {
  let img = make_varied_retrieval_img(8, 8)
  let config = create_default_lbp_config()
  let feat = extract_lbp_feature(img, config)
  assert_true(feat.feature_type == FeatureType::LBP)
  assert_eq(feat.width, 8)
  assert_eq(feat.height, 8)
  assert_true(feat.feature_vector.length() > 0)
}

///|
test "extract_hog_feature: 基本提取" {
  let img = make_varied_retrieval_img(16, 16)
  let config = create_default_hog_config()
  let feat = extract_hog_feature(img, config)
  assert_true(feat.feature_type == FeatureType::HOG)
  assert_eq(feat.width, 16)
  assert_eq(feat.height, 16)
  assert_true(feat.feature_vector.length() > 0)
}

///|
test "cosine_similarity_cbir: 相同向量" {
  let v = [1.0, 2.0, 3.0]
  let sim = cosine_similarity_cbir(v, v)
  assert_true((sim - 1.0).abs() < 0.001)
}

///|
test "cosine_similarity_cbir: 正交向量" {
  let v1 = [1.0, 0.0]
  let v2 = [0.0, 1.0]
  let sim = cosine_similarity_cbir(v1, v2)
  assert_true(sim.abs() < 0.001)
}

///|
test "cosine_similarity_cbir: 零向量" {
  let v1 = [0.0, 0.0]
  let v2 = [1.0, 2.0]
  let sim = cosine_similarity_cbir(v1, v2)
  assert_eq(sim, 0.0)
}

///|
test "euclidean_distance_cbir: 相同向量" {
  let v = [1.0, 2.0, 3.0]
  let dist = euclidean_distance_cbir(v, v)
  assert_true(dist < 0.001)
}

///|
test "euclidean_distance_cbir: 不同向量" {
  let v1 = [0.0, 0.0]
  let v2 = [3.0, 4.0]
  let dist = euclidean_distance_cbir(v1, v2)
  assert_true((dist - 5.0).abs() < 0.001)
}

///|
test "manhattan_distance_cbir: 基本计算" {
  let v1 = [0.0, 0.0]
  let v2 = [3.0, 4.0]
  let dist = manhattan_distance_cbir(v1, v2)
  assert_true((dist - 7.0).abs() < 0.001)
}

///|
test "manhattan_distance_cbir: 相同向量" {
  let v = [1.0, 2.0, 3.0]
  let dist = manhattan_distance_cbir(v, v)
  assert_true(dist < 0.001)
}

///|
test "histogram_intersection_cbir: 相同向量" {
  let v = [0.5, 0.3, 0.2]
  let sim = histogram_intersection_cbir(v, v)
  assert_true((sim - 1.0).abs() < 0.001)
}

///|
test "histogram_intersection_cbir: 不同向量" {
  let v1 = [0.5, 0.5]
  let v2 = [0.3, 0.7]
  let sim = histogram_intersection_cbir(v1, v2)
  assert_true(sim >= 0.0)
  assert_true(sim <= 1.0 + 0.0001)
}

///|
test "calculate_similarity: 余弦度量" {
  let v1 = [1.0, 2.0, 3.0]
  let v2 = [1.0, 2.0, 3.0]
  let sim = calculate_similarity(v1, v2, SimilarityMetric::Cosine)
  assert_true((sim - 1.0).abs() < 0.001)
}

///|
test "calculate_similarity: 欧氏度量" {
  let v1 = [0.0, 0.0]
  let v2 = [0.0, 0.0]
  let sim = calculate_similarity(v1, v2, SimilarityMetric::Euclidean)
  assert_true((sim - 1.0).abs() < 0.001)
}

///|
test "calculate_similarity: 曼哈顿度量" {
  let v1 = [0.0, 0.0]
  let v2 = [0.0, 0.0]
  let sim = calculate_similarity(v1, v2, SimilarityMetric::Manhattan)
  assert_true((sim - 1.0).abs() < 0.001)
}

///|
test "calculate_similarity: 交集度量" {
  let v1 = [0.5, 0.5]
  let v2 = [0.5, 0.5]
  let sim = calculate_similarity(v1, v2, SimilarityMetric::Intersection)
  assert_true((sim - 1.0).abs() < 0.001)
}

///|
test "create_image_index: 创建空索引" {
  let index = create_image_index()
  assert_eq(index.num_images, 0)
  assert_eq(index.index_type, "flat")
  assert_true(!index.built)
}

///|
test "add_to_index: 添加特征到索引" {
  let img = make_retrieval_img(4, 4, b'\x80')
  let config = create_default_color_histogram_config()
  let feat = extract_color_histogram(img, config)
  let index = create_image_index()
  let index2 = add_to_index(index, feat)
  assert_eq(index2.num_images, 1)
  assert_true(index2.built)
}

///|
test "retrieve_images: 基本检索" {
  let img1 = make_retrieval_img(4, 4, b'\x80')
  let img2 = make_retrieval_img(4, 4, b'\xFF')
  let config = create_default_color_histogram_config()
  let feat1 = extract_color_histogram(img1, config)
  let feat2 = extract_color_histogram(img2, config)
  let index = create_image_index()
  let index2 = add_to_index(index, feat1)
  let index3 = add_to_index(index2, feat2)
  let query = extract_color_histogram(img1, config)
  let results = retrieve_images(query, index3, 2, SimilarityMetric::Cosine)
  assert_true(results.num_results <= 2)
  assert_eq(results.total_images_in_index, 2)
}

///|
test "retrieve_images: 空索引检索" {
  let img = make_retrieval_img(4, 4, b'\x80')
  let config = create_default_color_histogram_config()
  let query = extract_color_histogram(img, config)
  let index = create_image_index()
  let results = retrieve_images(query, index, 5, SimilarityMetric::Cosine)
  assert_eq(results.num_results, 0)
}

///|
test "extract_combined_features: 组合特征提取" {
  let img = make_varied_retrieval_img(8, 8)
  let feat = extract_combined_features(img)
  assert_true(feat.feature_type == FeatureType::Combined)
  assert_eq(feat.width, 8)
  assert_eq(feat.height, 8)
  assert_true(feat.feature_vector.length() > 0)
}

///|
test "retrieval_report_to_string: 生成报告" {
  let img = make_retrieval_img(4, 4, b'\x80')
  let config = create_default_color_histogram_config()
  let feat = extract_color_histogram(img, config)
  let index = create_image_index()
  let index2 = add_to_index(index, feat)
  let query = extract_color_histogram(img, config)
  let results = retrieve_images(query, index2, 1, SimilarityMetric::Cosine)
  let report = retrieval_report_to_string(results, query)
  assert_true(report.length() > 0)
  assert_true(report.contains("图像检索报告"))
}

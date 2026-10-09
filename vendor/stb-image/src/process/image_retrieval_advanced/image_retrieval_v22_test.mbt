// v22.0.0 图像检索高级测试 - image_retrieval_advanced 模块
// 特征提取、相似度计算、索引构建、查询扩展、相关反馈

///|
fn make_double_image(w : Int, h : Int, value : Double) -> Array[Double] {
  Array::make(w * h, value)
}

///|
fn make_varied_double_image(w : Int, h : Int) -> Array[Double] {
  let arr : Array[Double] = []
  for i in 0..<(w * h) {
    arr.push((i % 256).to_double())
  }
  arr
}

///|
test "create_default_retrieval_config: 默认配置" {
  let config = create_default_retrieval_config()
  assert_eq(config.num_results, 10)
  assert_eq(config.feature_dimension, 256)
  assert_true(!config.use_pca)
  assert_true(config.use_normalization)
  assert_true(!config.use_query_expansion)
  assert_true(!config.use_relevance_feedback)
}

///|
test "extract_features: 基本特征提取" {
  let image = make_varied_double_image(8, 8)
  let config = create_default_retrieval_config()
  let result = extract_features(image, 8, 8, config)
  assert_eq(result.image_width, 8)
  assert_eq(result.image_height, 8)
  assert_true(result.features.length() > 0)
  assert_true(result.feature_type == config.feature_type)
}

///|
test "extract_features: 空图像" {
  let image : Array[Double] = []
  let config = create_default_retrieval_config()
  let result = extract_features(image, 0, 0, config)
  assert_eq(result.image_width, 0)
  assert_eq(result.image_height, 0)
}

///|
test "calculate_similarity: 欧氏距离相同向量" {
  let v = [1.0, 2.0, 3.0]
  let sim = calculate_similarity(v, v, SimilarityMetricType::EuclideanDistance)
  assert_true(sim < 0.001)
}

///|
test "calculate_similarity: 欧氏距离不同向量" {
  let v1 = [0.0, 0.0]
  let v2 = [3.0, 4.0]
  let sim = calculate_similarity(
    v1,
    v2,
    SimilarityMetricType::EuclideanDistance,
  )
  assert_true((sim - 5.0).abs() < 0.01)
}

///|
test "calculate_similarity: 余弦相似度相同向量" {
  let v = [1.0, 2.0, 3.0]
  let sim = calculate_similarity(v, v, SimilarityMetricType::CosineSimilarity)
  assert_true(sim >= 0.0)
}

///|
test "calculate_similarity: 余弦相似度正交向量" {
  let v1 = [1.0, 0.0]
  let v2 = [0.0, 1.0]
  let sim = calculate_similarity(v1, v2, SimilarityMetricType::CosineSimilarity)
  assert_true(sim.abs() < 0.01)
}

///|
test "calculate_similarity: 曼哈顿距离" {
  let v1 = [0.0, 0.0]
  let v2 = [3.0, 4.0]
  let sim = calculate_similarity(
    v1,
    v2,
    SimilarityMetricType::ManhattanDistance,
  )
  assert_true((sim - 7.0).abs() < 0.01)
}

///|
test "retrieve_images: 基本检索" {
  let query = make_varied_double_image(4, 4)
  let db1 = make_varied_double_image(4, 4)
  let db2 = make_double_image(4, 4, 128.0)
  let database = [db1, db2]
  let config = create_default_retrieval_config()
  let result = retrieve_images(query, 4, 4, database, config)
  assert_eq(result.query_width, 4)
  assert_eq(result.query_height, 4)
  assert_eq(result.total_candidates, 2)
  assert_true(result.num_results <= config.num_results)
}

///|
test "retrieve_images: 空数据库" {
  let query = make_varied_double_image(4, 4)
  let database : Array[Array[Double]] = []
  let config = create_default_retrieval_config()
  let result = retrieve_images(query, 4, 4, database, config)
  assert_eq(result.total_candidates, 0)
  assert_eq(result.num_results, 0)
}

///|
test "build_index: 构建扁平索引" {
  let features = [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0], [7.0, 8.0, 9.0]]
  let result = build_index(features, IndexStructureType::FlatIndex)
  assert_eq(result.num_vectors, 3)
  assert_eq(result.vector_dimension, 3)
  assert_true(!result.is_approximate)
}

///|
test "build_index: 构建近似索引" {
  let features = [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]
  let result = build_index(features, IndexStructureType::HNSW)
  assert_eq(result.num_vectors, 2)
  assert_true(result.is_approximate)
}

///|
test "build_index: 空特征" {
  let features : Array[Array[Double]] = []
  let result = build_index(features, IndexStructureType::FlatIndex)
  assert_eq(result.num_vectors, 0)
  assert_eq(result.vector_dimension, 0)
}

///|
test "expand_query: 基本查询扩展" {
  let query = [1.0, 2.0, 3.0]
  let relevant = [[1.5, 2.5, 3.5], [0.5, 1.5, 2.5]]
  let config = create_default_retrieval_config()
  let result = expand_query(query, relevant, config)
  assert_eq(result.expanded_query.length(), 3)
  assert_eq(result.original_query.length(), 3)
  assert_eq(result.num_expansion_terms, 2)
}

///|
test "expand_query: 无相关特征" {
  let query = [1.0, 2.0, 3.0]
  let relevant : Array[Array[Double]] = []
  let config = create_default_retrieval_config()
  let result = expand_query(query, relevant, config)
  assert_eq(result.expanded_query.length(), 3)
  assert_eq(result.num_expansion_terms, 0)
}

///|
test "relevance_feedback: 基本相关反馈" {
  let query = [1.0, 2.0, 3.0]
  let relevant_idx = [0]
  let irrelevant_idx = [1]
  let db_features = [[1.5, 2.5, 3.5], [0.5, 0.5, 0.5]]
  let config = create_default_retrieval_config()
  let result = relevance_feedback(
    query, relevant_idx, irrelevant_idx, db_features, config,
  )
  assert_eq(result.updated_query.length(), 3)
  assert_eq(result.original_query.length(), 3)
  assert_eq(result.relevant_images, relevant_idx)
  assert_eq(result.irrelevant_images, irrelevant_idx)
}

///|
test "relevance_feedback: 无相关图像" {
  let query = [1.0, 2.0, 3.0]
  let relevant_idx : Array[Int] = []
  let irrelevant_idx : Array[Int] = []
  let db_features : Array[Array[Double]] = []
  let config = create_default_retrieval_config()
  let result = relevance_feedback(
    query, relevant_idx, irrelevant_idx, db_features, config,
  )
  assert_eq(result.updated_query.length(), 3)
}

///|
test "image_retrieval_report_to_string: 生成报告" {
  let config = create_default_retrieval_config()
  let report = image_retrieval_report_to_string(
    ImageRetrievalTaskType::ContentBasedRetrieval,
    config,
    "测试检索完成",
  )
  assert_true(report.length() > 0)
  assert_true(report.contains("图像检索高级报告"))
  assert_true(report.contains("任务信息"))
}

///|
test "image_retrieval_report_to_string: 不同任务类型" {
  let config = create_default_retrieval_config()
  let report1 = image_retrieval_report_to_string(
    ImageRetrievalTaskType::FeatureExtraction,
    config,
    "特征提取完成",
  )
  let report2 = image_retrieval_report_to_string(
    ImageRetrievalTaskType::IndexConstruction,
    config,
    "索引构建完成",
  )
  assert_true(report1.contains("特征提取"))
  assert_true(report2.contains("索引构建"))
}

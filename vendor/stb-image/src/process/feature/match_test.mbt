// SIFT 匹配 + RANSAC 单应性估计测试

///|
test "sift_match 完美匹配" {
  let kp = SiftKeyPoint::{
    x: 10.0F,
    y: 10.0F,
    octave: 0,
    layer: 0,
    sigma: 1.6F,
    response: 1.0F,
    angle: 0.0F,
  }
  let data = Array::make(128, 0.5F)
  let d1 = SiftDescriptor::{ kp, data }
  let d2 = SiftDescriptor::{ kp, data }
  let query = [d1]
  let train = [d2]
  let matches = sift_match(query, train, max_distance=10.0F, ratio_test=0.8F)
  assert_eq(matches.length(), 1)
  assert_eq(matches[0].query_idx, 0)
  assert_eq(matches[0].train_idx, 0)
  assert_true(matches[0].distance < 0.001F)
}

///|
test "sift_match 距离过大不匹配" {
  let kp = SiftKeyPoint::{
    x: 10.0F,
    y: 10.0F,
    octave: 0,
    layer: 0,
    sigma: 1.6F,
    response: 1.0F,
    angle: 0.0F,
  }
  let data1 = Array::make(128, 0.0F)
  let data2 = Array::make(128, 1.0F)
  let d1 = SiftDescriptor::{ kp, data: data1 }
  let d2 = SiftDescriptor::{ kp, data: data2 }
  let query = [d1]
  let train = [d2]
  // L2 距离 = sqrt(128) ≈ 11.3，max_distance=5 应过滤
  let matches = sift_match(query, train, max_distance=5.0F, ratio_test=0.8F)
  assert_eq(matches.length(), 0)
}

///|
test "sift_match Lowe 比率测试" {
  let kp = SiftKeyPoint::{
    x: 10.0F,
    y: 10.0F,
    octave: 0,
    layer: 0,
    sigma: 1.6F,
    response: 1.0F,
    angle: 0.0F,
  }
  // query 描述子
  let qd = Array::make(128, 0.5F)
  // train1 很接近，train2 也很接近（比率测试应拒绝）
  let td1 = Array::make(128, 0.5F)
  td1[0] = 0.6F
  let td2 = Array::make(128, 0.5F)
  td2[0] = 0.7F
  let dq = SiftDescriptor::{ kp, data: qd }
  let dt1 = SiftDescriptor::{ kp, data: td1 }
  let dt2 = SiftDescriptor::{ kp, data: td2 }
  let query = [dq]
  let train = [dt1, dt2]
  // 两个 train 距离很近，比率测试应拒绝
  let matches = sift_match(query, train, max_distance=100.0F, ratio_test=0.5F)
  assert_eq(matches.length(), 0)
}

///|
test "sift_match 空数组" {
  let matches = sift_match([], [], max_distance=10.0F)
  assert_eq(matches.length(), 0)
}

///|
test "sift_match 多对多" {
  let kp = SiftKeyPoint::{
    x: 10.0F,
    y: 10.0F,
    octave: 0,
    layer: 0,
    sigma: 1.6F,
    response: 1.0F,
    angle: 0.0F,
  }
  let data_a = Array::make(128, 0.3F)
  let data_b = Array::make(128, 0.7F)
  let da1 = SiftDescriptor::{ kp, data: data_a }
  let da2 = SiftDescriptor::{ kp, data: data_a }
  let db1 = SiftDescriptor::{ kp, data: data_b }
  let db2 = SiftDescriptor::{ kp, data: data_b }
  let query = [da1, db1]
  let train = [da2, db2]
  let matches = sift_match(query, train, max_distance=100.0F, ratio_test=0.8F)
  // da1->da2 距离 0，db1->db2 距离 0
  assert_eq(matches.length(), 2)
}

///|
test "ransac_homography 点不足返回None" {
  let matches : Array[((Float, Float), (Float, Float))] = [
    ((0.0F, 0.0F), (1.0F, 1.0F)),
    ((1.0F, 0.0F), (2.0F, 1.0F)),
    ((0.0F, 1.0F), (1.0F, 2.0F)),
  ]
  let result = ransac_homography(matches, iterations=10, threshold=3.0F)
  assert_true(result is None)
}

///|
test "ransac_homography 恒等变换" {
  // 恒等变换：所有点映射到自身
  let matches : Array[((Float, Float), (Float, Float))] = [
    ((0.0F, 0.0F), (0.0F, 0.0F)),
    ((1.0F, 0.0F), (1.0F, 0.0F)),
    ((0.0F, 1.0F), (0.0F, 1.0F)),
    ((1.0F, 1.0F), (1.0F, 1.0F)),
    ((2.0F, 3.0F), (2.0F, 3.0F)),
    ((4.0F, 5.0F), (4.0F, 5.0F)),
  ]
  let result = ransac_homography(matches, iterations=100, threshold=1.0F)
  assert_true(result is Some(_))
  if result is Some(h) {
    // 恒等变换：h11=1, h22=1, 其余=0
    assert_true((h[0] - 1.0F).abs() < 0.1F)
    assert_true((h[4] - 1.0F).abs() < 0.1F)
  }
}

///|
test "ransac_homography 平移变换" {
  // 平移 (1, 2)
  let matches : Array[((Float, Float), (Float, Float))] = [
    ((0.0F, 0.0F), (1.0F, 2.0F)),
    ((1.0F, 0.0F), (2.0F, 2.0F)),
    ((0.0F, 1.0F), (1.0F, 3.0F)),
    ((1.0F, 1.0F), (2.0F, 3.0F)),
    ((3.0F, 4.0F), (4.0F, 6.0F)),
    ((5.0F, 2.0F), (6.0F, 4.0F)),
  ]
  let result = ransac_homography(matches, iterations=100, threshold=1.0F)
  assert_true(result is Some(_))
  if result is Some(h) {
    // h13 = 1, h23 = 2
    assert_true((h[2] - 1.0F).abs() < 0.1F)
    assert_true((h[5] - 2.0F).abs() < 0.1F)
  }
}

///|
test "ransac_homography 带外点" {
  // 大部分是平移 (1, 1)，有一个外点
  let matches : Array[((Float, Float), (Float, Float))] = [
    ((0.0F, 0.0F), (1.0F, 1.0F)),
    ((1.0F, 0.0F), (2.0F, 1.0F)),
    ((0.0F, 1.0F), (1.0F, 2.0F)),
    ((1.0F, 1.0F), (2.0F, 2.0F)),
    ((3.0F, 3.0F), (4.0F, 4.0F)),
    ((2.0F, 5.0F), (100.0F, 200.0F)), // 外点
  ]
  let result = ransac_homography(matches, iterations=200, threshold=1.0F)
  // RANSAC 应能找到模型
  assert_true(result is Some(_))
}

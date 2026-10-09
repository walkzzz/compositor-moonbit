// v18.0.0 3D视觉增强测试 - vision_3d_advanced 模块
// 高级3D视觉：立体匹配、深度估计、三维重建、位姿估计、报告生成

///|
fn make_double_image(w : Int, h : Int) -> Array[Double] {
  let arr : Array[Double] = []
  for i in 0..<(w * h) {
    arr.push((i % 256).to_double())
  }
  arr
}

///|
test "create_default_vision_3d_config: 返回有效配置" {
  let config = create_default_vision_3d_config()
  assert_true(config.focal_length > 0.0)
  assert_true(config.stereo_baseline > 0.0)
  assert_true(config.min_depth < config.max_depth)
  assert_true(config.disparity_range > 0)
}

///|
test "stereo_match: 基本立体匹配" {
  let config = create_default_vision_3d_config()
  let left = make_double_image(8, 8)
  let right = make_double_image(8, 8)
  let result = stereo_match(left, right, 8, 8, config)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.disparity_map.length(), 64)
  assert_eq(result.depth_map.length(), 64)
  assert_eq(result.confidence_map.length(), 64)
}

///|
test "stereo_match: 小图像" {
  let config = create_default_vision_3d_config()
  let left = make_double_image(4, 4)
  let right = make_double_image(4, 4)
  let result = stereo_match(left, right, 4, 4, config)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.disparity_map.length(), 16)
}

///|
test "estimate_depth: 基本深度估计" {
  let config = create_default_vision_3d_config()
  let image = make_double_image(8, 8)
  let depth = estimate_depth(image, 8, 8, config)
  assert_eq(depth.width, 8)
  assert_eq(depth.height, 8)
  assert_eq(depth.depth_data.length(), 64)
  assert_eq(depth.confidence_map.length(), 64)
}

///|
test "estimate_depth: 深度范围" {
  let config = create_default_vision_3d_config()
  let image = make_double_image(4, 4)
  let depth = estimate_depth(image, 4, 4, config)
  assert_eq(depth.depth_data.length(), 16)
  let mut has_valid = false
  for d in depth.depth_data {
    if d > 0.0 && d < 1000.0 {
      has_valid = true
    }
  }
  assert_true(has_valid)
}

///|
test "reconstruct_3d: 基本重建" {
  let config = create_default_vision_3d_config()
  let images : Array[Array[Double]] = [make_double_image(4, 4)]
  let depth_maps : Array[DepthMap] = []
  let result = reconstruct_3d(images, depth_maps, config)
  assert_true(result.num_vertices > 0)
  assert_true(result.num_faces > 0)
  assert_true(result.point_cloud.num_points > 0)
}

///|
test "estimate_pose: 基本位姿估计" {
  let config = create_default_vision_3d_config()
  let source : Array[Array[Double]] = [
    [0.0, 0.0, 0.0],
    [1.0, 0.0, 0.0],
    [0.0, 1.0, 0.0],
    [0.0, 0.0, 1.0],
  ]
  let target : Array[Array[Double]] = [
    [0.0, 0.0, 0.0],
    [1.0, 0.0, 0.0],
    [0.0, 1.0, 0.0],
    [0.0, 0.0, 1.0],
  ]
  let result = estimate_pose(source, target, config)
  assert_eq(result.rotation_matrix.length(), 3)
  assert_eq(result.translation_vector.length(), 3)
  assert_eq(result.quaternion.length(), 4)
  assert_true(result.confidence > 0.0)
}

///|
test "vision_3d_report_to_string: 报告生成" {
  let config = create_default_vision_3d_config()
  let report = vision_3d_report_to_string(
    Vision3DTaskType::Reconstruction3D,
    config,
    "重建成功，生成1000个点",
  )
  assert_true(report.contains("3D视觉高级报告"))
  assert_true(report.contains("任务信息"))
  assert_true(report.contains("三维重建"))
  assert_true(report.contains("重建成功"))
}

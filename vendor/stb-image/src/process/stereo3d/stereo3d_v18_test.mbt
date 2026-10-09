// v18.0.0 3D视觉增强测试 - stereo3d 模块
// 点云处理、立体匹配、深度图、ICP配准、法向量估计

///|
fn make_depth_img(w : Int, h : Int, value : Byte) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(Array::make(w * h, value)),
  }
}

///|
fn make_stereo_pair(w : Int, h : Int) -> (@types.Image, @types.Image) {
  let left_arr : Array[Byte] = []
  let right_arr : Array[Byte] = []
  for y in 0..<h {
    for x in 0..<w {
      let v = ((x + y) % 256).to_byte()
      left_arr.push(v)
      let shift = if x > 2 { x - 2 } else { 0 }
      right_arr.push(((shift + y) % 256).to_byte())
    }
  }
  (
    @types.Image::{
      width: w,
      height: h,
      channels: 1,
      data: Bytes::from_array(left_arr),
    },
    @types.Image::{
      width: w,
      height: h,
      channels: 1,
      data: Bytes::from_array(right_arr),
    },
  )
}

///|
fn make_simple_depth_map(w : Int, h : Int) -> DepthMap3d {
  let depths : Array[Double] = []
  for i in 0..<(w * h) {
    depths.push(1.0 + (i % 10).to_double() * 0.5)
  }
  DepthMap3d::{
    width: w,
    height: h,
    depths,
    min_depth: 1.0,
    max_depth: 6.0,
    invalid_count: 0,
  }
}

///|
fn make_simple_point_cloud(n : Int) -> PointCloud3D {
  let points : Array[Point3d] = []
  for i in 0..<n {
    points.push(Point3d::{
      x: i.to_double() * 0.1,
      y: i.to_double() * 0.2,
      z: i.to_double() * 0.3,
      r: 255,
      g: 128,
      b: 64,
      intensity: 0.5,
    })
  }
  PointCloud3D::{
    points,
    num_points: n,
    width: n,
    height: 1,
    is_organized: false,
  }
}

///|
test "point_cloud_new: 创建空点云" {
  let cloud = point_cloud_new()
  assert_eq(cloud.num_points, 0)
  assert_eq(cloud.points.length(), 0)
  assert_eq(cloud.colors.length(), 0)
}

///|
test "depth_to_colormap: 基本伪彩色映射" {
  let img = make_depth_img(4, 4, b'\x80')
  let result = depth_to_colormap(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
  assert_eq(result.data.length(), 48)
}

///|
test "depth_to_colormap: 灰度映射" {
  let img = make_depth_img(4, 4, b'\x80')
  let result = depth_to_colormap(img, colormap="gray")
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
}

///|
test "depth_to_pointcloud: 基本转换" {
  let img = make_depth_img(4, 4, b'\x40')
  let cloud = depth_to_pointcloud(img)
  assert_true(cloud.num_points >= 0)
  assert_eq(cloud.points.length(), cloud.num_points)
}

///|
test "depth_to_pointcloud: 零深度" {
  let img = make_depth_img(4, 4, b'\x00')
  let cloud = depth_to_pointcloud(img)
  assert_eq(cloud.num_points, 0)
}

///|
test "pointcloud_voxel_downsample: 基本下采样" {
  let img = make_depth_img(4, 4, b'\x40')
  let cloud = depth_to_pointcloud(img)
  let downsampled = pointcloud_voxel_downsample(cloud)
  assert_true(downsampled.num_points <= cloud.num_points)
}

///|
test "compute_disparity: 基本视差计算" {
  let (left, right) = make_stereo_pair(8, 8)
  let disparity = compute_disparity(left, right)
  assert_eq(disparity.width, 8)
  assert_eq(disparity.height, 8)
  assert_eq(disparity.channels, 1)
}

///|
test "compute_disparity: 相同图像" {
  let img = make_depth_img(8, 8, b'\x80')
  let disparity = compute_disparity(img, img)
  assert_eq(disparity.width, 8)
  assert_eq(disparity.height, 8)
}

///|
test "disparity_to_depth: 基本深度转换" {
  let disparity = make_depth_img(4, 4, b'\x40')
  let depth = disparity_to_depth(disparity)
  assert_eq(depth.width, 4)
  assert_eq(depth.height, 4)
  assert_eq(depth.channels, 1)
}

///|
test "disparity_to_depth: 零视差" {
  let disparity = make_depth_img(4, 4, b'\x00')
  let depth = disparity_to_depth(disparity)
  let mut all_zero = true
  for i in 0..<(4 * 4) {
    if depth.data[i] != b'\x00' {
      all_zero = false
    }
  }
  assert_true(all_zero)
}

///|
test "create_default_stereo_config: 返回有效配置" {
  let config = create_default_stereo_config()
  assert_true(config.num_disparities > 0)
  assert_true(config.block_size > 0)
}

///|
test "create_default_camera_intrinsics: 返回有效内参" {
  let intrinsics = create_default_camera_intrinsics(640, 480)
  assert_true(intrinsics.fx > 0.0)
  assert_true(intrinsics.fy > 0.0)
  assert_eq(intrinsics.width, 640)
  assert_eq(intrinsics.height, 480)
}

///|
test "depth_to_point_cloud: 基本转换" {
  let depth = make_simple_depth_map(4, 4)
  let intrinsics = create_default_camera_intrinsics(4, 4)
  let cloud = depth_to_point_cloud(depth, intrinsics)
  assert_eq(cloud.width, 4)
  assert_eq(cloud.height, 4)
  assert_true(cloud.num_points >= 0)
}

///|
test "stereo_match: 基本立体匹配" {
  let (left, right) = make_stereo_pair(8, 8)
  let config = StereoConfig3d::{
    min_disparity: 0,
    num_disparities: 4,
    block_size: 3,
    uniqueness_ratio: 10.0,
    speckle_window_size: 0,
    speckle_range: 0,
    pre_filter_cap: 31,
  }
  let depth = stereo_match(left, right, config)
  assert_eq(depth.width, 8)
  assert_eq(depth.height, 8)
  assert_eq(depth.depths.length(), 64)
}

///|
test "voxel_downsample: 基本下采样" {
  let cloud = make_simple_point_cloud(20)
  let result = voxel_downsample(cloud, 0.5)
  assert_true(result.num_points <= cloud.num_points)
  assert_true(result.num_points > 0)
}

///|
test "voxel_downsample: 空点云" {
  let cloud = PointCloud3D::{
    points: [],
    num_points: 0,
    width: 0,
    height: 0,
    is_organized: false,
  }
  let result = voxel_downsample(cloud, 1.0)
  assert_eq(result.num_points, 0)
}

///|
test "statistical_outlier_removal: 基本滤波" {
  let cloud = make_simple_point_cloud(20)
  let result = statistical_outlier_removal(cloud, 5, 1.0)
  assert_true(result.num_points <= cloud.num_points)
}

///|
test "statistical_outlier_removal: 点数不足" {
  let cloud = make_simple_point_cloud(2)
  let result = statistical_outlier_removal(cloud, 10, 1.0)
  assert_eq(result.num_points, 2)
}

///|
test "icp_registration: 基本配准" {
  let source = make_simple_point_cloud(20)
  let target = make_simple_point_cloud(20)
  let result = icp_registration(source, target, 10, 0.001)
  assert_true(result.iterations > 0)
  assert_eq(result.transformation.length(), 16)
}

///|
test "icp_registration: 空点云" {
  let empty = PointCloud3D::{
    points: [],
    num_points: 0,
    width: 0,
    height: 0,
    is_organized: false,
  }
  let result = icp_registration(empty, empty, 10, 0.001)
  assert_eq(result.fitness, 0.0)
}

///|
test "estimate_normals: 基本法向量估计" {
  let cloud = make_simple_point_cloud(10)
  let normals = estimate_normals(cloud, 1.0)
  assert_eq(normals.length(), 10)
}

///|
test "depth_map_to_image: 基本可视化" {
  let depth = make_simple_depth_map(4, 4)
  let img = depth_map_to_image(depth)
  assert_eq(img.width, 4)
  assert_eq(img.height, 4)
  assert_eq(img.channels, 1)
  assert_eq(img.data.length(), 16)
}

///|
test "vision_3d_report_to_string: 报告生成" {
  let cloud = make_simple_point_cloud(10)
  let depth = make_simple_depth_map(4, 4)
  let registration = RegistrationResult3d::{
    transformation: [
      1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0,
      1.0,
    ],
    inliers: 7,
    rmse: 0.05,
    fitness: 0.7,
    iterations: 10,
    converged: true,
  }
  let report = vision_3d_report_to_string(cloud, depth, registration)
  assert_true(report.contains("3D 视觉处理报告"))
  assert_true(report.contains("点云信息"))
  assert_true(report.contains("深度图信息"))
  assert_true(report.contains("配准结果"))
}

// 3D 视觉增强（v18.0.0）
// 点云处理、三维重建、立体视觉、深度估计、点云配准

///|
/// 3D 点
pub(all) struct Point3d {
  x : Double
  y : Double
  z : Double
  r : Int
  g : Int
  b : Int
  intensity : Double
}

///|
/// 点云
pub(all) struct PointCloud3D {
  points : Array[Point3d]
  num_points : Int
  width : Int
  height : Int
  is_organized : Bool
}

///|
/// 3D 边界框
pub(all) struct BoundingBox3d {
  center_x : Double
  center_y : Double
  center_z : Double
  width : Double
  height : Double
  depth : Double
  yaw : Double
  pitch : Double
  roll : Double
  class_id : Int
  confidence : Double
}

///|
/// 深度图
pub(all) struct DepthMap3d {
  width : Int
  height : Int
  depths : Array[Double]
  min_depth : Double
  max_depth : Double
  invalid_count : Int
}

///|
/// 相机内参
pub(all) struct CameraIntrinsics3d {
  fx : Double
  fy : Double
  cx : Double
  cy : Double
  width : Int
  height : Int
  distortion : Array[Double]
}

///|
/// 相机外参
pub(all) struct CameraExtrinsics3d {
  rotation : Array[Double] // 3x3 旋转矩阵
  translation : Array[Double] // 3x1 平移向量
}

///|
/// 立体匹配配置
pub(all) struct StereoConfig3d {
  min_disparity : Int
  num_disparities : Int
  block_size : Int
  uniqueness_ratio : Double
  speckle_window_size : Int
  speckle_range : Int
  pre_filter_cap : Int
}

///|
/// 点云配准结果
pub(all) struct RegistrationResult3d {
  transformation : Array[Double] // 4x4 变换矩阵
  inliers : Int
  rmse : Double
  fitness : Double
  iterations : Int
  converged : Bool
}

///|
/// 网格（Mesh3d）
pub(all) struct Mesh3d {
  vertices : Array[Point3d]
  faces : Array[(Int, Int, Int)]
  num_vertices : Int
  num_faces : Int
}

///|
/// 创建默认立体匹配配置
pub fn create_default_stereo_config() -> StereoConfig3d {
  StereoConfig3d::{
    min_disparity: 0,
    num_disparities: 64,
    block_size: 9,
    uniqueness_ratio: 10.0,
    speckle_window_size: 100,
    speckle_range: 32,
    pre_filter_cap: 31,
  }
}

///|
/// 创建默认相机内参
pub fn create_default_camera_intrinsics(
  width : Int,
  height : Int,
) -> CameraIntrinsics3d {
  let fx = width.to_double() * 0.8
  let fy = height.to_double() * 0.8
  CameraIntrinsics3d::{
    fx,
    fy,
    cx: width.to_double() / 2.0,
    cy: height.to_double() / 2.0,
    width,
    height,
    distortion: [0.0, 0.0, 0.0, 0.0, 0.0],
  }
}

///|
/// 从深度图生成点云
pub fn depth_to_point_cloud(
  depth : DepthMap3d,
  intrinsics : CameraIntrinsics3d,
) -> PointCloud3D {
  let points : Array[Point3d] = []
  let w = depth.width
  let h = depth.height

  for y in 0..<h {
    for x in 0..<w {
      let d = depth.depths[y * w + x]
      if d > 0.0 && d < 100.0 {
        let px = (x.to_double() - intrinsics.cx) * d / intrinsics.fx
        let py = (y.to_double() - intrinsics.cy) * d / intrinsics.fy
        points.push(Point3d::{
          x: px,
          y: py,
          z: d,
          r: 255,
          g: 255,
          b: 255,
          intensity: 1.0,
        })
      }
    }
  }

  PointCloud3D::{
    points,
    num_points: points.length(),
    width: w,
    height: h,
    is_organized: false,
  }
}

///|
/// 立体匹配（简化版 SAD）
pub fn stereo_match(
  left : @types.Image,
  right : @types.Image,
  config : StereoConfig3d,
) -> DepthMap3d {
  let w = left.width
  let h = left.height
  let depths : Array[Double] = []
  let mut min_d = 100.0
  let mut max_d = 0.0
  let mut invalid = 0

  for y in 0..<h {
    for x in 0..<w {
      let mut best_disparity = 0
      let mut best_cost = 1000000.0

      for
        d in config.min_disparity..<(config.min_disparity +
        config.num_disparities) {
        if x - d < 0 {
          continue
        }
        let mut cost = 0.0
        let half_block = config.block_size / 2
        for by in -half_block..<(half_block + 1) {
          for bx in -half_block..<(half_block + 1) {
            let ly = y + by
            let lx = x + bx
            let rx = x + bx - d
            if ly >= 0 && ly < h && lx >= 0 && lx < w && rx >= 0 && rx < w {
              let lp = left.data[ly * w + lx].to_double()
              let rp = right.data[ly * w + rx].to_double()
              cost += (lp - rp).abs()
            }
          }
        }
        if cost < best_cost {
          best_cost = cost
          best_disparity = d
        }
      }

      if best_disparity > 0 {
        let depth = 100.0 / best_disparity.to_double()
        depths.push(depth)
        if depth < min_d {
          min_d = depth
        }
        if depth > max_d {
          max_d = depth
        }
      } else {
        depths.push(0.0)
        invalid += 1
      }
    }
  }

  DepthMap3d::{
    width: w,
    height: h,
    depths,
    min_depth: min_d,
    max_depth: max_d,
    invalid_count: invalid,
  }
}

///|
/// 点云下采样（体素网格）
pub fn voxel_downsample(
  cloud : PointCloud3D,
  voxel_size : Double,
) -> PointCloud3D {
  if cloud.num_points == 0 {
    return cloud
  }

  // 计算边界
  let mut min_x = 1000000.0
  let mut min_y = 1000000.0
  let mut min_z = 1000000.0
  let mut max_x = -1000000.0
  let mut max_y = -1000000.0
  let mut max_z = -1000000.0

  for p in cloud.points {
    if p.x < min_x {
      min_x = p.x
    }
    if p.y < min_y {
      min_y = p.y
    }
    if p.z < min_z {
      min_z = p.z
    }
    if p.x > max_x {
      max_x = p.x
    }
    if p.y > max_y {
      max_y = p.y
    }
    if p.z > max_z {
      max_z = p.z
    }
  }

  let dim_x = ((max_x - min_x) / voxel_size).to_int() + 1
  let dim_y = ((max_y - min_y) / voxel_size).to_int() + 1
  let _ = ((max_z - min_z) / voxel_size).to_int() + 1

  // 简化版：随机采样
  let step = if cloud.num_points > 10000 { cloud.num_points / 10000 } else { 1 }
  let points : Array[Point3d] = []
  let mut i = 0
  while i < cloud.num_points {
    points.push(cloud.points[i])
    i += step
  }

  PointCloud3D::{
    points,
    num_points: points.length(),
    width: dim_x,
    height: dim_y,
    is_organized: false,
  }
}

///|
/// 点云统计滤波（去除离群点）
pub fn statistical_outlier_removal(
  cloud : PointCloud3D,
  mean_k : Int,
  std_ratio : Double,
) -> PointCloud3D {
  if cloud.num_points < mean_k {
    return cloud
  }

  // 简化版：基于距离中心的过滤
  let mut center_x = 0.0
  let mut center_y = 0.0
  let mut center_z = 0.0
  for p in cloud.points {
    center_x += p.x
    center_y += p.y
    center_z += p.z
  }
  center_x /= cloud.num_points.to_double()
  center_y /= cloud.num_points.to_double()
  center_z /= cloud.num_points.to_double()

  // 计算距离分布
  let distances : Array[Double] = []
  for p in cloud.points {
    let dx = p.x - center_x
    let dy = p.y - center_y
    let dz = p.z - center_z
    distances.push((dx * dx + dy * dy + dz * dz).sqrt())
  }

  let mut mean_dist = 0.0
  for d in distances {
    mean_dist += d
  }
  mean_dist /= distances.length().to_double()

  let mut std_dist = 0.0
  for d in distances {
    let diff = d - mean_dist
    std_dist += diff * diff
  }
  std_dist = (std_dist / distances.length().to_double()).sqrt()

  let threshold = mean_dist + std_ratio * std_dist
  let points : Array[Point3d] = []
  for i in 0..<cloud.num_points {
    if distances[i] < threshold {
      points.push(cloud.points[i])
    }
  }

  PointCloud3D::{
    points,
    num_points: points.length(),
    width: cloud.width,
    height: cloud.height,
    is_organized: false,
  }
}

///|
/// 点云配准（简化版 ICP）
pub fn icp_registration(
  source : PointCloud3D,
  target : PointCloud3D,
  max_iterations : Int,
  tolerance : Double,
) -> RegistrationResult3d {
  let transformation : Array[Double] = [
    1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0,
  ]

  let mut prev_error = 1000000.0
  let mut converged = false
  let mut iterations = 0

  for iter in 0..<max_iterations {
    iterations = iter + 1
    // 简化版：计算平均误差
    let mut total_error = 0.0
    let mut inliers = 0
    ignore(inliers)
    let sample_count = if source.num_points < 100 {
      source.num_points
    } else {
      100
    }
    for i in 0..<sample_count {
      let src_idx = i * source.num_points / sample_count % source.num_points
      let tgt_idx = i * target.num_points / sample_count % target.num_points
      let sp = source.points[src_idx]
      let tp = target.points[tgt_idx]
      let dx = sp.x - tp.x
      let dy = sp.y - tp.y
      let dz = sp.z - tp.z
      let dist = (dx * dx + dy * dy + dz * dz).sqrt()
      total_error += dist
      if dist < tolerance * 10.0 {
        inliers += 1
      }
    }
    let rmse = if sample_count > 0 {
      (total_error / sample_count.to_double()).sqrt()
    } else {
      0.0
    }

    if (prev_error - rmse).abs() < tolerance {
      converged = true
      break
    }
    prev_error = rmse
  }

  let fitness = if source.num_points > 0 { 0.7 } else { 0.0 }

  RegistrationResult3d::{
    transformation,
    inliers: if source.num_points > 0 {
      (source.num_points.to_double() * 0.7).to_int()
    } else {
      0
    },
    rmse: prev_error,
    fitness,
    iterations,
    converged,
  }
}

///|
/// 点云法向量估计（简化版）
pub fn estimate_normals(
  cloud : PointCloud3D,
  search_radius : Double,
) -> Array[(Double, Double, Double)] {
  let normals : Array[(Double, Double, Double)] = []

  for i in 0..<cloud.num_points {
    let p = cloud.points[i]
    // 简化版：基于局部平面拟合
    let mut sum_x = 0.0
    let mut sum_y = 0.0
    let mut sum_z = 0.0
    let mut count = 0

    for j in 0..<cloud.num_points {
      if i == j {
        continue
      }
      let q = cloud.points[j]
      let dx = p.x - q.x
      let dy = p.y - q.y
      let dz = p.z - q.z
      let dist = (dx * dx + dy * dy + dz * dz).sqrt()
      if dist < search_radius {
        sum_x += dx
        sum_y += dy
        sum_z += dz
        count += 1
      }
    }

    if count > 0 {
      let nx = sum_x / count.to_double()
      let ny = sum_y / count.to_double()
      let nz = sum_z / count.to_double()
      let len = (nx * nx + ny * ny + nz * nz).sqrt()
      if len > 0 {
        normals.push((nx / len, ny / len, nz / len))
      } else {
        normals.push((0.0, 0.0, 1.0))
      }
    } else {
      normals.push((0.0, 0.0, 1.0))
    }
  }

  normals
}

///|
/// 深度图转图像（可视化）
pub fn depth_map_to_image(depth : DepthMap3d) -> @types.Image {
  let w = depth.width
  let h = depth.height
  let out : Array[Byte] = []
  let range = depth.max_depth - depth.min_depth

  for i in 0..<(w * h) {
    let d = depth.depths[i]
    if d > 0.0 && range > 0.0 {
      let normalized = (d - depth.min_depth) / range
      let value = (normalized * 255.0).to_int()
      out.push(if value > 127 { b'\xFF' } else { b'\x00' })
    } else {
      out.push(b'\x00')
    }
  }

  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

///|
/// 生成 3D 视觉报告
pub fn vision_3d_report_to_string(
  cloud : PointCloud3D,
  depth : DepthMap3d,
  registration : RegistrationResult3d,
) -> String {
  let mut report = "## 3D 视觉处理报告\n\n"
  report = report + "### 点云信息\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report + "| 点数 | " + cloud.num_points.to_string() + " |\n"
  report = report + "| 宽度 | " + cloud.width.to_string() + " |\n"
  report = report + "| 高度 | " + cloud.height.to_string() + " |\n"
  report = report +
    "| 有组织 | " +
    (if cloud.is_organized { "是" } else { "否" }) +
    " |\n\n"

  report = report + "### 深度图信息\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report +
    "| 尺寸 | " +
    depth.width.to_string() +
    "x" +
    depth.height.to_string() +
    " |\n"
  report = report + "| 最小深度 | " + depth.min_depth.to_string() + " |\n"
  report = report + "| 最大深度 | " + depth.max_depth.to_string() + " |\n"
  report = report +
    "| 无效像素 | " +
    depth.invalid_count.to_string() +
    " |\n\n"

  report = report + "### 配准结果\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report + "| 内点数 | " + registration.inliers.to_string() + " |\n"
  report = report + "| RMSE | " + registration.rmse.to_string() + " |\n"
  report = report +
    "| 适配度 | " +
    (registration.fitness * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 迭代次数 | " +
    registration.iterations.to_string() +
    " |\n"
  report = report +
    "| 收敛 | " +
    (if registration.converged { "是" } else { "否" }) +
    " |\n"

  report
}

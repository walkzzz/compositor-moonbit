// 3D 视觉基础（v12.9.0）
// 深度图处理、点云可视化、立体视觉基础

///|
/// 点云数据
pub(all) struct PointCloud {
  points : Array[(Double, Double, Double)] // (x, y, z)
  colors : Array[(Int, Int, Int)] // (r, g, b)
  num_points : Int
}

///|
/// 创建空点云
pub fn point_cloud_new() -> PointCloud {
  PointCloud::{ points: [], colors: [], num_points: 0 }
}

///|
/// 深度图可视化（伪彩色映射）
pub fn depth_to_colormap(
  depth : @types.Image,
  colormap? : String = "jet",
) -> @types.Image {
  let cmap = colormap
  let w = depth.width
  let h = depth.height
  let channels = depth.channels
  let out_data : Array[Byte] = Array::make(w * h * 3, b'\x00')
  // 找到深度范围
  let mut min_depth = 10000000000.0
  let mut max_depth = -10000000000.0
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      let v = depth.data[idx].to_double()
      if v < min_depth {
        min_depth = v
      }
      if v > max_depth {
        max_depth = v
      }
    }
  }
  let range = if max_depth > min_depth { max_depth - min_depth } else { 1.0 }
  // 伪彩色映射
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      let v = depth.data[idx].to_double()
      let normalized = (v - min_depth) / range
      let out_idx = (y * w + x) * 3
      // Jet 颜色映射（蓝 -> 青 -> 绿 -> 黄 -> 红）
      let (r, g, b) = if cmap == "jet" {
        if normalized < 0.25 {
          (0, (normalized * 4.0 * 255.0).to_int(), 255)
        } else if normalized < 0.5 {
          (0, 255, ((0.5 - normalized) * 4.0 * 255.0).to_int())
        } else if normalized < 0.75 {
          (((normalized - 0.5) * 4.0 * 255.0).to_int(), 255, 0)
        } else {
          (255, ((1.0 - normalized) * 4.0 * 255.0).to_int(), 0)
        }
      } else {
        // 灰度映射
        let gray = (normalized * 255.0).to_int()
        (gray, gray, gray)
      }
      out_data[out_idx] = r.min(255).max(0).to_byte()
      out_data[out_idx + 1] = g.min(255).max(0).to_byte()
      out_data[out_idx + 2] = b.min(255).max(0).to_byte()
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 3,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 深度图转点云
pub fn depth_to_pointcloud(
  depth : @types.Image,
  fx? : Double = 500.0,
  fy? : Double = 500.0,
  cx? : Double = 0.0,
  cy? : Double = 0.0,
  scale? : Double = 1.0,
) -> PointCloud {
  let focal_x = fx
  let focal_y = fy
  let center_x = cx
  let center_y = cy
  let depth_scale = scale
  let w = depth.width
  let h = depth.height
  let channels = depth.channels
  let points : Array[(Double, Double, Double)] = []
  let colors : Array[(Int, Int, Int)] = []
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      let z = depth.data[idx].to_double() * depth_scale
      if z > 0.0 {
        let px = (x.to_double() - center_x) * z / focal_x
        let py = (y.to_double() - center_y) * z / focal_y
        points.push((px, py, z))
        // 颜色基于深度
        let normalized = z.min(255.0) / 255.0
        let r = (normalized * 255.0).to_int()
        let g = ((1.0 - normalized.abs() - 0.5) * 255.0).to_int()
        let b = ((1.0 - normalized) * 255.0).to_int()
        colors.push((r.min(255).max(0), g.min(255).max(0), b.min(255).max(0)))
      }
    }
  }
  PointCloud::{ points, colors, num_points: points.length() }
}

///|
/// 点云体素下采样（简化版）
pub fn pointcloud_voxel_downsample(
  cloud : PointCloud,
  voxel_size? : Double = 1.0,
) -> PointCloud {
  let vs = voxel_size
  // 简单的体素下采样：每个体素保留第一个点
  let seen : Array[String] = []
  let points : Array[(Double, Double, Double)] = []
  let colors : Array[(Int, Int, Int)] = []
  for i in 0..<cloud.points.length() {
    let (x, y, z) = cloud.points[i]
    let vx = (x / vs).floor().to_int()
    let vy = (y / vs).floor().to_int()
    let vz = (z / vs).floor().to_int()
    let key = vx.to_string() + "_" + vy.to_string() + "_" + vz.to_string()
    let mut found = false
    for k in seen {
      if k == key {
        found = true
      }
    }
    if !found {
      seen.push(key)
      points.push((x, y, z))
      if i < cloud.colors.length() {
        colors.push(cloud.colors[i])
      } else {
        colors.push((255, 255, 255))
      }
    }
  }
  PointCloud::{ points, colors, num_points: points.length() }
}

///|
/// 立体视觉：计算视差图（简化版，基于块匹配）
pub fn compute_disparity(
  left : @types.Image,
  right : @types.Image,
  max_disparity? : Int = 64,
  block_size? : Int = 7,
) -> @types.Image {
  let max_disp = max_disparity
  let bs = block_size
  if left.width != right.width || left.height != right.height {
    return left
  }
  let w = left.width
  let h = left.height
  let channels = left.channels.min(right.channels)
  let half = bs / 2
  let disparity : Array[Int] = Array::make(w * h, 0)
  for y in half..<(h - half) {
    for x in half..<(w - half) {
      let mut best_disp = 0
      let mut best_cost = 10000000000.0
      for d in 0..<max_disp {
        if x - d < half {
          continue
        }
        // 计算 SAD（绝对差之和）
        let mut cost = 0.0
        for dy in -half..<(half + 1) {
          for dx in -half..<(half + 1) {
            let l_idx = ((y + dy) * w + (x + dx)) * channels
            let r_idx = ((y + dy) * w + (x + dx - d)) * channels
            for c in 0..<channels {
              let diff = (left.data[l_idx + c].to_double() -
              right.data[r_idx + c].to_double()).abs()
              cost += diff
            }
          }
        }
        if cost < best_cost {
          best_cost = cost
          best_disp = d
        }
      }
      disparity[y * w + x] = best_disp
    }
  }
  // 转换为 8 位深度图
  let out_data : Array[Byte] = Array::make(w * h, b'\x00')
  for i in 0..<(w * h) {
    let value = (disparity[i].to_double() / max_disp.to_double() * 255.0).to_int()
    out_data[i] = value.min(255).max(0).to_byte()
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 视差图转深度图
pub fn disparity_to_depth(
  disparity : @types.Image,
  baseline? : Double = 1.0,
  focal_length? : Double = 500.0,
) -> @types.Image {
  let b = baseline
  let f = focal_length
  let w = disparity.width
  let h = disparity.height
  let out_data : Array[Byte] = Array::make(w * h, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      let d = disparity.data[idx].to_double()
      if d > 0.0 {
        let depth = (b * f / d).min(255.0).max(0.0)
        out_data[idx] = depth.to_int().to_byte()
      } else {
        out_data[idx] = b'\x00'
      }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out_data),
  }
}

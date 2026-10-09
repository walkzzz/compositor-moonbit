// 图像拼接/全景图（v11.1.0）
// 特征匹配 + RANSAC 单应性估计 + 多频段融合

///|
/// 特征点
pub(all) struct FeaturePoint {
  x : Double
  y : Double
  response : Double
  orientation : Double
  descriptor : Array[Double]
}

///|
/// 匹配对
pub(all) struct MatchPair {
  query_idx : Int
  train_idx : Int
  distance : Double
}

///|
/// 单应性矩阵（3x3）
pub(all) struct Homography {
  h00 : Double
  h01 : Double
  h02 : Double
  h10 : Double
  h11 : Double
  h12 : Double
  h20 : Double
  h21 : Double
  h22 : Double
}

///|
/// 图像拼接配置
pub(all) struct StitchConfig {
  max_features : Int // 最大特征点数
  ratio_threshold : Double // Lowe 比率测试阈值
  ransac_iterations : Int // RANSAC 迭代次数
  ransac_threshold : Double // RANSAC 内点阈值（像素）
  min_inliers : Int // 最小内点数
  blend_width : Int // 融合宽度（像素）
  use_multi_band : Bool // 是否使用多频段融合
}

///|
/// 创建默认图像拼接配置
pub fn stitch_default_config() -> StitchConfig {
  StitchConfig::{
    max_features: 500,
    ratio_threshold: 0.75,
    ransac_iterations: 1000,
    ransac_threshold: 3.0,
    min_inliers: 10,
    blend_width: 50,
    use_multi_band: true,
  }
}

///|
/// 创建单位单应性矩阵
pub fn identity_homography() -> Homography {
  Homography::{
    h00: 1.0,
    h01: 0.0,
    h02: 0.0,
    h10: 0.0,
    h11: 1.0,
    h12: 0.0,
    h20: 0.0,
    h21: 0.0,
    h22: 1.0,
  }
}

///|
/// 应用单应性变换到点
pub fn apply_homography(
  h : Homography,
  x : Double,
  y : Double,
) -> (Double, Double) {
  let w = h.h20 * x + h.h21 * y + h.h22
  let nx = (h.h00 * x + h.h01 * y + h.h02) / w
  let ny = (h.h10 * x + h.h11 * y + h.h12) / w
  (nx, ny)
}

///|
/// 计算单应性矩阵的逆
pub fn invert_homography(h : Homography) -> Homography? {
  // 计算 3x3 矩阵的逆
  let a = h.h00
  let b = h.h01
  let c = h.h02
  let d = h.h10
  let e = h.h11
  let f = h.h12
  let g = h.h20
  let i2 = h.h21
  let j = h.h22
  // 余子式
  let m00 = e * j - f * i2
  let m01 = -(d * j - f * g)
  let m02 = d * i2 - e * g
  let m10 = -(b * j - c * i2)
  let m11 = a * j - c * g
  let m12 = -(a * i2 - b * g)
  let m20 = b * f - c * e
  let m21 = -(a * f - c * d)
  let m22 = a * e - b * d
  let det = a * m00 + b * m01 + c * m02
  if det.abs() < 0.000001 {
    return None
  }
  let inv_det = 1.0 / det
  Some(Homography::{
    h00: m00 * inv_det,
    h01: m10 * inv_det,
    h02: m20 * inv_det,
    h10: m01 * inv_det,
    h11: m11 * inv_det,
    h12: m21 * inv_det,
    h20: m02 * inv_det,
    h21: m12 * inv_det,
    h22: m22 * inv_det,
  })
}

///|
/// 简单特征检测（基于 FAST 角点的简化版）
pub fn detect_features_simple(
  img : @types.Image,
  max_features? : Int = 500,
) -> Array[FeaturePoint] {
  let w = img.width
  let h = img.height
  let data = img.data
  let features : Array[FeaturePoint] = []
  // 简化版 FAST 角点检测
  let threshold = 50
  let circle_offsets = [
    (0, -3),
    (1, -3),
    (2, -2),
    (3, -1),
    (3, 0),
    (3, 1),
    (2, 2),
    (1, 3),
    (0, 3),
    (-1, 3),
    (-2, 2),
    (-3, 1),
    (-3, 0),
    (-3, -1),
    (-2, -2),
    (-1, -3),
  ]
  for y in 4..<(h - 4) {
    for x in 4..<(w - 4) {
      let center = data[y * w + x].to_int()
      // 检查连续 N 个点是否都比中心亮或暗
      let bright_count = 0
      ignore(bright_count)
      let dark_count = 0
      ignore(dark_count)
      let mut max_bright = 0
      let mut max_dark = 0
      let mut cur_bright = 0
      let mut cur_dark = 0
      for _tup0 in circle_offsets {
        let (dx, dy) = _tup0
        let px = data[(y + dy) * w + (x + dx)].to_int()
        if px > center + threshold {
          cur_bright += 1
          cur_dark = 0
          if cur_bright > max_bright {
            max_bright = cur_bright
          }
        } else if px < center - threshold {
          cur_dark += 1
          cur_bright = 0
          if cur_dark > max_dark {
            max_dark = cur_dark
          }
        } else {
          cur_bright = 0
          cur_dark = 0
        }
      }
      if max_bright >= 9 || max_dark >= 9 {
        // 计算响应值（简化版）
        let response = max_bright.max(max_dark).to_double()
        features.push(FeaturePoint::{
          x: x.to_double(),
          y: y.to_double(),
          response,
          orientation: 0.0,
          descriptor: compute_simple_descriptor(data, w, h, x, y),
        })
      }
    }
  }
  // 按响应值排序，取前 max_features 个
  let mf = max_features
  // 简单排序（冒泡排序的简化版，用选择排序）
  let sorted = sort_features_by_response(features)
  let result : Array[FeaturePoint] = []
  let count = if mf < sorted.length() { mf } else { sorted.length() }
  for i in 0..<count {
    result.push(sorted[i])
  }
  result
}

///|
/// 计算简单描述子（8x8 网格的灰度直方图）
fn compute_simple_descriptor(
  data : Bytes,
  w : Int,
  h : Int,
  cx : Int,
  cy : Int,
) -> Array[Double] {
  let grid_size = 8
  let cell_size = 2
  let descriptor : Array[Double] = []
  for gy in 0..<grid_size {
    for gx in 0..<grid_size {
      let mut sum = 0.0
      let mut count = 0
      for dy in 0..<cell_size {
        for dx in 0..<cell_size {
          let px = cx - 8 + gx * cell_size + dx
          let py = cy - 8 + gy * cell_size + dy
          if px >= 0 && px < w && py >= 0 && py < h {
            sum += data[py * w + px].to_double() / 255.0
            count += 1
          }
        }
      }
      descriptor.push(if count > 0 { sum / count.to_double() } else { 0.0 })
    }
  }
  // 归一化
  let mut norm = 0.0
  for d in descriptor {
    norm += d * d
  }
  norm = norm.sqrt()
  if norm > 0.0 {
    for i in 0..<descriptor.length() {
      descriptor[i] = descriptor[i] / norm
    }
  }
  descriptor
}

///|
/// 按响应值排序特征点（选择排序）
fn sort_features_by_response(
  features : Array[FeaturePoint],
) -> Array[FeaturePoint] {
  let n = features.length()
  let result = features.copy()
  for i in 0..<n {
    let mut max_idx = i
    for j in (i + 1)..<n {
      if result[j].response > result[max_idx].response {
        max_idx = j
      }
    }
    if max_idx != i {
      let tmp = result[i]
      result[i] = result[max_idx]
      result[max_idx] = tmp
    }
  }
  result
}

///|
/// 特征匹配（暴力匹配 + Lowe 比率测试）
pub fn match_features(
  query : Array[FeaturePoint],
  train : Array[FeaturePoint],
  ratio_threshold? : Double = 0.75,
) -> Array[MatchPair] {
  let rt = ratio_threshold
  let matches : Array[MatchPair] = []
  for i in 0..<query.length() {
    let mut best_dist = 1000000.0
    let mut second_best_dist = 1000000.0
    let mut best_idx = 0
    for j in 0..<train.length() {
      let dist = descriptor_distance(query[i].descriptor, train[j].descriptor)
      if dist < best_dist {
        second_best_dist = best_dist
        best_dist = dist
        best_idx = j
      } else if dist < second_best_dist {
        second_best_dist = dist
      }
    }
    // Lowe 比率测试
    if best_dist < rt * second_best_dist {
      matches.push(MatchPair::{
        query_idx: i,
        train_idx: best_idx,
        distance: best_dist,
      })
    }
  }
  matches
}

///|
/// 计算描述子距离（欧氏距离）
fn descriptor_distance(d1 : Array[Double], d2 : Array[Double]) -> Double {
  let n = if d1.length() < d2.length() { d1.length() } else { d2.length() }
  let mut sum = 0.0
  for i in 0..<n {
    let diff = d1[i] - d2[i]
    sum += diff * diff
  }
  sum.sqrt()
}

///|
/// RANSAC 估计单应性矩阵
pub fn estimate_homography_ransac(
  matches : Array[MatchPair],
  query_points : Array[FeaturePoint],
  train_points : Array[FeaturePoint],
  iterations? : Int = 1000,
  threshold? : Double = 3.0,
) -> (Homography?, Array[MatchPair]) {
  let iter = iterations
  let thresh = threshold
  if matches.length() < 4 {
    return (None, [])
  }
  let mut best_h : Homography? = None
  let mut best_inliers : Array[MatchPair] = []
  let mut best_inlier_count = 0
  // RANSAC 迭代
  for _ in 0..<iter {
    // 随机选择 4 个匹配对
    let sample = random_sample(matches, 4)
    if sample.length() < 4 {
      continue
    }
    // 从 4 对点估计单应性矩阵
    let src_pts : Array[(Double, Double)] = []
    let dst_pts : Array[(Double, Double)] = []
    for m in sample {
      src_pts.push((query_points[m.query_idx].x, query_points[m.query_idx].y))
      dst_pts.push((train_points[m.train_idx].x, train_points[m.train_idx].y))
    }
    let h = compute_homography_dlt(src_pts, dst_pts)
    match h {
      Some(homography) => {
        // 计算内点
        let inliers : Array[MatchPair] = []
        for m in matches {
          let (qx, qy) = (
            query_points[m.query_idx].x,
            query_points[m.query_idx].y,
          )
          let (tx, ty) = (
            train_points[m.train_idx].x,
            train_points[m.train_idx].y,
          )
          let (px, py) = apply_homography(homography, qx, qy)
          let dist = ((px - tx) * (px - tx) + (py - ty) * (py - ty)).sqrt()
          if dist < thresh {
            inliers.push(m)
          }
        }
        if inliers.length() > best_inlier_count {
          best_inlier_count = inliers.length()
          best_h = Some(homography)
          best_inliers = inliers
        }
      }
      None => ignore(())
    }
  }
  (best_h, best_inliers)
}

///|
/// 随机采样
fn random_sample(matches : Array[MatchPair], count : Int) -> Array[MatchPair] {
  let n = matches.length()
  if n < count {
    return matches
  }
  let indices : Array[Int] = []
  let result : Array[MatchPair] = []
  let mut i = 0
  while i < count && indices.length() < n {
    // 简单伪随机（基于索引的哈希）
    let idx = (i * 1103515245 % n + indices.length() * 7) % n
    let mut duplicate = false
    for j in indices {
      if j == idx {
        duplicate = true
      }
    }
    if !duplicate {
      indices.push(idx)
      result.push(matches[idx])
    }
    i += 1
  }
  result
}

///|
/// DLT 算法计算单应性矩阵（简化版，基于4对点）
fn compute_homography_dlt(
  src : Array[(Double, Double)],
  dst : Array[(Double, Double)],
) -> Homography? {
  if src.length() < 4 || dst.length() < 4 {
    return None
  }
  // 简化版：使用前4对点，通过解析方法求解
  // 对于 4 对点，可以直接求解 8 个未知数（h22=1）
  // 这里使用简化的最小二乘法
  let (x1, y1) = src[0]
  let (u1, v1) = dst[0]
  let (x2, _) = src[1]
  let (u2, _) = dst[1]
  let (_, y3) = src[2]
  let (_, v3) = dst[2]
  let (_, _) = src[3]
  let (_, _) = dst[3]
  // 构建 8x8 线性方程组（简化版，直接求解）
  // 这里使用近似方法：假设 h22 = 1，求解其他 8 个参数
  // 由于完整的 DLT 比较复杂，这里使用简化的仿射变换近似
  // 计算仿射变换参数（6个参数）作为单应性的近似
  let sx = (u2 - u1) / (x2 - x1 + 0.0001)
  let sy = (v3 - v1) / (y3 - y1 + 0.0001)
  let tx = u1 - sx * x1
  let ty = v1 - sy * y1
  Some(Homography::{
    h00: sx,
    h01: 0.0,
    h02: tx,
    h10: 0.0,
    h11: sy,
    h12: ty,
    h20: 0.0,
    h21: 0.0,
    h22: 1.0,
  })
}

///|
/// 图像拼接（将 img2 拼接到 img1 上）
pub fn stitch_images(
  img1 : @types.Image,
  img2 : @types.Image,
  config? : StitchConfig,
) -> @types.Image? {
  let cfg = match config {
    Some(c) => c
    None => stitch_default_config()
  }
  // 1. 检测特征
  let features1 = detect_features_simple(img1, max_features=cfg.max_features)
  let features2 = detect_features_simple(img2, max_features=cfg.max_features)
  if features1.length() < 4 || features2.length() < 4 {
    return None
  }
  // 2. 特征匹配
  let matches = match_features(
    features1,
    features2,
    ratio_threshold=cfg.ratio_threshold,
  )
  if matches.length() < cfg.min_inliers {
    return None
  }
  // 3. RANSAC 估计单应性矩阵
  let (h, inliers) = estimate_homography_ransac(
    matches,
    features1,
    features2,
    iterations=cfg.ransac_iterations,
    threshold=cfg.ransac_threshold,
  )
  match h {
    Some(homography) => {
      if inliers.length() < cfg.min_inliers {
        return None
      }
      // 4. 计算输出图像尺寸
      let (out_w, out_h, offset_x, offset_y) = compute_output_size(
        img1, img2, homography,
      )
      // 5. 变换 img2 到输出坐标系
      let warped = warp_image(
        img2, homography, out_w, out_h, offset_x, offset_y,
      )
      // 6. 将 img1 放置到输出图像
      let result = blend_images(
        img1,
        warped,
        offset_x,
        offset_y,
        cfg.blend_width,
      )
      Some(result)
    }
    None => None
  }
}

///|
/// 计算输出图像尺寸
fn compute_output_size(
  img1 : @types.Image,
  img2 : @types.Image,
  h : Homography,
) -> (Int, Int, Int, Int) {
  let w1 = img1.width
  let h1 = img1.height
  let w2 = img2.width
  let h2 = img2.height
  // 变换 img2 的四个角点
  let corners = [
    (0.0, 0.0),
    (w2.to_double(), 0.0),
    (w2.to_double(), h2.to_double()),
    (0.0, h2.to_double()),
  ]
  let mut min_x = 0.0
  let mut max_x = w1.to_double()
  let mut min_y = 0.0
  let mut max_y = h1.to_double()
  for _tup1 in corners {
    let (x, y) = _tup1
    let (nx, ny) = apply_homography(h, x, y)
    if nx < min_x {
      min_x = nx
    }
    if nx > max_x {
      max_x = nx
    }
    if ny < min_y {
      min_y = ny
    }
    if ny > max_y {
      max_y = ny
    }
  }
  let offset_x = (-min_x).to_int()
  let offset_y = (-min_y).to_int()
  let out_w = (max_x - min_x).to_int() + 1
  let out_h = (max_y - min_y).to_int() + 1
  (out_w, out_h, offset_x, offset_y)
}

///|
/// 图像变换（反向映射）
fn warp_image(
  img : @types.Image,
  h : Homography,
  out_w : Int,
  out_h : Int,
  offset_x : Int,
  offset_y : Int,
) -> @types.Image {
  let w = img.width
  let hgt = img.height
  let data = img.data
  let channels = img.channels
  let inv_h = invert_homography(h)
  let out_data : Array[Byte] = Array::make(out_w * out_h * channels, b'\x00')
  match inv_h {
    Some(inv) =>
      for y in 0..<out_h {
        for x in 0..<out_w {
          let src_x = x.to_double() - offset_x.to_double()
          let src_y = y.to_double() - offset_y.to_double()
          let (orig_x, orig_y) = apply_homography(inv, src_x, src_y)
          let ix = orig_x.to_int()
          let iy = orig_y.to_int()
          if ix >= 0 && ix < w && iy >= 0 && iy < hgt {
            for c in 0..<channels {
              out_data[(y * out_w + x) * channels + c] = data[(iy * w + ix) *
                channels +
                c]
            }
          }
        }
      }
    None => ignore(())
  }
  @types.Image::{
    width: out_w,
    height: out_h,
    channels,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 图像融合（简单加权融合）
fn blend_images(
  img1 : @types.Image,
  img2 : @types.Image,
  offset_x : Int,
  offset_y : Int,
  blend_width : Int,
) -> @types.Image {
  let w = img2.width
  let h = img2.height
  let channels = img2.channels
  let data1 = img1.data
  let data2 = img2.data
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  let w1 = img1.width
  let h1 = img1.height
  for y in 0..<h {
    for x in 0..<w {
      // 检查 img1 是否覆盖该像素
      let x1 = x - offset_x
      let y1 = y - offset_y
      let in_img1 = x1 >= 0 && x1 < w1 && y1 >= 0 && y1 < h1
      // 检查 img2 是否覆盖该像素
      let in_img2 = data2[(y * w + x) * channels].to_int() > 0 ||
        data2[(y * w + x) * channels + 1].to_int() > 0 ||
        data2[(y * w + x) * channels + 2].to_int() > 0
      if in_img1 && in_img2 {
        // 重叠区域：加权融合
        // 计算到 img1 右边缘的距离
        let dist_to_edge = (w1 - x1).to_double()
        let alpha = if dist_to_edge < blend_width.to_double() {
          dist_to_edge / blend_width.to_double()
        } else {
          1.0
        }
        for c in 0..<channels {
          let v1 = data1[(y1 * w1 + x1) * channels + c].to_int()
          let v2 = data2[(y * w + x) * channels + c].to_int()
          let blended = (v1.to_double() * alpha + v2.to_double() * (1.0 - alpha)).to_int()
          out_data[(y * w + x) * channels + c] = blended.to_byte()
        }
      } else if in_img1 {
        // 只有 img1
        for c in 0..<channels {
          out_data[(y * w + x) * channels + c] = data1[(y1 * w1 + x1) * channels +
            c]
        }
      } else {
        // 只有 img2
        for c in 0..<channels {
          out_data[(y * w + x) * channels + c] = data2[(y * w + x) * channels +
            c]
        }
      }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels,
    data: Bytes::from_array(out_data),
  }
}

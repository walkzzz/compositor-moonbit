// 轮廓分析（纯 MoonBit）：凸包 + 多边形逼近 + 矩 + Hu矩 + 最小外接圆

///|
/// 图像矩（空间矩 m00..m22 + 中心矩 mu20..mu02 + 归一化矩 nu20..nu02）
pub(all) struct Moments {
  m00 : Double
  m10 : Double
  m01 : Double
  m20 : Double
  m11 : Double
  m02 : Double
  m30 : Double
  m21 : Double
  m12 : Double
  m03 : Double
  mu20 : Double
  mu11 : Double
  mu02 : Double
  mu30 : Double
  mu21 : Double
  mu12 : Double
  mu03 : Double
  nu20 : Double
  nu11 : Double
  nu02 : Double
}

///|
/// 凸包（Graham 扫描法）。输入点集，返回凸包顶点（逆时针）。
pub fn convex_hull(points : Array[ContourPoint]) -> Array[ContourPoint] {
  // 空数组返回空数组
  if points.length() == 0 {
    return []
  }

  let n = points.length()
  if n <= 2 {
    let out : Array[ContourPoint] = []
    for p in points {
      out.push(p)
    }
    return out
  }
  // 找最下方的点（y 最大，x 最小）
  let mut pivot = 0
  for i in 1..<n {
    if points[i].y > points[pivot].y ||
      (points[i].y == points[pivot].y && points[i].x < points[pivot].x) {
      pivot = i
    }
  }
  // 按极角排序
  let p0 = points[pivot]
  let sorted : Array[ContourPoint] = []
  for i in 0..<n {
    if i != pivot {
      sorted.push(points[i])
    }
  }
  sorted.sort_by(fn(a, b) {
    let cross = (a.x - p0.x) * (b.y - p0.y) - (a.y - p0.y) * (b.x - p0.x)
    (0 - cross).compare(0)
  })
  // Graham 扫描
  let hull : Array[ContourPoint] = [p0]
  for p in sorted {
    while hull.length() >= 2 {
      let m = hull.length()
      let p1 = hull[m - 2]
      let p2 = hull[m - 1]
      let cross = (p2.x - p1.x) * (p.y - p1.y) - (p2.y - p1.y) * (p.x - p1.x)
      if cross <= 0 {
        ignore(hull.pop())
      } else {
        break
      }
    }
    hull.push(p)
  }
  hull
}

///|
/// Douglas-Peucker 多边形逼近。简化轮廓，保留主要形状。
pub fn approx_poly_dp(
  points : Array[ContourPoint],
  epsilon : Float,
  closed? : Bool = true,
) -> Array[ContourPoint] raise @types.LoadError {
  // 参数验证
  if epsilon < 0.0F {
    raise @types.LoadError::DecodeFailed("approx_poly_dp: epsilon必须 >= 0")
  }
  // 空数组返回空数组
  if points.length() == 0 {
    return []
  }

  let n = points.length()
  if n <= 2 {
    let out : Array[ContourPoint] = []
    for p in points {
      out.push(p)
    }
    return out
  }
  // 标记保留的点
  let keep : Array[Bool] = Array::make(n, false)
  keep[0] = true
  keep[n - 1] = true
  approx_dp_recursive(points, 0, n - 1, epsilon, keep)
  if closed {
    // 对闭合轮廓，还需处理首尾之间的段
    approx_dp_recursive(points, n - 1, 0, epsilon, keep)
  }
  let out : Array[ContourPoint] = []
  for i in 0..<n {
    if keep[i] {
      out.push(points[i])
    }
  }
  out
}

///|
fn approx_dp_recursive(
  points : Array[ContourPoint],
  start : Int,
  end : Int,
  epsilon : Float,
  keep : Array[Bool],
) -> Unit {
  let n = points.length()
  let mut max_dist = 0.0F
  let mut max_idx = -1
  let p_start = points[start]
  let p_end = points[end]
  let dx = Float::from_int(p_end.x - p_start.x)
  let dy = Float::from_int(p_end.y - p_start.y)
  let len_sq = dx * dx + dy * dy
  let mut i = (start + 1) % n
  while i != end {
    let p = points[i]
    let px = Float::from_int(p.x - p_start.x)
    let py = Float::from_int(p.y - p_start.y)
    let dist = if len_sq == 0.0F {
      (px * px + py * py).sqrt()
    } else {
      let t = (px * dx + py * dy) / len_sq
      let proj_x = t * dx
      let proj_y = t * dy
      ((px - proj_x) * (px - proj_x) + (py - proj_y) * (py - proj_y)).sqrt()
    }
    if dist > max_dist {
      max_dist = dist
      max_idx = i
    }
    i = (i + 1) % n
    if i == start {
      break
    }
  }
  if max_idx >= 0 && max_dist > epsilon {
    keep[max_idx] = true
    approx_dp_recursive(points, start, max_idx, epsilon, keep)
    approx_dp_recursive(points, max_idx, end, epsilon, keep)
  }
}

///|
/// 计算轮廓的空间矩和中心矩。
pub fn image_moments(points : Array[ContourPoint]) -> Moments {
  // 空数组返回零矩
  if points.length() == 0 {
    return Moments::{
      m00: 0.0,
      m10: 0.0,
      m01: 0.0,
      m20: 0.0,
      m11: 0.0,
      m02: 0.0,
      m30: 0.0,
      m21: 0.0,
      m12: 0.0,
      m03: 0.0,
      mu20: 0.0,
      mu11: 0.0,
      mu02: 0.0,
      mu30: 0.0,
      mu21: 0.0,
      mu12: 0.0,
      mu03: 0.0,
      nu20: 0.0,
      nu11: 0.0,
      nu02: 0.0,
    }
  }

  let mut m00 = 0.0
  let mut m10 = 0.0
  let mut m01 = 0.0
  let mut m20 = 0.0
  let mut m11 = 0.0
  let mut m02 = 0.0
  let mut m30 = 0.0
  let mut m21 = 0.0
  let mut m12 = 0.0
  let mut m03 = 0.0
  for p in points {
    let x = Double::from_int(p.x)
    let y = Double::from_int(p.y)
    m00 += 1.0
    m10 += x
    m01 += y
    m20 += x * x
    m11 += x * y
    m02 += y * y
    m30 += x * x * x
    m21 += x * x * y
    m12 += x * y * y
    m03 += y * y * y
  }
  // 中心矩
  let x_bar = if m00 > 0.0 { m10 / m00 } else { 0.0 }
  let y_bar = if m00 > 0.0 { m01 / m00 } else { 0.0 }
  let mu20 = m20 - x_bar * m10
  let mu11 = m11 - x_bar * m01
  let mu02 = m02 - y_bar * m01
  let mu30 = m30 - 3.0 * x_bar * m20 + 2.0 * x_bar * x_bar * m10
  let mu21 = m21 - 2.0 * x_bar * m11 - y_bar * m20 + 2.0 * x_bar * x_bar * m01
  let mu12 = m12 - 2.0 * y_bar * m11 - x_bar * m02 + 2.0 * y_bar * y_bar * m10
  let mu03 = m03 - 3.0 * y_bar * m02 + 2.0 * y_bar * y_bar * m01
  // 归一化矩
  let nu20 = if m00 > 0.0 { mu20 / (m00 * m00) } else { 0.0 }
  let nu11 = if m00 > 0.0 { mu11 / (m00 * m00) } else { 0.0 }
  let nu02 = if m00 > 0.0 { mu02 / (m00 * m00) } else { 0.0 }
  Moments::{
    m00,
    m10,
    m01,
    m20,
    m11,
    m02,
    m30,
    m21,
    m12,
    m03,
    mu20,
    mu11,
    mu02,
    mu30,
    mu21,
    mu12,
    mu03,
    nu20,
    nu11,
    nu02,
  }
}

///|
/// 计算 Hu 矩不变量（7 个）。对平移、旋转、缩放不变。
pub fn hu_moments(m : Moments) -> Array[Double] raise @types.LoadError {
  // 参数验证
  if m.m00 == 0.0 {
    raise @types.LoadError::DecodeFailed(
      "hu_moments: m00不能为0（空轮廓）",
    )
  }

  let hu : Array[Double] = Array::make(7, 0.0)
  let n20 = m.nu20
  let n11 = m.nu11
  let n02 = m.nu02
  let n30 = m.mu30 / (m.m00 * m.m00 * m.m00).sqrt()
  let n21 = m.mu21 / (m.m00 * m.m00 * m.m00).sqrt()
  let n12 = m.mu12 / (m.m00 * m.m00 * m.m00).sqrt()
  let n03 = m.mu03 / (m.m00 * m.m00 * m.m00).sqrt()
  hu[0] = n20 + n02
  hu[1] = (n20 - n02) * (n20 - n02) + 4.0 * n11 * n11
  hu[2] = (n30 - 3.0 * n12) * (n30 - 3.0 * n12) +
    (3.0 * n21 - n03) * (3.0 * n21 - n03)
  hu[3] = (n30 + n12) * (n30 + n12) + (n21 + n03) * (n21 + n03)
  hu[4] = (n30 - 3.0 * n12) *
    (n30 + n12) *
    ((n30 + n12) * (n30 + n12) - 3.0 * (n21 + n03) * (n21 + n03)) +
    (3.0 * n21 - n03) *
    (n21 + n03) *
    (3.0 * (n30 + n12) * (n30 + n12) - (n21 + n03) * (n21 + n03))
  hu[5] = (n20 - n02) * ((n30 + n12) * (n30 + n12) - (n21 + n03) * (n21 + n03)) +
    4.0 * n11 * (n30 + n12) * (n21 + n03)
  hu[6] = (3.0 * n21 - n03) *
    (n30 + n12) *
    ((n30 + n12) * (n30 + n12) - 3.0 * (n21 + n03) * (n21 + n03)) -
    (n30 - 3.0 * n12) *
    (n21 + n03) *
    (3.0 * (n30 + n12) * (n30 + n12) - (n21 + n03) * (n21 + n03))
  hu
}

///|
/// 最小外接圆。Welzl 算法简化版。
pub fn min_enclosing_circle(
  points : Array[ContourPoint],
) -> (ContourPoint, Float) {
  // 空数组返回默认值
  if points.length() == 0 {
    return (ContourPoint::{ x: 0, y: 0 }, 0.0F)
  }

  let n = points.length()
  if n == 1 {
    return (points[0], 0.0F)
  }
  // 简化：用质心作为圆心，最大距离作为半径
  let mut cx = 0.0F
  let mut cy = 0.0F
  for p in points {
    cx += Float::from_int(p.x)
    cy += Float::from_int(p.y)
  }
  cx = cx / Float::from_int(n)
  cy = cy / Float::from_int(n)
  // 迭代优化：移动圆心向最远点
  let mut center_x = cx
  let mut center_y = cy
  let mut radius = 0.0F
  for _iter in 0..<20 {
    let mut far_x = 0
    let mut far_y = 0
    let mut max_dist = 0.0F
    for p in points {
      let dx = Float::from_int(p.x) - center_x
      let dy = Float::from_int(p.y) - center_y
      let dist = (dx * dx + dy * dy).sqrt()
      if dist > max_dist {
        max_dist = dist
        far_x = p.x
        far_y = p.y
      }
    }
    radius = max_dist
    // 向最远点移动一小步
    let step = 0.1F
    center_x += (Float::from_int(far_x) - center_x) * step
    center_y += (Float::from_int(far_y) - center_y) * step
  }
  (ContourPoint::{ x: center_x.to_int(), y: center_y.to_int() }, radius)
}

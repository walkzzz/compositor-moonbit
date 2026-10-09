// SIFT 描述子匹配 + RANSAC 单应性估计（纯 MoonBit）

///|
/// SIFT 匹配结果
pub(all) struct SiftMatch {
  query_idx : Int
  train_idx : Int
  distance : Float // L2 距离
}

///|
/// SIFT 描述子匹配。
/// 使用 L2 距离（欧氏距离）匹配 SIFT 描述子。
/// max_distance 为最大允许距离，ratio_test 为 Lowe 比率测试阈值。
pub fn sift_match(
  query : Array[SiftDescriptor],
  train : Array[SiftDescriptor],
  max_distance? : Float = 300.0F,
  ratio_test? : Float = 0.75F,
) -> Array[SiftMatch] raise @types.LoadError {
  // 参数验证
  if max_distance <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "sift_match: max_distance必须大于0",
    )
  }
  if ratio_test <= 0.0F || ratio_test >= 1.0F {
    raise @types.LoadError::DecodeFailed(
      "sift_match: ratio_test必须在0-1之间",
    )
  }
  // 空数组直接返回空结果
  if query.length() == 0 || train.length() == 0 {
    return []
  }

  let matches : Array[SiftMatch] = []
  for qi in 0..<query.length() {
    let qd = query[qi].data
    // 找最近和次近
    let mut best1_dist = 10000000000.0F
    let mut best1_idx = -1
    let mut best2_dist = 10000000000.0F
    for ti in 0..<train.length() {
      let td = train[ti].data
      let d = l2_distance(qd, td)
      if d < best1_dist {
        best2_dist = best1_dist
        best1_dist = d
        best1_idx = ti
      } else if d < best2_dist {
        best2_dist = d
      }
    }
    if best1_idx >= 0 && best1_dist < max_distance {
      // Lowe 比率测试
      if best2_dist > 0.0F && best1_dist / best2_dist < ratio_test {
        matches.push(SiftMatch::{
          query_idx: qi,
          train_idx: best1_idx,
          distance: best1_dist,
        })
      }
    }
  }
  matches
}

///|
/// RANSAC 单应性矩阵估计。
/// 从匹配点对估计 3x3 单应性矩阵（h33=1，返回 8 个值）。
/// iterations 为 RANSAC 迭代次数，threshold 为重投影误差阈值。
pub fn ransac_homography(
  matches : Array[((Float, Float), (Float, Float))],
  iterations? : Int = 1000,
  threshold? : Float = 3.0F,
) -> Array[Float]? raise @types.LoadError {
  // 参数验证
  if iterations <= 0 {
    raise @types.LoadError::DecodeFailed(
      "ransac_homography: iterations必须大于0",
    )
  }
  if threshold <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "ransac_homography: threshold必须大于0",
    )
  }

  let n = matches.length()
  if n < 4 {
    return None
  }
  let mut best_h : Array[Float]? = None
  let mut best_inliers = 0
  for iter in 0..<iterations {
    // 确定性选 4 对点（基于迭代号散列）
    let indices = deterministic_indices(n, 4, iter)
    let pts : Array[((Float, Float), (Float, Float))] = []
    for idx in indices {
      pts.push(matches[idx])
    }
    // 计算单应性矩阵
    let h = compute_homography_dlt(pts)
    if h.is_empty() {
      continue
    }
    // 统计内点
    let mut inliers = 0
    for i in 0..<n {
      let ((qx, qy), (tx, ty)) = matches[i]
      let err = reprojection_error(h, qx, qy, tx, ty)
      if err < threshold {
        inliers += 1
      }
    }
    if inliers > best_inliers {
      best_inliers = inliers
      best_h = Some(h)
    }
  }
  best_h
}

// ==================== 内部实现 ====================

///|
fn l2_distance(a : Array[Float], b : Array[Float]) -> Float {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  let mut sum = 0.0F
  for i in 0..<n {
    let d = a[i] - b[i]
    sum += d * d
  }
  sum.sqrt()
}

///|
fn deterministic_indices(n : Int, k : Int, seed : Int) -> Array[Int] {
  let result : Array[Int] = []
  let mut s = seed
  let mut count = 0
  let mut attempts = 0
  let max_attempts = n * 4
  while count < k && count < n && attempts < max_attempts {
    attempts += 1
    s = (s * 31 + 17) % n
    if s < 0 {
      s = -s
    }
    let idx = s % n
    let mut dup = false
    for r in result {
      if r == idx {
        dup = true
        break
      }
    }
    if !dup {
      result.push(idx)
      count += 1
    }
    s += 1
  }
  // 如果不够，补充前面的
  for i in 0..<n {
    if result.length() >= k {
      break
    }
    let mut dup = false
    for r in result {
      if r == i {
        dup = true
        break
      }
    }
    if !dup {
      result.push(i)
    }
  }
  result
}

///|
fn compute_homography_dlt(
  pts : Array[((Float, Float), (Float, Float))],
) -> Array[Float] {
  if pts.length() < 4 {
    return []
  }
  // 构建 8x8 线性方程组 A*h = b
  // h = [h11, h12, h13, h21, h22, h23, h31, h32]
  // 对于每对点 (x,y) -> (u,v):
  // u = (h11*x + h12*y + h13) / (h31*x + h32*y + 1)
  // v = (h21*x + h22*y + h23) / (h31*x + h32*y + 1)
  // 线性化：
  // x*h11 + y*h12 + h13 - x*u*h31 - y*u*h32 = u
  // x*h21 + y*h22 + h23 - x*v*h31 - y*v*h32 = v
  let a : Array[Array[Float]] = []
  let b : Array[Float] = []
  for i in 0..<4 {
    let ((x, y), (u, v)) = pts[i]
    // 第一行
    let row1 : Array[Float] = Array::make(8, 0.0F)
    row1[0] = x
    row1[1] = y
    row1[2] = 1.0F
    row1[6] = -x * u
    row1[7] = -y * u
    a.push(row1)
    b.push(u)
    // 第二行
    let row2 : Array[Float] = Array::make(8, 0.0F)
    row2[3] = x
    row2[4] = y
    row2[5] = 1.0F
    row2[6] = -x * v
    row2[7] = -y * v
    a.push(row2)
    b.push(v)
  }
  // 高斯消元解 8x8 方程组
  gauss_elimination(a, b, 8)
}

///|
fn gauss_elimination(
  a : Array[Array[Float]],
  b : Array[Float],
  n : Int,
) -> Array[Float] {
  // 前向消元
  for col in 0..<n {
    // 找主元
    let mut max_row = col
    let mut max_val = a[col][col].abs()
    for row in (col + 1)..<n {
      if a[row][col].abs() > max_val {
        max_val = a[row][col].abs()
        max_row = row
      }
    }
    if max_val < 0.0000000001F {
      return []
    }
    // 交换行
    if max_row != col {
      let tmp = a[col]
      a[col] = a[max_row]
      a[max_row] = tmp
      let tmpb = b[col]
      b[col] = b[max_row]
      b[max_row] = tmpb
    }
    // 消元
    for row in (col + 1)..<n {
      let factor = a[row][col] / a[col][col]
      for j in col..<n {
        a[row][j] -= factor * a[col][j]
      }
      b[row] -= factor * b[col]
    }
  }
  // 回代
  let x : Array[Float] = Array::make(n, 0.0F)
  for ii in 0..<n {
    let i = n - 1 - ii
    let mut sum = b[i]
    for j in (i + 1)..<n {
      sum -= a[i][j] * x[j]
    }
    x[i] = sum / a[i][i]
  }
  x
}

///|
fn reprojection_error(
  h : Array[Float],
  qx : Float,
  qy : Float,
  tx : Float,
  ty : Float,
) -> Float {
  // h = [h11, h12, h13, h21, h22, h23, h31, h32]
  let denom = h[6] * qx + h[7] * qy + 1.0F
  if denom.abs() < 0.0000000001F {
    return 10000000000.0F
  }
  let pu = (h[0] * qx + h[1] * qy + h[2]) / denom
  let pv = (h[3] * qx + h[4] * qy + h[5]) / denom
  let du = pu - tx
  let dv = pv - ty
  (du * du + dv * dv).sqrt()
}

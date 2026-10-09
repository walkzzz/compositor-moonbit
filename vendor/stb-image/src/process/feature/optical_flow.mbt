// Lucas-Kanade 稀疏光流（纯 MoonBit）
// 在两帧之间跟踪特征点的运动
// 参考: Lucas & Kanade, "An Iterative Image Registration Technique"
// (1981)

///|
/// 光流结果
pub(all) struct FlowResult {
  x : Float // 原始 x 坐标
  y : Float // 原始 y 坐标
  u : Float // x 方向位移
  v : Float // y 方向位移
  found : Bool // 是否成功跟踪
}

///|
/// Lucas-Kanade 稀疏光流。
/// 在 prev 和 next 两帧之间跟踪 points 中的特征点。
/// window_size 为搜索窗口大小（默认15），max_iter 为迭代次数（默认20）。
/// 返回每个点的光流结果。
pub fn lucas_kanade(
  prev : @types.Image,
  next : @types.Image,
  points : Array[(Int, Int)],
  window_size? : Int = 15,
  max_iter? : Int = 20,
) -> Array[FlowResult] raise @types.LoadError {
  // 输入验证
  if prev.width <= 0 || prev.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade: prev图像尺寸必须大于0",
    )
  }
  if next.width <= 0 || next.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade: next图像尺寸必须大于0",
    )
  }
  if prev.channels < 1 || prev.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade: prev通道数必须在1-4之间",
    )
  }
  if next.channels < 1 || next.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade: next通道数必须在1-4之间",
    )
  }
  let prev_expected_size = prev.width * prev.height * prev.channels
  if prev.data.length() != prev_expected_size {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade: prev数据大小不匹配，期望 " +
      prev_expected_size.to_string() +
      "，实际 " +
      prev.data.length().to_string(),
    )
  }
  let next_expected_size = next.width * next.height * next.channels
  if next.data.length() != next_expected_size {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade: next数据大小不匹配，期望 " +
      next_expected_size.to_string() +
      "，实际 " +
      next.data.length().to_string(),
    )
  }
  if prev.width != next.width || prev.height != next.height {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade: 两帧图像尺寸必须一致",
    )
  }
  if points.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade: points数组不能为空",
    )
  }
  if window_size < 3 || window_size > 31 || window_size % 2 == 0 {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade: window_size必须为3..31之间的奇数",
    )
  }
  if max_iter <= 0 {
    raise @types.LoadError::DecodeFailed("lucas_kanade: max_iter必须大于0")
  }
  let w = prev.width
  let h = prev.height
  // 转灰度
  let (gray_prev, _) = to_gray_lk(prev)
  let (gray_next, _) = to_gray_lk(next)
  let half_win = window_size / 2
  let results : Array[FlowResult] = []
  for i in 0..<points.length() {
    let (px, py) = points[i]
    // 初始化位移
    let mut u = 0.0F
    let mut v = 0.0F
    let mut found = false
    // 迭代求解
    for _ in 0..<max_iter {
      // 构建 Lucas-Kanade 方程：A^T A * d = A^T b
      let mut ixx = 0.0F
      let mut ixy = 0.0F
      let mut iyy = 0.0F
      let mut ix_it = 0.0F
      let mut iy_it = 0.0F
      for dy in -half_win..<=half_win {
        for dx in -half_win..<=half_win {
          let x = px + dx
          let y = py + dy
          if x < 1 || x >= w - 1 || y < 1 || y >= h - 1 {
            continue
          }
          // 空间梯度（中心差分）
          let ix = Float::from_int(
              gray_prev[y * w + x + 1] - gray_prev[y * w + x - 1],
            ) /
            2.0F
          let iy = Float::from_int(
              gray_prev[(y + 1) * w + x] - gray_prev[(y - 1) * w + x],
            ) /
            2.0F
          // 时间差分：I_t = I_next(x+u, y+v) - I_prev(x, y)
          let nx = Float::from_int(x) + u
          let ny = Float::from_int(y) + v
          let next_val = sample_bilinear_lk(gray_next, w, h, nx, ny)
          let prev_val = Float::from_int(gray_prev[y * w + x])
          let it = next_val - prev_val
          // 累加 A^T A 和 A^T b
          ixx += ix * ix
          ixy += ix * iy
          iyy += iy * iy
          ix_it += ix * it
          iy_it += iy * it
        }
      }
      // 求解 2x2 线性方程
      let det = ixx * iyy - ixy * ixy
      if det.abs() < 0.01F {
        break
      }
      let du = -(iyy * ix_it - ixy * iy_it) / det
      let dv = -(ixx * iy_it - ixy * ix_it) / det
      u += du
      v += dv
      // 收敛检测
      if du.abs() < 0.01F && dv.abs() < 0.01F {
        found = true
        break
      }
      found = true
    }
    results.push(FlowResult::{
      x: Float::from_int(px),
      y: Float::from_int(py),
      u,
      v,
      found,
    })
  }
  results
}

///|
/// Horn-Schunck 密集光流（简化版）。
/// 计算两帧之间所有像素的光流场。
/// alpha 为平滑权重（默认1.0），iterations 为迭代次数（默认100）。
/// 返回 (u_field, v_field)，每个为 w*h 的 Float 数组。
pub fn horn_schunck(
  prev : @types.Image,
  next : @types.Image,
  alpha? : Float = 1.0F,
  iterations? : Int = 100,
) -> (Array[Float], Array[Float]) raise @types.LoadError {
  // 输入验证
  if prev.width <= 0 || prev.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck: prev图像尺寸必须大于0",
    )
  }
  if next.width <= 0 || next.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck: next图像尺寸必须大于0",
    )
  }
  if prev.channels < 1 || prev.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck: prev通道数必须在1-4之间",
    )
  }
  if next.channels < 1 || next.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck: next通道数必须在1-4之间",
    )
  }
  let prev_expected_size = prev.width * prev.height * prev.channels
  if prev.data.length() != prev_expected_size {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck: prev数据大小不匹配，期望 " +
      prev_expected_size.to_string() +
      "，实际 " +
      prev.data.length().to_string(),
    )
  }
  let next_expected_size = next.width * next.height * next.channels
  if next.data.length() != next_expected_size {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck: next数据大小不匹配，期望 " +
      next_expected_size.to_string() +
      "，实际 " +
      next.data.length().to_string(),
    )
  }
  if prev.width != next.width || prev.height != next.height {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck: 两帧图像尺寸必须一致",
    )
  }
  if alpha <= 0.0F {
    raise @types.LoadError::DecodeFailed("horn_schunck: alpha必须大于0")
  }
  if iterations <= 0 {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck: iterations必须大于0",
    )
  }
  let w = prev.width
  let h = prev.height
  let n = w * h
  let (gray_prev, _) = to_gray_lk(prev)
  let (gray_next, _) = to_gray_lk(next)
  // 计算空间梯度和时间梯度
  let ex : Array[Float] = Array::make(n, 0.0F)
  let ey : Array[Float] = Array::make(n, 0.0F)
  let et : Array[Float] = Array::make(n, 0.0F)
  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      let xl = if x > 0 { x - 1 } else { 0 }
      let xr = if x < w - 1 { x + 1 } else { w - 1 }
      let yu = if y > 0 { y - 1 } else { 0 }
      let yd = if y < h - 1 { y + 1 } else { h - 1 }
      // Ex = (I(x+1,y) - I(x-1,y) + J(x+1,y) - J(x-1,y)) / 4
      ex[idx] = Float::from_int(
          gray_prev[y * w + xr] -
          gray_prev[y * w + xl] +
          gray_next[y * w + xr] -
          gray_next[y * w + xl],
        ) /
        4.0F
      // Ey = (I(x,y+1) - I(x,y-1) + J(x,y+1) - J(x,y-1)) / 4
      ey[idx] = Float::from_int(
          gray_prev[yd * w + x] -
          gray_prev[yu * w + x] +
          gray_next[yd * w + x] -
          gray_next[yu * w + x],
        ) /
        4.0F
      // Et = J(x,y) - I(x,y)
      et[idx] = Float::from_int(gray_next[idx] - gray_prev[idx])
    }
  }
  // 初始化光流场
  let u : Array[Float] = Array::make(n, 0.0F)
  let v : Array[Float] = Array::make(n, 0.0F)
  let alpha_sq = alpha * alpha
  // 迭代求解
  for _ in 0..<iterations {
    let u_prev = u.copy()
    let v_prev = v.copy()
    for y in 0..<h {
      for x in 0..<w {
        let idx = y * w + x
        // 计算 u, v 的邻域平均（4 邻域）
        let xl = if x > 0 { idx - 1 } else { idx }
        let xr = if x < w - 1 { idx + 1 } else { idx }
        let yu = if y > 0 { idx - w } else { idx }
        let yd = if y < h - 1 { idx + w } else { idx }
        let u_avg = (u_prev[xl] + u_prev[xr] + u_prev[yu] + u_prev[yd]) / 4.0F
        let v_avg = (v_prev[xl] + v_prev[xr] + v_prev[yu] + v_prev[yd]) / 4.0F
        // Horn-Schunck 更新
        let denom = alpha_sq + ex[idx] * ex[idx] + ey[idx] * ey[idx]
        if denom > 0.0F {
          let common = ex[idx] * u_avg + ey[idx] * v_avg + et[idx]
          u[idx] = u_avg - ex[idx] * common / denom
          v[idx] = v_avg - ey[idx] * common / denom
        }
      }
    }
  }
  (u, v)
}

// ==================== 辅助函数 ====================

///|
fn to_gray_lk(img : @types.Image) -> (Array[Int], Int) {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let n = w * h
  let gray : Array[Int] = Array::make(n, 0)
  for i in 0..<n {
    if ch >= 3 {
      let r = img.data[i * ch].to_int()
      let g = img.data[i * ch + 1].to_int()
      let b = img.data[i * ch + 2].to_int()
      gray[i] = (r * 299 + g * 587 + b * 114) / 1000
    } else {
      gray[i] = img.data[i * ch].to_int()
    }
  }
  (gray, n)
}

///|
fn sample_bilinear_lk(
  gray : Array[Int],
  w : Int,
  h : Int,
  fx : Float,
  fy : Float,
) -> Float {
  let x0 = fx.to_int()
  let y0 = fy.to_int()
  let x1 = x0 + 1
  let y1 = y0 + 1
  let x0c = x0.clamp(min=0, max=w - 1)
  let x1c = x1.clamp(min=0, max=w - 1)
  let y0c = y0.clamp(min=0, max=h - 1)
  let y1c = y1.clamp(min=0, max=h - 1)
  let p00 = gray[y0c * w + x0c]
  let p01 = gray[y0c * w + x1c]
  let p10 = gray[y1c * w + x0c]
  let p11 = gray[y1c * w + x1c]
  let wx = fx - Float::from_int(x0)
  let wy = fy - Float::from_int(y0)
  Float::from_int(p00) * (1.0F - wx) * (1.0F - wy) +
  Float::from_int(p01) * wx * (1.0F - wy) +
  Float::from_int(p10) * (1.0F - wx) * wy +
  Float::from_int(p11) * wx * wy
}

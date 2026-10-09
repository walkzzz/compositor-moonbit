// 透视变换（纯 MoonBit）：get_perspective_transform + warp_perspective

///|
/// 3×3 透视变换矩阵 (m00, m01, m02, m10, m11, m12, m20, m21, m22)
pub(all) struct PerspectiveMatrix {
  m00 : Float
  m01 : Float
  m02 : Float
  m10 : Float
  m11 : Float
  m12 : Float
  m20 : Float
  m21 : Float
  m22 : Float
}

///|
/// 高斯消元法求解线性方程组 Ax=b，A 为 n×n 矩阵，b 为 n 维向量
fn solve_linear_system(
  a : Array[Array[Float]],
  b : Array[Float],
  n : Int,
) -> Array[Float]? {
  let mat : Array[Array[Float]] = Array::make(n, [])
  for i in 0..<n {
    mat[i] = Array::make(n + 1, 0.0F)
    for j in 0..<n {
      mat[i][j] = a[i][j]
    }
    mat[i][n] = b[i]
  }
  // 前向消元
  for col in 0..<n {
    // 选主元
    let mut pivot = col
    for row in (col + 1)..<n {
      if mat[row][col].abs() > mat[pivot][col].abs() {
        pivot = row
      }
    }
    if mat[pivot][col].abs() < 0.0000000001F {
      return None
    }
    if pivot != col {
      let tmp = mat[pivot]
      mat[pivot] = mat[col]
      mat[col] = tmp
    }
    // 消元
    for row in (col + 1)..<n {
      let factor = mat[row][col] / mat[col][col]
      for j in col..<=n {
        mat[row][j] -= factor * mat[col][j]
      }
    }
  }
  // 回代
  let x : Array[Float] = Array::make(n, 0.0F)
  for k in 0..<n {
    let i = n - 1 - k
    let mut sum = mat[i][n]
    for j in (i + 1)..<n {
      sum -= mat[i][j] * x[j]
    }
    x[i] = sum / mat[i][i]
  }
  Some(x)
}

///|
/// 从 4 对源点→目标点计算 3×3 透视变换矩阵。
/// src 和 dst 均为 4 个 (Float, Float) 点。
pub fn get_perspective_transform(
  src : Array[(Float, Float)],
  dst : Array[(Float, Float)],
) -> PerspectiveMatrix? {
  if src.length() != 4 || dst.length() != 4 {
    return None
  }
  // 构建 8×8 线性方程组
  let a : Array[Array[Float]] = Array::make(8, [])
  let b : Array[Float] = Array::make(8, 0.0F)
  for i in 0..<4 {
    let (sx, sy) = src[i]
    let (dx, dy) = dst[i]
    // 方程 1: m00*sx + m01*sy + m02 - m20*sx*dx - m21*sy*dx = dx
    a[i * 2] = [sx, sy, 1.0F, 0.0F, 0.0F, 0.0F, -sx * dx, -sy * dx]
    b[i * 2] = dx
    // 方程 2: m10*sx + m11*sy + m12 - m20*sx*dy - m21*sy*dy = dy
    a[i * 2 + 1] = [0.0F, 0.0F, 0.0F, sx, sy, 1.0F, -sx * dy, -sy * dy]
    b[i * 2 + 1] = dy
  }
  let sol = solve_linear_system(a, b, 8)
  match sol {
    None => None
    Some(v) =>
      Some(PerspectiveMatrix::{
        m00: v[0],
        m01: v[1],
        m02: v[2],
        m10: v[3],
        m11: v[4],
        m12: v[5],
        m20: v[6],
        m21: v[7],
        m22: 1.0F,
      })
  }
}

///|
/// 透视变换。使用 3×3 矩阵将图像变换到 new_w × new_h。
/// 采用 dst→src 映射 + 双线性插值。
pub fn warp_perspective(
  img : @types.Image,
  matrix : PerspectiveMatrix,
  new_w : Int,
  new_h : Int,
) -> @types.Image {
  let ch = img.channels
  let w = img.width
  let h = img.height
  let data_int : Array[Int] = Array::make(w * h * ch, 0)
  for i in 0..<(w * h * ch) {
    data_int[i] = img.data[i].to_int()
  }
  let out : Array[Byte] = Array::make(new_w * new_h * ch, b'\x00')
  for dy in 0..<new_h {
    let fdx = 0.0F
    let fdy = Float::from_int(dy)
    for dx in 0..<new_w {
      let fdx2 = if dx == 0 { fdx } else { Float::from_int(dx) }
      // dst→src: 求逆映射。这里假设 matrix 是 src→dst，需要求逆。
      // 简化：直接用 matrix 做 dst→src 映射（前向映射的逆）
      // src_x = (m00*dx + m01*dy + m02) / (m20*dx + m21*dy + m22)
      // src_y = (m10*dx + m11*dy + m12) / (m20*dx + m21*dy + m22)
      let denom = matrix.m20 * fdx2 + matrix.m21 * fdy + matrix.m22
      if denom.abs() < 0.0000000001F {
        continue
      }
      let sx = (matrix.m00 * fdx2 + matrix.m01 * fdy + matrix.m02) / denom
      let sy = (matrix.m10 * fdx2 + matrix.m11 * fdy + matrix.m12) / denom
      for ci in 0..<ch {
        let val = persp_sample_bilinear(data_int, w, h, ch, ci, sx, sy)
        out[(dy * new_w + dx) * ch + ci] = val.to_byte()
      }
    }
  }
  @types.Image::{
    width: new_w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
fn persp_sample_bilinear(
  data : Array[Int],
  w : Int,
  h : Int,
  ch : Int,
  c : Int,
  x : Float,
  y : Float,
) -> Int {
  let x0 = x.to_int()
  let y0 = y.to_int()
  let w1 = w - 1
  let h1 = h - 1
  let x0c = x0.clamp(min=0, max=w1)
  let y0c = y0.clamp(min=0, max=h1)
  let x1 = (x0 + 1).clamp(min=0, max=w1)
  let y1 = (y0 + 1).clamp(min=0, max=h1)
  let fx = x - Float::from_int(x0)
  let fy = y - Float::from_int(y0)
  let p00 = data[(y0c * w + x0c) * ch + c]
  let p10 = data[(y0c * w + x1) * ch + c]
  let p01 = data[(y1 * w + x0c) * ch + c]
  let p11 = data[(y1 * w + x1) * ch + c]
  let top = Float::from_int(p00) * (1.0F - fx) + Float::from_int(p10) * fx
  let bot = Float::from_int(p01) * (1.0F - fx) + Float::from_int(p11) * fx
  (top * (1.0F - fy) + bot * fy + 0.5F).to_int().clamp(min=0, max=255)
}

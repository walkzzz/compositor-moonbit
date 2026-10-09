// 图像配准（v12.7.0）
// 基于相位相关的平移估计 + 仿射变换 + 图像对齐

///|
/// 配准结果
pub(all) struct RegistrationResult {
  dx : Double // x 方向平移
  dy : Double // y 方向平移
  rotation : Double // 旋转角度（弧度）
  scale : Double // 缩放因子
  confidence : Double // 配准置信度
}

///|
/// 仿射变换矩阵
pub(all) struct AffineTransform {
  a : Double // 缩放+旋转
  b : Double // 剪切+旋转
  c : Double // x 平移
  d : Double // 剪切+旋转
  e : Double // 缩放+旋转
  f : Double // y 平移
}

///|
/// 创建恒等变换
pub fn affine_identity() -> AffineTransform {
  AffineTransform::{ a: 1.0, b: 0.0, c: 0.0, d: 0.0, e: 1.0, f: 0.0 }
}

///|
/// 创建平移变换
pub fn affine_translation(dx : Double, dy : Double) -> AffineTransform {
  AffineTransform::{ a: 1.0, b: 0.0, c: dx, d: 0.0, e: 1.0, f: dy }
}

///|
/// 创建旋转变换（围绕原点）
pub fn affine_rotation(angle : Double) -> AffineTransform {
  let cos_a = @math.cos(angle)
  let sin_a = @math.sin(angle)
  AffineTransform::{ a: cos_a, b: -sin_a, c: 0.0, d: sin_a, e: cos_a, f: 0.0 }
}

///|
/// 创建缩放变换
pub fn affine_scale(sx : Double, sy : Double) -> AffineTransform {
  AffineTransform::{ a: sx, b: 0.0, c: 0.0, d: 0.0, e: sy, f: 0.0 }
}

///|
/// 组合两个仿射变换（先应用 t1，再应用 t2）
pub fn affine_compose(
  t1 : AffineTransform,
  t2 : AffineTransform,
) -> AffineTransform {
  AffineTransform::{
    a: t2.a * t1.a + t2.b * t1.d,
    b: t2.a * t1.b + t2.b * t1.e,
    c: t2.a * t1.c + t2.b * t1.f + t2.c,
    d: t2.d * t1.a + t2.e * t1.d,
    e: t2.d * t1.b + t2.e * t1.e,
    f: t2.d * t1.c + t2.e * t1.f + t2.f,
  }
}

///|
/// 应用仿射变换到点
pub fn affine_apply(
  t : AffineTransform,
  x : Double,
  y : Double,
) -> (Double, Double) {
  let nx = t.a * x + t.b * y + t.c
  let ny = t.d * x + t.e * y + t.f
  (nx, ny)
}

///|
/// 计算图像的灰度图
fn to_gray(img : @types.Image) -> Array[Double] {
  let w = img.width
  let h = img.height
  let channels = img.channels
  let gray : Array[Double] = Array::make(w * h, 0.0)
  for i in 0..<(w * h) {
    let idx = i * channels
    let r = img.data[idx].to_double()
    let g = if channels >= 2 { img.data[idx + 1].to_double() } else { r }
    let b = if channels >= 3 { img.data[idx + 2].to_double() } else { r }
    gray[i] = 0.299 * r + 0.587 * g + 0.114 * b
  }
  gray
}

///|
/// 基于相位相关的平移估计（简化版，使用空间域互相关）
pub fn estimate_translation(
  img1 : @types.Image,
  img2 : @types.Image,
  max_offset? : Int = 20,
) -> RegistrationResult raise @types.LoadError {
  // 输入验证
  if img1.width <= 0 || img1.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "estimate_translation: 图像尺寸必须大于0",
    )
  }
  if img1.channels < 1 || img1.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "estimate_translation: 通道数必须在1-4之间",
    )
  }
  let expected_size = img1.width * img1.height * img1.channels
  if img1.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "estimate_translation: 数据大小不匹配",
    )
  }
  if img2.width <= 0 || img2.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "estimate_translation: 图像尺寸必须大于0",
    )
  }
  if img2.channels < 1 || img2.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "estimate_translation: 通道数必须在1-4之间",
    )
  }
  let expected_size2 = img2.width * img2.height * img2.channels
  if img2.data.length() != expected_size2 {
    raise @types.LoadError::DecodeFailed(
      "estimate_translation: 数据大小不匹配",
    )
  }
  let max_off = max_offset
  if img1.width != img2.width || img1.height != img2.height {
    return RegistrationResult::{
      dx: 0.0,
      dy: 0.0,
      rotation: 0.0,
      scale: 1.0,
      confidence: 0.0,
    }
  }
  let w = img1.width
  let h = img1.height
  let gray1 = to_gray(img1)
  let gray2 = to_gray(img2)
  // 计算均值
  let mut mean1 = 0.0
  let mut mean2 = 0.0
  for i in 0..<(w * h) {
    mean1 += gray1[i]
    mean2 += gray2[i]
  }
  mean1 = mean1 / (w * h).to_double()
  mean2 = mean2 / (w * h).to_double()
  // 搜索最佳平移
  let mut best_dx = 0
  let mut best_dy = 0
  let mut best_corr = -10000000000.0
  for dy in -max_off..<(max_off + 1) {
    for dx in -max_off..<(max_off + 1) {
      let mut corr = 0.0
      let mut var1 = 0.0
      let mut var2 = 0.0
      let mut count = 0
      for y in 0..<h {
        for x in 0..<w {
          let x2 = x + dx
          let y2 = y + dy
          if x2 >= 0 && x2 < w && y2 >= 0 && y2 < h {
            let v1 = gray1[y * w + x] - mean1
            let v2 = gray2[y2 * w + x2] - mean2
            corr += v1 * v2
            var1 += v1 * v1
            var2 += v2 * v2
            count += 1
          }
        }
      }
      if count > 0 && var1 > 0.0 && var2 > 0.0 {
        let normalized_corr = corr / (var1.sqrt() * var2.sqrt())
        if normalized_corr > best_corr {
          best_corr = normalized_corr
          best_dx = dx
          best_dy = dy
        }
      }
    }
  }
  RegistrationResult::{
    dx: best_dx.to_double(),
    dy: best_dy.to_double(),
    rotation: 0.0,
    scale: 1.0,
    confidence: if best_corr > 0.0 {
      best_corr
    } else {
      0.0
    },
  }
}

///|
/// 使用仿射变换对齐图像（反向映射 + 双线性插值）
pub fn warp_affine_transform(
  img : @types.Image,
  transform : AffineTransform,
  out_width? : Int = 0,
  out_height? : Int = 0,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "warp_affine_transform: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "warp_affine_transform: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "warp_affine_transform: 数据大小不匹配",
    )
  }
  let ow = if out_width == 0 { img.width } else { out_width }
  let oh = if out_height == 0 { img.height } else { out_height }
  let w = img.width
  let h = img.height
  let channels = img.channels
  let out_data : Array[Byte] = Array::make(ow * oh * channels, b'\x00')
  // 计算逆变换
  let det = transform.a * transform.e - transform.b * transform.d
  if det.abs() < 0.000001 {
    return img
  }
  let inv_a = transform.e / det
  let inv_b = -transform.b / det
  let inv_c = (transform.b * transform.f - transform.e * transform.c) / det
  let inv_d = -transform.d / det
  let inv_e = transform.a / det
  let inv_f = (transform.d * transform.c - transform.a * transform.f) / det
  for y in 0..<oh {
    for x in 0..<ow {
      // 反向映射
      let src_x = inv_a * x.to_double() + inv_b * y.to_double() + inv_c
      let src_y = inv_d * x.to_double() + inv_e * y.to_double() + inv_f
      // 双线性插值
      let x0 = src_x.floor().to_int()
      let y0 = src_y.floor().to_int()
      let x1 = x0 + 1
      let y1 = y0 + 1
      let fx = src_x - x0.to_double()
      let fy = src_y - y0.to_double()
      let out_idx = (y * ow + x) * channels
      for c in 0..<channels {
        if x0 >= 0 && x1 < w && y0 >= 0 && y1 < h {
          let v00 = img.data[(y0 * w + x0) * channels + c].to_double()
          let v01 = img.data[(y0 * w + x1) * channels + c].to_double()
          let v10 = img.data[(y1 * w + x0) * channels + c].to_double()
          let v11 = img.data[(y1 * w + x1) * channels + c].to_double()
          let top = v00 * (1.0 - fx) + v01 * fx
          let bottom = v10 * (1.0 - fx) + v11 * fx
          let value = top * (1.0 - fy) + bottom * fy
          out_data[out_idx + c] = value.min(255.0).max(0.0).to_int().to_byte()
        } else {
          out_data[out_idx + c] = b'\x00'
        }
      }
    }
  }
  @types.Image::{
    width: ow,
    height: oh,
    channels,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 图像对齐（将 img2 对齐到 img1）
pub fn align_images(
  img1 : @types.Image,
  img2 : @types.Image,
) -> (@types.Image, RegistrationResult) raise @types.LoadError {
  // 输入验证
  if img1.width <= 0 || img1.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "align_images: 图像尺寸必须大于0",
    )
  }
  if img1.channels < 1 || img1.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "align_images: 通道数必须在1-4之间",
    )
  }
  let expected_size = img1.width * img1.height * img1.channels
  if img1.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed("align_images: 数据大小不匹配")
  }
  if img2.width <= 0 || img2.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "align_images: 图像尺寸必须大于0",
    )
  }
  if img2.channels < 1 || img2.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "align_images: 通道数必须在1-4之间",
    )
  }
  let expected_size2 = img2.width * img2.height * img2.channels
  if img2.data.length() != expected_size2 {
    raise @types.LoadError::DecodeFailed("align_images: 数据大小不匹配")
  }
  let result = estimate_translation(img1, img2)
  let transform = affine_translation(-result.dx, -result.dy)
  let aligned = warp_affine_transform(img2, transform)
  (aligned, result)
}

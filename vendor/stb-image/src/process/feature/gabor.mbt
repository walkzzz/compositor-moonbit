// Gabor 滤波（纯 MoonBit）

///|
/// Gabor 滤波器。
/// g(x,y) = exp(-(x'²+γ²y'²)/(2σ²)) * cos(2πx'/λ + φ)
/// 其中 x' = x*cos(θ) + y*sin(θ), y' = -x*sin(θ) + y*cos(θ)
/// 适用于灰度图（channels=1）或 RGB/RGBA 图（channels=3/4）。
/// ksize 为核大小（奇数），sigma 为标准差，theta 为方向（弧度），
/// lambda 为波长，gamma 为空间纵横比（默认 0.5），phi 为相位偏移（默认 0）。
pub fn gabor_filter(
  img : @types.Image,
  ksize : Int,
  sigma : Float,
  theta : Float,
  lambda? : Float = 10.0F,
  gamma? : Float = 0.5F,
  phi? : Float = 0.0F,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "gabor_filter: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "gabor_filter: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "gabor_filter: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if gamma <= 0.0F {
    raise @types.LoadError::DecodeFailed("gabor_filter: gamma必须大于0")
  }
  if ksize < 3 || ksize > 31 || ksize % 2 == 0 {
    raise @types.LoadError::DecodeFailed(
      "ksize 必须为 3..31 之间的奇数",
    )
  }
  if sigma <= 0.0F {
    raise @types.LoadError::DecodeFailed("sigma 必须 > 0")
  }
  if lambda <= 0.0F {
    raise @types.LoadError::DecodeFailed("lambda 必须 > 0")
  }
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  if n == 0 {
    return img
  }
  // 生成 Gabor 核
  let half = ksize / 2
  let kernel : Array[Float] = Array::make(ksize * ksize, 0.0F)
  let cos_t = @math.cosf(theta)
  let sin_t = @math.sinf(theta)
  for ky in 0..<ksize {
    for kx in 0..<ksize {
      let x = Float::from_int(kx - half)
      let y = Float::from_int(ky - half)
      let x_prime = x * cos_t + y * sin_t
      let y_prime = -x * sin_t + y * cos_t
      let gaussian = @math.expf(
        -(x_prime * x_prime + gamma * gamma * y_prime * y_prime) /
        (2.0F * sigma * sigma),
      )
      let wave = @math.cosf(2.0F * 3.14159265F * x_prime / lambda + phi)
      let val = gaussian * wave
      kernel[ky * ksize + kx] = val
    }
  }
  // 预计算像素 Float 数组，避免内层循环重复类型转换
  let src : Array[Float] = Array::make(n * ch, 0.0F)
  for i in 0..<(n * ch) {
    src[i] = Float::from_int(img.data[i].to_int())
  }
  // 卷积，分离内部/边界区域，ch=1 特化消除内层通道循环
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  if ch == 1 {
    // 内部区域
    for y in half..<(h - half) {
      for x in half..<(w - half) {
        let mut sum = 0.0F
        let base = (y - half) * w + (x - half)
        for ky in 0..<ksize {
          let row = base + ky * w
          let krow = ky * ksize
          for kx in 0..<ksize {
            sum += src[row + kx] * kernel[krow + kx]
          }
        }
        let val = sum.to_int()
        out[y * w + x] = val.clamp(min=0, max=255).to_byte()
      }
    }
    // 边界区域
    for y in 0..<h {
      let y_inner = y >= half && y < h - half
      for x in 0..<w {
        if y_inner && x >= half && x < w - half {
          continue
        }
        let mut sum = 0.0F
        for ky in 0..<ksize {
          for kx in 0..<ksize {
            let px = (x + kx - half).clamp(min=0, max=w - 1)
            let py = (y + ky - half).clamp(min=0, max=h - 1)
            sum += src[py * w + px] * kernel[ky * ksize + kx]
          }
        }
        let val = sum.to_int()
        out[y * w + x] = val.clamp(min=0, max=255).to_byte()
      }
    }
  } else {
    for c in 0..<ch {
      if ch == 4 && c == 3 {
        for i in 0..<n {
          out[i * ch + 3] = img.data[i * ch + 3]
        }
        continue
      }
      // 内部区域
      for y in half..<(h - half) {
        for x in half..<(w - half) {
          let mut sum = 0.0F
          let base = (y - half) * w + (x - half)
          for ky in 0..<ksize {
            let row = (base + ky * w) * ch + c
            let krow = ky * ksize
            for kx in 0..<ksize {
              sum += src[row + kx * ch] * kernel[krow + kx]
            }
          }
          let val = sum.to_int()
          out[(y * w + x) * ch + c] = val.clamp(min=0, max=255).to_byte()
        }
      }
      // 边界区域
      for y in 0..<h {
        let y_inner = y >= half && y < h - half
        for x in 0..<w {
          if y_inner && x >= half && x < w - half {
            continue
          }
          let mut sum = 0.0F
          for ky in 0..<ksize {
            for kx in 0..<ksize {
              let px = (x + kx - half).clamp(min=0, max=w - 1)
              let py = (y + ky - half).clamp(min=0, max=h - 1)
              sum += src[(py * w + px) * ch + c] * kernel[ky * ksize + kx]
            }
          }
          let val = sum.to_int()
          out[(y * w + x) * ch + c] = val.clamp(min=0, max=255).to_byte()
        }
      }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// Gabor 滤波器组（多方向）。
/// 对图像应用多个方向的 Gabor 滤波器，返回每个方向的响应幅值之和。
/// 适用于灰度图（channels=1）或 RGB/RGBA 图（channels=3/4）。
/// num_orientations 为方向数（默认 4，即 0°/45°/90°/135°）。
pub fn gabor_filter_bank(
  img : @types.Image,
  ksize : Int,
  sigma : Float,
  num_orientations? : Int = 4,
  lambda? : Float = 10.0F,
  gamma? : Float = 0.5F,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "gabor_filter_bank: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "gabor_filter_bank: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "gabor_filter_bank: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if ksize < 3 || ksize > 31 || ksize % 2 == 0 {
    raise @types.LoadError::DecodeFailed(
      "gabor_filter_bank: ksize必须为3..31之间的奇数",
    )
  }
  if sigma <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "gabor_filter_bank: sigma必须大于0",
    )
  }
  if lambda <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "gabor_filter_bank: lambda必须大于0",
    )
  }
  if gamma <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "gabor_filter_bank: gamma必须大于0",
    )
  }
  if num_orientations < 1 || num_orientations > 16 {
    raise @types.LoadError::DecodeFailed(
      "num_orientations 必须在 1..16 之间",
    )
  }
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  if n == 0 {
    return img
  }
  // 累加各方向响应
  let accum : Array[Float] = Array::make(n * ch, 0.0F)
  for i in 0..<num_orientations {
    let theta = Float::from_int(i) *
      3.14159265F /
      Float::from_int(num_orientations)
    let filtered = gabor_filter(img, ksize, sigma, theta, lambda~, gamma~)
    for j in 0..<(n * ch) {
      accum[j] += Float::from_int(filtered.data[j].to_int())
    }
  }
  // 归一化
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  for j in 0..<(n * ch) {
    let val = (accum[j] / Float::from_int(num_orientations)).to_int()
    out[j] = val.clamp(min=0, max=255).to_byte()
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 生成 Gabor 核（返回核矩阵，用于可视化或调试）。
pub fn gabor_kernel(
  ksize : Int,
  sigma : Float,
  theta : Float,
  lambda? : Float = 10.0F,
  gamma? : Float = 0.5F,
  phi? : Float = 0.0F,
) -> Array[Array[Float]] raise @types.LoadError {
  // 参数验证
  if ksize < 3 || ksize > 31 || ksize % 2 == 0 {
    raise @types.LoadError::DecodeFailed(
      "gabor_kernel: ksize必须为3..31之间的奇数",
    )
  }
  if sigma <= 0.0F {
    raise @types.LoadError::DecodeFailed("gabor_kernel: sigma必须大于0")
  }
  if lambda <= 0.0F {
    raise @types.LoadError::DecodeFailed("gabor_kernel: lambda必须大于0")
  }
  if gamma <= 0.0F {
    raise @types.LoadError::DecodeFailed("gabor_kernel: gamma必须大于0")
  }
  let half = ksize / 2
  let kernel : Array[Array[Float]] = Array::make(ksize, [])
  for i in 0..<ksize {
    kernel[i] = Array::make(ksize, 0.0F)
  }
  let cos_t = @math.cosf(theta)
  let sin_t = @math.sinf(theta)
  for ky in 0..<ksize {
    for kx in 0..<ksize {
      let x = Float::from_int(kx - half)
      let y = Float::from_int(ky - half)
      let x_prime = x * cos_t + y * sin_t
      let y_prime = -x * sin_t + y * cos_t
      let gaussian = @math.expf(
        -(x_prime * x_prime + gamma * gamma * y_prime * y_prime) /
        (2.0F * sigma * sigma),
      )
      let wave = @math.cosf(2.0F * 3.14159265F * x_prime / lambda + phi)
      kernel[ky][kx] = gaussian * wave
    }
  }
  kernel
}

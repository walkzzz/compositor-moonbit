// 多尺度 Retinex（纯 MoonBit）

///|
/// Float 自然对数辅助函数
fn logf(x : Float) -> Float {
  Float::from_double(@math.log2(x.to_double()) * 0.6931471805599453)
}

///|
/// 单尺度 Retinex（SSR）。
/// 对每个像素计算 log(I) - log(I * G_sigma)，
/// 其中 G_sigma 为高斯滤波器。
/// 适用于灰度图（channels=1）或 RGB/RGBA 图（channels=3/4）。
/// sigma 为高斯标准差，gain 为增益，offset 为偏移。
pub fn ssr(
  img : @types.Image,
  sigma? : Float = 80.0F,
  gain? : Float = 1.0F,
  offset? : Float = 0.0F,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width == 0 || img.height == 0 {
    return img
  }
  if img.width < 0 || img.height < 0 {
    raise @types.LoadError::DecodeFailed("ssr: 图像尺寸不能为负")
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("ssr 仅支持 channels=1/3/4")
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "ssr: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if sigma <= 0.0F {
    raise @types.LoadError::DecodeFailed("sigma 必须 > 0")
  }
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  if n == 0 {
    return img
  }
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  for c in 0..<ch {
    if ch == 4 && c == 3 {
      for i in 0..<n {
        out[i * ch + 3] = img.data[i * ch + 3]
      }
      continue
    }
    let channel : Array[Float] = Array::make(n, 0.0F)
    for i in 0..<n {
      let v = img.data[i * ch + c].to_int()
      channel[i] = Float::from_int(if v == 0 { 1 } else { v })
    }
    let blurred = gaussian_blur_channel(channel, w, h, sigma)
    for i in 0..<n {
      let log_i = logf(channel[i])
      let log_b = logf(if blurred[i] > 0.0F { blurred[i] } else { 1.0F })
      let retinex = (log_i - log_b) * gain + offset
      let val = (retinex * 30.0F + 128.0F).to_int()
      out[i * ch + c] = val.clamp(min=0, max=255).to_byte()
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
/// 多尺度 Retinex（MSR）。
/// 对多个不同 sigma 的 SSR 结果取平均。
/// 适用于灰度图（channels=1）或 RGB/RGBA 图（channels=3/4）。
/// sigmas 为高斯标准差数组（默认 [15, 80, 250]）。
/// gain 为增益，offset 为偏移。
pub fn msr(
  img : @types.Image,
  sigmas? : Array[Float] = [15.0F, 80.0F, 250.0F],
  gain? : Float = 1.0F,
  offset? : Float = 0.0F,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width == 0 || img.height == 0 {
    return img
  }
  if img.width < 0 || img.height < 0 {
    raise @types.LoadError::DecodeFailed("msr: 图像尺寸不能为负")
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("msr 仅支持 channels=1/3/4")
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "msr: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if sigmas.length() == 0 {
    raise @types.LoadError::DecodeFailed("sigmas 不能为空")
  }
  for s in sigmas {
    if s <= 0.0F {
      raise @types.LoadError::DecodeFailed("sigma 必须 > 0")
    }
  }
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  if n == 0 {
    return img
  }
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  let num_scales = sigmas.length()
  for c in 0..<ch {
    if ch == 4 && c == 3 {
      for i in 0..<n {
        out[i * ch + 3] = img.data[i * ch + 3]
      }
      continue
    }
    let channel : Array[Float] = Array::make(n, 0.0F)
    for i in 0..<n {
      let v = img.data[i * ch + c].to_int()
      channel[i] = Float::from_int(if v == 0 { 1 } else { v })
    }
    // 预计算 log(channel[i])，避免在每个 sigma 循环中重复计算
    let log_channel : Array[Float] = Array::make(n, 0.0F)
    for i in 0..<n {
      log_channel[i] = logf(channel[i])
    }
    let retinex_sum : Array[Float] = Array::make(n, 0.0F)
    for sigma in sigmas {
      let blurred = gaussian_blur_channel(channel, w, h, sigma)
      for i in 0..<n {
        let log_b = logf(if blurred[i] > 0.0F { blurred[i] } else { 1.0F })
        retinex_sum[i] += log_channel[i] - log_b
      }
    }
    let inv_scales = gain / Float::from_int(num_scales)
    for i in 0..<n {
      let retinex = retinex_sum[i] * inv_scales + offset
      let val = (retinex * 30.0F + 128.0F).to_int()
      out[i * ch + c] = val.clamp(min=0, max=255).to_byte()
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
/// 带颜色恢复的多尺度 Retinex（MSRCR）。
/// 在 MSR 基础上恢复颜色信息。
/// 适用于 RGB/RGBA 图（channels=3/4）。
pub fn msrcr(
  img : @types.Image,
  sigmas? : Array[Float] = [15.0F, 80.0F, 250.0F],
  gain? : Float = 1.0F,
  offset? : Float = 0.0F,
  alpha? : Float = 125.0F,
  beta? : Float = 46.0F,
) -> @types.Image raise @types.LoadError {
  if img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("msrcr 需要 RGB/RGBA 图像")
  }
  if sigmas.length() == 0 {
    raise @types.LoadError::DecodeFailed("sigmas 不能为空")
  }
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  if n == 0 {
    return img
  }
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  let num_scales = sigmas.length()
  // 提取各通道
  let channels : Array[Array[Float]] = [
    Array::make(n, 0.0F),
    Array::make(n, 0.0F),
    Array::make(n, 0.0F),
  ]
  for c in 0..<3 {
    for i in 0..<n {
      let v = img.data[i * ch + c].to_int()
      channels[c][i] = Float::from_int(if v == 0 { 1 } else { v })
    }
  }
  // 计算各通道 MSR
  let msr_results : Array[Array[Float]] = [
    Array::make(n, 0.0F),
    Array::make(n, 0.0F),
    Array::make(n, 0.0F),
  ]
  for c in 0..<3 {
    // 预计算 log(channel[i])
    let log_channel : Array[Float] = Array::make(n, 0.0F)
    for i in 0..<n {
      log_channel[i] = logf(channels[c][i])
    }
    let retinex_sum : Array[Float] = Array::make(n, 0.0F)
    for sigma in sigmas {
      let blurred = gaussian_blur_channel(channels[c], w, h, sigma)
      for i in 0..<n {
        let log_b = logf(if blurred[i] > 0.0F { blurred[i] } else { 1.0F })
        retinex_sum[i] += log_channel[i] - log_b
      }
    }
    let inv_scales = 1.0F / Float::from_int(num_scales)
    for i in 0..<n {
      msr_results[c][i] = retinex_sum[i] * inv_scales
    }
  }
  // 颜色恢复因子
  for i in 0..<n {
    let sum = channels[0][i] + channels[1][i] + channels[2][i]
    for c in 0..<3 {
      let crf = logf(alpha * channels[c][i] / (sum + 1.0F)) * beta
      let val = msr_results[c][i] * gain + offset + crf
      let mapped = (val * 30.0F + 128.0F).to_int()
      out[i * ch + c] = mapped.clamp(min=0, max=255).to_byte()
    }
    if ch == 4 {
      out[i * ch + 3] = img.data[i * ch + 3]
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
/// 对单通道进行高斯模糊
fn gaussian_blur_channel(
  channel : Array[Float],
  w : Int,
  h : Int,
  sigma : Float,
) -> Array[Float] {
  let n = w * h
  let out : Array[Float] = Array::make(n, 0.0F)
  let radius = (Float::from_int(3) * sigma).to_int()
  let radius = if radius < 1 { 1 } else { radius }
  let kernel_size = 2 * radius + 1
  let kernel : Array[Float] = Array::make(kernel_size, 0.0F)
  let two_sigma_sq = 2.0F * sigma * sigma
  let mut kernel_sum = 0.0F
  for i in 0..<kernel_size {
    let x = Float::from_int(i - radius)
    kernel[i] = @math.expf(-(x * x) / two_sigma_sq)
    kernel_sum += kernel[i]
  }
  for i in 0..<kernel_size {
    kernel[i] = kernel[i] / kernel_sum
  }
  // kernel prefix sum，用于大 radius 时 O(w) 替代 O(kernel_size)
  let k_prefix : Array[Float] = Array::make(kernel_size + 1, 0.0F)
  for i in 0..<kernel_size {
    k_prefix[i + 1] = k_prefix[i] + kernel[i]
  }
  let total_k = k_prefix[kernel_size]
  // 水平模糊
  let temp : Array[Float] = Array::make(n, 0.0F)
  if radius >= w {
    // 大 radius：所有像素都是边界，用 prefix sum 将 O(kernel_size) 降为 O(w)
    for y in 0..<h {
      let row_base = y * w
      let c0 = channel[row_base]
      let cw1 = channel[row_base + w - 1]
      for x in 0..<w {
        let left_end = radius - x
        let right_start = left_end + w
        let mid_start = if left_end > 0 { left_end } else { 0 }
        let mid_end = if right_start < kernel_size {
          right_start
        } else {
          kernel_size
        }
        let mut sum = c0 * k_prefix[mid_start] +
          cw1 * (total_k - k_prefix[mid_end])
        for k in mid_start..<mid_end {
          sum += channel[row_base + k - left_end] * kernel[k]
        }
        temp[row_base + x] = sum
      }
    }
  } else {
    // 正常情况：分离内部/边界区域
    for y in 0..<h {
      let row_base = y * w
      for x in radius..<(w - radius) {
        let mut sum = 0.0F
        let base = row_base + x - radius
        for k in 0..<kernel_size {
          sum += channel[base + k] * kernel[k]
        }
        temp[row_base + x] = sum
      }
      for x in 0..<w {
        if x >= radius && x < w - radius {
          continue
        }
        let mut sum = 0.0F
        for k in -radius..<=radius {
          let px = (x + k).clamp(min=0, max=w - 1)
          sum += channel[row_base + px] * kernel[k + radius]
        }
        temp[row_base + x] = sum
      }
    }
  }
  // 垂直模糊
  if radius >= h {
    // 大 radius：用 prefix sum 优化
    for x in 0..<w {
      let c0 = temp[x]
      let ch1 = temp[(h - 1) * w + x]
      for y in 0..<h {
        let left_end = radius - y
        let right_start = left_end + h
        let mid_start = if left_end > 0 { left_end } else { 0 }
        let mid_end = if right_start < kernel_size {
          right_start
        } else {
          kernel_size
        }
        let mut sum = c0 * k_prefix[mid_start] +
          ch1 * (total_k - k_prefix[mid_end])
        for k in mid_start..<mid_end {
          sum += temp[(k - left_end) * w + x] * kernel[k]
        }
        out[y * w + x] = sum
      }
    }
  } else {
    for x in 0..<w {
      for y in radius..<(h - radius) {
        let mut sum = 0.0F
        let base = (y - radius) * w + x
        for k in 0..<kernel_size {
          sum += temp[base + k * w] * kernel[k]
        }
        out[y * w + x] = sum
      }
      for y in 0..<h {
        if y >= radius && y < h - radius {
          continue
        }
        let mut sum = 0.0F
        for k in -radius..<=radius {
          let py = (y + k).clamp(min=0, max=h - 1)
          sum += temp[py * w + x] * kernel[k + radius]
        }
        out[y * w + x] = sum
      }
    }
  }
  out
}

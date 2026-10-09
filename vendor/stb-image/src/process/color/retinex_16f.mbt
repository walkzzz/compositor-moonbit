// 多尺度 Retinex 16-bit/float 变体
// SSR / MSR / MSRCR

///|
fn logf_r(x : Float) -> Float {
  Float::from_double(@math.log2(x.to_double()) * 0.6931471805599453)
}

///|
fn read_u16_r(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() | (data[offset + 1].to_int() << 8)
}

///|
fn write_u16_r(data : Array[Byte], offset : Int, v : Int) -> Unit {
  data[offset] = (v & 0xFF).to_byte()
  data[offset + 1] = ((v >> 8) & 0xFF).to_byte()
}

///|
fn read_f32_r(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

///|
fn write_f32_r(data : Array[Byte], offset : Int, v : Float) -> Unit {
  let bits = v.reinterpret_as_int()
  data[offset] = (bits & 0xFF).to_byte()
  data[offset + 1] = ((bits >> 8) & 0xFF).to_byte()
  data[offset + 2] = ((bits >> 16) & 0xFF).to_byte()
  data[offset + 3] = ((bits >> 24) & 0xFF).to_byte()
}

// ========== SSR 16-bit ==========

///|
/// 单尺度 Retinex（SSR）16-bit 版本。
pub fn ssr_16(
  img : @types.Image16,
  sigma? : Float = 80.0F,
  gain? : Float = 1.0F,
  offset? : Float = 0.0F,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width == 0 || img.height == 0 {
    return img
  }
  if img.width < 0 || img.height < 0 {
    raise @types.LoadError::DecodeFailed("ssr_16: 图像尺寸不能为负")
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("ssr_16 仅支持 channels=1/3/4")
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "ssr_16: 数据大小不匹配，期望 " +
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
  let out : Array[Byte] = Array::make(n * ch * 2, b'\x00')
  for c in 0..<ch {
    if ch == 4 && c == 3 {
      for i in 0..<n {
        let v = read_u16_r(img.data, (i * ch + 3) * 2)
        write_u16_r(out, (i * ch + 3) * 2, v)
      }
      continue
    }
    let channel : Array[Float] = Array::make(n, 0.0F)
    for i in 0..<n {
      let v = read_u16_r(img.data, (i * ch + c) * 2)
      channel[i] = Float::from_int(if v == 0 { 1 } else { v })
    }
    let blurred = gaussian_blur_channel(channel, w, h, sigma)
    for i in 0..<n {
      let log_i = logf_r(channel[i])
      let log_b = logf_r(if blurred[i] > 0.0F { blurred[i] } else { 1.0F })
      let retinex = (log_i - log_b) * gain + offset
      let val = (retinex * 30.0F + 32768.0F).to_int()
      let clamped = if val < 0 { 0 } else if val > 65535 { 65535 } else { val }
      write_u16_r(out, (i * ch + c) * 2, clamped)
    }
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== SSR float ==========

///|
/// 单尺度 Retinex（SSR）float 版本。
pub fn ssr_f(
  img : @types.ImageF,
  sigma? : Float = 80.0F,
  gain? : Float = 1.0F,
  offset? : Float = 0.0F,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width == 0 || img.height == 0 {
    return img
  }
  if img.width < 0 || img.height < 0 {
    raise @types.LoadError::DecodeFailed("ssr_f: 图像尺寸不能为负")
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("ssr_f 仅支持 channels=1/3/4")
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "ssr_f: 数据大小不匹配，期望 " +
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
  let out : Array[Byte] = Array::make(n * ch * 4, b'\x00')
  for c in 0..<ch {
    if ch == 4 && c == 3 {
      for i in 0..<n {
        let v = read_f32_r(img.data, (i * ch + 3) * 4)
        write_f32_r(out, (i * ch + 3) * 4, v)
      }
      continue
    }
    let channel : Array[Float] = Array::make(n, 0.0F)
    for i in 0..<n {
      let v = read_f32_r(img.data, (i * ch + c) * 4)
      channel[i] = if v <= 0.0F { 0.0001F } else { v }
    }
    let blurred = gaussian_blur_channel(channel, w, h, sigma)
    for i in 0..<n {
      let log_i = logf_r(channel[i])
      let log_b = logf_r(if blurred[i] > 0.0F { blurred[i] } else { 1.0F })
      let retinex = (log_i - log_b) * gain + offset
      write_f32_r(out, (i * ch + c) * 4, retinex)
    }
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== MSR 16-bit ==========

///|
/// 多尺度 Retinex（MSR）16-bit 版本。
pub fn msr_16(
  img : @types.Image16,
  sigmas? : Array[Float] = [15.0F, 80.0F, 250.0F],
  gain? : Float = 1.0F,
  offset? : Float = 0.0F,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("msr_16: 图像尺寸必须大于0")
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("msr_16 仅支持 channels=1/3/4")
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "msr_16: 数据大小不匹配，期望 " +
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
  let out : Array[Byte] = Array::make(n * ch * 2, b'\x00')
  let num_scales = sigmas.length()
  for c in 0..<ch {
    if ch == 4 && c == 3 {
      for i in 0..<n {
        let v = read_u16_r(img.data, (i * ch + 3) * 2)
        write_u16_r(out, (i * ch + 3) * 2, v)
      }
      continue
    }
    let channel : Array[Float] = Array::make(n, 0.0F)
    for i in 0..<n {
      let v = read_u16_r(img.data, (i * ch + c) * 2)
      channel[i] = Float::from_int(if v == 0 { 1 } else { v })
    }
    let log_channel : Array[Float] = Array::make(n, 0.0F)
    for i in 0..<n {
      log_channel[i] = logf_r(channel[i])
    }
    let retinex_sum : Array[Float] = Array::make(n, 0.0F)
    for sigma in sigmas {
      let blurred = gaussian_blur_channel(channel, w, h, sigma)
      for i in 0..<n {
        let log_b = logf_r(if blurred[i] > 0.0F { blurred[i] } else { 1.0F })
        retinex_sum[i] += log_channel[i] - log_b
      }
    }
    let inv_scales = gain / Float::from_int(num_scales)
    for i in 0..<n {
      let retinex = retinex_sum[i] * inv_scales + offset
      let val = (retinex * 30.0F + 32768.0F).to_int()
      let clamped = if val < 0 { 0 } else if val > 65535 { 65535 } else { val }
      write_u16_r(out, (i * ch + c) * 2, clamped)
    }
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== MSR float ==========

///|
/// 多尺度 Retinex（MSR）float 版本。
pub fn msr_f(
  img : @types.ImageF,
  sigmas? : Array[Float] = [15.0F, 80.0F, 250.0F],
  gain? : Float = 1.0F,
  offset? : Float = 0.0F,
) -> @types.ImageF raise @types.LoadError {
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("msr_f 仅支持 channels=1/3/4")
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
  let out : Array[Byte] = Array::make(n * ch * 4, b'\x00')
  let num_scales = sigmas.length()
  for c in 0..<ch {
    if ch == 4 && c == 3 {
      for i in 0..<n {
        let v = read_f32_r(img.data, (i * ch + 3) * 4)
        write_f32_r(out, (i * ch + 3) * 4, v)
      }
      continue
    }
    let channel : Array[Float] = Array::make(n, 0.0F)
    for i in 0..<n {
      let v = read_f32_r(img.data, (i * ch + c) * 4)
      channel[i] = if v <= 0.0F { 0.0001F } else { v }
    }
    let log_channel : Array[Float] = Array::make(n, 0.0F)
    for i in 0..<n {
      log_channel[i] = logf_r(channel[i])
    }
    let retinex_sum : Array[Float] = Array::make(n, 0.0F)
    for sigma in sigmas {
      let blurred = gaussian_blur_channel(channel, w, h, sigma)
      for i in 0..<n {
        let log_b = logf_r(if blurred[i] > 0.0F { blurred[i] } else { 1.0F })
        retinex_sum[i] += log_channel[i] - log_b
      }
    }
    let inv_scales = gain / Float::from_int(num_scales)
    for i in 0..<n {
      let retinex = retinex_sum[i] * inv_scales + offset
      write_f32_r(out, (i * ch + c) * 4, retinex)
    }
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== MSRCR 16-bit ==========

///|
/// 带颜色恢复的多尺度 Retinex（MSRCR）16-bit 版本。
pub fn msrcr_16(
  img : @types.Image16,
  sigmas? : Array[Float] = [15.0F, 80.0F, 250.0F],
  gain? : Float = 1.0F,
  offset? : Float = 0.0F,
  alpha? : Float = 125.0F,
  beta? : Float = 46.0F,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("msrcr_16: 图像尺寸必须大于0")
  }
  if img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("msrcr_16 需要 RGB/RGBA 图像")
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "msrcr_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
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
  let out : Array[Byte] = Array::make(n * ch * 2, b'\x00')
  let num_scales = sigmas.length()
  let channels : Array[Array[Float]] = [
    Array::make(n, 0.0F),
    Array::make(n, 0.0F),
    Array::make(n, 0.0F),
  ]
  for c in 0..<3 {
    for i in 0..<n {
      let v = read_u16_r(img.data, (i * ch + c) * 2)
      channels[c][i] = Float::from_int(if v == 0 { 1 } else { v })
    }
  }
  let msr_results : Array[Array[Float]] = [
    Array::make(n, 0.0F),
    Array::make(n, 0.0F),
    Array::make(n, 0.0F),
  ]
  for c in 0..<3 {
    let log_channel : Array[Float] = Array::make(n, 0.0F)
    for i in 0..<n {
      log_channel[i] = logf_r(channels[c][i])
    }
    let retinex_sum : Array[Float] = Array::make(n, 0.0F)
    for sigma in sigmas {
      let blurred = gaussian_blur_channel(channels[c], w, h, sigma)
      for i in 0..<n {
        let log_b = logf_r(if blurred[i] > 0.0F { blurred[i] } else { 1.0F })
        retinex_sum[i] += log_channel[i] - log_b
      }
    }
    let inv_scales = 1.0F / Float::from_int(num_scales)
    for i in 0..<n {
      msr_results[c][i] = retinex_sum[i] * inv_scales
    }
  }
  for i in 0..<n {
    let sum = channels[0][i] + channels[1][i] + channels[2][i]
    for c in 0..<3 {
      let crf = logf_r(alpha * channels[c][i] / (sum + 1.0F)) * beta
      let val = msr_results[c][i] * gain + offset + crf
      let mapped = (val * 30.0F + 32768.0F).to_int()
      let clamped = if mapped < 0 {
        0
      } else if mapped > 65535 {
        65535
      } else {
        mapped
      }
      write_u16_r(out, (i * ch + c) * 2, clamped)
    }
    if ch == 4 {
      let v = read_u16_r(img.data, (i * ch + 3) * 2)
      write_u16_r(out, (i * ch + 3) * 2, v)
    }
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== MSRCR float ==========

///|
/// 带颜色恢复的多尺度 Retinex（MSRCR）float 版本。
pub fn msrcr_f(
  img : @types.ImageF,
  sigmas? : Array[Float] = [15.0F, 80.0F, 250.0F],
  gain? : Float = 1.0F,
  offset? : Float = 0.0F,
  alpha? : Float = 125.0F,
  beta? : Float = 46.0F,
) -> @types.ImageF raise @types.LoadError {
  if img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("msrcr_f 需要 RGB/RGBA 图像")
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
  let out : Array[Byte] = Array::make(n * ch * 4, b'\x00')
  let num_scales = sigmas.length()
  let channels : Array[Array[Float]] = [
    Array::make(n, 0.0F),
    Array::make(n, 0.0F),
    Array::make(n, 0.0F),
  ]
  for c in 0..<3 {
    for i in 0..<n {
      let v = read_f32_r(img.data, (i * ch + c) * 4)
      channels[c][i] = if v <= 0.0F { 0.0001F } else { v }
    }
  }
  let msr_results : Array[Array[Float]] = [
    Array::make(n, 0.0F),
    Array::make(n, 0.0F),
    Array::make(n, 0.0F),
  ]
  for c in 0..<3 {
    let log_channel : Array[Float] = Array::make(n, 0.0F)
    for i in 0..<n {
      log_channel[i] = logf_r(channels[c][i])
    }
    let retinex_sum : Array[Float] = Array::make(n, 0.0F)
    for sigma in sigmas {
      let blurred = gaussian_blur_channel(channels[c], w, h, sigma)
      for i in 0..<n {
        let log_b = logf_r(if blurred[i] > 0.0F { blurred[i] } else { 1.0F })
        retinex_sum[i] += log_channel[i] - log_b
      }
    }
    let inv_scales = 1.0F / Float::from_int(num_scales)
    for i in 0..<n {
      msr_results[c][i] = retinex_sum[i] * inv_scales
    }
  }
  for i in 0..<n {
    let sum = channels[0][i] + channels[1][i] + channels[2][i]
    for c in 0..<3 {
      let crf = logf_r(alpha * channels[c][i] / (sum + 1.0F)) * beta
      let val = msr_results[c][i] * gain + offset + crf
      write_f32_r(out, (i * ch + c) * 4, val)
    }
    if ch == 4 {
      let v = read_f32_r(img.data, (i * ch + 3) * 4)
      write_f32_r(out, (i * ch + 3) * 4, v)
    }
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

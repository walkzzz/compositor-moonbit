// 图像滤波 16-bit/float 变体：box_blur / gaussian_blur / median_blur
// 支持 Image16 / ImageF 两种类型

///|
fn read_u16_le_f(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn write_u16_le_f(buf : Array[Byte], offset : Int, val : Int) -> Unit {
  buf[offset] = (val & 0xFF).to_byte()
  buf[offset + 1] = ((val >> 8) & 0xFF).to_byte()
}

///|
fn read_f32_le_f(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

///|
fn write_f32_le_f(buf : Array[Byte], offset : Int, val : Float) -> Unit {
  let bits = val.reinterpret_as_int()
  buf[offset] = (bits & 0xFF).to_byte()
  buf[offset + 1] = ((bits >> 8) & 0xFF).to_byte()
  buf[offset + 2] = ((bits >> 16) & 0xFF).to_byte()
  buf[offset + 3] = ((bits >> 24) & 0xFF).to_byte()
}

///|
fn clamp_coord_f(v : Int, max : Int) -> Int {
  if v < 0 {
    0
  } else if v >= max {
    max - 1
  } else {
    v
  }
}

///|
/// 16-bit 盒模糊。radius 为模糊半径，窗口大小 = 2*radius+1。
/// 使用可分离滑动窗口，O(n) 复杂度。仅模糊颜色通道，alpha 不变。
pub fn box_blur_16(
  img : @types.Image16,
  radius : Int,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "box_blur_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "box_blur_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "box_blur_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if radius < 0 {
    raise @types.LoadError::DecodeFailed("box_blur_16: radius不能为负")
  }
  if radius <= 0 {
    return img
  }
  let w = img.width
  let h = img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let n = w * h
  let win_size = 2 * radius + 1
  let bpp = ch * 2
  // 水平模糊：img -> temp
  let temp : Array[Int] = Array::make(n * color_ch, 0)
  for y in 0..<h {
    for c in 0..<color_ch {
      let mut sum = 0
      for dx in 0..<win_size {
        let x = clamp_coord_f(dx - radius, w)
        sum += read_u16_le_f(img.data, (y * w + x) * bpp + c * 2)
      }
      for x in 0..<w {
        temp[(y * w + x) * color_ch + c] = sum / win_size
        let x_out = clamp_coord_f(x - radius, w)
        let x_in = clamp_coord_f(x + radius + 1, w)
        sum = sum -
          read_u16_le_f(img.data, (y * w + x_out) * bpp + c * 2) +
          read_u16_le_f(img.data, (y * w + x_in) * bpp + c * 2)
      }
    }
  }
  // 垂直模糊：temp -> out
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for x in 0..<w {
    for c in 0..<color_ch {
      let mut sum = 0
      for dy in 0..<win_size {
        let y = clamp_coord_f(dy - radius, h)
        sum += temp[(y * w + x) * color_ch + c]
      }
      for y in 0..<h {
        write_u16_le_f(out, (y * w + x) * bpp + c * 2, sum / win_size)
        let y_out = clamp_coord_f(y - radius, h)
        let y_in = clamp_coord_f(y + radius + 1, h)
        sum = sum -
          temp[(y_out * w + x) * color_ch + c] +
          temp[(y_in * w + x) * color_ch + c]
      }
    }
  }
  // 复制 alpha
  if ch == 4 {
    for i in 0..<n {
      let alpha_off = i * bpp + 6
      out[alpha_off] = img.data[alpha_off]
      out[alpha_off + 1] = img.data[alpha_off + 1]
    }
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// float 盒模糊。radius 为模糊半径，窗口大小 = 2*radius+1。
/// 使用可分离滑动窗口，O(n) 复杂度。仅模糊颜色通道，alpha 不变。
pub fn box_blur_f(
  img : @types.ImageF,
  radius : Int,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "box_blur_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "box_blur_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "box_blur_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if radius < 0 {
    raise @types.LoadError::DecodeFailed("box_blur_f: radius不能为负")
  }
  if radius <= 0 {
    return img
  }
  let w = img.width
  let h = img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let n = w * h
  let win_size = 2 * radius + 1
  let bpp = ch * 4
  let win_size_f = Float::from_int(win_size)
  // 水平模糊：img -> temp
  let temp : Array[Float] = Array::make(n * color_ch, 0.0F)
  for y in 0..<h {
    for c in 0..<color_ch {
      let mut sum = 0.0F
      for dx in 0..<win_size {
        let x = clamp_coord_f(dx - radius, w)
        sum += read_f32_le_f(img.data, (y * w + x) * bpp + c * 4)
      }
      for x in 0..<w {
        temp[(y * w + x) * color_ch + c] = sum / win_size_f
        let x_out = clamp_coord_f(x - radius, w)
        let x_in = clamp_coord_f(x + radius + 1, w)
        sum = sum -
          read_f32_le_f(img.data, (y * w + x_out) * bpp + c * 4) +
          read_f32_le_f(img.data, (y * w + x_in) * bpp + c * 4)
      }
    }
  }
  // 垂直模糊：temp -> out
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for x in 0..<w {
    for c in 0..<color_ch {
      let mut sum = 0.0F
      for dy in 0..<win_size {
        let y = clamp_coord_f(dy - radius, h)
        sum += temp[(y * w + x) * color_ch + c]
      }
      for y in 0..<h {
        write_f32_le_f(out, (y * w + x) * bpp + c * 4, sum / win_size_f)
        let y_out = clamp_coord_f(y - radius, h)
        let y_in = clamp_coord_f(y + radius + 1, h)
        sum = sum -
          temp[(y_out * w + x) * color_ch + c] +
          temp[(y_in * w + x) * color_ch + c]
      }
    }
  }
  // 复制 alpha
  if ch == 4 {
    for i in 0..<n {
      let alpha_off = i * bpp + 12
      for b in 0..<4 {
        out[alpha_off + b] = img.data[alpha_off + b]
      }
    }
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 16-bit 高斯模糊。radius 为核半径，sigma 为标准差。
/// 使用可分离高斯核，O(n*radius) 复杂度。仅模糊颜色通道，alpha 不变。
pub fn gaussian_blur_16(
  img : @types.Image16,
  radius : Int,
  sigma : Float,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "gaussian_blur_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "gaussian_blur_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "gaussian_blur_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if radius < 0 {
    raise @types.LoadError::DecodeFailed("gaussian_blur_16: radius不能为负")
  }
  if sigma <= 0.0F {
    raise @types.LoadError::DecodeFailed("gaussian_blur_16: sigma必须大于0")
  }
  if radius <= 0 {
    return img
  }
  let w = img.width
  let h = img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let n = w * h
  let win_size = 2 * radius + 1
  let bpp = ch * 2
  // 生成 1D 高斯核
  let kernel : Array[Float] = Array::make(win_size, 0.0F)
  let two_sigma_sq = 2.0F * sigma * sigma
  let mut ksum = 0.0F
  for i in 0..<win_size {
    let x = Float::from_int(i - radius)
    let val = @math.expf(-(x * x) / two_sigma_sq)
    kernel[i] = val
    ksum += val
  }
  for i in 0..<win_size {
    kernel[i] = kernel[i] / ksum
  }
  // 预计算像素 Float 数组
  let src : Array[Float] = Array::make(n * color_ch, 0.0F)
  for i in 0..<n {
    for c in 0..<color_ch {
      src[i * color_ch + c] = Float::from_int(
        read_u16_le_f(img.data, i * bpp + c * 2),
      )
    }
  }
  // 水平模糊：src -> temp (Float)
  let temp : Array[Float] = Array::make(n * color_ch, 0.0F)
  let x_inner_start = if radius >= w { w } else { radius }
  let x_inner_end = if radius >= w { w } else { w - radius }
  for y in 0..<h {
    let row_base = y * w
    for c in 0..<color_ch {
      for x in x_inner_start..<x_inner_end {
        let mut acc = 0.0F
        let base = (row_base + x - radius) * color_ch + c
        for k in 0..<win_size {
          acc += kernel[k] * src[base + k * color_ch]
        }
        temp[(row_base + x) * color_ch + c] = acc
      }
      for x in 0..<x_inner_start {
        let mut acc = 0.0F
        for k in 0..<win_size {
          let sx = clamp_coord_f(x + k - radius, w)
          acc += kernel[k] * src[(row_base + sx) * color_ch + c]
        }
        temp[(row_base + x) * color_ch + c] = acc
      }
      for x in x_inner_end..<w {
        let mut acc = 0.0F
        for k in 0..<win_size {
          let sx = clamp_coord_f(x + k - radius, w)
          acc += kernel[k] * src[(row_base + sx) * color_ch + c]
        }
        temp[(row_base + x) * color_ch + c] = acc
      }
    }
  }
  // 垂直模糊：temp -> out
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let y_inner_start = if radius >= h { h } else { radius }
  let y_inner_end = if radius >= h { h } else { h - radius }
  for x in 0..<w {
    for c in 0..<color_ch {
      for y in y_inner_start..<y_inner_end {
        let mut acc = 0.0F
        let base = ((y - radius) * w + x) * color_ch + c
        for k in 0..<win_size {
          acc += kernel[k] * temp[base + k * w * color_ch]
        }
        let v = (acc + 0.5F).to_int().clamp(min=0, max=65535)
        write_u16_le_f(out, (y * w + x) * bpp + c * 2, v)
      }
      for y in 0..<y_inner_start {
        let mut acc = 0.0F
        for k in 0..<win_size {
          let sy = clamp_coord_f(y + k - radius, h)
          acc += kernel[k] * temp[(sy * w + x) * color_ch + c]
        }
        let v = (acc + 0.5F).to_int().clamp(min=0, max=65535)
        write_u16_le_f(out, (y * w + x) * bpp + c * 2, v)
      }
      for y in y_inner_end..<h {
        let mut acc = 0.0F
        for k in 0..<win_size {
          let sy = clamp_coord_f(y + k - radius, h)
          acc += kernel[k] * temp[(sy * w + x) * color_ch + c]
        }
        let v = (acc + 0.5F).to_int().clamp(min=0, max=65535)
        write_u16_le_f(out, (y * w + x) * bpp + c * 2, v)
      }
    }
  }
  // 复制 alpha
  if ch == 4 {
    for i in 0..<n {
      let alpha_off = i * bpp + 6
      out[alpha_off] = img.data[alpha_off]
      out[alpha_off + 1] = img.data[alpha_off + 1]
    }
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// float 高斯模糊。radius 为核半径，sigma 为标准差。
/// 使用可分离高斯核，O(n*radius) 复杂度。仅模糊颜色通道，alpha 不变。
pub fn gaussian_blur_f(
  img : @types.ImageF,
  radius : Int,
  sigma : Float,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "gaussian_blur_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "gaussian_blur_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "gaussian_blur_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if radius < 0 {
    raise @types.LoadError::DecodeFailed("gaussian_blur_f: radius不能为负")
  }
  if sigma <= 0.0F {
    raise @types.LoadError::DecodeFailed("gaussian_blur_f: sigma必须大于0")
  }
  if radius <= 0 {
    return img
  }
  let w = img.width
  let h = img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let n = w * h
  let win_size = 2 * radius + 1
  let bpp = ch * 4
  // 生成 1D 高斯核
  let kernel : Array[Float] = Array::make(win_size, 0.0F)
  let two_sigma_sq = 2.0F * sigma * sigma
  let mut ksum = 0.0F
  for i in 0..<win_size {
    let x = Float::from_int(i - radius)
    let val = @math.expf(-(x * x) / two_sigma_sq)
    kernel[i] = val
    ksum += val
  }
  for i in 0..<win_size {
    kernel[i] = kernel[i] / ksum
  }
  // 预计算像素 Float 数组
  let src : Array[Float] = Array::make(n * color_ch, 0.0F)
  for i in 0..<n {
    for c in 0..<color_ch {
      src[i * color_ch + c] = read_f32_le_f(img.data, i * bpp + c * 4)
    }
  }
  // 水平模糊：src -> temp (Float)
  let temp : Array[Float] = Array::make(n * color_ch, 0.0F)
  let x_inner_start = if radius >= w { w } else { radius }
  let x_inner_end = if radius >= w { w } else { w - radius }
  for y in 0..<h {
    let row_base = y * w
    for c in 0..<color_ch {
      for x in x_inner_start..<x_inner_end {
        let mut acc = 0.0F
        let base = (row_base + x - radius) * color_ch + c
        for k in 0..<win_size {
          acc += kernel[k] * src[base + k * color_ch]
        }
        temp[(row_base + x) * color_ch + c] = acc
      }
      for x in 0..<x_inner_start {
        let mut acc = 0.0F
        for k in 0..<win_size {
          let sx = clamp_coord_f(x + k - radius, w)
          acc += kernel[k] * src[(row_base + sx) * color_ch + c]
        }
        temp[(row_base + x) * color_ch + c] = acc
      }
      for x in x_inner_end..<w {
        let mut acc = 0.0F
        for k in 0..<win_size {
          let sx = clamp_coord_f(x + k - radius, w)
          acc += kernel[k] * src[(row_base + sx) * color_ch + c]
        }
        temp[(row_base + x) * color_ch + c] = acc
      }
    }
  }
  // 垂直模糊：temp -> out
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let y_inner_start = if radius >= h { h } else { radius }
  let y_inner_end = if radius >= h { h } else { h - radius }
  for x in 0..<w {
    for c in 0..<color_ch {
      for y in y_inner_start..<y_inner_end {
        let mut acc = 0.0F
        let base = ((y - radius) * w + x) * color_ch + c
        for k in 0..<win_size {
          acc += kernel[k] * temp[base + k * w * color_ch]
        }
        write_f32_le_f(out, (y * w + x) * bpp + c * 4, acc)
      }
      for y in 0..<y_inner_start {
        let mut acc = 0.0F
        for k in 0..<win_size {
          let sy = clamp_coord_f(y + k - radius, h)
          acc += kernel[k] * temp[(sy * w + x) * color_ch + c]
        }
        write_f32_le_f(out, (y * w + x) * bpp + c * 4, acc)
      }
      for y in y_inner_end..<h {
        let mut acc = 0.0F
        for k in 0..<win_size {
          let sy = clamp_coord_f(y + k - radius, h)
          acc += kernel[k] * temp[(sy * w + x) * color_ch + c]
        }
        write_f32_le_f(out, (y * w + x) * bpp + c * 4, acc)
      }
    }
  }
  // 复制 alpha
  if ch == 4 {
    for i in 0..<n {
      let alpha_off = i * bpp + 12
      for b in 0..<4 {
        out[alpha_off + b] = img.data[alpha_off + b]
      }
    }
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 16-bit 中值滤波。ksize 为窗口大小（奇数）。有效去除椒盐噪声。
/// 仅滤波颜色通道，alpha 不变。
pub fn median_blur_16(
  img : @types.Image16,
  ksize : Int,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "median_blur_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "median_blur_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "median_blur_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if ksize <= 0 {
    raise @types.LoadError::DecodeFailed("median_blur_16: ksize必须大于0")
  }
  if ksize % 2 == 0 {
    raise @types.LoadError::DecodeFailed("median_blur_16: ksize必须为奇数")
  }
  if ksize <= 1 {
    return img
  }
  let radius = ksize / 2
  let w = img.width
  let h = img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let n = w * h
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let buf : Array[Int] = Array::make(ksize * ksize, 0)
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<color_ch {
        let mut idx = 0
        for dy in -radius..<=radius {
          for dx in -radius..<=radius {
            let sx = clamp_coord_f(x + dx, w)
            let sy = clamp_coord_f(y + dy, h)
            buf[idx] = read_u16_le_f(img.data, (sy * w + sx) * bpp + c * 2)
            idx += 1
          }
        }
        let mid = ksize * ksize / 2
        let mut lo = 0
        let mut hi = ksize * ksize - 1
        while lo < hi {
          let pivot = buf[(lo + hi) / 2]
          let mut i = lo
          let mut j = hi
          while i <= j {
            while buf[i] < pivot {
              i += 1
            }
            while buf[j] > pivot {
              j -= 1
            }
            if i <= j {
              let tmp = buf[i]
              buf[i] = buf[j]
              buf[j] = tmp
              i += 1
              j -= 1
            }
          }
          if mid <= j {
            hi = j
          } else if mid >= i {
            lo = i
          } else {
            lo = mid
            hi = mid
          }
        }
        write_u16_le_f(out, (y * w + x) * bpp + c * 2, buf[mid])
      }
    }
  }
  // 复制 alpha
  if ch == 4 {
    for i in 0..<n {
      let alpha_off = i * bpp + 6
      out[alpha_off] = img.data[alpha_off]
      out[alpha_off + 1] = img.data[alpha_off + 1]
    }
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// float 中值滤波。ksize 为窗口大小（奇数）。有效去除椒盐噪声。
/// 仅滤波颜色通道，alpha 不变。
pub fn median_blur_f(
  img : @types.ImageF,
  ksize : Int,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "median_blur_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "median_blur_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "median_blur_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if ksize <= 0 {
    raise @types.LoadError::DecodeFailed("median_blur_f: ksize必须大于0")
  }
  if ksize % 2 == 0 {
    raise @types.LoadError::DecodeFailed("median_blur_f: ksize必须为奇数")
  }
  if ksize <= 1 {
    return img
  }
  let radius = ksize / 2
  let w = img.width
  let h = img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let n = w * h
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let buf : Array[Float] = Array::make(ksize * ksize, 0.0F)
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<color_ch {
        let mut idx = 0
        for dy in -radius..<=radius {
          for dx in -radius..<=radius {
            let sx = clamp_coord_f(x + dx, w)
            let sy = clamp_coord_f(y + dy, h)
            buf[idx] = read_f32_le_f(img.data, (sy * w + sx) * bpp + c * 4)
            idx += 1
          }
        }
        // 完整排序找中值（Float 需要完整排序）
        let total = ksize * ksize
        for i in 0..<total {
          for j in 0..<(total - i - 1) {
            if buf[j] > buf[j + 1] {
              let tmp = buf[j]
              buf[j] = buf[j + 1]
              buf[j + 1] = tmp
            }
          }
        }
        write_f32_le_f(out, (y * w + x) * bpp + c * 4, buf[total / 2])
      }
    }
  }
  // 复制 alpha
  if ch == 4 {
    for i in 0..<n {
      let alpha_off = i * bpp + 12
      for b in 0..<4 {
        out[alpha_off + b] = img.data[alpha_off + b]
      }
    }
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 16-bit 锐化。amount 控制锐化强度（0.0=原图，1.0=强锐化）。
pub fn sharpen_16(
  img : @types.Image16,
  amount : Float,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "sharpen_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "sharpen_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "sharpen_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if amount < 0.0F {
    raise @types.LoadError::DecodeFailed("sharpen_16: amount不能为负")
  }

  let w = img.width
  let h = img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let n = w * h
  let bpp = ch * 2
  let center = 1.0F + 4.0F * amount
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let px : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<n {
    for c in 0..<ch {
      px[i * ch + c] = read_u16_le_f(img.data, i * bpp + c * 2)
    }
  }
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      for c in 0..<color_ch {
        let cx = px[idx * ch + c]
        let left = px[(idx - 1) * ch + c]
        let right = px[(idx + 1) * ch + c]
        let top = px[(idx - w) * ch + c]
        let bottom = px[(idx + w) * ch + c]
        let val = Float::from_int(cx) * center -
          amount * Float::from_int(left + right + top + bottom)
        let new_val = (val + 0.5F).to_int()
        let clamped = if new_val < 0 {
          0
        } else if new_val > 65535 {
          65535
        } else {
          new_val
        }
        write_u16_le_f(out, idx * bpp + c * 2, clamped)
      }
    }
  }
  for y in 0..<h {
    for x in 0..<w {
      if x >= 1 && x < w - 1 && y >= 1 && y < h - 1 {
        continue
      }
      let idx = y * w + x
      let x_l = clamp_coord_f(x - 1, w)
      let x_r = clamp_coord_f(x + 1, w)
      let y_t = clamp_coord_f(y - 1, h)
      let y_b = clamp_coord_f(y + 1, h)
      for c in 0..<color_ch {
        let cx = px[idx * ch + c]
        let left = px[(y * w + x_l) * ch + c]
        let right = px[(y * w + x_r) * ch + c]
        let top = px[(y_t * w + x) * ch + c]
        let bottom = px[(y_b * w + x) * ch + c]
        let val = Float::from_int(cx) * center -
          amount * Float::from_int(left + right + top + bottom)
        let new_val = (val + 0.5F).to_int()
        let clamped = if new_val < 0 {
          0
        } else if new_val > 65535 {
          65535
        } else {
          new_val
        }
        write_u16_le_f(out, idx * bpp + c * 2, clamped)
      }
    }
  }
  if ch == 4 {
    for i in 0..<n {
      let alpha_off = i * bpp + 6
      out[alpha_off] = img.data[alpha_off]
      out[alpha_off + 1] = img.data[alpha_off + 1]
    }
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// float 锐化。amount 控制锐化强度（0.0=原图，1.0=强锐化）。
pub fn sharpen_f(
  img : @types.ImageF,
  amount : Float,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("sharpen_f: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "sharpen_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "sharpen_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if amount < 0.0F {
    raise @types.LoadError::DecodeFailed("sharpen_f: amount不能为负")
  }

  let w = img.width
  let h = img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let n = w * h
  let bpp = ch * 4
  let center = 1.0F + 4.0F * amount
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let px : Array[Float] = Array::make(n * ch, 0.0F)
  for i in 0..<n {
    for c in 0..<ch {
      px[i * ch + c] = read_f32_le_f(img.data, i * bpp + c * 4)
    }
  }
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      for c in 0..<color_ch {
        let cx = px[idx * ch + c]
        let left = px[(idx - 1) * ch + c]
        let right = px[(idx + 1) * ch + c]
        let top = px[(idx - w) * ch + c]
        let bottom = px[(idx + w) * ch + c]
        let val = cx * center - amount * (left + right + top + bottom)
        write_f32_le_f(out, idx * bpp + c * 4, val)
      }
    }
  }
  for y in 0..<h {
    for x in 0..<w {
      if x >= 1 && x < w - 1 && y >= 1 && y < h - 1 {
        continue
      }
      let idx = y * w + x
      let x_l = clamp_coord_f(x - 1, w)
      let x_r = clamp_coord_f(x + 1, w)
      let y_t = clamp_coord_f(y - 1, h)
      let y_b = clamp_coord_f(y + 1, h)
      for c in 0..<color_ch {
        let cx = px[idx * ch + c]
        let left = px[(y * w + x_l) * ch + c]
        let right = px[(y * w + x_r) * ch + c]
        let top = px[(y_t * w + x) * ch + c]
        let bottom = px[(y_b * w + x) * ch + c]
        let val = cx * center - amount * (left + right + top + bottom)
        write_f32_le_f(out, idx * bpp + c * 4, val)
      }
    }
  }
  if ch == 4 {
    for i in 0..<n {
      let alpha_off = i * bpp + 12
      for b in 0..<4 {
        out[alpha_off + b] = img.data[alpha_off + b]
      }
    }
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// Canny 边缘检测 16-bit/float 变体
// 支持 Image16 / ImageF 两种类型

// ========== 辅助函数 ==========

///|
fn read_u16_le_c(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn write_u16_le_c(buf : Array[Byte], offset : Int, val : Int) -> Unit {
  buf[offset] = (val & 0xFF).to_byte()
  buf[offset + 1] = ((val >> 8) & 0xFF).to_byte()
}

///|
fn read_float_le_c(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

///|
fn write_f32_le_c(buf : Array[Byte], offset : Int, val : Float) -> Unit {
  let bits = val.reinterpret_as_int()
  buf[offset] = (bits & 0xFF).to_byte()
  buf[offset + 1] = ((bits >> 8) & 0xFF).to_byte()
  buf[offset + 2] = ((bits >> 16) & 0xFF).to_byte()
  buf[offset + 3] = ((bits >> 24) & 0xFF).to_byte()
}

///|
fn clamp_int_c(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

// 5x5 高斯模糊 (sigma=1.0)

///|
fn canny_gaussian_blur_16(gray : Array[Int], w : Int, h : Int) -> Array[Int] {
  let n = w * h
  let out : Array[Int] = Array::make(n, 0)
  let kernel : Array[Int] = [
    2, 4, 5, 4, 2, 4, 9, 12, 9, 4, 5, 12, 15, 12, 5, 4, 9, 12, 9, 4, 2, 4, 5, 4,
    2,
  ]
  let kernel_sum = 159
  for y in 2..<(h - 2) {
    for x in 2..<(w - 2) {
      let mut sum = 0
      let base = (y - 2) * w + (x - 2)
      for ky in 0..<5 {
        let row = base + ky * w
        let krow = ky * 5
        for kx in 0..<5 {
          sum += gray[row + kx] * kernel[krow + kx]
        }
      }
      out[y * w + x] = sum / kernel_sum
    }
  }
  for y in 0..<h {
    let y_inner = y >= 2 && y < h - 2
    for x in 0..<w {
      if y_inner && x >= 2 && x < w - 2 {
        continue
      }
      let mut sum = 0
      for ky in 0..<5 {
        for kx in 0..<5 {
          let px = clamp_int_c(x + kx - 2, 0, w - 1)
          let py = clamp_int_c(y + ky - 2, 0, h - 1)
          sum += gray[py * w + px] * kernel[ky * 5 + kx]
        }
      }
      out[y * w + x] = sum / kernel_sum
    }
  }
  out
}

// ========== 16-bit Canny ==========

///|
/// 16-bit Canny 边缘检测。阈值范围 0-65535，输出二值图像（0/65535）。
pub fn canny_edge_16(
  img : @types.Image16,
  low_threshold? : Int = 12800,
  high_threshold? : Int = 25600,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "canny_edge_16: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "canny_edge_16: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "canny_edge_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if low_threshold < 0 || low_threshold > 65535 {
    raise @types.LoadError::DecodeFailed(
      "low_threshold 必须在 0..65535 之间",
    )
  }
  if high_threshold < 0 || high_threshold > 65535 {
    raise @types.LoadError::DecodeFailed(
      "high_threshold 必须在 0..65535 之间",
    )
  }
  if low_threshold > high_threshold {
    raise @types.LoadError::DecodeFailed("low_threshold 应 <= high_threshold")
  }
  let w = img.width
  let h = img.height
  let n = w * h
  if n == 0 {
    return img
  }
  let ch = img.channels
  let bpp = ch * 2
  // 转灰度
  let gray : Array[Int] = Array::make(n, 0)
  for i in 0..<n {
    if ch == 1 {
      gray[i] = read_u16_le_c(img.data, i * 2)
    } else {
      let r = read_u16_le_c(img.data, i * bpp)
      let g = read_u16_le_c(img.data, i * bpp + 2)
      let b = read_u16_le_c(img.data, i * bpp + 4)
      gray[i] = (r * 299 + g * 587 + b * 114) / 1000
    }
  }
  // 1. 高斯模糊
  let blurred = canny_gaussian_blur_16(gray, w, h)
  // 2. Sobel 梯度
  let gradient : Array[Int] = Array::make(n, 0)
  let direction : Array[Int] = Array::make(n, 0)
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let gx = -blurred[(y - 1) * w + (x - 1)] -
        2 * blurred[y * w + (x - 1)] -
        blurred[(y + 1) * w + (x - 1)] +
        blurred[(y - 1) * w + (x + 1)] +
        2 * blurred[y * w + (x + 1)] +
        blurred[(y + 1) * w + (x + 1)]
      let gy = -blurred[(y - 1) * w + (x - 1)] -
        2 * blurred[(y - 1) * w + x] -
        blurred[(y - 1) * w + (x + 1)] +
        blurred[(y + 1) * w + (x - 1)] +
        2 * blurred[(y + 1) * w + x] +
        blurred[(y + 1) * w + (x + 1)]
      let mag = Float::from_int(gx * gx + gy * gy).sqrt().to_int()
      gradient[idx] = mag
      let angle = @math.atan2f(Float::from_int(gy), Float::from_int(gx)) *
        180.0F /
        3.14159265F
      let norm_angle = if angle < 0.0F { angle + 180.0F } else { angle }
      direction[idx] = if norm_angle < 22.5F || norm_angle >= 157.5F {
        0
      } else if norm_angle < 67.5F {
        1
      } else if norm_angle < 112.5F {
        2
      } else {
        3
      }
    }
  }
  // 3. 非极大值抑制
  let nms : Array[Int] = Array::make(n, 0)
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let mag = gradient[idx]
      if mag == 0 {
        continue
      }
      let dir = direction[idx]
      let (n1, n2) = match dir {
        0 => (gradient[idx - 1], gradient[idx + 1])
        1 => (gradient[(y - 1) * w + (x + 1)], gradient[(y + 1) * w + (x - 1)])
        2 => (gradient[(y - 1) * w + x], gradient[(y + 1) * w + x])
        _ => (gradient[(y - 1) * w + (x - 1)], gradient[(y + 1) * w + (x + 1)])
      }
      if mag >= n1 && mag >= n2 {
        nms[idx] = mag
      }
    }
  }
  // 4. 双阈值 + 滞后连接
  let out : Array[Byte] = Array::make(n * 2, b'\x00')
  let strong : Array[Bool] = Array::make(n, false)
  let weak : Array[Bool] = Array::make(n, false)
  for i in 0..<n {
    if nms[i] >= high_threshold {
      strong[i] = true
    } else if nms[i] >= low_threshold {
      weak[i] = true
    }
  }
  let stack : Array[Int] = []
  for i in 0..<n {
    if strong[i] {
      write_u16_le_c(out, i * 2, 65535)
      stack.push(i)
    }
  }
  while stack.length() > 0 {
    let idx = stack.remove(stack.length() - 1)
    let x = idx % w
    let y = idx / w
    for dy in -1..<=1 {
      for dx in -1..<=1 {
        if dx == 0 && dy == 0 {
          continue
        }
        let nx = x + dx
        let ny = y + dy
        if nx >= 0 && nx < w && ny >= 0 && ny < h {
          let nidx = ny * w + nx
          if weak[nidx] && !strong[nidx] {
            strong[nidx] = true
            write_u16_le_c(out, nidx * 2, 65535)
            stack.push(nidx)
          }
        }
      }
    }
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

// ========== float Canny ==========

///|
/// float Canny 边缘检测。阈值范围 0.0-1.0，输出二值图像（0.0/1.0）。
pub fn canny_edge_f(
  img : @types.ImageF,
  low_threshold? : Float = 0.2F,
  high_threshold? : Float = 0.4F,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "canny_edge_f: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "canny_edge_f: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "canny_edge_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if low_threshold < 0.0F || low_threshold > 1.0F {
    raise @types.LoadError::DecodeFailed(
      "low_threshold 必须在 0.0..1.0 之间",
    )
  }
  if high_threshold < 0.0F || high_threshold > 1.0F {
    raise @types.LoadError::DecodeFailed(
      "high_threshold 必须在 0.0..1.0 之间",
    )
  }
  if low_threshold > high_threshold {
    raise @types.LoadError::DecodeFailed("low_threshold 应 <= high_threshold")
  }
  let w = img.width
  let h = img.height
  let n = w * h
  if n == 0 {
    return img
  }
  let ch = img.channels
  let bpp = ch * 4
  // 转灰度
  let gray : Array[Float] = Array::make(n, 0.0F)
  for i in 0..<n {
    if ch == 1 {
      gray[i] = read_float_le_c(img.data, i * 4)
    } else {
      let r = read_float_le_c(img.data, i * bpp)
      let g = read_float_le_c(img.data, i * bpp + 4)
      let b = read_float_le_c(img.data, i * bpp + 8)
      gray[i] = r * 0.299F + g * 0.587F + b * 0.114F
    }
  }
  // 1. 高斯模糊 (5x5, sigma=1.0)
  let blurred : Array[Float] = Array::make(n, 0.0F)
  let kernel : Array[Float] = [
    2.0F, 4.0F, 5.0F, 4.0F, 2.0F, 4.0F, 9.0F, 12.0F, 9.0F, 4.0F, 5.0F, 12.0F, 15.0F,
    12.0F, 5.0F, 4.0F, 9.0F, 12.0F, 9.0F, 4.0F, 2.0F, 4.0F, 5.0F, 4.0F, 2.0F,
  ]
  let kernel_sum = 159.0F
  for y in 2..<(h - 2) {
    for x in 2..<(w - 2) {
      let mut sum = 0.0F
      let base = (y - 2) * w + (x - 2)
      for ky in 0..<5 {
        let row = base + ky * w
        let krow = ky * 5
        for kx in 0..<5 {
          sum += gray[row + kx] * kernel[krow + kx]
        }
      }
      blurred[y * w + x] = sum / kernel_sum
    }
  }
  for y in 0..<h {
    let y_inner = y >= 2 && y < h - 2
    for x in 0..<w {
      if y_inner && x >= 2 && x < w - 2 {
        continue
      }
      let mut sum = 0.0F
      for ky in 0..<5 {
        for kx in 0..<5 {
          let px = clamp_int_c(x + kx - 2, 0, w - 1)
          let py = clamp_int_c(y + ky - 2, 0, h - 1)
          sum += gray[py * w + px] * kernel[ky * 5 + kx]
        }
      }
      blurred[y * w + x] = sum / kernel_sum
    }
  }
  // 2. Sobel 梯度
  let gradient : Array[Float] = Array::make(n, 0.0F)
  let direction : Array[Int] = Array::make(n, 0)
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let gx = -blurred[(y - 1) * w + (x - 1)] -
        2.0F * blurred[y * w + (x - 1)] -
        blurred[(y + 1) * w + (x - 1)] +
        blurred[(y - 1) * w + (x + 1)] +
        2.0F * blurred[y * w + (x + 1)] +
        blurred[(y + 1) * w + (x + 1)]
      let gy = -blurred[(y - 1) * w + (x - 1)] -
        2.0F * blurred[(y - 1) * w + x] -
        blurred[(y - 1) * w + (x + 1)] +
        blurred[(y + 1) * w + (x - 1)] +
        2.0F * blurred[(y + 1) * w + x] +
        blurred[(y + 1) * w + (x + 1)]
      let mag = (gx * gx + gy * gy).sqrt()
      gradient[idx] = mag
      let angle = @math.atan2f(gy, gx) * 180.0F / 3.14159265F
      let norm_angle = if angle < 0.0F { angle + 180.0F } else { angle }
      direction[idx] = if norm_angle < 22.5F || norm_angle >= 157.5F {
        0
      } else if norm_angle < 67.5F {
        1
      } else if norm_angle < 112.5F {
        2
      } else {
        3
      }
    }
  }
  // 3. 非极大值抑制
  let nms : Array[Float] = Array::make(n, 0.0F)
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let mag = gradient[idx]
      if mag == 0.0F {
        continue
      }
      let dir = direction[idx]
      let (n1, n2) = match dir {
        0 => (gradient[idx - 1], gradient[idx + 1])
        1 => (gradient[(y - 1) * w + (x + 1)], gradient[(y + 1) * w + (x - 1)])
        2 => (gradient[(y - 1) * w + x], gradient[(y + 1) * w + x])
        _ => (gradient[(y - 1) * w + (x - 1)], gradient[(y + 1) * w + (x + 1)])
      }
      if mag >= n1 && mag >= n2 {
        nms[idx] = mag
      }
    }
  }
  // 4. 双阈值 + 滞后连接
  let out : Array[Byte] = Array::make(n * 4, b'\x00')
  let strong : Array[Bool] = Array::make(n, false)
  let weak : Array[Bool] = Array::make(n, false)
  for i in 0..<n {
    if nms[i] >= high_threshold {
      strong[i] = true
    } else if nms[i] >= low_threshold {
      weak[i] = true
    }
  }
  let stack : Array[Int] = []
  for i in 0..<n {
    if strong[i] {
      write_f32_le_c(out, i * 4, 1.0F)
      stack.push(i)
    }
  }
  while stack.length() > 0 {
    let idx = stack.remove(stack.length() - 1)
    let x = idx % w
    let y = idx / w
    for dy in -1..<=1 {
      for dx in -1..<=1 {
        if dx == 0 && dy == 0 {
          continue
        }
        let nx = x + dx
        let ny = y + dy
        if nx >= 0 && nx < w && ny >= 0 && ny < h {
          let nidx = ny * w + nx
          if weak[nidx] && !strong[nidx] {
            strong[nidx] = true
            write_f32_le_c(out, nidx * 4, 1.0F)
            stack.push(nidx)
          }
        }
      }
    }
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

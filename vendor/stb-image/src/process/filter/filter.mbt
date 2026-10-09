// 图像滤波/卷积（纯 MoonBit）
// box_blur / gaussian_blur / sharpen / convolve

///|
fn clamp_coord(v : Int, max : Int) -> Int {
  if v < 0 {
    0
  } else if v >= max {
    max - 1
  } else {
    v
  }
}

///|
fn clamp_b(v : Int) -> Byte {
  if v < 0 {
    b'\x00'
  } else if v > 255 {
    b'\xFF'
  } else {
    v.to_byte()
  }
}

///|
fn clamp_int(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
/// 盒模糊（均值滤波）。radius 为模糊半径，窗口大小 = 2*radius+1。
/// 使用可分离滑动窗口，O(n) 复杂度。仅模糊颜色通道，alpha 不变。
pub fn box_blur(
  img : @types.Image,
  radius : Int,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("box_blur: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "box_blur: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "box_blur: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if radius < 0 {
    raise @types.LoadError::DecodeFailed("box_blur: radius不能为负")
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
  // 水平模糊：img -> temp
  let temp : Array[Int] = Array::make(n * color_ch, 0)
  for y in 0..<h {
    for c in 0..<color_ch {
      let mut sum = 0
      for dx in 0..<win_size {
        let x = clamp_coord(dx - radius, w)
        sum += img.data[(y * w + x) * ch + c].to_int()
      }
      for x in 0..<w {
        temp[(y * w + x) * color_ch + c] = sum / win_size
        let x_out = clamp_coord(x - radius, w)
        let x_in = clamp_coord(x + radius + 1, w)
        sum = sum -
          img.data[(y * w + x_out) * ch + c].to_int() +
          img.data[(y * w + x_in) * ch + c].to_int()
      }
    }
  }
  // 垂直模糊：temp -> out
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  for x in 0..<w {
    for c in 0..<color_ch {
      let mut sum = 0
      for dy in 0..<win_size {
        let y = clamp_coord(dy - radius, h)
        sum += temp[(y * w + x) * color_ch + c]
      }
      for y in 0..<h {
        out[(y * w + x) * ch + c] = (sum / win_size).to_byte()
        let y_out = clamp_coord(y - radius, h)
        let y_in = clamp_coord(y + radius + 1, h)
        sum = sum -
          temp[(y_out * w + x) * color_ch + c] +
          temp[(y_in * w + x) * color_ch + c]
      }
    }
  }
  // 复制 alpha
  if ch == 4 {
    for i in 0..<n {
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
/// 高斯模糊。radius 为核半径，sigma 为标准差。
/// 使用可分离高斯核，O(n*radius) 复杂度。仅模糊颜色通道，alpha 不变。
pub fn gaussian_blur(
  img : @types.Image,
  radius : Int,
  sigma : Float,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "gaussian_blur: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "gaussian_blur: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "gaussian_blur: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if radius < 0 {
    raise @types.LoadError::DecodeFailed("gaussian_blur: radius不能为负")
  }
  if sigma <= 0.0F {
    raise @types.LoadError::DecodeFailed("gaussian_blur: sigma必须大于0")
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
  // 归一化
  for i in 0..<win_size {
    kernel[i] = kernel[i] / ksum
  }
  // 预计算像素 Float 数组，避免内层循环重复类型转换
  let src : Array[Float] = Array::make(n * color_ch, 0.0F)
  for i in 0..<n {
    for c in 0..<color_ch {
      src[i * color_ch + c] = Float::from_int(img.data[i * ch + c].to_int())
    }
  }
  // 水平模糊：src -> temp (Float)，分离内部/边界区域
  let temp : Array[Float] = Array::make(n * color_ch, 0.0F)
  let x_inner_start = if radius >= w { w } else { radius }
  let x_inner_end = if radius >= w { w } else { w - radius }
  for y in 0..<h {
    let row_base = y * w
    for c in 0..<color_ch {
      // 内部区域：x >= radius && x < w - radius，无需 clamp_coord
      for x in x_inner_start..<x_inner_end {
        let mut acc = 0.0F
        let base = (row_base + x - radius) * color_ch + c
        for k in 0..<win_size {
          acc += kernel[k] * src[base + k * color_ch]
        }
        temp[(row_base + x) * color_ch + c] = acc
      }
      // 左边界：x < radius
      for x in 0..<x_inner_start {
        let mut acc = 0.0F
        for k in 0..<win_size {
          let sx = clamp_coord(x + k - radius, w)
          acc += kernel[k] * src[(row_base + sx) * color_ch + c]
        }
        temp[(row_base + x) * color_ch + c] = acc
      }
      // 右边界：x >= w - radius
      for x in x_inner_end..<w {
        let mut acc = 0.0F
        for k in 0..<win_size {
          let sx = clamp_coord(x + k - radius, w)
          acc += kernel[k] * src[(row_base + sx) * color_ch + c]
        }
        temp[(row_base + x) * color_ch + c] = acc
      }
    }
  }
  // 垂直模糊：temp -> out，分离内部/边界区域
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  let y_inner_start = if radius >= h { h } else { radius }
  let y_inner_end = if radius >= h { h } else { h - radius }
  for x in 0..<w {
    for c in 0..<color_ch {
      // 内部区域：y >= radius && y < h - radius
      for y in y_inner_start..<y_inner_end {
        let mut acc = 0.0F
        let base = ((y - radius) * w + x) * color_ch + c
        for k in 0..<win_size {
          acc += kernel[k] * temp[base + k * w * color_ch]
        }
        out[(y * w + x) * ch + c] = (acc + 0.5F)
          .to_int()
          .clamp(min=0, max=255)
          .to_byte()
      }
      // 上边界：y < radius
      for y in 0..<y_inner_start {
        let mut acc = 0.0F
        for k in 0..<win_size {
          let sy = clamp_coord(y + k - radius, h)
          acc += kernel[k] * temp[(sy * w + x) * color_ch + c]
        }
        out[(y * w + x) * ch + c] = (acc + 0.5F)
          .to_int()
          .clamp(min=0, max=255)
          .to_byte()
      }
      // 下边界：y >= h - radius
      for y in y_inner_end..<h {
        let mut acc = 0.0F
        for k in 0..<win_size {
          let sy = clamp_coord(y + k - radius, h)
          acc += kernel[k] * temp[(sy * w + x) * color_ch + c]
        }
        out[(y * w + x) * ch + c] = (acc + 0.5F)
          .to_int()
          .clamp(min=0, max=255)
          .to_byte()
      }
    }
  }
  // 复制 alpha
  if ch == 4 {
    for i in 0..<n {
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
/// 锐化。amount 控制锐化强度（0.0=原图，1.0=强锐化）。
/// 使用拉普拉斯锐化卷积核。仅处理颜色通道，alpha 不变。
pub fn sharpen(
  img : @types.Image,
  amount : Float,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("sharpen: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed("sharpen: 通道数必须在1-4之间")
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "sharpen: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if amount < 0.0F {
    raise @types.LoadError::DecodeFailed("sharpen: amount不能为负")
  }

  let w = img.width
  let h = img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let n = w * h
  let center = 1.0F + 4.0F * amount
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  // 预计算像素 Int 数组
  let px : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    px[i] = img.data[i].to_int()
  }
  // 内部区域：1 <= x < w-1 && 1 <= y < h-1，无需 clamp_coord
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let base = (y * w + x) * ch
      let base_l = base - ch
      let base_r = base + ch
      let base_t = base - w * ch
      let base_b = base + w * ch
      for c in 0..<color_ch {
        let cx = px[base + c]
        let left = px[base_l + c]
        let right = px[base_r + c]
        let top = px[base_t + c]
        let bottom = px[base_b + c]
        let val = Float::from_int(cx) * center -
          amount * Float::from_int(left + right + top + bottom)
        out[base + c] = (val + 0.5F).to_int().clamp(min=0, max=255).to_byte()
      }
    }
  }
  // 边界区域：x==0 || x==w-1 || y==0 || y==h-1
  for y in 0..<h {
    for x in 0..<w {
      if x >= 1 && x < w - 1 && y >= 1 && y < h - 1 {
        continue
      }
      let base = (y * w + x) * ch
      for c in 0..<color_ch {
        let cx = px[base + c]
        let x_l = clamp_coord(x - 1, w)
        let x_r = clamp_coord(x + 1, w)
        let y_t = clamp_coord(y - 1, h)
        let y_b = clamp_coord(y + 1, h)
        let left = px[(y * w + x_l) * ch + c]
        let right = px[(y * w + x_r) * ch + c]
        let top = px[(y_t * w + x) * ch + c]
        let bottom = px[(y_b * w + x) * ch + c]
        let val = Float::from_int(cx) * center -
          amount * Float::from_int(left + right + top + bottom)
        out[base + c] = (val + 0.5F).to_int().clamp(min=0, max=255).to_byte()
      }
    }
  }
  // 复制 alpha
  if ch == 4 {
    for i in 0..<n {
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
/// 中值滤波。ksize 为窗口大小（奇数）。有效去除椒盐噪声。
/// 对每个像素，取 ksize×ksize 邻域的中值。仅滤波颜色通道，alpha 不变。
pub fn median_blur(
  img : @types.Image,
  ksize : Int,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "median_blur: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "median_blur: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "median_blur: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if ksize <= 0 {
    raise @types.LoadError::DecodeFailed("median_blur: ksize必须大于0")
  }
  if ksize % 2 == 0 {
    raise @types.LoadError::DecodeFailed("median_blur: ksize必须为奇数")
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
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  let buf : Array[Int] = Array::make(ksize * ksize, 0)
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<color_ch {
        let mut idx = 0
        for dy in -radius..<=radius {
          for dx in -radius..<=radius {
            let sx = clamp_coord(x + dx, w)
            let sy = clamp_coord(y + dy, h)
            buf[idx] = img.data[(sy * w + sx) * ch + c].to_int()
            idx += 1
          }
        }
        // 部分排序找中值（不需要完整排序）
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
        out[(y * w + x) * ch + c] = buf[mid].to_byte()
      }
    }
  }
  // 复制 alpha
  if ch == 4 {
    for i in 0..<n {
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
/// 通用卷积。kernel 为 3×3 卷积核（9 个 Float 值，行优先）。
/// 边缘采用 clamp 策略。bias 为偏移量，scale 为缩放因子。
pub fn convolve(
  img : @types.Image,
  kernel : Array[Float],
  bias : Float,
  scale : Float,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("convolve: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "convolve: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "convolve: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if kernel.length() != 9 {
    raise @types.LoadError::DecodeFailed(
      "convolve: kernel 必须为 9 个值（3x3）",
    )
  }
  if scale == 0.0F {
    raise @types.LoadError::DecodeFailed("convolve: scale不能为0")
  }
  let ch = img.channels
  let w = img.width
  let h = img.height
  let color_ch = if ch >= 3 { 3 } else { ch }
  let out : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<color_ch {
        let mut acc = 0.0F
        for ky in 0..<3 {
          for kx in 0..<3 {
            let sx = clamp_int(x + kx - 1, 0, w - 1)
            let sy = clamp_int(y + ky - 1, 0, h - 1)
            let v = Float::from_int(img.data[(sy * w + sx) * ch + c].to_int())
            acc += kernel[ky * 3 + kx] * v
          }
        }
        let result = (acc * scale + bias).to_int()
        out[(y * w + x) * ch + c] = clamp_b(result)
      }
      if ch == 4 {
        out[(y * w + x) * ch + 3] = img.data[(y * w + x) * ch + 3]
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

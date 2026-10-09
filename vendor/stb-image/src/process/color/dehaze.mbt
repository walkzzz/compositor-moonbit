// 暗通道先验去雾（纯 MoonBit）

///|
/// 暗通道先验去雾（Dark Channel Prior Dehaze）。
/// 基于 He et al. (2009) 的暗通道先验方法。
/// 适用于 RGB/RGBA 图像（channels=3/4）。
/// patch_size 为暗通道计算窗口半径（默认 7），omega 为去雾强度（默认 0.95），
/// t0 为透射率下限（默认 0.1）。
pub fn dehaze(
  img : @types.Image,
  patch_size? : Int = 7,
  omega? : Float = 0.95F,
  t0? : Float = 0.1F,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width < 0 || img.height < 0 {
    raise @types.LoadError::DecodeFailed("dehaze: 图像尺寸不能为负")
  }
  if img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("dehaze 需要 RGB/RGBA 图像")
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "dehaze: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if patch_size < 1 || patch_size > 30 {
    raise @types.LoadError::DecodeFailed("patch_size 必须在 1..30 之间")
  }
  if omega <= 0.0F || omega > 1.0F {
    raise @types.LoadError::DecodeFailed("omega 必须在 (0, 1] 之间")
  }
  if t0 <= 0.0F || t0 > 1.0F {
    raise @types.LoadError::DecodeFailed("t0 必须在 (0, 1] 之间")
  }
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  if n == 0 {
    return img
  }
  // 1. 计算暗通道
  let dark_channel = compute_dark_channel(img, w, h, ch, patch_size)
  // 2. 估计大气光 A（取暗通道中最亮的 0.1% 像素对应的原图最亮像素）
  let a = estimate_atmospheric_light(img, dark_channel, w, h, ch)
  let ar = Float::from_int(a[0])
  let ag = Float::from_int(a[1])
  let ab = Float::from_int(a[2])
  // 3. 计算透射率 t = 1 - omega * dark(I/A)
  let transmission : Array[Float] = Array::make(n, 0.0F)
  for i in 0..<n {
    transmission[i] = 1.0F - omega * dark_channel[i]
    if transmission[i] < t0 {
      transmission[i] = t0
    }
  }
  // 4. 恢复无雾图像: J = (I - A) / t + A
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  for i in 0..<n {
    for c in 0..<3 {
      let iv = Float::from_int(img.data[i * ch + c].to_int())
      let ac = if c == 0 { ar } else if c == 1 { ag } else { ab }
      let jv = (iv - ac) / transmission[i] + ac
      out[i * ch + c] = jv.to_int().clamp(min=0, max=255).to_byte()
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
/// 计算暗通道
fn compute_dark_channel(
  img : @types.Image,
  w : Int,
  h : Int,
  ch : Int,
  patch_size : Int,
) -> Array[Float] {
  let n = w * h
  // 先计算每个像素的最小通道值
  let min_channel : Array[Int] = Array::make(n, 255)
  for i in 0..<n {
    let r = img.data[i * ch].to_int()
    let g = img.data[i * ch + 1].to_int()
    let b = img.data[i * ch + 2].to_int()
    min_channel[i] = r.min(g).min(b)
  }
  // 最小值滤波，分离内部/边界区域
  let dark : Array[Float] = Array::make(n, 0.0F)
  // 内部区域：x in [patch_size, w-patch_size), y in [patch_size, h-patch_size)
  for y in patch_size..<(h - patch_size) {
    for x in patch_size..<(w - patch_size) {
      let mut min_val = 255
      for py in (y - patch_size)..<=(y + patch_size) {
        for px in (x - patch_size)..<=(x + patch_size) {
          if min_channel[py * w + px] < min_val {
            min_val = min_channel[py * w + px]
          }
        }
      }
      dark[y * w + x] = Float::from_int(min_val) / 255.0F
    }
  }
  // 边界区域
  for y in 0..<h {
    let y_inner = y >= patch_size && y < h - patch_size
    for x in 0..<w {
      if y_inner && x >= patch_size && x < w - patch_size {
        continue
      }
      let mut min_val = 255
      let y_start = (y - patch_size).clamp(min=0, max=h - 1)
      let y_end = (y + patch_size).clamp(min=0, max=h - 1)
      let x_start = (x - patch_size).clamp(min=0, max=w - 1)
      let x_end = (x + patch_size).clamp(min=0, max=w - 1)
      for py in y_start..<=y_end {
        for px in x_start..<=x_end {
          if min_channel[py * w + px] < min_val {
            min_val = min_channel[py * w + px]
          }
        }
      }
      dark[y * w + x] = Float::from_int(min_val) / 255.0F
    }
  }
  dark
}

///|
/// 估计大气光
fn estimate_atmospheric_light(
  img : @types.Image,
  dark_channel : Array[Float],
  w : Int,
  h : Int,
  ch : Int,
) -> Array[Int] {
  let n = w * h
  // 取暗通道中最亮的 0.1% 像素
  let num_pixels = (n / 1000).max(1)
  // 收集暗通道值和索引
  let pairs : Array[(Float, Int)] = []
  for i in 0..<n {
    pairs.push((dark_channel[i], i))
  }
  // 按暗通道值降序排序
  pairs.sort_by(fn(a, b) { b.0.compare(a.0) })
  // 在这些像素中找原图最亮的像素
  let mut max_r = 0
  let mut max_g = 0
  let mut max_b = 0
  let mut max_sum = 0
  for i in 0..<num_pixels.min(pairs.length()) {
    let idx = pairs[i].1
    let r = img.data[idx * ch].to_int()
    let g = img.data[idx * ch + 1].to_int()
    let b = img.data[idx * ch + 2].to_int()
    let sum = r + g + b
    if sum > max_sum {
      max_sum = sum
      max_r = r
      max_g = g
      max_b = b
    }
  }
  [max_r, max_g, max_b]
}

///|
/// 引导滤波（Guided Filter）用于优化透射率。
/// 适用于灰度图（channels=1）作为引导图。
pub fn guided_filter(
  img : @types.Image,
  input : Array[Float],
  radius? : Int = 20,
  eps? : Float = 0.001F,
) -> Array[Float] raise @types.LoadError {
  // 输入验证
  if img.width < 0 || img.height < 0 {
    raise @types.LoadError::DecodeFailed(
      "guided_filter: 图像尺寸不能为负",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "guided_filter 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "guided_filter: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if radius < 1 {
    raise @types.LoadError::DecodeFailed("guided_filter: radius必须>=1")
  }
  if eps <= 0.0F {
    raise @types.LoadError::DecodeFailed("guided_filter: eps必须大于0")
  }
  let w = img.width
  let h = img.height
  let n = w * h
  if n == 0 || input.length() != n {
    return []
  }
  // 转灰度作为引导图
  let guide : Array[Float] = Array::make(n, 0.0F)
  let ch = img.channels
  for i in 0..<n {
    let v = if ch == 1 {
      img.data[i].to_int()
    } else {
      let r = img.data[i * ch].to_int()
      let g = img.data[i * ch + 1].to_int()
      let b = img.data[i * ch + 2].to_int()
      (r * 299 + g * 587 + b * 114) / 1000
    }
    guide[i] = Float::from_int(v) / 255.0F
  }
  // 计算均值
  let mean_i = box_filter(guide, w, h, radius)
  let mean_p = box_filter(input, w, h, radius)
  // 计算 I*P 的均值
  let ip : Array[Float] = Array::make(n, 0.0F)
  for i in 0..<n {
    ip[i] = guide[i] * input[i]
  }
  let mean_ip = box_filter(ip, w, h, radius)
  // 协方差
  let cov_ip : Array[Float] = Array::make(n, 0.0F)
  for i in 0..<n {
    cov_ip[i] = mean_ip[i] - mean_i[i] * mean_p[i]
  }
  // I² 的均值
  let i_sq : Array[Float] = Array::make(n, 0.0F)
  for i in 0..<n {
    i_sq[i] = guide[i] * guide[i]
  }
  let mean_i_sq = box_filter(i_sq, w, h, radius)
  // 方差
  let var_i : Array[Float] = Array::make(n, 0.0F)
  for i in 0..<n {
    var_i[i] = mean_i_sq[i] - mean_i[i] * mean_i[i]
  }
  // a = cov_ip / (var_i + eps), b = mean_p - a * mean_i
  let a : Array[Float] = Array::make(n, 0.0F)
  let b : Array[Float] = Array::make(n, 0.0F)
  for i in 0..<n {
    a[i] = cov_ip[i] / (var_i[i] + eps)
    b[i] = mean_p[i] - a[i] * mean_i[i]
  }
  let mean_a = box_filter(a, w, h, radius)
  let mean_b = box_filter(b, w, h, radius)
  // 输出 = mean_a * guide + mean_b
  let out : Array[Float] = Array::make(n, 0.0F)
  for i in 0..<n {
    out[i] = mean_a[i] * guide[i] + mean_b[i]
  }
  out
}

///|
/// 盒式滤波（均值滤波），分离内部/边界区域以消除热点 clamp 调用
fn box_filter(
  data : Array[Float],
  w : Int,
  h : Int,
  radius : Int,
) -> Array[Float] {
  let n = w * h
  let out : Array[Float] = Array::make(n, 0.0F)
  // 内部区域 count 恒为 (2*radius+1)²
  let inner_count = Float::from_int((2 * radius + 1) * (2 * radius + 1))
  for y in radius..<(h - radius) {
    for x in radius..<(w - radius) {
      let mut sum = 0.0F
      for py in (y - radius)..<=(y + radius) {
        for px in (x - radius)..<=(x + radius) {
          sum += data[py * w + px]
        }
      }
      out[y * w + x] = sum / inner_count
    }
  }
  // 边界区域
  for y in 0..<h {
    let y_inner = y >= radius && y < h - radius
    for x in 0..<w {
      if y_inner && x >= radius && x < w - radius {
        continue
      }
      let mut sum = 0.0F
      let mut count = 0
      let y_start = (y - radius).clamp(min=0, max=h - 1)
      let y_end = (y + radius).clamp(min=0, max=h - 1)
      let x_start = (x - radius).clamp(min=0, max=w - 1)
      let x_end = (x + radius).clamp(min=0, max=w - 1)
      for py in y_start..<=y_end {
        for px in x_start..<=x_end {
          sum += data[py * w + px]
          count += 1
        }
      }
      out[y * w + x] = sum / Float::from_int(count)
    }
  }
  out
}

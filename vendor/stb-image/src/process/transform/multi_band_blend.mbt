// 拉普拉斯金字塔融合（纯 MoonBit）：multi_band_blend
// 多频带融合：对两幅图像和掩码构建拉普拉斯/高斯金字塔，逐层混合后重建

///|
/// 多频带融合（Laplacian pyramid blend）。
/// img_a 和 img_b 尺寸需相同，mask 为灰度图（非零区域取 img_a，零区域取 img_b）。
/// num_bands 为金字塔层数（默认 5）。
pub fn multi_band_blend(
  img_a : @types.Image,
  img_b : @types.Image,
  mask : @types.Image,
  num_bands? : Int = 5,
) -> @types.Image raise @types.LoadError {
  if img_a.width != img_b.width || img_a.height != img_b.height {
    raise @types.LoadError::DecodeFailed("img_a 和 img_b 尺寸需相同")
  }
  if mask.width != img_a.width || mask.height != img_a.height {
    raise @types.LoadError::DecodeFailed("mask 尺寸需与输入图像相同")
  }
  let w = img_a.width
  let h = img_a.height
  let ch = img_a.channels
  let n = w * h
  // 归一化 mask 到 [0, 1]（用 Float 数组）
  let mask_f : Array[Float] = Array::make(n, 0.0F)
  for i in 0..<n {
    mask_f[i] = Float::from_int(mask.data[i].to_int()) / 255.0F
  }
  // 构建 img_a 和 img_b 的 Float 数组
  let a_f : Array[Float] = Array::make(n * ch, 0.0F)
  let b_f : Array[Float] = Array::make(n * ch, 0.0F)
  for i in 0..<(n * ch) {
    a_f[i] = Float::from_int(img_a.data[i].to_int())
    b_f[i] = Float::from_int(img_b.data[i].to_int())
  }
  // 构建高斯金字塔（mask）和拉普拉斯金字塔（img_a, img_b）
  let levels = if num_bands > 0 { num_bands } else { 5 }
  // 高斯金字塔：mask
  let mask_pyr : Array[Array[Float]] = [mask_f]
  for _l in 1..<levels {
    let prev = mask_pyr[mask_pyr.length() - 1]
    let pw = get_w_from_n(prev.length(), w, h)
    let ph = prev.length() / pw
    mask_pyr.push(blur_downsample(prev, pw, ph))
  }
  // 拉普拉斯金字塔：img_a 和 img_b（每通道独立）
  let out : Array[Float] = Array::make(n * ch, 0.0F)
  for c in 0..<ch {
    let a_chan : Array[Float] = Array::make(n, 0.0F)
    let b_chan : Array[Float] = Array::make(n, 0.0F)
    for i in 0..<n {
      a_chan[i] = a_f[i * ch + c]
      b_chan[i] = b_f[i * ch + c]
    }
    // 构建拉普拉斯金字塔
    let a_pyr = build_laplacian_pyramid_f(a_chan, w, h, levels)
    let b_pyr = build_laplacian_pyramid_f(b_chan, w, h, levels)
    // 逐层混合
    let blended : Array[Array[Float]] = []
    for l in 0..<a_pyr.length() {
      let a_l = a_pyr[l]
      let b_l = b_pyr[l]
      let m_l = mask_pyr[l]
      let blended_l : Array[Float] = Array::make(a_l.length(), 0.0F)
      for i in 0..<a_l.length() {
        let m = if i < m_l.length() { m_l[i] } else { 0.5F }
        blended_l[i] = m * a_l[i] + (1.0F - m) * b_l[i]
      }
      blended.push(blended_l)
    }
    // 重建
    let reconstructed = collapse_laplacian_pyramid_f(blended, w, h)
    for i in 0..<n {
      out[i * ch + c] = reconstructed[i]
    }
  }
  // 转为 Byte
  let out_bytes : Array[Byte] = Array::make(n * ch, b'\x00')
  for i in 0..<(n * ch) {
    out_bytes[i] = (out[i] + 0.5F).to_int().clamp(min=0, max=255).to_byte()
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out_bytes),
  }
}

///|
fn get_w_from_n(n : Int, w : Int, h : Int) -> Int {
  if h == 0 {
    return 0
  }
  let ratio = n / h
  if ratio > 0 {
    ratio
  } else {
    w
  }
}

///|
fn blur_downsample(data : Array[Float], w : Int, h : Int) -> Array[Float] {
  let nw = w / 2
  let nh = h / 2
  if nw == 0 || nh == 0 {
    return [data[0]]
  }
  let out : Array[Float] = Array::make(nw * nh, 0.0F)
  for y in 0..<nh {
    for x in 0..<nw {
      let sx = x * 2
      let sy = y * 2
      let mut sum = 0.0F
      let mut count = 0
      for dy in 0..<2 {
        for dx in 0..<2 {
          let px = (sx + dx).clamp(min=0, max=w - 1)
          let py = (sy + dy).clamp(min=0, max=h - 1)
          sum += data[py * w + px]
          count += 1
        }
      }
      out[y * nw + x] = sum / Float::from_int(count)
    }
  }
  out
}

///|
fn build_laplacian_pyramid_f(
  data : Array[Float],
  w : Int,
  h : Int,
  levels : Int,
) -> Array[Array[Float]] {
  let gaussian : Array[(Array[Float], Int, Int)] = [(data, w, h)]
  for _l in 1..<levels {
    let (prev, pw, ph) = gaussian[gaussian.length() - 1]
    if pw <= 1 || ph <= 1 {
      break
    }
    let down = blur_downsample(prev, pw, ph)
    gaussian.push((down, pw / 2, ph / 2))
  }
  // 拉普拉斯 = 当前层 - 上采样(下一层)
  let laplacian : Array[Array[Float]] = []
  for l in 0..<(gaussian.length() - 1) {
    let (curr, cw, ch) = gaussian[l]
    let (next, nw, nh) = gaussian[l + 1]
    let upsampled = upsample_f(next, nw, nh, cw, ch)
    let diff : Array[Float] = Array::make(curr.length(), 0.0F)
    for i in 0..<curr.length() {
      diff[i] = curr[i] - upsampled[i]
    }
    laplacian.push(diff)
  }
  // 最后一层（最粗分辨率）直接保留
  let (last, _, _) = gaussian[gaussian.length() - 1]
  laplacian.push(last)
  laplacian
}

///|
fn upsample_f(
  data : Array[Float],
  sw : Int,
  sh : Int,
  dw : Int,
  dh : Int,
) -> Array[Float] {
  let out : Array[Float] = Array::make(dw * dh, 0.0F)
  for y in 0..<dh {
    for x in 0..<dw {
      let sx = (x * sw / dw).clamp(min=0, max=sw - 1)
      let sy = (y * sh / dh).clamp(min=0, max=sh - 1)
      out[y * dw + x] = data[sy * sw + sx]
    }
  }
  out
}

///|
fn collapse_laplacian_pyramid_f(
  pyramid : Array[Array[Float]],
  w : Int,
  h : Int,
) -> Array[Float] {
  if pyramid.length() == 0 {
    return Array::make(w * h, 0.0F)
  }
  // 从最粗层开始重建
  let mut current = pyramid[pyramid.length() - 1]
  let mut cw = 1
  let mut ch = 1
  // 推算最粗层尺寸
  let mut tw = w
  let mut th = h
  let sizes : Array[(Int, Int)] = [(tw, th)]
  for _l in 1..<pyramid.length() {
    tw = tw / 2
    th = th / 2
    if tw == 0 {
      tw = 1
    }
    if th == 0 {
      th = 1
    }
    sizes.push((tw, th))
  }
  let (lcw, lch) = sizes[sizes.length() - 1]
  cw = lcw
  ch = lch
  // 从倒数第二层开始向上重建
  for k in 0..<(pyramid.length() - 1) {
    let l = pyramid.length() - 2 - k
    let (nw, nh) = sizes[l]
    let upsampled = upsample_f(current, cw, ch, nw, nh)
    current = Array::make(nw * nh, 0.0F)
    for i in 0..<(nw * nh) {
      current[i] = pyramid[l][i] + upsampled[i]
    }
    cw = nw
    ch = nh
  }
  current
}

// ========== multi_band_blend 16-bit ==========

///|
/// 多频带融合 16-bit 版本。
pub fn multi_band_blend_16(
  img_a : @types.Image16,
  img_b : @types.Image16,
  mask : @types.Image16,
  num_bands? : Int = 5,
) -> @types.Image16 raise @types.LoadError {
  if img_a.width != img_b.width || img_a.height != img_b.height {
    raise @types.LoadError::DecodeFailed("img_a 和 img_b 尺寸需相同")
  }
  if mask.width != img_a.width || mask.height != img_a.height {
    raise @types.LoadError::DecodeFailed("mask 尺寸需与输入图像相同")
  }
  let w = img_a.width
  let h = img_a.height
  let ch = img_a.channels
  let n = w * h
  let mask_f : Array[Float] = Array::make(n, 0.0F)
  for i in 0..<n {
    let v = mask.data[i * 2].to_int() | (mask.data[i * 2 + 1].to_int() << 8)
    mask_f[i] = Float::from_int(v) / 65535.0F
  }
  let a_f : Array[Float] = Array::make(n * ch, 0.0F)
  let b_f : Array[Float] = Array::make(n * ch, 0.0F)
  for i in 0..<(n * ch) {
    let va = img_a.data[i * 2].to_int() | (img_a.data[i * 2 + 1].to_int() << 8)
    let vb = img_b.data[i * 2].to_int() | (img_b.data[i * 2 + 1].to_int() << 8)
    a_f[i] = Float::from_int(va)
    b_f[i] = Float::from_int(vb)
  }
  let levels = if num_bands > 0 { num_bands } else { 5 }
  let mask_pyr : Array[Array[Float]] = [mask_f]
  for _l in 1..<levels {
    let prev = mask_pyr[mask_pyr.length() - 1]
    let pw = get_w_from_n(prev.length(), w, h)
    let ph = prev.length() / pw
    mask_pyr.push(blur_downsample(prev, pw, ph))
  }
  let out : Array[Float] = Array::make(n * ch, 0.0F)
  for c in 0..<ch {
    let a_chan : Array[Float] = Array::make(n, 0.0F)
    let b_chan : Array[Float] = Array::make(n, 0.0F)
    for i in 0..<n {
      a_chan[i] = a_f[i * ch + c]
      b_chan[i] = b_f[i * ch + c]
    }
    let a_pyr = build_laplacian_pyramid_f(a_chan, w, h, levels)
    let b_pyr = build_laplacian_pyramid_f(b_chan, w, h, levels)
    let blended : Array[Array[Float]] = []
    for l in 0..<a_pyr.length() {
      let a_l = a_pyr[l]
      let b_l = b_pyr[l]
      let m_l = mask_pyr[l]
      let blended_l : Array[Float] = Array::make(a_l.length(), 0.0F)
      for i in 0..<a_l.length() {
        let m = if i < m_l.length() { m_l[i] } else { 0.5F }
        blended_l[i] = m * a_l[i] + (1.0F - m) * b_l[i]
      }
      blended.push(blended_l)
    }
    let reconstructed = collapse_laplacian_pyramid_f(blended, w, h)
    for i in 0..<n {
      out[i * ch + c] = reconstructed[i]
    }
  }
  let out_bytes : Array[Byte] = Array::make(n * ch * 2, b'\x00')
  for i in 0..<(n * ch) {
    let v = (out[i] + 0.5F).to_int()
    let clamped = if v < 0 { 0 } else if v > 65535 { 65535 } else { v }
    out_bytes[i * 2] = (clamped & 0xFF).to_byte()
    out_bytes[i * 2 + 1] = ((clamped >> 8) & 0xFF).to_byte()
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out_bytes),
  }
}

// ========== multi_band_blend float ==========

///|
/// 多频带融合 float 版本。
pub fn multi_band_blend_f(
  img_a : @types.ImageF,
  img_b : @types.ImageF,
  mask : @types.ImageF,
  num_bands? : Int = 5,
) -> @types.ImageF raise @types.LoadError {
  if img_a.width != img_b.width || img_a.height != img_b.height {
    raise @types.LoadError::DecodeFailed("img_a 和 img_b 尺寸需相同")
  }
  if mask.width != img_a.width || mask.height != img_a.height {
    raise @types.LoadError::DecodeFailed("mask 尺寸需与输入图像相同")
  }
  let w = img_a.width
  let h = img_a.height
  let ch = img_a.channels
  let n = w * h
  let mask_f : Array[Float] = Array::make(n, 0.0F)
  for i in 0..<n {
    let bits = mask.data[i * 4].to_int() |
      (mask.data[i * 4 + 1].to_int() << 8) |
      (mask.data[i * 4 + 2].to_int() << 16) |
      (mask.data[i * 4 + 3].to_int() << 24)
    mask_f[i] = Float::reinterpret_from_int(bits)
  }
  let a_f : Array[Float] = Array::make(n * ch, 0.0F)
  let b_f : Array[Float] = Array::make(n * ch, 0.0F)
  for i in 0..<(n * ch) {
    let bits_a = img_a.data[i * 4].to_int() |
      (img_a.data[i * 4 + 1].to_int() << 8) |
      (img_a.data[i * 4 + 2].to_int() << 16) |
      (img_a.data[i * 4 + 3].to_int() << 24)
    let bits_b = img_b.data[i * 4].to_int() |
      (img_b.data[i * 4 + 1].to_int() << 8) |
      (img_b.data[i * 4 + 2].to_int() << 16) |
      (img_b.data[i * 4 + 3].to_int() << 24)
    a_f[i] = Float::reinterpret_from_int(bits_a)
    b_f[i] = Float::reinterpret_from_int(bits_b)
  }
  let levels = if num_bands > 0 { num_bands } else { 5 }
  let mask_pyr : Array[Array[Float]] = [mask_f]
  for _l in 1..<levels {
    let prev = mask_pyr[mask_pyr.length() - 1]
    let pw = get_w_from_n(prev.length(), w, h)
    let ph = prev.length() / pw
    mask_pyr.push(blur_downsample(prev, pw, ph))
  }
  let out : Array[Float] = Array::make(n * ch, 0.0F)
  for c in 0..<ch {
    let a_chan : Array[Float] = Array::make(n, 0.0F)
    let b_chan : Array[Float] = Array::make(n, 0.0F)
    for i in 0..<n {
      a_chan[i] = a_f[i * ch + c]
      b_chan[i] = b_f[i * ch + c]
    }
    let a_pyr = build_laplacian_pyramid_f(a_chan, w, h, levels)
    let b_pyr = build_laplacian_pyramid_f(b_chan, w, h, levels)
    let blended : Array[Array[Float]] = []
    for l in 0..<a_pyr.length() {
      let a_l = a_pyr[l]
      let b_l = b_pyr[l]
      let m_l = mask_pyr[l]
      let blended_l : Array[Float] = Array::make(a_l.length(), 0.0F)
      for i in 0..<a_l.length() {
        let m = if i < m_l.length() { m_l[i] } else { 0.5F }
        blended_l[i] = m * a_l[i] + (1.0F - m) * b_l[i]
      }
      blended.push(blended_l)
    }
    let reconstructed = collapse_laplacian_pyramid_f(blended, w, h)
    for i in 0..<n {
      out[i * ch + c] = reconstructed[i]
    }
  }
  let out_bytes : Array[Byte] = Array::make(n * ch * 4, b'\x00')
  for i in 0..<(n * ch) {
    let bits = out[i].reinterpret_as_int()
    out_bytes[i * 4] = (bits & 0xFF).to_byte()
    out_bytes[i * 4 + 1] = ((bits >> 8) & 0xFF).to_byte()
    out_bytes[i * 4 + 2] = ((bits >> 16) & 0xFF).to_byte()
    out_bytes[i * 4 + 3] = ((bits >> 24) & 0xFF).to_byte()
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out_bytes),
  }
}

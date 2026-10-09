// 图像金字塔 16-bit/float 变体
// pyr_down / pyr_up

///|
fn clamp_i_p(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
fn read_u16_p(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() | (data[offset + 1].to_int() << 8)
}

///|
fn write_u16_p(data : Array[Byte], offset : Int, v : Int) -> Unit {
  data[offset] = (v & 0xFF).to_byte()
  data[offset + 1] = ((v >> 8) & 0xFF).to_byte()
}

///|
fn read_f32_p(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

///|
fn write_f32_p(data : Array[Byte], offset : Int, v : Float) -> Unit {
  let bits = v.reinterpret_as_int()
  data[offset] = (bits & 0xFF).to_byte()
  data[offset + 1] = ((bits >> 8) & 0xFF).to_byte()
  data[offset + 2] = ((bits >> 16) & 0xFF).to_byte()
  data[offset + 3] = ((bits >> 24) & 0xFF).to_byte()
}

// ========== pyr_down 16-bit ==========

///|
/// 高斯金字塔下采样 16-bit 版本。
pub fn pyr_down_16(
  img : @types.Image16,
) -> @types.Image16 raise @types.LoadError {
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("pyr_down_16 仅支持 channels=1/3/4")
  }
  let ch = img.channels
  let w = img.width
  let h = img.height
  let new_w = w / 2
  let new_h = h / 2
  if new_w == 0 || new_h == 0 {
    raise @types.LoadError::DecodeFailed("图像太小，无法下采样")
  }
  let data_int : Array[Int] = Array::make(w * h * ch, 0)
  for i in 0..<(w * h * ch) {
    data_int[i] = read_u16_p(img.data, i * 2)
  }
  let out : Array[Byte] = Array::make(new_w * new_h * ch * 2, b'\x00')
  for y in 0..<new_h {
    for x in 0..<new_w {
      for c in 0..<ch {
        let mut sum = 0
        let mut count = 0
        for dy in 0..<2 {
          for dx in 0..<2 {
            let sx = x * 2 + dx
            let sy = y * 2 + dy
            if sx < w && sy < h {
              sum += data_int[(sy * w + sx) * ch + c]
              count += 1
            }
          }
        }
        write_u16_p(out, ((y * new_w + x) * ch + c) * 2, sum / count)
      }
    }
  }
  @types.Image16::{
    width: new_w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== pyr_down float ==========

///|
/// 高斯金字塔下采样 float 版本。
pub fn pyr_down_f(img : @types.ImageF) -> @types.ImageF raise @types.LoadError {
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("pyr_down_f 仅支持 channels=1/3/4")
  }
  let ch = img.channels
  let w = img.width
  let h = img.height
  let new_w = w / 2
  let new_h = h / 2
  if new_w == 0 || new_h == 0 {
    raise @types.LoadError::DecodeFailed("图像太小，无法下采样")
  }
  let data_f : Array[Float] = Array::make(w * h * ch, 0.0F)
  for i in 0..<(w * h * ch) {
    data_f[i] = read_f32_p(img.data, i * 4)
  }
  let out : Array[Byte] = Array::make(new_w * new_h * ch * 4, b'\x00')
  for y in 0..<new_h {
    for x in 0..<new_w {
      for c in 0..<ch {
        let mut sum = 0.0F
        let mut count = 0
        for dy in 0..<2 {
          for dx in 0..<2 {
            let sx = x * 2 + dx
            let sy = y * 2 + dy
            if sx < w && sy < h {
              sum += data_f[(sy * w + sx) * ch + c]
              count += 1
            }
          }
        }
        write_f32_p(
          out,
          ((y * new_w + x) * ch + c) * 4,
          sum / Float::from_int(count),
        )
      }
    }
  }
  @types.ImageF::{
    width: new_w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== pyr_up 16-bit ==========

///|
/// 拉普拉斯金字塔上采样 16-bit 版本。
pub fn pyr_up_16(img : @types.Image16) -> @types.Image16 raise @types.LoadError {
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("pyr_up_16 仅支持 channels=1/3/4")
  }
  let ch = img.channels
  let w = img.width
  let h = img.height
  let new_w = w * 2
  let new_h = h * 2
  let data_int : Array[Int] = Array::make(w * h * ch, 0)
  for i in 0..<(w * h * ch) {
    data_int[i] = read_u16_p(img.data, i * 2)
  }
  let x0_arr : Array[Int] = Array::make(new_w, 0)
  let x1_arr : Array[Int] = Array::make(new_w, 0)
  let wx_arr : Array[Float] = Array::make(new_w, 0.0F)
  for x in 0..<new_w {
    let fx = (Float::from_int(x) - 0.5F) / 2.0F
    let x0 = clamp_i_p(fx.to_int(), 0, w - 1)
    x0_arr[x] = x0
    x1_arr[x] = clamp_i_p(x0 + 1, 0, w - 1)
    wx_arr[x] = fx - Float::from_int(x0)
  }
  let y0_arr : Array[Int] = Array::make(new_h, 0)
  let y1_arr : Array[Int] = Array::make(new_h, 0)
  let wy_arr : Array[Float] = Array::make(new_h, 0.0F)
  for y in 0..<new_h {
    let fy = (Float::from_int(y) - 0.5F) / 2.0F
    let y0 = clamp_i_p(fy.to_int(), 0, h - 1)
    y0_arr[y] = y0
    y1_arr[y] = clamp_i_p(y0 + 1, 0, h - 1)
    wy_arr[y] = fy - Float::from_int(y0)
  }
  let out : Array[Byte] = Array::make(new_w * new_h * ch * 2, b'\x00')
  for y in 0..<new_h {
    let y0 = y0_arr[y]
    let y1 = y1_arr[y]
    let wy = wy_arr[y]
    let wy_inv = 1.0F - wy
    let row0 = y0 * w
    let row1 = y1 * w
    for x in 0..<new_w {
      let x0 = x0_arr[x]
      let x1 = x1_arr[x]
      let wx = wx_arr[x]
      let wx_inv = 1.0F - wx
      for c in 0..<ch {
        let v00 = Float::from_int(data_int[(row0 + x0) * ch + c])
        let v01 = Float::from_int(data_int[(row0 + x1) * ch + c])
        let v10 = Float::from_int(data_int[(row1 + x0) * ch + c])
        let v11 = Float::from_int(data_int[(row1 + x1) * ch + c])
        let top = v00 * wx_inv + v01 * wx
        let bot = v10 * wx_inv + v11 * wx
        let v = top * wy_inv + bot * wy
        let clamped = if v < 0.0F {
          0
        } else if v > 65535.0F {
          65535
        } else {
          (v + 0.5F).to_int()
        }
        write_u16_p(out, ((y * new_w + x) * ch + c) * 2, clamped)
      }
    }
  }
  @types.Image16::{
    width: new_w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== pyr_up float ==========

///|
/// 拉普拉斯金字塔上采样 float 版本。
pub fn pyr_up_f(img : @types.ImageF) -> @types.ImageF raise @types.LoadError {
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("pyr_up_f 仅支持 channels=1/3/4")
  }
  let ch = img.channels
  let w = img.width
  let h = img.height
  let new_w = w * 2
  let new_h = h * 2
  let data_f : Array[Float] = Array::make(w * h * ch, 0.0F)
  for i in 0..<(w * h * ch) {
    data_f[i] = read_f32_p(img.data, i * 4)
  }
  let x0_arr : Array[Int] = Array::make(new_w, 0)
  let x1_arr : Array[Int] = Array::make(new_w, 0)
  let wx_arr : Array[Float] = Array::make(new_w, 0.0F)
  for x in 0..<new_w {
    let fx = (Float::from_int(x) - 0.5F) / 2.0F
    let x0 = clamp_i_p(fx.to_int(), 0, w - 1)
    x0_arr[x] = x0
    x1_arr[x] = clamp_i_p(x0 + 1, 0, w - 1)
    wx_arr[x] = fx - Float::from_int(x0)
  }
  let y0_arr : Array[Int] = Array::make(new_h, 0)
  let y1_arr : Array[Int] = Array::make(new_h, 0)
  let wy_arr : Array[Float] = Array::make(new_h, 0.0F)
  for y in 0..<new_h {
    let fy = (Float::from_int(y) - 0.5F) / 2.0F
    let y0 = clamp_i_p(fy.to_int(), 0, h - 1)
    y0_arr[y] = y0
    y1_arr[y] = clamp_i_p(y0 + 1, 0, h - 1)
    wy_arr[y] = fy - Float::from_int(y0)
  }
  let out : Array[Byte] = Array::make(new_w * new_h * ch * 4, b'\x00')
  for y in 0..<new_h {
    let y0 = y0_arr[y]
    let y1 = y1_arr[y]
    let wy = wy_arr[y]
    let wy_inv = 1.0F - wy
    let row0 = y0 * w
    let row1 = y1 * w
    for x in 0..<new_w {
      let x0 = x0_arr[x]
      let x1 = x1_arr[x]
      let wx = wx_arr[x]
      let wx_inv = 1.0F - wx
      for c in 0..<ch {
        let v00 = data_f[(row0 + x0) * ch + c]
        let v01 = data_f[(row0 + x1) * ch + c]
        let v10 = data_f[(row1 + x0) * ch + c]
        let v11 = data_f[(row1 + x1) * ch + c]
        let top = v00 * wx_inv + v01 * wx
        let bot = v10 * wx_inv + v11 * wx
        let v = top * wy_inv + bot * wy
        write_f32_p(out, ((y * new_w + x) * ch + c) * 4, v)
      }
    }
  }
  @types.ImageF::{
    width: new_w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== laplacian_diff 16-bit ==========

///|
fn laplacian_diff_p16(a : @types.Image16, b : @types.Image16) -> @types.Image16 {
  let ch = a.channels
  let w = a.width
  let h = a.height
  let a_int : Array[Int] = Array::make(w * h * ch, 0)
  for i in 0..<(w * h * ch) {
    a_int[i] = read_u16_p(a.data, i * 2)
  }
  let bw = b.width
  let bh = b.height
  let b_int : Array[Int] = Array::make(bw * bh * ch, 0)
  for i in 0..<(bw * bh * ch) {
    b_int[i] = read_u16_p(b.data, i * 2)
  }
  let out : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  for y in 0..<h {
    let by = y * bh / h
    for x in 0..<w {
      let bx = x * bw / w
      for c in 0..<ch {
        let va = a_int[(y * w + x) * ch + c]
        let vb = b_int[(by * bw + bx) * ch + c]
        let diff = va - vb + 32768
        let clamped = if diff < 0 {
          0
        } else if diff > 65535 {
          65535
        } else {
          diff
        }
        write_u16_p(out, ((y * w + x) * ch + c) * 2, clamped)
      }
    }
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== laplacian_diff float ==========

///|
fn laplacian_diff_pf(a : @types.ImageF, b : @types.ImageF) -> @types.ImageF {
  let ch = a.channels
  let w = a.width
  let h = a.height
  let a_f : Array[Float] = Array::make(w * h * ch, 0.0F)
  for i in 0..<(w * h * ch) {
    a_f[i] = read_f32_p(a.data, i * 4)
  }
  let bw = b.width
  let bh = b.height
  let b_f : Array[Float] = Array::make(bw * bh * ch, 0.0F)
  for i in 0..<(bw * bh * ch) {
    b_f[i] = read_f32_p(b.data, i * 4)
  }
  let out : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  for y in 0..<h {
    let by = y * bh / h
    for x in 0..<w {
      let bx = x * bw / w
      for c in 0..<ch {
        let va = a_f[(y * w + x) * ch + c]
        let vb = b_f[(by * bw + bx) * ch + c]
        let diff = va - vb + 0.5F
        write_f32_p(out, ((y * w + x) * ch + c) * 4, diff)
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

// ========== build_gaussian_pyramid 16-bit ==========

///|
/// 构建高斯金字塔 16-bit 版本。
pub fn build_gaussian_pyramid_16(
  img : @types.Image16,
  levels : Int,
) -> Array[@types.Image16] raise @types.LoadError {
  let result : Array[@types.Image16] = [img]
  let mut current = img
  let max_levels = if levels == 0 { 100 } else { levels }
  for _ in 1..<max_levels {
    if current.width < 2 || current.height < 2 {
      break
    }
    current = pyr_down_16(current)
    result.push(current)
  }
  result
}

// ========== build_gaussian_pyramid float ==========

///|
/// 构建高斯金字塔 float 版本。
pub fn build_gaussian_pyramid_f(
  img : @types.ImageF,
  levels : Int,
) -> Array[@types.ImageF] raise @types.LoadError {
  let result : Array[@types.ImageF] = [img]
  let mut current = img
  let max_levels = if levels == 0 { 100 } else { levels }
  for _ in 1..<max_levels {
    if current.width < 2 || current.height < 2 {
      break
    }
    current = pyr_down_f(current)
    result.push(current)
  }
  result
}

// ========== build_laplacian_pyramid 16-bit ==========

///|
/// 构建拉普拉斯金字塔 16-bit 版本。
pub fn build_laplacian_pyramid_16(
  img : @types.Image16,
  levels : Int,
) -> Array[@types.Image16] raise @types.LoadError {
  let gaussian = build_gaussian_pyramid_16(img, levels)
  let result : Array[@types.Image16] = []
  for i in 0..<(gaussian.length() - 1) {
    let upsampled = pyr_up_16(gaussian[i + 1])
    let lap = laplacian_diff_p16(gaussian[i], upsampled)
    result.push(lap)
  }
  result.push(gaussian[gaussian.length() - 1])
  result
}

// ========== build_laplacian_pyramid float ==========

///|
/// 构建拉普拉斯金字塔 float 版本。
pub fn build_laplacian_pyramid_float(
  img : @types.ImageF,
  levels : Int,
) -> Array[@types.ImageF] raise @types.LoadError {
  let gaussian = build_gaussian_pyramid_f(img, levels)
  let result : Array[@types.ImageF] = []
  for i in 0..<(gaussian.length() - 1) {
    let upsampled = pyr_up_f(gaussian[i + 1])
    let lap = laplacian_diff_pf(gaussian[i], upsampled)
    result.push(lap)
  }
  result.push(gaussian[gaussian.length() - 1])
  result
}

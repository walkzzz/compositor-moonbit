// 局部二值模式（LBP）16-bit/float 变体
// 支持 Image16 / ImageF 两种类型

// ========== 辅助函数 ==========

///|
fn read_u16_le_l(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn write_u16_le_l(buf : Array[Byte], offset : Int, val : Int) -> Unit {
  buf[offset] = (val & 0xFF).to_byte()
  buf[offset + 1] = ((val >> 8) & 0xFF).to_byte()
}

///|
fn read_float_le_l(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

///|
fn write_f32_le_l(buf : Array[Byte], offset : Int, val : Float) -> Unit {
  let bits = val.reinterpret_as_int()
  buf[offset] = (bits & 0xFF).to_byte()
  buf[offset + 1] = ((bits >> 8) & 0xFF).to_byte()
  buf[offset + 2] = ((bits >> 16) & 0xFF).to_byte()
  buf[offset + 3] = ((bits >> 24) & 0xFF).to_byte()
}

///|
fn clamp_int_l(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
fn get_pixel_safe_16(
  src : Array[Int],
  x : Int,
  y : Int,
  c : Int,
  ch : Int,
  w : Int,
  h : Int,
) -> Int {
  let sx = clamp_int_l(x, 0, w - 1)
  let sy = clamp_int_l(y, 0, h - 1)
  src[(sy * w + sx) * ch + c]
}

///|
fn get_pixel_safe_f(
  src : Array[Float],
  x : Int,
  y : Int,
  c : Int,
  ch : Int,
  w : Int,
  h : Int,
) -> Float {
  let sx = clamp_int_l(x, 0, w - 1)
  let sy = clamp_int_l(y, 0, h - 1)
  src[(sy * w + sx) * ch + c]
}

// 计算均匀 LBP 映射（跳变次数 <= 2）

///|
fn uniform_lbp_map(lbp_val : Int) -> Int {
  // 计算 0->1 和 1->0 跳变次数
  let mut transitions = 0
  let mut prev = (lbp_val >> 7) & 1
  for i in 0..<8 {
    let curr = (lbp_val >> i) & 1
    if curr != prev {
      transitions += 1
    }
    prev = curr
  }
  if transitions <= 2 {
    // 均匀模式：计算 1 的个数作为标签（0-8）
    let mut count = 0
    for i in 0..<8 {
      if ((lbp_val >> i) & 1) == 1 {
        count += 1
      }
    }
    count
  } else {
    // 非均匀模式
    9
  }
}

// ========== 基本 LBP ==========

///|
/// 16-bit 基本局部二值模式（LBP）。输出 0-255 的编码值，存储为 16-bit。
pub fn lbp_16(img : @types.Image16) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("lbp_16: 图像尺寸必须大于0")
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("lbp_16: 仅支持 channels=1/3/4")
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "lbp_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { 1 }
  let w = img.width
  let h = img.height
  let n = w * h
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let src : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    src[i] = read_u16_le_l(img.data, i * 2)
  }
  for c in 0..<color_ch {
    for y in 1..<(h - 1) {
      for x in 1..<(w - 1) {
        let center = src[(y * w + x) * ch + c]
        let mut lbp_val = 0
        if src[((y - 1) * w + (x - 1)) * ch + c] >= center {
          lbp_val = lbp_val | 1
        }
        if src[((y - 1) * w + x) * ch + c] >= center {
          lbp_val = lbp_val | 2
        }
        if src[((y - 1) * w + (x + 1)) * ch + c] >= center {
          lbp_val = lbp_val | 4
        }
        if src[(y * w + (x + 1)) * ch + c] >= center {
          lbp_val = lbp_val | 8
        }
        if src[((y + 1) * w + (x + 1)) * ch + c] >= center {
          lbp_val = lbp_val | 16
        }
        if src[((y + 1) * w + x) * ch + c] >= center {
          lbp_val = lbp_val | 32
        }
        if src[((y + 1) * w + (x - 1)) * ch + c] >= center {
          lbp_val = lbp_val | 64
        }
        if src[(y * w + (x - 1)) * ch + c] >= center {
          lbp_val = lbp_val | 128
        }
        write_u16_le_l(out, (y * w + x) * bpp + c * 2, lbp_val)
      }
    }
    for y in 0..<h {
      let y_inner = y >= 1 && y < h - 1
      for x in 0..<w {
        if y_inner && x >= 1 && x < w - 1 {
          continue
        }
        let center = src[(y * w + x) * ch + c]
        let mut lbp_val = 0
        if get_pixel_safe_16(src, x - 1, y - 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 1
        }
        if get_pixel_safe_16(src, x, y - 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 2
        }
        if get_pixel_safe_16(src, x + 1, y - 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 4
        }
        if get_pixel_safe_16(src, x + 1, y, c, ch, w, h) >= center {
          lbp_val = lbp_val | 8
        }
        if get_pixel_safe_16(src, x + 1, y + 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 16
        }
        if get_pixel_safe_16(src, x, y + 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 32
        }
        if get_pixel_safe_16(src, x - 1, y + 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 64
        }
        if get_pixel_safe_16(src, x - 1, y, c, ch, w, h) >= center {
          lbp_val = lbp_val | 128
        }
        write_u16_le_l(out, (y * w + x) * bpp + c * 2, lbp_val)
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
/// float 基本局部二值模式（LBP）。输出归一化到 0.0-1.0（LBP值/255）。
pub fn lbp_f(img : @types.ImageF) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("lbp_f: 图像尺寸必须大于0")
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("lbp_f: 仅支持 channels=1/3/4")
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "lbp_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { 1 }
  let w = img.width
  let h = img.height
  let n = w * h
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let src : Array[Float] = Array::make(n * ch, 0.0F)
  for i in 0..<(n * ch) {
    src[i] = read_float_le_l(img.data, i * 4)
  }
  for c in 0..<color_ch {
    for y in 1..<(h - 1) {
      for x in 1..<(w - 1) {
        let center = src[(y * w + x) * ch + c]
        let mut lbp_val = 0
        if src[((y - 1) * w + (x - 1)) * ch + c] >= center {
          lbp_val = lbp_val | 1
        }
        if src[((y - 1) * w + x) * ch + c] >= center {
          lbp_val = lbp_val | 2
        }
        if src[((y - 1) * w + (x + 1)) * ch + c] >= center {
          lbp_val = lbp_val | 4
        }
        if src[(y * w + (x + 1)) * ch + c] >= center {
          lbp_val = lbp_val | 8
        }
        if src[((y + 1) * w + (x + 1)) * ch + c] >= center {
          lbp_val = lbp_val | 16
        }
        if src[((y + 1) * w + x) * ch + c] >= center {
          lbp_val = lbp_val | 32
        }
        if src[((y + 1) * w + (x - 1)) * ch + c] >= center {
          lbp_val = lbp_val | 64
        }
        if src[(y * w + (x - 1)) * ch + c] >= center {
          lbp_val = lbp_val | 128
        }
        write_f32_le_l(
          out,
          (y * w + x) * bpp + c * 4,
          Float::from_int(lbp_val) / 255.0F,
        )
      }
    }
    for y in 0..<h {
      let y_inner = y >= 1 && y < h - 1
      for x in 0..<w {
        if y_inner && x >= 1 && x < w - 1 {
          continue
        }
        let center = src[(y * w + x) * ch + c]
        let mut lbp_val = 0
        if get_pixel_safe_f(src, x - 1, y - 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 1
        }
        if get_pixel_safe_f(src, x, y - 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 2
        }
        if get_pixel_safe_f(src, x + 1, y - 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 4
        }
        if get_pixel_safe_f(src, x + 1, y, c, ch, w, h) >= center {
          lbp_val = lbp_val | 8
        }
        if get_pixel_safe_f(src, x + 1, y + 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 16
        }
        if get_pixel_safe_f(src, x, y + 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 32
        }
        if get_pixel_safe_f(src, x - 1, y + 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 64
        }
        if get_pixel_safe_f(src, x - 1, y, c, ch, w, h) >= center {
          lbp_val = lbp_val | 128
        }
        write_f32_le_l(
          out,
          (y * w + x) * bpp + c * 4,
          Float::from_int(lbp_val) / 255.0F,
        )
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

// ========== 均匀 LBP ==========

///|
/// 16-bit 均匀局部二值模式（Uniform LBP）。输出 0-9 的标签值，存储为 16-bit。
pub fn lbp_uniform_16(
  img : @types.Image16,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "lbp_uniform_16: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "lbp_uniform_16: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "lbp_uniform_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { 1 }
  let w = img.width
  let h = img.height
  let n = w * h
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let src : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    src[i] = read_u16_le_l(img.data, i * 2)
  }
  for c in 0..<color_ch {
    for y in 1..<(h - 1) {
      for x in 1..<(w - 1) {
        let center = src[(y * w + x) * ch + c]
        let mut lbp_val = 0
        if src[((y - 1) * w + (x - 1)) * ch + c] >= center {
          lbp_val = lbp_val | 1
        }
        if src[((y - 1) * w + x) * ch + c] >= center {
          lbp_val = lbp_val | 2
        }
        if src[((y - 1) * w + (x + 1)) * ch + c] >= center {
          lbp_val = lbp_val | 4
        }
        if src[(y * w + (x + 1)) * ch + c] >= center {
          lbp_val = lbp_val | 8
        }
        if src[((y + 1) * w + (x + 1)) * ch + c] >= center {
          lbp_val = lbp_val | 16
        }
        if src[((y + 1) * w + x) * ch + c] >= center {
          lbp_val = lbp_val | 32
        }
        if src[((y + 1) * w + (x - 1)) * ch + c] >= center {
          lbp_val = lbp_val | 64
        }
        if src[(y * w + (x - 1)) * ch + c] >= center {
          lbp_val = lbp_val | 128
        }
        write_u16_le_l(out, (y * w + x) * bpp + c * 2, uniform_lbp_map(lbp_val))
      }
    }
    for y in 0..<h {
      let y_inner = y >= 1 && y < h - 1
      for x in 0..<w {
        if y_inner && x >= 1 && x < w - 1 {
          continue
        }
        let center = src[(y * w + x) * ch + c]
        let mut lbp_val = 0
        if get_pixel_safe_16(src, x - 1, y - 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 1
        }
        if get_pixel_safe_16(src, x, y - 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 2
        }
        if get_pixel_safe_16(src, x + 1, y - 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 4
        }
        if get_pixel_safe_16(src, x + 1, y, c, ch, w, h) >= center {
          lbp_val = lbp_val | 8
        }
        if get_pixel_safe_16(src, x + 1, y + 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 16
        }
        if get_pixel_safe_16(src, x, y + 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 32
        }
        if get_pixel_safe_16(src, x - 1, y + 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 64
        }
        if get_pixel_safe_16(src, x - 1, y, c, ch, w, h) >= center {
          lbp_val = lbp_val | 128
        }
        write_u16_le_l(out, (y * w + x) * bpp + c * 2, uniform_lbp_map(lbp_val))
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
/// float 均匀局部二值模式（Uniform LBP）。输出归一化到 0.0-1.0（标签/9）。
pub fn lbp_uniform_f(
  img : @types.ImageF,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "lbp_uniform_f: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "lbp_uniform_f: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "lbp_uniform_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { 1 }
  let w = img.width
  let h = img.height
  let n = w * h
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let src : Array[Float] = Array::make(n * ch, 0.0F)
  for i in 0..<(n * ch) {
    src[i] = read_float_le_l(img.data, i * 4)
  }
  for c in 0..<color_ch {
    for y in 1..<(h - 1) {
      for x in 1..<(w - 1) {
        let center = src[(y * w + x) * ch + c]
        let mut lbp_val = 0
        if src[((y - 1) * w + (x - 1)) * ch + c] >= center {
          lbp_val = lbp_val | 1
        }
        if src[((y - 1) * w + x) * ch + c] >= center {
          lbp_val = lbp_val | 2
        }
        if src[((y - 1) * w + (x + 1)) * ch + c] >= center {
          lbp_val = lbp_val | 4
        }
        if src[(y * w + (x + 1)) * ch + c] >= center {
          lbp_val = lbp_val | 8
        }
        if src[((y + 1) * w + (x + 1)) * ch + c] >= center {
          lbp_val = lbp_val | 16
        }
        if src[((y + 1) * w + x) * ch + c] >= center {
          lbp_val = lbp_val | 32
        }
        if src[((y + 1) * w + (x - 1)) * ch + c] >= center {
          lbp_val = lbp_val | 64
        }
        if src[(y * w + (x - 1)) * ch + c] >= center {
          lbp_val = lbp_val | 128
        }
        let label = uniform_lbp_map(lbp_val)
        write_f32_le_l(
          out,
          (y * w + x) * bpp + c * 4,
          Float::from_int(label) / 9.0F,
        )
      }
    }
    for y in 0..<h {
      let y_inner = y >= 1 && y < h - 1
      for x in 0..<w {
        if y_inner && x >= 1 && x < w - 1 {
          continue
        }
        let center = src[(y * w + x) * ch + c]
        let mut lbp_val = 0
        if get_pixel_safe_f(src, x - 1, y - 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 1
        }
        if get_pixel_safe_f(src, x, y - 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 2
        }
        if get_pixel_safe_f(src, x + 1, y - 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 4
        }
        if get_pixel_safe_f(src, x + 1, y, c, ch, w, h) >= center {
          lbp_val = lbp_val | 8
        }
        if get_pixel_safe_f(src, x + 1, y + 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 16
        }
        if get_pixel_safe_f(src, x, y + 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 32
        }
        if get_pixel_safe_f(src, x - 1, y + 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 64
        }
        if get_pixel_safe_f(src, x - 1, y, c, ch, w, h) >= center {
          lbp_val = lbp_val | 128
        }
        let label = uniform_lbp_map(lbp_val)
        write_f32_le_l(
          out,
          (y * w + x) * bpp + c * 4,
          Float::from_int(label) / 9.0F,
        )
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

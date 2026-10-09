// 高级几何变换 16-bit/float 变体
// warp_affine / warp_perspective / resize

// ========== 辅助函数 ==========

///|
fn read_u16_le_geo(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn write_u16_le_geo(buf : Array[Byte], offset : Int, val : Int) -> Unit {
  buf[offset] = (val & 0xFF).to_byte()
  buf[offset + 1] = ((val >> 8) & 0xFF).to_byte()
}

///|
fn read_float_le_geo(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

///|
fn write_f32_le_geo(buf : Array[Byte], offset : Int, val : Float) -> Unit {
  let bits = val.reinterpret_as_int()
  buf[offset] = (bits & 0xFF).to_byte()
  buf[offset + 1] = ((bits >> 8) & 0xFF).to_byte()
  buf[offset + 2] = ((bits >> 16) & 0xFF).to_byte()
  buf[offset + 3] = ((bits >> 24) & 0xFF).to_byte()
}

///|
fn clamp_int_geo(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
fn sample_bilinear_16(
  data : Array[Int],
  w : Int,
  h : Int,
  ch : Int,
  c : Int,
  x : Float,
  y : Float,
) -> Int {
  let x0 = x.to_int()
  let y0 = y.to_int()
  let w_minus_1 = w - 1
  let h_minus_1 = h - 1
  let x0c = clamp_int_geo(x0, 0, w_minus_1)
  let y0c = clamp_int_geo(y0, 0, h_minus_1)
  let x1 = clamp_int_geo(x0 + 1, 0, w_minus_1)
  let y1 = clamp_int_geo(y0 + 1, 0, h_minus_1)
  let fx = x - Float::from_int(x0)
  let fy = y - Float::from_int(y0)
  let p00 = data[(y0c * w + x0c) * ch + c]
  let p10 = data[(y0c * w + x1) * ch + c]
  let p01 = data[(y1 * w + x0c) * ch + c]
  let p11 = data[(y1 * w + x1) * ch + c]
  let top = Float::from_int(p00) * (1.0F - fx) + Float::from_int(p10) * fx
  let bot = Float::from_int(p01) * (1.0F - fx) + Float::from_int(p11) * fx
  (top * (1.0F - fy) + bot * fy + 0.5F).to_int()
}

///|
fn sample_bilinear_f(
  data : Array[Float],
  w : Int,
  h : Int,
  ch : Int,
  c : Int,
  x : Float,
  y : Float,
) -> Float {
  let x0 = x.to_int()
  let y0 = y.to_int()
  let w_minus_1 = w - 1
  let h_minus_1 = h - 1
  let x0c = clamp_int_geo(x0, 0, w_minus_1)
  let y0c = clamp_int_geo(y0, 0, h_minus_1)
  let x1 = clamp_int_geo(x0 + 1, 0, w_minus_1)
  let y1 = clamp_int_geo(y0 + 1, 0, h_minus_1)
  let fx = x - Float::from_int(x0)
  let fy = y - Float::from_int(y0)
  let p00 = data[(y0c * w + x0c) * ch + c]
  let p10 = data[(y0c * w + x1) * ch + c]
  let p01 = data[(y1 * w + x0c) * ch + c]
  let p11 = data[(y1 * w + x1) * ch + c]
  let top = p00 * (1.0F - fx) + p10 * fx
  let bot = p01 * (1.0F - fx) + p11 * fx
  top * (1.0F - fy) + bot * fy
}

// ========== warp_affine 16-bit ==========

///|
/// 16-bit 仿射变换。
pub fn warp_affine_16(
  img : @types.Image16,
  matrix : (Float, Float, Float, Float, Float, Float),
  new_w : Int,
  new_h : Int,
) -> @types.Image16 {
  let (a, b, c, d, e, f) = matrix
  let ch = img.channels
  let w = img.width
  let h = img.height
  let data_int : Array[Int] = Array::make(w * h * ch, 0)
  for i in 0..<(w * h * ch) {
    data_int[i] = read_u16_le_geo(img.data, i * 2)
  }
  let out : Array[Byte] = Array::make(new_w * new_h * ch * 2, b'\x00')
  for dy in 0..<new_h {
    let fdy = Float::from_int(dy)
    for dx in 0..<new_w {
      let sx = a * Float::from_int(dx) + b * fdy + c
      let sy = d * Float::from_int(dx) + e * fdy + f
      for ci in 0..<ch {
        let val = sample_bilinear_16(data_int, w, h, ch, ci, sx, sy)
        write_u16_le_geo(
          out,
          (dy * new_w + dx) * ch * 2 + ci * 2,
          clamp_int_geo(val, 0, 65535),
        )
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

// ========== warp_affine float ==========

///|
/// float 仿射变换。
pub fn warp_affine_f(
  img : @types.ImageF,
  matrix : (Float, Float, Float, Float, Float, Float),
  new_w : Int,
  new_h : Int,
) -> @types.ImageF {
  let (a, b, c, d, e, f) = matrix
  let ch = img.channels
  let w = img.width
  let h = img.height
  let data_f : Array[Float] = Array::make(w * h * ch, 0.0F)
  for i in 0..<(w * h * ch) {
    data_f[i] = read_float_le_geo(img.data, i * 4)
  }
  let out : Array[Byte] = Array::make(new_w * new_h * ch * 4, b'\x00')
  for dy in 0..<new_h {
    let fdy = Float::from_int(dy)
    for dx in 0..<new_w {
      let sx = a * Float::from_int(dx) + b * fdy + c
      let sy = d * Float::from_int(dx) + e * fdy + f
      for ci in 0..<ch {
        let val = sample_bilinear_f(data_f, w, h, ch, ci, sx, sy)
        write_f32_le_geo(out, (dy * new_w + dx) * ch * 4 + ci * 4, val)
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

// ========== warp_perspective 16-bit ==========

///|
/// 16-bit 透视变换。
pub fn warp_perspective_16(
  img : @types.Image16,
  matrix : PerspectiveMatrix,
  new_w : Int,
  new_h : Int,
) -> @types.Image16 {
  let ch = img.channels
  let w = img.width
  let h = img.height
  let data_int : Array[Int] = Array::make(w * h * ch, 0)
  for i in 0..<(w * h * ch) {
    data_int[i] = read_u16_le_geo(img.data, i * 2)
  }
  let out : Array[Byte] = Array::make(new_w * new_h * ch * 2, b'\x00')
  for dy in 0..<new_h {
    let fdy = Float::from_int(dy)
    for dx in 0..<new_w {
      let fdx = Float::from_int(dx)
      let denom = matrix.m20 * fdx + matrix.m21 * fdy + matrix.m22
      let sx = (matrix.m00 * fdx + matrix.m01 * fdy + matrix.m02) / denom
      let sy = (matrix.m10 * fdx + matrix.m11 * fdy + matrix.m12) / denom
      for ci in 0..<ch {
        let val = sample_bilinear_16(data_int, w, h, ch, ci, sx, sy)
        write_u16_le_geo(
          out,
          (dy * new_w + dx) * ch * 2 + ci * 2,
          clamp_int_geo(val, 0, 65535),
        )
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

// ========== warp_perspective float ==========

///|
/// float 透视变换。
pub fn warp_perspective_f(
  img : @types.ImageF,
  matrix : PerspectiveMatrix,
  new_w : Int,
  new_h : Int,
) -> @types.ImageF {
  let ch = img.channels
  let w = img.width
  let h = img.height
  let data_f : Array[Float] = Array::make(w * h * ch, 0.0F)
  for i in 0..<(w * h * ch) {
    data_f[i] = read_float_le_geo(img.data, i * 4)
  }
  let out : Array[Byte] = Array::make(new_w * new_h * ch * 4, b'\x00')
  for dy in 0..<new_h {
    let fdy = Float::from_int(dy)
    for dx in 0..<new_w {
      let fdx = Float::from_int(dx)
      let denom = matrix.m20 * fdx + matrix.m21 * fdy + matrix.m22
      let sx = (matrix.m00 * fdx + matrix.m01 * fdy + matrix.m02) / denom
      let sy = (matrix.m10 * fdx + matrix.m11 * fdy + matrix.m12) / denom
      for ci in 0..<ch {
        let val = sample_bilinear_f(data_f, w, h, ch, ci, sx, sy)
        write_f32_le_geo(out, (dy * new_w + dx) * ch * 4 + ci * 4, val)
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

// ========== resize 16-bit ==========

///|
/// 16-bit 图像缩放。
pub fn resize_16(
  img : @types.Image16,
  new_w : Int,
  new_h : Int,
) -> @types.Image16 {
  let ch = img.channels
  let w = img.width
  let h = img.height
  let data_int : Array[Int] = Array::make(w * h * ch, 0)
  for i in 0..<(w * h * ch) {
    data_int[i] = read_u16_le_geo(img.data, i * 2)
  }
  let scale_x = Float::from_int(w) / Float::from_int(new_w)
  let scale_y = Float::from_int(h) / Float::from_int(new_h)
  let out : Array[Byte] = Array::make(new_w * new_h * ch * 2, b'\x00')
  for dy in 0..<new_h {
    for dx in 0..<new_w {
      let sx = (Float::from_int(dx) + 0.5F) * scale_x - 0.5F
      let sy = (Float::from_int(dy) + 0.5F) * scale_y - 0.5F
      for ci in 0..<ch {
        let val = sample_bilinear_16(data_int, w, h, ch, ci, sx, sy)
        write_u16_le_geo(
          out,
          (dy * new_w + dx) * ch * 2 + ci * 2,
          clamp_int_geo(val, 0, 65535),
        )
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

// ========== resize float ==========

///|
/// float 图像缩放。
pub fn resize_f(img : @types.ImageF, new_w : Int, new_h : Int) -> @types.ImageF {
  let ch = img.channels
  let w = img.width
  let h = img.height
  let data_f : Array[Float] = Array::make(w * h * ch, 0.0F)
  for i in 0..<(w * h * ch) {
    data_f[i] = read_float_le_geo(img.data, i * 4)
  }
  let scale_x = Float::from_int(w) / Float::from_int(new_w)
  let scale_y = Float::from_int(h) / Float::from_int(new_h)
  let out : Array[Byte] = Array::make(new_w * new_h * ch * 4, b'\x00')
  for dy in 0..<new_h {
    for dx in 0..<new_w {
      let sx = (Float::from_int(dx) + 0.5F) * scale_x - 0.5F
      let sy = (Float::from_int(dy) + 0.5F) * scale_y - 0.5F
      for ci in 0..<ch {
        let val = sample_bilinear_f(data_f, w, h, ch, ci, sx, sy)
        write_f32_le_geo(out, (dy * new_w + dx) * ch * 4 + ci * 4, val)
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

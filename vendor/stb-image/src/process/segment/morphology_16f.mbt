// 形态学操作 16-bit/float 变体
// 支持 Image16 / ImageF 两种类型
// StructuringElement 复用 morphology.mbt 中的定义

// 复用 color_16f.mbt 中的 read_u16_le_m / write_u16_le_m / write_f32_le_m
// 复用 tonemap.mbt 中的 read_float_le_m

// ========== 基础操作：erode / dilate ==========

///|
/// 16-bit 腐蚀。每个像素取 3x3 邻域最小值。
pub fn erode_16(img : @types.Image16) -> @types.Image16 {
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let src : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    src[i] = read_u16_le_m(img.data, i * 2)
  }
  // 内部区域
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      for c in 0..<ch {
        let base = ((y - 1) * w + (x - 1)) * ch + c
        let mut min_v = src[base]
        if src[base + ch] < min_v {
          min_v = src[base + ch]
        }
        if src[base + 2 * ch] < min_v {
          min_v = src[base + 2 * ch]
        }
        let row1 = base + w * ch
        if src[row1] < min_v {
          min_v = src[row1]
        }
        if src[row1 + ch] < min_v {
          min_v = src[row1 + ch]
        }
        if src[row1 + 2 * ch] < min_v {
          min_v = src[row1 + 2 * ch]
        }
        let row2 = base + 2 * w * ch
        if src[row2] < min_v {
          min_v = src[row2]
        }
        if src[row2 + ch] < min_v {
          min_v = src[row2 + ch]
        }
        if src[row2 + 2 * ch] < min_v {
          min_v = src[row2 + 2 * ch]
        }
        write_u16_le_m(out, (y * w + x) * bpp + c * 2, min_v)
      }
    }
  }
  // 边界区域
  for y in 0..<h {
    let y_inner = y >= 1 && y < h - 1
    for x in 0..<w {
      if y_inner && x >= 1 && x < w - 1 {
        continue
      }
      for c in 0..<ch {
        let mut min_v = 65535
        for dy in -1..<=1 {
          for dx in -1..<=1 {
            let sx = clamp_morph(x + dx, 0, w - 1)
            let sy = clamp_morph(y + dy, 0, h - 1)
            let v = src[(sy * w + sx) * ch + c]
            if v < min_v {
              min_v = v
            }
          }
        }
        write_u16_le_m(out, (y * w + x) * bpp + c * 2, min_v)
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

///|
/// float 腐蚀。每个像素取 3x3 邻域最小值。
pub fn erode_f(img : @types.ImageF) -> @types.ImageF {
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let src : Array[Float] = Array::make(n * ch, 0.0F)
  for i in 0..<(n * ch) {
    src[i] = read_float_le_m(img.data, i * 4)
  }
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      for c in 0..<ch {
        let base = ((y - 1) * w + (x - 1)) * ch + c
        let mut min_v = src[base]
        if src[base + ch] < min_v {
          min_v = src[base + ch]
        }
        if src[base + 2 * ch] < min_v {
          min_v = src[base + 2 * ch]
        }
        let row1 = base + w * ch
        if src[row1] < min_v {
          min_v = src[row1]
        }
        if src[row1 + ch] < min_v {
          min_v = src[row1 + ch]
        }
        if src[row1 + 2 * ch] < min_v {
          min_v = src[row1 + 2 * ch]
        }
        let row2 = base + 2 * w * ch
        if src[row2] < min_v {
          min_v = src[row2]
        }
        if src[row2 + ch] < min_v {
          min_v = src[row2 + ch]
        }
        if src[row2 + 2 * ch] < min_v {
          min_v = src[row2 + 2 * ch]
        }
        write_f32_le_m(out, (y * w + x) * bpp + c * 4, min_v)
      }
    }
  }
  for y in 0..<h {
    let y_inner = y >= 1 && y < h - 1
    for x in 0..<w {
      if y_inner && x >= 1 && x < w - 1 {
        continue
      }
      for c in 0..<ch {
        let mut min_v = 1.0F
        for dy in -1..<=1 {
          for dx in -1..<=1 {
            let sx = clamp_morph(x + dx, 0, w - 1)
            let sy = clamp_morph(y + dy, 0, h - 1)
            let v = src[(sy * w + sx) * ch + c]
            if v < min_v {
              min_v = v
            }
          }
        }
        write_f32_le_m(out, (y * w + x) * bpp + c * 4, min_v)
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
/// 16-bit 膨胀。每个像素取 3x3 邻域最大值。
pub fn dilate_16(img : @types.Image16) -> @types.Image16 {
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let src : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    src[i] = read_u16_le_m(img.data, i * 2)
  }
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      for c in 0..<ch {
        let base = ((y - 1) * w + (x - 1)) * ch + c
        let mut max_v = src[base]
        if src[base + ch] > max_v {
          max_v = src[base + ch]
        }
        if src[base + 2 * ch] > max_v {
          max_v = src[base + 2 * ch]
        }
        let row1 = base + w * ch
        if src[row1] > max_v {
          max_v = src[row1]
        }
        if src[row1 + ch] > max_v {
          max_v = src[row1 + ch]
        }
        if src[row1 + 2 * ch] > max_v {
          max_v = src[row1 + 2 * ch]
        }
        let row2 = base + 2 * w * ch
        if src[row2] > max_v {
          max_v = src[row2]
        }
        if src[row2 + ch] > max_v {
          max_v = src[row2 + ch]
        }
        if src[row2 + 2 * ch] > max_v {
          max_v = src[row2 + 2 * ch]
        }
        write_u16_le_m(out, (y * w + x) * bpp + c * 2, max_v)
      }
    }
  }
  for y in 0..<h {
    let y_inner = y >= 1 && y < h - 1
    for x in 0..<w {
      if y_inner && x >= 1 && x < w - 1 {
        continue
      }
      for c in 0..<ch {
        let mut max_v = 0
        for dy in -1..<=1 {
          for dx in -1..<=1 {
            let sx = clamp_morph(x + dx, 0, w - 1)
            let sy = clamp_morph(y + dy, 0, h - 1)
            let v = src[(sy * w + sx) * ch + c]
            if v > max_v {
              max_v = v
            }
          }
        }
        write_u16_le_m(out, (y * w + x) * bpp + c * 2, max_v)
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

///|
/// float 膨胀。每个像素取 3x3 邻域最大值。
pub fn dilate_f(img : @types.ImageF) -> @types.ImageF {
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let src : Array[Float] = Array::make(n * ch, 0.0F)
  for i in 0..<(n * ch) {
    src[i] = read_float_le_m(img.data, i * 4)
  }
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      for c in 0..<ch {
        let base = ((y - 1) * w + (x - 1)) * ch + c
        let mut max_v = src[base]
        if src[base + ch] > max_v {
          max_v = src[base + ch]
        }
        if src[base + 2 * ch] > max_v {
          max_v = src[base + 2 * ch]
        }
        let row1 = base + w * ch
        if src[row1] > max_v {
          max_v = src[row1]
        }
        if src[row1 + ch] > max_v {
          max_v = src[row1 + ch]
        }
        if src[row1 + 2 * ch] > max_v {
          max_v = src[row1 + 2 * ch]
        }
        let row2 = base + 2 * w * ch
        if src[row2] > max_v {
          max_v = src[row2]
        }
        if src[row2 + ch] > max_v {
          max_v = src[row2 + ch]
        }
        if src[row2 + 2 * ch] > max_v {
          max_v = src[row2 + 2 * ch]
        }
        write_f32_le_m(out, (y * w + x) * bpp + c * 4, max_v)
      }
    }
  }
  for y in 0..<h {
    let y_inner = y >= 1 && y < h - 1
    for x in 0..<w {
      if y_inner && x >= 1 && x < w - 1 {
        continue
      }
      for c in 0..<ch {
        let mut max_v = 0.0F
        for dy in -1..<=1 {
          for dx in -1..<=1 {
            let sx = clamp_morph(x + dx, 0, w - 1)
            let sy = clamp_morph(y + dy, 0, h - 1)
            let v = src[(sy * w + sx) * ch + c]
            if v > max_v {
              max_v = v
            }
          }
        }
        write_f32_le_m(out, (y * w + x) * bpp + c * 4, max_v)
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

// ========== 组合操作 ==========

///|
/// 16-bit 开运算（先腐蚀后膨胀）。
pub fn morph_open_16(img : @types.Image16) -> @types.Image16 {
  dilate_16(erode_16(img))
}

///|
/// float 开运算（先腐蚀后膨胀）。
pub fn morph_open_f(img : @types.ImageF) -> @types.ImageF {
  dilate_f(erode_f(img))
}

///|
/// 16-bit 闭运算（先膨胀后腐蚀）。
pub fn morph_close_16(img : @types.Image16) -> @types.Image16 {
  erode_16(dilate_16(img))
}

///|
/// float 闭运算（先膨胀后腐蚀）。
pub fn morph_close_f(img : @types.ImageF) -> @types.ImageF {
  erode_f(dilate_f(img))
}

///|
/// 16-bit 形态学梯度（dilate - erode）。
pub fn morph_gradient_16(img : @types.Image16) -> @types.Image16 {
  let dilated = dilate_16(img)
  let eroded = erode_16(img)
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for i in 0..<(n * ch) {
    let v = read_u16_le_m(dilated.data, i * 2) -
      read_u16_le_m(eroded.data, i * 2)
    write_u16_le_m(out, i * 2, if v < 0 { 0 } else { v })
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// float 形态学梯度（dilate - erode）。
pub fn morph_gradient_f(img : @types.ImageF) -> @types.ImageF {
  let dilated = dilate_f(img)
  let eroded = erode_f(img)
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for i in 0..<(n * ch) {
    let v = read_float_le_m(dilated.data, i * 4) -
      read_float_le_m(eroded.data, i * 4)
    write_f32_le_m(out, i * 4, if v < 0.0F { 0.0F } else { v })
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 16-bit 顶帽变换（original - open）。
pub fn morph_tophat_16(img : @types.Image16) -> @types.Image16 {
  let opened = morph_open_16(img)
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for i in 0..<(n * ch) {
    let v = read_u16_le_m(img.data, i * 2) - read_u16_le_m(opened.data, i * 2)
    write_u16_le_m(out, i * 2, if v < 0 { 0 } else { v })
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// float 顶帽变换（original - open）。
pub fn morph_tophat_f(img : @types.ImageF) -> @types.ImageF {
  let opened = morph_open_f(img)
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for i in 0..<(n * ch) {
    let v = read_float_le_m(img.data, i * 4) -
      read_float_le_m(opened.data, i * 4)
    write_f32_le_m(out, i * 4, if v < 0.0F { 0.0F } else { v })
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 16-bit 黑帽变换（close - original）。
pub fn morph_blackhat_16(img : @types.Image16) -> @types.Image16 {
  let closed = morph_close_16(img)
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for i in 0..<(n * ch) {
    let v = read_u16_le_m(closed.data, i * 2) - read_u16_le_m(img.data, i * 2)
    write_u16_le_m(out, i * 2, if v < 0 { 0 } else { v })
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// float 黑帽变换（close - original）。
pub fn morph_blackhat_f(img : @types.ImageF) -> @types.ImageF {
  let closed = morph_close_f(img)
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for i in 0..<(n * ch) {
    let v = read_float_le_m(closed.data, i * 4) -
      read_float_le_m(img.data, i * 4)
    write_f32_le_m(out, i * 4, if v < 0.0F { 0.0F } else { v })
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== 自定义结构元素 ==========

///|
/// 16-bit 自定义结构元素腐蚀。
pub fn erode_custom_16(
  img : @types.Image16,
  se : StructuringElement,
) -> @types.Image16 {
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  let bpp = ch * 2
  let src : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    src[i] = read_u16_le_m(img.data, i * 2)
  }
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let cx = se.width / 2
  let cy = se.height / 2
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<ch {
        let mut min_v = 65535
        for sy in 0..<se.height {
          for sx in 0..<se.width {
            if se.data[sy * se.width + sx] {
              let nx = clamp_morph(x + sx - cx, 0, w - 1)
              let ny = clamp_morph(y + sy - cy, 0, h - 1)
              let v = src[(ny * w + nx) * ch + c]
              if v < min_v {
                min_v = v
              }
            }
          }
        }
        write_u16_le_m(out, (y * w + x) * bpp + c * 2, min_v)
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

///|
/// float 自定义结构元素腐蚀。
pub fn erode_custom_f(
  img : @types.ImageF,
  se : StructuringElement,
) -> @types.ImageF {
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  let bpp = ch * 4
  let src : Array[Float] = Array::make(n * ch, 0.0F)
  for i in 0..<(n * ch) {
    src[i] = read_float_le_m(img.data, i * 4)
  }
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let cx = se.width / 2
  let cy = se.height / 2
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<ch {
        let mut min_v = 1.0F
        for sy in 0..<se.height {
          for sx in 0..<se.width {
            if se.data[sy * se.width + sx] {
              let nx = clamp_morph(x + sx - cx, 0, w - 1)
              let ny = clamp_morph(y + sy - cy, 0, h - 1)
              let v = src[(ny * w + nx) * ch + c]
              if v < min_v {
                min_v = v
              }
            }
          }
        }
        write_f32_le_m(out, (y * w + x) * bpp + c * 4, min_v)
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
/// 16-bit 自定义结构元素膨胀。
pub fn dilate_custom_16(
  img : @types.Image16,
  se : StructuringElement,
) -> @types.Image16 {
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  let bpp = ch * 2
  let src : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    src[i] = read_u16_le_m(img.data, i * 2)
  }
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let cx = se.width / 2
  let cy = se.height / 2
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<ch {
        let mut max_v = 0
        for sy in 0..<se.height {
          for sx in 0..<se.width {
            if se.data[sy * se.width + sx] {
              let nx = clamp_morph(x + sx - cx, 0, w - 1)
              let ny = clamp_morph(y + sy - cy, 0, h - 1)
              let v = src[(ny * w + nx) * ch + c]
              if v > max_v {
                max_v = v
              }
            }
          }
        }
        write_u16_le_m(out, (y * w + x) * bpp + c * 2, max_v)
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

///|
/// float 自定义结构元素膨胀。
pub fn dilate_custom_f(
  img : @types.ImageF,
  se : StructuringElement,
) -> @types.ImageF {
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  let bpp = ch * 4
  let src : Array[Float] = Array::make(n * ch, 0.0F)
  for i in 0..<(n * ch) {
    src[i] = read_float_le_m(img.data, i * 4)
  }
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let cx = se.width / 2
  let cy = se.height / 2
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<ch {
        let mut max_v = 0.0F
        for sy in 0..<se.height {
          for sx in 0..<se.width {
            if se.data[sy * se.width + sx] {
              let nx = clamp_morph(x + sx - cx, 0, w - 1)
              let ny = clamp_morph(y + sy - cy, 0, h - 1)
              let v = src[(ny * w + nx) * ch + c]
              if v > max_v {
                max_v = v
              }
            }
          }
        }
        write_f32_le_m(out, (y * w + x) * bpp + c * 4, max_v)
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
/// 16-bit 自定义结构元素开运算。
pub fn morph_open_custom_16(
  img : @types.Image16,
  se : StructuringElement,
) -> @types.Image16 {
  dilate_custom_16(erode_custom_16(img, se), se)
}

///|
/// float 自定义结构元素开运算。
pub fn morph_open_custom_f(
  img : @types.ImageF,
  se : StructuringElement,
) -> @types.ImageF {
  dilate_custom_f(erode_custom_f(img, se), se)
}

///|
/// 16-bit 自定义结构元素闭运算。
pub fn morph_close_custom_16(
  img : @types.Image16,
  se : StructuringElement,
) -> @types.Image16 {
  erode_custom_16(dilate_custom_16(img, se), se)
}

///|
/// float 自定义结构元素闭运算。
pub fn morph_close_custom_f(
  img : @types.ImageF,
  se : StructuringElement,
) -> @types.ImageF {
  erode_custom_f(dilate_custom_f(img, se), se)
}

// ========== 辅助函数 ==========

///|
fn clamp_morph(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
fn read_u16_le_m(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn write_u16_le_m(buf : Array[Byte], offset : Int, val : Int) -> Unit {
  buf[offset] = (val & 0xFF).to_byte()
  buf[offset + 1] = ((val >> 8) & 0xFF).to_byte()
}

///|
fn read_float_le_m(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

///|
fn write_f32_le_m(buf : Array[Byte], offset : Int, val : Float) -> Unit {
  let bits = val.reinterpret_as_int()
  buf[offset] = (bits & 0xFF).to_byte()
  buf[offset + 1] = ((bits >> 8) & 0xFF).to_byte()
  buf[offset + 2] = ((bits >> 16) & 0xFF).to_byte()
  buf[offset + 3] = ((bits >> 24) & 0xFF).to_byte()
}

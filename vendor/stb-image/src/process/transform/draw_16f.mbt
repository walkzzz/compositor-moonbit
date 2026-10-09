// 绘制函数 16-bit/float 变体
// draw_line / draw_rectangle / draw_circle / draw_polygon

// ========== 辅助函数 ==========

///|
fn write_u16_le_draw(buf : Array[Byte], offset : Int, val : Int) -> Unit {
  buf[offset] = (val & 0xFF).to_byte()
  buf[offset + 1] = ((val >> 8) & 0xFF).to_byte()
}

///|
fn write_f32_le_draw(buf : Array[Byte], offset : Int, val : Float) -> Unit {
  let bits = val.reinterpret_as_int()
  buf[offset] = (bits & 0xFF).to_byte()
  buf[offset + 1] = ((bits >> 8) & 0xFF).to_byte()
  buf[offset + 2] = ((bits >> 16) & 0xFF).to_byte()
  buf[offset + 3] = ((bits >> 24) & 0xFF).to_byte()
}

///|
fn clamp_int_draw(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
fn set_pixel_16(
  buf : Array[Byte],
  x : Int,
  y : Int,
  w : Int,
  ch : Int,
  color : Array[Int],
) -> Unit {
  if x < 0 || x >= w || y < 0 {
    return
  }
  let idx = (y * w + x) * ch * 2
  for c in 0..<ch {
    if c < color.length() {
      write_u16_le_draw(buf, idx + c * 2, clamp_int_draw(color[c], 0, 65535))
    }
  }
}

///|
fn set_pixel_f(
  buf : Array[Byte],
  x : Int,
  y : Int,
  w : Int,
  ch : Int,
  color : Array[Float],
) -> Unit {
  if x < 0 || x >= w || y < 0 {
    return
  }
  let idx = (y * w + x) * ch * 4
  for c in 0..<ch {
    if c < color.length() {
      write_f32_le_draw(buf, idx + c * 4, color[c])
    }
  }
}

// ========== 16-bit 绘制函数 ==========

///|
/// 16-bit 绘制直线。
pub fn draw_line_16(
  img : @types.Image16,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
  color : Array[Int],
  thickness? : Int = 1,
) -> @types.Image16 {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let buf : Array[Byte] = img.data.to_array()
  let dx = if x2 > x1 { x2 - x1 } else { x1 - x2 }
  let dy = if y2 > y1 { y2 - y1 } else { y1 - y2 }
  let sx = if x1 < x2 { 1 } else { -1 }
  let sy = if y1 < y2 { 1 } else { -1 }
  let mut err = dx - dy
  let mut x = x1
  let mut y = y1
  let t = if thickness < 1 { 1 } else { thickness }
  let mut done = false
  while !done {
    for ty in 0..<t {
      for tx in 0..<t {
        set_pixel_16(buf, x + tx, y + ty, w, ch, color)
      }
    }
    if x == x2 && y == y2 {
      done = true
    }
    if !done {
      let e2 = 2 * err
      if e2 > -dy {
        err -= dy
        x += sx
      }
      if e2 < dx {
        err += dx
        y += sy
      }
    }
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(buf),
  }
}

///|
/// 16-bit 绘制矩形。
pub fn draw_rectangle_16(
  img : @types.Image16,
  x : Int,
  y : Int,
  rw : Int,
  rh : Int,
  color : Array[Int],
  thickness? : Int = 1,
  fill? : Bool = false,
) -> @types.Image16 {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let buf : Array[Byte] = img.data.to_array()
  if fill {
    for py in y..<(y + rh) {
      for px in x..<(x + rw) {
        set_pixel_16(buf, px, py, w, ch, color)
      }
    }
  } else {
    let t = if thickness < 1 { 1 } else { thickness }
    for px in x..<(x + rw) {
      for ty in 0..<t {
        set_pixel_16(buf, px, y + ty, w, ch, color)
        set_pixel_16(buf, px, y + rh - 1 - ty, w, ch, color)
      }
    }
    for py in y..<(y + rh) {
      for tx in 0..<t {
        set_pixel_16(buf, x + tx, py, w, ch, color)
        set_pixel_16(buf, x + rw - 1 - tx, py, w, ch, color)
      }
    }
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(buf),
  }
}

///|
/// 16-bit 绘制圆形。
pub fn draw_circle_16(
  img : @types.Image16,
  cx : Int,
  cy : Int,
  r : Int,
  color : Array[Int],
  thickness? : Int = 1,
  fill? : Bool = false,
) -> @types.Image16 {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let buf : Array[Byte] = img.data.to_array()
  if fill {
    for y in (cy - r)..<=(cy + r) {
      for x in (cx - r)..<=(cx + r) {
        let dx = x - cx
        let dy = y - cy
        if dx * dx + dy * dy <= r * r {
          set_pixel_16(buf, x, y, w, ch, color)
        }
      }
    }
  } else {
    let _ = thickness
    let mut x = r
    let mut y = 0
    let mut err = 0
    while x >= y {
      set_pixel_16(buf, cx + x, cy + y, w, ch, color)
      set_pixel_16(buf, cx + y, cy + x, w, ch, color)
      set_pixel_16(buf, cx - y, cy + x, w, ch, color)
      set_pixel_16(buf, cx - x, cy + y, w, ch, color)
      set_pixel_16(buf, cx - x, cy - y, w, ch, color)
      set_pixel_16(buf, cx - y, cy - x, w, ch, color)
      set_pixel_16(buf, cx + y, cy - x, w, ch, color)
      set_pixel_16(buf, cx + x, cy - y, w, ch, color)
      y += 1
      if err <= 0 {
        err += 2 * y + 1
      }
      if err > 0 {
        x -= 1
        err -= 2 * x + 1
      }
    }
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(buf),
  }
}

///|
/// 16-bit 绘制多边形。
pub fn draw_polygon_16(
  img : @types.Image16,
  points : Array[(Int, Int)],
  color : Array[Int],
  thickness? : Int = 1,
) -> @types.Image16 {
  let mut result = img
  let n = points.length()
  if n < 2 {
    return result
  }
  for i in 0..<n {
    let (x1, y1) = points[i]
    let (x2, y2) = points[(i + 1) % n]
    result = draw_line_16(result, x1, y1, x2, y2, color, thickness~)
  }
  result
}

// ========== float 绘制函数 ==========

///|
/// float 绘制直线。
pub fn draw_line_f(
  img : @types.ImageF,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
  color : Array[Float],
  thickness? : Int = 1,
) -> @types.ImageF {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let buf : Array[Byte] = img.data.to_array()
  let dx = if x2 > x1 { x2 - x1 } else { x1 - x2 }
  let dy = if y2 > y1 { y2 - y1 } else { y1 - y2 }
  let sx = if x1 < x2 { 1 } else { -1 }
  let sy = if y1 < y2 { 1 } else { -1 }
  let mut err = dx - dy
  let mut x = x1
  let mut y = y1
  let t = if thickness < 1 { 1 } else { thickness }
  let mut done = false
  while !done {
    for ty in 0..<t {
      for tx in 0..<t {
        set_pixel_f(buf, x + tx, y + ty, w, ch, color)
      }
    }
    if x == x2 && y == y2 {
      done = true
    }
    if !done {
      let e2 = 2 * err
      if e2 > -dy {
        err -= dy
        x += sx
      }
      if e2 < dx {
        err += dx
        y += sy
      }
    }
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(buf),
  }
}

///|
/// float 绘制矩形。
pub fn draw_rectangle_f(
  img : @types.ImageF,
  x : Int,
  y : Int,
  rw : Int,
  rh : Int,
  color : Array[Float],
  thickness? : Int = 1,
  fill? : Bool = false,
) -> @types.ImageF {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let buf : Array[Byte] = img.data.to_array()
  if fill {
    for py in y..<(y + rh) {
      for px in x..<(x + rw) {
        set_pixel_f(buf, px, py, w, ch, color)
      }
    }
  } else {
    let t = if thickness < 1 { 1 } else { thickness }
    for px in x..<(x + rw) {
      for ty in 0..<t {
        set_pixel_f(buf, px, y + ty, w, ch, color)
        set_pixel_f(buf, px, y + rh - 1 - ty, w, ch, color)
      }
    }
    for py in y..<(y + rh) {
      for tx in 0..<t {
        set_pixel_f(buf, x + tx, py, w, ch, color)
        set_pixel_f(buf, x + rw - 1 - tx, py, w, ch, color)
      }
    }
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(buf),
  }
}

///|
/// float 绘制圆形。
pub fn draw_circle_f(
  img : @types.ImageF,
  cx : Int,
  cy : Int,
  r : Int,
  color : Array[Float],
  thickness? : Int = 1,
  fill? : Bool = false,
) -> @types.ImageF {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let buf : Array[Byte] = img.data.to_array()
  if fill {
    for y in (cy - r)..<=(cy + r) {
      for x in (cx - r)..<=(cx + r) {
        let dx = x - cx
        let dy = y - cy
        if dx * dx + dy * dy <= r * r {
          set_pixel_f(buf, x, y, w, ch, color)
        }
      }
    }
  } else {
    let _ = thickness
    let mut x = r
    let mut y = 0
    let mut err = 0
    while x >= y {
      set_pixel_f(buf, cx + x, cy + y, w, ch, color)
      set_pixel_f(buf, cx + y, cy + x, w, ch, color)
      set_pixel_f(buf, cx - y, cy + x, w, ch, color)
      set_pixel_f(buf, cx - x, cy + y, w, ch, color)
      set_pixel_f(buf, cx - x, cy - y, w, ch, color)
      set_pixel_f(buf, cx - y, cy - x, w, ch, color)
      set_pixel_f(buf, cx + y, cy - x, w, ch, color)
      set_pixel_f(buf, cx + x, cy - y, w, ch, color)
      y += 1
      if err <= 0 {
        err += 2 * y + 1
      }
      if err > 0 {
        x -= 1
        err -= 2 * x + 1
      }
    }
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(buf),
  }
}

///|
/// float 绘制多边形。
pub fn draw_polygon_f(
  img : @types.ImageF,
  points : Array[(Int, Int)],
  color : Array[Float],
  thickness? : Int = 1,
) -> @types.ImageF {
  let mut result = img
  let n = points.length()
  if n < 2 {
    return result
  }
  for i in 0..<n {
    let (x1, y1) = points[i]
    let (x2, y2) = points[(i + 1) % n]
    result = draw_line_f(result, x1, y1, x2, y2, color, thickness~)
  }
  result
}

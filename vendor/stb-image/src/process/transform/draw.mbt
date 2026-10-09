// 图像合成操作（纯 MoonBit）：draw_over / draw_copy

///|
/// 将 src 图像直接拷贝到 dst 的 (x, y) 位置
/// 返回新的 Image，不修改原图。要求 dst 和 src channels 相同。
pub fn draw_copy(
  dst : @types.Image,
  src : @types.Image,
  x : Int,
  y : Int,
) -> @types.Image raise @types.LoadError {
  if dst.channels != src.channels {
    raise @types.LoadError::DecodeFailed(
      "draw_copy 要求 dst 和 src channels 相同",
    )
  }
  if x < 0 || y < 0 || x + src.width > dst.width || y + src.height > dst.height {
    raise @types.LoadError::DecodeFailed("draw_copy 区域越界")
  }
  let ch = dst.channels
  let out : Array[Byte] = []
  for i in 0..<dst.data.length() {
    out.push(dst.data[i])
  }
  for row in 0..<src.height {
    for col in 0..<src.width {
      let src_off = (row * src.width + col) * ch
      let dst_off = ((y + row) * dst.width + (x + col)) * ch
      for c in 0..<ch {
        out[dst_off + c] = src.data[src_off + c]
      }
    }
  }
  @types.Image::{
    width: dst.width,
    height: dst.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// Alpha 混合合成（source over destination）
/// 将 src 图像合成到 dst 的 (x, y) 位置
/// 要求 dst 和 src 均为 RGBA (channels=4)
/// 公式: result = src * src_a + dst * (1 - src_a)
pub fn draw_over(
  dst : @types.Image,
  src : @types.Image,
  x : Int,
  y : Int,
) -> @types.Image raise @types.LoadError {
  if dst.channels != 4 || src.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "draw_over 要求 dst 和 src 均为 RGBA (channels=4)",
    )
  }
  if x < 0 || y < 0 || x + src.width > dst.width || y + src.height > dst.height {
    raise @types.LoadError::DecodeFailed("draw_over 区域越界")
  }
  let out : Array[Byte] = []
  for i in 0..<dst.data.length() {
    out.push(dst.data[i])
  }
  let src_n = src.width * src.height
  let src_int : Array[Int] = Array::make(src_n * 4, 0)
  for i in 0..<(src_n * 4) {
    src_int[i] = src.data[i].to_int()
  }
  for row in 0..<src.height {
    for col in 0..<src.width {
      let src_off = (row * src.width + col) * 4
      let dst_off = ((y + row) * dst.width + (x + col)) * 4
      let sr = src_int[src_off]
      let sg = src_int[src_off + 1]
      let sb = src_int[src_off + 2]
      let sa = src_int[src_off + 3]
      let dr = out[dst_off].to_int()
      let dg = out[dst_off + 1].to_int()
      let db = out[dst_off + 2].to_int()
      let da = out[dst_off + 3].to_int()
      let inv_sa = 255 - sa
      let rr = (sr * sa + dr * inv_sa) / 255
      let rg = (sg * sa + dg * inv_sa) / 255
      let rb = (sb * sa + db * inv_sa) / 255
      let ra = sa + da * inv_sa / 255
      out[dst_off] = rr.to_byte()
      out[dst_off + 1] = rg.to_byte()
      out[dst_off + 2] = rb.to_byte()
      out[dst_off + 3] = ra.to_byte()
    }
  }
  @types.Image::{
    width: dst.width,
    height: dst.height,
    channels: 4,
    data: Bytes::from_array(out),
  }
}

///|
fn put_pixel(
  out : Array[Byte],
  w : Int,
  h : Int,
  ch : Int,
  x : Int,
  y : Int,
  color : Array[Byte],
) -> Unit {
  if x < 0 || x >= w || y < 0 || y >= h {
    return
  }
  let off = (y * w + x) * ch
  for c in 0..<ch {
    if c < color.length() {
      out[off + c] = color[c]
    }
  }
}

///|
/// 画线段（Bresenham 算法）。color 为颜色数组（如 [R,G,B]）。thickness 为线宽（默认 1）。
pub fn draw_line(
  img : @types.Image,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
  color : Array[Byte],
  thickness? : Int = 1,
) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let out : Array[Byte] = []
  for i in 0..<img.data.length() {
    out.push(img.data[i])
  }
  let t = thickness / 2
  let dx = (x2 - x1).abs()
  let dy = (y2 - y1).abs()
  let sx = if x1 < x2 { 1 } else { -1 }
  let sy = if y1 < y2 { 1 } else { -1 }
  let mut err = dx - dy
  let mut x = x1
  let mut y = y1
  while true {
    for ty in -t..<=t {
      for tx in -t..<=t {
        put_pixel(out, w, h, ch, x + tx, y + ty, color)
      }
    }
    if x == x2 && y == y2 {
      break
    }
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
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 画矩形。color 为颜色数组。thickness 为线宽（默认 1）。fill 为是否填充（默认 false）。
pub fn draw_rectangle(
  img : @types.Image,
  x : Int,
  y : Int,
  rw : Int,
  rh : Int,
  color : Array[Byte],
  thickness? : Int = 1,
  fill? : Bool = false,
) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let out : Array[Byte] = []
  for i in 0..<img.data.length() {
    out.push(img.data[i])
  }
  if fill {
    for py in y..<(y + rh) {
      for px in x..<(x + rw) {
        put_pixel(out, w, h, ch, px, py, color)
      }
    }
  } else {
    let result = draw_line(
      @types.Image::{
        width: w,
        height: h,
        channels: ch,
        data: Bytes::from_array(out),
      },
      x,
      y,
      x + rw - 1,
      y,
      color,
      thickness~,
    )
    let result2 = draw_line(
      result,
      x + rw - 1,
      y,
      x + rw - 1,
      y + rh - 1,
      color,
      thickness~,
    )
    let result3 = draw_line(
      result2,
      x,
      y + rh - 1,
      x + rw - 1,
      y + rh - 1,
      color,
      thickness~,
    )
    let result4 = draw_line(result3, x, y, x, y + rh - 1, color, thickness~)
    return result4
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 画圆（中点画圆算法）。color 为颜色数组。thickness 为线宽（默认 1）。fill 为是否填充（默认 false）。
pub fn draw_circle(
  img : @types.Image,
  cx : Int,
  cy : Int,
  r : Int,
  color : Array[Byte],
  thickness? : Int = 1,
  fill? : Bool = false,
) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let out : Array[Byte] = []
  for i in 0..<img.data.length() {
    out.push(img.data[i])
  }
  if fill {
    for py in -r..<=r {
      let px_max = Float::from_int(r * r - py * py).sqrt().to_int()
      for px in -px_max..<=px_max {
        put_pixel(out, w, h, ch, cx + px, cy + py, color)
      }
    }
  } else {
    let mut x = r
    let mut y = 0
    let mut d = 1 - r
    let t = thickness / 2
    while x >= y {
      for dx in -t..<=t {
        put_pixel(out, w, h, ch, cx + x + dx, cy + y, color)
        put_pixel(out, w, h, ch, cx - x + dx, cy + y, color)
        put_pixel(out, w, h, ch, cx + x + dx, cy - y, color)
        put_pixel(out, w, h, ch, cx - x + dx, cy - y, color)
        put_pixel(out, w, h, ch, cx + y + dx, cy + x, color)
        put_pixel(out, w, h, ch, cx - y + dx, cy + x, color)
        put_pixel(out, w, h, ch, cx + y + dx, cy - x, color)
        put_pixel(out, w, h, ch, cx - y + dx, cy - x, color)
      }
      y += 1
      if d <= 0 {
        d += 2 * y + 1
      } else {
        x -= 1
        d += 2 * (y - x) + 1
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

///|
/// 画多边形。points 为顶点数组 [(x1,y1), (x2,y2), ...]。color 为颜色数组。thickness 为线宽（默认 1）。fill 为是否填充（默认 false）。
pub fn draw_polygon(
  img : @types.Image,
  points : Array[(Int, Int)],
  color : Array[Byte],
  thickness? : Int = 1,
  fill? : Bool = false,
) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let out : Array[Byte] = []
  for i in 0..<img.data.length() {
    out.push(img.data[i])
  }
  let n = points.length()
  if n < 2 {
    return @types.Image::{
      width: w,
      height: h,
      channels: ch,
      data: Bytes::from_array(out),
    }
  }
  // 画轮廓
  let mut result = @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
  for i in 0..<n {
    let (x1, y1) = points[i]
    let (x2, y2) = points[(i + 1) % n]
    result = draw_line(result, x1, y1, x2, y2, color, thickness~)
  }
  if fill {
    // 扫描线填充
    let fill_out : Array[Byte] = []
    for i in 0..<result.data.length() {
      fill_out.push(result.data[i])
    }
    let mut y_min = h
    let mut y_max = 0
    for i in 0..<n {
      let (_, py) = points[i]
      if py < y_min {
        y_min = py
      }
      if py > y_max {
        y_max = py
      }
    }
    for y in y_min..<=y_max {
      // 求交点
      let xs : Array[Int] = []
      for i in 0..<n {
        let (x1, y1) = points[i]
        let (x2, y2) = points[(i + 1) % n]
        if y1 == y2 {
          continue
        }
        if y < y1 && y < y2 {
          continue
        }
        if y >= y1 && y >= y2 {
          continue
        }
        let x = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
        xs.push(x)
      }
      // 排序交点
      xs.sort()
      // 填充相邻对
      let mut j = 0
      while j + 1 < xs.length() {
        for x in xs[j]..<=xs[j + 1] {
          put_pixel(fill_out, w, h, ch, x, y, color)
        }
        j += 2
      }
    }
    return @types.Image::{
      width: w,
      height: h,
      channels: ch,
      data: Bytes::from_array(fill_out),
    }
  }
  result
}

// 轮廓提取与绘制 16-bit/float 变体

///|
/// 提取轮廓 16-bit 版本。
pub fn find_contours_16(
  img : @types.Image16,
) -> Array[Contour] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "find_contours_16: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "find_contours_16: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "find_contours_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let w = img.width
  let h = img.height
  let ch = img.channels
  let binary : Array[Bool] = Array::make(w * h, false)
  for i in 0..<(w * h) {
    let v = img.data[i * ch * 2].to_int() |
      (img.data[i * ch * 2 + 1].to_int() << 8)
    binary[i] = v > 0
  }
  let visited : Array[Bool] = Array::make(w * h, false)
  let contours : Array[Contour] = []
  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      if binary[idx] && !visited[idx] {
        let is_outer = y == 0 || !binary[idx - w]
        let contour = trace_boundary_16f(binary, visited, x, y, w, h, is_outer)
        if contour.points.length() > 0 {
          contours.push(contour)
        }
      }
    }
  }
  contours
}

///|
/// 提取轮廓 float 版本。
pub fn find_contours_f(
  img : @types.ImageF,
) -> Array[Contour] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "find_contours_f: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "find_contours_f: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "find_contours_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let w = img.width
  let h = img.height
  let ch = img.channels
  let binary : Array[Bool] = Array::make(w * h, false)
  for i in 0..<(w * h) {
    let bits = img.data[i * ch * 4].to_int() |
      (img.data[i * ch * 4 + 1].to_int() << 8) |
      (img.data[i * ch * 4 + 2].to_int() << 16) |
      (img.data[i * ch * 4 + 3].to_int() << 24)
    binary[i] = Float::reinterpret_from_int(bits) > 0.0F
  }
  let visited : Array[Bool] = Array::make(w * h, false)
  let contours : Array[Contour] = []
  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      if binary[idx] && !visited[idx] {
        let is_outer = y == 0 || !binary[idx - w]
        let contour = trace_boundary_16f(binary, visited, x, y, w, h, is_outer)
        if contour.points.length() > 0 {
          contours.push(contour)
        }
      }
    }
  }
  contours
}

///|
/// Moore 边界跟踪（16/f 共用）
fn trace_boundary_16f(
  binary : Array[Bool],
  visited : Array[Bool],
  start_x : Int,
  start_y : Int,
  w : Int,
  h : Int,
  is_outer : Bool,
) -> Contour {
  let points : Array[ContourPoint] = []
  let mut cx = start_x
  let mut cy = start_y
  let mut dir_idx = 0
  let mut count = 0
  let max_count = w * h * 8 + 1
  while count < max_count {
    let idx = cy * w + cx
    if !visited[idx] {
      visited[idx] = true
      points.push(ContourPoint::{ x: cx, y: cy })
    }
    count += 1
    let mut found = false
    for i in 0..<8 {
      let d = (dir_idx + i) % 8
      let (dx, dy) = match d {
        0 => (1, 0)
        1 => (1, 1)
        2 => (0, 1)
        3 => (-1, 1)
        4 => (-1, 0)
        5 => (-1, -1)
        6 => (0, -1)
        _ => (1, -1)
      }
      let nx = cx + dx
      let ny = cy + dy
      if nx >= 0 && nx < w && ny >= 0 && ny < h && binary[ny * w + nx] {
        cx = nx
        cy = ny
        dir_idx = (d + 6) % 8
        found = true
        break
      }
    }
    if !found {
      break
    }
    if cx == start_x && cy == start_y {
      break
    }
  }
  Contour::{ points, is_outer }
}

///|
/// 绘制轮廓 16-bit 版本。
pub fn draw_contours_16(
  img : @types.Image16,
  contours : Array[Contour],
  color : Array[Int],
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "draw_contours_16: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "draw_contours_16: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "draw_contours_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if color.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "draw_contours_16: color数组不能为空",
    )
  }
  let ch = img.channels
  let w = img.width
  let h = img.height
  let out : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  for i in 0..<(w * h * ch) {
    out[i * 2] = img.data[i * 2]
    out[i * 2 + 1] = img.data[i * 2 + 1]
  }
  let draw_ch = if ch >= 3 { 3 } else { 1 }
  for contour in contours {
    for pt in contour.points {
      if pt.x >= 0 && pt.x < w && pt.y >= 0 && pt.y < h {
        for c in 0..<draw_ch {
          if c < color.length() {
            let v = color[c]
            out[((pt.y * w + pt.x) * ch + c) * 2] = (v & 0xFF).to_byte()
            out[((pt.y * w + pt.x) * ch + c) * 2 + 1] = ((v >> 8) & 0xFF).to_byte()
          }
        }
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
/// 绘制轮廓 float 版本。
pub fn draw_contours_f(
  img : @types.ImageF,
  contours : Array[Contour],
  color : Array[Float],
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "draw_contours_f: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "draw_contours_f: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "draw_contours_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if color.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "draw_contours_f: color数组不能为空",
    )
  }
  let ch = img.channels
  let w = img.width
  let h = img.height
  let out : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  for i in 0..<(w * h * ch) {
    out[i * 4] = img.data[i * 4]
    out[i * 4 + 1] = img.data[i * 4 + 1]
    out[i * 4 + 2] = img.data[i * 4 + 2]
    out[i * 4 + 3] = img.data[i * 4 + 3]
  }
  let draw_ch = if ch >= 3 { 3 } else { 1 }
  for contour in contours {
    for pt in contour.points {
      if pt.x >= 0 && pt.x < w && pt.y >= 0 && pt.y < h {
        for c in 0..<draw_ch {
          if c < color.length() {
            let bits = color[c].reinterpret_as_int()
            out[((pt.y * w + pt.x) * ch + c) * 4] = (bits & 0xFF).to_byte()
            out[((pt.y * w + pt.x) * ch + c) * 4 + 1] = ((bits >> 8) & 0xFF).to_byte()
            out[((pt.y * w + pt.x) * ch + c) * 4 + 2] = ((bits >> 16) & 0xFF).to_byte()
            out[((pt.y * w + pt.x) * ch + c) * 4 + 3] = ((bits >> 24) & 0xFF).to_byte()
          }
        }
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

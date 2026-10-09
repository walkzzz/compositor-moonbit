// 轮廓提取与绘制（纯 MoonBit）

///|
/// 轮廓点
pub(all) struct ContourPoint {
  x : Int
  y : Int
}

///|
/// 轮廓
pub(all) struct Contour {
  points : Array[ContourPoint]
  is_outer : Bool // true=外轮廓, false=内轮廓(孔洞)
}

///|
/// 提取轮廓（Suzuki 边界跟踪简化版）。
/// 对二值图（非零为前景）提取所有外轮廓。
/// 仅处理灰度图（channels=1）或 RGB 图（channels=3/4，取首通道）。
pub fn find_contours(
  img : @types.Image,
) -> Array[Contour] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "find_contours: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "find_contours: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "find_contours: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let w = img.width
  let h = img.height
  let ch = img.channels
  // 转为二值（直接从首通道计算，消除中间数组）
  let binary : Array[Bool] = Array::make(w * h, false)
  for i in 0..<(w * h) {
    binary[i] = img.data[i * ch].to_int() > 0
  }
  let visited : Array[Bool] = Array::make(w * h, false)
  let contours : Array[Contour] = []
  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      if binary[idx] && !visited[idx] {
        // 检查是否为外轮廓起点（上方为背景或边界）
        let is_outer = y == 0 || !binary[idx - w]
        let contour = trace_boundary(binary, visited, x, y, w, h, is_outer)
        if contour.points.length() > 0 {
          contours.push(contour)
        }
      }
    }
  }
  contours
}

///|
/// Moore 边界跟踪
fn trace_boundary(
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
  let mut dir_idx = 0 // 起始方向
  let mut count = 0
  let max_count = w * h * 8 + 1
  while count < max_count {
    let idx = cy * w + cx
    if !visited[idx] {
      visited[idx] = true
      points.push(ContourPoint::{ x: cx, y: cy })
    }
    count += 1
    // 寻找下一个前景像素（match 替代数组查找，消除堆分配）
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
        // 下次搜索方向：回退两个方向
        dir_idx = (d + 6) % 8
        found = true
        break
      }
    }
    if !found {
      break
    }
    // 回到起点则结束
    if cx == start_x && cy == start_y {
      break
    }
  }
  Contour::{ points, is_outer }
}

///|
/// 绘制轮廓到图像上。color 为绘制颜色数组（长度 >= channels）。
pub fn draw_contours(
  img : @types.Image,
  contours : Array[Contour],
  color : Array[Byte],
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "draw_contours: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "draw_contours: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "draw_contours: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if color.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "draw_contours: color数组不能为空",
    )
  }
  let ch = img.channels
  let w = img.width
  let h = img.height
  let out : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for i in 0..<(w * h * ch) {
    out[i] = img.data[i]
  }
  let draw_ch = if ch >= 3 { 3 } else { 1 }
  for contour in contours {
    for pt in contour.points {
      if pt.x >= 0 && pt.x < w && pt.y >= 0 && pt.y < h {
        for c in 0..<draw_ch {
          if c < color.length() {
            out[(pt.y * w + pt.x) * ch + c] = color[c]
          }
        }
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
/// 计算轮廓周长
pub fn contour_perimeter(contour : Contour) -> Float {
  let pts = contour.points
  if pts.length() < 2 {
    return 0.0F
  }
  let mut perim = 0.0F
  for i in 0..<pts.length() {
    let j = (i + 1) % pts.length()
    let dx = pts[i].x - pts[j].x
    let dy = pts[i].y - pts[j].y
    perim += Float::from_int(dx * dx + dy * dy).sqrt()
  }
  perim
}

///|
/// 计算轮廓面积（鞋带公式）
pub fn contour_area(contour : Contour) -> Float {
  let pts = contour.points
  if pts.length() < 3 {
    return 0.0F
  }
  let mut area = 0.0F
  for i in 0..<pts.length() {
    let j = (i + 1) % pts.length()
    area += Float::from_int(pts[i].x * pts[j].y - pts[j].x * pts[i].y)
  }
  (area / 2.0F).abs()
}

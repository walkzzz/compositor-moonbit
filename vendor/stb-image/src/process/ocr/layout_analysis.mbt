// 版面分析
// 文本区域检测、页面分割、多栏检测

///|
/// 文本区域结构体
pub(all) struct TextRegion {
  x : Int
  y : Int
  width : Int
  height : Int
  region_type : TextRegionType
}

///|
/// 文本区域类型
pub(all) enum TextRegionType {
  Text
  Image
  Table
  Unknown
} derive(Eq)

///|
/// 文本行结构体
pub(all) struct TextLine {
  x : Int
  y : Int
  width : Int
  height : Int
}

///|
/// 检测文本区域（基于投影分析）
/// 返回文本区域列表
pub fn detect_text_regions(
  img : @types.Image,
) -> Array[TextRegion] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_text_regions: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "detect_text_regions: 仅支持单通道灰度图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "detect_text_regions: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let w = img.width
  let h = img.height
  let data = img.data
  // 二值化（简单阈值）
  let binary : Array[Bool] = Array::make(w * h, false)
  for i in 0..<(w * h) {
    binary[i] = data[i].to_int() < 128
  }
  // 水平投影（检测文本行）
  let horizontal_proj : Array[Int] = Array::make(h, 0)
  for y in 0..<h {
    for x in 0..<w {
      if binary[y * w + x] {
        horizontal_proj[y] += 1
      }
    }
  }
  // 检测文本行区域
  let regions : Array[TextRegion] = []
  let mut in_text = false
  let mut start_y = 0
  let threshold = w / 20 // 文本行阈值
  for y in 0..<h {
    if horizontal_proj[y] > threshold && !in_text {
      in_text = true
      start_y = y
    } else if horizontal_proj[y] <= threshold && in_text {
      in_text = false
      // 计算这一行的水平范围
      let mut min_x = w
      let mut max_x = 0
      for yy in start_y..<y {
        for x in 0..<w {
          if binary[yy * w + x] {
            if x < min_x {
              min_x = x
            }
            if x > max_x {
              max_x = x
            }
          }
        }
      }
      if max_x > min_x {
        regions.push(TextRegion::{
          x: min_x,
          y: start_y,
          width: max_x - min_x + 1,
          height: y - start_y,
          region_type: TextRegionType::Text,
        })
      }
    }
  }
  regions
}

///|
/// 页面分割（文本/图像/表格区域）
/// 返回区域列表
pub fn segment_page(
  img : @types.Image,
) -> Array[TextRegion] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "segment_page: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "segment_page: 仅支持单通道灰度图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "segment_page: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let w = img.width
  let h = img.height
  let data = img.data
  // 二值化
  let binary : Array[Bool] = Array::make(w * h, false)
  for i in 0..<(w * h) {
    binary[i] = data[i].to_int() < 128
  }
  // 连通域分析（简化版）
  let visited : Array[Bool] = Array::make(w * h, false)
  let regions : Array[TextRegion] = []
  for y in 0..<h {
    for x in 0..<w {
      if binary[y * w + x] && !visited[y * w + x] {
        // BFS 找连通域
        let mut min_x = x
        let mut max_x = x
        let mut min_y = y
        let mut max_y = y
        let mut count = 0
        let queue : Array[(Int, Int)] = [(x, y)]
        visited[y * w + x] = true
        let mut queue_idx = 0
        while queue_idx < queue.length() {
          let (cx, cy) = queue[queue_idx]
          queue_idx += 1
          count += 1
          if cx < min_x {
            min_x = cx
          }
          if cx > max_x {
            max_x = cx
          }
          if cy < min_y {
            min_y = cy
          }
          if cy > max_y {
            max_y = cy
          }
          // 8 邻域
          for dy in -1..<2 {
            for dx in -1..<2 {
              let nx = cx + dx
              let ny = cy + dy
              if nx >= 0 &&
                nx < w &&
                ny >= 0 &&
                ny < h &&
                binary[ny * w + nx] &&
                !visited[ny * w + nx] {
                visited[ny * w + nx] = true
                queue.push((nx, ny))
              }
            }
          }
        }
        // 根据区域大小和宽高比判断类型
        let region_w = max_x - min_x + 1
        let region_h = max_y - min_y + 1
        let region_type = if count < 50 {
          TextRegionType::Unknown // 噪声
        } else if region_w > 50 && region_h > 50 {
          TextRegionType::Image // 大区域可能是图像
        } else {
          TextRegionType::Text // 小区域可能是文字
        }
        regions.push(TextRegion::{
          x: min_x,
          y: min_y,
          width: region_w,
          height: region_h,
          region_type,
        })
      }
    }
  }
  regions
}

///|
/// 检测多栏布局
/// 返回栏数和每栏的 x 范围
pub fn detect_columns(
  img : @types.Image,
) -> (Int, Array[(Int, Int)]) raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_columns: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "detect_columns: 仅支持单通道灰度图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "detect_columns: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let w = img.width
  let h = img.height
  let data = img.data
  // 垂直投影
  let vertical_proj : Array[Int] = Array::make(w, 0)
  for y in 0..<h {
    for x in 0..<w {
      if data[y * w + x].to_int() < 128 {
        vertical_proj[x] += 1
      }
    }
  }
  // 找空白列（栏间距）
  let threshold = h / 50 // 空白列阈值
  let gaps : Array[(Int, Int)] = []
  let mut in_gap = false
  let mut gap_start = 0
  for x in 0..<w {
    if vertical_proj[x] < threshold && !in_gap {
      in_gap = true
      gap_start = x
    } else if vertical_proj[x] >= threshold && in_gap {
      in_gap = false
      let gap_width = x - gap_start
      if gap_width > w / 20 { // 足够宽的间隙才算栏间距
        gaps.push((gap_start, x))
      }
    }
  }
  // 根据间隙计算栏数和范围
  let num_columns = gaps.length() + 1
  let columns : Array[(Int, Int)] = []
  let mut prev_end = 0
  for i in 0..<gaps.length() {
    let (start, end) = gaps[i]
    columns.push((prev_end, start))
    prev_end = end
  }
  columns.push((prev_end, w))
  (num_columns, columns)
}

///|
/// 提取文本行图像
/// 返回文本行图像列表
pub fn extract_text_lines(
  img : @types.Image,
) -> Array[@types.Image] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "extract_text_lines: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "extract_text_lines: 仅支持单通道灰度图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "extract_text_lines: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let regions = detect_text_regions(img)
  let lines : Array[@types.Image] = []
  for region in regions {
    if region.region_type == TextRegionType::Text {
      let line = crop_region(
        img,
        region.x,
        region.y,
        region.width,
        region.height,
      )
      match line {
        Some(l) => lines.push(l)
        None => ignore(())
      }
    }
  }
  lines
}

///|
/// 裁剪图像区域
fn crop_region(
  img : @types.Image,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) -> @types.Image? {
  let w = img.width
  let h = img.height
  let ch = img.channels
  if x < 0 || y < 0 || x + width > w || y + height > h {
    return None
  }
  let out : Array[Byte] = Array::make(width * height * ch, b'\x00')
  let data = img.data
  for yy in 0..<height {
    for xx in 0..<width {
      for c in 0..<ch {
        out[(yy * width + xx) * ch + c] = data[((y + yy) * w + (x + xx)) * ch +
          c]
      }
    }
  }
  Some(@types.Image::{
    width,
    height,
    channels: ch,
    data: Bytes::from_array(out),
  })
}

///|
/// OCR 完整预处理流水线
/// 灰度化 -> 去噪 -> 倾斜校正 -> 二值化 -> 输出
pub fn ocr_preprocess(
  img : @types.Image,
  binarization_method? : String = "sauvola",
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "ocr_preprocess: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "ocr_preprocess: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "ocr_preprocess: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let mut result = img
  // 1. 转灰度
  if result.channels != 1 {
    result = to_grayscale_ocr(result)
  }
  // 2. 文档增强（去噪+对比度+锐化）
  result = document_enhance(result)
  // 3. 倾斜校正
  result = deskew(result)
  // 4. 二值化
  result = match binarization_method {
    "sauvola" => sauvola_threshold(result)
    "niblack" => niblack_threshold(result)
    "otsu" => otsu_threshold(result)
    "adaptive" => adaptive_threshold_ocr(result)
    _ => sauvola_threshold(result)
  }
  result
}

///|
/// 转灰度（OCR 专用）
fn to_grayscale_ocr(img : @types.Image) -> @types.Image {
  if img.channels == 1 {
    return img
  }
  let n = img.width * img.height
  let ch = img.channels
  let out : Array[Byte] = Array::make(n, b'\x00')
  let data = img.data
  for i in 0..<n {
    let base = i * ch
    let r = data[base].to_int()
    let g = data[base + 1].to_int()
    let b = data[base + 2].to_int()
    let gray = (r * 299 + g * 587 + b * 114) / 1000
    out[i] = gray.to_byte()
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

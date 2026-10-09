// 投影分析与文本行分割
// 水平/垂直投影、文本行检测、字符分割

///|
/// 投影结果结构体
pub(all) struct ProjectionResult {
  projection : Array[Int]
  peaks : Array[Int]
  valleys : Array[Int]
  mean : Double
  stddev : Double
}

///|
/// 水平投影（按行统计前景像素数）
pub fn horizontal_projection(
  img : @types.Image,
) -> ProjectionResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "horizontal_projection: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "horizontal_projection: 仅支持单通道二值图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "horizontal_projection: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let w = img.width
  let h = img.height
  let data = img.data
  let projection : Array[Int] = Array::make(h, 0)
  for y in 0..<h {
    for x in 0..<w {
      if data[y * w + x].to_int() > 128 {
        projection[y] += 1
      }
    }
  }
  analyze_projection(projection)
}

///|
/// 垂直投影（按列统计前景像素数）
pub fn vertical_projection(
  img : @types.Image,
) -> ProjectionResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "vertical_projection: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "vertical_projection: 仅支持单通道二值图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "vertical_projection: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let w = img.width
  let h = img.height
  let data = img.data
  let projection : Array[Int] = Array::make(w, 0)
  for y in 0..<h {
    for x in 0..<w {
      if data[y * w + x].to_int() > 128 {
        projection[x] += 1
      }
    }
  }
  analyze_projection(projection)
}

///|
/// 分析投影（找峰值、谷值、均值、标准差）
fn analyze_projection(projection : Array[Int]) -> ProjectionResult {
  let n = projection.length()
  // 计算均值和标准差
  let mut sum = 0
  let mut sum_sq = 0
  for i in 0..<n {
    sum += projection[i]
    sum_sq += projection[i] * projection[i]
  }
  let mean = if n > 0 { sum.to_double() / n.to_double() } else { 0.0 }
  let variance = if n > 0 {
    sum_sq.to_double() / n.to_double() - mean * mean
  } else {
    0.0
  }
  let stddev = if variance > 0.0 { variance.sqrt() } else { 0.0 }
  // 找峰值（局部最大值）
  let peaks : Array[Int] = []
  for i in 1..<(n - 1) {
    if projection[i] > projection[i - 1] &&
      projection[i] >= projection[i + 1] &&
      projection[i].to_double() > mean {
      peaks.push(i)
    }
  }
  // 找谷值（局部最小值）
  let valleys : Array[Int] = []
  for i in 1..<(n - 1) {
    if projection[i] < projection[i - 1] &&
      projection[i] <= projection[i + 1] &&
      projection[i].to_double() < mean {
      valleys.push(i)
    }
  }
  ProjectionResult::{ projection, peaks, valleys, mean, stddev }
}

///|
/// 文本行结构体
pub(all) struct TextLineInfo {
  y_start : Int
  y_end : Int
  height : Int
  x_start : Int
  x_end : Int
  width : Int
  pixel_count : Int
  baseline : Int
}

///|
/// 检测文本行（基于水平投影）
pub fn detect_text_lines_projection(
  img : @types.Image,
  min_height? : Int = 5,
  max_gap? : Int = 3,
) -> Array[TextLineInfo] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_text_lines_projection: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "detect_text_lines_projection: 仅支持单通道二值图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "detect_text_lines_projection: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if min_height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_text_lines_projection: min_height必须大于0",
    )
  }
  if max_gap < 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_text_lines_projection: max_gap不能为负数",
    )
  }

  let w = img.width
  let h = img.height
  let data = img.data
  // 水平投影
  let projection : Array[Int] = Array::make(h, 0)
  for y in 0..<h {
    for x in 0..<w {
      if data[y * w + x].to_int() > 128 {
        projection[y] += 1
      }
    }
  }
  // 找文本行（连续的非零行）
  let lines : Array[TextLineInfo] = []
  let mut in_line = false
  let mut start_y = 0
  let mut gap_count = 0
  for y in 0..<h {
    if projection[y] > 0 {
      if !in_line {
        in_line = true
        start_y = y
      }
      gap_count = 0
    } else if in_line {
      gap_count += 1
      if gap_count > max_gap {
        // 结束当前行
        let end_y = y - gap_count
        let line_height = end_y - start_y + 1
        if line_height >= min_height {
          // 计算这一行的水平范围和像素数
          let mut min_x = w
          let mut max_x = 0
          let mut pixel_count = 0
          let mut baseline_y = start_y
          let mut max_proj = 0
          for yy in start_y..<(end_y + 1) {
            if projection[yy] > max_proj {
              max_proj = projection[yy]
              baseline_y = yy
            }
            for x in 0..<w {
              if data[yy * w + x].to_int() > 128 {
                pixel_count += 1
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
            lines.push(TextLineInfo::{
              y_start: start_y,
              y_end: end_y,
              height: line_height,
              x_start: min_x,
              x_end: max_x,
              width: max_x - min_x + 1,
              pixel_count,
              baseline: baseline_y,
            })
          }
        }
        in_line = false
        gap_count = 0
      }
    }
  }
  // 处理最后一行
  if in_line {
    let end_y = h - 1
    let line_height = end_y - start_y + 1
    if line_height >= min_height {
      let mut min_x = w
      let mut max_x = 0
      let mut pixel_count = 0
      for yy in start_y..<(end_y + 1) {
        for x in 0..<w {
          if data[yy * w + x].to_int() > 128 {
            pixel_count += 1
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
        lines.push(TextLineInfo::{
          y_start: start_y,
          y_end: end_y,
          height: line_height,
          x_start: min_x,
          x_end: max_x,
          width: max_x - min_x + 1,
          pixel_count,
          baseline: start_y + line_height / 2,
        })
      }
    }
  }
  lines
}

///|
/// 字符分割结构体
pub(all) struct CharSegment {
  x_start : Int
  x_end : Int
  width : Int
  y_start : Int
  y_end : Int
  height : Int
  pixel_count : Int
}

///|
/// 文本行字符分割（基于垂直投影）
pub fn segment_chars_projection(
  img : @types.Image,
  line : TextLineInfo,
  min_width? : Int = 2,
  max_gap? : Int = 2,
) -> Array[CharSegment] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "segment_chars_projection: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "segment_chars_projection: 仅支持单通道二值图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "segment_chars_projection: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if line.width <= 0 || line.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "segment_chars_projection: 文本行尺寸必须大于0",
    )
  }
  if min_width <= 0 {
    raise @types.LoadError::DecodeFailed(
      "segment_chars_projection: min_width必须大于0",
    )
  }
  if max_gap < 0 {
    raise @types.LoadError::DecodeFailed(
      "segment_chars_projection: max_gap不能为负数",
    )
  }

  let w = img.width
  let data = img.data
  let y_start = line.y_start
  let y_end = line.y_end
  let x_start = line.x_start
  let x_end = line.x_end
  // 垂直投影（只在文本行范围内）
  let projection : Array[Int] = Array::make(w, 0)
  for x in x_start..<(x_end + 1) {
    for y in y_start..<(y_end + 1) {
      if data[y * w + x].to_int() > 128 {
        projection[x] += 1
      }
    }
  }
  // 找字符（连续的非零列）
  let chars : Array[CharSegment] = []
  let mut in_char = false
  let mut start_x = 0
  let mut gap_count = 0
  for x in x_start..<(x_end + 1) {
    if projection[x] > 0 {
      if !in_char {
        in_char = true
        start_x = x
      }
      gap_count = 0
    } else if in_char {
      gap_count += 1
      if gap_count > max_gap {
        let end_x = x - gap_count
        let char_width = end_x - start_x + 1
        if char_width >= min_width {
          // 计算字符的垂直范围和像素数
          let mut min_y = y_end
          let mut max_y = y_start
          let mut pixel_count = 0
          for xx in start_x..<(end_x + 1) {
            for yy in y_start..<(y_end + 1) {
              if data[yy * w + xx].to_int() > 128 {
                pixel_count += 1
                if yy < min_y {
                  min_y = yy
                }
                if yy > max_y {
                  max_y = yy
                }
              }
            }
          }
          chars.push(CharSegment::{
            x_start: start_x,
            x_end: end_x,
            width: char_width,
            y_start: min_y,
            y_end: max_y,
            height: max_y - min_y + 1,
            pixel_count,
          })
        }
        in_char = false
        gap_count = 0
      }
    }
  }
  // 处理最后一个字符
  if in_char {
    let end_x = x_end
    let char_width = end_x - start_x + 1
    if char_width >= min_width {
      let mut min_y = y_end
      let mut max_y = y_start
      let mut pixel_count = 0
      for xx in start_x..<(end_x + 1) {
        for yy in y_start..<(y_end + 1) {
          if data[yy * w + xx].to_int() > 128 {
            pixel_count += 1
            if yy < min_y {
              min_y = yy
            }
            if yy > max_y {
              max_y = yy
            }
          }
        }
      }
      chars.push(CharSegment::{
        x_start: start_x,
        x_end: end_x,
        width: char_width,
        y_start: min_y,
        y_end: max_y,
        height: max_y - min_y + 1,
        pixel_count,
      })
    }
  }
  chars
}

///|
/// 提取文本行图像
pub fn extract_text_line_image(
  img : @types.Image,
  line : TextLineInfo,
  padding? : Int = 2,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "extract_text_line_image: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "extract_text_line_image: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "extract_text_line_image: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if line.width <= 0 || line.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "extract_text_line_image: 文本行尺寸必须大于0",
    )
  }
  if padding < 0 {
    raise @types.LoadError::DecodeFailed(
      "extract_text_line_image: padding不能为负数",
    )
  }

  let w = img.width
  let h = img.height
  let ch = img.channels
  let x_start = max(0, line.x_start - padding)
  let x_end = min(w - 1, line.x_end + padding)
  let y_start = max(0, line.y_start - padding)
  let y_end = min(h - 1, line.y_end + padding)
  let new_w = x_end - x_start + 1
  let new_h = y_end - y_start + 1
  let out : Array[Byte] = Array::make(new_w * new_h * ch, b'\x00')
  let data = img.data
  for y in 0..<new_h {
    for x in 0..<new_w {
      for c in 0..<ch {
        out[(y * new_w + x) * ch + c] = data[((y_start + y) * w + (x_start + x)) *
          ch +
          c]
      }
    }
  }
  @types.Image::{
    width: new_w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 提取字符图像
pub fn extract_char_image(
  img : @types.Image,
  char : CharSegment,
  target_size? : Int = 32,
  padding? : Int = 2,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "extract_char_image: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "extract_char_image: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "extract_char_image: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if char.width <= 0 || char.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "extract_char_image: 字符尺寸必须大于0",
    )
  }
  if target_size <= 0 {
    raise @types.LoadError::DecodeFailed(
      "extract_char_image: target_size必须大于0",
    )
  }
  if padding < 0 {
    raise @types.LoadError::DecodeFailed(
      "extract_char_image: padding不能为负数",
    )
  }

  let w = img.width
  let h = img.height
  let ch = img.channels
  let x_start = max(0, char.x_start - padding)
  let x_end = min(w - 1, char.x_end + padding)
  let y_start = max(0, char.y_start - padding)
  let y_end = min(h - 1, char.y_end + padding)
  let src_w = x_end - x_start + 1
  let src_h = y_end - y_start + 1
  // 缩放到目标尺寸（保持宽高比，居中）
  let scale_w = target_size.to_double() / src_w.to_double()
  let scale_h = target_size.to_double() / src_h.to_double()
  let scale = if scale_w < scale_h { scale_w } else { scale_h }
  let new_w = max(1, (src_w.to_double() * scale).to_int())
  let new_h = max(1, (src_h.to_double() * scale).to_int())
  let offset_x = (target_size - new_w) / 2
  let offset_y = (target_size - new_h) / 2
  let out : Array[Byte] = Array::make(target_size * target_size * ch, b'\x00')
  let data = img.data
  // 最近邻缩放
  for y in 0..<new_h {
    for x in 0..<new_w {
      let src_x = x_start + x * src_w / new_w
      let src_y = y_start + y * src_h / new_h
      for c in 0..<ch {
        out[((offset_y + y) * target_size + (offset_x + x)) * ch + c] = data[(
            src_y * w + src_x
          ) *
          ch +
          c]
      }
    }
  }
  @types.Image::{
    width: target_size,
    height: target_size,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 辅助函数：最小值
fn _min_proj(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// 辅助函数：最大值
fn _max_proj(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

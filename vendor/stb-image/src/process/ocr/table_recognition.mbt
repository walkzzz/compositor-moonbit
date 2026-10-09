// 表格识别
// 表格线检测、单元格分割、表格结构分析

///|
/// 表格线结构体
pub(all) struct TableLine {
  x1 : Int
  y1 : Int
  x2 : Int
  y2 : Int
  line_type : TableLineType
  thickness : Int
}

///|
/// 表格线类型
pub(all) enum TableLineType {
  Horizontal
  Vertical
} derive(Eq)

///|
/// 单元格结构体
pub(all) struct TableCell {
  x : Int
  y : Int
  width : Int
  height : Int
  row : Int
  col : Int
  row_span : Int
  col_span : Int
}

///|
/// 表格结构结构体
pub(all) struct TableStructure {
  rows : Int
  cols : Int
  cells : Array[TableCell]
  horizontal_lines : Array[TableLine]
  vertical_lines : Array[TableLine]
  bounding_box : (Int, Int, Int, Int)
}

///|
/// 检测水平表格线
pub fn detect_horizontal_lines(
  img : @types.Image,
  min_length? : Int = 20,
  max_gap? : Int = 2,
) -> Array[TableLine] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_horizontal_lines: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "detect_horizontal_lines: 仅支持单通道二值图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "detect_horizontal_lines: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if min_length <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_horizontal_lines: min_length必须大于0",
    )
  }
  if max_gap < 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_horizontal_lines: max_gap不能为负数",
    )
  }
  let w = img.width
  let h = img.height
  let data = img.data
  let lines : Array[TableLine] = []
  // 逐行检测水平线
  for y in 0..<h {
    let mut x = 0
    while x < w {
      // 找连续的黑色像素
      if data[y * w + x].to_int() < 128 {
        let start_x = x
        let mut end_x = x
        let mut gap = 0
        while x < w && gap <= max_gap {
          if data[y * w + x].to_int() < 128 {
            end_x = x
            gap = 0
          } else {
            gap += 1
          }
          x += 1
        }
        let length = end_x - start_x + 1
        if length >= min_length {
          lines.push(TableLine::{
            x1: start_x,
            y1: y,
            x2: end_x,
            y2: y,
            line_type: TableLineType::Horizontal,
            thickness: 1,
          })
        }
      } else {
        x += 1
      }
    }
  }
  // 合并相邻的水平线（同一表格线可能有多行像素）
  merge_horizontal_lines(lines, 3)
}

///|
/// 检测垂直表格线
pub fn detect_vertical_lines(
  img : @types.Image,
  min_length? : Int = 20,
  max_gap? : Int = 2,
) -> Array[TableLine] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_vertical_lines: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "detect_vertical_lines: 仅支持单通道二值图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "detect_vertical_lines: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if min_length <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_vertical_lines: min_length必须大于0",
    )
  }
  if max_gap < 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_vertical_lines: max_gap不能为负数",
    )
  }
  let w = img.width
  let h = img.height
  let data = img.data
  let lines : Array[TableLine] = []
  // 逐列检测垂直线
  for x in 0..<w {
    let mut y = 0
    while y < h {
      if data[y * w + x].to_int() < 128 {
        let start_y = y
        let mut end_y = y
        let mut gap = 0
        while y < h && gap <= max_gap {
          if data[y * w + x].to_int() < 128 {
            end_y = y
            gap = 0
          } else {
            gap += 1
          }
          y += 1
        }
        let length = end_y - start_y + 1
        if length >= min_length {
          lines.push(TableLine::{
            x1: x,
            y1: start_y,
            x2: x,
            y2: end_y,
            line_type: TableLineType::Vertical,
            thickness: 1,
          })
        }
      } else {
        y += 1
      }
    }
  }
  // 合并相邻的垂直线
  merge_vertical_lines(lines, 3)
}

///|
/// 合并相邻的水平线
fn merge_horizontal_lines(
  lines : Array[TableLine],
  max_y_diff : Int,
) -> Array[TableLine] {
  if lines.length() == 0 {
    return lines
  }
  let merged : Array[TableLine] = []
  let mut current = lines[0]
  for i in 1..<lines.length() {
    let next = lines[i]
    // 检查是否是同一条线（y坐标接近，x范围重叠）
    let y_diff = (next.y1 - current.y1).abs()
    let x_overlap = min_table(current.x2, next.x2) -
      max_table(current.x1, next.x1)
    if y_diff <= max_y_diff && x_overlap > 0 {
      // 合并
      current = TableLine::{
        x1: min_table(current.x1, next.x1),
        y1: (current.y1 + next.y1) / 2,
        x2: max_table(current.x2, next.x2),
        y2: (current.y2 + next.y2) / 2,
        line_type: TableLineType::Horizontal,
        thickness: current.thickness + 1,
      }
    } else {
      merged.push(current)
      current = next
    }
  }
  merged.push(current)
  merged
}

///|
/// 合并相邻的垂直线
fn merge_vertical_lines(
  lines : Array[TableLine],
  max_x_diff : Int,
) -> Array[TableLine] {
  if lines.length() == 0 {
    return lines
  }
  let merged : Array[TableLine] = []
  let mut current = lines[0]
  for i in 1..<lines.length() {
    let next = lines[i]
    let x_diff = (next.x1 - current.x1).abs()
    let y_overlap = min_table(current.y2, next.y2) -
      max_table(current.y1, next.y1)
    if x_diff <= max_x_diff && y_overlap > 0 {
      current = TableLine::{
        x1: (current.x1 + next.x1) / 2,
        y1: min_table(current.y1, next.y1),
        x2: (current.x2 + next.x2) / 2,
        y2: max_table(current.y2, next.y2),
        line_type: TableLineType::Vertical,
        thickness: current.thickness + 1,
      }
    } else {
      merged.push(current)
      current = next
    }
  }
  merged.push(current)
  merged
}

///|
/// 分析表格结构（基于水平线和垂直线）
pub fn analyze_table_structure(
  horizontal_lines : Array[TableLine],
  vertical_lines : Array[TableLine],
) -> TableStructure raise @types.LoadError {
  // 输入验证
  if horizontal_lines.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "analyze_table_structure: 水平线列表不能为空",
    )
  }
  if vertical_lines.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "analyze_table_structure: 垂直线列表不能为空",
    )
  }
  if horizontal_lines.length() < 2 || vertical_lines.length() < 2 {
    return TableStructure::{
      rows: 0,
      cols: 0,
      cells: [],
      horizontal_lines,
      vertical_lines,
      bounding_box: (0, 0, 0, 0),
    }
  }
  // 提取水平线的y坐标（按y排序）
  let h_ys : Array[Int] = []
  for line in horizontal_lines {
    h_ys.push(line.y1)
  }
  // 排序
  for _ in 0..<h_ys.length() {
    for j in 0..<(h_ys.length() - 1) {
      if h_ys[j] > h_ys[j + 1] {
        let temp = h_ys[j]
        h_ys[j] = h_ys[j + 1]
        h_ys[j + 1] = temp
      }
    }
  }
  // 提取垂直线的x坐标（按x排序）
  let v_xs : Array[Int] = []
  for line in vertical_lines {
    v_xs.push(line.x1)
  }
  for _ in 0..<v_xs.length() {
    for j in 0..<(v_xs.length() - 1) {
      if v_xs[j] > v_xs[j + 1] {
        let temp = v_xs[j]
        v_xs[j] = v_xs[j + 1]
        v_xs[j + 1] = temp
      }
    }
  }
  // 计算边界框
  let min_x = v_xs[0]
  let max_x = v_xs[v_xs.length() - 1]
  let min_y = h_ys[0]
  let max_y = h_ys[h_ys.length() - 1]
  // 生成单元格
  let cells : Array[TableCell] = []
  let rows = h_ys.length() - 1
  let cols = v_xs.length() - 1
  for row in 0..<rows {
    for col in 0..<cols {
      let cell_x = v_xs[col]
      let cell_y = h_ys[row]
      let cell_w = v_xs[col + 1] - v_xs[col]
      let cell_h = h_ys[row + 1] - h_ys[row]
      if cell_w > 0 && cell_h > 0 {
        cells.push(TableCell::{
          x: cell_x,
          y: cell_y,
          width: cell_w,
          height: cell_h,
          row,
          col,
          row_span: 1,
          col_span: 1,
        })
      }
    }
  }
  TableStructure::{
    rows,
    cols,
    cells,
    horizontal_lines,
    vertical_lines,
    bounding_box: (min_x, min_y, max_x - min_x, max_y - min_y),
  }
}

///|
/// 完整表格识别流水线
pub fn recognize_table(
  img : @types.Image,
  min_line_length? : Int = 20,
) -> TableStructure raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_table: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "recognize_table: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "recognize_table: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if min_line_length <= 0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_table: min_line_length必须大于0",
    )
  }
  // 1. 预处理（二值化）
  let binary = if img.channels == 1 { img } else { to_grayscale_table(img) }
  // 2. 检测水平线
  let h_lines = detect_horizontal_lines(binary, min_length=min_line_length)
  // 3. 检测垂直线
  let v_lines = detect_vertical_lines(binary, min_length=min_line_length)
  // 4. 分析表格结构
  analyze_table_structure(h_lines, v_lines)
}

///|
/// 提取单元格图像
pub fn extract_cell_image(
  img : @types.Image,
  cell : TableCell,
  padding? : Int = 1,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "extract_cell_image: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "extract_cell_image: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "extract_cell_image: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if cell.width <= 0 || cell.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "extract_cell_image: 单元格尺寸必须大于0",
    )
  }
  if padding < 0 {
    raise @types.LoadError::DecodeFailed(
      "extract_cell_image: padding不能为负数",
    )
  }
  let w = img.width
  let h = img.height
  let ch = img.channels
  let x = max_table(0, cell.x - padding)
  let y = max_table(0, cell.y - padding)
  let width = min_table(w - x, cell.width + padding * 2)
  let height = min_table(h - y, cell.height + padding * 2)
  if width <= 0 || height <= 0 {
    let empty : Array[Byte] = Array::make(1 * 1 * ch, b'\x00')
    return @types.Image::{
      width: 1,
      height: 1,
      channels: ch,
      data: Bytes::from_array(empty),
    }
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
  @types.Image::{ width, height, channels: ch, data: Bytes::from_array(out) }
}

///|
/// 提取所有单元格图像
pub fn extract_all_cells(
  img : @types.Image,
  structure : TableStructure,
  padding? : Int = 1,
) -> Array[@types.Image] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "extract_all_cells: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "extract_all_cells: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "extract_all_cells: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if padding < 0 {
    raise @types.LoadError::DecodeFailed(
      "extract_all_cells: padding不能为负数",
    )
  }
  let images : Array[@types.Image] = []
  for cell in structure.cells {
    let cell_img = extract_cell_image(img, cell, padding~)
    images.push(cell_img)
  }
  images
}

///|
/// 转灰度（表格识别专用）
fn to_grayscale_table(img : @types.Image) -> @types.Image {
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

///|
/// 辅助函数：最小值
fn min_table(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// 辅助函数：最大值
fn max_table(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

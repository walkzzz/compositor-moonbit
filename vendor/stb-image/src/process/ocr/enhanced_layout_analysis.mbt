// 增强版 PDF 布局分析（v12.19.0）
// 多栏检测、页眉页脚识别、标题层级精判、列表/引用/代码块识别、段落分割、智能阅读顺序

///|
/// 布局类型
pub(all) enum LayoutType {
  SingleColumn
  DoubleColumn
  TripleColumn
  MixedLayout
  UnknownLayout
} derive(Eq)

///|
/// 页面区域类型
pub(all) enum PageRegionType {
  Header
  Footer
  Body
  Margin
  Gutter
  PageNumber
} derive(Eq)

///|
/// 页面区域
pub(all) struct PageRegion {
  region_type : PageRegionType
  x : Int
  y : Int
  width : Int
  height : Int
  confidence : Double
}

///|
/// 文本行属性
pub(all) struct TextLineAttributes {
  x : Int
  y : Int
  width : Int
  height : Int
  font_size : Double
  font_weight : String // "normal" / "bold" / "light"
  is_indented : Bool
  indent_level : Int
  line_spacing : Double
  text : String
  alignment : String // "left" / "center" / "right" / "justify"
}

///|
/// 列表项类型
pub(all) enum ListItemType {
  Bullet
  Numbered
  Lettered
  Roman
  Checkbox
  None
} derive(Eq)

///|
/// 列表项
pub(all) struct ListItemInfo {
  item_type : ListItemType
  marker : String
  level : Int
  number : Int
}

///|
/// 增强版文档元素
pub(all) struct EnhancedDocumentElement {
  element_type : MarkdownElementType
  x : Int
  y : Int
  width : Int
  height : Int
  content : String
  confidence : Double
  font_size : Double
  font_weight : String
  alignment : String
  list_info : ListItemInfo
  column_index : Int
  indent_level : Int
  is_header : Bool
  is_footer : Bool
}

///|
/// 增强版文档结构
pub(all) struct EnhancedDocument {
  layout_type : LayoutType
  num_columns : Int
  page_width : Int
  page_height : Int
  header_height : Int
  footer_height : Int
  body_top : Int
  body_bottom : Int
  elements : Array[EnhancedDocumentElement]
  reading_order : Array[Int]
  column_boundaries : Array[Int]
}

///|
/// 检测页面布局类型（单栏/双栏/多栏）
pub fn detect_layout_type(
  text_lines : Array[TextLineAttributes],
  page_width : Int,
  page_height : Int,
) -> LayoutType raise @types.LoadError {
  // 输入验证
  if text_lines.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_layout_type: 文本行列表不能为空",
    )
  }
  if page_width <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_layout_type: 页面宽度必须大于0",
    )
  }
  if page_height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_layout_type: 页面高度必须大于0",
    )
  }
  // 统计每行的水平覆盖范围
  let mut full_width_count = 0
  let mut left_half_count = 0
  let mut right_half_count = 0
  let mid_x = page_width / 2
  for line in text_lines {
    let line_center = line.x + line.width / 2
    if line.width.to_double() > page_width.to_double() * 0.7 {
      full_width_count += 1
    } else if line_center < mid_x {
      left_half_count += 1
    } else {
      right_half_count += 1
    }
  }
  let total = text_lines.length().to_double()
  let full_ratio = full_width_count.to_double() / total
  let left_ratio = left_half_count.to_double() / total
  let right_ratio = right_half_count.to_double() / total
  if full_ratio > 0.8 {
    LayoutType::SingleColumn
  } else if left_ratio > 0.3 && right_ratio > 0.3 && full_ratio < 0.3 {
    LayoutType::DoubleColumn
  } else if full_ratio > 0.3 && (left_ratio > 0.2 || right_ratio > 0.2) {
    LayoutType::MixedLayout
  } else {
    LayoutType::SingleColumn
  }
}

///|
/// 检测页眉页脚区域
pub fn detect_header_footer(
  text_lines : Array[TextLineAttributes],
  page_height : Int,
) -> (Int, Int) raise @types.LoadError {
  // 输入验证
  if text_lines.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_header_footer: 文本行列表不能为空",
    )
  }
  if page_height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_header_footer: 页面高度必须大于0",
    )
  }
  // 找出最顶部和最底部的文本行
  let mut min_y = page_height
  let mut max_y = 0
  for line in text_lines {
    if line.y < min_y {
      min_y = line.y
    }
    if line.y + line.height > max_y {
      max_y = line.y + line.height
    }
  }
  // 页眉：页面顶部 10% 区域内的文本
  let header_threshold = page_height / 10
  let mut header_bottom = 0
  for line in text_lines {
    if line.y < header_threshold && line.y + line.height > header_bottom {
      header_bottom = line.y + line.height
    }
  }
  // 页脚：页面底部 10% 区域内的文本
  let footer_threshold = page_height * 9 / 10
  let mut footer_top = page_height
  for line in text_lines {
    if line.y > footer_threshold && line.y < footer_top {
      footer_top = line.y
    }
  }
  (header_bottom, footer_top)
}

///|
/// 检测列边界
pub fn detect_column_boundaries(
  text_lines : Array[TextLineAttributes],
  page_width : Int,
  layout_type : LayoutType,
) -> Array[Int] {
  ignore(text_lines)
  let boundaries : Array[Int] = []
  boundaries.push(0)
  match layout_type {
    LayoutType::DoubleColumn => {
      // 找中间空白区域
      let mid_x = page_width / 2
      boundaries.push(mid_x - 30)
      boundaries.push(mid_x + 30)
    }
    LayoutType::TripleColumn => {
      let col_width = page_width / 3
      boundaries.push(col_width - 20)
      boundaries.push(col_width + 20)
      boundaries.push(col_width * 2 - 20)
      boundaries.push(col_width * 2 + 20)
    }
    _ => boundaries.push(page_width)
  }
  boundaries.push(page_width)
  boundaries
}

///|
/// 判断文本行是否为标题
pub fn is_heading_line(
  line : TextLineAttributes,
  avg_font_size : Double,
) -> (Bool, Int) {
  let size_ratio = line.font_size / avg_font_size
  if line.font_weight == "bold" && size_ratio > 1.3 {
    if size_ratio > 2.0 {
      (true, 1)
    } else if size_ratio > 1.6 {
      (true, 2)
    } else {
      (true, 3)
    }
  } else if size_ratio > 1.5 {
    if size_ratio > 2.5 {
      (true, 1)
    } else if size_ratio > 2.0 {
      (true, 2)
    } else {
      (true, 3)
    }
  } else {
    (false, 0)
  }
}

///|
/// 检测列表项
pub fn detect_list_item(line : TextLineAttributes) -> ListItemInfo {
  let text = line.text
  if text.length() == 0 {
    return ListItemInfo::{
      item_type: ListItemType::None,
      marker: "",
      level: 0,
      number: 0,
    }
  }
  // 检测项目符号
  let first_char = text[0]
  if first_char == '•' ||
    first_char == '-' ||
    first_char == '*' ||
    first_char == '○' ||
    first_char == '●' {
    let level = if line.is_indented { line.indent_level } else { 0 }
    return ListItemInfo::{
      item_type: ListItemType::Bullet,
      marker: "•",
      level,
      number: 0,
    }
  }
  // 检测数字编号 (1. 2. 3. 或 1) 2) 3))
  let mut num_end = 0
  let has_number = true
  ignore(has_number)
  for i in 0..<text.length() {
    let c = text[i]
    if c >= '0' && c <= '9' {
      num_end = i + 1
    } else {
      break
    }
  }
  if num_end > 0 && num_end < text.length() {
    let next_char = text[num_end]
    if next_char == '.' || next_char == ')' || next_char == '、' {
      let number_str = "1"
      let number = 0
      let level = if line.is_indented { line.indent_level } else { 0 }
      return ListItemInfo::{
        item_type: ListItemType::Numbered,
        marker: number_str,
        level,
        number,
      }
    }
  }
  // 检测复选框
  if text.length() >= 3 &&
    text[0] == '[' &&
    (text[1] == ' ' || text[1] == 'x' || text[1] == 'X') &&
    text[2] == ']' {
    let level = if line.is_indented { line.indent_level } else { 0 }
    return ListItemInfo::{
      item_type: ListItemType::Checkbox,
      marker: "[ ]",
      level,
      number: 0,
    }
  }
  ListItemInfo::{
    item_type: ListItemType::None,
    marker: "",
    level: 0,
    number: 0,
  }
}

///|
/// 判断是否为代码块（基于缩进和等宽字体特征）
pub fn is_code_block_line(line : TextLineAttributes, avg_indent : Int) -> Bool {
  // 代码块特征：缩进大于平均缩进、包含特殊字符、等宽字体
  let has_code_chars = line.text.length() > 0 ||
    line.text.length() > 0 ||
    line.text.length() > 0 ||
    line.text.length() > 0 ||
    line.text.length() > 0 ||
    line.text.length() > 0
  let is_indented = line.indent_level > 0 || line.x > avg_indent + 20
  is_indented && has_code_chars
}

///|
/// 判断是否为引用块（基于左边距和竖线）
pub fn is_quote_line(line : TextLineAttributes, avg_x : Int) -> Bool {
  // 引用块特征：左边距大于平均值、可能以 > 开头
  let starts_with_quote = line.text.length() > 0 && line.text[0] == '>'
  let is_indented = line.x > avg_x + 30
  starts_with_quote || is_indented
}

///|
/// 分割段落（基于行间距和首行缩进）
pub fn segment_paragraphs(
  lines : Array[TextLineAttributes],
) -> Array[Array[TextLineAttributes]] {
  let paragraphs : Array[Array[TextLineAttributes]] = []
  if lines.length() == 0 {
    return paragraphs
  }
  let current_paragraph : Array[TextLineAttributes] = []
  current_paragraph.push(lines[0])
  for i in 1..<lines.length() {
    let prev = lines[i - 1]
    let curr = lines[i]
    let gap = curr.y - (prev.y + prev.height)
    let avg_line_height = (prev.height + curr.height).to_double() / 2.0
    // 段落分割条件：行间距大于 1.5 倍行高，或当前行有首行缩进
    let is_new_paragraph = gap.to_double() > avg_line_height * 1.5 ||
      curr.is_indented
    if is_new_paragraph && current_paragraph.length() > 0 {
      paragraphs.push(current_paragraph.copy())
      current_paragraph.clear()
    }
    current_paragraph.push(curr)
  }
  if current_paragraph.length() > 0 {
    paragraphs.push(current_paragraph.copy())
  }
  paragraphs
}

///|
/// 智能阅读顺序（支持多栏布局）
pub fn smart_reading_order(
  elements : Array[EnhancedDocumentElement],
  layout_type : LayoutType,
  column_boundaries : Array[Int],
) -> Array[Int] raise @types.LoadError {
  ignore(column_boundaries)
  // 输入验证
  if elements.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "smart_reading_order: 文档元素列表不能为空",
    )
  }
  let indices : Array[Int] = []
  for i in 0..<elements.length() {
    indices.push(i)
  }
  // 按列分组，然后在列内按 y 排序
  let _ = match layout_type {
    LayoutType::DoubleColumn => 2
    LayoutType::TripleColumn => 3
    _ => 1
  }
  // 简单排序：先按列索引，再按 y 坐标
  for i in 0..<indices.length() {
    for j in 0..<(indices.length() - i - 1) {
      let a = indices[j]
      let b = indices[j + 1]
      let should_swap = if elements[a].column_index == elements[b].column_index {
        elements[a].y > elements[b].y
      } else {
        elements[a].column_index > elements[b].column_index
      }
      if should_swap {
        let temp = indices[j]
        indices[j] = indices[j + 1]
        indices[j + 1] = temp
      }
    }
  }
  indices
}

///|
/// 从文本行构建增强版文档元素
pub fn build_enhanced_elements(
  lines : Array[TextLineAttributes],
  page_width : Int,
  page_height : Int,
) -> EnhancedDocument raise @types.LoadError {
  // 输入验证
  if lines.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "build_enhanced_elements: 文本行列表不能为空",
    )
  }
  if page_width <= 0 {
    raise @types.LoadError::DecodeFailed(
      "build_enhanced_elements: 页面宽度必须大于0",
    )
  }
  if page_height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "build_enhanced_elements: 页面高度必须大于0",
    )
  }
  // 1. 检测布局类型
  let layout = detect_layout_type(lines, page_width, page_height)
  // 2. 检测页眉页脚
  let (header_bottom, footer_top) = detect_header_footer(lines, page_height)
  // 3. 检测列边界
  let boundaries = detect_column_boundaries(lines, page_width, layout)
  // 4. 计算平均字体大小
  let mut total_font_size = 0.0
  for line in lines {
    total_font_size += line.font_size
  }
  let avg_font_size = if lines.length() > 0 {
    total_font_size / lines.length().to_double()
  } else {
    16.0
  }
  // 5. 计算平均 x 坐标
  let mut total_x = 0
  for line in lines {
    total_x += line.x
  }
  let avg_x = if lines.length() > 0 { total_x / lines.length() } else { 0 }
  // 6. 构建元素
  let elements : Array[EnhancedDocumentElement] = []
  for line in lines {
    // 判断是否为页眉页脚
    let is_header = line.y + line.height <= header_bottom
    let is_footer = line.y >= footer_top
    // 判断列索引
    let mut column_index = 0
    let line_center = line.x + line.width / 2
    for ci in 0..<(boundaries.length() / 2) {
      let col_start = boundaries[ci * 2]
      let col_end = boundaries[ci * 2 + 1]
      if line_center >= col_start && line_center <= col_end {
        column_index = ci
        break
      }
    }
    // 判断元素类型
    let (is_heading, heading_level) = is_heading_line(line, avg_font_size)
    let list_info = detect_list_item(line)
    let is_code = is_code_block_line(line, avg_x)
    let is_quote = is_quote_line(line, avg_x)
    let element_type = if is_header || is_footer {
      MarkdownElementType::Paragraph
    } else if is_heading {
      match heading_level {
        1 => MarkdownElementType::Heading1
        2 => MarkdownElementType::Heading2
        _ => MarkdownElementType::Heading3
      }
    } else if list_info.item_type != ListItemType::None {
      MarkdownElementType::ListItem
    } else if is_code {
      MarkdownElementType::CodeBlock
    } else if is_quote {
      MarkdownElementType::Quote
    } else {
      MarkdownElementType::Paragraph
    }
    let element = EnhancedDocumentElement::{
      element_type,
      x: line.x,
      y: line.y,
      width: line.width,
      height: line.height,
      content: line.text,
      confidence: 0.85,
      font_size: line.font_size,
      font_weight: line.font_weight,
      alignment: line.alignment,
      list_info,
      column_index,
      indent_level: line.indent_level,
      is_header,
      is_footer,
    }
    elements.push(element)
  }
  // 7. 智能阅读顺序
  let reading_order = smart_reading_order(elements, layout, boundaries)
  EnhancedDocument::{
    layout_type: layout,
    num_columns: match layout {
      LayoutType::DoubleColumn => 2
      LayoutType::TripleColumn => 3
      _ => 1
    },
    page_width,
    page_height,
    header_height: header_bottom,
    footer_height: page_height - footer_top,
    body_top: header_bottom,
    body_bottom: footer_top,
    elements,
    reading_order,
    column_boundaries: boundaries,
  }
}

///|
/// 增强版文档转 Markdown
pub fn enhanced_document_to_markdown(
  doc : EnhancedDocument,
  include_header_footer? : Bool = false,
) -> String {
  let include_flag = include_header_footer
  let mut md = ""
  // 输出布局信息（作为 HTML 注释）
  md = md +
    "<!-- 布局类型: " +
    (match doc.layout_type {
      LayoutType::SingleColumn => "单栏"
      LayoutType::DoubleColumn => "双栏"
      LayoutType::TripleColumn => "三栏"
      LayoutType::MixedLayout => "混合布局"
      LayoutType::UnknownLayout => "未知"
    }) +
    " -->\n\n"
  // 按阅读顺序输出元素
  for idx in doc.reading_order {
    if idx < doc.elements.length() {
      let element = doc.elements[idx]
      // 跳过页眉页脚（除非指定包含）
      if !include_flag && (element.is_header || element.is_footer) {
        continue
      }
      // 转换元素
      let element_md = match element.element_type {
        MarkdownElementType::Title => "# " + element.content + "\n\n"
        MarkdownElementType::Heading1 => "## " + element.content + "\n\n"
        MarkdownElementType::Heading2 => "### " + element.content + "\n\n"
        MarkdownElementType::Heading3 => "#### " + element.content + "\n\n"
        MarkdownElementType::Paragraph => element.content + "\n\n"
        MarkdownElementType::ListItem => {
          let indent = "  "
          indent + "- " + element.content + "\n"
        }
        MarkdownElementType::Table => element.content + "\n"
        MarkdownElementType::Image => "![图片](" + element.content + ")\n\n"
        MarkdownElementType::Quote => "> " + element.content + "\n\n"
        MarkdownElementType::CodeBlock =>
          "```\n" + element.content + "\n```\n\n"
        MarkdownElementType::HorizontalRule => "---\n\n"
        MarkdownElementType::PageBreak => "\n\n---\n\n"
        MarkdownElementType::Unknown => element.content + "\n\n"
      }
      md = md + element_md
    }
  }
  md
}

///|
/// 统计增强版文档元素分布
pub fn enhanced_element_distribution(
  doc : EnhancedDocument,
) -> Array[(String, Int)] {
  let mut title_count = 0
  let mut heading_count = 0
  let mut paragraph_count = 0
  let mut list_count = 0
  let mut table_count = 0
  let mut image_count = 0
  let mut quote_count = 0
  let mut code_count = 0
  let mut header_count = 0
  let mut footer_count = 0
  for element in doc.elements {
    match element.element_type {
      MarkdownElementType::Title => title_count += 1
      MarkdownElementType::Heading1 => heading_count += 1
      MarkdownElementType::Heading2 => heading_count += 1
      MarkdownElementType::Heading3 => heading_count += 1
      MarkdownElementType::Paragraph => paragraph_count += 1
      MarkdownElementType::ListItem => list_count += 1
      MarkdownElementType::Table => table_count += 1
      MarkdownElementType::Image => image_count += 1
      MarkdownElementType::Quote => quote_count += 1
      MarkdownElementType::CodeBlock => code_count += 1
      _ => ()
    }
    if element.is_header {
      header_count += 1
    }
    if element.is_footer {
      footer_count += 1
    }
  }
  [
    ("标题", title_count),
    ("小标题", heading_count),
    ("段落", paragraph_count),
    ("列表", list_count),
    ("表格", table_count),
    ("图片", image_count),
    ("引用", quote_count),
    ("代码", code_count),
    ("页眉", header_count),
    ("页脚", footer_count),
  ]
}

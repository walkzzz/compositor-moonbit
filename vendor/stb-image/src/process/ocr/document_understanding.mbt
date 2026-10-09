// 文档理解
// 版面分析、阅读顺序、标题/正文分类、文档结构提取

///|
/// 文档元素类型
pub(all) enum DocumentElementType {
  Title
  Subtitle
  Heading1
  Heading2
  Heading3
  Body
  Caption
  Footer
  Header
  List
  Table
  Image
  Unknown
} derive(Eq)

///|
/// 文档元素结构体
pub(all) struct DocumentElement {
  element_type : DocumentElementType
  x : Int
  y : Int
  width : Int
  height : Int
  text : String
  confidence : Double
  font_size : Int
  font_weight : String // "normal" / "bold"
  reading_order : Int
}

///|
/// 文档结构结构体
pub(all) struct DocumentStructure {
  elements : Array[DocumentElement]
  num_elements : Int
  title : String
  num_headings : Int
  num_paragraphs : Int
  reading_order : Array[Int]
  bounding_box : (Int, Int, Int, Int)
}

///|
/// 分析文档版面（检测文本块、分类元素类型）
pub fn analyze_document_layout(
  img : @types.Image,
) -> DocumentStructure raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "analyze_document_layout: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "analyze_document_layout: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "analyze_document_layout: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  // 1. 预处理
  let preprocessed = ocr_preprocess(img)
  // 2. 文本行检测
  let lines = detect_text_lines_projection(preprocessed)
  // 3. 文本区域检测
  let _ = detect_text_regions(preprocessed)
  // 4. 分类元素类型
  let elements : Array[DocumentElement] = []
  let mut order = 0
  for line in lines {
    // 根据行高和位置判断元素类型
    let element_type = classify_element_type(line, lines)
    let font_size = line.height
    let font_weight = if line.height > 20 { "bold" } else { "normal" }
    elements.push(DocumentElement::{
      element_type,
      x: line.x_start,
      y: line.y_start,
      width: line.width,
      height: line.height,
      text: "",
      confidence: 0.8,
      font_size,
      font_weight,
      reading_order: order,
    })
    order += 1
  }
  // 5. 计算阅读顺序（从上到下，从左到右）
  let reading_order : Array[Int] = []
  for i in 0..<elements.length() {
    reading_order.push(i)
  }
  // 6. 提取标题
  let mut title = ""
  for elem in elements {
    if elem.element_type == DocumentElementType::Title ||
      elem.element_type == DocumentElementType::Heading1 {
      title = elem.text
      break
    }
  }
  // 7. 统计
  let mut num_headings = 0
  let mut num_paragraphs = 0
  for elem in elements {
    match elem.element_type {
      DocumentElementType::Heading1 => num_headings += 1
      DocumentElementType::Heading2 => num_headings += 1
      DocumentElementType::Heading3 => num_headings += 1
      DocumentElementType::Body => num_paragraphs += 1
      _ => ignore(())
    }
  }
  // 8. 边界框
  let mut min_x = img.width
  let mut min_y = img.height
  let mut max_x = 0
  let mut max_y = 0
  for elem in elements {
    if elem.x < min_x {
      min_x = elem.x
    }
    if elem.y < min_y {
      min_y = elem.y
    }
    if elem.x + elem.width > max_x {
      max_x = elem.x + elem.width
    }
    if elem.y + elem.height > max_y {
      max_y = elem.y + elem.height
    }
  }
  DocumentStructure::{
    elements,
    num_elements: elements.length(),
    title,
    num_headings,
    num_paragraphs,
    reading_order,
    bounding_box: (min_x, min_y, max_x - min_x, max_y - min_y),
  }
}

///|
/// 分类元素类型（基于行高和位置）
fn classify_element_type(
  line : TextLineInfo,
  all_lines : Array[TextLineInfo],
) -> DocumentElementType {
  // 计算平均行高
  let mut avg_height = 0
  for l in all_lines {
    avg_height += l.height
  }
  if all_lines.length() > 0 {
    avg_height = avg_height / all_lines.length()
  }
  // 根据行高判断
  let height_ratio = if avg_height > 0 {
    line.height.to_double() / avg_height.to_double()
  } else {
    1.0
  }
  if height_ratio > 1.8 {
    DocumentElementType::Title
  } else if height_ratio > 1.5 {
    DocumentElementType::Heading1
  } else if height_ratio > 1.3 {
    DocumentElementType::Heading2
  } else if height_ratio > 1.15 {
    DocumentElementType::Heading3
  } else if line.y_start < 30 {
    DocumentElementType::Header
  } else {
    DocumentElementType::Body
  }
}

///|
/// 计算阅读顺序（从上到下，从左到右）
pub fn compute_reading_order(
  elements : Array[DocumentElement],
) -> Array[Int] raise @types.LoadError {
  // 输入验证
  if elements.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "compute_reading_order: 元素列表不能为空",
    )
  }
  // 按 y 坐标排序，然后按 x 坐标排序
  let indices : Array[Int] = []
  for i in 0..<elements.length() {
    indices.push(i)
  }
  // 简单排序（冒泡排序）
  for _ in 0..<indices.length() {
    for j in 0..<(indices.length() - 1) {
      let e1 = elements[indices[j]]
      let e2 = elements[indices[j + 1]]
      // 先按 y 排序，再按 x 排序
      let should_swap = if e1.y > e2.y {
        true
      } else if e1.y == e2.y && e1.x > e2.x {
        true
      } else {
        false
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
/// 提取标题
pub fn extract_title(structure : DocumentStructure) -> String {
  for elem in structure.elements {
    if elem.element_type == DocumentElementType::Title {
      return elem.text
    }
  }
  // 如果没有标题，返回第一个大字体元素
  for elem in structure.elements {
    if elem.font_size > 20 {
      return elem.text
    }
  }
  ""
}

///|
/// 提取所有标题
pub fn extract_headings(
  structure : DocumentStructure,
) -> Array[DocumentElement] {
  let headings : Array[DocumentElement] = []
  for elem in structure.elements {
    match elem.element_type {
      DocumentElementType::Title => headings.push(elem)
      DocumentElementType::Heading1 => headings.push(elem)
      DocumentElementType::Heading2 => headings.push(elem)
      DocumentElementType::Heading3 => headings.push(elem)
      _ => ignore(())
    }
  }
  headings
}

///|
/// 提取正文段落
pub fn extract_paragraphs(
  structure : DocumentStructure,
) -> Array[DocumentElement] {
  let paragraphs : Array[DocumentElement] = []
  for elem in structure.elements {
    if elem.element_type == DocumentElementType::Body {
      paragraphs.push(elem)
    }
  }
  paragraphs
}

///|
/// 按阅读顺序获取元素
pub fn get_elements_in_reading_order(
  structure : DocumentStructure,
) -> Array[DocumentElement] {
  let ordered : Array[DocumentElement] = []
  for idx in structure.reading_order {
    if idx < structure.elements.length() {
      ordered.push(structure.elements[idx])
    }
  }
  ordered
}

///|
/// 文档结构统计
pub fn document_structure_stats(
  structure : DocumentStructure,
) -> (Int, Int, Int, Int, Int) {
  let mut titles = 0
  let mut headings = 0
  let mut paragraphs = 0
  let mut lists = 0
  let mut images = 0
  for elem in structure.elements {
    match elem.element_type {
      DocumentElementType::Title => titles += 1
      DocumentElementType::Heading1 => headings += 1
      DocumentElementType::Heading2 => headings += 1
      DocumentElementType::Heading3 => headings += 1
      DocumentElementType::Body => paragraphs += 1
      DocumentElementType::List => lists += 1
      DocumentElementType::Image => images += 1
      _ => ignore(())
    }
  }
  (titles, headings, paragraphs, lists, images)
}

///|
/// 检测多栏布局并返回栏数
pub fn detect_document_columns(
  img : @types.Image,
) -> Int raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_document_columns: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "detect_document_columns: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "detect_document_columns: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let (num_cols, _) = detect_columns(img)
  num_cols
}

///|
/// 完整文档理解流水线
pub fn understand_document(
  img : @types.Image,
) -> DocumentStructure raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "understand_document: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "understand_document: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "understand_document: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  // 1. 版面分析
  let structure = analyze_document_layout(img)
  // 2. 计算阅读顺序
  let order = compute_reading_order(structure.elements)
  // 3. 更新阅读顺序
  DocumentStructure::{
    elements: structure.elements,
    num_elements: structure.num_elements,
    title: extract_title(structure),
    num_headings: structure.num_headings,
    num_paragraphs: structure.num_paragraphs,
    reading_order: order,
    bounding_box: structure.bounding_box,
  }
}

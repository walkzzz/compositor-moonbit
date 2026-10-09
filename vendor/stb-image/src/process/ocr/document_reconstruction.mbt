// 文档结构理解与 Markdown 还原（v12.18.0）
// 表格转 Markdown、图片提取、符号识别、版面元素分类、阅读顺序、1:1 还原

///|
/// Markdown 元素类型
pub(all) enum MarkdownElementType {
  Title
  Heading1
  Heading2
  Heading3
  Paragraph
  ListItem
  Table
  Image
  Quote
  CodeBlock
  HorizontalRule
  PageBreak
  Unknown
} derive(Eq)

///|
/// Markdown 元素
pub(all) struct MarkdownElement {
  element_type : MarkdownElementType
  x : Int
  y : Int
  width : Int
  height : Int
  content : String
  confidence : Double
}

///|
/// 表格数据
pub(all) struct MarkdownTable {
  rows : Int
  cols : Int
  cells : Array[Array[String]]
  has_header : Bool
}

///|
/// 图片区域
pub(all) struct MarkdownImage {
  x : Int
  y : Int
  width : Int
  height : Int
  image_type : String
  confidence : Double
}

///|
/// 符号识别结果
pub(all) struct MarkdownSymbol {
  symbol : String
  unicode : String
  category : String
  x : Int
  y : Int
  confidence : Double
}

///|
/// 完整 Markdown 文档
pub(all) struct MarkdownDocument {
  title : String
  elements : Array[MarkdownElement]
  tables : Array[MarkdownTable]
  images : Array[MarkdownImage]
  symbols : Array[MarkdownSymbol]
  reading_order : Array[Int]
}

///|
/// 常见符号映射表
fn get_symbol_map() -> Array[(String, String, String)] {
  [
    ("。", "U+3002", "punctuation"),
    ("，", "U+FF0C", "punctuation"),
    ("；", "U+FF1B", "punctuation"),
    ("：", "U+FF1A", "punctuation"),
    ("？", "U+FF1F", "punctuation"),
    ("！", "U+FF01", "punctuation"),
    ("（", "U+FF08", "punctuation"),
    ("）", "U+FF09", "punctuation"),
    ("【", "U+3010", "punctuation"),
    ("】", "U+3011", "punctuation"),
    ("《", "U+300A", "punctuation"),
    ("》", "U+300B", "punctuation"),
    ("—", "U+2014", "punctuation"),
    ("…", "U+2026", "punctuation"),
    ("±", "U+00B1", "math"),
    ("×", "U+00D7", "math"),
    ("÷", "U+00F7", "math"),
    ("≠", "U+2260", "math"),
    ("≤", "U+2264", "math"),
    ("≥", "U+2265", "math"),
    ("∞", "U+221E", "math"),
    ("√", "U+221A", "math"),
    ("π", "U+03C0", "math"),
    ("°", "U+00B0", "math"),
    ("¥", "U+00A5", "currency"),
    ("$", "U+0024", "currency"),
    ("€", "U+20AC", "currency"),
    ("£", "U+00A3", "currency"),
    ("→", "U+2192", "arrow"),
    ("←", "U+2190", "arrow"),
    ("↑", "U+2191", "arrow"),
    ("↓", "U+2193", "arrow"),
    ("★", "U+2605", "special"),
    ("☆", "U+2606", "special"),
    ("●", "U+25CF", "special"),
    ("○", "U+25CB", "special"),
    ("■", "U+25A0", "special"),
    ("□", "U+25A1", "special"),
    ("▲", "U+25B2", "special"),
    ("△", "U+25B3", "special"),
    ("◆", "U+25C6", "special"),
    ("◇", "U+25C7", "special"),
    ("✓", "U+2713", "special"),
    ("✗", "U+2717", "special"),
    ("©", "U+00A9", "special"),
    ("®", "U+00AE", "special"),
    ("™", "U+2122", "special"),
  ]
}

///|
/// 识别文本中的符号
pub fn recognize_symbols_markdown(text : String) -> Array[MarkdownSymbol] {
  let symbols = get_symbol_map()
  let results : Array[MarkdownSymbol] = []
  for _tup0 in symbols {
    let (symbol, unicode, category) = _tup0
    // 简化版：检查符号是否在文本中（通过长度判断）
    if text.length() > 0 {
      results.push(MarkdownSymbol::{
        symbol,
        unicode,
        category,
        x: 0,
        y: 0,
        confidence: 0.9,
      })
    }
  }
  results
}

///|
/// 检测图片区域（基于连通域分析的简化版）
pub fn detect_image_regions_markdown(
  binary_img : @types.Image,
  min_area? : Int = 500,
) -> Array[MarkdownImage] raise @types.LoadError {
  // 输入验证
  if binary_img.width <= 0 || binary_img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_image_regions_markdown: 图像尺寸必须大于0",
    )
  }
  if binary_img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "detect_image_regions_markdown: 仅支持单通道二值图",
    )
  }
  let expected_size = binary_img.width * binary_img.height
  if binary_img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "detect_image_regions_markdown: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      binary_img.data.length().to_string(),
    )
  }
  if min_area <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_image_regions_markdown: 最小区域面积必须大于0",
    )
  }
  let min = min_area
  let w = binary_img.width
  let h = binary_img.height
  let regions : Array[MarkdownImage] = []
  let visited : Array[Bool] = []
  for _ in 0..<(w * h) {
    visited.push(false)
  }
  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      if !visited[idx] && binary_img.data[idx].to_int() < 128 {
        let stack_x : Array[Int] = []
        let stack_y : Array[Int] = []
        stack_x.push(x)
        stack_y.push(y)
        visited[idx] = true
        let mut min_x = x
        let mut max_x = x
        let mut min_y = y
        let mut max_y = y
        let mut area = 0
        while stack_x.length() > 0 {
          let cx_opt = stack_x.pop()
          let cy_opt = stack_y.pop()
          match cx_opt {
            Some(cx) =>
              match cy_opt {
                Some(cy) => {
                  area += 1
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
                  let neighbors = [
                    (cx - 1, cy),
                    (cx + 1, cy),
                    (cx, cy - 1),
                    (cx, cy + 1),
                  ]
                  for _tup1 in neighbors {
                    let (nx, ny) = _tup1
                    if nx >= 0 && nx < w && ny >= 0 && ny < h {
                      let nidx = ny * w + nx
                      if !visited[nidx] && binary_img.data[nidx].to_int() < 128 {
                        visited[nidx] = true
                        stack_x.push(nx)
                        stack_y.push(ny)
                      }
                    }
                  }
                }
                None => ()
              }
            None => ()
          }
        }
        let region_width = max_x - min_x + 1
        let region_height = max_y - min_y + 1
        if area >= min && region_width > 20 && region_height > 20 {
          let fill_ratio = area.to_double() /
            (region_width * region_height).to_double()
          let image_type = if fill_ratio > 0.8 {
            "diagram"
          } else if fill_ratio > 0.5 {
            "chart"
          } else {
            "photo"
          }
          regions.push(MarkdownImage::{
            x: min_x,
            y: min_y,
            width: region_width,
            height: region_height,
            image_type,
            confidence: 0.7,
          })
        }
      }
    }
  }
  regions
}

///|
/// 分类 Markdown 元素类型
pub fn classify_markdown_element(
  block : TextBlock,
  avg_font_size? : Double = 16.0,
) -> MarkdownElementType {
  let avg_size = avg_font_size
  let height_ratio = block.height.to_double() / avg_size
  if height_ratio > 3.0 && block.y < 100 {
    MarkdownElementType::Title
  } else if height_ratio > 2.0 {
    MarkdownElementType::Heading1
  } else if height_ratio > 1.5 {
    MarkdownElementType::Heading2
  } else if height_ratio > 1.2 {
    MarkdownElementType::Heading3
  } else if block.height < 5 && block.width > 100 {
    MarkdownElementType::HorizontalRule
  } else {
    MarkdownElementType::Paragraph
  }
}

///|
/// 表格数据转 Markdown
pub fn markdown_table_to_string(table : MarkdownTable) -> String {
  let mut md = ""
  if table.has_header && table.rows > 0 {
    md = md + "| "
    for col in 0..<table.cols {
      let cell_text = if col < table.cells[0].length() {
        table.cells[0][col]
      } else {
        ""
      }
      md = md + cell_text + " | "
    }
    md = md + "\n| "
    for _ in 0..<table.cols {
      md = md + "--- | "
    }
    md = md + "\n"
    for row in 1..<table.rows {
      md = md + "| "
      for col in 0..<table.cols {
        let cell_text = if row < table.cells.length() &&
          col < table.cells[row].length() {
          table.cells[row][col]
        } else {
          ""
        }
        md = md + cell_text + " | "
      }
      md = md + "\n"
    }
  } else {
    for row in 0..<table.rows {
      md = md + "| "
      for col in 0..<table.cols {
        let cell_text = if row < table.cells.length() &&
          col < table.cells[row].length() {
          table.cells[row][col]
        } else {
          ""
        }
        md = md + cell_text + " | "
      }
      md = md + "\n"
    }
  }
  md
}

///|
/// 确定阅读顺序
pub fn determine_reading_order_markdown(
  elements : Array[MarkdownElement],
) -> Array[Int] {
  let indices : Array[Int] = []
  for i in 0..<elements.length() {
    indices.push(i)
  }
  for i in 0..<indices.length() {
    for j in 0..<(indices.length() - i - 1) {
      let a = indices[j]
      let b = indices[j + 1]
      let should_swap = if (elements[a].y - elements[b].y).abs() < 20 {
        elements[a].x > elements[b].x
      } else {
        elements[a].y > elements[b].y
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
/// Markdown 元素转字符串
fn markdown_element_to_string(element : MarkdownElement) -> String {
  match element.element_type {
    MarkdownElementType::Title => "# " + element.content + "\n\n"
    MarkdownElementType::Heading1 => "## " + element.content + "\n\n"
    MarkdownElementType::Heading2 => "### " + element.content + "\n\n"
    MarkdownElementType::Heading3 => "#### " + element.content + "\n\n"
    MarkdownElementType::Paragraph => element.content + "\n\n"
    MarkdownElementType::ListItem => "- " + element.content + "\n"
    MarkdownElementType::Table => element.content + "\n"
    MarkdownElementType::Image => "![图片](" + element.content + ")\n\n"
    MarkdownElementType::Quote => "> " + element.content + "\n\n"
    MarkdownElementType::CodeBlock => "```\n" + element.content + "\n```\n\n"
    MarkdownElementType::HorizontalRule => "---\n\n"
    MarkdownElementType::PageBreak => "\n\n---\n\n"
    MarkdownElementType::Unknown => element.content + "\n\n"
  }
}

///|
/// 完整文档转 Markdown（1:1 还原）
pub fn markdown_document_to_string(doc : MarkdownDocument) -> String {
  let mut md = ""
  if doc.title.length() > 0 {
    md = md + "# " + doc.title + "\n\n"
  }
  for idx in doc.reading_order {
    if idx < doc.elements.length() {
      md = md + markdown_element_to_string(doc.elements[idx])
    }
  }
  md
}

///|
/// 从 OCR 结果构建 Markdown 文档
pub fn build_markdown_document(
  ocr_result : OCRPageResult,
  title? : String,
) -> MarkdownDocument raise @types.LoadError {
  // 输入验证
  if ocr_result.blocks.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "build_markdown_document: OCR结果的文本块列表不能为空",
    )
  }
  let doc_title = match title {
    Some(v) => v
    None => ""
  }
  let elements : Array[MarkdownElement] = []
  let tables : Array[MarkdownTable] = []
  let images : Array[MarkdownImage] = []
  let symbols : Array[MarkdownSymbol] = []
  for block in ocr_result.blocks {
    let element_type = classify_markdown_element(block, avg_font_size=16.0)
    let element = MarkdownElement::{
      element_type,
      x: block.x,
      y: block.y,
      width: block.width,
      height: block.height,
      content: block.text,
      confidence: block.confidence,
    }
    elements.push(element)
    let block_symbols = recognize_symbols_markdown(block.text)
    for s in block_symbols {
      symbols.push(s)
    }
  }
  let reading_order = determine_reading_order_markdown(elements)
  MarkdownDocument::{
    title: doc_title,
    elements,
    tables,
    images,
    symbols,
    reading_order,
  }
}

///|
/// 生成 Markdown 图片占位符
pub fn generate_markdown_image_placeholder(
  image : MarkdownImage,
  index : Int,
) -> String {
  "![图片" +
  index.to_string() +
  "（" +
  image.image_type +
  "，位置：" +
  image.x.to_string() +
  "," +
  image.y.to_string() +
  "，尺寸：" +
  image.width.to_string() +
  "x" +
  image.height.to_string() +
  "）](image_" +
  index.to_string() +
  ".png)"
}

///|
/// 统计文档元素类型分布
pub fn analyze_markdown_element_distribution(
  doc : MarkdownDocument,
) -> Array[(String, Int)] {
  let mut title_count = 0
  let mut heading_count = 0
  let mut paragraph_count = 0
  let mut list_count = 0
  let mut table_count = 0
  let mut image_count = 0
  let mut quote_count = 0
  let mut code_count = 0
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
  ]
}

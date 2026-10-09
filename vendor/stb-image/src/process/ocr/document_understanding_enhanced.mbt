// 文档理解增强版（v10.2.0）
// 增强版面分析、阅读顺序优化、标题检测、段落检测、多栏处理、文档结构树

///|
/// 文档块类型（增强版）
pub(all) enum DocumentBlockType {
  Title
  Heading1
  Heading2
  Heading3
  Paragraph
  ListItem
  Table
  Image
  Caption
  Header
  Footer
  PageNumber
  Unknown
} derive(Eq)

///|
/// 文档块结构体（增强版）
pub(all) struct DocumentBlock {
  block_type : DocumentBlockType
  x : Int
  y : Int
  width : Int
  height : Int
  text : String
  confidence : Double
  font_size : Int
  is_bold : Bool
  is_italic : Bool
  line_spacing : Double
  indent_level : Int
  column_index : Int
  mut reading_order : Int
  parent_id : Int
  children_ids : Array[Int]
}

///|
/// 文档结构树节点
pub(all) struct DocumentTreeNode {
  node_id : Int
  block : DocumentBlock
  children : Array[DocumentTreeNode]
  depth : Int
}

///|
/// 增强文档理解配置
pub(all) struct DocumentUnderstandingEnhancedConfig {
  min_block_width : Int
  min_block_height : Int
  title_font_size_threshold : Int
  heading_font_size_threshold : Int
  max_line_spacing_ratio : Double
  enable_column_detection : Bool
  enable_hierarchy : Bool
  enable_title_detection : Bool
}

///|
/// 创建默认增强文档理解配置
pub fn document_understanding_enhanced_default_config() -> DocumentUnderstandingEnhancedConfig {
  DocumentUnderstandingEnhancedConfig::{
    min_block_width: 20,
    min_block_height: 10,
    title_font_size_threshold: 24,
    heading_font_size_threshold: 18,
    max_line_spacing_ratio: 2.0,
    enable_column_detection: true,
    enable_hierarchy: true,
    enable_title_detection: true,
  }
}

///|
/// 增强版面分析（基于连通域的文本块检测）
pub fn analyze_layout_enhanced(
  img : @types.Image,
  config? : DocumentUnderstandingEnhancedConfig,
) -> Array[DocumentBlock] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "analyze_layout_enhanced: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "analyze_layout_enhanced: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "analyze_layout_enhanced: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let cfg = match config {
    Some(c) => c
    None => document_understanding_enhanced_default_config()
  }
  // 1. 预处理
  let preprocessed = ocr_preprocess(img)
  // 2. 检测文本行
  let lines = detect_text_lines_projection(preprocessed)
  // 3. 检测文本区域（连通域合并）
  let _ = detect_text_regions(preprocessed)
  // 4. 多栏检测
  let num_columns = if cfg.enable_column_detection {
    let (cols, _) = detect_columns(preprocessed)
    cols
  } else {
    1
  }
  // 5. 构建文档块
  let blocks : Array[DocumentBlock] = []
  let mut order = 0
  for line in lines {
    // 估计字体大小（基于行高）
    let font_size = line.height
    // 判断块类型
    let block_type = classify_block_type_enhanced(line, font_size, cfg, order)
    // 判断是否加粗（基于笔画密度）
    let is_bold = estimate_bold(preprocessed, line)
    // 计算行间距
    let line_spacing = if order > 0 && order < blocks.length() {
      let prev = blocks[order - 1]
      (line.y_start - (prev.y + prev.height)).to_double() /
      font_size.to_double()
    } else {
      1.0
    }
    // 计算缩进级别
    let indent_level = if line.x_start > img.width / 10 {
      ((line.x_start - img.width / 20) / (img.width / 20)).max(0).min(3)
    } else {
      0
    }
    // 计算列索引
    let column_index = if num_columns > 1 {
      let col_width = img.width / num_columns
      (line.x_start / col_width).min(num_columns - 1)
    } else {
      0
    }
    blocks.push(DocumentBlock::{
      block_type,
      x: line.x_start,
      y: line.y_start,
      width: line.width,
      height: line.height,
      text: "",
      confidence: 0.8,
      font_size,
      is_bold,
      is_italic: false,
      line_spacing,
      indent_level,
      column_index,
      reading_order: order,
      parent_id: -1,
      children_ids: [],
    })
    order += 1
  }
  blocks
}

///|
/// 分类块类型（增强版）
fn classify_block_type_enhanced(
  line : TextLineInfo,
  font_size : Int,
  cfg : DocumentUnderstandingEnhancedConfig,
  order : Int,
) -> DocumentBlockType {
  // 标题检测（第一行且字体大）
  if cfg.enable_title_detection &&
    order == 0 &&
    font_size >= cfg.title_font_size_threshold {
    return DocumentBlockType::Title
  }
  // 标题检测（字体大且加粗）
  if font_size >= cfg.heading_font_size_threshold {
    if font_size >= cfg.title_font_size_threshold {
      return DocumentBlockType::Heading1
    } else if font_size >= cfg.heading_font_size_threshold + 2 {
      return DocumentBlockType::Heading2
    } else {
      return DocumentBlockType::Heading3
    }
  }
  // 列表项检测（缩进且短）
  if line.width < 200 && line.x_start > 30 {
    return DocumentBlockType::ListItem
  }
  // 普通段落
  DocumentBlockType::Paragraph
}

///|
/// 估计是否加粗（基于笔画密度）
fn estimate_bold(img : @types.Image, line : TextLineInfo) -> Bool {
  let w = img.width
  let h = img.height
  let data = img.data
  let mut ink_pixels = 0
  let mut total = 0
  let y_start = if line.y_start > 0 { line.y_start } else { 0 }
  let y_end = if line.y_start + line.height < h {
    line.y_start + line.height
  } else {
    h
  }
  let x_start = if line.x_start > 0 { line.x_start } else { 0 }
  let x_end = if line.x_start + line.width < w {
    line.x_start + line.width
  } else {
    w
  }
  for y in y_start..<y_end {
    for x in x_start..<x_end {
      total += 1
      if data[y * w + x].to_int() > 128 {
        ink_pixels += 1
      }
    }
  }
  let density = if total > 0 {
    ink_pixels.to_double() / total.to_double()
  } else {
    0.0
  }
  // 加粗字符通常密度更高
  density > 0.35
}

///|
/// 优化阅读顺序（基于列和几何关系）
pub fn optimize_reading_order(
  blocks : Array[DocumentBlock],
  num_columns : Int,
) -> Array[Int] {
  // 按列分组，然后每列内按 y 排序，再按 x 排序
  let indices : Array[Int] = []
  for col in 0..<num_columns {
    let col_indices : Array[Int] = []
    for i in 0..<blocks.length() {
      if blocks[i].column_index == col {
        col_indices.push(i)
      }
    }
    // 列内按 y 排序，再按 x 排序（冒泡排序）
    for _ in 0..<col_indices.length() {
      for j in 0..<(col_indices.length() - 1) {
        let b1 = blocks[col_indices[j]]
        let b2 = blocks[col_indices[j + 1]]
        let should_swap = if b1.y > b2.y {
          true
        } else if b1.y == b2.y && b1.x > b2.x {
          true
        } else {
          false
        }
        if should_swap {
          let temp = col_indices[j]
          col_indices[j] = col_indices[j + 1]
          col_indices[j + 1] = temp
        }
      }
    }
    for idx in col_indices {
      indices.push(idx)
    }
  }
  // 如果没有检测到列，按全局 y/x 排序
  if indices.length() == 0 {
    for i in 0..<blocks.length() {
      indices.push(i)
    }
    for _ in 0..<indices.length() {
      for j in 0..<(indices.length() - 1) {
        let b1 = blocks[indices[j]]
        let b2 = blocks[indices[j + 1]]
        let should_swap = if b1.y > b2.y {
          true
        } else if b1.y == b2.y && b1.x > b2.x {
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
  }
  indices
}

///|
/// 段落检测（基于行间距和缩进）
pub fn detect_paragraphs(
  blocks : Array[DocumentBlock],
  max_line_spacing_ratio? : Double = 2.0,
) -> Array[Array[Int]] {
  let paragraphs : Array[Array[Int]] = []
  let current_paragraph : Array[Int] = []
  for i in 0..<blocks.length() {
    let block = blocks[i]
    // 只处理段落类型的块
    if block.block_type != DocumentBlockType::Paragraph &&
      block.block_type != DocumentBlockType::ListItem {
      if current_paragraph.length() > 0 {
        paragraphs.push(current_paragraph)
        current_paragraph.clear()
      }
      continue
    }
    // 检查是否是新段落的开始
    let is_new_paragraph = if i > 0 {
      let prev = blocks[i - 1]
      // 行间距过大
      let spacing_too_large = block.line_spacing > max_line_spacing_ratio
      // 缩进变化
      let indent_changed = block.indent_level != prev.indent_level
      // 前一个块不是段落
      let prev_not_paragraph = prev.block_type != DocumentBlockType::Paragraph &&
        prev.block_type != DocumentBlockType::ListItem
      spacing_too_large || indent_changed || prev_not_paragraph
    } else {
      true
    }
    if is_new_paragraph && current_paragraph.length() > 0 {
      paragraphs.push(current_paragraph)
      current_paragraph.clear()
    }
    current_paragraph.push(i)
  }
  if current_paragraph.length() > 0 {
    paragraphs.push(current_paragraph)
  }
  paragraphs
}

///|
/// 标题检测（基于字体大小、位置、加粗特征）
pub fn detect_titles(
  blocks : Array[DocumentBlock],
  title_font_size_threshold? : Int = 24,
) -> Array[Int] {
  let title_indices : Array[Int] = []
  for i in 0..<blocks.length() {
    let block = blocks[i]
    // 标题特征：字体大、加粗、在页面顶部、独占一行
    let is_large = block.font_size >= title_font_size_threshold
    let is_at_top = block.y < 100
    let is_short = block.width < 400
    if is_large && (block.is_bold || is_at_top) && is_short {
      title_indices.push(i)
    }
  }
  title_indices
}

///|
/// 构建文档结构树（层级结构）
pub fn build_document_structure_tree(
  blocks : Array[DocumentBlock],
) -> Array[DocumentTreeNode] {
  // 按阅读顺序排序
  let order = optimize_reading_order(blocks, 1)
  let ordered_blocks : Array[DocumentBlock] = []
  for idx in order {
    ordered_blocks.push(blocks[idx])
  }
  // 构建树（基于标题层级）
  let roots : Array[DocumentTreeNode] = []
  let stack : Array[DocumentTreeNode] = []
  let mut node_id = 0
  for block in ordered_blocks {
    // 计算深度（基于块类型）
    let depth = match block.block_type {
      DocumentBlockType::Title => 0
      DocumentBlockType::Heading1 => 1
      DocumentBlockType::Heading2 => 2
      DocumentBlockType::Heading3 => 3
      _ => 4
    }
    let node = DocumentTreeNode::{ node_id, block, children: [], depth }
    node_id += 1
    // 弹出栈中深度 >= 当前深度的节点
    while stack.length() > 0 && stack[stack.length() - 1].depth >= depth {
      let _ = stack.pop()
    }
    // 如果栈为空，添加到根节点
    if stack.length() == 0 {
      roots.push(node)
    } else {
      // 添加为栈顶节点的子节点
      let parent = stack[stack.length() - 1]
      parent.children.push(node)
    }
    // 将当前节点压入栈
    stack.push(node)
  }
  roots
}

///|
/// 提取文档纯文本（按阅读顺序）
pub fn extract_document_text(
  blocks : Array[DocumentBlock],
  include_headers? : Bool = true,
  include_footers? : Bool = false,
) -> String {
  let order = optimize_reading_order(blocks, 1)
  let mut text = ""
  for idx in order {
    let block = blocks[idx]
    // 过滤页眉页脚
    if !include_headers && block.block_type == DocumentBlockType::Header {
      continue
    }
    if !include_footers && block.block_type == DocumentBlockType::Footer {
      continue
    }
    if block.text.length() > 0 {
      text += block.text
      // 标题和段落之间加换行
      match block.block_type {
        DocumentBlockType::Title => text += "\n\n"
        DocumentBlockType::Heading1 => text += "\n\n"
        DocumentBlockType::Heading2 => text += "\n\n"
        DocumentBlockType::Heading3 => text += "\n\n"
        DocumentBlockType::Paragraph => text += "\n"
        DocumentBlockType::ListItem => text += "\n"
        _ => text += " "
      }
    }
  }
  text
}

///|
/// 文档统计信息（增强版）
pub fn document_statistics_enhanced(
  blocks : Array[DocumentBlock],
) -> (Int, Int, Int, Int, Int, Int, Int) {
  let mut titles = 0
  let mut headings = 0
  let mut paragraphs = 0
  let mut list_items = 0
  let mut tables = 0
  let mut images = 0
  let mut total_chars = 0
  for block in blocks {
    match block.block_type {
      DocumentBlockType::Title => titles += 1
      DocumentBlockType::Heading1 => headings += 1
      DocumentBlockType::Heading2 => headings += 1
      DocumentBlockType::Heading3 => headings += 1
      DocumentBlockType::Paragraph => paragraphs += 1
      DocumentBlockType::ListItem => list_items += 1
      DocumentBlockType::Table => tables += 1
      DocumentBlockType::Image => images += 1
      _ => ignore(())
    }
    total_chars += block.text.length()
  }
  (titles, headings, paragraphs, list_items, tables, images, total_chars)
}

///|
/// 完整增强文档理解流水线
pub fn understand_document_enhanced(
  img : @types.Image,
  config? : DocumentUnderstandingEnhancedConfig,
) -> (Array[DocumentBlock], Array[DocumentTreeNode], String) raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "understand_document_enhanced: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "understand_document_enhanced: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "understand_document_enhanced: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let cfg = match config {
    Some(c) => c
    None => document_understanding_enhanced_default_config()
  }
  // 1. 增强版面分析
  let blocks = analyze_layout_enhanced(img, config=cfg)
  // 2. 多栏检测
  let num_columns = if cfg.enable_column_detection {
    let preprocessed = ocr_preprocess(img)
    let (cols, _) = detect_columns(preprocessed)
    cols
  } else {
    1
  }
  // 3. 优化阅读顺序
  let order = optimize_reading_order(blocks, num_columns)
  // 更新块的阅读顺序
  for i in 0..<order.length() {
    blocks[order[i]].reading_order = i
  }
  // 4. 构建文档结构树
  let tree = if cfg.enable_hierarchy {
    build_document_structure_tree(blocks)
  } else {
    []
  }
  // 5. 提取纯文本
  let text = extract_document_text(
    blocks,
    include_headers=true,
    include_footers=false,
  )
  (blocks, tree, text)
}

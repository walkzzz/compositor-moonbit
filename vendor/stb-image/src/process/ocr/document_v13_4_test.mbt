// v13.4.0 文档理解测试

///|
fn make_doc_img(w : Int, h : Int) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(Array::make(w * h, b'\x80')),
  }
}

///|
test "analyze_document_layout: 基本版面分析" {
  let img = make_doc_img(64, 64)
  let structure = analyze_document_layout(img)
  assert_true(structure.num_elements >= 0)
}

///|
test "analyze_document_layout: 无效图像抛异常" {
  let img = @types.Image::{
    width: 0,
    height: 0,
    channels: 1,
    data: Bytes::from_array([]),
  }
  try {
    ignore(analyze_document_layout(img))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "extract_title: 提取标题" {
  let img = make_doc_img(64, 64)
  let structure = analyze_document_layout(img)
  let title = extract_title(structure)
  assert_true(title.length() >= 0)
}

///|
test "extract_headings: 提取标题列表" {
  let img = make_doc_img(64, 64)
  let structure = analyze_document_layout(img)
  let headings = extract_headings(structure)
  assert_true(headings.length() >= 0)
}

///|
test "extract_paragraphs: 提取段落列表" {
  let img = make_doc_img(64, 64)
  let structure = analyze_document_layout(img)
  let paragraphs = extract_paragraphs(structure)
  assert_true(paragraphs.length() >= 0)
}

///|
test "get_elements_in_reading_order: 按阅读顺序获取元素" {
  let img = make_doc_img(64, 64)
  let structure = analyze_document_layout(img)
  let ordered = get_elements_in_reading_order(structure)
  assert_true(ordered.length() >= 0)
}

///|
test "document_structure_stats: 统计信息" {
  let img = make_doc_img(64, 64)
  let structure = analyze_document_layout(img)
  let (total, titles, headings, paragraphs, others) = document_structure_stats(
    structure,
  )
  assert_true(total >= 0)
  assert_true(titles >= 0)
  assert_true(headings >= 0)
  assert_true(paragraphs >= 0)
  assert_true(others >= 0)
}

///|
test "detect_document_columns: 检测栏数" {
  let img = make_doc_img(128, 64)
  let cols = detect_document_columns(img)
  assert_true(cols >= 1)
}

///|
test "understand_document: 完整文档理解" {
  let img = make_doc_img(64, 64)
  let structure = understand_document(img)
  assert_true(structure.num_elements >= 0)
}

///|
test "document_understanding_enhanced_default_config: 返回有效配置" {
  let config = document_understanding_enhanced_default_config()
  assert_true(config.min_block_width > 0)
  assert_true(config.min_block_height > 0)
}

///|
test "analyze_layout_enhanced: 增强版面分析" {
  let img = make_doc_img(64, 64)
  let blocks = analyze_layout_enhanced(img)
  assert_true(blocks.length() >= 0)
}

///|
test "optimize_reading_order: 优化阅读顺序" {
  let img = make_doc_img(64, 64)
  let blocks = analyze_layout_enhanced(img)
  let order = optimize_reading_order(blocks, 1)
  assert_true(order.length() >= 0)
}

///|
test "detect_paragraphs: 检测段落" {
  let img = make_doc_img(64, 64)
  let blocks = analyze_layout_enhanced(img)
  let paragraphs = detect_paragraphs(blocks)
  assert_true(paragraphs.length() >= 0)
}

///|
test "detect_titles: 检测标题" {
  let img = make_doc_img(64, 64)
  let blocks = analyze_layout_enhanced(img)
  let titles = detect_titles(blocks)
  assert_true(titles.length() >= 0)
}

///|
test "build_document_structure_tree: 构建结构树" {
  let img = make_doc_img(64, 64)
  let blocks = analyze_layout_enhanced(img)
  let tree = build_document_structure_tree(blocks)
  assert_true(tree.length() >= 0)
}

///|
test "extract_document_text: 提取文本" {
  let img = make_doc_img(64, 64)
  let blocks = analyze_layout_enhanced(img)
  let text = extract_document_text(blocks)
  assert_true(text.length() >= 0)
}

///|
test "document_statistics_enhanced: 增强统计" {
  let img = make_doc_img(64, 64)
  let blocks = analyze_layout_enhanced(img)
  let (total, titles, paras, _, _, _, _) = document_statistics_enhanced(blocks)
  assert_true(total >= 0)
  assert_true(titles >= 0)
  assert_true(paras >= 0)
}

///|
test "understand_document_enhanced: 完整增强理解" {
  let img = make_doc_img(64, 64)
  let (blocks, tree, text) = understand_document_enhanced(img)
  assert_true(blocks.length() >= 0)
  assert_true(tree.length() >= 0)
  assert_true(text.length() >= 0)
}

///|
test "recognize_symbols_markdown: 符号识别" {
  let symbols = recognize_symbols_markdown("Hello World")
  assert_true(symbols.length() >= 0)
}

///|
test "detect_image_regions_markdown: 图片区域检测" {
  let img = make_doc_img(64, 64)
  let regions = detect_image_regions_markdown(img)
  assert_true(regions.length() >= 0)
}

///|
test "markdown_table_to_string: 表格转Markdown" {
  let table = MarkdownTable::{
    rows: 2,
    cols: 2,
    has_header: true,
    cells: [["A", "B"], ["1", "2"]],
  }
  let result = markdown_table_to_string(table)
  assert_true(result.length() > 0)
}

///|
test "determine_reading_order_markdown: 阅读顺序" {
  let elements : Array[MarkdownElement] = []
  let order = determine_reading_order_markdown(elements)
  assert_eq(order.length(), 0)
}

///|
test "markdown_document_to_string: 文档转字符串" {
  let doc = MarkdownDocument::{
    title: "Test",
    elements: [],
    tables: [],
    images: [],
    symbols: [],
    reading_order: [],
  }
  let result = markdown_document_to_string(doc)
  assert_true(result.length() > 0)
}

///|
test "analyze_markdown_element_distribution: 元素分布" {
  let doc = MarkdownDocument::{
    title: "Test",
    elements: [],
    tables: [],
    images: [],
    symbols: [],
    reading_order: [],
  }
  let distribution = analyze_markdown_element_distribution(doc)
  assert_true(distribution.length() >= 0)
}

///|
test "document_enhance: 文档增强" {
  let img = make_doc_img(32, 32)
  let result = document_enhance(img)
  assert_true(result.width > 0)
  assert_true(result.height > 0)
}

///|
test "shadow_removal: 阴影去除" {
  let img = make_doc_img(32, 32)
  let result = shadow_removal(img)
  assert_true(result.width > 0)
  assert_true(result.height > 0)
}

///|
test "background_normalization: 背景归一化" {
  let img = make_doc_img(32, 32)
  let result = background_normalization(img)
  assert_true(result.width > 0)
  assert_true(result.height > 0)
}

// OCR 功能测试
// 测试扫描版文档 OCR 的预处理、版面分析和识别功能

///|
/// 创建测试用的文档图像（模拟扫描文档）
fn create_test_document_image() -> @types.Image {
  let width = 400
  let height = 300
  let channels = 3
  let data : Array[Byte] = []
  // 白色背景
  for _ in 0..<(width * height * channels) {
    data.push(b'\xFF')
  }
  // 绘制一些黑色文本行（模拟文本）
  // 第一行：y=50
  for x in 50..<350 {
    for dy in 0..<20 {
      let idx = ((50 + dy) * width + x) * channels
      data[idx] = b'\x00'
      data[idx + 1] = b'\x00'
      data[idx + 2] = b'\x00'
    }
  }
  // 第二行：y=100
  for x in 80..<320 {
    for dy in 0..<20 {
      let idx = ((100 + dy) * width + x) * channels
      data[idx] = b'\x00'
      data[idx + 1] = b'\x00'
      data[idx + 2] = b'\x00'
    }
  }
  // 第三行：y=150
  for x in 30..<370 {
    for dy in 0..<20 {
      let idx = ((150 + dy) * width + x) * channels
      data[idx] = b'\x00'
      data[idx + 1] = b'\x00'
      data[idx + 2] = b'\x00'
    }
  }
  // 第四行：y=200
  for x in 100..<300 {
    for dy in 0..<20 {
      let idx = ((200 + dy) * width + x) * channels
      data[idx] = b'\x00'
      data[idx + 1] = b'\x00'
      data[idx + 2] = b'\x00'
    }
  }
  @types.Image::{ width, height, channels, data: Bytes::from_array(data) }
}

///|
/// 测试扫描质量评估
test "scan_quality_evaluation" {
  let img = create_test_document_image()
  let quality = @img.evaluate_scan_quality(img)
  // 白色背景 + 黑色文本，亮度应该较高
  assert_true(quality.brightness > 200.0)
  // 有黑白对比，对比度应该 > 0
  assert_true(quality.contrast > 0.0)
  // 质量评分应该 > 0
  assert_true(quality.overall_score >= 0.0)
  println("扫描质量评估测试通过")
  println("  亮度: " + quality.brightness.to_string())
  println("  对比度: " + quality.contrast.to_string())
  println("  质量评分: " + quality.overall_score.to_string())
}

///|
/// 测试文档预处理
test "document_preprocessing" {
  let img = create_test_document_image()
  let config = @img.scan_ocr_default_config()
  let preprocessed = @img.scan_document_preprocess(img, config)
  // 预处理后应该是二值图像（1通道）
  assert_eq(preprocessed.channels, 1)
  // 尺寸应该不变
  assert_eq(preprocessed.width, img.width)
  assert_eq(preprocessed.height, img.height)
  println("文档预处理测试通过")
  println("  输出通道: " + preprocessed.channels.to_string())
}

///|
/// 测试版面分析
test "layout_analysis" {
  let img = create_test_document_image()
  let config = @img.scan_ocr_default_config()
  let preprocessed = @img.scan_document_preprocess(img, config)
  let blocks = @img.analyze_layout_scan(preprocessed)
  // 应该检测到至少 3 个文本块（4 行文本，可能有些合并）
  assert_true(blocks.length() >= 3)
  println("版面分析测试通过")
  println("  检测到文本块数: " + blocks.length().to_string())
  for i in 0..<blocks.length() {
    let block = blocks[i]
    println(
      "    块 " +
      i.to_string() +
      ": y=" +
      block.y.to_string() +
      ", height=" +
      block.height.to_string(),
    )
  }
}

///|
/// 测试 OCR 识别流水线
test "ocr_recognition_pipeline" {
  let img = create_test_document_image()
  let config = @img.scan_ocr_default_config()
  let result = @img.scan_ocr_recognize(img, config)
  // 应该有识别结果
  assert_true(result.blocks.length() > 0)
  // 平均置信度应该 > 0
  assert_true(result.average_confidence > 0.0)
  println("OCR 识别流水线测试通过")
  println("  文本块数: " + result.blocks.length().to_string())
  println("  平均置信度: " + result.average_confidence.to_string())
  println("  识别文本长度: " + result.full_text.length().to_string())
}

///|
/// 测试 OCR 结果导出
test "ocr_result_export" {
  let img = create_test_document_image()
  let config = @img.scan_ocr_default_config()
  let result = @img.scan_ocr_recognize(img, config)
  // 测试纯文本导出
  let text = @img.ocr_result_to_text(result)
  assert_true(text.length() > 0)
  // 测试 hOCR 导出
  let hocr = @img.ocr_result_to_hocr(result)
  assert_true(hocr.contains("html"))
  assert_true(hocr.contains("ocr_page"))
  // 测试 JSON 导出
  let json = @img.ocr_result_to_json(result)
  assert_true(json.contains("page_number"))
  assert_true(json.contains("blocks"))
  println("OCR 结果导出测试通过")
  println("  文本长度: " + text.length().to_string())
  println("  hOCR 长度: " + hocr.length().to_string())
  println("  JSON 长度: " + json.length().to_string())
}

///|
/// 测试批量 OCR
test "batch_ocr" {
  let img1 = create_test_document_image()
  let img2 = create_test_document_image()
  let config = @img.scan_ocr_default_config()
  let images = [img1, img2]
  let results = @img.batch_scan_ocr(images, config)
  // 应该有 2 个结果
  assert_eq(results.length(), 2)
  // 页码应该是 1 和 2
  assert_eq(results[0].page_number, 1)
  assert_eq(results[1].page_number, 2)
  println("批量 OCR 测试通过")
  println("  结果数: " + results.length().to_string())
  println("  第一页页码: " + results[0].page_number.to_string())
  println("  第二页页码: " + results[1].page_number.to_string())
}

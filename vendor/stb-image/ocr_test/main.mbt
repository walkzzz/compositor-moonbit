// OCR 测试程序
// 测试扫描版 PDF 的 OCR 识别功能

fn read_raw_image(path : String) -> @image.Image {
  let file = @io.open(path).unwrap()
  let data = file.read_all().unwrap()
  file.close()
  // 解析头部：宽度(4字节) + 高度(4字节) + 通道数(4字节)
  let width = (data[0].to_int() | (data[1].to_int() << 8) | (data[2].to_int() << 16) | (data[3].to_int() << 24))
  let height = (data[4].to_int() | (data[5].to_int() << 8) | (data[6].to_int() << 16) | (data[7].to_int() << 24))
  let channels = (data[8].to_int() | (data[9].to_int() << 8) | (data[10].to_int() << 16) | (data[11].to_int() << 24))
  // 像素数据从第 12 字节开始
  let pixel_data = @array.slice(data, 12, data.length())
  @image.Image::{
    width,
    height,
    channels,
    data: pixel_data,
  }
}

fn main() {
  println("=== stb-image OCR 测试程序 ===")
  println()

  // 1. 读取测试图像
  println("[1/5] 读取测试图像...")
  let img = read_raw_image("page-01.raw")
  println("图像尺寸: " + img.width.to_string() + "x" + img.height.to_string() + ", " + img.channels.to_string() + " 通道")
  println()

  // 2. 评估扫描质量
  println("[2/5] 评估扫描质量...")
  let quality = @image.evaluate_scan_quality(img)
  println("亮度: " + quality.brightness.to_string())
  println("对比度: " + quality.contrast.to_string())
  println("锐度: " + quality.sharpness.to_string())
  println("噪声水平: " + quality.noise_level.to_string())
  println("综合质量评分: " + quality.overall_score.to_string() + "/100")
  if quality.issues.length() > 0 {
    println("检测到的问题:")
    for issue in quality.issues {
      println("  - " + issue)
    }
  }
  println()

  // 3. 图像预处理
  println("[3/5] 图像预处理...")
  let config = @image.scan_ocr_default_config()
  let preprocessed = @image.scan_document_preprocess(img, config)
  println("预处理完成，输出尺寸: " + preprocessed.width.to_string() + "x" + preprocessed.height.to_string())
  println()

  // 4. 版面分析
  println("[4/5] 版面分析...")
  let blocks = @image.analyze_layout_scan(preprocessed)
  println("检测到 " + blocks.length().to_string() + " 个文本块")
  for i in 0..<blocks.length().min(10) {
    let block = blocks[i]
    println("  块 " + i.to_string() + ": 位置(" + block.x.to_string() + "," + block.y.to_string() + ") 尺寸(" + block.width.to_string() + "x" + block.height.to_string() + ") 类型:" + block.block_type)
  }
  if blocks.length() > 10 {
    println("  ... 还有 " + (blocks.length() - 10).to_string() + " 个文本块")
  }
  println()

  // 5. OCR 识别
  println("[5/5] OCR 识别...")
  let result = @image.scan_ocr_recognize(img, config)
  println("识别完成")
  println("平均置信度: " + result.average_confidence.to_string())
  println("文本块数量: " + result.blocks.length().to_string())
  println()
  println("=== 识别结果（前 500 字符）===")
  let text = result.full_text
  let display_len = if text.length() > 500 { 500 } else { text.length() }
  println(@string.substring(text, 0, display_len))
  if text.length() > 500 {
    println("... (共 " + text.length().to_string() + " 字符)")
  }
  println()
  println("=== 测试完成 ===")
}

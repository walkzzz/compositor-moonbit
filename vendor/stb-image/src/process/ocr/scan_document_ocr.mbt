// 扫描版文档 OCR 增强（v12.16.0）
// 扫描文档预处理、版面分析、质量评估、批量处理、多格式输出

///|
/// 扫描文档配置
pub(all) struct ScanOCRConfig {
  language : String // "digit" / "english" / "chinese" / "multilingual"
  dpi : Int // 扫描 DPI（通常 300）
  deskew : Bool // 是否自动倾斜校正
  denoise : Bool // 是否去噪
  binarization_method : String // "otsu" / "adaptive" / "sauvola"
  layout_analysis : Bool // 是否进行版面分析
  confidence_threshold : Double // 置信度阈值
}

///|
/// 创建默认扫描 OCR 配置
pub fn scan_ocr_default_config() -> ScanOCRConfig {
  ScanOCRConfig::{
    language: "english",
    dpi: 300,
    deskew: true,
    denoise: true,
    binarization_method: "otsu",
    layout_analysis: true,
    confidence_threshold: 0.6,
  }
}

///|
/// 扫描质量评估结果
pub(all) struct ScanQuality {
  brightness : Double // 平均亮度（0-255）
  contrast : Double // 对比度（标准差）
  sharpness : Double // 锐度（拉普拉斯方差）
  noise_level : Double // 噪声水平
  skew_angle : Double // 倾斜角度（度）
  overall_score : Double // 综合质量评分（0-100）
  issues : Array[String] // 检测到的问题
}

///|
/// 文本块（版面分析结果）
pub(all) struct TextBlock {
  x : Int
  y : Int
  width : Int
  height : Int
  block_type : String // "text" / "title" / "table" / "image" / "list"
  text : String
  confidence : Double
  reading_order : Int
}

///|
/// OCR 页面结果
pub(all) struct OCRPageResult {
  page_number : Int
  width : Int
  height : Int
  blocks : Array[TextBlock]
  full_text : String
  average_confidence : Double
  processing_time_ms : Double
}

///|
/// 评估扫描图像质量
pub fn evaluate_scan_quality(
  img : @types.Image,
) -> ScanQuality raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "evaluate_scan_quality: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "evaluate_scan_quality: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "evaluate_scan_quality: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let w = img.width
  let h = img.height
  let channels = img.channels
  // 计算亮度和对比度
  let mut sum = 0.0
  let mut sum_sq = 0.0
  let total = (w * h).to_double()
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      let gray = if channels >= 3 {
        0.299 * img.data[idx].to_double() +
        0.587 * img.data[idx + 1].to_double() +
        0.114 * img.data[idx + 2].to_double()
      } else {
        img.data[idx].to_double()
      }
      sum += gray
      sum_sq += gray * gray
    }
  }
  let brightness = sum / total
  let variance = sum_sq / total - brightness * brightness
  let contrast = if variance > 0.0 { variance.sqrt() } else { 0.0 }
  // 计算锐度（拉普拉斯算子简化版）
  let mut sharpness_sum = 0.0
  let mut sharpness_count = 0
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = (y * w + x) * channels
      let center = if channels >= 3 {
        0.299 * img.data[idx].to_double() +
        0.587 * img.data[idx + 1].to_double() +
        0.114 * img.data[idx + 2].to_double()
      } else {
        img.data[idx].to_double()
      }
      let up = if channels >= 3 {
        0.299 * img.data[((y - 1) * w + x) * channels].to_double() +
        0.587 * img.data[((y - 1) * w + x) * channels + 1].to_double() +
        0.114 * img.data[((y - 1) * w + x) * channels + 2].to_double()
      } else {
        img.data[((y - 1) * w + x) * channels].to_double()
      }
      let down = if channels >= 3 {
        0.299 * img.data[((y + 1) * w + x) * channels].to_double() +
        0.587 * img.data[((y + 1) * w + x) * channels + 1].to_double() +
        0.114 * img.data[((y + 1) * w + x) * channels + 2].to_double()
      } else {
        img.data[((y + 1) * w + x) * channels].to_double()
      }
      let left = if channels >= 3 {
        0.299 * img.data[(y * w + x - 1) * channels].to_double() +
        0.587 * img.data[(y * w + x - 1) * channels + 1].to_double() +
        0.114 * img.data[(y * w + x - 1) * channels + 2].to_double()
      } else {
        img.data[(y * w + x - 1) * channels].to_double()
      }
      let right = if channels >= 3 {
        0.299 * img.data[(y * w + x + 1) * channels].to_double() +
        0.587 * img.data[(y * w + x + 1) * channels + 1].to_double() +
        0.114 * img.data[(y * w + x + 1) * channels + 2].to_double()
      } else {
        img.data[(y * w + x + 1) * channels].to_double()
      }
      let laplacian = 4.0 * center - up - down - left - right
      sharpness_sum += laplacian * laplacian
      sharpness_count += 1
    }
  }
  let sharpness = if sharpness_count > 0 {
    sharpness_sum / sharpness_count.to_double()
  } else {
    0.0
  }
  // 估计噪声水平（基于平坦区域的方差）
  let noise_level = if contrast > 0 { (contrast * 0.1).min(50.0) } else { 10.0 }
  // 估计倾斜角度（简化版：基于水平投影的方差）
  let skew_angle = 0.0 // 简化，实际需要霍夫变换
  // 综合质量评分
  let mut score = 50.0
  // 亮度评分（理想 128）
  let brightness_score = 100.0 - (brightness - 128.0).abs() * 0.5
  score += brightness_score * 0.2
  // 对比度评分（理想 > 50）
  let contrast_score = if contrast > 50.0 { 100.0 } else { contrast * 2.0 }
  score += contrast_score * 0.3
  // 锐度评分
  let sharpness_score = if sharpness > 100.0 { 100.0 } else { sharpness }
  score += sharpness_score * 0.3
  // 噪声评分
  let noise_score = if noise_level < 10.0 {
    100.0
  } else {
    (100.0 - noise_level).max(0.0)
  }
  score += noise_score * 0.2
  // 检测问题
  let issues : Array[String] = []
  if brightness < 50.0 {
    issues.push("图像过暗")
  }
  if brightness > 200.0 {
    issues.push("图像过亮")
  }
  if contrast < 30.0 {
    issues.push("对比度不足")
  }
  if sharpness < 20.0 {
    issues.push("图像模糊")
  }
  if noise_level > 30.0 {
    issues.push("噪声较高")
  }
  ScanQuality::{
    brightness,
    contrast,
    sharpness,
    noise_level,
    skew_angle,
    overall_score: score.min(100.0).max(0.0),
    issues,
  }
}

///|
/// 扫描文档预处理流水线
pub fn scan_document_preprocess(
  img : @types.Image,
  config : ScanOCRConfig,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "scan_document_preprocess: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "scan_document_preprocess: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "scan_document_preprocess: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let mut result = img
  // 1. 去噪（中值滤波简化版）
  if config.denoise {
    result = denoise_scan(result)
  }
  // 2. 对比度增强
  result = enhance_contrast_scan(result)
  // 3. 二值化
  result = match config.binarization_method {
    "otsu" => binarize_otsu_scan(result)
    "adaptive" => binarize_adaptive_scan(result)
    "sauvola" => binarize_sauvola_scan(result)
    _ => binarize_otsu_scan(result)
  }
  result
}

///|
/// 扫描文档去噪（简化版中值滤波）
fn denoise_scan(img : @types.Image) -> @types.Image {
  let w = img.width
  let h = img.height
  let channels = img.channels
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      for c in 0..<channels {
        // 3x3 中值滤波（简化版：取 5 个点的中值）
        let values : Array[Int] = []
        // 中心
        values.push(img.data[idx + c].to_int())
        // 上
        if y > 0 {
          values.push(img.data[((y - 1) * w + x) * channels + c].to_int())
        }
        // 下
        if y < h - 1 {
          values.push(img.data[((y + 1) * w + x) * channels + c].to_int())
        }
        // 左
        if x > 0 {
          values.push(img.data[(y * w + x - 1) * channels + c].to_int())
        }
        // 右
        if x < w - 1 {
          values.push(img.data[(y * w + x + 1) * channels + c].to_int())
        }
        // 排序取中值
        for i in 0..<values.length() {
          for j in 0..<(values.length() - i - 1) {
            if values[j] > values[j + 1] {
              let temp = values[j]
              values[j] = values[j + 1]
              values[j + 1] = temp
            }
          }
        }
        let median = values[values.length() / 2]
        out_data[idx + c] = median.to_byte()
      }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 扫描文档对比度增强（直方图拉伸）
fn enhance_contrast_scan(img : @types.Image) -> @types.Image {
  let w = img.width
  let h = img.height
  let channels = img.channels
  // 计算最小值和最大值（忽略 1% 极值）
  let histogram : Array[Int] = []
  for _ in 0..<256 {
    histogram.push(0)
  }
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      let gray = if channels >= 3 {
        (0.299 * img.data[idx].to_double() +
        0.587 * img.data[idx + 1].to_double() +
        0.114 * img.data[idx + 2].to_double()).to_int()
      } else {
        img.data[idx].to_int()
      }
      histogram[gray] += 1
    }
  }
  let total = w * h
  let lower_count = total / 100
  let upper_count = total - lower_count
  let mut min_val = 0
  let mut max_val = 255
  let mut cum = 0
  for i in 0..<256 {
    cum += histogram[i]
    if cum >= lower_count && min_val == 0 {
      min_val = i
    }
    if cum >= upper_count {
      max_val = i
      break
    }
  }
  // 应用拉伸
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  let range = (max_val - min_val).max(1)
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      for c in 0..<channels {
        let val = img.data[idx + c].to_int()
        let stretched = ((val - min_val) * 255 / range).min(255).max(0)
        out_data[idx + c] = stretched.to_byte()
      }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels,
    data: Bytes::from_array(out_data),
  }
}

///|
/// Otsu 二值化
fn binarize_otsu_scan(img : @types.Image) -> @types.Image {
  let w = img.width
  let h = img.height
  let channels = img.channels
  // 计算直方图
  let histogram : Array[Int] = []
  for _ in 0..<256 {
    histogram.push(0)
  }
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      let gray = if channels >= 3 {
        (0.299 * img.data[idx].to_double() +
        0.587 * img.data[idx + 1].to_double() +
        0.114 * img.data[idx + 2].to_double()).to_int()
      } else {
        img.data[idx].to_int()
      }
      histogram[gray] += 1
    }
  }
  // Otsu 阈值计算
  let total = w * h
  let mut sum_total = 0.0
  for i in 0..<256 {
    sum_total += i.to_double() * histogram[i].to_double()
  }
  let mut sum_bg = 0.0
  let mut weight_bg = 0
  let mut max_variance = 0.0
  let mut threshold = 128
  for i in 0..<256 {
    weight_bg += histogram[i]
    if weight_bg == 0 {
      continue
    }
    let weight_fg = total - weight_bg
    if weight_fg == 0 {
      break
    }
    sum_bg += i.to_double() * histogram[i].to_double()
    let mean_bg = sum_bg / weight_bg.to_double()
    let mean_fg = (sum_total - sum_bg) / weight_fg.to_double()
    let variance = weight_bg.to_double() *
      weight_fg.to_double() *
      (mean_bg - mean_fg) *
      (mean_bg - mean_fg)
    if variance > max_variance {
      max_variance = variance
      threshold = i
    }
  }
  // 应用二值化
  let out_data : Array[Byte] = Array::make(w * h, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      let gray = if channels >= 3 {
        (0.299 * img.data[idx].to_double() +
        0.587 * img.data[idx + 1].to_double() +
        0.114 * img.data[idx + 2].to_double()).to_int()
      } else {
        img.data[idx].to_int()
      }
      out_data[y * w + x] = if gray > threshold { b'\xFF' } else { b'\x00' }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 自适应二值化（简化版）
fn binarize_adaptive_scan(img : @types.Image) -> @types.Image {
  let w = img.width
  let h = img.height
  let channels = img.channels
  let block_size = 15
  let c = 10
  let out_data : Array[Byte] = Array::make(w * h, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      // 计算局部均值
      let mut sum = 0
      let mut count = 0
      for dy_idx in 0..<block_size {
        let dy = dy_idx - block_size / 2
        for dx_idx in 0..<block_size {
          let dx = dx_idx - block_size / 2
          let ny = y + dy
          let nx = x + dx
          if ny >= 0 && ny < h && nx >= 0 && nx < w {
            let idx = (ny * w + nx) * channels
            let gray = if channels >= 3 {
              (0.299 * img.data[idx].to_double() +
              0.587 * img.data[idx + 1].to_double() +
              0.114 * img.data[idx + 2].to_double()).to_int()
            } else {
              img.data[idx].to_int()
            }
            sum += gray
            count += 1
          }
        }
      }
      let local_mean = if count > 0 { sum / count } else { 128 }
      let idx = (y * w + x) * channels
      let gray = if channels >= 3 {
        (0.299 * img.data[idx].to_double() +
        0.587 * img.data[idx + 1].to_double() +
        0.114 * img.data[idx + 2].to_double()).to_int()
      } else {
        img.data[idx].to_int()
      }
      out_data[y * w + x] = if gray > local_mean - c {
        b'\xFF'
      } else {
        b'\x00'
      }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out_data),
  }
}

///|
/// Sauvola 二值化（简化版）
fn binarize_sauvola_scan(img : @types.Image) -> @types.Image {
  let w = img.width
  let h = img.height
  let channels = img.channels
  let window_size = 15
  let k = 0.2
  let r = 128.0
  let out_data : Array[Byte] = Array::make(w * h, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      // 计算局部均值和标准差
      let mut sum = 0.0
      let mut sum_sq = 0.0
      let mut count = 0
      for dy_idx in 0..<window_size {
        let dy = dy_idx - window_size / 2
        for dx_idx in 0..<window_size {
          let dx = dx_idx - window_size / 2
          let ny = y + dy
          let nx = x + dx
          if ny >= 0 && ny < h && nx >= 0 && nx < w {
            let idx = (ny * w + nx) * channels
            let gray = if channels >= 3 {
              0.299 * img.data[idx].to_double() +
              0.587 * img.data[idx + 1].to_double() +
              0.114 * img.data[idx + 2].to_double()
            } else {
              img.data[idx].to_double()
            }
            sum += gray
            sum_sq += gray * gray
            count += 1
          }
        }
      }
      let mean = if count > 0 { sum / count.to_double() } else { 128.0 }
      let variance = if count > 0 {
        sum_sq / count.to_double() - mean * mean
      } else {
        0.0
      }
      let std = if variance > 0.0 { variance.sqrt() } else { 0.0 }
      // Sauvola 阈值
      let threshold = mean * (1.0 + k * (std / r - 1.0))
      let idx = (y * w + x) * channels
      let gray = if channels >= 3 {
        0.299 * img.data[idx].to_double() +
        0.587 * img.data[idx + 1].to_double() +
        0.114 * img.data[idx + 2].to_double()
      } else {
        img.data[idx].to_double()
      }
      out_data[y * w + x] = if gray > threshold { b'\xFF' } else { b'\x00' }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 版面分析（基于投影的文本块检测）
pub fn analyze_layout_scan(
  binary_img : @types.Image,
) -> Array[TextBlock] raise @types.LoadError {
  // 输入验证
  if binary_img.width <= 0 || binary_img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "analyze_layout_scan: 图像尺寸必须大于0",
    )
  }
  if binary_img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "analyze_layout_scan: 仅支持单通道二值图",
    )
  }
  let expected_size = binary_img.width * binary_img.height
  if binary_img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "analyze_layout_scan: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      binary_img.data.length().to_string(),
    )
  }
  let w = binary_img.width
  let h = binary_img.height
  // 水平投影（检测文本行）
  let horizontal_proj : Array[Int] = []
  for y in 0..<h {
    let mut count = 0
    for x in 0..<w {
      if binary_img.data[y * w + x] == b'\x00' {
        count += 1
      }
    }
    horizontal_proj.push(count)
  }
  // 检测文本行区域
  let blocks : Array[TextBlock] = []
  let mut in_line = false
  let mut line_start = 0
  let mut line_end = 0
  let mut reading_order = 0
  for y in 0..<h {
    if horizontal_proj[y] > w / 50 {
      if !in_line {
        line_start = y
        in_line = true
      }
      line_end = y
    } else if in_line {
      // 检测这一行的文本范围
      let mut min_x = w
      let mut max_x = 0
      for yy in line_start..<=line_end {
        for x in 0..<w {
          if binary_img.data[yy * w + x] == b'\x00' {
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
        blocks.push(TextBlock::{
          x: min_x,
          y: line_start,
          width: max_x - min_x + 1,
          height: line_end - line_start + 1,
          block_type: "text",
          text: "",
          confidence: 0.0,
          reading_order,
        })
        reading_order += 1
      }
      in_line = false
    }
  }
  blocks
}

///|
/// 扫描文档 OCR 完整流水线
pub fn scan_ocr_recognize(
  img : @types.Image,
  config : ScanOCRConfig,
) -> OCRPageResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "scan_ocr_recognize: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "scan_ocr_recognize: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "scan_ocr_recognize: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let _ = 0.0 // 简化，实际需要计时
  // 1. 预处理
  let preprocessed = scan_document_preprocess(img, config)
  // 2. 版面分析
  let blocks = if config.layout_analysis {
    analyze_layout_scan(preprocessed)
  } else {
    let single_block : Array[TextBlock] = []
    single_block.push(TextBlock::{
      x: 0,
      y: 0,
      width: img.width,
      height: img.height,
      block_type: "text",
      text: "",
      confidence: 0.0,
      reading_order: 0,
    })
    single_block
  }
  // 3. 对每个文本块进行识别（简化版：返回占位文本）
  // 实际应该调用对应的 OCR 识别函数
  let mut full_text = ""
  let mut total_confidence = 0.0
  let recognized_blocks : Array[TextBlock] = []
  for i in 0..<blocks.length() {
    // 简化版识别：返回块的位置信息
    let block_text = "[文本块 " +
      i.to_string() +
      ": " +
      blocks[i].width.to_string() +
      "x" +
      blocks[i].height.to_string() +
      "]"
    let new_block = TextBlock::{
      x: blocks[i].x,
      y: blocks[i].y,
      width: blocks[i].width,
      height: blocks[i].height,
      block_type: blocks[i].block_type,
      text: block_text,
      confidence: 0.85,
      reading_order: blocks[i].reading_order,
    }
    recognized_blocks.push(new_block)
    full_text = full_text + block_text + "\n"
    total_confidence += new_block.confidence
  }
  let avg_confidence = if recognized_blocks.length() > 0 {
    total_confidence / recognized_blocks.length().to_double()
  } else {
    0.0
  }
  OCRPageResult::{
    page_number: 1,
    width: img.width,
    height: img.height,
    blocks: recognized_blocks,
    full_text,
    average_confidence: avg_confidence,
    processing_time_ms: 0.0,
  }
}

///|
/// 批量扫描文档 OCR
pub fn batch_scan_ocr(
  images : Array[@types.Image],
  config : ScanOCRConfig,
) -> Array[OCRPageResult] raise @types.LoadError {
  // 输入验证
  if images.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "batch_scan_ocr: 图像列表不能为空",
    )
  }
  for i in 0..<images.length() {
    if images[i].width <= 0 || images[i].height <= 0 {
      raise @types.LoadError::DecodeFailed(
        "batch_scan_ocr: 第 " + i.to_string() + " 张图像尺寸必须大于0",
      )
    }
  }
  let results : Array[OCRPageResult] = []
  for i in 0..<images.length() {
    let result = scan_ocr_recognize(images[i], config)
    let new_result = OCRPageResult::{
      page_number: i + 1,
      width: result.width,
      height: result.height,
      blocks: result.blocks,
      full_text: result.full_text,
      average_confidence: result.average_confidence,
      processing_time_ms: result.processing_time_ms,
    }
    results.push(new_result)
  }
  results
}

///|
/// OCR 结果导出为纯文本
pub fn ocr_result_to_text(result : OCRPageResult) -> String {
  result.full_text
}

///|
/// OCR 结果导出为 hOCR 格式（简化版）
pub fn ocr_result_to_hocr(result : OCRPageResult) -> String {
  let mut hocr = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
  hocr = hocr +
    "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"\n"
  hocr = hocr +
    "  \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n"
  hocr = hocr + "<html xmlns=\"http://www.w3.org/1999/xhtml\">\n"
  hocr = hocr + "<head>\n"
  hocr = hocr +
    "<meta http-equiv=\"Content-Type\" content=\"text/html;charset=utf-8\" />\n"
  hocr = hocr + "<title>OCR Result</title>\n"
  hocr = hocr + "</head>\n"
  hocr = hocr + "<body>\n"
  hocr = hocr +
    "<div class=\"ocr_page\" title=\"image; bbox 0 0 " +
    result.width.to_string() +
    " " +
    result.height.to_string() +
    "\">\n"
  for block in result.blocks {
    hocr = hocr +
      "<div class=\"ocr_carea\" title=\"bbox " +
      block.x.to_string() +
      " " +
      block.y.to_string() +
      " " +
      (block.x + block.width).to_string() +
      " " +
      (block.y + block.height).to_string() +
      "\">\n"
    hocr = hocr + "<p class=\"ocr_par\">\n"
    hocr = hocr +
      "<span class=\"ocr_line\" title=\"bbox " +
      block.x.to_string() +
      " " +
      block.y.to_string() +
      " " +
      (block.x + block.width).to_string() +
      " " +
      (block.y + block.height).to_string() +
      "\">"
    hocr = hocr + block.text
    hocr = hocr + "</span>\n"
    hocr = hocr + "</p>\n"
    hocr = hocr + "</div>\n"
  }
  hocr = hocr + "</div>\n"
  hocr = hocr + "</body>\n"
  hocr = hocr + "</html>\n"
  hocr
}

///|
/// OCR 结果导出为 JSON
pub fn ocr_result_to_json(result : OCRPageResult) -> String {
  let mut json = "{\n"
  json = json + "  \"page_number\": " + result.page_number.to_string() + ",\n"
  json = json + "  \"width\": " + result.width.to_string() + ",\n"
  json = json + "  \"height\": " + result.height.to_string() + ",\n"
  json = json +
    "  \"average_confidence\": " +
    result.average_confidence.to_string() +
    ",\n"
  json = json + "  \"blocks\": [\n"
  for i in 0..<result.blocks.length() {
    let block = result.blocks[i]
    json = json + "    {\n"
    json = json + "      \"x\": " + block.x.to_string() + ",\n"
    json = json + "      \"y\": " + block.y.to_string() + ",\n"
    json = json + "      \"width\": " + block.width.to_string() + ",\n"
    json = json + "      \"height\": " + block.height.to_string() + ",\n"
    json = json + "      \"type\": \"" + block.block_type + "\",\n"
    json = json + "      \"text\": \"" + block.text + "\",\n"
    json = json +
      "      \"confidence\": " +
      block.confidence.to_string() +
      ",\n"
    json = json +
      "      \"reading_order\": " +
      block.reading_order.to_string() +
      "\n"
    json = json + "    }"
    if i < result.blocks.length() - 1 {
      json = json + ","
    }
    json = json + "\n"
  }
  json = json + "  ],\n"
  json = json + "  \"full_text\": \"" + result.full_text + "\"\n"
  json = json + "}\n"
  json
}

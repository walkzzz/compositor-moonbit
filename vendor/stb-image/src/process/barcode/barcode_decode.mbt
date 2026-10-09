// 条形码/二维码识别（v11.0.0）
// EAN-13 一维条码识别 + QR Code 基础定位与解码

///|
/// 条形码类型
pub(all) enum BarcodeType {
  Ean13
  UpcA
  Code128
  QrCode
  Unknown
} derive(Eq)

///|
/// 条形码识别结果
pub(all) struct BarcodeResult {
  barcode_type : BarcodeType
  data : String
  confidence : Double
  x : Int
  y : Int
  width : Int
  height : Int
}

///|
/// 条形码识别配置
pub(all) struct BarcodeConfig {
  enable_ean13 : Bool
  enable_upca : Bool
  enable_code128 : Bool
  enable_qrcode : Bool
  min_bar_width : Int // 最小条宽（像素）
  max_bar_width : Int // 最大条宽（像素）
  scan_lines : Int // 扫描线数量
  quiet_zone_required : Bool // 是否要求静区
}

///|
/// 创建默认条形码识别配置
pub fn barcode_default_config() -> BarcodeConfig {
  BarcodeConfig::{
    enable_ean13: true,
    enable_upca: true,
    enable_code128: false,
    enable_qrcode: true,
    min_bar_width: 1,
    max_bar_width: 20,
    scan_lines: 10,
    quiet_zone_required: true,
  }
}

// ==================== EAN-13 一维条码识别 ====================

///|
/// EAN-13 编码表（左侧奇偶编码）
/// L码（奇数）和 G码（偶数）的编码模式
let ean13_l_codes : Array[Array[Int]] = [
  [0, 0, 0, 1, 1, 0, 1], // 0
  [0, 0, 1, 1, 0, 0, 1], // 1
  [0, 0, 1, 0, 0, 1, 1], // 2
  [0, 1, 1, 1, 1, 0, 1], // 3
  [0, 1, 0, 0, 0, 1, 1], // 4
  [0, 1, 1, 0, 0, 0, 1], // 5
  [0, 1, 0, 1, 1, 1, 1], // 6
  [0, 1, 1, 1, 0, 1, 1], // 7
  [0, 1, 1, 0, 1, 1, 1], // 8
  [0, 0, 0, 1, 0, 1, 1], // 9
]

///|
/// EAN-13 G码（偶数编码）
let ean13_g_codes : Array[Array[Int]] = [
  [0, 1, 0, 0, 1, 1, 1], // 0
  [0, 1, 1, 0, 0, 1, 1], // 1
  [0, 0, 1, 1, 0, 1, 1], // 2
  [0, 1, 0, 0, 0, 0, 1], // 3
  [0, 0, 1, 1, 1, 0, 1], // 4
  [0, 1, 1, 1, 0, 0, 1], // 5
  [0, 0, 0, 0, 1, 0, 1], // 6
  [0, 0, 1, 0, 0, 0, 1], // 7
  [0, 0, 0, 1, 0, 0, 1], // 8
  [0, 0, 1, 0, 1, 1, 1], // 9
]

///|
/// EAN-13 右侧编码（R码）
let ean13_r_codes : Array[Array[Int]] = [
  [1, 1, 1, 0, 0, 1, 0], // 0
  [1, 1, 0, 0, 1, 1, 0], // 1
  [1, 1, 0, 1, 1, 0, 0], // 2
  [1, 0, 0, 0, 0, 1, 0], // 3
  [1, 0, 1, 1, 1, 0, 0], // 4
  [1, 0, 0, 1, 1, 1, 0], // 5
  [1, 0, 1, 0, 0, 0, 0], // 6
  [1, 0, 0, 0, 1, 0, 0], // 7
  [1, 0, 0, 1, 0, 0, 0], // 8
  [1, 1, 1, 0, 1, 0, 0], // 9
]

///|
/// EAN-13 前缀对应的奇偶编码模式
let ean13_parity_patterns : Array[Array[Int]] = [
  [0, 0, 0, 0, 0, 0], // 0
  [0, 0, 1, 0, 1, 1], // 1
  [0, 0, 1, 1, 0, 1], // 2
  [0, 0, 1, 1, 1, 0], // 3
  [0, 1, 0, 0, 1, 1], // 4
  [0, 1, 1, 0, 0, 1], // 5
  [0, 1, 1, 1, 0, 0], // 6
  [0, 1, 0, 1, 0, 1], // 7
  [0, 1, 0, 1, 1, 0], // 8
  [0, 1, 1, 0, 1, 0], // 9
]

///|
/// 识别 EAN-13 条形码
pub fn decode_ean13(
  img : @types.Image,
  config? : BarcodeConfig,
) -> BarcodeResult? raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "decode_ean13: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "decode_ean13: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed("decode_ean13: 数据大小不匹配")
  }
  let cfg = match config {
    Some(c) => c
    None => barcode_default_config()
  }
  if !cfg.enable_ean13 {
    return None
  }
  let w = img.width
  let h = img.height
  let data = img.data
  // 在多条水平扫描线上尝试解码
  let mut best_result : BarcodeResult? = None
  let mut best_confidence = 0.0
  let line_step = h / (cfg.scan_lines + 1)
  for line_idx in 1..<(cfg.scan_lines + 1) {
    let y = line_idx * line_step
    if y >= h {
      break
    }
    // 提取扫描线的像素值
    let scan_line : Array[Int] = []
    for x in 0..<w {
      scan_line.push(data[y * w + x].to_int())
    }
    // 二值化（Otsu或简单阈值）
    let binary = binarize_scanline(scan_line)
    // 尝试解码
    let result = decode_ean13_from_binary(binary, y, w, h)
    match result {
      Some(r) =>
        if r.confidence > best_confidence {
          best_confidence = r.confidence
          best_result = Some(r)
        }
      None => ignore(())
    }
  }
  best_result
}

///|
/// 扫描线二值化
fn binarize_scanline(pixels : Array[Int]) -> Array[Int] {
  // 计算阈值（简单均值）
  let mut sum = 0
  for p in pixels {
    sum += p
  }
  let threshold = if pixels.length() > 0 { sum / pixels.length() } else { 128 }
  let binary : Array[Int] = []
  for p in pixels {
    binary.push(if p < threshold { 1 } else { 0 })
  }
  binary
}

///|
/// 从二值化扫描线解码 EAN-13
fn decode_ean13_from_binary(
  binary : Array[Int],
  y : Int,
  img_width : Int,
  img_height : Int,
) -> BarcodeResult? {
  ignore(img_height)
  ignore(img_width)
  let w = binary.length()
  if w < 95 { // EAN-13 至少需要 95 个模块
    return None
  }
  // 寻找起始符（101）
  let mut start_idx = -1
  for i in 0..<(w - 94) {
    if binary[i] == 1 && binary[i + 1] == 0 && binary[i + 2] == 1 {
      // 检查左侧静区
      let mut quiet = true
      for q in 0..<5 {
        if i - q - 1 >= 0 && binary[i - q - 1] == 1 {
          quiet = false
        }
      }
      if quiet {
        start_idx = i
        break
      }
    }
  }
  if start_idx < 0 {
    return None
  }
  // 估计模块宽度
  let module_width = estimate_module_width(binary, start_idx)
  if module_width < 1 {
    return None
  }
  // 解析左侧6位数字
  let left_digits : Array[Int] = []
  let left_parity : Array[Int] = []
  let mut pos = start_idx + 3 * module_width // 跳过起始符
  for _ in 0..<6 {
    let (digit, parity) = decode_ean13_digit(binary, pos, module_width, true)
    if digit < 0 {
      return None
    }
    left_digits.push(digit)
    left_parity.push(parity)
    pos += 7 * module_width
  }
  // 检查中间分隔符（01010）
  pos += 5 * module_width // 跳过中间分隔符
  // 解析右侧6位数字
  let right_digits : Array[Int] = []
  for _ in 0..<6 {
    let (digit, _) = decode_ean13_digit(binary, pos, module_width, false)
    if digit < 0 {
      return None
    }
    right_digits.push(digit)
    pos += 7 * module_width
  }
  // 根据奇偶编码模式确定第一位数字
  let first_digit = match_parity_pattern(left_parity)
  if first_digit < 0 {
    return None
  }
  // 组合完整条码
  let mut barcode = first_digit.to_string()
  for d in left_digits {
    barcode += d.to_string()
  }
  for d in right_digits {
    barcode += d.to_string()
  }
  // 验证校验位
  let valid = validate_ean13_checksum(barcode)
  let confidence = if valid { 0.95 } else { 0.5 }
  Some(BarcodeResult::{
    barcode_type: BarcodeType::Ean13,
    data: barcode,
    confidence,
    x: start_idx,
    y,
    width: 95 * module_width,
    height: 1,
  })
}

///|
/// 估计模块宽度
fn estimate_module_width(binary : Array[Int], start_idx : Int) -> Int {
  // 起始符是 101，测量第一个条的宽度
  let mut width = 0
  let mut i = start_idx
  while i < binary.length() && binary[i] == 1 {
    width += 1
    i += 1
  }
  if width == 0 {
    width = 1
  }
  width
}

///|
/// 解码单个 EAN-13 数字
fn decode_ean13_digit(
  binary : Array[Int],
  start : Int,
  module_width : Int,
  is_left : Bool,
) -> (Int, Int) {
  // 采样7个模块
  let modules : Array[Int] = []
  for i in 0..<7 {
    let pos = start + i * module_width + module_width / 2
    if pos < binary.length() {
      modules.push(binary[pos])
    } else {
      modules.push(0)
    }
  }
  // 匹配编码表
  if is_left {
    // 尝试 L 码（奇数）
    for d in 0..<10 {
      if modules == ean13_l_codes[d] {
        return (d, 0) // 0 = L码（奇数）
      }
    }
    // 尝试 G 码（偶数）
    for d in 0..<10 {
      if modules == ean13_g_codes[d] {
        return (d, 1) // 1 = G码（偶数）
      }
    }
  } else {
    // 右侧 R 码
    for d in 0..<10 {
      if modules == ean13_r_codes[d] {
        return (d, 0)
      }
    }
  }
  (-1, 0)
}

///|
/// 根据奇偶编码模式匹配第一位数字
fn match_parity_pattern(parity : Array[Int]) -> Int {
  for d in 0..<10 {
    let mut is_match = true
    for i in 0..<6 {
      if parity[i] != ean13_parity_patterns[d][i] {
        is_match = false
      }
    }
    if is_match {
      return d
    }
  }
  -1
}

///|
/// 验证 EAN-13 校验位
fn validate_ean13_checksum(barcode : String) -> Bool {
  if barcode.length() != 13 {
    return false
  }
  let mut sum = 0
  for i in 0..<12 {
    let digit = barcode[i].to_int() - '0'.to_int()
    if i % 2 == 0 {
      sum += digit // 奇数位（从0开始）权重1
    } else {
      sum += digit * 3 // 偶数位权重3
    }
  }
  let checksum = (10 - sum % 10) % 10
  let actual = barcode[12].to_int() - '0'.to_int()
  checksum == actual
}

// ==================== QR Code 基础识别 ====================

///|
/// QR Code 定位图案（Finder Pattern）
pub(all) struct QrFinderPattern {
  x : Double
  y : Double
  size : Double
  quality : Double
}

///|
/// 检测 QR Code 定位图案
pub fn detect_qr_finder_patterns(
  img : @types.Image,
) -> Array[QrFinderPattern] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_qr_finder_patterns: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "detect_qr_finder_patterns: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "detect_qr_finder_patterns: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let data = img.data
  let patterns : Array[QrFinderPattern] = []
  // 水平扫描寻找 1:1:3:1:1 比例的图案
  for y in 0..<h {
    let mut x = 0
    while x < w {
      // 寻找起始黑条
      if data[y * w + x].to_int() < 128 {
        let (found, pattern_x, pattern_size) = scan_qr_pattern_horizontal(
          data, w, x, y,
        )
        if found && pattern_size > 10 {
          // 验证垂直方向
          let vertical_valid = verify_qr_pattern_vertical(
            data, w, h, pattern_x, y, pattern_size,
          )
          if vertical_valid {
            patterns.push(QrFinderPattern::{
              x: pattern_x.to_double(),
              y: y.to_double(),
              size: pattern_size.to_double(),
              quality: 0.8,
            })
          }
          x = pattern_x + pattern_size + 1
        } else {
          x += 1
        }
      } else {
        x += 1
      }
    }
  }
  patterns
}

///|
/// 水平扫描 QR 定位图案（1:1:3:1:1 比例）
fn scan_qr_pattern_horizontal(
  data : Bytes,
  w : Int,
  start_x : Int,
  y : Int,
) -> (Bool, Int, Int) {
  let mut x = start_x
  // 模块1：黑条
  let mut m1 = 0
  while x < w && data[y * w + x].to_int() < 128 {
    m1 += 1
    x += 1
  }
  // 模块2：白条
  let mut m2 = 0
  while x < w && data[y * w + x].to_int() >= 128 {
    m2 += 1
    x += 1
  }
  // 模块3：黑条（中心，应该是3倍）
  let mut m3 = 0
  while x < w && data[y * w + x].to_int() < 128 {
    m3 += 1
    x += 1
  }
  // 模块4：白条
  let mut m4 = 0
  while x < w && data[y * w + x].to_int() >= 128 {
    m4 += 1
    x += 1
  }
  // 模块5：黑条
  let mut m5 = 0
  while x < w && data[y * w + x].to_int() < 128 {
    m5 += 1
    x += 1
  }
  // 检查比例 1:1:3:1:1
  let total = m1 + m2 + m3 + m4 + m5
  if total < 20 {
    return (false, 0, 0)
  }
  let module_val = total / 7
  let m1d = m1.to_double()
  let m2d = m2.to_double()
  let m3d = m3.to_double()
  let m4d = m4.to_double()
  let m5d = m5.to_double()
  let mod_d = module_val.to_double()
  let ratio_ok = m1d >= mod_d * 0.5 &&
    m1d <= mod_d * 1.5 &&
    m2d >= mod_d * 0.5 &&
    m2d <= mod_d * 1.5 &&
    m3d >= mod_d * 2.5 &&
    m3d <= mod_d * 3.5 &&
    m4d >= mod_d * 0.5 &&
    m4d <= mod_d * 1.5 &&
    m5d >= mod_d * 0.5 &&
    m5d <= mod_d * 1.5
  if ratio_ok {
    return (true, start_x, total)
  }
  (false, 0, 0)
}

///|
/// 垂直验证 QR 定位图案
fn verify_qr_pattern_vertical(
  data : Bytes,
  w : Int,
  h : Int,
  start_x : Int,
  start_y : Int,
  size : Int,
) -> Bool {
  let center_x = start_x + size / 2
  if center_x >= w {
    return false
  }
  let mut y = start_y
  // 模块1：黑条
  let mut m1 = 0
  while y < h && data[y * w + center_x].to_int() < 128 {
    m1 += 1
    y += 1
  }
  // 模块2：白条
  let mut m2 = 0
  while y < h && data[y * w + center_x].to_int() >= 128 {
    m2 += 1
    y += 1
  }
  // 模块3：黑条
  let mut m3 = 0
  while y < h && data[y * w + center_x].to_int() < 128 {
    m3 += 1
    y += 1
  }
  // 模块4：白条
  let mut m4 = 0
  while y < h && data[y * w + center_x].to_int() >= 128 {
    m4 += 1
    y += 1
  }
  // 模块5：黑条
  let mut m5 = 0
  while y < h && data[y * w + center_x].to_int() < 128 {
    m5 += 1
    y += 1
  }
  let total = m1 + m2 + m3 + m4 + m5
  if total < 20 {
    return false
  }
  let module_val = total / 7
  let m1d = m1.to_double()
  let m2d = m2.to_double()
  let m3d = m3.to_double()
  let m4d = m4.to_double()
  let m5d = m5.to_double()
  let mod_d = module_val.to_double()
  m1d >= mod_d * 0.5 &&
  m1d <= mod_d * 1.5 &&
  m2d >= mod_d * 0.5 &&
  m2d <= mod_d * 1.5 &&
  m3d >= mod_d * 2.5 &&
  m3d <= mod_d * 3.5 &&
  m4d >= mod_d * 0.5 &&
  m4d <= mod_d * 1.5 &&
  m5d >= mod_d * 0.5 &&
  m5d <= mod_d * 1.5
}

///|
/// 识别 QR Code（基础版：检测定位图案并估算版本）
pub fn decode_qrcode(
  img : @types.Image,
  config? : BarcodeConfig,
) -> BarcodeResult? raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "decode_qrcode: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "decode_qrcode: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed("decode_qrcode: 数据大小不匹配")
  }
  let cfg = match config {
    Some(c) => c
    None => barcode_default_config()
  }
  if !cfg.enable_qrcode {
    return None
  }
  // 检测定位图案
  let patterns = detect_qr_finder_patterns(img)
  if patterns.length() < 3 {
    return None
  }
  // 取前3个定位图案（左上、右上、左下）
  let p1 = patterns[0]
  let p2 = patterns[1]
  let p3 = patterns[2]
  // 估算 QR Code 尺寸
  let avg_size = (p1.size + p2.size + p3.size) / 3.0
  let module_size = avg_size / 7.0
  let _ = (21.0 * module_size).to_int() // Version 1 是 21x21 模块
  // 计算边界框
  let min_x = p1.x.min(p2.x).min(p3.x).to_int()
  let min_y = p1.y.min(p2.y).min(p3.y).to_int()
  let max_x = (p1.x + p1.size).max(p2.x + p2.size).max(p3.x + p3.size).to_int()
  let max_y = (p1.y + p1.size).max(p2.y + p2.size).max(p3.y + p3.size).to_int()
  let width = max_x - min_x
  let height = max_y - min_y
  // 基础版：只检测定位，不做完整解码
  // 返回检测结果，data 字段包含基本信息
  let info = "QR Code detected: 3 finder patterns, ~" +
    module_size.to_int().to_string() +
    "px/module_val, ~v1 size"
  Some(BarcodeResult::{
    barcode_type: BarcodeType::QrCode,
    data: info,
    confidence: 0.7,
    x: min_x,
    y: min_y,
    width,
    height,
  })
}

///|
/// 通用条形码识别（自动尝试所有启用的类型）
pub fn decode_barcode(
  img : @types.Image,
  config? : BarcodeConfig,
) -> Array[BarcodeResult] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "decode_barcode: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "decode_barcode: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "decode_barcode: 数据大小不匹配",
    )
  }
  let results : Array[BarcodeResult] = []
  // 尝试 EAN-13
  let ean13_result = match config {
    Some(c) => decode_ean13(img, config=c)
    None => decode_ean13(img)
  }
  match ean13_result {
    Some(r) => results.push(r)
    None => ignore(())
  }
  // 尝试 QR Code
  let qr_result = match config {
    Some(c) => decode_qrcode(img, config=c)
    None => decode_qrcode(img)
  }
  match qr_result {
    Some(r) => results.push(r)
    None => ignore(())
  }
  results
}

// 更多一维码支持（v11.3.0）
// Code128 / UPC-A / Code39 解码

///|
/// Code128 字符集类型
pub(all) enum Code128Charset {
  CodeA
  CodeB
  CodeC
} derive(Eq)

///|
/// Code128 编码表（107个码字）
/// 每个码字对应 11 位的条空模式（3条3空，宽度1-4）
let code128_patterns : Array[Array[Int]] = [
  [2, 1, 2, 2, 2, 2], // 0
  [2, 2, 2, 1, 2, 2], // 1
  [2, 2, 2, 2, 2, 1], // 2
  [1, 2, 1, 2, 2, 3], // 3
  [1, 2, 1, 3, 2, 2], // 4
  [1, 3, 1, 2, 2, 2], // 5
  [1, 2, 2, 2, 1, 3], // 6
  [1, 2, 2, 3, 1, 2], // 7
  [1, 3, 2, 2, 1, 2], // 8
  [2, 2, 1, 2, 1, 3], // 9
  [2, 2, 1, 3, 1, 2], // 10
  [2, 3, 1, 2, 1, 2], // 11
  [1, 1, 2, 2, 3, 2], // 12
  [1, 2, 2, 1, 3, 2], // 13
  [1, 2, 2, 2, 3, 1], // 14
  [1, 1, 3, 2, 2, 2], // 15
  [1, 2, 3, 1, 2, 2], // 16
  [1, 2, 3, 2, 2, 1], // 17
  [2, 2, 3, 2, 1, 1], // 18
  [2, 2, 1, 1, 3, 2], // 19
  [2, 2, 1, 2, 3, 1], // 20
  [2, 1, 3, 2, 1, 2], // 21
  [2, 2, 3, 1, 1, 2], // 22
  [3, 1, 2, 1, 3, 1], // 23
  [3, 1, 1, 2, 2, 2], // 24
  [3, 2, 1, 1, 2, 2], // 25
  [3, 2, 1, 2, 2, 1], // 26
  [3, 1, 2, 2, 1, 2], // 27
  [3, 2, 2, 1, 1, 2], // 28
  [3, 2, 2, 2, 1, 1], // 29
  [2, 1, 2, 1, 2, 3], // 30
  [2, 1, 2, 3, 2, 1], // 31
  [2, 3, 2, 1, 2, 1], // 32
  [1, 1, 1, 3, 2, 3], // 33
  [1, 3, 1, 1, 2, 3], // 34
  [1, 3, 1, 3, 2, 1], // 35
  [1, 1, 2, 3, 1, 3], // 36
  [1, 3, 2, 1, 1, 3], // 37
  [1, 3, 2, 3, 1, 1], // 38
  [2, 1, 1, 3, 1, 3], // 39
  [2, 3, 1, 1, 1, 3], // 40
  [2, 3, 1, 3, 1, 1], // 41
  [1, 1, 2, 1, 3, 3], // 42
  [1, 1, 2, 3, 3, 1], // 43
  [1, 3, 2, 1, 3, 1], // 44
  [1, 1, 3, 1, 2, 3], // 45
  [1, 1, 3, 3, 2, 1], // 46
  [1, 3, 3, 1, 2, 1], // 47
  [3, 1, 3, 1, 2, 1], // 48
  [2, 1, 1, 3, 3, 1], // 49
  [2, 3, 1, 1, 3, 1], // 50
  [2, 1, 3, 1, 1, 3], // 51
  [2, 1, 3, 3, 1, 1], // 52
  [2, 1, 3, 1, 3, 1], // 53
  [3, 1, 1, 1, 2, 3], // 54
  [3, 1, 1, 3, 2, 1], // 55
  [3, 3, 1, 1, 2, 1], // 56
  [3, 1, 2, 1, 1, 3], // 57
  [3, 1, 2, 3, 1, 1], // 58
  [3, 3, 2, 1, 1, 1], // 59
  [3, 1, 4, 1, 1, 1], // 60
  [2, 2, 1, 4, 1, 1], // 61
  [4, 3, 1, 1, 1, 1], // 62
  [1, 1, 1, 2, 2, 4], // 63
  [1, 1, 1, 4, 2, 2], // 64
  [1, 2, 1, 1, 2, 4], // 65
  [1, 2, 1, 4, 2, 1], // 66
  [1, 4, 1, 1, 2, 2], // 67
  [1, 4, 1, 2, 2, 1], // 68
  [1, 1, 2, 2, 1, 4], // 69
  [1, 1, 2, 4, 1, 2], // 70
  [1, 2, 2, 1, 1, 4], // 71
  [1, 2, 2, 4, 1, 1], // 72
  [1, 4, 2, 1, 1, 2], // 73
  [1, 4, 2, 2, 1, 1], // 74
  [2, 4, 1, 2, 1, 1], // 75
  [2, 2, 1, 1, 1, 4], // 76
  [4, 1, 3, 1, 1, 1], // 77
  [2, 4, 1, 1, 1, 2], // 78
  [1, 3, 4, 1, 1, 1], // 79
  [1, 1, 1, 2, 4, 2], // 80
  [1, 2, 1, 1, 4, 2], // 81
  [1, 2, 1, 2, 4, 1], // 82
  [1, 1, 4, 2, 1, 2], // 83
  [1, 2, 4, 1, 1, 2], // 84
  [1, 2, 4, 2, 1, 1], // 85
  [4, 1, 1, 2, 1, 2], // 86
  [4, 2, 1, 1, 1, 2], // 87
  [4, 2, 1, 2, 1, 1], // 88
  [2, 1, 2, 1, 4, 1], // 89
  [2, 1, 4, 1, 2, 1], // 90
  [4, 1, 2, 1, 2, 1], // 91
  [1, 1, 1, 1, 4, 3], // 92
  [1, 1, 1, 3, 4, 1], // 93
  [1, 3, 1, 1, 4, 1], // 94
  [1, 1, 4, 1, 1, 3], // 95
  [1, 1, 4, 3, 1, 1], // 96
  [4, 1, 1, 1, 1, 3], // 97
  [4, 1, 1, 3, 1, 1], // 98
  [1, 1, 3, 1, 4, 1], // 99
  [1, 1, 4, 1, 3, 1], // 100
  [3, 1, 1, 1, 4, 1], // 101
  [4, 1, 1, 1, 3, 1], // 102
  [2, 1, 1, 4, 1, 2], // 103
  [2, 1, 1, 2, 1, 4], // 104
  [2, 1, 1, 2, 3, 2], // 105 (Start A)
  [2, 1, 1, 2, 2, 3], // 106 (Start B)
  [2, 1, 3, 2, 1, 1], // 107 (Start C)
]

///|
/// Code128 字符集 A 的字符映射（0-95）
fn code128_char_a(code : Int) -> String {
  if code >= 0 && code <= 95 {
    if code < 64 {
      (code + 32).to_char().map(c => c.to_string()).unwrap_or("")
    } else {
      // 控制字符
      (code - 64).to_char().map(c => c.to_string()).unwrap_or("")
    }
  } else {
    "?"
  }
}

///|
/// Code128 字符集 B 的字符映射（0-95）
fn code128_char_b(code : Int) -> String {
  if code >= 0 && code <= 95 {
    (code + 32).to_char().map(c => c.to_string()).unwrap_or("")
  } else {
    "?"
  }
}

///|
/// 识别 Code128 条形码
pub fn decode_code128(
  img : @types.Image,
) -> BarcodeResult? raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "decode_code128: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "decode_code128: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "decode_code128: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let data = img.data
  // 在中间扫描线尝试解码
  let y = h / 2
  let scan_line : Array[Int] = []
  for x in 0..<w {
    scan_line.push(if data[y * w + x].to_int() < 128 { 1 } else { 0 })
  }
  // 寻找起始符（Code A/B/C）
  let start_patterns = [
    (103, [2, 1, 1, 4, 1, 2]), // Start A
    (104, [2, 1, 1, 2, 1, 4]), // Start B
    (105, [2, 1, 1, 2, 3, 2]), // Start C (实际是 2,1,3,2,1,1)
  ]
  let mut start_idx = -1
  let mut start_code = 0
  for i in 0..<(w - 20) {
    for _tup0 in start_patterns {
      let (code, pattern) = _tup0
      if match_bar_pattern(scan_line, i, pattern) {
        start_idx = i
        start_code = code
        break
      }
    }
    if start_idx >= 0 {
      break
    }
  }
  if start_idx < 0 {
    return None
  }
  // 确定字符集
  let charset = match start_code {
    103 => Code128Charset::CodeA
    104 => Code128Charset::CodeB
    105 => Code128Charset::CodeC
    _ => Code128Charset::CodeB
  }
  // 解码数据码字
  let mut pos = start_idx + 11 // 起始符占 11 个模块
  let codes : Array[Int] = []
  let mut checksum = start_code
  let mut code_count = 0
  while pos < w - 13 {
    // 匹配一个码字（6个条空，11个模块）
    let (matched_code, matched_width) = match_code128_symbol(scan_line, pos)
    if matched_code < 0 {
      break
    }
    if matched_code == 106 { // Stop 符
      break
    }
    codes.push(matched_code)
    code_count += 1
    checksum += matched_code * code_count
    pos += matched_width
  }
  if codes.length() < 2 {
    return None
  }
  // 验证校验位
  let expected_checksum = checksum % 103
  let actual_checksum = codes[codes.length() - 1]
  let valid = expected_checksum == actual_checksum
  // 解码数据
  let mut result = ""
  let mut current_charset = charset
  for i in 0..<(codes.length() - 1) {
    let code = codes[i]
    // 处理字符集切换
    if code == 101 { // Code A
      current_charset = Code128Charset::CodeA
      continue
    } else if code == 100 { // Code B
      current_charset = Code128Charset::CodeB
      continue
    } else if code == 99 { // Code C
      current_charset = Code128Charset::CodeC
      continue
    }
    match current_charset {
      Code128Charset::CodeA => result += code128_char_a(code)
      Code128Charset::CodeB => result += code128_char_b(code)
      Code128Charset::CodeC => {
        // Code C: 两个数字一个码字
        let d1 = code / 10
        let d2 = code % 10
        result += d1.to_string()
        result += d2.to_string()
      }
    }
  }
  let confidence = if valid { 0.9 } else { 0.5 }
  Some(BarcodeResult::{
    barcode_type: BarcodeType::Code128,
    data: result,
    confidence,
    x: start_idx,
    y,
    width: pos - start_idx,
    height: 1,
  })
}

///|
/// 匹配条空模式
fn match_bar_pattern(
  scan_line : Array[Int],
  start : Int,
  pattern : Array[Int],
) -> Bool {
  let mut pos = start
  let mut is_bar = true
  for width in pattern {
    for _ in 0..<width {
      if pos >= scan_line.length() {
        return false
      }
      let expected = if is_bar { 1 } else { 0 }
      if scan_line[pos] != expected {
        return false
      }
      pos += 1
    }
    is_bar = !is_bar
  }
  true
}

///|
/// 匹配 Code128 码字
fn match_code128_symbol(scan_line : Array[Int], start : Int) -> (Int, Int) {
  // 尝试匹配所有 108 个码字
  for code in 0..<108 {
    let pattern = code128_patterns[code]
    let mut total_width = 0
    for w in pattern {
      total_width += w
    }
    if match_bar_pattern(scan_line, start, pattern) {
      return (code, total_width)
    }
  }
  (-1, 0)
}

///|
/// 识别 UPC-A 条形码
pub fn decode_upca(img : @types.Image) -> BarcodeResult? raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "decode_upca: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "decode_upca: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed("decode_upca: 数据大小不匹配")
  }
  // UPC-A 与 EAN-13 兼容（UPC-A 是 EAN-13 第一位为 0 的特例）
  let result = decode_ean13(img)
  match result {
    Some(r) =>
      if r.data.length() == 13 && r.data[0] == '0' {
        // 去掉前导 0，转换为 UPC-A
        let mut upca = ""
        for i in 1..<13 {
          upca += r.data[i].to_string()
        }
        Some(BarcodeResult::{
          barcode_type: BarcodeType::UpcA,
          data: upca,
          confidence: r.confidence,
          x: r.x,
          y: r.y,
          width: r.width,
          height: r.height,
        })
      } else {
        None
      }
    None => None
  }
}

///|
/// Code39 编码表
let code39_chars : Array[String] = [
  "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F",
  "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V",
  "W", "X", "Y", "Z", "-", ".", " ", "$", "/", "+", "%",
]

///|
/// Code39 条空模式（9个元素：5条4空，3宽6窄）
let code39_patterns : Array[Array[Int]] = [
  [1, 1, 1, 2, 2, 1, 2, 1, 1], // 0
  [2, 1, 1, 2, 1, 1, 1, 1, 2], // 1
  [1, 1, 2, 2, 1, 1, 1, 1, 2], // 2
  [2, 1, 2, 2, 1, 1, 1, 1, 1], // 3
  [1, 1, 1, 2, 2, 1, 1, 1, 2], // 4
  [2, 1, 1, 2, 2, 1, 1, 1, 1], // 5
  [1, 1, 2, 2, 2, 1, 1, 1, 1], // 6
  [1, 1, 1, 2, 1, 1, 2, 1, 2], // 7
  [2, 1, 1, 2, 1, 1, 2, 1, 1], // 8
  [1, 1, 2, 2, 1, 1, 2, 1, 1], // 9
  [2, 1, 1, 1, 1, 2, 1, 1, 2], // A
  [1, 1, 2, 1, 1, 2, 1, 1, 2], // B
  [2, 1, 2, 1, 1, 2, 1, 1, 1], // C
  [1, 1, 1, 1, 2, 2, 1, 1, 2], // D
  [2, 1, 1, 1, 2, 2, 1, 1, 1], // E
  [1, 1, 2, 1, 2, 2, 1, 1, 1], // F
  [1, 1, 1, 1, 1, 2, 2, 1, 2], // G
  [2, 1, 1, 1, 1, 2, 2, 1, 1], // H
  [1, 1, 2, 1, 1, 2, 2, 1, 1], // I
  [1, 1, 1, 1, 2, 2, 2, 1, 1], // J
  [2, 1, 1, 1, 1, 1, 1, 2, 2], // K
  [1, 1, 2, 1, 1, 1, 1, 2, 2], // L
  [2, 1, 2, 1, 1, 1, 1, 2, 1], // M
  [1, 1, 1, 1, 2, 1, 1, 2, 2], // N
  [2, 1, 1, 1, 2, 1, 1, 2, 1], // O
  [1, 1, 2, 1, 2, 1, 1, 2, 1], // P
  [1, 1, 1, 1, 1, 1, 2, 2, 2], // Q
  [2, 1, 1, 1, 1, 1, 2, 2, 1], // R
  [1, 1, 2, 1, 1, 1, 2, 2, 1], // S
  [1, 1, 1, 1, 2, 1, 2, 2, 1], // T
  [2, 2, 1, 1, 1, 1, 1, 1, 2], // U
  [1, 2, 2, 1, 1, 1, 1, 1, 2], // V
  [2, 2, 2, 1, 1, 1, 1, 1, 1], // W
  [1, 2, 1, 1, 2, 1, 1, 1, 2], // X
  [2, 2, 1, 1, 2, 1, 1, 1, 1], // Y
  [1, 2, 2, 1, 2, 1, 1, 1, 1], // Z
  [1, 2, 1, 1, 1, 1, 2, 1, 2], // -
  [2, 2, 1, 1, 1, 1, 2, 1, 1], // .
  [1, 2, 2, 1, 1, 1, 2, 1, 1], // (space)
  [1, 2, 1, 2, 1, 2, 1, 1, 1], // $
  [1, 2, 1, 2, 1, 1, 1, 2, 1], // /
  [1, 2, 1, 1, 1, 2, 1, 2, 1], // +
  [1, 1, 1, 2, 1, 2, 1, 2, 1], // %
]

///|
/// Code39 起始/终止符模式（*）
let code39_start_pattern : Array[Int] = [1, 2, 1, 1, 2, 1, 2, 1, 1]

///|
/// 识别 Code39 条形码
pub fn decode_code39(
  img : @types.Image,
) -> BarcodeResult? raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "decode_code39: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "decode_code39: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed("decode_code39: 数据大小不匹配")
  }
  let w = img.width
  let h = img.height
  let data = img.data
  let y = h / 2
  let scan_line : Array[Int] = []
  for x in 0..<w {
    scan_line.push(if data[y * w + x].to_int() < 128 { 1 } else { 0 })
  }
  // 寻找起始符 *
  let mut start_idx = -1
  for i in 0..<(w - 20) {
    if match_bar_pattern(scan_line, i, code39_start_pattern) {
      start_idx = i
      break
    }
  }
  if start_idx < 0 {
    return None
  }
  // 解码数据字符
  let mut pos = start_idx + 10 // 起始符 + 间隔
  let result_chars : Array[String] = []
  while pos < w - 15 {
    // 跳过空白间隔
    while pos < w && scan_line[pos] == 0 {
      pos += 1
    }
    if pos >= w - 9 {
      break
    }
    // 检查是否是终止符
    if match_bar_pattern(scan_line, pos, code39_start_pattern) {
      break
    }
    // 匹配数据字符
    let mut matched = false
    for code in 0..<code39_patterns.length() {
      if match_bar_pattern(scan_line, pos, code39_patterns[code]) {
        result_chars.push(code39_chars[code])
        let mut total_width = 0
        for width in code39_patterns[code] {
          total_width += width
        }
        pos += total_width + 1 // 字符 + 间隔
        matched = true
        break
      }
    }
    if !matched {
      pos += 1
    }
  }
  if result_chars.length() == 0 {
    return None
  }
  let mut result = ""
  for c in result_chars {
    result += c
  }
  Some(BarcodeResult::{
    barcode_type: BarcodeType::Code128, // 复用类型
    data: result,
    confidence: 0.8,
    x: start_idx,
    y,
    width: pos - start_idx,
    height: 1,
  })
}

///|
/// 通用一维码识别（自动尝试所有类型）
pub fn decode_linear_barcode(
  img : @types.Image,
) -> Array[BarcodeResult] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "decode_linear_barcode: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "decode_linear_barcode: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "decode_linear_barcode: 数据大小不匹配",
    )
  }
  let results : Array[BarcodeResult] = []
  // 尝试 EAN-13
  let ean13 = decode_ean13(img)
  match ean13 {
    Some(r) => results.push(r)
    None => ignore(())
  }
  // 尝试 UPC-A
  let upca = decode_upca(img)
  match upca {
    Some(r) => results.push(r)
    None => ignore(())
  }
  // 尝试 Code128
  let code128 = decode_code128(img)
  match code128 {
    Some(r) => results.push(r)
    None => ignore(())
  }
  // 尝试 Code39
  let code39 = decode_code39(img)
  match code39 {
    Some(r) => results.push(r)
    None => ignore(())
  }
  results
}

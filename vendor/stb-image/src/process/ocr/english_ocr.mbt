// 英文 OCR
// 数字+字母识别（0-9, A-Z, a-z）

///|
/// 英文 OCR 配置
pub(all) struct EnglishOcrConfig {
  min_char_width : Int
  max_char_width : Int
  target_size : Int
  distance_metric : String
  case_sensitive : Bool
}

///|
/// 创建默认英文 OCR 配置
pub fn english_ocr_default_config() -> EnglishOcrConfig {
  EnglishOcrConfig::{
    min_char_width: 5,
    max_char_width: 60,
    target_size: 32,
    distance_metric: "euclidean",
    case_sensitive: false,
  }
}

///|
/// 生成英文字符模板（0-9, A-Z）
/// 不区分大小写时只生成大写
pub fn generate_english_templates(
  case_sensitive? : Bool = false,
) -> Array[(String, Array[Double])] {
  let templates : Array[(String, Array[Double])] = []
  // 数字 0-9
  for digit in 0..<10 {
    let template = generate_char_template_simple(digit.to_string())
    templates.push((digit.to_string(), template))
  }
  // 大写字母 A-Z
  for code in 65..<91 {
    let char = code.to_char().map(c => c.to_string()).unwrap_or("")
    let template = generate_char_template_simple(char)
    templates.push((char, template))
  }
  // 如果区分大小写，添加小写字母
  if case_sensitive {
    for code in 97..<123 {
      let char = code.to_char().map(c => c.to_string()).unwrap_or("")
      let template = generate_char_template_simple(char)
      templates.push((char, template))
    }
  }
  templates
}

///|
/// 生成简单字符模板（基于5x7点阵字体）
fn generate_char_template_simple(char : String) -> Array[Double] {
  let size = 8
  let features : Array[Double] = Array::make(size * size, 0.0)
  // 简化的字符模式（基于常见字符形状）
  match char {
    "0" | "O" | "o" => {
      // 圆形：四周有像素，中间空
      set_char_pixels(features, size, 1, 0, 6, 1) // 上
      set_char_pixels(features, size, 0, 1, 1, 6) // 左
      set_char_pixels(features, size, 7, 1, 1, 6) // 右
      set_char_pixels(features, size, 1, 7, 6, 1) // 下
    }
    "1" | "I" | "l" =>
      // 竖线
      set_char_pixels(features, size, 3, 0, 2, 8) // 中竖
    "2" | "Z" | "z" => {
      // Z形：上、对角、下
      set_char_pixels(features, size, 1, 0, 6, 1) // 上
      set_char_pixels(features, size, 5, 1, 1, 1)
      set_char_pixels(features, size, 4, 2, 1, 1)
      set_char_pixels(features, size, 3, 3, 1, 1)
      set_char_pixels(features, size, 2, 4, 1, 1)
      set_char_pixels(features, size, 1, 5, 1, 1)
      set_char_pixels(features, size, 1, 7, 6, 1) // 下
    }
    "3" => {
      // 3形：上、中、下、右
      set_char_pixels(features, size, 1, 0, 6, 1) // 上
      set_char_pixels(features, size, 1, 3, 6, 1) // 中
      set_char_pixels(features, size, 1, 7, 6, 1) // 下
      set_char_pixels(features, size, 6, 0, 1, 8) // 右
    }
    "4" | "A" => {
      // A形：倒V + 横
      set_char_pixels(features, size, 1, 0, 1, 4) // 左上
      set_char_pixels(features, size, 6, 0, 1, 4) // 右上
      set_char_pixels(features, size, 2, 1, 1, 1)
      set_char_pixels(features, size, 5, 1, 1, 1)
      set_char_pixels(features, size, 3, 2, 2, 1) // 顶
      set_char_pixels(features, size, 1, 4, 6, 1) // 中横
    }
    "5" | "S" | "s" => {
      // S形：上、左、中、右、下
      set_char_pixels(features, size, 1, 0, 6, 1) // 上
      set_char_pixels(features, size, 0, 0, 1, 4) // 左上
      set_char_pixels(features, size, 1, 3, 6, 1) // 中
      set_char_pixels(features, size, 7, 4, 1, 4) // 右下
      set_char_pixels(features, size, 1, 7, 6, 1) // 下
    }
    "6" | "b" => {
      // b形：左竖 + 上右 + 下圆
      set_char_pixels(features, size, 0, 0, 1, 8) // 左
      set_char_pixels(features, size, 1, 0, 6, 1) // 上
      set_char_pixels(features, size, 6, 0, 1, 4) // 右上
      set_char_pixels(features, size, 1, 3, 6, 1) // 中
      set_char_pixels(features, size, 6, 4, 1, 4) // 右下
      set_char_pixels(features, size, 1, 7, 6, 1) // 下
    }
    "7" | "T" | "t" => {
      // T形：上横 + 中竖
      set_char_pixels(features, size, 0, 0, 8, 1) // 上
      set_char_pixels(features, size, 3, 1, 2, 7) // 中竖
    }
    "8" | "B" => {
      // B形：左竖 + 双圆
      set_char_pixels(features, size, 0, 0, 1, 8) // 左
      set_char_pixels(features, size, 1, 0, 6, 1) // 上
      set_char_pixels(features, size, 6, 0, 1, 4) // 右上
      set_char_pixels(features, size, 1, 3, 6, 1) // 中
      set_char_pixels(features, size, 6, 4, 1, 4) // 右下
      set_char_pixels(features, size, 1, 7, 6, 1) // 下
    }
    "9" | "g" | "q" => {
      // g形：上圆 + 下左 + 尾
      set_char_pixels(features, size, 1, 0, 6, 1) // 上
      set_char_pixels(features, size, 0, 0, 1, 4) // 左上
      set_char_pixels(features, size, 6, 0, 1, 4) // 右上
      set_char_pixels(features, size, 1, 3, 6, 1) // 中
      set_char_pixels(features, size, 0, 4, 1, 4) // 左下
      set_char_pixels(features, size, 1, 7, 6, 1) // 下
      set_char_pixels(features, size, 6, 6, 1, 2) // 尾
    }
    "C" | "c" | "(" => {
      // C形：上、左、下
      set_char_pixels(features, size, 1, 0, 6, 1) // 上
      set_char_pixels(features, size, 0, 1, 1, 6) // 左
      set_char_pixels(features, size, 1, 7, 6, 1) // 下
    }
    "D" | "d" => {
      // D形：左竖 + 右弧
      set_char_pixels(features, size, 0, 0, 1, 8) // 左
      set_char_pixels(features, size, 1, 0, 5, 1) // 上
      set_char_pixels(features, size, 6, 1, 1, 6) // 右
      set_char_pixels(features, size, 1, 7, 5, 1) // 下
    }
    "E" => {
      // E形：左竖 + 三横
      set_char_pixels(features, size, 0, 0, 1, 8) // 左
      set_char_pixels(features, size, 1, 0, 7, 1) // 上
      set_char_pixels(features, size, 1, 3, 5, 1) // 中
      set_char_pixels(features, size, 1, 7, 7, 1) // 下
    }
    "F" | "f" => {
      // F形：左竖 + 上中横
      set_char_pixels(features, size, 0, 0, 1, 8) // 左
      set_char_pixels(features, size, 1, 0, 7, 1) // 上
      set_char_pixels(features, size, 1, 3, 5, 1) // 中
    }
    "G" => {
      // G形：C + 中右
      set_char_pixels(features, size, 1, 0, 6, 1) // 上
      set_char_pixels(features, size, 0, 1, 1, 6) // 左
      set_char_pixels(features, size, 1, 7, 6, 1) // 下
      set_char_pixels(features, size, 6, 4, 1, 3) // 右中
      set_char_pixels(features, size, 4, 4, 3, 1) // 中横
    }
    "H" | "h" => {
      // H形：双竖 + 中横
      set_char_pixels(features, size, 0, 0, 1, 8) // 左
      set_char_pixels(features, size, 7, 0, 1, 8) // 右
      set_char_pixels(features, size, 1, 3, 6, 1) // 中
    }
    "J" | "j" => {
      // J形：右竖 + 下左
      set_char_pixels(features, size, 7, 0, 1, 7) // 右
      set_char_pixels(features, size, 1, 7, 6, 1) // 下
      set_char_pixels(features, size, 0, 5, 1, 3) // 左下
    }
    "K" | "k" => {
      // K形：左竖 + 对角
      set_char_pixels(features, size, 0, 0, 1, 8) // 左
      set_char_pixels(features, size, 6, 0, 1, 1)
      set_char_pixels(features, size, 5, 1, 1, 1)
      set_char_pixels(features, size, 4, 2, 1, 1)
      set_char_pixels(features, size, 3, 3, 1, 1)
      set_char_pixels(features, size, 4, 4, 1, 1)
      set_char_pixels(features, size, 5, 5, 1, 1)
      set_char_pixels(features, size, 6, 6, 1, 2)
    }
    "L" => {
      // L形：左竖 + 下横
      set_char_pixels(features, size, 0, 0, 1, 8) // 左
      set_char_pixels(features, size, 0, 7, 8, 1) // 下
    }
    "M" | "m" => {
      // M形：双竖 + V
      set_char_pixels(features, size, 0, 0, 1, 8) // 左
      set_char_pixels(features, size, 7, 0, 1, 8) // 右
      set_char_pixels(features, size, 1, 0, 1, 3)
      set_char_pixels(features, size, 6, 0, 1, 3)
      set_char_pixels(features, size, 2, 1, 1, 2)
      set_char_pixels(features, size, 5, 1, 1, 2)
      set_char_pixels(features, size, 3, 3, 2, 2) // 中
    }
    "N" | "n" => {
      // N形：双竖 + 对角
      set_char_pixels(features, size, 0, 0, 1, 8) // 左
      set_char_pixels(features, size, 7, 0, 1, 8) // 右
      set_char_pixels(features, size, 6, 1, 1, 1)
      set_char_pixels(features, size, 5, 2, 1, 1)
      set_char_pixels(features, size, 4, 3, 1, 1)
      set_char_pixels(features, size, 3, 4, 1, 1)
      set_char_pixels(features, size, 2, 5, 1, 1)
      set_char_pixels(features, size, 1, 6, 1, 1)
    }
    "P" | "p" => {
      // P形：左竖 + 上右
      set_char_pixels(features, size, 0, 0, 1, 8) // 左
      set_char_pixels(features, size, 1, 0, 6, 1) // 上
      set_char_pixels(features, size, 6, 0, 1, 4) // 右上
      set_char_pixels(features, size, 1, 3, 6, 1) // 中
    }
    "Q" => {
      // Q形：O + 尾
      set_char_pixels(features, size, 1, 0, 6, 1) // 上
      set_char_pixels(features, size, 0, 1, 1, 6) // 左
      set_char_pixels(features, size, 7, 1, 1, 6) // 右
      set_char_pixels(features, size, 1, 7, 6, 1) // 下
      set_char_pixels(features, size, 5, 6, 1, 1)
      set_char_pixels(features, size, 6, 7, 1, 1)
    }
    "R" | "r" => {
      // R形：P + 右下对角
      set_char_pixels(features, size, 0, 0, 1, 8) // 左
      set_char_pixels(features, size, 1, 0, 6, 1) // 上
      set_char_pixels(features, size, 6, 0, 1, 4) // 右上
      set_char_pixels(features, size, 1, 3, 6, 1) // 中
      set_char_pixels(features, size, 5, 4, 1, 1)
      set_char_pixels(features, size, 4, 5, 1, 1)
      set_char_pixels(features, size, 3, 6, 1, 1)
      set_char_pixels(features, size, 2, 7, 1, 1)
    }
    "U" | "u" => {
      // U形：双竖 + 下
      set_char_pixels(features, size, 0, 0, 1, 7) // 左
      set_char_pixels(features, size, 7, 0, 1, 7) // 右
      set_char_pixels(features, size, 1, 7, 6, 1) // 下
    }
    "V" | "v" => {
      // V形：倒V
      set_char_pixels(features, size, 0, 0, 1, 4)
      set_char_pixels(features, size, 7, 0, 1, 4)
      set_char_pixels(features, size, 1, 4, 1, 2)
      set_char_pixels(features, size, 6, 4, 1, 2)
      set_char_pixels(features, size, 2, 6, 1, 1)
      set_char_pixels(features, size, 5, 6, 1, 1)
      set_char_pixels(features, size, 3, 7, 2, 1) // 底
    }
    "W" | "w" => {
      // W形：双V
      set_char_pixels(features, size, 0, 0, 1, 5)
      set_char_pixels(features, size, 7, 0, 1, 5)
      set_char_pixels(features, size, 1, 5, 1, 2)
      set_char_pixels(features, size, 6, 5, 1, 2)
      set_char_pixels(features, size, 2, 7, 1, 1)
      set_char_pixels(features, size, 5, 7, 1, 1)
      set_char_pixels(features, size, 3, 5, 2, 2) // 中
    }
    "X" | "x" => {
      // X形：双对角
      set_char_pixels(features, size, 0, 0, 1, 1)
      set_char_pixels(features, size, 7, 0, 1, 1)
      set_char_pixels(features, size, 1, 1, 1, 1)
      set_char_pixels(features, size, 6, 1, 1, 1)
      set_char_pixels(features, size, 2, 2, 1, 1)
      set_char_pixels(features, size, 5, 2, 1, 1)
      set_char_pixels(features, size, 3, 3, 2, 2) // 中
      set_char_pixels(features, size, 2, 5, 1, 1)
      set_char_pixels(features, size, 5, 5, 1, 1)
      set_char_pixels(features, size, 1, 6, 1, 1)
      set_char_pixels(features, size, 6, 6, 1, 1)
      set_char_pixels(features, size, 0, 7, 1, 1)
      set_char_pixels(features, size, 7, 7, 1, 1)
    }
    "Y" | "y" => {
      // Y形：上双竖 + 下中竖
      set_char_pixels(features, size, 0, 0, 1, 4)
      set_char_pixels(features, size, 7, 0, 1, 4)
      set_char_pixels(features, size, 1, 1, 1, 2)
      set_char_pixels(features, size, 6, 1, 1, 2)
      set_char_pixels(features, size, 2, 3, 1, 1)
      set_char_pixels(features, size, 5, 3, 1, 1)
      set_char_pixels(features, size, 3, 4, 2, 4) // 中竖
    }
    "+" | "=" | "-" => {
      // 加号/等号/横
      set_char_pixels(features, size, 3, 0, 2, 8) // 竖
      set_char_pixels(features, size, 0, 3, 8, 2) // 横
    }
    "." | "," =>
      // 点/逗号
      set_char_pixels(features, size, 3, 6, 2, 2)
    ":" | ";" => {
      // 冒号/分号
      set_char_pixels(features, size, 3, 2, 2, 2)
      set_char_pixels(features, size, 3, 5, 2, 2)
    }
    "!" => {
      // 感叹号
      set_char_pixels(features, size, 3, 0, 2, 5)
      set_char_pixels(features, size, 3, 7, 2, 1)
    }
    "?" => {
      // 问号
      set_char_pixels(features, size, 1, 0, 6, 1) // 上
      set_char_pixels(features, size, 6, 0, 1, 3) // 右上
      set_char_pixels(features, size, 3, 3, 2, 2) // 中
      set_char_pixels(features, size, 3, 6, 2, 2) // 点
    }
    "/" => {
      // 斜杠
      set_char_pixels(features, size, 6, 0, 1, 1)
      set_char_pixels(features, size, 5, 1, 1, 1)
      set_char_pixels(features, size, 4, 2, 1, 1)
      set_char_pixels(features, size, 3, 3, 1, 1)
      set_char_pixels(features, size, 2, 4, 1, 1)
      set_char_pixels(features, size, 1, 5, 1, 1)
      set_char_pixels(features, size, 0, 6, 1, 2)
    }
    "\\" => {
      // 反斜杠
      set_char_pixels(features, size, 0, 0, 1, 2)
      set_char_pixels(features, size, 1, 2, 1, 1)
      set_char_pixels(features, size, 2, 3, 1, 1)
      set_char_pixels(features, size, 3, 4, 1, 1)
      set_char_pixels(features, size, 4, 5, 1, 1)
      set_char_pixels(features, size, 5, 6, 1, 1)
      set_char_pixels(features, size, 6, 7, 1, 1)
    }
    _ =>
      // 默认：中心点
      set_char_pixels(features, size, 3, 3, 2, 2)
  }
  features
}

///|
/// 设置字符模板像素
fn set_char_pixels(
  features : Array[Double],
  size : Int,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) -> Unit {
  for r in 0..<height {
    for c in 0..<width {
      let px = x + c
      let py = y + r
      if px < size && py < size {
        features[py * size + px] = 1.0
      }
    }
  }
}

///|
/// 英文 OCR 识别（完整流水线）
pub fn recognize_english(
  img : @types.Image,
  config? : EnglishOcrConfig,
) -> OcrResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_english: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "recognize_english: 仅支持单通道灰度图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "recognize_english: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let cfg = match config {
    Some(c) => c
    None => english_ocr_default_config()
  }
  // 配置验证
  if cfg.min_char_width <= 0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_english: min_char_width必须大于0",
    )
  }
  if cfg.max_char_width < cfg.min_char_width {
    raise @types.LoadError::DecodeFailed(
      "recognize_english: max_char_width不能小于min_char_width",
    )
  }
  if cfg.target_size <= 0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_english: target_size必须大于0",
    )
  }
  // 1. 预处理
  let preprocessed = ocr_preprocess(img)
  // 2. 字符分割
  let char_regions = complete_char_segmentation(
    preprocessed,
    min_char_width=cfg.min_char_width,
    max_char_width=cfg.max_char_width,
  )
  // 3. 生成模板
  let templates = generate_english_templates(case_sensitive=cfg.case_sensitive)
  // 4. 对每个字符进行识别
  let char_results : Array[OcrCharResult] = []
  let mut text = ""
  let mut total_confidence = 0.0
  for _tup0 in char_regions {
    let (x, y, w, h) = _tup0
    // 提取字符图像
    let char_img = extract_char_region_english(
      preprocessed,
      x,
      y,
      w,
      h,
      cfg.target_size,
    )
    // 提取特征
    let features = extract_char_features_english(char_img, 8)
    // 模板匹配
    let result = match_template_english(
      features,
      templates,
      cfg.distance_metric,
    )
    text += result.0
    total_confidence += result.1
    char_results.push(OcrCharResult::{
      char: result.0,
      confidence: result.1,
      x,
      y,
      width: w,
      height: h,
    })
  }
  let avg_confidence = if char_results.length() > 0 {
    total_confidence / char_results.length().to_double()
  } else {
    0.0
  }
  OcrResult::{ text, confidence: avg_confidence, characters: char_results }
}

///|
/// 提取字符区域（英文OCR专用）
fn extract_char_region_english(
  img : @types.Image,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  target_size : Int,
) -> @types.Image {
  let w = img.width
  let h = img.height
  let crop_w = if x + width > w { w - x } else { width }
  let crop_h = if y + height > h { h - y } else { height }
  if crop_w <= 0 || crop_h <= 0 {
    let empty : Array[Byte] = Array::make(target_size * target_size, b'\x00')
    return @types.Image::{
      width: target_size,
      height: target_size,
      channels: 1,
      data: Bytes::from_array(empty),
    }
  }
  let scale = if crop_w > crop_h {
    target_size.to_double() / crop_w.to_double()
  } else {
    target_size.to_double() / crop_h.to_double()
  }
  let new_w = max_eng(1, (crop_w.to_double() * scale).to_int())
  let new_h = max_eng(1, (crop_h.to_double() * scale).to_int())
  let offset_x = (target_size - new_w) / 2
  let offset_y = (target_size - new_h) / 2
  let out : Array[Byte] = Array::make(target_size * target_size, b'\x00')
  let data = img.data
  for py in 0..<new_h {
    for px in 0..<new_w {
      let src_x = x + px * crop_w / new_w
      let src_y = y + py * crop_h / new_h
      if src_x < w && src_y < h {
        out[(offset_y + py) * target_size + (offset_x + px)] = data[src_y * w +
          src_x]
      }
    }
  }
  @types.Image::{
    width: target_size,
    height: target_size,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

///|
/// 提取字符特征（英文OCR专用）
fn extract_char_features_english(
  char_img : @types.Image,
  grid_size : Int,
) -> Array[Double] {
  let w = char_img.width
  let h = char_img.height
  let data = char_img.data
  let cell_w = w / grid_size
  let cell_h = h / grid_size
  let features : Array[Double] = []
  for r in 0..<grid_size {
    for c in 0..<grid_size {
      let mut count = 0
      let mut total = 0
      for py in 0..<cell_h {
        for px in 0..<cell_w {
          let sx = c * cell_w + px
          let sy = r * cell_h + py
          if sx < w && sy < h {
            total += 1
            if data[sy * w + sx].to_int() > 128 {
              count += 1
            }
          }
        }
      }
      let density = if total > 0 {
        count.to_double() / total.to_double()
      } else {
        0.0
      }
      features.push(density)
    }
  }
  features
}

///|
/// 模板匹配（英文OCR专用）
fn match_template_english(
  features : Array[Double],
  templates : Array[(String, Array[Double])],
  distance_metric : String,
) -> (String, Double) {
  let mut best_label = "?"
  let mut best_dist = 1000000.0
  for _tup1 in templates {
    let (label, template) = _tup1
    let dist = match distance_metric {
      "manhattan" => manhattan_distance_eng(features, template)
      "cosine" => cosine_distance_eng(features, template)
      _ => euclidean_distance_eng(features, template)
    }
    if dist < best_dist {
      best_dist = dist
      best_label = label
    }
  }
  let confidence = if best_dist > 0.0 { 1.0 / (1.0 + best_dist) } else { 1.0 }
  (best_label, confidence)
}

///|
/// 局部欧氏距离
fn euclidean_distance_eng(a : Array[Double], b : Array[Double]) -> Double {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  let mut sum_sq = 0.0
  for i in 0..<n {
    let diff = a[i] - b[i]
    sum_sq += diff * diff
  }
  sum_sq.sqrt()
}

///|
/// 局部曼哈顿距离
fn manhattan_distance_eng(a : Array[Double], b : Array[Double]) -> Double {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  let mut sum = 0.0
  for i in 0..<n {
    sum += (a[i] - b[i]).abs()
  }
  sum
}

///|
/// 局部余弦距离
fn cosine_distance_eng(a : Array[Double], b : Array[Double]) -> Double {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  let mut dot = 0.0
  let mut norm_a = 0.0
  let mut norm_b = 0.0
  for i in 0..<n {
    dot += a[i] * b[i]
    norm_a += a[i] * a[i]
    norm_b += b[i] * b[i]
  }
  let denom = norm_a.sqrt() * norm_b.sqrt()
  if denom > 0.0 {
    1.0 - dot / denom
  } else {
    1.0
  }
}

///|
/// 辅助函数：最大值
fn max_eng(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

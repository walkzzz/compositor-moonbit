// 局部二值模式（LBP，纯 MoonBit）

///|
/// 基本局部二值模式（LBP）。对每个像素，与其 3x3 邻域的 8 个像素比较，
/// 大于等于中心记 1，否则记 0，按顺时针顺序组成 8 位二进制数。
/// 仅处理灰度图（channels=1）或 RGB 图（channels=3/4），alpha 通道不变。
pub fn lbp(img : @types.Image) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("lbp: 图像尺寸必须大于0")
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("lbp: 仅支持 channels=1/3/4")
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "lbp: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { 1 }
  let w = img.width
  let h = img.height
  let n = w * h
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  // 预计算像素 Int 数组
  let src : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    src[i] = img.data[i].to_int()
  }
  for c in 0..<color_ch {
    // 内部区域：x in [1, w-1), y in [1, h-1)，直接访问 8 邻域
    for y in 1..<(h - 1) {
      for x in 1..<(w - 1) {
        let center = src[(y * w + x) * ch + c]
        let mut lbp_val = 0
        // 左上、上、右上、右、右下、下、左下、左
        if src[((y - 1) * w + (x - 1)) * ch + c] >= center {
          lbp_val = lbp_val | 1
        }
        if src[((y - 1) * w + x) * ch + c] >= center {
          lbp_val = lbp_val | 2
        }
        if src[((y - 1) * w + (x + 1)) * ch + c] >= center {
          lbp_val = lbp_val | 4
        }
        if src[(y * w + (x + 1)) * ch + c] >= center {
          lbp_val = lbp_val | 8
        }
        if src[((y + 1) * w + (x + 1)) * ch + c] >= center {
          lbp_val = lbp_val | 16
        }
        if src[((y + 1) * w + x) * ch + c] >= center {
          lbp_val = lbp_val | 32
        }
        if src[((y + 1) * w + (x - 1)) * ch + c] >= center {
          lbp_val = lbp_val | 64
        }
        if src[(y * w + (x - 1)) * ch + c] >= center {
          lbp_val = lbp_val | 128
        }
        out[(y * w + x) * ch + c] = lbp_val.to_byte()
      }
    }
    // 边界区域：使用 get_pixel_safe
    for y in 0..<h {
      let y_inner = y >= 1 && y < h - 1
      for x in 0..<w {
        if y_inner && x >= 1 && x < w - 1 {
          continue
        }
        let center = src[(y * w + x) * ch + c]
        let mut lbp_val = 0
        if get_pixel_safe(src, x - 1, y - 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 1
        }
        if get_pixel_safe(src, x, y - 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 2
        }
        if get_pixel_safe(src, x + 1, y - 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 4
        }
        if get_pixel_safe(src, x + 1, y, c, ch, w, h) >= center {
          lbp_val = lbp_val | 8
        }
        if get_pixel_safe(src, x + 1, y + 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 16
        }
        if get_pixel_safe(src, x, y + 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 32
        }
        if get_pixel_safe(src, x - 1, y + 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 64
        }
        if get_pixel_safe(src, x - 1, y, c, ch, w, h) >= center {
          lbp_val = lbp_val | 128
        }
        out[(y * w + x) * ch + c] = lbp_val.to_byte()
      }
    }
  }
  if ch == 4 {
    for i in 0..<n {
      out[i * 4 + 3] = img.data[i * 4 + 3]
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 均匀局部二值模式（Uniform LBP）。
/// 均匀模式指 0→1 和 1→0 跳变次数 <= 2 的模式，共有 58 种均匀模式。
/// 非均匀模式统一映射为 59。输出范围 0~59。
pub fn lbp_uniform(img : @types.Image) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "lbp_uniform: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "lbp_uniform: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "lbp_uniform: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { 1 }
  let w = img.width
  let h = img.height
  let n = w * h
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  // 预计算均匀模式映射表
  let uniform_map = build_uniform_map()
  // 预计算像素 Int 数组
  let src : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    src[i] = img.data[i].to_int()
  }
  for c in 0..<color_ch {
    // 内部区域
    for y in 1..<(h - 1) {
      for x in 1..<(w - 1) {
        let center = src[(y * w + x) * ch + c]
        let mut lbp_val = 0
        if src[((y - 1) * w + (x - 1)) * ch + c] >= center {
          lbp_val = lbp_val | 1
        }
        if src[((y - 1) * w + x) * ch + c] >= center {
          lbp_val = lbp_val | 2
        }
        if src[((y - 1) * w + (x + 1)) * ch + c] >= center {
          lbp_val = lbp_val | 4
        }
        if src[(y * w + (x + 1)) * ch + c] >= center {
          lbp_val = lbp_val | 8
        }
        if src[((y + 1) * w + (x + 1)) * ch + c] >= center {
          lbp_val = lbp_val | 16
        }
        if src[((y + 1) * w + x) * ch + c] >= center {
          lbp_val = lbp_val | 32
        }
        if src[((y + 1) * w + (x - 1)) * ch + c] >= center {
          lbp_val = lbp_val | 64
        }
        if src[(y * w + (x - 1)) * ch + c] >= center {
          lbp_val = lbp_val | 128
        }
        out[(y * w + x) * ch + c] = uniform_map[lbp_val].to_byte()
      }
    }
    // 边界区域
    for y in 0..<h {
      let y_inner = y >= 1 && y < h - 1
      for x in 0..<w {
        if y_inner && x >= 1 && x < w - 1 {
          continue
        }
        let center = src[(y * w + x) * ch + c]
        let mut lbp_val = 0
        if get_pixel_safe(src, x - 1, y - 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 1
        }
        if get_pixel_safe(src, x, y - 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 2
        }
        if get_pixel_safe(src, x + 1, y - 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 4
        }
        if get_pixel_safe(src, x + 1, y, c, ch, w, h) >= center {
          lbp_val = lbp_val | 8
        }
        if get_pixel_safe(src, x + 1, y + 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 16
        }
        if get_pixel_safe(src, x, y + 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 32
        }
        if get_pixel_safe(src, x - 1, y + 1, c, ch, w, h) >= center {
          lbp_val = lbp_val | 64
        }
        if get_pixel_safe(src, x - 1, y, c, ch, w, h) >= center {
          lbp_val = lbp_val | 128
        }
        out[(y * w + x) * ch + c] = uniform_map[lbp_val].to_byte()
      }
    }
  }
  if ch == 4 {
    for i in 0..<n {
      out[i * 4 + 3] = img.data[i * 4 + 3]
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
fn get_pixel_safe(
  src : Array[Int],
  x : Int,
  y : Int,
  c : Int,
  ch : Int,
  w : Int,
  h : Int,
) -> Int {
  if x < 0 || x >= w || y < 0 || y >= h {
    return 0
  }
  src[(y * w + x) * ch + c]
}

///|
fn build_uniform_map() -> Array[Int] {
  let map : Array[Int] = Array::make(256, 59)
  let mut label = 0
  for v in 0..<256 {
    if count_transitions(v) <= 2 {
      map[v] = label
      label += 1
    }
  }
  map
}

///|
fn count_transitions(v : Int) -> Int {
  let mut count = 0
  for i in 0..<8 {
    let bit_i = (v >> i) & 1
    let bit_next = (v >> ((i + 1) % 8)) & 1
    if bit_i != bit_next {
      count += 1
    }
  }
  count
}

// 形态学操作（纯 MoonBit）：erode / dilate / morph_open / morph_close
// 使用 3x3 结构元素（八邻域）

///|
/// 腐蚀。每个像素取 3x3 邻域最小值。分离内部/边界区域以消除热点 clamp 调用。
pub fn erode(img : @types.Image) -> @types.Image {
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  // 预计算像素 Int 数组，避免内层循环重复类型转换
  let src : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    src[i] = img.data[i].to_int()
  }
  // 内部区域：x in [1, w-1), y in [1, h-1)，3x3 核完全在图像内
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      for c in 0..<ch {
        let base = ((y - 1) * w + (x - 1)) * ch + c
        let mut min_v = src[base]
        if src[base + ch] < min_v {
          min_v = src[base + ch]
        }
        if src[base + 2 * ch] < min_v {
          min_v = src[base + 2 * ch]
        }
        let row1 = base + w * ch
        if src[row1] < min_v {
          min_v = src[row1]
        }
        if src[row1 + ch] < min_v {
          min_v = src[row1 + ch]
        }
        if src[row1 + 2 * ch] < min_v {
          min_v = src[row1 + 2 * ch]
        }
        let row2 = base + 2 * w * ch
        if src[row2] < min_v {
          min_v = src[row2]
        }
        if src[row2 + ch] < min_v {
          min_v = src[row2 + ch]
        }
        if src[row2 + 2 * ch] < min_v {
          min_v = src[row2 + 2 * ch]
        }
        out[(y * w + x) * ch + c] = min_v.to_byte()
      }
    }
  }
  // 边界区域：需要 clamp
  for y in 0..<h {
    let y_inner = y >= 1 && y < h - 1
    for x in 0..<w {
      if y_inner && x >= 1 && x < w - 1 {
        continue
      }
      for c in 0..<ch {
        let mut min_v = 255
        for dy in -1..<=1 {
          for dx in -1..<=1 {
            let sx = clamp_i(x + dx, 0, w - 1)
            let sy = clamp_i(y + dy, 0, h - 1)
            let v = src[(sy * w + sx) * ch + c]
            if v < min_v {
              min_v = v
            }
          }
        }
        out[(y * w + x) * ch + c] = min_v.to_byte()
      }
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
/// 膨胀。每个像素取 3x3 邻域最大值。分离内部/边界区域以消除热点 clamp 调用。
pub fn dilate(img : @types.Image) -> @types.Image {
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  // 预计算像素 Int 数组
  let src : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    src[i] = img.data[i].to_int()
  }
  // 内部区域：x in [1, w-1), y in [1, h-1)
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      for c in 0..<ch {
        let base = ((y - 1) * w + (x - 1)) * ch + c
        let mut max_v = src[base]
        if src[base + ch] > max_v {
          max_v = src[base + ch]
        }
        if src[base + 2 * ch] > max_v {
          max_v = src[base + 2 * ch]
        }
        let row1 = base + w * ch
        if src[row1] > max_v {
          max_v = src[row1]
        }
        if src[row1 + ch] > max_v {
          max_v = src[row1 + ch]
        }
        if src[row1 + 2 * ch] > max_v {
          max_v = src[row1 + 2 * ch]
        }
        let row2 = base + 2 * w * ch
        if src[row2] > max_v {
          max_v = src[row2]
        }
        if src[row2 + ch] > max_v {
          max_v = src[row2 + ch]
        }
        if src[row2 + 2 * ch] > max_v {
          max_v = src[row2 + 2 * ch]
        }
        out[(y * w + x) * ch + c] = max_v.to_byte()
      }
    }
  }
  // 边界区域：需要 clamp
  for y in 0..<h {
    let y_inner = y >= 1 && y < h - 1
    for x in 0..<w {
      if y_inner && x >= 1 && x < w - 1 {
        continue
      }
      for c in 0..<ch {
        let mut max_v = 0
        for dy in -1..<=1 {
          for dx in -1..<=1 {
            let sx = clamp_i(x + dx, 0, w - 1)
            let sy = clamp_i(y + dy, 0, h - 1)
            let v = src[(sy * w + sx) * ch + c]
            if v > max_v {
              max_v = v
            }
          }
        }
        out[(y * w + x) * ch + c] = max_v.to_byte()
      }
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
/// 开运算（先腐蚀后膨胀）。去除小的明亮噪点。
pub fn morph_open(img : @types.Image) -> @types.Image {
  dilate(erode(img))
}

///|
/// 闭运算（先膨胀后腐蚀）。填充小的暗洞。
pub fn morph_close(img : @types.Image) -> @types.Image {
  erode(dilate(img))
}

///|
/// 形态学梯度（dilate - erode）。提取边缘轮廓。
pub fn morph_gradient(img : @types.Image) -> @types.Image {
  let dilated = dilate(img)
  let eroded = erode(img)
  let ch = img.channels
  let n = img.width * img.height * ch
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    let v = dilated.data[i].to_int() - eroded.data[i].to_int()
    out[i] = if v < 0 { b'\x00' } else { v.to_byte() }
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 顶帽变换（original - open）。提取比结构元素小的明亮细节。
pub fn morph_tophat(img : @types.Image) -> @types.Image {
  let opened = morph_open(img)
  let ch = img.channels
  let n = img.width * img.height * ch
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    let v = img.data[i].to_int() - opened.data[i].to_int()
    out[i] = if v < 0 { b'\x00' } else { v.to_byte() }
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 黑帽变换（close - original）。提取比结构元素小的暗细节。
pub fn morph_blackhat(img : @types.Image) -> @types.Image {
  let closed = morph_close(img)
  let ch = img.channels
  let n = img.width * img.height * ch
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    let v = closed.data[i].to_int() - img.data[i].to_int()
    out[i] = if v < 0 { b'\x00' } else { v.to_byte() }
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
fn clamp_i(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
/// 结构元素（核）。二维布尔数组，true 表示该位置属于结构元素。
pub(all) struct StructuringElement {
  width : Int
  height : Int
  data : Array[Bool] // height * width
}

///|
/// 创建矩形结构元素（全为 true）。
pub fn se_rect(width : Int, height : Int) -> StructuringElement {
  StructuringElement::{ width, height, data: Array::make(width * height, true) }
}

///|
/// 创建十字形结构元素（中心行+中心列）。
pub fn se_cross(size : Int) -> StructuringElement {
  let data : Array[Bool] = Array::make(size * size, false)
  let cx = size / 2
  for i in 0..<size {
    data[cx * size + i] = true
    data[i * size + cx] = true
  }
  StructuringElement::{ width: size, height: size, data }
}

///|
/// 创建椭圆形结构元素。对于 size×size 的核，包含所有满足
/// (dx/rx)² + (dy/ry)² ≤ 1 的位置。
pub fn se_ellipse(size : Int) -> StructuringElement {
  let data : Array[Bool] = Array::make(size * size, false)
  let cx = (size - 1) / 2
  let cy = (size - 1) / 2
  let rx = Float::from_int(cx) + 0.5F
  let ry = Float::from_int(cy) + 0.5F
  for y in 0..<size {
    for x in 0..<size {
      let dx = (Float::from_int(x) - Float::from_int(cx)) / rx
      let dy = (Float::from_int(y) - Float::from_int(cy)) / ry
      if dx * dx + dy * dy <= 1.0F {
        data[y * size + x] = true
      }
    }
  }
  StructuringElement::{ width: size, height: size, data }
}

///|
/// 使用自定义结构元素进行腐蚀。
pub fn erode_custom(
  img : @types.Image,
  se : StructuringElement,
) -> @types.Image {
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  let src : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    src[i] = img.data[i].to_int()
  }
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  let cx = se.width / 2
  let cy = se.height / 2
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<ch {
        let mut min_v = 255
        for sy in 0..<se.height {
          for sx in 0..<se.width {
            if se.data[sy * se.width + sx] {
              let nx = clamp_i(x + sx - cx, 0, w - 1)
              let ny = clamp_i(y + sy - cy, 0, h - 1)
              let v = src[(ny * w + nx) * ch + c]
              if v < min_v {
                min_v = v
              }
            }
          }
        }
        out[(y * w + x) * ch + c] = min_v.to_byte()
      }
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
/// 使用自定义结构元素进行膨胀。
pub fn dilate_custom(
  img : @types.Image,
  se : StructuringElement,
) -> @types.Image {
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  let src : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    src[i] = img.data[i].to_int()
  }
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  let cx = se.width / 2
  let cy = se.height / 2
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<ch {
        let mut max_v = 0
        for sy in 0..<se.height {
          for sx in 0..<se.width {
            if se.data[sy * se.width + sx] {
              let nx = clamp_i(x + sx - cx, 0, w - 1)
              let ny = clamp_i(y + sy - cy, 0, h - 1)
              let v = src[(ny * w + nx) * ch + c]
              if v > max_v {
                max_v = v
              }
            }
          }
        }
        out[(y * w + x) * ch + c] = max_v.to_byte()
      }
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
/// 使用自定义结构元素进行开运算。
pub fn morph_open_custom(
  img : @types.Image,
  se : StructuringElement,
) -> @types.Image {
  dilate_custom(erode_custom(img, se), se)
}

///|
/// 使用自定义结构元素进行闭运算。
pub fn morph_close_custom(
  img : @types.Image,
  se : StructuringElement,
) -> @types.Image {
  erode_custom(dilate_custom(img, se), se)
}

// 图像拼接与平铺（纯 MoonBit）：hstack / vstack / tile / transpose

///|
/// 水平拼接。两图高度和通道数必须相同。
pub fn hstack(
  left : @types.Image,
  right : @types.Image,
) -> @types.Image raise @types.LoadError {
  if left.height != right.height || left.channels != right.channels {
    raise @types.LoadError::DecodeFailed(
      "hstack 两图高度/通道数必须相同",
    )
  }
  let ch = left.channels
  let new_w = left.width + right.width
  let h = left.height
  let out : Array[Byte] = Array::make(new_w * h * ch, b'\x00')
  for y in 0..<h {
    for x in 0..<left.width {
      let src_off = (y * left.width + x) * ch
      let dst_off = (y * new_w + x) * ch
      for c in 0..<ch {
        out[dst_off + c] = left.data[src_off + c]
      }
    }
    for x in 0..<right.width {
      let src_off = (y * right.width + x) * ch
      let dst_off = (y * new_w + left.width + x) * ch
      for c in 0..<ch {
        out[dst_off + c] = right.data[src_off + c]
      }
    }
  }
  @types.Image::{
    width: new_w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 垂直拼接。两图宽度和通道数必须相同。
pub fn vstack(
  top : @types.Image,
  bottom : @types.Image,
) -> @types.Image raise @types.LoadError {
  if top.width != bottom.width || top.channels != bottom.channels {
    raise @types.LoadError::DecodeFailed(
      "vstack 两图宽度/通道数必须相同",
    )
  }
  let ch = top.channels
  let w = top.width
  let new_h = top.height + bottom.height
  let out : Array[Byte] = Array::make(w * new_h * ch, b'\x00')
  for i in 0..<(w * top.height * ch) {
    out[i] = top.data[i]
  }
  let top_size = w * top.height * ch
  for i in 0..<(w * bottom.height * ch) {
    out[top_size + i] = bottom.data[i]
  }
  @types.Image::{
    width: w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 平铺图像。将 img 在 x 方向重复 cols 次，y 方向重复 rows 次。
pub fn tile(
  img : @types.Image,
  cols : Int,
  rows : Int,
) -> @types.Image raise @types.LoadError {
  if cols <= 0 || rows <= 0 {
    raise @types.LoadError::DecodeFailed("tile cols/rows 必须为正数")
  }
  let ch = img.channels
  let new_w = img.width * cols
  let new_h = img.height * rows
  let out : Array[Byte] = Array::make(new_w * new_h * ch, b'\x00')
  for y in 0..<new_h {
    for x in 0..<new_w {
      let src_x = x % img.width
      let src_y = y % img.height
      let src_off = (src_y * img.width + src_x) * ch
      let dst_off = (y * new_w + x) * ch
      for c in 0..<ch {
        out[dst_off + c] = img.data[src_off + c]
      }
    }
  }
  @types.Image::{
    width: new_w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 转置（沿主对角线翻转）。宽高互换。
pub fn transpose(img : @types.Image) -> @types.Image {
  let ch = img.channels
  let new_w = img.height
  let new_h = img.width
  let out : Array[Byte] = Array::make(new_w * new_h * ch, b'\x00')
  for y in 0..<img.height {
    for x in 0..<img.width {
      let src_off = (y * img.width + x) * ch
      let dst_off = (x * new_w + y) * ch
      for c in 0..<ch {
        out[dst_off + c] = img.data[src_off + c]
      }
    }
  }
  @types.Image::{
    width: new_w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

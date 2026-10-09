// 图像几何增强（纯 MoonBit）：pad / add_border

///|
/// 在图像四周填充指定颜色，生成新尺寸 (width+2*px, height+2*py) 的新图像。
/// pad_color 长度应等于 channels，不足则循环使用。
pub fn pad(
  img : @types.Image,
  px : Int,
  py : Int,
  pad_color : Array[Byte],
) -> @types.Image raise @types.LoadError {
  if px < 0 || py < 0 {
    raise @types.LoadError::DecodeFailed("pad 填充必须非负")
  }
  let ch = img.channels
  let new_w = img.width + 2 * px
  let new_h = img.height + 2 * py
  let out : Array[Byte] = Array::make(new_w * new_h * ch, b'\x00')
  let color_len = pad_color.length()
  if color_len == 0 {
    raise @types.LoadError::DecodeFailed("pad_color 不能为空")
  }
  // 填充
  for y in 0..<new_h {
    for x in 0..<new_w {
      let dst_off = (y * new_w + x) * ch
      if x >= px && x < px + img.width && y >= py && y < py + img.height {
        // 拷贝原始像素
        let src_off = ((y - py) * img.width + (x - px)) * ch
        for c in 0..<ch {
          out[dst_off + c] = img.data[src_off + c]
        }
      } else {
        // 填充颜色
        for c in 0..<ch {
          out[dst_off + c] = pad_color[c % color_len]
        }
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
/// 添加边框。top/right/bottom/left 分别为四边边框宽度，border_color 为边框颜色。
pub fn add_border(
  img : @types.Image,
  top : Int,
  right : Int,
  bottom : Int,
  left : Int,
  border_color : Array[Byte],
) -> @types.Image raise @types.LoadError {
  if top < 0 || right < 0 || bottom < 0 || left < 0 {
    raise @types.LoadError::DecodeFailed("border 宽度必须非负")
  }
  let ch = img.channels
  let new_w = img.width + left + right
  let new_h = img.height + top + bottom
  let out : Array[Byte] = Array::make(new_w * new_h * ch, b'\x00')
  let color_len = border_color.length()
  if color_len == 0 {
    raise @types.LoadError::DecodeFailed("border_color 不能为空")
  }
  for y in 0..<new_h {
    for x in 0..<new_w {
      let dst_off = (y * new_w + x) * ch
      if x >= left && x < left + img.width && y >= top && y < top + img.height {
        let src_off = ((y - top) * img.width + (x - left)) * ch
        for c in 0..<ch {
          out[dst_off + c] = img.data[src_off + c]
        }
      } else {
        for c in 0..<ch {
          out[dst_off + c] = border_color[c % color_len]
        }
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

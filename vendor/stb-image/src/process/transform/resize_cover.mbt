// 高级 Resize 操作（纯 MoonBit）：resize_to_cover / resize_to_contain
// 含裁剪和填充逻辑，属于高级算法层

///|
/// Resize 并裁剪到精确尺寸（cover 模式）。
/// 先按宽高比缩放使图像"覆盖"目标尺寸，然后居中裁剪多余部分。
pub fn resize_to_cover(
  img : @types.Image,
  target_w : Int,
  target_h : Int,
) -> @types.Image raise @types.LoadError {
  if target_w <= 0 || target_h <= 0 {
    raise @types.LoadError::DecodeFailed("目标尺寸必须为正数")
  }
  let scale_w = Float::from_int(target_w) / Float::from_int(img.width)
  let scale_h = Float::from_int(target_h) / Float::from_int(img.height)
  let scale = if scale_w > scale_h { scale_w } else { scale_h }
  let scaled_w = (Float::from_int(img.width) * scale).to_int()
  let scaled_h = (Float::from_int(img.height) * scale).to_int()
  let scaled = @pure_util.resize_pure(img, scaled_w, scaled_h)
  let x = (scaled_w - target_w) / 2
  let y = (scaled_h - target_h) / 2
  crop(scaled, x, y, target_w, target_h)
}

///|
/// Resize 到目标尺寸内（contain 模式），保持宽高比，不足部分用 fill_color 填充。
pub fn resize_to_contain(
  img : @types.Image,
  target_w : Int,
  target_h : Int,
  fill_color : Array[Byte],
) -> @types.Image raise @types.LoadError {
  if target_w <= 0 || target_h <= 0 {
    raise @types.LoadError::DecodeFailed("目标尺寸必须为正数")
  }
  let scale_w = Float::from_int(target_w) / Float::from_int(img.width)
  let scale_h = Float::from_int(target_h) / Float::from_int(img.height)
  let scale = if scale_w < scale_h { scale_w } else { scale_h }
  let scaled_w = (Float::from_int(img.width) * scale).to_int()
  let scaled_h = (Float::from_int(img.height) * scale).to_int()
  let scaled = @pure_util.resize_pure(img, scaled_w, scaled_h)
  let px = (target_w - scaled_w) / 2
  let py = (target_h - scaled_h) / 2
  pad_image(scaled, px, py, fill_color)
}

///|
/// 内部 pad 辅助函数：在图像四周填充指定颜色，生成新尺寸 (width+2*px, height+2*py) 的新图像。
fn pad_image(
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

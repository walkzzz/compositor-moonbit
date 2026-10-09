// 纯 MoonBit TGA 解码器
// 支持 image type 2（未压缩 RGB）和 type 10（RLE RGB）
// 24-bit（BGR→RGB）和 32-bit（BGRA→RGBA）
// 规范: https://en.wikipedia.org/wiki/Truevision_TGA

///|
/// 解码 TGA 字节流为 Image（24-bit -> channels=3, 32-bit -> channels=4）
/// 支持 image type 2（未压缩 RGB）和 type 10（RLE RGB）
pub fn decode_tga_pure(data : Bytes) -> @types.Image raise @types.LoadError {
  let len = data.length()
  // TGA header 18 字节
  if len < 18 {
    raise @types.LoadError::DecodeFailed("TGA 数据过短")
  }
  let id_length = data[0].to_int()
  let color_map_type = data[1].to_int()
  let image_type = data[2].to_int()
  let width = read_u16_le(data, 12)
  let height = read_u16_le(data, 14)
  let bpp = data[16].to_int()
  let descriptor = data[17].to_int()
  // 仅支持无颜色映射
  if color_map_type != 0 {
    raise @types.LoadError::DecodeFailed(
      "不支持的 TGA 颜色映射类型，仅支持无颜色映射",
    )
  }
  // 仅支持 image type 2（未压缩 RGB）和 type 10（RLE RGB）
  if image_type != 2 && image_type != 10 {
    raise @types.LoadError::DecodeFailed(
      "不支持的 TGA image type，仅支持 type 2 和 type 10",
    )
  }
  // 仅支持 24-bit 和 32-bit
  if bpp != 24 && bpp != 32 {
    raise @types.LoadError::DecodeFailed(
      "不支持的 TGA 位深，仅支持 24-bit 和 32-bit",
    )
  }
  // 尺寸校验
  if width == 0 || height == 0 {
    raise @types.LoadError::DecodeFailed("TGA 尺寸无效")
  }
  let bytes_per_pixel = bpp / 8
  let out_channels = bytes_per_pixel
  @types.check_dims(width, height, out_channels)
  // 行序：descriptor bit4=0 bottom-up, bit4=1 top-down
  let bottom_up = (descriptor & 0x10) == 0
  // 像素数据起始位置
  let pixel_data_start = 18 + id_length
  // 解码像素（BGR(A) → RGB(A)）到 raw_pixels（按文件行序）
  let pixel_count = width * height
  let raw_pixels : Array[Byte] = Array::make(
    pixel_count * out_channels,
    b'\x00',
  )
  let pos = Ref(pixel_data_start)
  let pixel_idx = Ref(0)
  if image_type == 2 {
    // 未压缩
    while pixel_idx.val < pixel_count {
      let p = pos.val
      if p + bytes_per_pixel > len {
        raise @types.LoadError::DecodeFailed("TGA 像素数据越界")
      }
      // BGR(A) → RGB(A)
      let b = data[p].to_int()
      let g = data[p + 1].to_int()
      let r = data[p + 2].to_int()
      let out_idx = pixel_idx.val * out_channels
      raw_pixels[out_idx] = r.to_byte()
      raw_pixels[out_idx + 1] = g.to_byte()
      raw_pixels[out_idx + 2] = b.to_byte()
      if out_channels == 4 {
        let a = data[p + 3].to_int()
        raw_pixels[out_idx + 3] = a.to_byte()
      }
      pos.val += bytes_per_pixel
      pixel_idx.val += 1
    }
  } else {
    // RLE (image_type == 10)
    while pixel_idx.val < pixel_count && pos.val < len {
      let header = data[pos.val].to_int()
      pos.val += 1
      if (header & 0x80) != 0 {
        // RLE packet: run = (header & 0x7F) + 1, 读 1 像素重复 run 次
        let run = (header & 0x7F) + 1
        let p = pos.val
        if p + bytes_per_pixel > len {
          raise @types.LoadError::DecodeFailed("TGA RLE 像素数据越界")
        }
        let b = data[p].to_int()
        let g = data[p + 1].to_int()
        let r = data[p + 2].to_int()
        let a = if out_channels == 4 { data[p + 3].to_int() } else { 0 }
        pos.val += bytes_per_pixel
        for i in 0..<run {
          if pixel_idx.val + i < pixel_count {
            let out_idx = (pixel_idx.val + i) * out_channels
            raw_pixels[out_idx] = r.to_byte()
            raw_pixels[out_idx + 1] = g.to_byte()
            raw_pixels[out_idx + 2] = b.to_byte()
            if out_channels == 4 {
              raw_pixels[out_idx + 3] = a.to_byte()
            }
          }
        }
        pixel_idx.val += run
      } else {
        // raw packet: count = (header & 0x7F) + 1, 读 count 像素
        let count = (header & 0x7F) + 1
        for i in 0..<count {
          let p = pos.val + i * bytes_per_pixel
          if p + bytes_per_pixel > len {
            raise @types.LoadError::DecodeFailed(
              "TGA RLE raw 像素数据越界",
            )
          }
          if pixel_idx.val + i < pixel_count {
            let b = data[p].to_int()
            let g = data[p + 1].to_int()
            let r = data[p + 2].to_int()
            let out_idx = (pixel_idx.val + i) * out_channels
            raw_pixels[out_idx] = r.to_byte()
            raw_pixels[out_idx + 1] = g.to_byte()
            raw_pixels[out_idx + 2] = b.to_byte()
            if out_channels == 4 {
              let a = data[p + 3].to_int()
              raw_pixels[out_idx + 3] = a.to_byte()
            }
          }
        }
        pos.val += count * bytes_per_pixel
        pixel_idx.val += count
      }
    }
  }
  // 行序处理：按输出行序写入 pixels
  let pixels : Array[Byte] = Array::make(pixel_count * out_channels, b'\x00')
  for file_row in 0..<height {
    let out_row = if bottom_up { height - 1 - file_row } else { file_row }
    for x in 0..<width {
      let src_idx = (file_row * width + x) * out_channels
      let dst_idx = (out_row * width + x) * out_channels
      for c in 0..<out_channels {
        pixels[dst_idx + c] = raw_pixels[src_idx + c]
      }
    }
  }
  @types.Image::{
    width,
    height,
    channels: out_channels,
    data: Bytes::from_array(pixels),
  }
}

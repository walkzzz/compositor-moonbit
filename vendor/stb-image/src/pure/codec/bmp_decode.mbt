// 纯 MoonBit BMP 解码器
// 支持 24-bit / 32-bit 无压缩 BMP（BI_RGB，compression=0）
// 规范: https://en.wikipedia.org/wiki/BMP_file_format

///|
/// 解码 BMP 字节流为 Image（24-bit -> channels=3, 32-bit -> channels=4）
/// 仅支持 BITMAPINFOHEADER（DIB 头 40 字节）+ BI_RGB（无压缩）
pub fn decode_bmp_pure(data : Bytes) -> @types.Image raise @types.LoadError {
  let len = data.length()
  // BMP 文件头 14 字节 + DIB 头 40 字节 = 54 字节最小
  if len < 54 {
    raise @types.LoadError::DecodeFailed("BMP 数据过短")
  }
  // 检查 magic "BM"
  if data[0].to_int() != 0x42 || data[1].to_int() != 0x4D {
    raise @types.LoadError::DecodeFailed("BMP magic 不匹配")
  }
  let data_offset = read_u32_le(data, 10)
  let dib_size = read_u32_le(data, 14)
  // 仅支持 BITMAPINFOHEADER（40 字节）
  if dib_size != 40 {
    raise @types.LoadError::DecodeFailed(
      "不支持的 BMP DIB 头大小，仅支持 BITMAPINFOHEADER（40 字节）",
    )
  }
  let width = read_u32_le(data, 18)
  let height = read_u32_le(data, 22)
  let bpp = read_u16_le(data, 28)
  let compression = read_u32_le(data, 30)
  // 仅支持 24-bit 和 32-bit
  if bpp != 24 && bpp != 32 {
    raise @types.LoadError::DecodeFailed(
      "不支持的 BMP 位深，仅支持 24-bit 和 32-bit",
    )
  }
  // 仅支持 BI_RGB（compression=0）
  if compression != 0 {
    raise @types.LoadError::DecodeFailed(
      "不支持的 BMP 压缩方式，仅支持 BI_RGB（无压缩）",
    )
  }
  // 尺寸校验
  if width == 0 || height == 0 {
    raise @types.LoadError::DecodeFailed("BMP 尺寸无效")
  }
  let abs_width = if width < 0 { -width } else { width }
  let abs_height = if height < 0 { -height } else { height }
  // 行序：height > 0 自下而上，height < 0 自上而下
  let bottom_up = height > 0
  // 每像素字节数
  let bytes_per_pixel = bpp / 8
  // 行数据字节数（4 字节对齐）
  let row_size = (abs_width * bytes_per_pixel + 3) / 4 * 4
  // 输出 channels
  let out_channels = bytes_per_pixel
  @types.check_dims(abs_width, abs_height, out_channels)
  // 输出像素数据
  let pixel_count = abs_width * abs_height
  let pixels : Array[Byte] = Array::make(pixel_count * out_channels, b'\x00')
  // 逐行读取
  for file_row in 0..<abs_height {
    // 计算输出行号
    let out_row = if bottom_up { abs_height - 1 - file_row } else { file_row }
    let row_start = data_offset + file_row * row_size
    for x in 0..<abs_width {
      let pixel_offset = row_start + x * bytes_per_pixel
      if pixel_offset + bytes_per_pixel > len {
        raise @types.LoadError::DecodeFailed("BMP 像素数据越界")
      }
      // BGR(A) -> RGB(A)
      let b = data[pixel_offset].to_int()
      let g = data[pixel_offset + 1].to_int()
      let r = data[pixel_offset + 2].to_int()
      let out_idx = (out_row * abs_width + x) * out_channels
      pixels[out_idx] = r.to_byte()
      pixels[out_idx + 1] = g.to_byte()
      pixels[out_idx + 2] = b.to_byte()
      if out_channels == 4 {
        let a = data[pixel_offset + 3].to_int()
        pixels[out_idx + 3] = a.to_byte()
      }
    }
  }
  @types.Image::{
    width: abs_width,
    height: abs_height,
    channels: out_channels,
    data: Bytes::from_array(pixels),
  }
}

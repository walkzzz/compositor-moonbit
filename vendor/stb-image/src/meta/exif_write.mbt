// EXIF 元数据写入（纯 MoonBit）
// 支持将 ExifInfo 写入 JPEG 字节流

///|
fn write_u16_be(buf : Array[Byte], val : Int) -> Unit {
  buf.push(((val >> 8) & 0xFF).to_byte())
  buf.push((val & 0xFF).to_byte())
}

///|
fn write_u32_be(buf : Array[Byte], val : Int) -> Unit {
  buf.push(((val >> 24) & 0xFF).to_byte())
  buf.push(((val >> 16) & 0xFF).to_byte())
  buf.push(((val >> 8) & 0xFF).to_byte())
  buf.push((val & 0xFF).to_byte())
}

///|
fn string_to_exif_bytes(s : String) -> Bytes {
  let buf : Array[Byte] = []
  for c in s.to_array() {
    let code = c.to_int()
    if code < 128 {
      buf.push(code.to_byte())
    } else {
      buf.push(b'?')
    }
  }
  buf.push(b'\x00')
  Bytes::from_array(buf)
}

///|
/// 构造 EXIF APP1 segment 数据（不含 FF E1 前缀和长度）。
/// 返回 "Exif\0\0" + TIFF 头(大端) + IFD0 + 数据区
pub fn create_exif_segment(info : ExifInfo) -> Bytes {
  let make_bytes = string_to_exif_bytes(info.make)
  let model_bytes = string_to_exif_bytes(info.model)
  let dt_bytes = string_to_exif_bytes(info.date_time)
  let make_count = make_bytes.length()
  let model_count = model_bytes.length()
  let dt_count = dt_bytes.length()
  let entry_count = 4
  let ifd0_size = 2 + entry_count * 12 + 4
  let data_start = 8 + ifd0_size
  let mut offset = data_start
  let make_offset = if make_count <= 4 {
    -1
  } else {
    let o = offset
    offset += make_count
    o
  }
  let model_offset = if model_count <= 4 {
    -1
  } else {
    let o = offset
    offset += model_count
    o
  }
  let dt_offset = if dt_count <= 4 {
    -1
  } else {
    let o = offset
    offset += dt_count
    o
  }
  let buf : Array[Byte] = []
  buf.push(b'E')
  buf.push(b'x')
  buf.push(b'i')
  buf.push(b'f')
  buf.push(b'\x00')
  buf.push(b'\x00')
  buf.push(b'M')
  buf.push(b'M')
  buf.push(b'\x00')
  buf.push(b'\x2A')
  buf.push(b'\x00')
  buf.push(b'\x00')
  buf.push(b'\x00')
  buf.push(b'\x08')
  write_u16_be(buf, entry_count)
  write_u16_be(buf, 0x010F)
  write_u16_be(buf, 2)
  write_u32_be(buf, make_count)
  if make_count <= 4 {
    for j in 0..<make_count {
      buf.push(make_bytes[j])
    }
    for _ in make_count..<4 {
      buf.push(b'\x00')
    }
  } else {
    write_u32_be(buf, make_offset)
  }
  write_u16_be(buf, 0x0110)
  write_u16_be(buf, 2)
  write_u32_be(buf, model_count)
  if model_count <= 4 {
    for j in 0..<model_count {
      buf.push(model_bytes[j])
    }
    for _ in model_count..<4 {
      buf.push(b'\x00')
    }
  } else {
    write_u32_be(buf, model_offset)
  }
  write_u16_be(buf, 0x0112)
  write_u16_be(buf, 3)
  write_u32_be(buf, 1)
  write_u16_be(buf, info.orientation)
  buf.push(b'\x00')
  buf.push(b'\x00')
  write_u16_be(buf, 0x0132)
  write_u16_be(buf, 2)
  write_u32_be(buf, dt_count)
  if dt_count <= 4 {
    for j in 0..<dt_count {
      buf.push(dt_bytes[j])
    }
    for _ in dt_count..<4 {
      buf.push(b'\x00')
    }
  } else {
    write_u32_be(buf, dt_offset)
  }
  write_u32_be(buf, 0)
  if make_count > 4 {
    for j in 0..<make_count {
      buf.push(make_bytes[j])
    }
  }
  if model_count > 4 {
    for j in 0..<model_count {
      buf.push(model_bytes[j])
    }
  }
  if dt_count > 4 {
    for j in 0..<dt_count {
      buf.push(dt_bytes[j])
    }
  }
  Bytes::from_array(buf)
}

///|
/// 将 EXIF 元数据写入 JPEG 字节流。
/// 在 SOI (FF D8) 之后插入 APP1 segment。
/// 如果已有 APP1 EXIF segment，替换之。
pub fn write_exif_to_bytes(
  info : ExifInfo,
  jpeg_data : Bytes,
) -> Bytes raise @types.LoadError {
  let len = jpeg_data.length()
  if len < 2 || jpeg_data[0].to_int() != 0xFF || jpeg_data[1].to_int() != 0xD8 {
    raise @types.LoadError::DecodeFailed("Not a valid JPEG: missing SOI marker")
  }
  let exif_data = create_exif_segment(info)
  let exif_len = exif_data.length()
  let app1_size = exif_len + 2
  let mut pos = 2
  let mut existing_app1_end = -1
  while pos < len - 1 {
    if jpeg_data[pos].to_int() == 0xFF {
      let marker = jpeg_data[pos + 1].to_int()
      if marker == 0xE1 {
        let seg_len = jpeg_data[pos + 2].to_int() * 256 +
          jpeg_data[pos + 3].to_int()
        existing_app1_end = pos + 2 + seg_len
        break
      }
      if marker == 0xDA || marker == 0xD9 {
        break
      }
      if marker == 0x00 || (marker >= 0xD0 && marker <= 0xD7) {
        pos += 2
      } else {
        let seg_len = jpeg_data[pos + 2].to_int() * 256 +
          jpeg_data[pos + 3].to_int()
        pos += 2 + seg_len
      }
    } else {
      pos += 1
    }
  }
  let result : Array[Byte] = []
  result.push(b'\xFF')
  result.push(b'\xD8')
  result.push(b'\xFF')
  result.push(b'\xE1')
  write_u16_be(result, app1_size)
  for i in 0..<exif_len {
    result.push(exif_data[i])
  }
  let rest_start = if existing_app1_end >= 0 { existing_app1_end } else { 2 }
  for i in rest_start..<len {
    result.push(jpeg_data[i])
  }
  Bytes::from_array(result)
}

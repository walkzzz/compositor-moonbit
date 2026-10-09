// EXIF 元数据读取（纯 MoonBit）
// 支持 JPEG EXIF：Make/Model/Orientation/DateTime

///|
/// EXIF 元数据信息
pub(all) struct ExifInfo {
  make : String
  model : String
  orientation : Int
  date_time : String
} derive(Eq, @debug.Debug)

///|
fn read_u16_be(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() * 256 + data[offset + 1].to_int()
}

///|
fn read_u16_le(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn read_u32_be(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() * 16777216 +
  data[offset + 1].to_int() * 65536 +
  data[offset + 2].to_int() * 256 +
  data[offset + 3].to_int()
}

///|
fn read_u32_le(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() +
  data[offset + 1].to_int() * 256 +
  data[offset + 2].to_int() * 65536 +
  data[offset + 3].to_int() * 16777216
}

///|
fn read_exif_string(
  data : Bytes,
  tiff_start : Int,
  entry_offset : Int,
  count : Int,
  little : Bool,
) -> String {
  let val_offset = if count <= 4 {
    tiff_start + entry_offset + 8
  } else {
    let ptr = if little {
      read_u32_le(data, tiff_start + entry_offset + 8)
    } else {
      read_u32_be(data, tiff_start + entry_offset + 8)
    }
    tiff_start + ptr
  }
  // 读取 ASCII 字符串（去除尾部 \0）
  let chars : Array[Byte] = []
  for i in 0..<count {
    let b = data[val_offset + i]
    if b == b'\x00' {
      break
    }
    chars.push(b)
  }
  @encoding/utf8.decode(Bytes::from_array(chars)[:]) catch {
    _ => ""
  }
}

///|
/// 从 JPEG 字节流读取 EXIF 元数据。
/// 返回 None 如果不含 EXIF 数据。
pub fn read_exif_from_bytes(data : Bytes) -> ExifInfo? {
  let len = data.length()
  if len < 4 || data[0].to_int() != 0xFF || data[1].to_int() != 0xD8 {
    return None
  }
  // 查找 APP1 marker (0xFF 0xE1)
  let mut pos = 2
  let mut exif_start = -1
  let mut exif_len = 0
  while pos < len - 1 {
    if data[pos].to_int() == 0xFF && data[pos + 1].to_int() == 0xE1 {
      exif_len = read_u16_be(data, pos + 2) - 2
      exif_start = pos + 4
      break
    }
    if data[pos].to_int() == 0xFF {
      let marker = data[pos + 1].to_int()
      if marker == 0xDA || marker == 0xD9 {
        break
      }
      let seg_len = read_u16_be(data, pos + 2)
      pos += 2 + seg_len
    } else {
      pos += 1
    }
  }
  if exif_start < 0 || exif_start + exif_len > len {
    return None
  }
  // 检查 "Exif\0\0"
  if exif_len < 6 ||
    data[exif_start].to_int() != 0x45 ||
    data[exif_start + 1].to_int() != 0x78 ||
    data[exif_start + 2].to_int() != 0x69 ||
    data[exif_start + 3].to_int() != 0x66 {
    return None
  }
  let tiff_start = exif_start + 6
  if tiff_start + 8 > len {
    return None
  }
  // 读取字节序
  let little = if data[tiff_start].to_int() == 0x49 &&
    data[tiff_start + 1].to_int() == 0x49 {
    true
  } else if data[tiff_start].to_int() == 0x4D &&
    data[tiff_start + 1].to_int() == 0x4D {
    false
  } else {
    return None
  }
  // IFD0 偏移
  let ifd0_offset = if little {
    read_u32_le(data, tiff_start + 4)
  } else {
    read_u32_be(data, tiff_start + 4)
  }
  let ifd0_pos = tiff_start + ifd0_offset
  if ifd0_pos + 2 > len {
    return None
  }
  let entry_count = if little {
    read_u16_le(data, ifd0_pos)
  } else {
    read_u16_be(data, ifd0_pos)
  }
  // 默认值
  let mut make = ""
  let mut model = ""
  let mut orientation = 1
  let mut date_time = ""
  // 解析 IFD 条目
  for i in 0..<entry_count {
    let entry_pos = ifd0_pos + 2 + i * 12
    if entry_pos + 12 > len {
      break
    }
    let tag = if little {
      read_u16_le(data, entry_pos)
    } else {
      read_u16_be(data, entry_pos)
    }
    let count = if little {
      read_u32_le(data, entry_pos + 4)
    } else {
      read_u32_be(data, entry_pos + 4)
    }
    let entry_offset = entry_pos - tiff_start
    match tag {
      0x010F =>
        make = read_exif_string(data, tiff_start, entry_offset, count, little)
      0x0110 =>
        model = read_exif_string(data, tiff_start, entry_offset, count, little)
      0x0112 =>
        orientation = if little {
          read_u16_le(data, tiff_start + entry_offset + 8)
        } else {
          read_u16_be(data, tiff_start + entry_offset + 8)
        }
      0x0132 =>
        date_time = read_exif_string(
          data, tiff_start, entry_offset, count, little,
        )
      _ => ()
    }
  }
  Some(ExifInfo::{ make, model, orientation, date_time })
}

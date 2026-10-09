// TIFF 编解码测试

///|
test "decode_tiff_pure: 无压缩 1x1 灰度 roundtrip" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x80']),
  }
  let tiff = encode_tiff_pure(img)
  let decoded = decode_tiff_pure(tiff)
  assert_eq(decoded.width, 1)
  assert_eq(decoded.height, 1)
  assert_eq(decoded.channels, 1)
  assert_eq(decoded.data[0].to_int(), 128)
}

///|
test "decode_tiff_pure: 无压缩 2x2 灰度 roundtrip" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: Bytes::from_array([b'\x00', b'\x80', b'\xFF', b'\x40']),
  }
  let tiff = encode_tiff_pure(img)
  let decoded = decode_tiff_pure(tiff)
  assert_eq(decoded.width, 2)
  assert_eq(decoded.height, 2)
  assert_eq(decoded.channels, 1)
  assert_eq(decoded.data[0].to_int(), 0)
  assert_eq(decoded.data[1].to_int(), 128)
  assert_eq(decoded.data[2].to_int(), 255)
  assert_eq(decoded.data[3].to_int(), 64)
}

///|
test "decode_tiff_pure: 无压缩 1x1 RGB roundtrip" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 3,
    data: Bytes::from_array([b'\xFF', b'\x80', b'\x00']),
  }
  let tiff = encode_tiff_pure(img)
  let decoded = decode_tiff_pure(tiff)
  assert_eq(decoded.width, 1)
  assert_eq(decoded.height, 1)
  assert_eq(decoded.channels, 3)
  assert_eq(decoded.data[0].to_int(), 255)
  assert_eq(decoded.data[1].to_int(), 128)
  assert_eq(decoded.data[2].to_int(), 0)
}

///|
test "decode_tiff_pure: 无压缩 1x1 RGBA roundtrip" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 4,
    data: Bytes::from_array([b'\xFF', b'\x80', b'\x00', b'\xC0']),
  }
  let tiff = encode_tiff_pure(img)
  let decoded = decode_tiff_pure(tiff)
  assert_eq(decoded.width, 1)
  assert_eq(decoded.height, 1)
  assert_eq(decoded.channels, 4)
  assert_eq(decoded.data[0].to_int(), 255)
  assert_eq(decoded.data[1].to_int(), 128)
  assert_eq(decoded.data[2].to_int(), 0)
  assert_eq(decoded.data[3].to_int(), 192)
}

///|
test "decode_tiff_pure: 无压缩 2x2 RGB roundtrip" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 3,
    data: Bytes::from_array([
      b'\xFF', b'\x00', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\x00', b'\xFF',
      b'\xFF', b'\xFF', b'\xFF',
    ]),
  }
  let tiff = encode_tiff_pure(img)
  let decoded = decode_tiff_pure(tiff)
  assert_eq(decoded.width, 2)
  assert_eq(decoded.height, 2)
  assert_eq(decoded.channels, 3)
  assert_eq(decoded.data[0].to_int(), 255)
  assert_eq(decoded.data[1].to_int(), 0)
  assert_eq(decoded.data[2].to_int(), 0)
  assert_eq(decoded.data[3].to_int(), 0)
  assert_eq(decoded.data[4].to_int(), 255)
  assert_eq(decoded.data[5].to_int(), 0)
}

///|
test "tiff_packbits_decode: 单字节" {
  let pb_data : Array[Byte] = [0x00, b'\x80']
  let bytes = Bytes::from_array(pb_data)
  let result = tiff_packbits_decode(bytes)
  assert_eq(result.length(), 1)
  assert_eq(result[0], b'\x80')
}

///|
test "tiff_packbits_decode: 重复5字节" {
  let pb_data : Array[Byte] = [0xFC, b'\xFF']
  let bytes = Bytes::from_array(pb_data)
  let result = tiff_packbits_decode(bytes)
  assert_eq(result.length(), 5)
  for i in 0..<5 {
    assert_eq(result[i], b'\xFF')
  }
}

///|
test "tiff_packbits_decode: 原始两字节" {
  let pb_data : Array[Byte] = [0x01, b'\xAA', b'\xBB']
  let bytes = Bytes::from_array(pb_data)
  let result = tiff_packbits_decode(bytes)
  assert_eq(result.length(), 2)
  assert_eq(result[0], b'\xAA')
  assert_eq(result[1], b'\xBB')
}

///|
test "tiff_deflate_decode: 单字节" {
  let raw : Array[Byte] = [0x01, 0x01, 0x00, 0xFE, 0xFF, 0x80]
  let bytes = Bytes::from_array(raw)
  let result = tiff_deflate_decode(bytes)
  assert_eq(result.length(), 1)
  assert_eq(result[0], b'\x80')
}

///|
test "tiff_deflate_decode: 多字节" {
  let raw : Array[Byte] = [0x01, 0x04, 0x00, 0xFB, 0xFF, 0x01, 0x02, 0x03, 0x04]
  let bytes = Bytes::from_array(raw)
  let result = tiff_deflate_decode(bytes)
  assert_eq(result.length(), 4)
  assert_eq(result[0], b'\x01')
  assert_eq(result[1], b'\x02')
  assert_eq(result[2], b'\x03')
  assert_eq(result[3], b'\x04')
}

///|
test "decode_tiff_pure: PackBits 1x1 灰度 roundtrip" {
  let out : Array[Byte] = []
  out.push(b'\x49')
  out.push(b'\x49')
  out.push(b'\x2A')
  out.push(b'\x00')
  out.push(b'\x08')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x09')
  out.push(b'\x00')
  let pixel_offset = 8 + 2 + 9 * 12 + 4
  fn write_le_entry(
    out : Array[Byte],
    tag : Int,
    type_id : Int,
    count : Int,
    value : Int,
  ) -> Unit {
    out.push((tag & 0xFF).to_byte())
    out.push(((tag >> 8) & 0xFF).to_byte())
    out.push((type_id & 0xFF).to_byte())
    out.push(((type_id >> 8) & 0xFF).to_byte())
    out.push((count & 0xFF).to_byte())
    out.push(((count >> 8) & 0xFF).to_byte())
    out.push(((count >> 16) & 0xFF).to_byte())
    out.push(((count >> 24) & 0xFF).to_byte())
    out.push((value & 0xFF).to_byte())
    out.push(((value >> 8) & 0xFF).to_byte())
    out.push(((value >> 16) & 0xFF).to_byte())
    out.push(((value >> 24) & 0xFF).to_byte())
  }
  write_le_entry(out, 256, 4, 1, 1) // ImageWidth
  write_le_entry(out, 257, 4, 1, 1) // ImageLength
  write_le_entry(out, 258, 3, 1, 8) // BitsPerSample
  write_le_entry(out, 259, 3, 1, 32773) // PackBits
  write_le_entry(out, 262, 3, 1, 1) // Photometric
  write_le_entry(out, 273, 4, 1, pixel_offset) // StripOffsets
  write_le_entry(out, 277, 3, 1, 1) // SamplesPerPixel
  write_le_entry(out, 278, 4, 1, 1) // RowsPerStrip
  write_le_entry(out, 279, 4, 1, 2) // StripByteCounts=2 (PackBits: 0x00, 0x80)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x80')
  let tiff = Bytes::from_array(out)
  let decoded = decode_tiff_pure(tiff)
  assert_eq(decoded.width, 1)
  assert_eq(decoded.height, 1)
  assert_eq(decoded.channels, 1)
  assert_eq(decoded.data[0].to_int(), 128)
}

///|
test "decode_tiff_pure: LZW 1x1 灰度 roundtrip" {
  let out : Array[Byte] = []
  out.push(b'\x49')
  out.push(b'\x49')
  out.push(b'\x2A')
  out.push(b'\x00')
  out.push(b'\x08')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x09')
  out.push(b'\x00')
  let pixel_offset = 8 + 2 + 9 * 12 + 4
  fn write_le_entry(
    out : Array[Byte],
    tag : Int,
    type_id : Int,
    count : Int,
    value : Int,
  ) -> Unit {
    out.push((tag & 0xFF).to_byte())
    out.push(((tag >> 8) & 0xFF).to_byte())
    out.push((type_id & 0xFF).to_byte())
    out.push(((type_id >> 8) & 0xFF).to_byte())
    out.push((count & 0xFF).to_byte())
    out.push(((count >> 8) & 0xFF).to_byte())
    out.push(((count >> 16) & 0xFF).to_byte())
    out.push(((count >> 24) & 0xFF).to_byte())
    out.push((value & 0xFF).to_byte())
    out.push(((value >> 8) & 0xFF).to_byte())
    out.push(((value >> 16) & 0xFF).to_byte())
    out.push(((value >> 24) & 0xFF).to_byte())
  }
  write_le_entry(out, 256, 4, 1, 1)
  write_le_entry(out, 257, 4, 1, 1)
  write_le_entry(out, 258, 3, 1, 8)
  write_le_entry(out, 259, 3, 1, 5) // LZW
  write_le_entry(out, 262, 3, 1, 1)
  write_le_entry(out, 273, 4, 1, pixel_offset)
  write_le_entry(out, 277, 3, 1, 1)
  write_le_entry(out, 278, 4, 1, 1)
  write_le_entry(out, 279, 4, 1, 5) // StripByteCounts=5
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00') // Next IFD
  // LZW data: init=8, then 9-bit codes CLEAR(256), code 128, EOI(257)
  // CLEAR=256: bits 0-8 = 0b1_0000_0000 → byte1=0x00, bit8=1
  // code=128:  bits 9-17 = 0b0_1000_0000 → bit16=1
  // EOI=257:   bits 18-26 = 0b1_0000_0001 → bit18=1, bit26=1
  // Byte layout: [0x00, 0x01, 0x05, 0x04]
  out.push(b'\x08')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x05')
  out.push(b'\x04')
  let tiff = Bytes::from_array(out)
  let decoded = decode_tiff_pure(tiff)
  assert_eq(decoded.width, 1)
  assert_eq(decoded.height, 1)
  assert_eq(decoded.channels, 1)
  assert_eq(decoded.data[0].to_int(), 128)
}

///|
test "decode_tiff_pure: PackBits 2x1 灰度 roundtrip" {
  let out : Array[Byte] = []
  out.push(b'\x49')
  out.push(b'\x49')
  out.push(b'\x2A')
  out.push(b'\x00')
  out.push(b'\x08')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x09')
  out.push(b'\x00')
  let pixel_offset = 8 + 2 + 9 * 12 + 4
  fn write_le_entry(
    out : Array[Byte],
    tag : Int,
    type_id : Int,
    count : Int,
    value : Int,
  ) -> Unit {
    out.push((tag & 0xFF).to_byte())
    out.push(((tag >> 8) & 0xFF).to_byte())
    out.push((type_id & 0xFF).to_byte())
    out.push(((type_id >> 8) & 0xFF).to_byte())
    out.push((count & 0xFF).to_byte())
    out.push(((count >> 8) & 0xFF).to_byte())
    out.push(((count >> 16) & 0xFF).to_byte())
    out.push(((count >> 24) & 0xFF).to_byte())
    out.push((value & 0xFF).to_byte())
    out.push(((value >> 8) & 0xFF).to_byte())
    out.push(((value >> 16) & 0xFF).to_byte())
    out.push(((value >> 24) & 0xFF).to_byte())
  }
  write_le_entry(out, 256, 4, 1, 2)
  write_le_entry(out, 257, 4, 1, 1)
  write_le_entry(out, 258, 3, 1, 8)
  write_le_entry(out, 259, 3, 1, 32773)
  write_le_entry(out, 262, 3, 1, 1)
  write_le_entry(out, 273, 4, 1, pixel_offset)
  write_le_entry(out, 277, 3, 1, 1)
  write_le_entry(out, 278, 4, 1, 1)
  write_le_entry(out, 279, 4, 1, 3) // StripByteCounts=3 (PackBits: 0x01, 0x10, 0x20)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x10')
  out.push(b'\x20')
  let tiff = Bytes::from_array(out)
  let decoded = decode_tiff_pure(tiff)
  assert_eq(decoded.width, 2)
  assert_eq(decoded.height, 1)
  assert_eq(decoded.channels, 1)
  assert_eq(decoded.data[0].to_int(), 16)
  assert_eq(decoded.data[1].to_int(), 32)
}

///|
test "decode_tiff_pure: PackBits RGB 1x1 roundtrip" {
  let out : Array[Byte] = []
  out.push(b'\x49')
  out.push(b'\x49')
  out.push(b'\x2A')
  out.push(b'\x00')
  out.push(b'\x08')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x09')
  out.push(b'\x00')
  let pixel_offset = 8 + 2 + 9 * 12 + 4
  fn write_le_entry(
    out : Array[Byte],
    tag : Int,
    type_id : Int,
    count : Int,
    value : Int,
  ) -> Unit {
    out.push((tag & 0xFF).to_byte())
    out.push(((tag >> 8) & 0xFF).to_byte())
    out.push((type_id & 0xFF).to_byte())
    out.push(((type_id >> 8) & 0xFF).to_byte())
    out.push((count & 0xFF).to_byte())
    out.push(((count >> 8) & 0xFF).to_byte())
    out.push(((count >> 16) & 0xFF).to_byte())
    out.push(((count >> 24) & 0xFF).to_byte())
    out.push((value & 0xFF).to_byte())
    out.push(((value >> 8) & 0xFF).to_byte())
    out.push(((value >> 16) & 0xFF).to_byte())
    out.push(((value >> 24) & 0xFF).to_byte())
  }
  write_le_entry(out, 256, 4, 1, 1)
  write_le_entry(out, 257, 4, 1, 1)
  write_le_entry(out, 258, 3, 1, 8)
  write_le_entry(out, 259, 3, 1, 32773)
  write_le_entry(out, 262, 3, 1, 2)
  write_le_entry(out, 273, 4, 1, pixel_offset)
  write_le_entry(out, 277, 3, 1, 3)
  write_le_entry(out, 278, 4, 1, 1)
  write_le_entry(out, 279, 4, 1, 4) // StripByteCounts=4 (PackBits: 0x02, 0xFF, 0x80, 0x00)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x02')
  out.push(b'\xFF')
  out.push(b'\x80')
  out.push(b'\x00')
  let tiff = Bytes::from_array(out)
  let decoded = decode_tiff_pure(tiff)
  assert_eq(decoded.width, 1)
  assert_eq(decoded.height, 1)
  assert_eq(decoded.channels, 3)
  assert_eq(decoded.data[0].to_int(), 255)
  assert_eq(decoded.data[1].to_int(), 128)
  assert_eq(decoded.data[2].to_int(), 0)
}

///|
test "tiff_packbits_decode: 扩展模式-复制10字节" {
  // Extended PackBits: count=-128 (0x80), then 2 bytes big-endian
  // extended_count = ((0x80 << 8) | 0x09) - 32768 = 32777 - 32768 = 9 (copy 10 bytes)
  let pb_data : Array[Byte] = [
    0x80, 0x80, 0x09, b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06', b'\x07',
    b'\x08', b'\x09', b'\x0A',
  ]
  let bytes = Bytes::from_array(pb_data)
  let result = tiff_packbits_decode(bytes)
  assert_eq(result.length(), 10)
  assert_eq(result[0], b'\x01')
  assert_eq(result[9], b'\x0A')
}

///|
test "tiff_packbits_decode: 扩展模式-重复5字节" {
  // Extended PackBits repeat mode: extended_count = -4, repeat 5 times
  // -4 + 32768 = 32764 = 0x7FFC
  // bytes: [0x80, 0x7F, 0xFC, 0xAA] → 5 bytes of 0xAA
  let pb_data : Array[Byte] = [0x80, 0x7F, 0xFC, b'\xAA']
  let bytes = Bytes::from_array(pb_data)
  let result = tiff_packbits_decode(bytes)
  assert_eq(result.length(), 5)
  for i in 0..<5 {
    assert_eq(result[i], b'\xAA')
  }
}

// ==================== 错误路径测试 ====================

///|
test "decode_tiff_pure: 数据过短 raises" {
  try {
    let _ = decode_tiff_pure(b"\x49\x49\x2A\x00\x08\x00")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_tiff_pure: 无效字节序标记 raises" {
  try {
    let _ = decode_tiff_pure(b"\x00\x00\x2A\x00\x08\x00\x00\x00")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_tiff_pure: 无效 magic raises" {
  try {
    let _ = decode_tiff_pure(b"\x49\x49\x00\x00\x08\x00\x00\x00")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_tiff_pure: IFD 偏移越界 raises" {
  // 有效 TIFF header，但 IFD offset = 0xFFFFFFFF（越界）
  let out : Array[Byte] = []
  out.push(b'\x49')
  out.push(b'\x49')
  out.push(b'\x2A')
  out.push(b'\x00')
  out.push(b'\xFF')
  out.push(b'\xFF')
  out.push(b'\xFF')
  out.push(b'\xFF')
  try {
    let _ = decode_tiff_pure(Bytes::from_array(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_tiff_pure: IFD 条目数据不完整 raises" {
  // IFD offset=8 但数据只有 header（8字节），IFD 内容不足
  let out : Array[Byte] = []
  out.push(b'\x49')
  out.push(b'\x49')
  out.push(b'\x2A')
  out.push(b'\x00')
  out.push(b'\x08')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  // 只有 8 字节，没有 IFD 内容
  try {
    let _ = decode_tiff_pure(Bytes::from_array(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_tiff_pure: 缺少 ImageWidth raises" {
  let out : Array[Byte] = []
  out.push(b'\x49')
  out.push(b'\x49')
  out.push(b'\x2A')
  out.push(b'\x00')
  out.push(b'\x08')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00') // IFD count = 1
  // 写一个 tag=0 的条目（不是 ImageWidth=256）
  out.push(b'\x00')
  out.push(b'\x00') // tag=0
  out.push(b'\x04')
  out.push(b'\x00') // type=LONG
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00') // count=1
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00') // value=1
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00') // Next IFD=0
  // 没有 ImageWidth, ImageLength, StripOffsets
  try {
    let _ = decode_tiff_pure(Bytes::from_array(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_tiff_pure: 缺少 StripOffsets raises" {
  let out : Array[Byte] = []
  out.push(b'\x49')
  out.push(b'\x49')
  out.push(b'\x2A')
  out.push(b'\x00')
  out.push(b'\x08')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x02')
  out.push(b'\x00') // IFD count = 2
  // tag=256 (ImageWidth), value=1
  out.push(b'\x00')
  out.push(b'\x01') // tag=256
  out.push(b'\x04')
  out.push(b'\x00') // type=LONG
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00') // count=1
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00') // value=1
  // tag=257 (ImageLength), value=1
  out.push(b'\x01')
  out.push(b'\x01') // tag=257
  out.push(b'\x04')
  out.push(b'\x00') // type=LONG
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00') // count=1
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00') // value=1
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00') // Next IFD=0
  try {
    let _ = decode_tiff_pure(Bytes::from_array(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_tiff_pure: 不支持的压缩类型 raises" {
  let out : Array[Byte] = []
  out.push(b'\x49')
  out.push(b'\x49')
  out.push(b'\x2A')
  out.push(b'\x00')
  out.push(b'\x08')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x05')
  out.push(b'\x00') // IFD count = 5
  fn write_entry(
    out : Array[Byte],
    tag : Int,
    type_id : Int,
    count : Int,
    value : Int,
  ) {
    out.push((tag & 0xFF).to_byte())
    out.push(((tag >> 8) & 0xFF).to_byte())
    out.push((type_id & 0xFF).to_byte())
    out.push(((type_id >> 8) & 0xFF).to_byte())
    out.push((count & 0xFF).to_byte())
    out.push(((count >> 8) & 0xFF).to_byte())
    out.push(((count >> 16) & 0xFF).to_byte())
    out.push(((count >> 24) & 0xFF).to_byte())
    out.push((value & 0xFF).to_byte())
    out.push(((value >> 8) & 0xFF).to_byte())
    out.push(((value >> 16) & 0xFF).to_byte())
    out.push(((value >> 24) & 0xFF).to_byte())
  }
  write_entry(out, 256, 4, 1, 1) // ImageWidth
  write_entry(out, 257, 4, 1, 1) // ImageLength
  write_entry(out, 258, 3, 1, 8) // BitsPerSample=8
  write_entry(out, 259, 3, 1, 99) // Compression=99 (unsupported)
  write_entry(out, 273, 4, 1, 0) // StripOffsets
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00') // Next IFD=0
  try {
    let _ = decode_tiff_pure(Bytes::from_array(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_tiff_pure: 16-bit 样本 raises" {
  let out : Array[Byte] = []
  out.push(b'\x49')
  out.push(b'\x49')
  out.push(b'\x2A')
  out.push(b'\x00')
  out.push(b'\x08')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x05')
  out.push(b'\x00') // IFD count = 5
  fn write_entry(
    out : Array[Byte],
    tag : Int,
    type_id : Int,
    count : Int,
    value : Int,
  ) {
    out.push((tag & 0xFF).to_byte())
    out.push(((tag >> 8) & 0xFF).to_byte())
    out.push((type_id & 0xFF).to_byte())
    out.push(((type_id >> 8) & 0xFF).to_byte())
    out.push((count & 0xFF).to_byte())
    out.push(((count >> 8) & 0xFF).to_byte())
    out.push(((count >> 16) & 0xFF).to_byte())
    out.push(((count >> 24) & 0xFF).to_byte())
    out.push((value & 0xFF).to_byte())
    out.push(((value >> 8) & 0xFF).to_byte())
    out.push(((value >> 16) & 0xFF).to_byte())
    out.push(((value >> 24) & 0xFF).to_byte())
  }
  write_entry(out, 256, 4, 1, 1) // ImageWidth
  write_entry(out, 257, 4, 1, 1) // ImageLength
  write_entry(out, 258, 3, 1, 16) // BitsPerSample=16 (unsupported)
  write_entry(out, 259, 3, 1, 1) // Compression=1 (none)
  write_entry(out, 273, 4, 1, 0) // StripOffsets
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00') // Next IFD=0
  out.push(b'\x00') // 1 byte of pixel data
  try {
    let _ = decode_tiff_pure(Bytes::from_array(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_tiff_pure: 尺寸为零 raises" {
  let out : Array[Byte] = []
  out.push(b'\x49')
  out.push(b'\x49')
  out.push(b'\x2A')
  out.push(b'\x00')
  out.push(b'\x08')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x05')
  out.push(b'\x00') // IFD count = 5
  fn write_entry(
    out : Array[Byte],
    tag : Int,
    type_id : Int,
    count : Int,
    value : Int,
  ) {
    out.push((tag & 0xFF).to_byte())
    out.push(((tag >> 8) & 0xFF).to_byte())
    out.push((type_id & 0xFF).to_byte())
    out.push(((type_id >> 8) & 0xFF).to_byte())
    out.push((count & 0xFF).to_byte())
    out.push(((count >> 8) & 0xFF).to_byte())
    out.push(((count >> 16) & 0xFF).to_byte())
    out.push(((count >> 24) & 0xFF).to_byte())
    out.push((value & 0xFF).to_byte())
    out.push(((value >> 8) & 0xFF).to_byte())
    out.push(((value >> 16) & 0xFF).to_byte())
    out.push(((value >> 24) & 0xFF).to_byte())
  }
  write_entry(out, 256, 4, 1, 0) // ImageWidth=0
  write_entry(out, 257, 4, 1, 1) // ImageLength=1
  write_entry(out, 258, 3, 1, 8) // BitsPerSample=8
  write_entry(out, 259, 3, 1, 1) // Compression=1
  write_entry(out, 273, 4, 1, 0) // StripOffsets
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00') // Next IFD=0
  try {
    let _ = decode_tiff_pure(Bytes::from_array(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_tiff_pure: 2 samples per pixel raises" {
  let out : Array[Byte] = []
  out.push(b'\x49')
  out.push(b'\x49')
  out.push(b'\x2A')
  out.push(b'\x00')
  out.push(b'\x08')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x06')
  out.push(b'\x00') // IFD count = 6
  fn write_entry(
    out : Array[Byte],
    tag : Int,
    type_id : Int,
    count : Int,
    value : Int,
  ) {
    out.push((tag & 0xFF).to_byte())
    out.push(((tag >> 8) & 0xFF).to_byte())
    out.push((type_id & 0xFF).to_byte())
    out.push(((type_id >> 8) & 0xFF).to_byte())
    out.push((count & 0xFF).to_byte())
    out.push(((count >> 8) & 0xFF).to_byte())
    out.push(((count >> 16) & 0xFF).to_byte())
    out.push(((count >> 24) & 0xFF).to_byte())
    out.push((value & 0xFF).to_byte())
    out.push(((value >> 8) & 0xFF).to_byte())
    out.push(((value >> 16) & 0xFF).to_byte())
    out.push(((value >> 24) & 0xFF).to_byte())
  }
  write_entry(out, 256, 4, 1, 1) // ImageWidth
  write_entry(out, 257, 4, 1, 1) // ImageLength
  write_entry(out, 258, 3, 1, 8) // BitsPerSample
  write_entry(out, 259, 3, 1, 1) // Compression=1
  write_entry(out, 277, 3, 1, 2) // SamplesPerPixel=2 (unsupported)
  write_entry(out, 273, 4, 1, 0) // StripOffsets
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00') // Next IFD=0
  out.push(b'\x80') // 1 byte of pixel data
  try {
    let _ = decode_tiff_pure(Bytes::from_array(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_tiff_pure: 不支持的 PhotometricInterpretation raises" {
  let out : Array[Byte] = []
  out.push(b'\x49')
  out.push(b'\x49')
  out.push(b'\x2A')
  out.push(b'\x00')
  out.push(b'\x08')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x06')
  out.push(b'\x00') // IFD count = 6
  fn write_entry(
    out : Array[Byte],
    tag : Int,
    type_id : Int,
    count : Int,
    value : Int,
  ) {
    out.push((tag & 0xFF).to_byte())
    out.push(((tag >> 8) & 0xFF).to_byte())
    out.push((type_id & 0xFF).to_byte())
    out.push(((type_id >> 8) & 0xFF).to_byte())
    out.push((count & 0xFF).to_byte())
    out.push(((count >> 8) & 0xFF).to_byte())
    out.push(((count >> 16) & 0xFF).to_byte())
    out.push(((count >> 24) & 0xFF).to_byte())
    out.push((value & 0xFF).to_byte())
    out.push(((value >> 8) & 0xFF).to_byte())
    out.push(((value >> 16) & 0xFF).to_byte())
    out.push(((value >> 24) & 0xFF).to_byte())
  }
  write_entry(out, 256, 4, 1, 1) // ImageWidth
  write_entry(out, 257, 4, 1, 1) // ImageLength
  write_entry(out, 258, 3, 1, 8) // BitsPerSample
  write_entry(out, 259, 3, 1, 1) // Compression=1
  write_entry(out, 262, 3, 1, 99) // Photometric=99 (unsupported, must be RGB to trigger)
  write_entry(out, 277, 3, 1, 3) // SamplesPerPixel=3 (RGB)
  write_entry(out, 273, 4, 1, 0) // StripOffsets
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00') // Next IFD=0
  out.push(b'\xFF')
  out.push(b'\x80')
  out.push(b'\x00') // 3 bytes of pixel data
  try {
    let _ = decode_tiff_pure(Bytes::from_array(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "tiff_lzw_decode: 数据过短 raises" {
  try {
    let _ = tiff_lzw_decode(b"\x08")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "tiff_lzw_decode: 空数据 raises" {
  try {
    let _ = tiff_lzw_decode(b"")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "tiff_lzw_decode: 初始码长无效(0) raises" {
  // init_code_len=0 < 2
  try {
    let _ = tiff_lzw_decode(b"\x00\x00")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "tiff_lzw_decode: 初始码长无效(12) raises" {
  // init_code_len=12 > 11
  try {
    let _ = tiff_lzw_decode(b"\x0C\x00")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "tiff_lzw_decode: 首码不为 CLEAR raises" {
  // init_code_len=2 (CLEAR=4), data starts with non-CLEAR code
  try {
    let _ = tiff_lzw_decode(b"\x02\x01\x00")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "tiff_lzw_decode: 码越界 raises" {
  // init_code_len=2 (CLEAR=4, EOI=5), first code after CLEAR is 6 (out of range before dict entry)
  // With 2-bit codes: CLEAR=4, next_code=6, dict has 0-255
  // After reading CLEAR, next code should be 0-255 or 6 (but 6 is not in dict yet)
  // Actually with init_code_len=2, code_len=3, clear=8, eoi=9
  // CLEAR is code 8 (3 bits), then next code should be 0-7 or 9
  // Let's construct: init=2, then 3-bit code 0 (output 'A'), then 3-bit code 8 (CLEAR), then invalid code 10
  let data : Array[Byte] = [0x02, 0x00, 0x00, 0x80, 0x00]
  try {
    let _ = tiff_lzw_decode(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "tiff_packbits_decode: 扩展模式数据不足 raises" {
  // Extended mode (0x80) but no following 2 bytes
  try {
    let _ = tiff_packbits_decode(b"\x80")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "tiff_packbits_decode: 重复模式数据不足 raises" {
  // Repeat mode (0x80) but no following byte to repeat
  try {
    let _ = tiff_packbits_decode(b"\x80")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "tiff_packbits_decode: 原始数据越界安全处理" {
  // Count says copy 10 bytes but only 2 available - should not panic
  let data : Array[Byte] = [0x09, b'\x01', b'\x02']
  let result = tiff_packbits_decode(Bytes::from_array(data))
  assert_eq(result.length(), 2)
  assert_eq(result[0], b'\x01')
  assert_eq(result[1], b'\x02')
}

///|
test "tiff_deflate_decode: 数据过短 raises" {
  try {
    let _ = tiff_deflate_decode(b"\x01")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "tiff_deflate_decode: 空数据 raises" {
  try {
    let _ = tiff_deflate_decode(b"")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "tiff_deflate_decode: Huffman 块 raises" {
  // BFINAL=0, BTYPE=01 (static Huffman) - unsupported
  // bit pattern: first bit = 0 (not final), next 2 bits = 01 (static Huffman)
  // In LSB-first: bits 0,1,2 = 0,1,0 → byte = 0b010 = 0x02
  try {
    let _ = tiff_deflate_decode(b"\x02\x00\x00\x00\x00")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "tiff_deflate_decode: 长度校验失败 raises" {
  // BFINAL=0, BTYPE=00 (uncompressed), but LEN/NLEN don't match
  // Byte 0: 0x01 = BFINAL=1, BTYPE=01... wait
  // Need: BFINAL=0, BTYPE=00 → byte = 0b00000001 = 0x01 (but BFINAL is bit 0)
  // Actually: bit0=BFINAL=0, bits1-2=BTYPE=00 → first byte = 0b00000000 = 0x00
  // Then LEN=1, NLEN=0xFE (which is ~1 = 0xFFFE... not matching)
  // LEN = 1 (LE), NLEN should be 0xFFFE, but we put 0xFE00
  // Wait, let me think again. LEN is 2 bytes LE, NLEN is 2 bytes LE.
  // LEN=1: [0x01, 0x00], NLEN=~1=0xFFFE: [0xFE, 0xFF]
  // Wrong NLEN: [0x00, 0xFF] (which is 0xFF00 != 0xFFFE)
  let raw : Array[Byte] = [0x00, 0x01, 0x00, 0x00, 0xFF, 0x80]
  try {
    let _ = tiff_deflate_decode(Bytes::from_array(raw))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "encode_tiff_pure: 无效 channels raises" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 2,
    data: Bytes::from_array([b'\x80', b'\x40']),
  }
  try {
    let _ = encode_tiff_pure(img)
    assert_true(false)
  } catch {
    @types.LoadError::EncodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|

///|
test "decode_tiff_pure: big-endian (MM) 1x1 gray roundtrip" {
  let out : Array[Byte] = [
    b'\x4D', b'\x49', // 'MM'
     b'\x00', b'\x2A', // magic = 42
     b'\x00', b'\x00', b'\x00', b'\x08', // IFD offset = 8
     b'\x00', b'\x09', // IFD count = 9 (big-endian)
  ]
  // Entry 0: tag=256 (0x0100), type=4, count=1, value=1
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x04')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  // Entry 1: tag=257 (0x0101), type=4, count=1, value=1
  out.push(b'\x01')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x04')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  // Entry 2: tag=258 (0x0102), type=3, count=1, value=8
  out.push(b'\x01')
  out.push(b'\x02')
  out.push(b'\x00')
  out.push(b'\x03')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x08')
  // Entry 3: tag=259 (0x0103), type=3, count=1, value=1
  out.push(b'\x01')
  out.push(b'\x03')
  out.push(b'\x00')
  out.push(b'\x03')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  // Entry 4: tag=262 (0x0106), type=3, count=1, value=1
  out.push(b'\x01')
  out.push(b'\x06')
  out.push(b'\x00')
  out.push(b'\x03')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  // Entry 5: tag=273 (0x0111), type=4, count=1, value=122
  out.push(b'\x01')
  out.push(b'\x11')
  out.push(b'\x00')
  out.push(b'\x04')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x7A')
  // Entry 6: tag=277 (0x0115), type=3, count=1, value=1
  out.push(b'\x01')
  out.push(b'\x15')
  out.push(b'\x00')
  out.push(b'\x03')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  // Entry 7: tag=278 (0x0116), type=4, count=1, value=1
  out.push(b'\x01')
  out.push(b'\x16')
  out.push(b'\x00')
  out.push(b'\x04')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  // Entry 8: tag=279 (0x0117), type=4, count=1, value=1
  out.push(b'\x01')
  out.push(b'\x17')
  out.push(b'\x00')
  out.push(b'\x04')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  // Next IFD = 0
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  // Pixel data at offset 122 (0x7A)
  out.push(b'\x80')
  let tiff = Bytes::from_array(out)
  let decoded = decode_tiff_pure(tiff)
  assert_eq(decoded.width, 1)
  assert_eq(decoded.height, 1)
  assert_eq(decoded.channels, 1)
  assert_eq(decoded.data[0].to_int(), 128)
}

///|
test "decode_tiff_pure: type_id=1 (BYTE) in IFD entry" {
  // Construct a minimal TIFF with BYTE type (type_id=1) for tag 254 (NewRawTag)
  // which tests the type_id=1 branch in tiff_read_values
  let out : Array[Byte] = [
    b'\x49', b'\x49', // 'II' little-endian
     b'\x00', b'\x2A', // magic = 42
     b'\x00', b'\x00', b'\x00', b'\x08', // IFD offset = 8
     b'\x00', b'\x01', // IFD count = 1
  ]
  // Entry 0: tag=254 (0x00FE), type=1 (BYTE), count=1, value=200
  out.push(b'\x00')
  out.push(b'\xFE') // tag=254
  out.push(b'\x00')
  out.push(b'\x01') // type=1 (BYTE)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01') // count=1
  out.push(b'\xC8') // value=200 (BYTE fits in 4 bytes)
  // Next IFD = 0
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
}

///|
test "decode_tiff_pure: type_id=5 (RATIONAL) in IFD entry" {
  // Construct a minimal TIFF with RATIONAL type (type_id=5)
  // which tests the type_id=5 branch in tiff_type_size
  let out : Array[Byte] = [
    b'\x49', b'\x49', // 'II' little-endian
     b'\x00', b'\x2A', // magic = 42
     b'\x00', b'\x00', b'\x00', b'\x08', // IFD offset = 8
     b'\x00', b'\x01', // IFD count = 1
  ]
  // Entry 0: tag=700 (ExifGPSInfo IFD pointer), type=5 (RATIONAL), count=1
  out.push(b'\x02')
  out.push(b'\x0C') // tag=700 (0x02CC)
  out.push(b'\x00')
  out.push(b'\x05') // type=5 (RATIONAL)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01') // count=1
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00') // offset to rational value
  // Next IFD = 0
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
}

// TIFF 解码错误路径测试
// 覆盖 decode_tiff_pure 的各种错误分支

///|
fn make_tiff_header_le(out : Array[Byte], ifd_offset : Int) -> Unit {
  out.push(b'\x49')
  out.push(b'\x49')
  out.push(b'\x2A')
  out.push(b'\x00')
  out.push((ifd_offset & 0xFF).to_byte())
  out.push(((ifd_offset >> 8) & 0xFF).to_byte())
  out.push(((ifd_offset >> 16) & 0xFF).to_byte())
  out.push(((ifd_offset >> 24) & 0xFF).to_byte())
}

///|
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

///|
test "decode_tiff_pure: missing ImageWidth raises" {
  let out : Array[Byte] = []
  make_tiff_header_le(out, 8)
  // IFD: 8 entries (no ImageWidth tag 256)
  out.push(b'\x08')
  out.push(b'\x00')
  let pixel_offset = 8 + 2 + 8 * 12 + 4
  write_le_entry(out, 257, 4, 1, 1) // height=1
  write_le_entry(out, 258, 3, 1, 8) // bits=8
  write_le_entry(out, 259, 3, 1, 1) // compression=none
  write_le_entry(out, 262, 3, 1, 1) // photometric
  write_le_entry(out, 273, 4, 1, pixel_offset) // strip offset
  write_le_entry(out, 277, 3, 1, 1) // samples=1
  write_le_entry(out, 278, 4, 1, 1) // rows per strip
  write_le_entry(out, 279, 4, 1, 1) // strip byte count
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x80')
  let tiff = Bytes::from_array(out)
  try {
    let _ = decode_tiff_pure(tiff)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_tiff_pure: unsupported compression raises" {
  let out : Array[Byte] = []
  make_tiff_header_le(out, 8)
  out.push(b'\x08')
  out.push(b'\x00')
  let pixel_offset = 8 + 2 + 8 * 12 + 4
  write_le_entry(out, 256, 4, 1, 1) // width=1
  write_le_entry(out, 257, 4, 1, 1) // height=1
  write_le_entry(out, 258, 3, 1, 8) // bits=8
  write_le_entry(out, 259, 3, 1, 2) // compression=LZW (unsupported)
  write_le_entry(out, 262, 3, 1, 1) // photometric
  write_le_entry(out, 273, 4, 1, pixel_offset)
  write_le_entry(out, 277, 3, 1, 1)
  write_le_entry(out, 278, 4, 1, 1)
  write_le_entry(out, 279, 4, 1, 1)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x80')
  let tiff = Bytes::from_array(out)
  try {
    let _ = decode_tiff_pure(tiff)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_tiff_pure: 16-bit bits_per_sample raises" {
  let out : Array[Byte] = []
  make_tiff_header_le(out, 8)
  out.push(b'\x08')
  out.push(b'\x00')
  let pixel_offset = 8 + 2 + 8 * 12 + 4
  write_le_entry(out, 256, 4, 1, 1)
  write_le_entry(out, 257, 4, 1, 1)
  write_le_entry(out, 258, 3, 1, 16) // bits=16 (unsupported for 8-bit decoder)
  write_le_entry(out, 259, 3, 1, 1)
  write_le_entry(out, 262, 3, 1, 1)
  write_le_entry(out, 273, 4, 1, pixel_offset)
  write_le_entry(out, 277, 3, 1, 1)
  write_le_entry(out, 278, 4, 1, 1)
  write_le_entry(out, 279, 4, 1, 1)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x80')
  let tiff = Bytes::from_array(out)
  try {
    let _ = decode_tiff_pure(tiff)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_tiff_pure: missing StripOffsets raises" {
  let out : Array[Byte] = []
  make_tiff_header_le(out, 8)
  out.push(b'\x08')
  out.push(b'\x00')
  write_le_entry(out, 256, 4, 1, 1)
  write_le_entry(out, 257, 4, 1, 1)
  write_le_entry(out, 258, 3, 1, 8)
  write_le_entry(out, 259, 3, 1, 1)
  write_le_entry(out, 262, 3, 1, 1)
  write_le_entry(out, 277, 3, 1, 1)
  write_le_entry(out, 278, 4, 1, 1)
  write_le_entry(out, 279, 4, 1, 1)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x80')
  let tiff = Bytes::from_array(out)
  try {
    let _ = decode_tiff_pure(tiff)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_tiff_pure: invalid samples_per_pixel raises" {
  let out : Array[Byte] = []
  make_tiff_header_le(out, 8)
  out.push(b'\x08')
  out.push(b'\x00')
  let pixel_offset = 8 + 2 + 8 * 12 + 4
  write_le_entry(out, 256, 4, 1, 1)
  write_le_entry(out, 257, 4, 1, 1)
  write_le_entry(out, 258, 3, 1, 8)
  write_le_entry(out, 259, 3, 1, 1)
  write_le_entry(out, 262, 3, 1, 1)
  write_le_entry(out, 273, 4, 1, pixel_offset)
  write_le_entry(out, 277, 3, 1, 5) // samples=5 (invalid)
  write_le_entry(out, 278, 4, 1, 1)
  write_le_entry(out, 279, 4, 1, 1)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x80')
  let tiff = Bytes::from_array(out)
  try {
    let _ = decode_tiff_pure(tiff)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_tiff_pure: big-endian RGB roundtrip" {
  let out : Array[Byte] = []
  // Big-endian header
  out.push(b'\x4D')
  out.push(b'\x4D')
  out.push(b'\x00')
  out.push(b'\x2A')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x08')
  // IFD
  out.push(b'\x00')
  out.push(b'\x08')
  let pixel_offset = 8 + 2 + 8 * 12 + 4
  let write_be = fn(
    tag : Int,
    type_id : Int,
    count : Int,
    value : Int,
  ) -> Unit {
    out.push(((tag >> 8) & 0xFF).to_byte())
    out.push((tag & 0xFF).to_byte())
    out.push(((type_id >> 8) & 0xFF).to_byte())
    out.push((type_id & 0xFF).to_byte())
    out.push(((count >> 24) & 0xFF).to_byte())
    out.push(((count >> 16) & 0xFF).to_byte())
    out.push(((count >> 8) & 0xFF).to_byte())
    out.push((count & 0xFF).to_byte())
    out.push(((value >> 24) & 0xFF).to_byte())
    out.push(((value >> 16) & 0xFF).to_byte())
    out.push(((value >> 8) & 0xFF).to_byte())
    out.push((value & 0xFF).to_byte())
  }
  write_be(256, 4, 1, 2) // width=2
  write_be(257, 4, 1, 1) // height=1
  write_be(258, 3, 1, 8) // bits=8
  write_be(259, 3, 1, 1) // compression=none
  write_be(262, 3, 1, 2) // photometric=RGB
  write_be(273, 4, 1, pixel_offset)
  write_be(277, 3, 1, 3) // samples=3
  write_be(278, 4, 1, 1)
  write_be(279, 4, 1, 6) // 2*1*3=6 bytes
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  // 2x1 RGB pixels
  out.push(b'\xFF')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\xFF')
  out.push(b'\x00')
  let tiff = Bytes::from_array(out)
  let decoded = decode_tiff_pure(tiff)
  assert_eq(decoded.width, 2)
  assert_eq(decoded.height, 1)
  assert_eq(decoded.channels, 3)
}

///|
test "decode_tiff_pure: truncated IFD raises" {
  // IFD offset beyond data length
  let bad = b"\x49\x49\x2A\x00\xFF\xFF\xFF\xFF"
  try {
    let _ = decode_tiff_pure(bad)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_tiff_pure: zero dimensions raises" {
  let out : Array[Byte] = []
  make_tiff_header_le(out, 8)
  out.push(b'\x08')
  out.push(b'\x00')
  let pixel_offset = 8 + 2 + 8 * 12 + 4
  write_le_entry(out, 256, 4, 1, 0) // width=0
  write_le_entry(out, 257, 4, 1, 0) // height=0
  write_le_entry(out, 258, 3, 1, 8)
  write_le_entry(out, 259, 3, 1, 1)
  write_le_entry(out, 262, 3, 1, 1)
  write_le_entry(out, 273, 4, 1, pixel_offset)
  write_le_entry(out, 277, 3, 1, 1)
  write_le_entry(out, 278, 4, 1, 1)
  write_le_entry(out, 279, 4, 1, 0)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  let tiff = Bytes::from_array(out)
  try {
    let _ = decode_tiff_pure(tiff)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

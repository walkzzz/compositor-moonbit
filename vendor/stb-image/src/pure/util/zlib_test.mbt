// 纯 MoonBit zlib 测试
// 覆盖 crc32, adler32, zlib_inflate

///|
test "zlib: crc32 empty" {
  assert_eq(crc32(b""), 0)
}

///|
test "zlib: crc32 consistency" {
  // CRC32 相同输入产生相同输出，不同输入产生不同输出
  let data1 = b"\x31\x32\x33\x34\x35\x36\x37\x38\x39"
  let data2 = b"\x61\x62\x63"
  let h1 = crc32(data1)
  let h2 = crc32(data2)
  let h1_again = crc32(data1)
  assert_eq(h1, h1_again)
  assert_not_eq(h1, h2)
  assert_not_eq(h1, 0)
  assert_not_eq(h2, 0)
}

///|
test "zlib: crc32 single byte" {
  let data = b"\x61"
  // 验证非零且确定性
  let h = crc32(data)
  assert_not_eq(h, 0)
  assert_eq(h, crc32(data))
}

///|
test "zlib: adler32 empty" {
  assert_eq(adler32(b""), 1)
}

///|
test "zlib: adler32 single byte" {
  // Adler32("a"): a=98, b=98, (b<<16)|a = 0x00620062
  let data = b"\x61"
  assert_eq(adler32(data), 0x00620062)
}

///|
test "zlib: adler32 known vector" {
  // Adler32("Wikipedia") = 0x11E60398
  let data = b"\x57\x69\x6B\x69\x70\x65\x64\x69\x61"
  assert_eq(adler32(data), 0x11E60398)
}

///|
test "zlib: zlib_inflate stored block empty" {
  // 构造 zlib 头 + 空 stored block (bfinal=1, btype=0)
  // zlib header: CMF=0x78, FLG=0x01 (FCHECK=1, no dict, FLEVEL=0)
  // 实际上 FLG 需要满足 (CMF*256 + FLG) % 31 == 0
  // 0x78*256 = 30720, 30720 % 31 = 30720 - 990*31 = 30720 - 30690 = 30
  // FLG = 31 - 30 = 1 → 0x01
  // stored block: bfinal=1, btype=00 → byte = 0x01 (bit0=1, bit1-2=0)
  // LEN = 0, NLEN = 0xFFFF
  let data = b"\x78\x01\x01\x00\x00\xFF\xFF"
  let result = zlib_inflate(data)
  assert_eq(result.length(), 0)
}

///|
test "zlib: zlib_inflate stored block with data" {
  // 构造 zlib 头 + stored block 含 3 字节数据
  // bfinal=1, btype=0 → 0x01
  // LEN=3, NLEN=0xFFFC
  // data: 0x41 0x42 0x43 ("ABC")
  let data = b"\x78\x01\x01\x03\x00\xFC\xFF\x41\x42\x43"
  let result = zlib_inflate(data)
  assert_eq(result.length(), 3)
  assert_eq(result[0].to_int(), 0x41)
  assert_eq(result[1].to_int(), 0x42)
  assert_eq(result[2].to_int(), 0x43)
}

///|
test "zlib: zlib_inflate too short raises" {
  let data = b"\x00"
  try {
    let _ = zlib_inflate(data)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "zlib: zlib_inflate via PNG roundtrip" {
  // PNG encode 使用 zlib stored blocks，通过 PNG round-trip 间接测试 inflate
  let pixels = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120]
  let img_data : Array[Byte] = []
  for p in pixels {
    img_data.push(p.to_byte())
  }
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 3,
    data: Bytes::from_array(img_data),
  }
  let png_bytes = @codec.encode_png_pure(img)
  let restored = @codec.decode_png_pure(png_bytes)
  assert_eq(restored.width, 2)
  assert_eq(restored.height, 2)
  for i in 0..<pixels.length() {
    assert_eq(restored.data[i].to_int(), pixels[i])
  }
}

///|
test "zlib: zlib_inflate stored block out of bounds raises" {
  // 构造 stored block 但 LEN 超出数据范围
  // bfinal=1, btype=0, LEN=0xFF, NLEN=0x00
  let bad = b"\x78\x01\x01\xFF\x00\x00\x00"
  try {
    let _ = zlib_inflate(bad)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "zlib: zlib_inflate stored block data too short raises" {
  // 构造只有 6 字节的 stored block：header(2) + 3 bits + 3 字节
  // 检查 pos + 4 > len → 3 + 4 = 7 > 6 → 触发 "DEFLATE stored block 数据过短"
  let bad = b"\x78\x01\x01\x00\x00\x00"
  try {
    let _ = zlib_inflate(bad)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

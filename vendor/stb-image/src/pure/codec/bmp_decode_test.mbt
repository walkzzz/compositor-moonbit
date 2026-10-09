// 纯 MoonBit BMP 解码器测试
// 纯逻辑断言测试（全目标可用：native/wasm/js），不依赖 @core
// 对比验证（@core.load_from_bytes）留待后续轮次移至根包 roundtrip_test.mbt（native-only）

///|
// 1x1 24-bit BMP，红色像素 (R=255, G=0, B=0)
// BMP Header(14) + DIB(40) + pixel(4, BGR+pad) = 58 bytes
fn make_1x1_red_bmp_24() -> Bytes {
  b"\x42\x4D\x3A\x00\x00\x00\x00\x00\x00\x00\x36\x00\x00\x00\x28\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01\x00\x18\x00\x00\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xFF\x00"
}

///|
// 2x2 24-bit BMP，含行填充
// 布局: (0,0)=红, (1,0)=白, (0,1)=绿, (1,1)=蓝
// BMP Header(14) + DIB(40) + pixel(16, 2 rows * 8 bytes) = 70 bytes
fn make_2x2_colors_bmp_24() -> Bytes {
  b"\x42\x4D\x46\x00\x00\x00\x00\x00\x00\x00\x36\x00\x00\x00\x28\x00\x00\x00\x02\x00\x00\x00\x02\x00\x00\x00\x01\x00\x18\x00\x00\x00\x00\x00\x10\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xFF\x00\xFF\x00\x00\x00\x00\x00\x00\xFF\xFF\xFF\xFF\x00\x00"
}

///|
// 1x1 32-bit BMP，红色像素 (R=255, G=0, B=0, A=255)
// BMP Header(14) + DIB(40) + pixel(4, BGRA) = 58 bytes
fn make_1x1_red_bmp_32() -> Bytes {
  b"\x42\x4D\x3A\x00\x00\x00\x00\x00\x00\x00\x36\x00\x00\x00\x28\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01\x00\x20\x00\x00\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xFF\xFF"
}

///|
// 1x2 24-bit BMP，自上而下 (height=-2)
// 顶行(y=0)=红, 底行(y=1)=绿
// BMP Header(14) + DIB(40) + pixel(8, 2 rows * 4 bytes) = 62 bytes
fn make_1x2_top_down_bmp_24() -> Bytes {
  b"\x42\x4D\x3E\x00\x00\x00\x00\x00\x00\x00\x36\x00\x00\x00\x28\x00\x00\x00\x01\x00\x00\x00\xFE\xFF\xFF\xFF\x01\x00\x18\x00\x00\x00\x00\x00\x08\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xFF\x00\x00\xFF\x00\x00"
}

///|
test "decode_bmp_pure: 1x1 24-bit BMP" {
  let img = decode_bmp_pure(make_1x1_red_bmp_24())
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 3)
  // 红色像素 RGB
  assert_eq(img.data[0].to_int(), 255)
  assert_eq(img.data[1].to_int(), 0)
  assert_eq(img.data[2].to_int(), 0)
}

///|
test "decode_bmp_pure: 2x2 24-bit BMP with row padding" {
  let img = decode_bmp_pure(make_2x2_colors_bmp_24())
  assert_eq(img.width, 2)
  assert_eq(img.height, 2)
  assert_eq(img.channels, 3)
  // (0,0)=红, (1,0)=白, (0,1)=绿, (1,1)=蓝，RGB 顺序
  let expected = [255, 0, 0, 255, 255, 255, 0, 255, 0, 0, 0, 255]
  for i in 0..<12 {
    assert_eq(img.data[i].to_int(), expected[i])
  }
}

///|
test "decode_bmp_pure: 1x1 32-bit BMP" {
  let img = decode_bmp_pure(make_1x1_red_bmp_32())
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 4)
  // 红色像素 RGBA
  assert_eq(img.data[0].to_int(), 255)
  assert_eq(img.data[1].to_int(), 0)
  assert_eq(img.data[2].to_int(), 0)
  assert_eq(img.data[3].to_int(), 255)
}

///|
test "decode_bmp_pure: top-down row order (height < 0)" {
  let img = decode_bmp_pure(make_1x2_top_down_bmp_24())
  assert_eq(img.width, 1)
  assert_eq(img.height, 2)
  assert_eq(img.channels, 3)
  // 顶行(y=0)=红 RGB(255,0,0)，底行(y=1)=绿 RGB(0,255,0)
  assert_eq(img.data[0].to_int(), 255)
  assert_eq(img.data[1].to_int(), 0)
  assert_eq(img.data[2].to_int(), 0)
  assert_eq(img.data[3].to_int(), 0)
  assert_eq(img.data[4].to_int(), 255)
  assert_eq(img.data[5].to_int(), 0)
}

///|
test "decode_bmp_pure: invalid magic raises" {
  // 58 字节，magic 错误 "XX"
  let bad = b"XX\x3A\x00\x00\x00\x00\x00\x00\x00\x36\x00\x00\x00\x28\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01\x00\x18\x00\x00\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xFF\x00"
  try {
    let _ = decode_bmp_pure(bad)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_bmp_pure: too short raises" {
  let short = b"\x42\x4D"
  try {
    let _ = decode_bmp_pure(short)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_bmp_pure: wrong magic raises" {
  try {
    let _ = decode_bmp_pure(
      b"XX\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
    )
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_bmp_pure: unsupported DIB header size raises" {
  // DIB header size = 12 (OS/2 style), not 40
  let data : Array[Byte] = [
    b'B', b'M', // magic
     0x3A, 0x00, 0x00, 0x00, // file size
     0x00, 0x00, 0x00, 0x00, // reserved
     0x36, 0x00, 0x00, 0x00, // data offset
     0x0C, 0x00, 0x00, 0x00, // DIB header size=12 (unsupported)
     0x01, 0x00, 0x00, 0x00, // width=1
     0x01, 0x00, 0x00, 0x00, // height=1
     0x01, 0x00, // planes
     0x18, 0x00, // bpp=24
     0x00, 0x00, 0x00, 0x00, // compression
     0x00, 0x00, 0x00, 0x00, // image size
     0x00, 0x00, 0x00, 0x00, // xpels
     0x00, 0x00, 0x00, 0x00, // ypels
     0x00, 0x00, 0x00, 0x00, // colors
     0x00, 0x00, 0x00, 0x00, // important colors
  ]
  try {
    let _ = decode_bmp_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_bmp_pure: unsupported bit depth raises" {
  // Valid BMP header but bpp=8 (palette-based, not supported)
  let data : Array[Byte] = [
    b'B', b'M', // magic
     0x3A, 0x00, 0x00, 0x00, // file size
     0x00, 0x00, 0x00, 0x00, // reserved
     0x36, 0x00, 0x00, 0x00, // data offset
     0x28, 0x00, 0x00, 0x00, // DIB header size=40
     0x01, 0x00, 0x00, 0x00, // width=1
     0x01, 0x00, 0x00, 0x00, // height=1
     0x01, 0x00, // planes
     0x08, 0x00, // bpp=8 (unsupported)
     0x00, 0x00, 0x00, 0x00, // compression
     0x00, 0x00, 0x00, 0x00, // image size
     0x00, 0x00, 0x00, 0x00, // xpels
     0x00, 0x00, 0x00, 0x00, // ypels
     0x00, 0x00, 0x00, 0x00, // colors
     0x00, 0x00, 0x00, 0x00, // important colors
  ]
  try {
    let _ = decode_bmp_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_bmp_pure: unsupported compression raises" {
  // Valid BMP header but compression=1 (RLE)
  let data : Array[Byte] = [
    b'B', b'M', // magic
     0x3A, 0x00, 0x00, 0x00, // file size
     0x00, 0x00, 0x00, 0x00, // reserved
     0x36, 0x00, 0x00, 0x00, // data offset
     0x28, 0x00, 0x00, 0x00, // DIB header size=40
     0x01, 0x00, 0x00, 0x00, // width=1
     0x01, 0x00, 0x00, 0x00, // height=1
     0x01, 0x00, // planes
     0x18, 0x00, // bpp=24
     0x01, 0x00, 0x00, 0x00, // compression=1 (RLE)
     0x00, 0x00, 0x00, 0x00, // image size
     0x00, 0x00, 0x00, 0x00, // xpels
     0x00, 0x00, 0x00, 0x00, // ypels
     0x00, 0x00, 0x00, 0x00, // colors
     0x00, 0x00, 0x00, 0x00, // important colors
  ]
  try {
    let _ = decode_bmp_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_bmp_pure: zero dimensions raises" {
  // Valid header but width=0
  let data : Array[Byte] = [
    b'B', b'M', // magic
     0x3A, 0x00, 0x00, 0x00, // file size
     0x00, 0x00, 0x00, 0x00, // reserved
     0x36, 0x00, 0x00, 0x00, // data offset
     0x28, 0x00, 0x00, 0x00, // DIB header size=40
     0x00, 0x00, 0x00, 0x00, // width=0
     0x01, 0x00, 0x00, 0x00, // height=1
     0x01, 0x00, // planes
     0x18, 0x00, // bpp=24
     0x00, 0x00, 0x00, 0x00, // compression=0
     0x00, 0x00, 0x00, 0x00, // image size
     0x00, 0x00, 0x00, 0x00, // xpels
     0x00, 0x00, 0x00, 0x00, // ypels
     0x00, 0x00, 0x00, 0x00, // colors
     0x00, 0x00, 0x00, 0x00, // important colors
  ]
  try {
    let _ = decode_bmp_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_bmp_pure: pixel data out of bounds raises" {
  // Valid header but pixel data truncated
  let data : Array[Byte] = [
    b'B', b'M', // magic
     0x46, 0x00, 0x00, 0x00, // file size=70
     0x00, 0x00, 0x00, 0x00, // reserved
     0x36, 0x00, 0x00, 0x00, // data offset=54
     0x28, 0x00, 0x00, 0x00, // DIB header size=40
     0x02, 0x00, 0x00, 0x00, // width=2
     0x02, 0x00, 0x00, 0x00, // height=2
     0x01, 0x00, // planes
     0x18, 0x00, // bpp=24
     0x00, 0x00, 0x00, 0x00, // compression=0
     0x00, 0x00, 0x00, 0x00, // image size
     0x00, 0x00, 0x00, 0x00, // xpels
     0x00, 0x00, 0x00, 0x00, // ypels
     0x00, 0x00, 0x00, 0x00, // colors
     0x00, 0x00, 0x00, 0x00, // important colors
    // Only 4 bytes of pixel data (need 16 for 2x2 24-bit with padding)
     0xFF, 0x00, 0x00, 0xFF,
  ]
  try {
    let _ = decode_bmp_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_bmp_pure: second row pixel data out of bounds raises" {
  // width=2, height=2, bpp=24 → row_size=8 bytes (2*3 rounded up to 4-byte align)
  // file_row=0: row_start=54, has 6 bytes (need 8)
  // file_row=1: row_start=62, would need 8 bytes but only 1 available
  let data : Array[Byte] = [
    b'B', b'M', // magic
     0x45, 0x00, 0x00, 0x00, // file size=69
     0x00, 0x00, 0x00, 0x00, // reserved
     0x36, 0x00, 0x00, 0x00, // data offset=54
     0x28, 0x00, 0x00, 0x00, // DIB header size=40
     0x02, 0x00, 0x00, 0x00, // width=2
     0x02, 0x00, 0x00, 0x00, // height=2
     0x01, 0x00, // planes
     0x18, 0x00, // bpp=24
     0x00, 0x00, 0x00, 0x00, // compression=0
     0x00, 0x00, 0x00, 0x00, // image size
     0x00, 0x00, 0x00, 0x00, // xpels
     0x00, 0x00, 0x00, 0x00, // ypels
     0x00, 0x00, 0x00, 0x00, // colors
     0x00, 0x00, 0x00, 0x00, // important colors
    // Row 0: 6 bytes (need 8 with padding) - partial row, first 2 pixels ok
     0xFF, 0x00, 0x00, 0xFF, 0x00, 0x00,
    // Row 1: only 1 byte (need 8)
     0x00,
  ]
  try {
    let _ = decode_bmp_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

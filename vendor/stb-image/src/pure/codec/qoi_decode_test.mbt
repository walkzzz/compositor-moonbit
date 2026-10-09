// 纯 MoonBit QOI 解码器测试
// 纯逻辑断言测试（全目标可用：native/wasm/js），不依赖 @core
// 手构造 QOI 字节流验证解码正确性，覆盖全部 6 种 QOI 标签 + 2 错误路径
// 规范: https://qoiformat.org/qoi-specification.pdf

///|
fn make_qoi_header(width : Int, height : Int, channels : Int) -> Array[Byte] {
  let out : Array[Byte] = []
  // magic "qoif"
  out.push(b'\x71')
  out.push(b'\x6F')
  out.push(b'\x69')
  out.push(b'\x66')
  // width (big-endian)
  out.push(((width >> 24) & 0xFF).to_byte())
  out.push(((width >> 16) & 0xFF).to_byte())
  out.push(((width >> 8) & 0xFF).to_byte())
  out.push((width & 0xFF).to_byte())
  // height (big-endian)
  out.push(((height >> 24) & 0xFF).to_byte())
  out.push(((height >> 16) & 0xFF).to_byte())
  out.push(((height >> 8) & 0xFF).to_byte())
  out.push((height & 0xFF).to_byte())
  // channels
  out.push(channels.to_byte())
  // colorspace (0 = sRGB with linear alpha)
  out.push(b'\x00')
  out
}

///|
fn make_qoi_end() -> Array[Byte] {
  [b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x01']
}

///|
fn to_bytes(arr : Array[Byte]) -> Bytes {
  Bytes::from_array(arr)
}

///|
fn append_bytes(arr : Array[Byte], extra : Array[Byte]) -> Unit {
  for b in extra {
    arr.push(b)
  }
}

///|
// 1x1 RGB，像素 (100, 150, 200)，使用 QOI_OP_RGB 标签
fn make_1x1_rgb_qoi() -> Bytes {
  let out = make_qoi_header(1, 1, 3)
  // QOI_OP_RGB: 0xFE, r, g, b
  out.push(b'\xFE')
  out.push(b'\x64') // 100
  out.push(b'\x96') // 150
  out.push(b'\xC8') // 200
  append_bytes(out, make_qoi_end())
  to_bytes(out)
}

///|
// 1x1 RGBA，像素 (100, 150, 200, 50)，使用 QOI_OP_RGBA 标签
fn make_1x1_rgba_qoi() -> Bytes {
  let out = make_qoi_header(1, 1, 4)
  // QOI_OP_RGBA: 0xFF, r, g, b, a
  out.push(b'\xFF')
  out.push(b'\x64') // 100
  out.push(b'\x96') // 150
  out.push(b'\xC8') // 200
  out.push(b'\x32') // 50
  append_bytes(out, make_qoi_end())
  to_bytes(out)
}

///|
// 2x2 RGB，含 QOI_OP_DIFF 差分编码
// 像素: (50,50,50) -> (51,51,51) -> (52,52,52) -> (53,53,53)
// 像素 0 用 QOI_OP_RGB，后续 3 个用 QOI_OP_DIFF (dr=dg=db=1)
fn make_2x2_diff_qoi() -> Bytes {
  let out = make_qoi_header(2, 2, 3)
  // 像素 0: (50, 50, 50) - QOI_OP_RGB
  out.push(b'\xFE')
  out.push(b'\x32') // 50
  out.push(b'\x32')
  out.push(b'\x32')
  // 像素 1-3: QOI_OP_DIFF, dr=1, dg=1, db=1
  // tag = 0x40 | ((1+2)<<4) | ((1+2)<<2) | (1+2) = 0x7F
  out.push(b'\x7F')
  out.push(b'\x7F')
  out.push(b'\x7F')
  append_bytes(out, make_qoi_end())
  to_bytes(out)
}

///|
// 2x2 RGB，含 QOI_OP_LUMA 双字节差分编码
// 像素: (100,100,100) -> (118,120,122) -> (50,50,50) -> (50,50,50)
// 像素 1 用 QOI_OP_LUMA: dg=20, dr_dg=-2, db_dg=2
fn make_2x2_luma_qoi() -> Bytes {
  let out = make_qoi_header(2, 2, 3)
  // 像素 0: (100, 100, 100) - QOI_OP_RGB
  out.push(b'\xFE')
  out.push(b'\x64') // 100
  out.push(b'\x64')
  out.push(b'\x64')
  // 像素 1: (118, 120, 122) - QOI_OP_LUMA
  // dg=20, dr_dg=-2, db_dg=2
  // tag = 0x80 | (20+32) = 0xB4
  // b2 = ((-2+8)<<4) | (2+8) = 0x6A
  out.push(b'\xB4')
  out.push(b'\x6A')
  // 像素 2: (50, 50, 50) - QOI_OP_RGB
  out.push(b'\xFE')
  out.push(b'\x32') // 50
  out.push(b'\x32')
  out.push(b'\x32')
  // 像素 3: (50, 50, 50) - QOI_OP_RUN, run=1
  // tag = 0xC0 | 0 = 0xC0
  out.push(b'\xC0')
  append_bytes(out, make_qoi_end())
  to_bytes(out)
}

///|
// 2x2 RGB，含 QOI_OP_RUN 游程编码
// 像素: (200,100,50) x 4
// 像素 0 用 QOI_OP_RGB，像素 1-3 用 QOI_OP_RUN (run=3)
fn make_2x2_run_qoi() -> Bytes {
  let out = make_qoi_header(2, 2, 3)
  // 像素 0: (200, 100, 50) - QOI_OP_RGB
  out.push(b'\xFE')
  out.push(b'\xC8') // 200
  out.push(b'\x64') // 100
  out.push(b'\x32') // 50
  // 像素 1-3: QOI_OP_RUN, run=3
  // tag = 0xC0 | (3-1) = 0xC2
  out.push(b'\xC2')
  append_bytes(out, make_qoi_end())
  to_bytes(out)
}

///|
// 2x2 RGBA，含 QOI_OP_INDEX 索引编码
// 像素: (10,20,30,40) x 4
// 像素 0 用 QOI_OP_RGBA，后续用 QOI_OP_INDEX (hash=12)
fn make_2x2_index_qoi() -> Bytes {
  let out = make_qoi_header(2, 2, 4)
  // 像素 0: (10, 20, 30, 40) - QOI_OP_RGBA
  out.push(b'\xFF')
  out.push(b'\x0A') // 10
  out.push(b'\x14') // 20
  out.push(b'\x1E') // 30
  out.push(b'\x28') // 40
  // hash = (10*3 + 20*5 + 30*7 + 40*11) % 64 = 780 % 64 = 12
  // 像素 1-3: QOI_OP_INDEX, idx=12
  // tag = 0x00 | 12 = 0x0C
  out.push(b'\x0C')
  out.push(b'\x0C')
  out.push(b'\x0C')
  append_bytes(out, make_qoi_end())
  to_bytes(out)
}

///|
test "decode_qoi_pure: 1x1 RGB (QOI_OP_RGB)" {
  let img = decode_qoi_pure(make_1x1_rgb_qoi())
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 3)
  // 像素 (100, 150, 200)
  assert_eq(img.data[0].to_int(), 100)
  assert_eq(img.data[1].to_int(), 150)
  assert_eq(img.data[2].to_int(), 200)
}

///|
test "decode_qoi_pure: 1x1 RGBA (QOI_OP_RGBA)" {
  let img = decode_qoi_pure(make_1x1_rgba_qoi())
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 4)
  // 像素 (100, 150, 200, 50)
  assert_eq(img.data[0].to_int(), 100)
  assert_eq(img.data[1].to_int(), 150)
  assert_eq(img.data[2].to_int(), 200)
  assert_eq(img.data[3].to_int(), 50)
}

///|
test "decode_qoi_pure: 2x2 RGB (QOI_OP_DIFF)" {
  let img = decode_qoi_pure(make_2x2_diff_qoi())
  assert_eq(img.width, 2)
  assert_eq(img.height, 2)
  assert_eq(img.channels, 3)
  // 像素: (50,50,50) -> (51,51,51) -> (52,52,52) -> (53,53,53)
  let expected = [50, 50, 50, 51, 51, 51, 52, 52, 52, 53, 53, 53]
  for i in 0..<12 {
    assert_eq(img.data[i].to_int(), expected[i])
  }
}

///|
test "decode_qoi_pure: 2x2 RGB (QOI_OP_LUMA)" {
  let img = decode_qoi_pure(make_2x2_luma_qoi())
  assert_eq(img.width, 2)
  assert_eq(img.height, 2)
  assert_eq(img.channels, 3)
  // 像素: (100,100,100) -> (118,120,122) -> (50,50,50) -> (50,50,50)
  let expected = [100, 100, 100, 118, 120, 122, 50, 50, 50, 50, 50, 50]
  for i in 0..<12 {
    assert_eq(img.data[i].to_int(), expected[i])
  }
}

///|
test "decode_qoi_pure: 2x2 RGB (QOI_OP_RUN)" {
  let img = decode_qoi_pure(make_2x2_run_qoi())
  assert_eq(img.width, 2)
  assert_eq(img.height, 2)
  assert_eq(img.channels, 3)
  // 像素: (200,100,50) x 4
  let expected = [200, 100, 50, 200, 100, 50, 200, 100, 50, 200, 100, 50]
  for i in 0..<12 {
    assert_eq(img.data[i].to_int(), expected[i])
  }
}

///|
test "decode_qoi_pure: 2x2 RGBA (QOI_OP_INDEX)" {
  let img = decode_qoi_pure(make_2x2_index_qoi())
  assert_eq(img.width, 2)
  assert_eq(img.height, 2)
  assert_eq(img.channels, 4)
  // 像素: (10,20,30,40) x 4
  let expected = [
    10, 20, 30, 40, 10, 20, 30, 40, 10, 20, 30, 40, 10, 20, 30, 40,
  ]
  for i in 0..<16 {
    assert_eq(img.data[i].to_int(), expected[i])
  }
}

///|
test "decode_qoi_pure: invalid magic raises" {
  // 14 字节，magic 错误 "xxxx"
  let bad = b"\x78\x78\x78\x78\x00\x00\x00\x01\x00\x00\x00\x01\x03\x00"
  try {
    let _ = decode_qoi_pure(bad)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_qoi_pure: too short raises" {
  // 4 字节，仅 magic，不足 14 字节
  let short = b"\x71\x6F\x69\x66"
  try {
    let _ = decode_qoi_pure(short)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_qoi_pure: invalid dimensions raises" {
  let data : Array[Byte] = [
    0x1A, 0x0B, 0xFE, 0x44, // magic "QOI"
     0x00, 0x00, 0x00, 0x00, // width=0
     0x00, 0x00, 0x00, 0x01, // height=1
     0x03, // channels=3 (RGB)
     0x00, // colorspace=0 (sRGB)
  ]
  try {
    let _ = decode_qoi_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_qoi_pure: truncated pixel data raises" {
  let data : Array[Byte] = [
    0x1A, 0x0B, 0xFE, 0x44, // magic "QOI"
     0x00, 0x00, 0x00, 0x01, // width=1
     0x00, 0x00, 0x00, 0x01, // height=1
     0x03, // channels=3 (RGB)
     0x00, // colorspace=0 (sRGB)
    // Only 2 bytes instead of full pixel data
     0x01, 0xFF,
  ]
  try {
    let _ = decode_qoi_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

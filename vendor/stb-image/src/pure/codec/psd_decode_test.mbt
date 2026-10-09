// 纯 MoonBit PSD 解码器测试
// 纯逻辑断言测试（全目标可用：native/wasm/js），不依赖 @core
// 手构造 PSD 字节流验证解码正确性，覆盖 RGB/RGBA/交错/边界/错误路径
// 规范: Adobe Photoshop PSD File Format + stb_image.h:6126-6280 stbi__psd_load

///|
fn push_be16(arr : Array[Byte], v : Int) -> Unit {
  arr.push(((v >> 8) & 0xFF).to_byte())
  arr.push((v & 0xFF).to_byte())
}

///|
fn push_be32(arr : Array[Byte], v : Int) -> Unit {
  arr.push(((v >> 24) & 0xFF).to_byte())
  arr.push(((v >> 16) & 0xFF).to_byte())
  arr.push(((v >> 8) & 0xFF).to_byte())
  arr.push((v & 0xFF).to_byte())
}

///|
/// 构造 PSD header（26 字节）+ 3 个空段（color mode / image resources / layer and mask）
/// 不含 image data，由调用方追加 compression + 像素数据
fn make_psd_header_and_empty_sections(
  channel_count : Int,
  h : Int,
  w : Int,
  bitdepth : Int,
  color_mode : Int,
) -> Array[Byte] {
  let out : Array[Byte] = []
  // signature "8BPS"
  out.push(b'\x38')
  out.push(b'\x42')
  out.push(b'\x50')
  out.push(b'\x53')
  // version (BE) = 1
  push_be16(out, 1)
  // reserved (6 字节)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  // channelCount (BE)
  push_be16(out, channel_count)
  // h (BE)
  push_be32(out, h)
  // w (BE)
  push_be32(out, w)
  // bitdepth (BE)
  push_be16(out, bitdepth)
  // colorMode (BE)
  push_be16(out, color_mode)
  // Color mode data: length=0
  push_be32(out, 0)
  // Image resources: length=0
  push_be32(out, 0)
  // Layer and mask data: length=0
  push_be32(out, 0)
  out
}

///|
/// 追加 image data 段（compression=0 + 按通道排列像素）
/// channels_data：按通道排列的像素数组，每通道 w*h 字节
fn append_psd_image_data(
  out : Array[Byte],
  channels_data : Array[Array[Byte]],
) -> Unit {
  // compression (BE) = 0
  push_be16(out, 0)
  for ch in channels_data {
    for b in ch {
      out.push(b)
    }
  }
}

///|
test "decode_psd_pure: 2x2 RGB basic" {
  let header = make_psd_header_and_empty_sections(3, 2, 2, 8, 3)
  // 2x2 RGB，4 像素：R 通道 [10,20,30,40] G 通道 [50,60,70,80] B 通道 [90,100,110,120]
  let r : Array[Byte] = [b'\x0A', b'\x14', b'\x1E', b'\x28']
  let g : Array[Byte] = [b'\x32', b'\x3C', b'\x46', b'\x50']
  let b : Array[Byte] = [b'\x5A', b'\x64', b'\x6E', b'\x78']
  append_psd_image_data(header, [r, g, b])
  let img = decode_psd_pure(to_bytes(header))
  assert_eq(img.width, 2)
  assert_eq(img.height, 2)
  assert_eq(img.channels, 3)
  // 交错后：[10,50,90, 20,60,100, 30,70,110, 40,80,120]
  let expected = [10, 50, 90, 20, 60, 100, 30, 70, 110, 40, 80, 120]
  for i in 0..<12 {
    assert_eq(img.data[i].to_int(), expected[i])
  }
}

///|
test "decode_psd_pure: 2x2 RGBA basic" {
  let header = make_psd_header_and_empty_sections(4, 2, 2, 8, 3)
  // 2x2 RGBA，4 像素，含 alpha
  let r : Array[Byte] = [b'\xFF', b'\x00', b'\x00', b'\xFF']
  let g : Array[Byte] = [b'\x00', b'\xFF', b'\x00', b'\xFF']
  let b : Array[Byte] = [b'\x00', b'\x00', b'\xFF', b'\xFF']
  let a : Array[Byte] = [b'\x80', b'\x80', b'\x80', b'\xFF']
  append_psd_image_data(header, [r, g, b, a])
  let img = decode_psd_pure(to_bytes(header))
  assert_eq(img.width, 2)
  assert_eq(img.height, 2)
  assert_eq(img.channels, 4)
  // 交错后：[FF,00,00,80, 00,FF,00,80, 00,00,FF,80, FF,FF,FF,FF]
  let expected = [
    0xFF, 0x00, 0x00, 0x80, 0x00, 0xFF, 0x00, 0x80, 0x00, 0x00, 0xFF, 0x80, 0xFF,
    0xFF, 0xFF, 0xFF,
  ]
  for i in 0..<16 {
    assert_eq(img.data[i].to_int(), expected[i])
  }
}

///|
test "decode_psd_pure: channel interleave verify" {
  // 2x1 3 通道：R=[10,20] G=[30,40] B=[50,60]
  // 交错后应为 [10,30,50, 20,40,60]（确保交错逻辑正确，非简单拷贝）
  let header = make_psd_header_and_empty_sections(3, 1, 2, 8, 3)
  let r : Array[Byte] = [b'\x0A', b'\x14']
  let g : Array[Byte] = [b'\x1E', b'\x28']
  let b : Array[Byte] = [b'\x32', b'\x3C']
  append_psd_image_data(header, [r, g, b])
  let img = decode_psd_pure(to_bytes(header))
  assert_eq(img.width, 2)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 3)
  let expected = [10, 30, 50, 20, 40, 60]
  for i in 0..<6 {
    assert_eq(img.data[i].to_int(), expected[i])
  }
}

///|
test "decode_psd_pure: 1x1 minimal image" {
  let header = make_psd_header_and_empty_sections(3, 1, 1, 8, 3)
  let r : Array[Byte] = [b'\x42']
  let g : Array[Byte] = [b'\x84']
  let b : Array[Byte] = [b'\xC6']
  append_psd_image_data(header, [r, g, b])
  let img = decode_psd_pure(to_bytes(header))
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 3)
  assert_eq(img.data[0].to_int(), 0x42)
  assert_eq(img.data[1].to_int(), 0x84)
  assert_eq(img.data[2].to_int(), 0xC6)
}

///|
test "decode_psd_pure: bad signature raises" {
  let out : Array[Byte] = []
  // signature "XXXX"
  out.push(b'\x58')
  out.push(b'\x58')
  out.push(b'\x58')
  out.push(b'\x58')
  // version=1
  push_be16(out, 1)
  // reserved 6
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  // channelCount=3
  push_be16(out, 3)
  // h=1, w=1
  push_be32(out, 1)
  push_be32(out, 1)
  // bitdepth=8
  push_be16(out, 8)
  // colorMode=3
  push_be16(out, 3)
  push_be32(out, 0)
  push_be32(out, 0)
  push_be32(out, 0)
  push_be16(out, 0)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  try {
    let _ = decode_psd_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_psd_pure: too short raises" {
  // 仅 4 字节 "8BPS"
  let short = b"\x38\x42\x50\x53"
  try {
    let _ = decode_psd_pure(short)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_psd_pure: bad version raises" {
  let out : Array[Byte] = []
  out.push(b'\x38')
  out.push(b'\x42')
  out.push(b'\x50')
  out.push(b'\x53')
  // version=2
  push_be16(out, 2)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  push_be16(out, 3)
  push_be32(out, 1)
  push_be32(out, 1)
  push_be16(out, 8)
  push_be16(out, 3)
  push_be32(out, 0)
  push_be32(out, 0)
  push_be32(out, 0)
  push_be16(out, 0)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  try {
    let _ = decode_psd_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_psd_pure: unsupported channelCount raises" {
  // channelCount=1（灰度）
  let out : Array[Byte] = []
  out.push(b'\x38')
  out.push(b'\x42')
  out.push(b'\x50')
  out.push(b'\x53')
  push_be16(out, 1)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  push_be16(out, 1)
  push_be32(out, 1)
  push_be32(out, 1)
  push_be16(out, 8)
  push_be16(out, 3)
  push_be32(out, 0)
  push_be32(out, 0)
  push_be32(out, 0)
  push_be16(out, 0)
  out.push(b'\x00')
  try {
    let _ = decode_psd_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_psd_pure: unsupported bitdepth raises" {
  // bitdepth=16
  let out : Array[Byte] = []
  out.push(b'\x38')
  out.push(b'\x42')
  out.push(b'\x50')
  out.push(b'\x53')
  push_be16(out, 1)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  push_be16(out, 3)
  push_be32(out, 1)
  push_be32(out, 1)
  push_be16(out, 16)
  push_be16(out, 3)
  push_be32(out, 0)
  push_be32(out, 0)
  push_be32(out, 0)
  push_be16(out, 0)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  try {
    let _ = decode_psd_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_psd_pure: unsupported colorMode raises" {
  // colorMode=1（Grayscale）
  let out : Array[Byte] = []
  out.push(b'\x38')
  out.push(b'\x42')
  out.push(b'\x50')
  out.push(b'\x53')
  push_be16(out, 1)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  push_be16(out, 3)
  push_be32(out, 1)
  push_be32(out, 1)
  push_be16(out, 8)
  push_be16(out, 1)
  push_be32(out, 0)
  push_be32(out, 0)
  push_be32(out, 0)
  push_be16(out, 0)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  try {
    let _ = decode_psd_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_psd_pure: unsupported compression raises" {
  // compression=1（RLE）
  let out : Array[Byte] = []
  out.push(b'\x38')
  out.push(b'\x42')
  out.push(b'\x50')
  out.push(b'\x53')
  push_be16(out, 1)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  push_be16(out, 3)
  push_be32(out, 1)
  push_be32(out, 1)
  push_be16(out, 8)
  push_be16(out, 3)
  push_be32(out, 0)
  push_be32(out, 0)
  push_be32(out, 0)
  // compression=1
  push_be16(out, 1)
  try {
    let _ = decode_psd_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_psd_pure: invalid dimensions raises" {
  // w=0
  let out : Array[Byte] = []
  out.push(b'\x38')
  out.push(b'\x42')
  out.push(b'\x50')
  out.push(b'\x53')
  push_be16(out, 1)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  push_be16(out, 3)
  // h=1, w=0
  push_be32(out, 1)
  push_be32(out, 0)
  push_be16(out, 8)
  push_be16(out, 3)
  push_be32(out, 0)
  push_be32(out, 0)
  push_be32(out, 0)
  push_be16(out, 0)
  try {
    let _ = decode_psd_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_psd_pure: pixel data insufficient raises" {
  // 2x2 3 通道需要 12 字节像素，仅提供 3 字节
  let header = make_psd_header_and_empty_sections(3, 2, 2, 8, 3)
  // compression=0
  push_be16(header, 0)
  // 仅 3 字节像素（不足 12）
  header.push(b'\x0A')
  header.push(b'\x14')
  header.push(b'\x1E')
  try {
    let _ = decode_psd_pure(to_bytes(header))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

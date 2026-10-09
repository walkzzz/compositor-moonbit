// 纯 MoonBit HDR 编码器测试
// 覆盖 encode_hdr_pure 编码正确性 + roundtrip (encode→decode) + 错误路径
// 纯逻辑断言测试（全目标可用：native/wasm/js），不依赖 @core

///|
// 构造 ImageF，pixels 为 (r, g, b) float 三元组数组
fn he_make_imagef(
  width : Int,
  height : Int,
  pixels : Array[(Float, Float, Float)],
) -> @types.ImageF {
  let data : Array[Byte] = []
  for p in pixels {
    let rb = p.0.to_le_bytes()
    let gb = p.1.to_le_bytes()
    let bb = p.2.to_le_bytes()
    for i in 0..<4 {
      data.push(rb[i])
    }
    for i in 0..<4 {
      data.push(gb[i])
    }
    for i in 0..<4 {
      data.push(bb[i])
    }
  }
  @types.ImageF::{ width, height, channels: 3, data: Bytes::from_array(data) }
}

///|
test "encode_hdr_pure: RADIANCE header" {
  let img = he_make_imagef(1, 1, [(1.0F, 0.0F, 0.0F)])
  let out = encode_hdr_pure(img)
  // header 应包含 "#?RADIANCE\n"
  assert_eq(out[0].to_int(), 0x23) // #
  assert_eq(out[1].to_int(), 0x3F) // ?
  assert_eq(out[2].to_int(), 0x52) // R
  assert_eq(out[3].to_int(), 0x41) // A
  assert_eq(out[4].to_int(), 0x44) // D
  assert_eq(out[5].to_int(), 0x49) // I
}

///|
test "encode_hdr_pure: invalid channels raises" {
  let img = @types.ImageF::{
    width: 1,
    height: 1,
    channels: 4,
    data: Bytes::from_array(Array::make(16, b'\x00')),
  }
  try {
    let _ = encode_hdr_pure(img)
    fail("expected error")
  } catch {
    @types.LoadError::EncodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "encode_hdr_pure: 1x1 roundtrip" {
  let img = he_make_imagef(1, 1, [(1.0F, 0.5F, 0.25F)])
  let hdr_bytes = encode_hdr_pure(img)
  let restored = decode_hdr_pure(hdr_bytes)
  assert_eq(restored.width, 1)
  assert_eq(restored.height, 1)
  assert_eq(restored.channels, 3)
}

///|
test "encode_hdr_pure: 2x2 roundtrip" {
  let img = he_make_imagef(2, 2, [
    (1.0F, 0.0F, 0.0F),
    (0.0F, 1.0F, 0.0F),
    (0.0F, 0.0F, 1.0F),
    (1.0F, 1.0F, 1.0F),
  ])
  let hdr_bytes = encode_hdr_pure(img)
  let restored = decode_hdr_pure(hdr_bytes)
  assert_eq(restored.width, 2)
  assert_eq(restored.height, 2)
  assert_eq(restored.channels, 3)
}

///|
test "encode_hdr_pure: 8x8 roundtrip with RLE" {
  // 8x8 图像，宽度 >= 8 触发 RLE 编码
  let pixels : Array[(Float, Float, Float)] = []
  for i in 0..<64 {
    pixels.push((Float::from_int(i % 8) * 0.1F, 0.5F, 0.3F))
  }
  let img = he_make_imagef(8, 8, pixels)
  let hdr_bytes = encode_hdr_pure(img)
  let restored = decode_hdr_pure(hdr_bytes)
  assert_eq(restored.width, 8)
  assert_eq(restored.height, 8)
  assert_eq(restored.channels, 3)
}

///|
test "encode_hdr_pure: 4x4 small image (no RLE)" {
  // 宽度 < 8，不使用 RLE
  let pixels : Array[(Float, Float, Float)] = []
  for _ in 0..<16 {
    pixels.push((0.5F, 0.5F, 0.5F))
  }
  let img = he_make_imagef(4, 4, pixels)
  let hdr_bytes = encode_hdr_pure(img)
  let restored = decode_hdr_pure(hdr_bytes)
  assert_eq(restored.width, 4)
  assert_eq(restored.height, 4)
  assert_eq(restored.channels, 3)
}

///|
test "encode_hdr_pure: all-black image" {
  let img = he_make_imagef(2, 2, [
    (0.0F, 0.0F, 0.0F),
    (0.0F, 0.0F, 0.0F),
    (0.0F, 0.0F, 0.0F),
    (0.0F, 0.0F, 0.0F),
  ])
  let hdr_bytes = encode_hdr_pure(img)
  let restored = decode_hdr_pure(hdr_bytes)
  assert_eq(restored.width, 2)
  assert_eq(restored.height, 2)
  // 全黑解码后应全 0
  for i in 0..<restored.data.length() {
    assert_eq(restored.data[i].to_int(), 0)
  }
}

///|
test "encode_hdr_pure: 16x1 uniform scanline RLE" {
  // 16x1 均匀图像，测试 RLE 重复编码
  let pixels = Array::make(16, (0.5F, 0.5F, 0.5F))
  let img = he_make_imagef(16, 1, pixels)
  let hdr_bytes = encode_hdr_pure(img)
  let restored = decode_hdr_pure(hdr_bytes)
  assert_eq(restored.width, 16)
  assert_eq(restored.height, 1)
  assert_eq(restored.channels, 3)
}

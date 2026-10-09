// 纯 MoonBit JPEG 解码器测试
// 覆盖 decode_jpeg_pure 错误路径 + 边界情况
// 纯逻辑断言测试（全目标可用：native/wasm/js），不依赖 @core

///|
test "decode_jpeg_pure: empty data raises" {
  try {
    let _ = decode_jpeg_pure(b"")
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "decode_jpeg_pure: wrong SOI marker raises" {
  // not FF D8
  let data = b"\x00\x00\xFF\xC0"
  try {
    let _ = decode_jpeg_pure(data)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "decode_jpeg_pure: only SOI raises" {
  // FF D8 only, no other markers
  let data = b"\xFF\xD8"
  try {
    let _ = decode_jpeg_pure(data)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "decode_jpeg_pure: single byte raises" {
  let data = b"\xFF"
  try {
    let _ = decode_jpeg_pure(data)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "decode_jpeg_pure: 1x1 gray roundtrip via encode" {
  // 构造 1x1 灰度图，encode 后 decode
  let img = @types.Image::{ width: 1, height: 1, channels: 1, data: b"\x80" }
  let jpeg_bytes = encode_jpeg_pure(img)
  let restored = decode_jpeg_pure(jpeg_bytes)
  assert_eq(restored.width, 1)
  assert_eq(restored.height, 1)
  assert_eq(restored.channels, 3)
}

///|
test "decode_jpeg_pure: 4x4 uniform roundtrip" {
  // 4x4 均匀灰色图像
  let data : Array[Byte] = Array::make(48, b'\x80')
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let jpeg_bytes = encode_jpeg_pure(img)
  let restored = decode_jpeg_pure(jpeg_bytes)
  assert_eq(restored.width, 4)
  assert_eq(restored.height, 4)
  assert_eq(restored.channels, 3)
  // 均匀灰色应近似保持
  for i in 0..<restored.data.length() {
    let v = restored.data[i].to_int()
    assert_true(v >= 100 && v <= 156)
  }
}

///|
test "decode_jpeg_pure: 3x5 non-square roundtrip" {
  // 3x5 非方形图像
  let pixels : Array[Byte] = []
  for i in 0..<15 {
    pixels.push((i * 17 % 256).to_byte())
    pixels.push((i * 31 % 256).to_byte())
    pixels.push((i * 53 % 256).to_byte())
  }
  let img = @types.Image::{
    width: 3,
    height: 5,
    channels: 3,
    data: Bytes::from_array(pixels),
  }
  let jpeg_bytes = encode_jpeg_pure(img)
  let restored = decode_jpeg_pure(jpeg_bytes)
  assert_eq(restored.width, 3)
  assert_eq(restored.height, 5)
  assert_eq(restored.channels, 3)
}

///|
test "decode_jpeg_pure: 9x9 multi-block roundtrip" {
  // 9x9 图像（超过单个 8x8 MCU 块）
  let pixels : Array[Byte] = []
  for i in 0..<81 {
    pixels.push((i * 7 % 256).to_byte())
    pixels.push((i * 13 % 256).to_byte())
    pixels.push((i * 23 % 256).to_byte())
  }
  let img = @types.Image::{
    width: 9,
    height: 9,
    channels: 3,
    data: Bytes::from_array(pixels),
  }
  let jpeg_bytes = encode_jpeg_pure(img)
  let restored = decode_jpeg_pure(jpeg_bytes)
  assert_eq(restored.width, 9)
  assert_eq(restored.height, 9)
  assert_eq(restored.channels, 3)
}

///|
test "decode_jpeg_pure: truncated after SOI raises" {
  // Just SOI marker with nothing else
  let data : Array[Byte] = [0xFF, 0xD8]
  try {
    let _ = decode_jpeg_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

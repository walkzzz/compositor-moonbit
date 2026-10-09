// 纯 MoonBit JPEG 编码器测试
// 覆盖 encode_jpeg_pure 编码正确性 + roundtrip (encode→decode) + 错误路径
// 纯逻辑断言测试（全目标可用：native/wasm/js），不依赖 @core

///|
fn je_make_rgb_image(
  width : Int,
  height : Int,
  pixels : Array[(Int, Int, Int)],
) -> @types.Image {
  let data : Array[Byte] = []
  for p in pixels {
    data.push(p.0.to_byte())
    data.push(p.1.to_byte())
    data.push(p.2.to_byte())
  }
  @types.Image::{ width, height, channels: 3, data: Bytes::from_array(data) }
}

///|
fn je_make_gray_image(
  width : Int,
  height : Int,
  pixels : Array[Int],
) -> @types.Image {
  let data : Array[Byte] = []
  for p in pixels {
    data.push(p.to_byte())
  }
  @types.Image::{ width, height, channels: 1, data: Bytes::from_array(data) }
}

///|
test "encode_jpeg_pure: SOI and EOI markers" {
  let img = je_make_rgb_image(1, 1, [(128, 128, 128)])
  let out = encode_jpeg_pure(img)
  // SOI
  assert_eq(out[0].to_int(), 0xFF)
  assert_eq(out[1].to_int(), 0xD8)
  // EOI (last 2 bytes)
  let len = out.length()
  assert_eq(out[len - 2].to_int(), 0xFF)
  assert_eq(out[len - 1].to_int(), 0xD9)
}

///|
test "encode_jpeg_pure: DQT marker" {
  let img = je_make_rgb_image(1, 1, [(0, 0, 0)])
  let out = encode_jpeg_pure(img)
  // SOI(2) then DQT: FF DB
  assert_eq(out[2].to_int(), 0xFF)
  assert_eq(out[3].to_int(), 0xDB)
  // DQT length = 0x0084 (132)
  assert_eq(out[4].to_int(), 0x00)
  assert_eq(out[5].to_int(), 0x84)
}

///|
test "encode_jpeg_pure: SOF0 marker" {
  let img = je_make_rgb_image(16, 16, Array::make(256, (128, 128, 128)))
  let out = encode_jpeg_pure(img)
  // 找到 SOF0 marker (FF C0)
  let mut found = false
  for i in 0..<(out.length() - 1) {
    if out[i].to_int() == 0xFF && out[i + 1].to_int() == 0xC0 {
      found = true
      // precision = 8
      assert_eq(out[i + 4].to_int(), 0x08)
      // height = 16 (BE u16)
      assert_eq(out[i + 5].to_int(), 0x00)
      assert_eq(out[i + 6].to_int(), 0x10)
      // width = 16 (BE u16)
      assert_eq(out[i + 7].to_int(), 0x00)
      assert_eq(out[i + 8].to_int(), 0x10)
      // num_components = 3
      assert_eq(out[i + 9].to_int(), 0x03)
      break
    }
  }
  assert_true(found)
}

///|
test "encode_jpeg_pure: DHT marker" {
  let img = je_make_rgb_image(1, 1, [(255, 255, 255)])
  let out = encode_jpeg_pure(img)
  // 找到 DHT marker (FF C4)
  let mut found = false
  for i in 0..<(out.length() - 1) {
    if out[i].to_int() == 0xFF && out[i + 1].to_int() == 0xC4 {
      found = true
      break
    }
  }
  assert_true(found)
}

///|
test "encode_jpeg_pure: SOS marker" {
  let img = je_make_rgb_image(2, 2, Array::make(4, (100, 100, 100)))
  let out = encode_jpeg_pure(img)
  // 找到 SOS marker (FF DA)
  let mut found = false
  for i in 0..<(out.length() - 1) {
    if out[i].to_int() == 0xFF && out[i + 1].to_int() == 0xDA {
      found = true
      break
    }
  }
  assert_true(found)
}

///|
test "encode_jpeg_pure: invalid dimensions raises" {
  let img = @types.Image::{
    width: 0,
    height: 10,
    channels: 3,
    data: Bytes::from_array([]),
  }
  try {
    let _ = encode_jpeg_pure(img)
    fail("expected error")
  } catch {
    @types.LoadError::EncodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "encode_jpeg_pure: invalid dimensions raises (negative)" {
  let img = @types.Image::{
    width: 10,
    height: 0,
    channels: 3,
    data: Bytes::from_array([]),
  }
  try {
    let _ = encode_jpeg_pure(img)
    fail("expected error")
  } catch {
    @types.LoadError::EncodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "encode_jpeg_pure: 1x1 RGB roundtrip" {
  let img = je_make_rgb_image(1, 1, [(128, 128, 128)])
  let jpeg_bytes = encode_jpeg_pure(img)
  let restored = decode_jpeg_pure(jpeg_bytes)
  assert_eq(restored.width, 1)
  assert_eq(restored.height, 1)
  assert_eq(restored.channels, 3)
}

///|
test "encode_jpeg_pure: 8x8 RGB roundtrip" {
  // 8x8 灰色图像
  let pixels = Array::make(64, (128, 128, 128))
  let img = je_make_rgb_image(8, 8, pixels)
  let jpeg_bytes = encode_jpeg_pure(img)
  let restored = decode_jpeg_pure(jpeg_bytes)
  assert_eq(restored.width, 8)
  assert_eq(restored.height, 8)
  assert_eq(restored.channels, 3)
  // 灰色 128 经 JPEG 压缩后应近似保持
  for i in 0..<restored.data.length() {
    let v = restored.data[i].to_int()
    assert_true(v >= 100 && v <= 156)
  }
}

///|
test "encode_jpeg_pure: 16x16 RGB roundtrip" {
  // 16x16 渐变图像
  let pixels : Array[(Int, Int, Int)] = []
  for y in 0..<16 {
    for x in 0..<16 {
      pixels.push((x * 8, y * 8, 128))
    }
  }
  let img = je_make_rgb_image(16, 16, pixels)
  let jpeg_bytes = encode_jpeg_pure(img)
  let restored = decode_jpeg_pure(jpeg_bytes)
  assert_eq(restored.width, 16)
  assert_eq(restored.height, 16)
  assert_eq(restored.channels, 3)
}

///|
test "encode_jpeg_pure: grayscale input roundtrip" {
  // channels=1 灰度输入，encode 时按 r=g=b 处理
  let pixels = [64, 128, 192, 255]
  let img = je_make_gray_image(2, 2, pixels)
  let jpeg_bytes = encode_jpeg_pure(img)
  let restored = decode_jpeg_pure(jpeg_bytes)
  assert_eq(restored.width, 2)
  assert_eq(restored.height, 2)
  assert_eq(restored.channels, 3)
}

///|
test "encode_jpeg_pure: 2x2 RGB roundtrip" {
  let img = je_make_rgb_image(2, 2, [
    (255, 0, 0),
    (0, 255, 0),
    (0, 0, 255),
    (255, 255, 255),
  ])
  let jpeg_bytes = encode_jpeg_pure(img)
  let restored = decode_jpeg_pure(jpeg_bytes)
  assert_eq(restored.width, 2)
  assert_eq(restored.height, 2)
  assert_eq(restored.channels, 3)
}

///|
test "encode_jpeg_pure: all-black image" {
  let pixels = Array::make(16, (0, 0, 0))
  let img = je_make_rgb_image(4, 4, pixels)
  let jpeg_bytes = encode_jpeg_pure(img)
  let restored = decode_jpeg_pure(jpeg_bytes)
  assert_eq(restored.width, 4)
  assert_eq(restored.height, 4)
  // 全黑图像解码后应接近 0
  for i in 0..<restored.data.length() {
    assert_true(restored.data[i].to_int() <= 20)
  }
}

///|
test "encode_jpeg_pure: all-white image" {
  let pixels = Array::make(16, (255, 255, 255))
  let img = je_make_rgb_image(4, 4, pixels)
  let jpeg_bytes = encode_jpeg_pure(img)
  let restored = decode_jpeg_pure(jpeg_bytes)
  assert_eq(restored.width, 4)
  assert_eq(restored.height, 4)
  // 全白图像解码后应接近 255
  for i in 0..<restored.data.length() {
    assert_true(restored.data[i].to_int() >= 235)
  }
}

///|
test "encode_jpeg_pure: non-multiple-of-8 dimensions" {
  // 5x5 图像（非 8 的倍数，测试边界填充）
  let img = je_make_rgb_image(5, 5, Array::make(25, (100, 150, 200)))
  let jpeg_bytes = encode_jpeg_pure(img)
  let restored = decode_jpeg_pure(jpeg_bytes)
  assert_eq(restored.width, 5)
  assert_eq(restored.height, 5)
  assert_eq(restored.channels, 3)
}

// 纯 MoonBit PNG 编码器测试
// 覆盖 encode_png_pure 编码正确性 + roundtrip (encode→decode) + 多通道
// 纯逻辑断言测试（全目标可用：native/wasm/js），不依赖 @core

///|
fn pe_make_image(
  width : Int,
  height : Int,
  channels : Int,
  pixels : Array[Int],
) -> @types.Image {
  let data : Array[Byte] = []
  for p in pixels {
    data.push(p.to_byte())
  }
  @types.Image::{ width, height, channels, data: Bytes::from_array(data) }
}

///|
test "encode_png_pure: PNG signature" {
  let img = pe_make_image(1, 1, 3, [128, 128, 128])
  let out = encode_png_pure(img)
  // PNG signature
  assert_eq(out[0].to_int(), 0x89)
  assert_eq(out[1].to_int(), 0x50) // P
  assert_eq(out[2].to_int(), 0x4E) // N
  assert_eq(out[3].to_int(), 0x47) // G
  assert_eq(out[4].to_int(), 0x0D)
  assert_eq(out[5].to_int(), 0x0A)
  assert_eq(out[6].to_int(), 0x1A)
  assert_eq(out[7].to_int(), 0x0A)
}

///|
test "encode_png_pure: IHDR chunk" {
  let img = pe_make_image(16, 32, 3, Array::make(16 * 32 * 3, 0))
  let out = encode_png_pure(img)
  // IHDR length = 13 (BE u32) at offset 8
  assert_eq(out[8].to_int(), 0x00)
  assert_eq(out[9].to_int(), 0x00)
  assert_eq(out[10].to_int(), 0x00)
  assert_eq(out[11].to_int(), 0x0D)
  // "IHDR"
  assert_eq(out[12].to_int(), 0x49)
  assert_eq(out[13].to_int(), 0x48)
  assert_eq(out[14].to_int(), 0x44)
  assert_eq(out[15].to_int(), 0x52)
  // width = 16 (BE u32) at offset 16
  assert_eq(out[16].to_int(), 0x00)
  assert_eq(out[17].to_int(), 0x00)
  assert_eq(out[18].to_int(), 0x00)
  assert_eq(out[19].to_int(), 0x10)
  // height = 32 (BE u32) at offset 20
  assert_eq(out[20].to_int(), 0x00)
  assert_eq(out[21].to_int(), 0x00)
  assert_eq(out[22].to_int(), 0x00)
  assert_eq(out[23].to_int(), 0x20)
}

///|
test "encode_png_pure: RGB roundtrip 1x1" {
  let img = pe_make_image(1, 1, 3, [255, 0, 0])
  let png_bytes = encode_png_pure(img)
  let restored = decode_png_pure(png_bytes)
  assert_eq(restored.width, 1)
  assert_eq(restored.height, 1)
  assert_eq(restored.channels, 3)
  assert_eq(restored.data[0].to_int(), 255)
  assert_eq(restored.data[1].to_int(), 0)
  assert_eq(restored.data[2].to_int(), 0)
}

///|
test "encode_png_pure: RGB roundtrip 4x4" {
  let pixels = [
    255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 0, 128, 128, 128, 64, 64, 64, 192,
    192, 192, 32, 32, 32, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 100, 150, 200, 50,
    100, 150, 200, 50, 100, 250, 250, 250,
  ]
  let img = pe_make_image(4, 4, 3, pixels)
  let png_bytes = encode_png_pure(img)
  let restored = decode_png_pure(png_bytes)
  assert_eq(restored.width, 4)
  assert_eq(restored.height, 4)
  assert_eq(restored.channels, 3)
  // PNG 是无损，像素应完全一致
  for i in 0..<pixels.length() {
    assert_eq(restored.data[i].to_int(), pixels[i])
  }
}

///|
test "encode_png_pure: RGBA roundtrip (alpha retained by decode)" {
  let pixels = [255, 0, 0, 255, 0, 255, 0, 128, 0, 0, 255, 64, 255, 255, 255, 0]
  let img = pe_make_image(2, 2, 4, pixels)
  let png_bytes = encode_png_pure(img)
  let restored = decode_png_pure(png_bytes)
  assert_eq(restored.width, 2)
  assert_eq(restored.height, 2)
  assert_eq(restored.channels, 4)
  // decode 保留 alpha，RGBA 完整往返
  for i in 0..<pixels.length() {
    assert_eq(restored.data[i].to_int(), pixels[i])
  }
}

///|
test "encode_png_pure: grayscale roundtrip (retained as gray)" {
  let pixels = [0, 64, 128, 192, 255, 32, 96, 160, 224]
  let img = pe_make_image(3, 3, 1, pixels)
  let png_bytes = encode_png_pure(img)
  let restored = decode_png_pure(png_bytes)
  assert_eq(restored.width, 3)
  assert_eq(restored.height, 3)
  assert_eq(restored.channels, 1)
  // 灰度保留为 channels=1
  for i in 0..<pixels.length() {
    assert_eq(restored.data[i].to_int(), pixels[i])
  }
}

///|
test "encode_png_pure: gray+alpha roundtrip (alpha retained)" {
  let pixels = [100, 255, 200, 128, 50, 0, 75, 200]
  let img = pe_make_image(2, 2, 2, pixels)
  let png_bytes = encode_png_pure(img)
  let restored = decode_png_pure(png_bytes)
  assert_eq(restored.width, 2)
  assert_eq(restored.height, 2)
  assert_eq(restored.channels, 2)
  // gray+alpha 保留为 channels=2
  for i in 0..<pixels.length() {
    assert_eq(restored.data[i].to_int(), pixels[i])
  }
}

///|
test "encode_png_pure: 3-channel from 5-channel input" {
  // channels=5 应被当作 RGB (out_ch=3)
  let pixels = [10, 20, 30, 40, 50]
  let img = pe_make_image(1, 1, 5, pixels)
  let png_bytes = encode_png_pure(img)
  let restored = decode_png_pure(png_bytes)
  assert_eq(restored.width, 1)
  assert_eq(restored.height, 1)
  assert_eq(restored.channels, 3)
  assert_eq(restored.data[0].to_int(), 10)
  assert_eq(restored.data[1].to_int(), 20)
  assert_eq(restored.data[2].to_int(), 30)
}

///|
test "encode_png_pure: 8x8 RGB roundtrip" {
  let pixels : Array[Int] = []
  for i in 0..<192 {
    pixels.push(i * 37 % 256)
  }
  let img = pe_make_image(8, 8, 3, pixels)
  let png_bytes = encode_png_pure(img)
  let restored = decode_png_pure(png_bytes)
  assert_eq(restored.width, 8)
  assert_eq(restored.height, 8)
  assert_eq(restored.channels, 3)
  for i in 0..<pixels.length() {
    assert_eq(restored.data[i].to_int(), pixels[i])
  }
}

///|
test "decode_png_16_pure: req_channels invalid raises" {
  // Construct a minimal 8-bit PNG and test req_channels validation
  let img = pe_make_image(1, 1, 3, [128, 64, 32])
  let png_bytes = encode_png_pure(img)
  try {
    let _ = decode_png_16_pure(png_bytes, req_channels=Some(5))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
  let _ = img
  let _ = png_bytes
}

///|
test "decode_png_16_pure: 8-bit roundtrip" {
  // 8-bit RGB PNG decoded as 16-bit: verify structure and req_channels
  let img = pe_make_image(1, 1, 3, [100, 150, 200])
  let png_bytes = encode_png_pure(img)
  let restored = decode_png_16_pure(png_bytes)
  assert_eq(restored.width, 1)
  assert_eq(restored.height, 1)
  assert_eq(restored.channels, 3)
  let _ = img
  let _ = png_bytes
  let _ = restored
}

// 纯 MoonBit GIF 编码器测试
// 纯逻辑断言测试（全目标可用：native/wasm/js），不依赖 @core
// 验证 encode_gif_pure 编码正确性，覆盖 header/LSD/GCT/Image Descriptor/LZW/Trailer + roundtrip + 错误路径
// 规范: GIF89a Specification + src/format/gif_encode.mbt
// to_bytes 复用 src/pure/qoi_decode_test.mbt 已有定义（同包私有函数跨文件可见）

///|
fn ge_make_rgb_image(
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
fn ge_make_rgba_image(
  width : Int,
  height : Int,
  pixels : Array[(Int, Int, Int, Int)],
) -> @types.Image {
  let data : Array[Byte] = []
  for p in pixels {
    data.push(p.0.to_byte())
    data.push(p.1.to_byte())
    data.push(p.2.to_byte())
    data.push(p.3.to_byte())
  }
  @types.Image::{ width, height, channels: 4, data: Bytes::from_array(data) }
}

///|
test "encode_gif_pure: GIF89a header" {
  // 1x1 RGB (0,0,0)，验证输出前 6 字节为 "GIF89a"
  let img = ge_make_rgb_image(1, 1, [(0, 0, 0)])
  let out = encode_gif_pure(img)
  assert_eq(out[0].to_int(), 0x47) // G
  assert_eq(out[1].to_int(), 0x49) // I
  assert_eq(out[2].to_int(), 0x46) // F
  assert_eq(out[3].to_int(), 0x38) // 8
  assert_eq(out[4].to_int(), 0x39) // 9
  assert_eq(out[5].to_int(), 0x61) // a
  let _ = img
}

///|
test "encode_gif_pure: LSD + GCT structure" {
  // 2x2 RGB，验证 LSD 7 字节 + GCT 768 字节
  let img = ge_make_rgb_image(2, 2, [
    (0, 0, 0),
    (10, 20, 30),
    (40, 50, 60),
    (70, 80, 90),
  ])
  let out = encode_gif_pure(img)
  // LSD: width LE (2) + height LE (2) + packed=0xF7 + bg=0 + aspect=0
  assert_eq(out[6].to_int(), 2) // width LE low
  assert_eq(out[7].to_int(), 0) // width LE high
  assert_eq(out[8].to_int(), 2) // height LE low
  assert_eq(out[9].to_int(), 0) // height LE high
  assert_eq(out[10].to_int(), 0xF7) // packed
  assert_eq(out[11].to_int(), 0) // background color index
  assert_eq(out[12].to_int(), 0) // pixel aspect ratio
  // GCT 768 字节（3-3-2 调色板）
  // palette[0] = (0,0,0)
  assert_eq(out[13].to_int(), 0)
  assert_eq(out[14].to_int(), 0)
  assert_eq(out[15].to_int(), 0)
  // palette[255] = (252,252,255)，位于偏移 13 + 255*3 = 778
  assert_eq(out[778].to_int(), 252)
  assert_eq(out[779].to_int(), 252)
  assert_eq(out[780].to_int(), 255)
  let _ = img
}

///|
test "encode_gif_pure: Image Descriptor" {
  // 2x2 RGB，验证 Image Separator 0x2C + left/top=0 + width/height LE + packed=0x00
  let img = ge_make_rgb_image(2, 2, [
    (0, 0, 0),
    (10, 20, 30),
    (40, 50, 60),
    (70, 80, 90),
  ])
  let out = encode_gif_pure(img)
  // Image Descriptor 起始偏移 = 6 (header) + 7 (LSD) + 768 (GCT) = 781
  let base = 781
  assert_eq(out[base].to_int(), 0x2C) // Image Separator
  assert_eq(out[base + 1].to_int(), 0) // left LE low
  assert_eq(out[base + 2].to_int(), 0) // left LE high
  assert_eq(out[base + 3].to_int(), 0) // top LE low
  assert_eq(out[base + 4].to_int(), 0) // top LE high
  assert_eq(out[base + 5].to_int(), 2) // width LE low
  assert_eq(out[base + 6].to_int(), 0) // width LE high
  assert_eq(out[base + 7].to_int(), 2) // height LE low
  assert_eq(out[base + 8].to_int(), 0) // height LE high
  assert_eq(out[base + 9].to_int(), 0x00) // packed: no LCT, not interlaced
  let _ = img
}

///|
test "encode_gif_pure: LZW min code size + Trailer" {
  // 1x1 RGB (0,0,0)，验证 LZW min code size=0x08 + Trailer 0x3B 在输出末尾
  let img = ge_make_rgb_image(1, 1, [(0, 0, 0)])
  let out = encode_gif_pure(img)
  // LZW min code size 位于偏移 781 + 10 = 791
  assert_eq(out[791].to_int(), 0x08) // LZW Minimum Code Size
  // Trailer 0x3B 在输出末尾
  let len = out.length()
  assert_eq(out[len - 1].to_int(), 0x3B)
  let _ = img
}

///|
test "encode_gif_pure: RGB roundtrip" {
  // 2x2 RGB 像素，encode_gif_pure → decode_gif_pure
  // 3-3-2 量化后预期 data:
  //   (10,20,30)→(0,0,0); (40,50,60)→(36,36,0); (70,80,90)→(72,72,85); (100,110,120)→(108,108,85)
  let img = ge_make_rgb_image(2, 2, [
    (10, 20, 30),
    (40, 50, 60),
    (70, 80, 90),
    (100, 110, 120),
  ])
  let gif_bytes = encode_gif_pure(img)
  let restored = decode_gif_pure(gif_bytes)
  assert_eq(restored.width, 2)
  assert_eq(restored.height, 2)
  assert_eq(restored.channels, 3)
  let expected = [0, 0, 0, 36, 36, 0, 72, 72, 85, 108, 108, 85]
  for i in 0..<12 {
    assert_eq(restored.data[i].to_int(), expected[i])
  }
  let _ = img
  let _ = restored
}

///|
test "encode_gif_pure: RGBA alpha ignored" {
  // 2x2 RGBA 像素，alpha 被忽略，data 与对应 RGB 编码结果一致
  let img = ge_make_rgba_image(2, 2, [
    (10, 20, 30, 128),
    (40, 50, 60, 128),
    (70, 80, 90, 128),
    (100, 110, 120, 128),
  ])
  let gif_bytes = encode_gif_pure(img)
  let restored = decode_gif_pure(gif_bytes)
  assert_eq(restored.width, 2)
  assert_eq(restored.height, 2)
  assert_eq(restored.channels, 3)
  let expected = [0, 0, 0, 36, 36, 0, 72, 72, 85, 108, 108, 85]
  for i in 0..<12 {
    assert_eq(restored.data[i].to_int(), expected[i])
  }
  let _ = img
  let _ = restored
}

///|
test "encode_gif_pure: 3-3-2 quantization white" {
  // 1x1 RGB (255,255,255)，量化后 (252,252,255)
  // 白色: r_level=7, g_level=7, b_level=3 → (7*36, 7*36, 3*85) = (252, 252, 255)
  let img = ge_make_rgb_image(1, 1, [(255, 255, 255)])
  let gif_bytes = encode_gif_pure(img)
  let restored = decode_gif_pure(gif_bytes)
  assert_eq(restored.width, 1)
  assert_eq(restored.height, 1)
  assert_eq(restored.channels, 3)
  assert_eq(restored.data[0].to_int(), 252)
  assert_eq(restored.data[1].to_int(), 252)
  assert_eq(restored.data[2].to_int(), 255)
  let _ = img
  let _ = restored
}

///|
test "encode_gif_pure: invalid channels raises" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 2,
    data: [b'\x00', b'\x00'] |> Bytes::from_array,
  }
  try {
    let _ = encode_gif_pure(img)
    assert_true(false)
  } catch {
    @types.LoadError::EncodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

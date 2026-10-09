// 纯 MoonBit PNM 编码器测试
// 纯逻辑断言测试（全目标可用：native/wasm/js），不依赖 @core
// 验证 encode_ppm_pure / encode_pgm_pure / encode_pnm_pure 编码正确性
// 规范: https://netpbm.sourceforge.net/doc/pgm.html / ppm.html

///|
fn pe_make_rgb_image(
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
test "encode_ppm_pure: RGB encoding" {
  let img = pe_make_rgb_image(2, 2, [
    (255, 0, 0),
    (0, 255, 0),
    (0, 0, 255),
    (255, 255, 255),
  ])
  let out = encode_ppm_pure(img)
  // 预期: "P6\n2 2\n255\n" (11 字节 header) + 12 字节 RGB 像素
  let expected : Array[Byte] = []
  // header "P6\n2 2\n255\n"
  expected.push(b'\x50') // P
  expected.push(b'\x36') // 6
  expected.push(b'\x0A') // \n
  expected.push(b'\x32') // 2
  expected.push(b'\x20') // space
  expected.push(b'\x32') // 2
  expected.push(b'\x0A') // \n
  expected.push(b'\x32') // 2
  expected.push(b'\x35') // 5
  expected.push(b'\x35') // 5
  expected.push(b'\x0A') // \n
  // 12 字节 RGB 像素
  expected.push(b'\xFF')
  expected.push(b'\x00')
  expected.push(b'\x00')
  expected.push(b'\x00')
  expected.push(b'\xFF')
  expected.push(b'\x00')
  expected.push(b'\x00')
  expected.push(b'\x00')
  expected.push(b'\xFF')
  expected.push(b'\xFF')
  expected.push(b'\xFF')
  expected.push(b'\xFF')
  assert_eq(out, Bytes::from_array(expected))
  let _ = img
}

///|
test "encode_pgm_pure: grayscale from RGB" {
  let img = pe_make_rgb_image(2, 2, [
    (255, 0, 0),
    (0, 255, 0),
    (0, 0, 255),
    (255, 255, 255),
  ])
  let out = encode_pgm_pure(img)
  // BT.601 灰度转换:
  // (255,0,0) -> 255*299/1000 = 76
  // (0,255,0) -> 255*587/1000 = 149
  // (0,0,255) -> 255*114/1000 = 29
  // (255,255,255) -> 255*1000/1000 = 255
  let expected : Array[Byte] = []
  // header "P5\n2 2\n255\n"
  expected.push(b'\x50') // P
  expected.push(b'\x35') // 5
  expected.push(b'\x0A') // \n
  expected.push(b'\x32') // 2
  expected.push(b'\x20') // space
  expected.push(b'\x32') // 2
  expected.push(b'\x0A') // \n
  expected.push(b'\x32') // 2
  expected.push(b'\x35') // 5
  expected.push(b'\x35') // 5
  expected.push(b'\x0A') // \n
  // 4 字节灰度像素
  expected.push(b'\x4C') // 76
  expected.push(b'\x95') // 149
  expected.push(b'\x1D') // 29
  expected.push(b'\xFF') // 255
  assert_eq(out, Bytes::from_array(expected))
  let _ = img
}

///|
test "encode_pnm_pure: auto select" {
  // channels=1 灰度 Image -> encode_pgm_pure
  let gray_img = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: [b'\x00', b'\x40', b'\x80', b'\xFF'] |> Bytes::from_array,
  }
  let pnm_gray = encode_pnm_pure(gray_img)
  let pgm_gray = encode_pgm_pure(gray_img)
  assert_eq(pnm_gray, pgm_gray)
  // channels=3 RGB Image -> encode_ppm_pure
  let rgb_img = pe_make_rgb_image(2, 2, [
    (10, 20, 30),
    (40, 50, 60),
    (70, 80, 90),
    (100, 110, 120),
  ])
  let pnm_rgb = encode_pnm_pure(rgb_img)
  let ppm_rgb = encode_ppm_pure(rgb_img)
  assert_eq(pnm_rgb, ppm_rgb)
  let _ = gray_img
  let _ = rgb_img
}

///|
test "encode_ppm_pure: RGBA drops alpha" {
  // 2x2 RGBA Image（alpha=128），encode_ppm_pure 应丢弃 alpha
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 4,
    data: [
      b'\x0A', b'\x14', b'\x1E', b'\x80', b'\x28', b'\x32', b'\x3C', b'\x80', b'\x46',
      b'\x50', b'\x5A', b'\x80', b'\x64', b'\x6E', b'\x78', b'\x80',
    ]
    |> Bytes::from_array,
  }
  let out = encode_ppm_pure(img)
  // header "P6\n2 2\n255\n" = 11 字节，像素 = 2*2*3 = 12 字节，总 23 字节
  assert_eq(out.length(), 23)
  // 验证 RGB 像素（alpha 被丢弃）
  // 像素 0: (10, 20, 30)
  assert_eq(out[11].to_int(), 10)
  assert_eq(out[12].to_int(), 20)
  assert_eq(out[13].to_int(), 30)
  // 像素 1: (40, 50, 60)
  assert_eq(out[14].to_int(), 40)
  assert_eq(out[15].to_int(), 50)
  assert_eq(out[16].to_int(), 60)
  // 像素 2: (70, 80, 90)
  assert_eq(out[17].to_int(), 70)
  assert_eq(out[18].to_int(), 80)
  assert_eq(out[19].to_int(), 90)
  // 像素 3: (100, 110, 120)
  assert_eq(out[20].to_int(), 100)
  assert_eq(out[21].to_int(), 110)
  assert_eq(out[22].to_int(), 120)
  let _ = img
}

///|
test "encode_ppm_pure: grayscale input to RGB" {
  // 2x2 channels=1 灰度 Image（值 100），每个灰度像素转为 RGB (100,100,100)
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: [b'\x64', b'\x64', b'\x64', b'\x64'] |> Bytes::from_array,
  }
  let out = encode_ppm_pure(img)
  // header "P6\n2 2\n255\n" = 11 字节，像素 = 2*2*3 = 12 字节，总 23 字节
  assert_eq(out.length(), 23)
  // 每个灰度像素 100 -> RGB (100, 100, 100)
  for i in 0..<4 {
    assert_eq(out[11 + i * 3].to_int(), 100)
    assert_eq(out[11 + i * 3 + 1].to_int(), 100)
    assert_eq(out[11 + i * 3 + 2].to_int(), 100)
  }
  let _ = img
}

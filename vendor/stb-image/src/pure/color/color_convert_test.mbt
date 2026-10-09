// 纯 MoonBit 色彩转换测试
// 纯逻辑断言测试（全目标可用：native/wasm/js），不依赖 @core
// 验证 to_grayscale_pure / to_rgb_pure / to_rgba_pure / premultiply_alpha_pure / unpremultiply_alpha_pure 正确性

///|
fn cc_make_image(
  width : Int,
  height : Int,
  channels : Int,
  data : Array[Byte],
) -> @types.Image {
  @types.Image::{ width, height, channels, data: Bytes::from_array(data) }
}

///|
test "to_grayscale_pure: RGB to gray" {
  // 2x2 RGB，4 个像素
  let img = cc_make_image(2, 2, 3, [
    b'\x64', b'\xC8', b'\x32', b'\x0A', b'\x14', b'\x1E', b'\xFF', b'\x00', b'\x80',
    b'\x00', b'\xFF', b'\x00',
  ])
  // 像素 (100,200,50): (100*299+200*587+50*114)/1000 = 153000/1000 = 153
  // 像素 (10,20,30):   (10*299+20*587+30*114)/1000  = 18150/1000  = 18
  // 像素 (255,0,128):  (255*299+0*587+128*114)/1000 = 90837/1000  = 90
  // 像素 (0,255,0):    (0*299+255*587+0*114)/1000   = 149685/1000 = 149
  let gray = to_grayscale_pure(img)
  assert_eq(gray.width, 2)
  assert_eq(gray.height, 2)
  assert_eq(gray.channels, 1)
  assert_eq(gray.data[0].to_int(), 153)
  assert_eq(gray.data[1].to_int(), 18)
  assert_eq(gray.data[2].to_int(), 90)
  assert_eq(gray.data[3].to_int(), 149)
  let _ = img
  let _ = gray
}

///|
test "to_grayscale_pure: already gray" {
  // channels=1 → 返回自身（同对象）
  let img = cc_make_image(2, 2, 1, [b'\x64', b'\xC8', b'\x32', b'\x0A'])
  let gray = to_grayscale_pure(img)
  assert_eq(gray.width, 2)
  assert_eq(gray.height, 2)
  assert_eq(gray.channels, 1)
  assert_eq(gray.data, img.data)
  let _ = img
  let _ = gray
}

///|
test "to_rgb_pure: RGBA to RGB" {
  // 2x2 RGBA，验证 alpha 丢弃
  let img = cc_make_image(2, 2, 4, [
    b'\x64', b'\xC8', b'\x32', b'\xFF', b'\x0A', b'\x14', b'\x1E', b'\x80', b'\xFF',
    b'\x00', b'\x80', b'\x40', b'\x00', b'\xFF', b'\x00', b'\x20',
  ])
  let rgb = to_rgb_pure(img)
  assert_eq(rgb.width, 2)
  assert_eq(rgb.height, 2)
  assert_eq(rgb.channels, 3)
  // 预期：每像素取前 3 字节，丢弃 alpha
  let expected : Array[Byte] = [
    b'\x64', b'\xC8', b'\x32', b'\x0A', b'\x14', b'\x1E', b'\xFF', b'\x00', b'\x80',
    b'\x00', b'\xFF', b'\x00',
  ]
  assert_eq(rgb.data, Bytes::from_array(expected))
  let _ = img
  let _ = rgb
}

///|
test "to_rgb_pure: already RGB" {
  // channels=3 → 返回自身
  let img = cc_make_image(2, 2, 3, [
    b'\x64', b'\xC8', b'\x32', b'\x0A', b'\x14', b'\x1E', b'\xFF', b'\x00', b'\x80',
    b'\x00', b'\xFF', b'\x00',
  ])
  let rgb = to_rgb_pure(img)
  assert_eq(rgb.width, 2)
  assert_eq(rgb.height, 2)
  assert_eq(rgb.channels, 3)
  assert_eq(rgb.data, img.data)
  let _ = img
  let _ = rgb
}

///|
test "to_rgba_pure: RGB to RGBA" {
  // 2x2 RGB → RGBA，验证 alpha=255
  let img = cc_make_image(2, 2, 3, [
    b'\x64', b'\xC8', b'\x32', b'\x0A', b'\x14', b'\x1E', b'\xFF', b'\x00', b'\x80',
    b'\x00', b'\xFF', b'\x00',
  ])
  let rgba = to_rgba_pure(img)
  assert_eq(rgba.width, 2)
  assert_eq(rgba.height, 2)
  assert_eq(rgba.channels, 4)
  // 预期：每像素 RGB 后追加 alpha=255
  let expected : Array[Byte] = [
    b'\x64', b'\xC8', b'\x32', b'\xFF', b'\x0A', b'\x14', b'\x1E', b'\xFF', b'\xFF',
    b'\x00', b'\x80', b'\xFF', b'\x00', b'\xFF', b'\x00', b'\xFF',
  ]
  assert_eq(rgba.data, Bytes::from_array(expected))
  let _ = img
  let _ = rgba
}

///|
test "to_rgba_pure: already RGBA" {
  // channels=4 → 返回自身
  let img = cc_make_image(2, 2, 4, [
    b'\x64', b'\xC8', b'\x32', b'\xFF', b'\x0A', b'\x14', b'\x1E', b'\x80', b'\xFF',
    b'\x00', b'\x80', b'\x40', b'\x00', b'\xFF', b'\x00', b'\x20',
  ])
  let rgba = to_rgba_pure(img)
  assert_eq(rgba.width, 2)
  assert_eq(rgba.height, 2)
  assert_eq(rgba.channels, 4)
  assert_eq(rgba.data, img.data)
  let _ = img
  let _ = rgba
}

///|
test "premultiply_alpha_pure: basic" {
  // 2x2 RGBA，验证 (c*a/255) 公式
  // 像素 (200,100,50,128): (200*128/255,100*128/255,50*128/255,128) = (100,50,25,128)
  // 像素 (255,0,0,255):    (255,0,0,255)
  // 像素 (0,255,0,0):      (0,0,0,0)
  // 像素 (10,20,30,64):    (10*64/255,20*64/255,30*64/255,64) = (2,5,7,64)
  let img = cc_make_image(2, 2, 4, [
    b'\xC8', b'\x64', b'\x32', b'\x80', b'\xFF', b'\x00', b'\x00', b'\xFF', b'\x00',
    b'\xFF', b'\x00', b'\x00', b'\x0A', b'\x14', b'\x1E', b'\x40',
  ])
  let out = premultiply_alpha_pure(img)
  assert_eq(out.width, 2)
  assert_eq(out.height, 2)
  assert_eq(out.channels, 4)
  assert_eq(out.data[0].to_int(), 100)
  assert_eq(out.data[1].to_int(), 50)
  assert_eq(out.data[2].to_int(), 25)
  assert_eq(out.data[3].to_int(), 128)
  assert_eq(out.data[4].to_int(), 255)
  assert_eq(out.data[5].to_int(), 0)
  assert_eq(out.data[6].to_int(), 0)
  assert_eq(out.data[7].to_int(), 255)
  assert_eq(out.data[8].to_int(), 0)
  assert_eq(out.data[9].to_int(), 0)
  assert_eq(out.data[10].to_int(), 0)
  assert_eq(out.data[11].to_int(), 0)
  assert_eq(out.data[12].to_int(), 2)
  assert_eq(out.data[13].to_int(), 5)
  assert_eq(out.data[14].to_int(), 7)
  assert_eq(out.data[15].to_int(), 64)
  let _ = img
  let _ = out
}

///|
test "premultiply_alpha_pure: channels!=4 raises" {
  // channels=3 → raise @types.LoadError::DecodeFailed
  let img = cc_make_image(2, 2, 3, [
    b'\x64', b'\xC8', b'\x32', b'\x0A', b'\x14', b'\x1E', b'\xFF', b'\x00', b'\x80',
    b'\x00', b'\xFF', b'\x00',
  ])
  let raised = try {
    let _ = premultiply_alpha_pure(img)
    false
  } catch {
    @types.LoadError::DecodeFailed(_) => true
    _ => false
  }
  assert_true(raised)
  let _ = img
}

///|
test "unpremultiply_alpha_pure: basic" {
  // 2x2 RGBA 含 alpha=0 像素
  // 像素 (100,50,25,128):  (100*255/128,50*255/128,25*255/128,128) = (199,99,49,128)
  // 像素 (255,0,0,255):    (255,0,0,255)
  // 像素 (10,20,30,0):     alpha=0 → (0,0,0,0)
  // 像素 (2,5,7,64):       (2*255/64,5*255/64,7*255/64,64) = (7,19,27,64)
  let img = cc_make_image(2, 2, 4, [
    b'\x64', b'\x32', b'\x19', b'\x80', b'\xFF', b'\x00', b'\x00', b'\xFF', b'\x0A',
    b'\x14', b'\x1E', b'\x00', b'\x02', b'\x05', b'\x07', b'\x40',
  ])
  let out = unpremultiply_alpha_pure(img)
  assert_eq(out.width, 2)
  assert_eq(out.height, 2)
  assert_eq(out.channels, 4)
  assert_eq(out.data[0].to_int(), 199)
  assert_eq(out.data[1].to_int(), 99)
  assert_eq(out.data[2].to_int(), 49)
  assert_eq(out.data[3].to_int(), 128)
  assert_eq(out.data[4].to_int(), 255)
  assert_eq(out.data[5].to_int(), 0)
  assert_eq(out.data[6].to_int(), 0)
  assert_eq(out.data[7].to_int(), 255)
  assert_eq(out.data[8].to_int(), 0)
  assert_eq(out.data[9].to_int(), 0)
  assert_eq(out.data[10].to_int(), 0)
  assert_eq(out.data[11].to_int(), 0)
  assert_eq(out.data[12].to_int(), 7)
  assert_eq(out.data[13].to_int(), 19)
  assert_eq(out.data[14].to_int(), 27)
  assert_eq(out.data[15].to_int(), 64)
  let _ = img
  let _ = out
}

///|
test "unpremultiply_alpha_pure: channels!=4 raises" {
  // channels=3 → raise @types.LoadError::DecodeFailed
  let img = cc_make_image(2, 2, 3, [
    b'\x64', b'\xC8', b'\x32', b'\x0A', b'\x14', b'\x1E', b'\xFF', b'\x00', b'\x80',
    b'\x00', b'\xFF', b'\x00',
  ])
  let raised = try {
    let _ = unpremultiply_alpha_pure(img)
    false
  } catch {
    @types.LoadError::DecodeFailed(_) => true
    _ => false
  }
  assert_true(raised)
  let _ = img
}

///|
test "convert_channels_pure: same channels returns self" {
  let img = cc_make_image(2, 2, 3, [
    b'\x64', b'\xC8', b'\x32', b'\x0A', b'\x14', b'\x1E', b'\xFF', b'\x00', b'\x80',
    b'\x00', b'\xFF', b'\x00',
  ])
  let out = convert_channels_pure(img, 3)
  assert_eq(out.channels, 3)
  assert_eq(out.data, img.data)
}

///|
test "convert_channels_pure: RGB to gray (req=1)" {
  let img = cc_make_image(2, 2, 3, [
    b'\x64', b'\xC8', b'\x32', b'\x0A', b'\x14', b'\x1E', b'\xFF', b'\x00', b'\x80',
    b'\x00', b'\xFF', b'\x00',
  ])
  let out = convert_channels_pure(img, 1)
  assert_eq(out.channels, 1)
  assert_eq(out.data[0].to_int(), 153)
}

///|
test "convert_channels_pure: RGB to gray+alpha (req=2)" {
  let img = cc_make_image(1, 1, 3, [b'\x64', b'\xC8', b'\x32'])
  let out = convert_channels_pure(img, 2)
  assert_eq(out.channels, 2)
  // gray = (100*299+200*587+50*114)/1000 = 153
  assert_eq(out.data[0].to_int(), 153)
  // alpha = 255 (no source alpha)
  assert_eq(out.data[1].to_int(), 255)
}

///|
test "convert_channels_pure: RGBA to gray+alpha (req=2)" {
  let img = cc_make_image(1, 1, 4, [b'\x64', b'\xC8', b'\x32', b'\x80'])
  let out = convert_channels_pure(img, 2)
  assert_eq(out.channels, 2)
  assert_eq(out.data[0].to_int(), 153)
  // alpha from source
  assert_eq(out.data[1].to_int(), 128)
}

///|
test "convert_channels_pure: gray to gray+alpha (req=2)" {
  let img = cc_make_image(1, 1, 1, [b'\x80'])
  let out = convert_channels_pure(img, 2)
  assert_eq(out.channels, 2)
  assert_eq(out.data[0].to_int(), 128)
  assert_eq(out.data[1].to_int(), 255)
}

///|
test "convert_channels_pure: gray+alpha to gray+alpha (req=2)" {
  let img = cc_make_image(1, 1, 2, [b'\x80', b'\x40'])
  let out = convert_channels_pure(img, 2)
  assert_eq(out.channels, 2)
  assert_eq(out.data[0].to_int(), 128)
  assert_eq(out.data[1].to_int(), 64)
}

///|
test "convert_channels_pure: gray to RGB (req=3)" {
  let img = cc_make_image(2, 1, 1, [b'\x80', b'\x40'])
  let out = convert_channels_pure(img, 3)
  assert_eq(out.channels, 3)
  // gray -> R=G=B
  assert_eq(out.data[0].to_int(), 128)
  assert_eq(out.data[1].to_int(), 128)
  assert_eq(out.data[2].to_int(), 128)
  assert_eq(out.data[3].to_int(), 64)
  assert_eq(out.data[4].to_int(), 64)
  assert_eq(out.data[5].to_int(), 64)
}

///|
test "convert_channels_pure: RGBA to RGB (req=3)" {
  let img = cc_make_image(1, 1, 4, [b'\x64', b'\xC8', b'\x32', b'\xFF'])
  let out = convert_channels_pure(img, 3)
  assert_eq(out.channels, 3)
  assert_eq(out.data[0].to_int(), 100)
  assert_eq(out.data[1].to_int(), 200)
  assert_eq(out.data[2].to_int(), 50)
}

///|
test "convert_channels_pure: gray to RGBA (req=4)" {
  let img = cc_make_image(1, 1, 1, [b'\x80'])
  let out = convert_channels_pure(img, 4)
  assert_eq(out.channels, 4)
  assert_eq(out.data[0].to_int(), 128)
  assert_eq(out.data[1].to_int(), 0)
  assert_eq(out.data[2].to_int(), 0)
  assert_eq(out.data[3].to_int(), 255)
}

///|
test "convert_channels_pure: RGB to RGBA (req=4)" {
  let img = cc_make_image(1, 1, 3, [b'\x64', b'\xC8', b'\x32'])
  let out = convert_channels_pure(img, 4)
  assert_eq(out.channels, 4)
  assert_eq(out.data[0].to_int(), 100)
  assert_eq(out.data[1].to_int(), 200)
  assert_eq(out.data[2].to_int(), 50)
  assert_eq(out.data[3].to_int(), 255)
}

///|
test "convert_channels_pure: invalid req_channels" {
  let img = cc_make_image(1, 1, 1, [b'\x80'])
  try {
    let _ = convert_channels_pure(img, 5)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "to_rgb_pure: channels < 3 returns self" {
  let img = cc_make_image(1, 1, 1, [b'\x80'])
  let out = to_rgb_pure(img)
  assert_eq(out.channels, 1)
  assert_eq(out.data, img.data)
}

///|
test "to_rgba_pure: gray to RGBA" {
  let img = cc_make_image(1, 1, 1, [b'\x80'])
  let out = to_rgba_pure(img)
  assert_eq(out.channels, 4)
  assert_eq(out.data[0].to_int(), 128)
  assert_eq(out.data[1].to_int(), 0)
  assert_eq(out.data[2].to_int(), 0)
  assert_eq(out.data[3].to_int(), 255)
}

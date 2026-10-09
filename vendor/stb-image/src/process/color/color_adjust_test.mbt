///|
test "adjust_brightness: positive delta brightens" {
  let img = @lib.load_from_bytes_auto(make_1x1_red_bmp(), req_channels=Some(3))
  // R=255,G=0,B=0 → +50 → R=255(clamped),G=50,B=50
  let result = adjust_brightness(img, 50)
  assert_eq(result.data[0].to_int(), 255)
  assert_eq(result.data[1].to_int(), 50)
  assert_eq(result.data[2].to_int(), 50)
  let _ = img
  let _ = result
}

///|
test "adjust_brightness: negative delta darkens" {
  let img = @lib.load_from_bytes_auto(make_1x1_red_bmp(), req_channels=Some(3))
  // R=255 → -50 → 205
  let result = adjust_brightness(img, -50)
  assert_eq(result.data[0].to_int(), 205)
  assert_eq(result.data[1].to_int(), 0)
  assert_eq(result.data[2].to_int(), 0)
  let _ = img
  let _ = result
}

///|
test "adjust_brightness: clamps to 0 and 255" {
  let img = @lib.load_from_bytes_auto(make_1x1_red_bmp(), req_channels=Some(3))
  let bright = adjust_brightness(img, 300)
  assert_eq(bright.data[0].to_int(), 255)
  let dark = adjust_brightness(img, -300)
  assert_eq(dark.data[0].to_int(), 0)
  let _ = img
}

///|
test "adjust_brightness: preserves alpha" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(4))
  let result = adjust_brightness(img, 50)
  // alpha 通道不变
  assert_eq(result.data[3].to_int(), img.data[3].to_int())
  let _ = img
  let _ = result
}

///|
test "adjust_contrast: factor=1.0 is identity" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let result = adjust_contrast(img, 1.0)
  assert_eq(result.data, img.data)
  let _ = img
  let _ = result
}

///|
test "adjust_contrast: factor=0.0 is gray (128)" {
  let img = @lib.load_from_bytes_auto(make_1x1_red_bmp(), req_channels=Some(3))
  let result = adjust_contrast(img, 0.0)
  // 所有像素 → 128
  assert_eq(result.data[0].to_int(), 128)
  assert_eq(result.data[1].to_int(), 128)
  assert_eq(result.data[2].to_int(), 128)
  let _ = img
  let _ = result
}

///|
test "adjust_gamma: gamma=1.0 is identity" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let result = adjust_gamma(img, 1.0)
  assert_eq(result.data, img.data)
  let _ = img
  let _ = result
}

///|
test "adjust_gamma: gamma=2.2 darkens midtones" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 3,
    data: Bytes::from_array([b'\x80', b'\x80', b'\x80']),
  }
  let result = adjust_gamma(img, 2.2)
  // 128 with gamma 2.2 should be darker
  assert_true(result.data[0].to_int() < 128)
  let _ = img
  let _ = result
}

///|
test "invert: 255 - original" {
  let img = @lib.load_from_bytes_auto(make_1x1_red_bmp(), req_channels=Some(3))
  let result = invert(img)
  // R=255→0, G=0→255, B=0→255
  assert_eq(result.data[0].to_int(), 0)
  assert_eq(result.data[1].to_int(), 255)
  assert_eq(result.data[2].to_int(), 255)
  let _ = img
  let _ = result
}

///|
test "invert: double invert is identity" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let result = invert(invert(img))
  assert_eq(result.data, img.data)
  let _ = img
  let _ = result
}

///|
test "rgb_to_hsv: red pixel" {
  let (h, s, v) = rgb_to_hsv(255, 0, 0)
  assert_eq(h, 0.0)
  assert_eq(s, 1.0)
  assert_eq(v, 1.0)
}

///|
test "rgb_to_hsv: green pixel" {
  let (h, _s, v) = rgb_to_hsv(0, 255, 0)
  assert_eq(h, 120.0)
  assert_eq(v, 1.0)
}

///|
test "rgb_to_hsv: blue pixel" {
  let (h, _s, v) = rgb_to_hsv(0, 0, 255)
  assert_eq(h, 240.0)
  assert_eq(v, 1.0)
}

///|
test "rgb_to_hsv: white pixel" {
  let (_h, s, v) = rgb_to_hsv(255, 255, 255)
  assert_eq(s, 0.0)
  assert_eq(v, 1.0)
}

///|
test "rgb_to_hsv: black pixel" {
  let (_h, s, v) = rgb_to_hsv(0, 0, 0)
  assert_eq(s, 0.0)
  assert_eq(v, 0.0)
}

///|
test "hsv_to_rgb: red pixel" {
  let (r, g, b) = hsv_to_rgb(0.0, 1.0, 1.0)
  assert_eq(r, 255)
  assert_eq(g, 0)
  assert_eq(b, 0)
}

///|
test "hsv_to_rgb: green pixel" {
  let (r, g, b) = hsv_to_rgb(120.0, 1.0, 1.0)
  assert_eq(r, 0)
  assert_eq(g, 255)
  assert_eq(b, 0)
}

///|
test "hsv_to_rgb: blue pixel" {
  let (r, g, b) = hsv_to_rgb(240.0, 1.0, 1.0)
  assert_eq(r, 0)
  assert_eq(g, 0)
  assert_eq(b, 255)
}

///|
test "hsv round-trip" {
  let (h, s, v) = rgb_to_hsv(123, 45, 200)
  let (r, g, b) = hsv_to_rgb(h, s, v)
  // 允许 ±1 的误差
  assert_true((r - 123).abs() <= 1)
  assert_true((g - 45).abs() <= 1)
  assert_true((b - 200).abs() <= 1)
}

///|
test "rgb_to_hsl: red pixel" {
  let (h, s, l) = rgb_to_hsl(255, 0, 0)
  assert_eq(h, 0.0)
  assert_eq(s, 1.0)
  assert_eq(l, 0.5)
}

///|
test "rgb_to_hsl: white pixel" {
  let (_h, s, l) = rgb_to_hsl(255, 255, 255)
  assert_eq(s, 0.0)
  assert_eq(l, 1.0)
}

///|
test "rgb_to_hsl: gray pixel" {
  let (_h, s, l) = rgb_to_hsl(128, 128, 128)
  assert_eq(s, 0.0)
  assert_true((l - 128.0 / 255.0).abs() < 0.01)
}

///|
test "hsl_to_rgb: red pixel" {
  let (r, g, b) = hsl_to_rgb(0.0, 1.0, 0.5)
  assert_eq(r, 255)
  assert_eq(g, 0)
  assert_eq(b, 0)
}

///|
test "hsl round-trip" {
  let (h, s, l) = rgb_to_hsl(100, 150, 200)
  let (r, g, b) = hsl_to_rgb(h, s, l)
  assert_true((r - 100).abs() <= 1)
  assert_true((g - 150).abs() <= 1)
  assert_true((b - 200).abs() <= 1)
}

// ==================== RGBA alpha 保留测试 ====================

///|
test "adjust_contrast: preserves alpha (RGBA)" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 4,
    data: Bytes::from_array([b'\x80', b'\x40', b'\x20', b'\xC0']),
  }
  let result = adjust_contrast(img, 2.0)
  assert_eq(result.channels, 4)
  assert_eq(result.data[3], b'\xC0')
}

///|
test "adjust_gamma: preserves alpha (RGBA)" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 4,
    data: Bytes::from_array([b'\x80', b'\x40', b'\x20', b'\xC0']),
  }
  let result = adjust_gamma(img, 2.2)
  assert_eq(result.channels, 4)
  assert_eq(result.data[3], b'\xC0')
}

///|
test "invert: preserves alpha (RGBA)" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 4,
    data: Bytes::from_array([b'\x80', b'\x40', b'\x20', b'\xC0']),
  }
  let result = invert(img)
  assert_eq(result.channels, 4)
  assert_eq(result.data[3], b'\xC0')
}

// ==================== HSV/HSL 边界测试 ====================

///|
test "hsv_to_rgb: h >= 360 normalization" {
  // h=420 should be same as h=60 (yellow)
  let (r1, g1, b1) = hsv_to_rgb(420.0, 1.0, 1.0)
  let (r2, g2, b2) = hsv_to_rgb(60.0, 1.0, 1.0)
  assert_eq(r1, r2)
  assert_eq(g1, g2)
  assert_eq(b1, b2)
}

///|
test "hsv_to_rgb: h < 0 normalization" {
  // h=-60 should be same as h=300 (magenta)
  let (r1, g1, b1) = hsv_to_rgb(-60.0, 1.0, 1.0)
  let (r2, g2, b2) = hsv_to_rgb(300.0, 1.0, 1.0)
  assert_eq(r1, r2)
  assert_eq(g1, g2)
  assert_eq(b1, b2)
}

///|
test "hsv_to_rgb: hp in [5,6) magenta-red" {
  // h=330 → hp=5.5, tests the hp >= 5.0 branch
  let (r, g, b) = hsv_to_rgb(330.0, 1.0, 1.0)
  assert_true(r > 200)
  assert_true(g < 50)
  assert_true(b > 100)
}

///|
test "rgb_to_hsl: green max" {
  // Green is max → tests mx == gf branch
  let (h, _s, _l) = rgb_to_hsl(0, 255, 128)
  assert_true(h > 100.0 && h < 180.0)
}

///|
test "hsl_to_rgb: h >= 360 normalization" {
  let (r1, g1, b1) = hsl_to_rgb(420.0, 1.0, 0.5)
  let (r2, g2, b2) = hsl_to_rgb(60.0, 1.0, 0.5)
  assert_eq(r1, r2)
  assert_eq(g1, g2)
  assert_eq(b1, b2)
}

///|
test "hsl_to_rgb: h < 0 normalization" {
  let (r1, g1, b1) = hsl_to_rgb(-60.0, 1.0, 0.5)
  let (r2, g2, b2) = hsl_to_rgb(300.0, 1.0, 0.5)
  assert_eq(r1, r2)
  assert_eq(g1, g2)
  assert_eq(b1, b2)
}

///|
test "hsl_to_rgb: hp in [2,3) range" {
  // h=150 → hp=2.5, tests hp < 3.0 branch
  let (r, g, b) = hsl_to_rgb(150.0, 1.0, 0.5)
  assert_true(r < 50)
  assert_true(g > 200)
  assert_true(b > 50)
}

///|
test "hsl_to_rgb: hp in [3,4) range" {
  // h=210 → hp=3.5, tests hp < 4.0 branch
  let (r, g, b) = hsl_to_rgb(210.0, 1.0, 0.5)
  assert_true(r < 50)
  assert_true(g > 50)
  assert_true(b > 200)
}

///|
test "hsl_to_rgb: hp in [5,6) range" {
  // h=330 → hp=5.5, tests hp >= 5.0 branch
  let (r, g, b) = hsl_to_rgb(330.0, 1.0, 0.5)
  assert_true(r > 200)
  assert_true(g < 50)
  assert_true(b > 100)
}

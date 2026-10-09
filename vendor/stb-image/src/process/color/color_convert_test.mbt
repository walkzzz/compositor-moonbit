///|
test "to_grayscale: RGB → 1 channel" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let gray = to_grayscale(img)
  assert_eq(gray.width, 4)
  assert_eq(gray.height, 4)
  assert_eq(gray.channels, 1)
  let _ = img
  let _ = gray
}

///|
test "to_grayscale: already grayscale is identity" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(1))
  let gray = to_grayscale(img)
  assert_eq(gray.channels, 1)
  assert_eq(gray.data, img.data)
  let _ = img
  let _ = gray
}

///|
test "to_rgb: RGBA → RGB" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(4))
  let rgb = to_rgb(img)
  assert_eq(rgb.channels, 3)
  assert_eq(rgb.data.length(), 4 * 4 * 3)
  let _ = img
  let _ = rgb
}

///|
test "to_rgb: already RGB is identity" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let rgb = to_rgb(img)
  assert_eq(rgb.channels, 3)
  assert_eq(rgb.data, img.data)
  let _ = img
  let _ = rgb
}

///|
test "to_rgba: RGB → RGBA" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let rgba = to_rgba(img)
  assert_eq(rgba.channels, 4)
  assert_eq(rgba.data.length(), 4 * 4 * 4)
  // alpha should be 255
  assert_eq(rgba.data[3].to_int(), 255)
  let _ = img
  let _ = rgba
}

///|
test "to_rgba: already RGBA is identity" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(4))
  let rgba = to_rgba(img)
  assert_eq(rgba.channels, 4)
  assert_eq(rgba.data, img.data)
  let _ = img
  let _ = rgba
}

///|
test "premultiply_alpha: full opacity is identity" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(4))
  let premul = premultiply_alpha(img)
  // alpha=255 → premultiply is identity
  assert_eq(premul.data, img.data)
  let _ = img
  let _ = premul
}

///|
test "premultiply/unpremultiply round-trip" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(4))
  let premul = premultiply_alpha(img)
  let restored = unpremultiply_alpha(premul)
  assert_eq(restored.width, 4)
  assert_eq(restored.height, 4)
  let _ = img
  let _ = restored
}

///|
test "premultiply_alpha: non-RGBA raises" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  try {
    let _ = premultiply_alpha(img)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "to_grayscale: red pixel luminance" {
  let img = @lib.load_from_bytes_auto(make_1x1_red_bmp(), req_channels=Some(3))
  let gray = to_grayscale(img)
  // R=255, G=0, B=0 → Y = 0.299*255 = 76
  assert_eq(gray.data[0].to_int(), 76)
  let _ = img
  let _ = gray
}

///|
test "rgb_to_ycbcr: roundtrip" {
  let (y, cb, cr) = rgb_to_ycbcr(100, 150, 200)
  let (r, g, b) = ycbcr_to_rgb(y, cb, cr)
  // 允许 ±2 误差（整数运算精度）
  assert_true((r - 100).abs() <= 2)
  assert_true((g - 150).abs() <= 2)
  assert_true((b - 200).abs() <= 2)
}

///|
test "rgb_to_ycbcr: gray pixel" {
  let (y, cb, cr) = rgb_to_ycbcr(128, 128, 128)
  assert_eq(y, 128)
  assert_eq(cb, 128)
  assert_eq(cr, 128)
}

///|
test "rgb_to_xyz: black and white" {
  let (x0, y0, z0) = rgb_to_xyz(0, 0, 0)
  assert_true(x0 < 0.001F)
  assert_true(y0 < 0.001F)
  assert_true(z0 < 0.001F)
  let (_x1, y1, _z1) = rgb_to_xyz(255, 255, 255)
  // 白色 Y 应接近 1.0
  assert_true((y1 - 1.0F).abs() < 0.01F)
}

///|
test "rgb_to_lab: roundtrip" {
  let (l, a, b) = rgb_to_lab(100, 150, 200)
  let (r, g, bl) = lab_to_rgb(l, a, b)
  // 允许 ±3 误差（浮点+gamma 精度）
  assert_true((r - 100).abs() <= 3)
  assert_true((g - 150).abs() <= 3)
  assert_true((bl - 200).abs() <= 3)
}

///|
test "rgb_to_lab: gray pixel" {
  let (l, a, b) = rgb_to_lab(128, 128, 128)
  // 灰色 a 和 b 应接近 0
  assert_true(a.abs() < 1.0F)
  assert_true(b.abs() < 1.0F)
  // L 应在 50-60 之间
  assert_true(l > 50.0F && l < 60.0F)
}

///|
test "rgb_to_cmyk: roundtrip" {
  let (c, m, y, k) = rgb_to_cmyk(100, 150, 200)
  let (r, g, b) = cmyk_to_rgb(c, m, y, k)
  // 允许 ±1 误差
  assert_true((r - 100).abs() <= 1)
  assert_true((g - 150).abs() <= 1)
  assert_true((b - 200).abs() <= 1)
}

///|
test "rgb_to_cmyk: black pixel" {
  let (c, m, y, k) = rgb_to_cmyk(0, 0, 0)
  assert_eq(k, 255)
  assert_eq(c, 0)
  assert_eq(m, 0)
  assert_eq(y, 0)
}

///|
test "rgb_to_cmyk: white pixel" {
  let (c, m, y, k) = rgb_to_cmyk(255, 255, 255)
  assert_eq(k, 0)
  assert_eq(c, 0)
  assert_eq(m, 0)
  assert_eq(y, 0)
}

// ==================== 错误路径 + 边界测试 ====================

///|
test "unpremultiply_alpha: invalid channels raises" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 3,
    data: Bytes::from_array([b'\x80', b'\x40', b'\x20']),
  }
  try {
    let _ = unpremultiply_alpha(img)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "unpremultiply_alpha: zero alpha pixel" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 4,
    data: Bytes::from_array([b'\x80', b'\x40', b'\x20', b'\x00']),
  }
  let result = unpremultiply_alpha(img)
  // alpha=0 → all zeros
  assert_eq(result.data[0], b'\x00')
  assert_eq(result.data[1], b'\x00')
  assert_eq(result.data[2], b'\x00')
  assert_eq(result.data[3], b'\x00')
}

///|
test "rgb_to_xyz: roundtrip" {
  let (x, y, z) = rgb_to_xyz(100, 150, 200)
  let (r, g, b) = xyz_to_rgb(x, y, z)
  assert_true((r - 100).abs() <= 2)
  assert_true((g - 150).abs() <= 2)
  assert_true((b - 200).abs() <= 2)
}

///|
test "rgb_to_lab: dark pixel (f(t) <= 0.008856)" {
  // Very dark pixel tests the linear branch of Lab f(t)
  let (l, a, b) = rgb_to_lab(5, 5, 5)
  assert_true(l < 10.0F)
  assert_true(a.abs() < 5.0F)
  assert_true(b.abs() < 5.0F)
}

///|
test "rgb_to_cmyk: k from min(c,y) when c < m and c < y" {
  // R=200, G=50, B=100 → R'=55, G'=205, B'=155 → c is min → k=55
  let (_c, _m, _y, k) = rgb_to_cmyk(200, 50, 100)
  assert_true(k > 0)
}

///|
test "rgb_to_ycbcr: roundtrip with color" {
  let (y, cb, cr) = rgb_to_ycbcr(100, 150, 200)
  let (r, g, b) = ycbcr_to_rgb(y, cb, cr)
  assert_true((r - 100).abs() <= 2)
  assert_true((g - 150).abs() <= 2)
  assert_true((b - 200).abs() <= 2)
}

///|
test "xyz_to_rgb: srgb linear branch (small values)" {
  // Very small XYZ values trigger the linear branch: c <= 0.0031308
  let (r, g, b) = xyz_to_rgb(0.001F, 0.001F, 0.001F)
  assert_true(r >= 0 && r <= 255)
  assert_true(g >= 0 && g <= 255)
  assert_true(b >= 0 && b <= 255)
}

///|
test "lab_to_rgb: f_inv small branch (low L)" {
  // Very low L triggers f_inv small branch: powf(t,3) <= 0.008856
  let (r, g, b) = lab_to_rgb(1.0F, 0.0F, 0.0F)
  assert_true(r >= 0 && r <= 255)
  assert_true(g >= 0 && g <= 255)
  assert_true(b >= 0 && b <= 255)
}

///|
test "rgb_to_cmyk: k from m when m < c and m < y" {
  // R=50, G=200, B=100 → c=205, m=55, y=155 → m is min → k=55
  let (_c, _m, _y, k) = rgb_to_cmyk(50, 200, 100)
  assert_true(k > 0)
}

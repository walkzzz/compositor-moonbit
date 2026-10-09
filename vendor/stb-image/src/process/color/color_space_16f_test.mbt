// 颜色空间转换 16-bit/float 变体测试

///|
test "rgb_to_hsl_16 basic" {
  let (h, s, l) = @color.rgb_to_hsl_16(65535, 0, 0)
  assert_eq(h, 0.0F)
  assert_eq(s, 1.0F)
  assert_eq(l, 0.5F)
}

///|
test "rgb_to_hsl_f basic" {
  let (h, s, l) = @color.rgb_to_hsl_f(1.0F, 0.0F, 0.0F)
  assert_eq(h, 0.0F)
  assert_eq(s, 1.0F)
  assert_eq(l, 0.5F)
}

///|
test "hsl_to_rgb_16 basic" {
  let (r, g, b) = @color.hsl_to_rgb_16(0.0F, 1.0F, 0.5F)
  assert_eq(r, 65535)
  assert_eq(g, 0)
  assert_eq(b, 0)
}

///|
test "hsl_to_rgb_f basic" {
  let (r, g, b) = @color.hsl_to_rgb_f(0.0F, 1.0F, 0.5F)
  assert_eq(r, 1.0F)
  assert_eq(g, 0.0F)
  assert_eq(b, 0.0F)
}

///|
test "rgb_to_hsv_16 basic" {
  let (h, s, v) = @color.rgb_to_hsv_16(65535, 0, 0)
  assert_eq(h, 0.0F)
  assert_eq(s, 1.0F)
  assert_eq(v, 1.0F)
}

///|
test "rgb_to_hsv_f basic" {
  let (h, s, v) = @color.rgb_to_hsv_f(1.0F, 0.0F, 0.0F)
  assert_eq(h, 0.0F)
  assert_eq(s, 1.0F)
  assert_eq(v, 1.0F)
}

///|
test "hsv_to_rgb_16 basic" {
  let (r, g, b) = @color.hsv_to_rgb_16(0.0F, 1.0F, 1.0F)
  assert_eq(r, 65535)
  assert_eq(g, 0)
  assert_eq(b, 0)
}

///|
test "hsv_to_rgb_f basic" {
  let (r, g, b) = @color.hsv_to_rgb_f(0.0F, 1.0F, 1.0F)
  assert_eq(r, 1.0F)
  assert_eq(g, 0.0F)
  assert_eq(b, 0.0F)
}

///|
test "rgb_to_xyz_16 white" {
  let (x, y, z) = @color.rgb_to_xyz_16(65535, 65535, 65535)
  assert_true(x >= 0.9F)
  assert_true(y >= 0.9F)
  assert_true(z >= 0.9F)
}

///|
test "rgb_to_xyz_f white" {
  let (x, y, z) = @color.rgb_to_xyz_f(1.0F, 1.0F, 1.0F)
  assert_true(x >= 0.9F)
  assert_true(y >= 0.9F)
  assert_true(z >= 0.9F)
}

///|
test "xyz_to_rgb_16 white" {
  try {
    let (r, g, b) = @color.xyz_to_rgb_16(0.9505F, 1.0F, 1.089F)
    assert_true(r >= 65000)
    assert_true(g >= 65000)
    assert_true(b >= 65000)
  } catch {
    _ => assert_true(false) // 不应该抛出错误
  }
}

///|
test "xyz_to_rgb_f white" {
  let (r, g, b) = @color.xyz_to_rgb_f(0.9505F, 1.0F, 1.089F)
  assert_true(r >= 0.99F)
  assert_true(g >= 0.99F)
  assert_true(b >= 0.99F)
}

///|
test "rgb_to_lab_16 white" {
  let (l, a, b) = @color.rgb_to_lab_16(65535, 65535, 65535)
  assert_true(l >= 99.0F)
  assert_true(a.abs() <= 1.0F)
  assert_true(b.abs() <= 1.0F)
}

///|
test "rgb_to_lab_f white" {
  let (l, a, b) = @color.rgb_to_lab_f(1.0F, 1.0F, 1.0F)
  assert_true(l >= 99.0F)
  assert_true(a.abs() <= 1.0F)
  assert_true(b.abs() <= 1.0F)
}

///|
test "lab_to_rgb_16 white" {
  try {
    let (r, g, b) = @color.lab_to_rgb_16(100.0F, 0.0F, 0.0F)
    assert_true(r >= 65000)
    assert_true(g >= 65000)
    assert_true(b >= 65000)
  } catch {
    _ => assert_true(false) // 不应该抛出错误
  }
}

///|
test "lab_to_rgb_f white" {
  let (r, g, b) = @color.lab_to_rgb_f(100.0F, 0.0F, 0.0F)
  assert_true(r >= 0.99F)
  assert_true(g >= 0.99F)
  assert_true(b >= 0.99F)
}

///|
test "hsl roundtrip_16" {
  let (h, s, l) = @color.rgb_to_hsl_16(100, 150, 200)
  let (r, g, b) = @color.hsl_to_rgb_16(h, s, l)
  assert_true((r - 100).abs() <= 256)
  assert_true((g - 150).abs() <= 256)
  assert_true((b - 200).abs() <= 256)
}

///|
test "hsv roundtrip_f" {
  let (h, s, v) = @color.rgb_to_hsv_f(0.4F, 0.6F, 0.8F)
  let (r, g, b) = @color.hsv_to_rgb_f(h, s, v)
  assert_true((r - 0.4F).abs() <= 0.01F)
  assert_true((g - 0.6F).abs() <= 0.01F)
  assert_true((b - 0.8F).abs() <= 0.01F)
}

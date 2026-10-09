// 纯 MoonBit 全局配置测试
// 覆盖所有 set/get 函数

///|
test "config: flip_vertically_on_load" {
  set_flip_vertically_on_load_pure(true)
  assert_true(get_flip_vertically_on_load_pure())
  set_flip_vertically_on_load_pure(false)
  assert_false(get_flip_vertically_on_load_pure())
}

///|
test "config: flip_vertically_on_write" {
  flip_vertically_on_write_pure(true)
  assert_true(get_flip_vertically_on_write_pure())
  flip_vertically_on_write_pure(false)
  assert_false(get_flip_vertically_on_write_pure())
}

///|
test "config: unpremultiply_on_load" {
  set_unpremultiply_on_load_pure(true)
  assert_true(get_unpremultiply_on_load_pure())
  set_unpremultiply_on_load_pure(false)
  assert_false(get_unpremultiply_on_load_pure())
}

///|
test "config: convert_iphone_png_to_rgb" {
  convert_iphone_png_to_rgb_pure(true)
  assert_true(get_convert_iphone_png_to_rgb_pure())
  convert_iphone_png_to_rgb_pure(false)
  assert_false(get_convert_iphone_png_to_rgb_pure())
}

///|
test "config: hdr_to_ldr_gamma" {
  hdr_to_ldr_gamma_pure(2.2F)
  assert_eq(get_hdr_to_ldr_gamma_pure(), 2.2F)
  hdr_to_ldr_gamma_pure(1.0F)
  assert_eq(get_hdr_to_ldr_gamma_pure(), 1.0F)
}

///|
test "config: hdr_to_ldr_scale" {
  hdr_to_ldr_scale_pure(0.5F)
  assert_eq(get_hdr_to_ldr_scale_pure(), 0.5F)
  hdr_to_ldr_scale_pure(1.0F)
  assert_eq(get_hdr_to_ldr_scale_pure(), 1.0F)
}

///|
test "config: ldr_to_hdr_gamma" {
  ldr_to_hdr_gamma_pure(2.2F)
  assert_eq(get_ldr_to_hdr_gamma_pure(), 2.2F)
  ldr_to_hdr_gamma_pure(1.0F)
  assert_eq(get_ldr_to_hdr_gamma_pure(), 1.0F)
}

///|
test "config: ldr_to_hdr_scale" {
  ldr_to_hdr_scale_pure(2.0F)
  assert_eq(get_ldr_to_hdr_scale_pure(), 2.0F)
  ldr_to_hdr_scale_pure(1.0F)
  assert_eq(get_ldr_to_hdr_scale_pure(), 1.0F)
}

///|
test "se_rect: creates all-true kernel" {
  let se = se_rect(3, 3)
  assert_eq(se.width, 3)
  assert_eq(se.height, 3)
  for i in 0..<9 {
    assert_true(se.data[i])
  }
}

///|
test "se_cross: creates cross shape" {
  let se = se_cross(3)
  assert_eq(se.width, 3)
  assert_eq(se.height, 3)
  // Center row and column should be true
  assert_true(se.data[1 * 3 + 0]) // left
  assert_true(se.data[1 * 3 + 1]) // center
  assert_true(se.data[1 * 3 + 2]) // right
  assert_true(se.data[0 * 3 + 1]) // top
  assert_true(se.data[2 * 3 + 1]) // bottom
  // Corners should be false
  assert_false(se.data[0 * 3 + 0])
  assert_false(se.data[0 * 3 + 2])
  assert_false(se.data[2 * 3 + 0])
  assert_false(se.data[2 * 3 + 2])
}

///|
test "se_ellipse: 3x3 ellipse equals cross" {
  let se = se_ellipse(3)
  // For 3x3, ellipse should be same as cross
  assert_true(se.data[1 * 3 + 1])
  assert_true(se.data[0 * 3 + 1])
  assert_true(se.data[2 * 3 + 1])
  assert_true(se.data[1 * 3 + 0])
  assert_true(se.data[1 * 3 + 2])
}

///|
test "erode_custom: 3x3 rect SE matches default erode" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: b"\x00\x00\xFF\xFF\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF",
  }
  let se = se_rect(3, 3)
  let result_custom = erode_custom(img, se)
  let result_default = erode(img)
  for i in 0..<16 {
    assert_eq(result_custom.data[i], result_default.data[i])
  }
}

///|
test "dilate_custom: 3x3 rect SE matches default dilate" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: b"\x00\x00\xFF\xFF\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF",
  }
  let se = se_rect(3, 3)
  let result_custom = dilate_custom(img, se)
  let result_default = dilate(img)
  for i in 0..<16 {
    assert_eq(result_custom.data[i], result_default.data[i])
  }
}

///|
test "morph_open_custom: removes bright noise" {
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: b"\x00\x00\x00\x00\x00\x00\xFF\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
  }
  let se = se_cross(3)
  let result = morph_open_custom(img, se)
  // Single bright pixel should be removed by opening with 3x3 cross
  let mut has_white = false
  for i in 0..<25 {
    if result.data[i].to_int() > 128 {
      has_white = true
    }
  }
  assert_false(has_white)
}

///|
test "morph_close_custom: fills dark hole" {
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: b"\xFF\xFF\xFF\xFF\xFF\xFF\x00\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF",
  }
  let se = se_cross(3)
  let result = morph_close_custom(img, se)
  // Single dark pixel should be filled by closing with 3x3 cross
  assert_eq(result.data[6].to_int(), 255)
}

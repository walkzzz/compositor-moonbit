// image_util 测试：pad / add_border

///|
fn make_test_img(w : Int, h : Int, ch : Int, v : Byte) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Array::make(w * h * ch, v) |> Bytes::from_array,
  }
}

///|
test "pad: 2x2 -> 4x4 with zero padding" {
  let img = make_test_img(2, 2, 3, b'\xFF')
  let padded = pad(img, 1, 1, [b'\x00', b'\x00', b'\x00'])
  assert_eq(padded.width, 4)
  assert_eq(padded.height, 4)
  // 中心 2x2 应为白色
  assert_eq(padded.data[(1 * 4 + 1) * 3], b'\xFF')
  // 左上角应为黑色
  assert_eq(padded.data[0], b'\x00')
  let _ = img
  let _ = padded
}

///|
test "pad: zero padding is identity" {
  let img = make_test_img(2, 2, 3, b'\x80')
  let padded = pad(img, 0, 0, [b'\x00'])
  assert_eq(padded.data, img.data)
  let _ = img
  let _ = padded
}

///|
test "pad: raises on negative padding" {
  let img = make_test_img(2, 2, 3, b'\xFF')
  try {
    let _ = pad(img, -1, 0, [b'\x00'])
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "add_border: 2x2 -> 4x4 with border=1" {
  let img = make_test_img(2, 2, 3, b'\xFF')
  let bordered = add_border(img, 1, 1, 1, 1, [b'\x00', b'\x00', b'\x00'])
  assert_eq(bordered.width, 4)
  assert_eq(bordered.height, 4)
  // 中心应为白色
  assert_eq(bordered.data[(1 * 4 + 1) * 3], b'\xFF')
  // 边框应为黑色
  assert_eq(bordered.data[0], b'\x00')
  let _ = img
  let _ = bordered
}

///|
test "add_border: asymmetric borders" {
  let img = make_test_img(2, 2, 1, b'\xFF')
  let bordered = add_border(img, 1, 2, 3, 4, [b'\x00'])
  assert_eq(bordered.width, 8)
  assert_eq(bordered.height, 6)
  let _ = img
  let _ = bordered
}

///|
test "pad: raises on empty pad_color" {
  let img = make_test_img(2, 2, 3, b'\xFF')
  try {
    let _ = pad(img, 1, 1, [])
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "add_border: raises on empty border_color" {
  let img = make_test_img(2, 2, 3, b'\xFF')
  try {
    let _ = add_border(img, 1, 1, 1, 1, [])
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

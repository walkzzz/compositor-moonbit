// resize_to_cover / resize_to_contain 测试

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
test "resize_to_cover: 4x4 -> 8x8 square" {
  let img = make_test_img(4, 4, 3, b'\x80')
  let result = resize_to_cover(img, 8, 8)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  let _ = img
  let _ = result
}

///|
test "resize_to_cover: 4x2 -> 8x8 covers and crops" {
  let img = make_test_img(4, 2, 3, b'\x80')
  let result = resize_to_cover(img, 8, 8)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  let _ = img
  let _ = result
}

///|
test "resize_to_contain: 4x4 -> 8x8 fits inside" {
  let img = make_test_img(4, 4, 3, b'\x80')
  let result = resize_to_contain(img, 8, 8, [b'\x00', b'\x00', b'\x00'])
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  let _ = img
  let _ = result
}

///|
test "resize_to_contain: 4x2 -> 8x8 letterboxed" {
  let img = make_test_img(4, 2, 3, b'\x80')
  let result = resize_to_contain(img, 8, 8, [b'\x00', b'\x00', b'\x00'])
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  let _ = img
  let _ = result
}

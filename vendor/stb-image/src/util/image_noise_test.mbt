// image_noise 测试

///|
test "add_noise_gaussian: preserves dimensions" {
  let img = mk(4, 4, 3, b'\x80')
  let result = add_noise_gaussian(img, 10.0F, 42U)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "add_noise_gaussian: sigma=0 is identity" {
  let img = mk(2, 2, 1, b'\x80')
  let result = add_noise_gaussian(img, 0.0F, 42U)
  assert_eq(result.data, img.data)
  let _ = img
  let _ = result
}

///|
test "add_noise_gaussian: preserves alpha" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 4,
    data: [b'\x80', b'\x80', b'\x80', b'\xFF'] |> Bytes::from_array,
  }
  let result = add_noise_gaussian(img, 10.0F, 42U)
  assert_eq(result.data[3], b'\xFF')
  let _ = img
  let _ = result
}

///|
test "add_noise_salt_pepper: prob=0 is identity" {
  let img = mk(2, 2, 1, b'\x80')
  let result = add_noise_salt_pepper(img, 0.0F, 42U)
  assert_eq(result.data, img.data)
  let _ = img
  let _ = result
}

///|
test "add_noise_salt_pepper: prob=1 all noise" {
  let img = mk(4, 4, 1, b'\x80')
  let result = add_noise_salt_pepper(img, 1.0F, 42U)
  // 所有像素应该为 0 或 255
  for i in 0..<16 {
    let v = result.data[i].to_int()
    assert_true(v == 0 || v == 255)
  }
  let _ = img
  let _ = result
}

///|
test "add_noise_salt_pepper: preserves dimensions" {
  let img = mk(3, 3, 3, b'\x80')
  let result = add_noise_salt_pepper(img, 0.1F, 42U)
  assert_eq(result.width, 3)
  assert_eq(result.height, 3)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

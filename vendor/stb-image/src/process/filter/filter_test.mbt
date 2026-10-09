///|
test "box_blur: radius=0 is identity" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let result = box_blur(img, 0)
  assert_eq(result.data, img.data)
  let _ = img
  let _ = result
}

///|
test "box_blur: radius=1 smooths image" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let result = box_blur(img, 1)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "box_blur: preserves alpha channel" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(4))
  let result = box_blur(img, 1)
  // alpha 不变
  assert_eq(result.data[3].to_int(), img.data[3].to_int())
  let _ = img
  let _ = result
}

///|
test "box_blur: uniform image is unchanged" {
  // 全白图模糊后还是全白
  let img = @types.Image::{
    width: 3,
    height: 3,
    channels: 1,
    data: Array::make(9, b'\xFF') |> Bytes::from_array,
  }
  let result = box_blur(img, 1)
  for i in 0..<9 {
    assert_eq(result.data[i].to_int(), 255)
  }
  let _ = img
  let _ = result
}

///|
test "gaussian_blur: radius=0 is identity" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let result = gaussian_blur(img, 0, 1.0F)
  assert_eq(result.data, img.data)
  let _ = img
  let _ = result
}

///|
test "gaussian_blur: smooths image" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let result = gaussian_blur(img, 2, 1.5F)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  let _ = img
  let _ = result
}

///|
test "gaussian_blur: uniform image is unchanged" {
  let img = @types.Image::{
    width: 3,
    height: 3,
    channels: 1,
    data: Array::make(9, b'\x80') |> Bytes::from_array,
  }
  let result = gaussian_blur(img, 1, 1.0F)
  for i in 0..<9 {
    assert_eq(result.data[i].to_int(), 128)
  }
  let _ = img
  let _ = result
}

///|
test "sharpen: amount=0 is identity" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let result = sharpen(img, 0.0F)
  assert_eq(result.data, img.data)
  let _ = img
  let _ = result
}

///|
test "sharpen: uniform image is unchanged" {
  let img = @types.Image::{
    width: 3,
    height: 3,
    channels: 1,
    data: Array::make(9, b'\x80') |> Bytes::from_array,
  }
  let result = sharpen(img, 1.0F)
  for i in 0..<9 {
    assert_eq(result.data[i].to_int(), 128)
  }
  let _ = img
  let _ = result
}

///|
test "sharpen: preserves alpha" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(4))
  let result = sharpen(img, 0.5F)
  assert_eq(result.data[3].to_int(), img.data[3].to_int())
  let _ = img
  let _ = result
}

///|
test "box_blur: radius exceeds image size" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let result = box_blur(img, 100)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "gaussian_blur: radius exceeds image size" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let result = gaussian_blur(img, 100, 1.5F)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "median_blur: ksize=1 is identity" {
  let img = @types.Image::{
    width: 3,
    height: 3,
    channels: 1,
    data: [10, 20, 30, 40, 50, 60, 70, 80, 90].map(fn(x) { x.to_byte() })
    |> Bytes::from_array,
  }
  let result = median_blur(img, 1)
  assert_eq(result.data, img.data)
  let _ = img
  let _ = result
}

///|
test "median_blur: removes salt pepper noise" {
  // 5x5 均匀灰度图，中心一个椒盐噪声
  let data = Array::make(25, b'\x80')
  data[2 * 5 + 2] = b'\x00'
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let result = median_blur(img, 3)
  // 中心噪声应被去除（中值=128）
  assert_eq(result.data[2 * 5 + 2].to_int(), 128)
  let _ = img
  let _ = result
}

///|
test "median_blur: preserves uniform image" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 3,
    data: Array::make(48, b'\x64') |> Bytes::from_array,
  }
  let result = median_blur(img, 3)
  for i in 0..<48 {
    assert_eq(result.data[i].to_int(), 100)
  }
  let _ = img
  let _ = result
}

///|
test "median_blur: preserves alpha channel" {
  let img = @types.Image::{
    width: 3,
    height: 3,
    channels: 4,
    data: Array::make(36, b'\x80') |> Bytes::from_array,
  }
  let result = median_blur(img, 3)
  // alpha 不变
  for i in 0..<9 {
    assert_eq(result.data[i * 4 + 3].to_int(), 128)
  }
  let _ = img
  let _ = result
}

///|
fn make_img(w : Int, h : Int, ch : Int, v : Byte) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Array::make(w * h * ch, v) |> Bytes::from_array,
  }
}

///|
test "convolve: identity kernel" {
  let img = make_img(3, 3, 1, b'\x80')
  let identity = [0.0F, 0.0F, 0.0F, 0.0F, 1.0F, 0.0F, 0.0F, 0.0F, 0.0F]
  let result = convolve(img, identity, 0.0F, 1.0F)
  assert_eq(result.data[4], b'\x80')
  let _ = img
  let _ = result
}

///|
test "convolve: box blur kernel" {
  let img = @types.Image::{
    width: 3,
    height: 3,
    channels: 1,
    data: [
      b'\x00', b'\x00', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\x00', b'\x00',
    ]
    |> Bytes::from_array,
  }
  let blur = [
    0.111F, 0.111F, 0.111F, 0.111F, 0.111F, 0.111F, 0.111F, 0.111F, 0.111F,
  ]
  let result = convolve(img, blur, 0.0F, 1.0F)
  // 中心像素应该被模糊（值降低）
  let center = result.data[4].to_int()
  assert_true(center > 0 && center < 255)
  let _ = img
  let _ = result
}

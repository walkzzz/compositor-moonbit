///|
test "mse: identical images return 0" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: Array::make(4, b'\x80') |> Bytes::from_array,
  }
  assert_eq(mse(img, img), 0.0)
  let _ = img
}

///|
test "mse: known value" {
  // img1 = [0, 0, 0, 0], img2 = [10, 10, 10, 10]
  // MSE = (100 + 100 + 100 + 100) / 4 = 100
  let img1 = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: Array::make(4, b'\x00') |> Bytes::from_array,
  }
  let img2 = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: Array::make(4, (10).to_byte()) |> Bytes::from_array,
  }
  assert_eq(mse(img1, img2), 100.0)
  let _ = img1
  let _ = img2
}

///|
test "psnr: identical images return infinity" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: Array::make(4, b'\x80') |> Bytes::from_array,
  }
  let result = psnr(img, img)
  assert_true(result > 1000.0)
  let _ = img
  let _ = result
}

///|
test "psnr: known value" {
  // MSE = 100, PSNR = 10 * log10(255^2 / 100) = 10 * log10(650.25) ≈ 28.13
  let img1 = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: Array::make(4, b'\x00') |> Bytes::from_array,
  }
  let img2 = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: Array::make(4, (10).to_byte()) |> Bytes::from_array,
  }
  let result = psnr(img1, img2)
  // 验证 PSNR 在合理范围内（约 28 dB）
  assert_true(result > 27.0 && result < 29.0)
  let _ = img1
  let _ = img2
  let _ = result
}

///|
test "ssim: identical images return ~1" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Array::make(16, b'\x80') |> Bytes::from_array,
  }
  let result = ssim(img, img)
  assert_true(result > 0.99)
  let _ = img
  let _ = result
}

///|
test "ssim: range [-1, 1]" {
  let img1 = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Array::make(16, b'\x00') |> Bytes::from_array,
  }
  let img2 = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Array::make(16, b'\xFF') |> Bytes::from_array,
  }
  let result = ssim(img1, img2)
  assert_true(result >= -1.0 && result <= 1.0)
  let _ = img1
  let _ = img2
  let _ = result
}

///|
test "mse: works with RGB images" {
  let img1 = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let img2 = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  assert_eq(mse(img1, img2), 0.0)
  let _ = img1
  let _ = img2
}

///|
test "psnr: higher for similar images" {
  let img1 = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: Array::make(4, b'\x80') |> Bytes::from_array,
  }
  let img_close = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: Array::make(4, b'\x82') |> Bytes::from_array,
  }
  let img_far = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: Array::make(4, b'\x00') |> Bytes::from_array,
  }
  let psnr_close = psnr(img1, img_close)
  let psnr_far = psnr(img1, img_far)
  assert_true(psnr_close > psnr_far)
  let _ = img1
  let _ = img_close
  let _ = img_far
  let _ = psnr_close
  let _ = psnr_far
}

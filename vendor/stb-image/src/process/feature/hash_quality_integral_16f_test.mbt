// 图像哈希 + 图像质量 + 积分图像 16-bit/float 变体测试

///|
fn make_img16_hq(w : Int, h : Int, ch : Int, val : Int) -> @types.Image16 {
  let data : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  for i in 0..<(w * h * ch) {
    data[i * 2] = (val & 0xFF).to_byte()
    data[i * 2 + 1] = ((val >> 8) & 0xFF).to_byte()
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
}

///|
fn make_imgf_hq(w : Int, h : Int, ch : Int, val : Float) -> @types.ImageF {
  let data : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  for i in 0..<(w * h * ch) {
    let bits = val.reinterpret_as_int()
    data[i * 4] = (bits & 0xFF).to_byte()
    data[i * 4 + 1] = ((bits >> 8) & 0xFF).to_byte()
    data[i * 4 + 2] = ((bits >> 16) & 0xFF).to_byte()
    data[i * 4 + 3] = ((bits >> 24) & 0xFF).to_byte()
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
}

// ========== 图像哈希 ==========

///|
test "ahash_16: basic" {
  let img = make_img16_hq(32, 32, 1, 30000)
  let result = ahash_16(img)
  assert_eq(result.length() > 0, true)
  let _ = img
  let _ = result
}

///|
test "ahash_f: basic" {
  let img = make_imgf_hq(32, 32, 1, 0.5F)
  let result = ahash_f(img)
  assert_eq(result.length() > 0, true)
  let _ = img
  let _ = result
}

///|
test "dhash_16: basic" {
  let img = make_img16_hq(32, 32, 1, 30000)
  let result = dhash_16(img)
  assert_eq(result.length() > 0, true)
  let _ = img
  let _ = result
}

///|
test "phash_16: basic" {
  let img = make_img16_hq(32, 32, 1, 30000)
  let result = phash_16(img)
  assert_eq(result.length() > 0, true)
  let _ = img
  let _ = result
}

// ========== 图像质量 ==========

///|
test "mse_16: basic" {
  let img1 = make_img16_hq(16, 16, 1, 30000)
  let img2 = make_img16_hq(16, 16, 1, 30000)
  let result = mse_16(img1, img2)
  assert_eq(result >= 0.0, true)
  let _ = img1
  let _ = img2
  let _ = result
}

///|
test "mse_f: basic" {
  let img1 = make_imgf_hq(16, 16, 1, 0.5F)
  let img2 = make_imgf_hq(16, 16, 1, 0.5F)
  let result = mse_f(img1, img2)
  assert_eq(result >= 0.0, true)
  let _ = img1
  let _ = img2
  let _ = result
}

///|
test "psnr_16: basic" {
  let img1 = make_img16_hq(16, 16, 1, 30000)
  let img2 = make_img16_hq(16, 16, 1, 30000)
  let result = psnr_16(img1, img2)
  assert_eq(result >= 0.0, true)
  let _ = img1
  let _ = img2
  let _ = result
}

///|
test "ssim_16: basic" {
  let img1 = make_img16_hq(16, 16, 1, 30000)
  let img2 = make_img16_hq(16, 16, 1, 30000)
  let result = ssim_16(img1, img2)
  assert_eq(result >= 0.0, true)
  let _ = img1
  let _ = img2
  let _ = result
}

// ========== 积分图像 ==========

///|
test "integral_image_16: basic" {
  let img = make_img16_hq(16, 16, 1, 30000)
  let result = integral_image_16(img)
  let sum = integral_sum(result, 0, 0, 8, 8)
  assert_eq(sum > 0, true)
  let _ = img
  let _ = result
  let _ = sum
}

///|
test "integral_image_f: basic" {
  let img = make_imgf_hq(16, 16, 1, 0.5F)
  let result = integral_image_f(img)
  let sum = integral_sum(result, 0, 0, 8, 8)
  assert_eq(sum > 0, true)
  let _ = img
  let _ = result
  let _ = sum
}

///|
test "integral_image_sq_16: basic" {
  let img = make_img16_hq(16, 16, 1, 30000)
  let result = integral_image_sq_16(img)
  let sum = integral_sum_sq(result, 0, 0, 8, 8)
  assert_eq(sum > 0, true)
  let _ = img
  let _ = result
  let _ = sum
}

///|
test "integral_image_sq_f: basic" {
  let img = make_imgf_hq(16, 16, 1, 0.5F)
  let result = integral_image_sq_f(img)
  let sum = integral_sum_sq(result, 0, 0, 8, 8)
  assert_eq(sum > 0, true)
  let _ = img
  let _ = result
  let _ = sum
}

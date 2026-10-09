// 卷积 + 双边滤波 16-bit/float 变体测试

///|
fn make_img16_cb(w : Int, h : Int, ch : Int, val : Int) -> @types.Image16 {
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
fn make_imgf_cb(w : Int, h : Int, ch : Int, val : Float) -> @types.ImageF {
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

// ========== 卷积 ==========

///|
test "convolve_16: basic" {
  let img = make_img16_cb(16, 16, 1, 30000)
  let kernel : Array[Float] = [
    0.0F,
    -1.0F,
    0.0F,
    -1.0F,
    5.0F,
    -1.0F,
    0.0F,
    -1.0F,
    0.0F,
  ]
  let result = convolve_16(img, kernel, 0.0F, 1.0F)
  assert_eq(result.width, 16)
  assert_eq(result.height, 16)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = kernel
  let _ = result
}

///|
test "convolve_f: basic" {
  let img = make_imgf_cb(16, 16, 1, 0.5F)
  let kernel : Array[Float] = [
    0.0F,
    -1.0F,
    0.0F,
    -1.0F,
    5.0F,
    -1.0F,
    0.0F,
    -1.0F,
    0.0F,
  ]
  let result = convolve_f(img, kernel, 0.0F, 1.0F)
  assert_eq(result.width, 16)
  assert_eq(result.height, 16)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = kernel
  let _ = result
}

///|
test "convolve_16: RGB input" {
  let img = make_img16_cb(16, 16, 3, 30000)
  let kernel : Array[Float] = [
    1.0F / 9.0F,
    1.0F / 9.0F,
    1.0F / 9.0F,
    1.0F / 9.0F,
    1.0F / 9.0F,
    1.0F / 9.0F,
    1.0F / 9.0F,
    1.0F / 9.0F,
    1.0F / 9.0F,
  ]
  let result = convolve_16(img, kernel, 0.0F, 1.0F)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = kernel
  let _ = result
}

// ========== 双边滤波 ==========

///|
test "bilateral_filter_16: basic" {
  let img = make_img16_cb(16, 16, 1, 30000)
  let result = bilateral_filter_16(img, 3, 10.0F, 20.0F)
  assert_eq(result.width, 16)
  assert_eq(result.height, 16)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "bilateral_filter_f: basic" {
  let img = make_imgf_cb(16, 16, 1, 0.5F)
  let result = bilateral_filter_f(img, 3, 10.0F, 20.0F)
  assert_eq(result.width, 16)
  assert_eq(result.height, 16)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "bilateral_filter_fast_16: basic" {
  let img = make_img16_cb(16, 16, 1, 30000)
  let result = bilateral_filter_fast_16(img, 3, 10.0F, 20.0F, 2)
  assert_eq(result.width, 16)
  assert_eq(result.height, 16)
  let _ = img
  let _ = result
}

///|
test "bilateral_filter_fast_f: basic" {
  let img = make_imgf_cb(16, 16, 1, 0.5F)
  let result = bilateral_filter_fast_f(img, 3, 10.0F, 20.0F, 2)
  assert_eq(result.width, 16)
  assert_eq(result.height, 16)
  let _ = img
  let _ = result
}

///|
test "bilateral_filter_16: RGB input" {
  let img = make_img16_cb(16, 16, 3, 30000)
  let result = bilateral_filter_16(img, 3, 10.0F, 20.0F)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

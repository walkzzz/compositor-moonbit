// 高级几何变换 16-bit/float 变体测试

///|
fn make_img16_geo(w : Int, h : Int, ch : Int, val : Int) -> @types.Image16 {
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
fn make_imgf_geo(w : Int, h : Int, ch : Int, val : Float) -> @types.ImageF {
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

// ========== warp_affine ==========

///|
test "warp_affine_16: identity transform" {
  let img = make_img16_geo(8, 8, 1, 30000)
  let matrix = (1.0F, 0.0F, 0.0F, 0.0F, 1.0F, 0.0F)
  let result = warp_affine_16(img, matrix, 8, 8)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = matrix
  let _ = result
}

///|
test "warp_affine_f: identity transform" {
  let img = make_imgf_geo(8, 8, 1, 0.5F)
  let matrix = (1.0F, 0.0F, 0.0F, 0.0F, 1.0F, 0.0F)
  let result = warp_affine_f(img, matrix, 8, 8)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = matrix
  let _ = result
}

///|
test "warp_affine_16: scale transform" {
  let img = make_img16_geo(8, 8, 3, 30000)
  let matrix = (0.5F, 0.0F, 0.0F, 0.0F, 0.5F, 0.0F)
  let result = warp_affine_16(img, matrix, 4, 4)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = matrix
  let _ = result
}

// ========== warp_perspective ==========

///|
test "warp_perspective_16: identity transform" {
  let img = make_img16_geo(8, 8, 1, 30000)
  let matrix = PerspectiveMatrix::{
    m00: 1.0F,
    m01: 0.0F,
    m02: 0.0F,
    m10: 0.0F,
    m11: 1.0F,
    m12: 0.0F,
    m20: 0.0F,
    m21: 0.0F,
    m22: 1.0F,
  }
  let result = warp_perspective_16(img, matrix, 8, 8)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = matrix
  let _ = result
}

///|
test "warp_perspective_f: identity transform" {
  let img = make_imgf_geo(8, 8, 1, 0.5F)
  let matrix = PerspectiveMatrix::{
    m00: 1.0F,
    m01: 0.0F,
    m02: 0.0F,
    m10: 0.0F,
    m11: 1.0F,
    m12: 0.0F,
    m20: 0.0F,
    m21: 0.0F,
    m22: 1.0F,
  }
  let result = warp_perspective_f(img, matrix, 8, 8)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = matrix
  let _ = result
}

// ========== resize ==========

///|
test "resize_16: scale up" {
  let img = make_img16_geo(4, 4, 1, 30000)
  let result = resize_16(img, 8, 8)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "resize_f: scale up" {
  let img = make_imgf_geo(4, 4, 1, 0.5F)
  let result = resize_f(img, 8, 8)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "resize_16: scale down" {
  let img = make_img16_geo(8, 8, 3, 30000)
  let result = resize_16(img, 4, 4)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "resize_f: RGB input" {
  let img = make_imgf_geo(8, 8, 3, 0.5F)
  let result = resize_f(img, 4, 4)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

// 金字塔操作 16-bit/float 测试

///|
fn make_img16_p(w : Int, h : Int, ch : Int, val : Int) -> @types.Image16 {
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
fn make_imgf_p(w : Int, h : Int, ch : Int, val : Float) -> @types.ImageF {
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

///|
test "pyr_down_16 basic" {
  let img = make_img16_p(4, 4, 3, 128)
  let out = @transform.pyr_down_16(img)
  assert_eq(out.width, 2)
  assert_eq(out.height, 2)
  assert_eq(out.channels, 3)
}

///|
test "pyr_down_f basic" {
  let img = make_imgf_p(4, 4, 3, 0.5F)
  let out = @transform.pyr_down_f(img)
  assert_eq(out.width, 2)
  assert_eq(out.height, 2)
  assert_eq(out.channels, 3)
}

///|
test "pyr_up_16 basic" {
  let img = make_img16_p(2, 2, 3, 128)
  let out = @transform.pyr_up_16(img)
  assert_eq(out.width, 4)
  assert_eq(out.height, 4)
  assert_eq(out.channels, 3)
}

///|
test "pyr_up_f basic" {
  let img = make_imgf_p(2, 2, 3, 0.5F)
  let out = @transform.pyr_up_f(img)
  assert_eq(out.width, 4)
  assert_eq(out.height, 4)
  assert_eq(out.channels, 3)
}

///|
test "pyr_down_16 rgba" {
  let img = make_img16_p(4, 4, 4, 128)
  let out = @transform.pyr_down_16(img)
  assert_eq(out.channels, 4)
}

///|
test "pyr_up_f grayscale" {
  let img = make_imgf_p(2, 2, 1, 0.5F)
  let out = @transform.pyr_up_f(img)
  assert_eq(out.channels, 1)
}

///|
test "build_gaussian_pyramid_16 basic" {
  let img = make_img16_p(8, 8, 3, 128)
  let pyr = @transform.build_gaussian_pyramid_16(img, 3)
  assert_eq(pyr.length(), 3)
  assert_eq(pyr[0].width, 8)
  assert_eq(pyr[1].width, 4)
  assert_eq(pyr[2].width, 2)
}

///|
test "build_gaussian_pyramid_f basic" {
  let img = make_imgf_p(8, 8, 3, 0.5F)
  let pyr = @transform.build_gaussian_pyramid_f(img, 3)
  assert_eq(pyr.length(), 3)
  assert_eq(pyr[0].width, 8)
  assert_eq(pyr[1].width, 4)
  assert_eq(pyr[2].width, 2)
}

///|
test "build_laplacian_pyramid_16 basic" {
  let img = make_img16_p(8, 8, 3, 128)
  let pyr = @transform.build_laplacian_pyramid_16(img, 3)
  assert_eq(pyr.length(), 3)
  assert_eq(pyr[0].width, 8)
  assert_eq(pyr[2].width, 2)
}

///|
test "build_laplacian_pyramid_f basic" {
  let img = make_imgf_p(8, 8, 3, 0.5F)
  let pyr = @transform.build_laplacian_pyramid_float(img, 3)
  assert_eq(pyr.length(), 3)
  assert_eq(pyr[0].width, 8)
  assert_eq(pyr[2].width, 2)
}

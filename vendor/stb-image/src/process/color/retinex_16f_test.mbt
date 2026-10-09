// 多尺度 Retinex 16-bit/float 变体测试

///|
fn make_img16_r(w : Int, h : Int, ch : Int, val : Int) -> @types.Image16 {
  let n = w * h * ch
  let data : Array[Byte] = Array::make(n * 2, b'\x00')
  for i in 0..<n {
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
fn make_imgf_r(w : Int, h : Int, ch : Int, val : Float) -> @types.ImageF {
  let n = w * h * ch
  let data : Array[Byte] = Array::make(n * 4, b'\x00')
  for i in 0..<n {
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
test "ssr_16 basic" {
  let img = make_img16_r(4, 4, 3, 128)
  let out = @color.ssr_16(img, sigma=10.0F)
  assert_eq(out.width, 4)
  assert_eq(out.height, 4)
  assert_eq(out.channels, 3)
}

///|
test "ssr_f basic" {
  let img = make_imgf_r(4, 4, 3, 0.5F)
  let out = @color.ssr_f(img, sigma=10.0F)
  assert_eq(out.width, 4)
  assert_eq(out.height, 4)
  assert_eq(out.channels, 3)
}

///|
test "msr_16 basic" {
  let img = make_img16_r(4, 4, 3, 128)
  let out = @color.msr_16(img, sigmas=[5.0F, 10.0F])
  assert_eq(out.width, 4)
  assert_eq(out.height, 4)
  assert_eq(out.channels, 3)
}

///|
test "msr_f basic" {
  let img = make_imgf_r(4, 4, 3, 0.5F)
  let out = @color.msr_f(img, sigmas=[5.0F, 10.0F])
  assert_eq(out.width, 4)
  assert_eq(out.height, 4)
  assert_eq(out.channels, 3)
}

///|
test "msrcr_16 basic" {
  let img = make_img16_r(4, 4, 3, 128)
  let out = @color.msrcr_16(img, sigmas=[5.0F, 10.0F])
  assert_eq(out.width, 4)
  assert_eq(out.height, 4)
  assert_eq(out.channels, 3)
}

///|
test "msrcr_f basic" {
  let img = make_imgf_r(4, 4, 3, 0.5F)
  let out = @color.msrcr_f(img, sigmas=[5.0F, 10.0F])
  assert_eq(out.width, 4)
  assert_eq(out.height, 4)
  assert_eq(out.channels, 3)
}

///|
test "ssr_16 grayscale" {
  let img = make_img16_r(4, 4, 1, 128)
  let out = @color.ssr_16(img, sigma=10.0F)
  assert_eq(out.channels, 1)
}

///|
test "ssr_f rgba" {
  let img = make_imgf_r(4, 4, 4, 0.5F)
  let out = @color.ssr_f(img, sigma=10.0F)
  assert_eq(out.channels, 4)
}

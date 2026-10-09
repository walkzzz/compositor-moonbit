// multi_band_blend 16-bit/float 测试

///|
fn make_img16_mbb(w : Int, h : Int, ch : Int, val : Int) -> @types.Image16 {
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
fn make_imgf_mbb(w : Int, h : Int, ch : Int, val : Float) -> @types.ImageF {
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
test "multi_band_blend_16 basic" {
  let img_a = make_img16_mbb(8, 8, 3, 100)
  let img_b = make_img16_mbb(8, 8, 3, 200)
  let mask = make_img16_mbb(8, 8, 1, 32768)
  let out = @transform.multi_band_blend_16(img_a, img_b, mask, num_bands=3)
  assert_eq(out.width, 8)
  assert_eq(out.height, 8)
  assert_eq(out.channels, 3)
}

///|
test "multi_band_blend_f basic" {
  let img_a = make_imgf_mbb(8, 8, 3, 0.2F)
  let img_b = make_imgf_mbb(8, 8, 3, 0.8F)
  let mask = make_imgf_mbb(8, 8, 1, 0.5F)
  let out = @transform.multi_band_blend_f(img_a, img_b, mask, num_bands=3)
  assert_eq(out.width, 8)
  assert_eq(out.height, 8)
  assert_eq(out.channels, 3)
}

///|
test "multi_band_blend_16 rgba" {
  let img_a = make_img16_mbb(8, 8, 4, 100)
  let img_b = make_img16_mbb(8, 8, 4, 200)
  let mask = make_img16_mbb(8, 8, 1, 32768)
  let out = @transform.multi_band_blend_16(img_a, img_b, mask, num_bands=3)
  assert_eq(out.channels, 4)
}

///|
test "multi_band_blend_f default_bands" {
  let img_a = make_imgf_mbb(8, 8, 3, 0.2F)
  let img_b = make_imgf_mbb(8, 8, 3, 0.8F)
  let mask = make_imgf_mbb(8, 8, 1, 0.5F)
  let out = @transform.multi_band_blend_f(img_a, img_b, mask)
  assert_eq(out.width, 8)
}

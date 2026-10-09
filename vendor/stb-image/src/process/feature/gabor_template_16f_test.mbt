// Gabor 滤波 + 模板匹配 16-bit/float 变体测试

///|
fn make_img16_gt(w : Int, h : Int, ch : Int, val : Int) -> @types.Image16 {
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
fn make_imgf_gt(w : Int, h : Int, ch : Int, val : Float) -> @types.ImageF {
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

// ========== Gabor ==========

///|
test "gabor_filter_16: basic" {
  let img = make_img16_gt(32, 32, 1, 30000)
  let result = gabor_filter_16(img, 15, 3.0, 0.0F)
  assert_eq(result.width, 32)
  assert_eq(result.height, 32)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "gabor_filter_f: basic" {
  let img = make_imgf_gt(32, 32, 1, 0.5F)
  let result = gabor_filter_f(img, 15, 3.0, 0.0F)
  assert_eq(result.width, 32)
  assert_eq(result.height, 32)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "gabor_filter_bank_16: basic" {
  let img = make_img16_gt(32, 32, 1, 30000)
  let result = gabor_filter_bank_16(img, 15, 3.0)
  assert_eq(result.width, 32)
  assert_eq(result.height, 32)
  let _ = img
  let _ = result
}

///|
test "gabor_filter_bank_f: basic" {
  let img = make_imgf_gt(32, 32, 1, 0.5F)
  let result = gabor_filter_bank_f(img, 15, 3.0)
  assert_eq(result.width, 32)
  assert_eq(result.height, 32)
  let _ = img
  let _ = result
}

// ========== Template Match ==========

///|
test "template_match_16: basic" {
  let img = make_img16_gt(32, 32, 1, 30000)
  let tpl = make_img16_gt(8, 8, 1, 30000)
  let result = template_match_16(img, tpl)
  assert_eq(result.length() > 0, true)
  let _ = img
  let _ = tpl
  let _ = result
}

///|
test "template_match_f: basic" {
  let img = make_imgf_gt(32, 32, 1, 0.5F)
  let tpl = make_imgf_gt(8, 8, 1, 0.5F)
  let result = template_match_f(img, tpl)
  assert_eq(result.length() > 0, true)
  let _ = img
  let _ = tpl
  let _ = result
}

///|
test "template_match_best_16: basic" {
  let img = make_img16_gt(32, 32, 1, 30000)
  let tpl = make_img16_gt(8, 8, 1, 30000)
  let result = template_match_best_16(img, tpl)
  assert_eq(result is Some(_), true)
  let _ = img
  let _ = tpl
  let _ = result
}

///|
test "template_match_best_f: basic" {
  let img = make_imgf_gt(32, 32, 1, 0.5F)
  let tpl = make_imgf_gt(8, 8, 1, 0.5F)
  let result = template_match_best_f(img, tpl)
  assert_eq(result is Some(_), true)
  let _ = img
  let _ = tpl
  let _ = result
}

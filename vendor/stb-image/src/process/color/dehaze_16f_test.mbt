// 去雾 16-bit/float 变体测试（color 包）

///|
fn make_img16_dh(w : Int, h : Int, ch : Int, val : Int) -> @types.Image16 {
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
fn make_imgf_dh(w : Int, h : Int, ch : Int, val : Float) -> @types.ImageF {
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

// ========== Dehaze ==========

///|
test "dehaze_16: basic dehaze" {
  let img = make_img16_dh(8, 8, 3, 30000)
  let result = dehaze_16(img)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "dehaze_f: basic dehaze" {
  let img = make_imgf_dh(8, 8, 3, 0.5F)
  let result = dehaze_f(img)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "dehaze_16: RGBA input" {
  let img = make_img16_dh(8, 8, 4, 30000)
  let result = dehaze_16(img)
  assert_eq(result.channels, 4)
  let _ = img
  let _ = result
}

///|
test "dehaze_16: rejects grayscale" {
  let img = make_img16_dh(8, 8, 1, 30000)
  try {
    let _ = dehaze_16(img)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

// ========== Guided Filter ==========

///|
test "guided_filter_16: basic filter" {
  let img = make_img16_dh(8, 8, 1, 30000)
  let input : Array[Float] = Array::make(64, 0.5F)
  let result = guided_filter_16(img, input)
  assert_eq(result.length(), 64)
  let _ = img
  let _ = input
  let _ = result
}

///|
test "guided_filter_f: basic filter" {
  let img = make_imgf_dh(8, 8, 1, 0.5F)
  let input : Array[Float] = Array::make(64, 0.5F)
  let result = guided_filter_f(img, input)
  assert_eq(result.length(), 64)
  let _ = img
  let _ = input
  let _ = result
}

///|
test "guided_filter_16: RGB input" {
  let img = make_img16_dh(8, 8, 3, 30000)
  let input : Array[Float] = Array::make(64, 0.5F)
  let result = guided_filter_16(img, input)
  assert_eq(result.length(), 64)
  let _ = img
  let _ = input
  let _ = result
}

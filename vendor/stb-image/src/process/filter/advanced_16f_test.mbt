// 高级算法 16-bit/float 变体测试（filter 包：inpaint + NLM）

///|
fn make_img16_adv(w : Int, h : Int, ch : Int, val : Int) -> @types.Image16 {
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
fn make_imgf_adv(w : Int, h : Int, ch : Int, val : Float) -> @types.ImageF {
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

// ========== Inpaint ==========

///|
test "inpaint_16: basic inpaint" {
  let img = make_img16_adv(8, 8, 3, 30000)
  let mask = make_img16_adv(8, 8, 1, 0)
  let result = inpaint_16(img, mask, iterations=10)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = mask
  let _ = result
}

///|
test "inpaint_f: basic inpaint" {
  let img = make_imgf_adv(8, 8, 3, 0.5F)
  let mask = make_imgf_adv(8, 8, 1, 0.0F)
  let result = inpaint_f(img, mask, iterations=10)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = mask
  let _ = result
}

///|
test "inpaint_fast_16: basic inpaint" {
  let img = make_img16_adv(8, 8, 3, 30000)
  let mask = make_img16_adv(8, 8, 1, 0)
  let result = inpaint_fast_16(img, mask, radius=3)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = mask
  let _ = result
}

///|
test "inpaint_fast_f: basic inpaint" {
  let img = make_imgf_adv(8, 8, 3, 0.5F)
  let mask = make_imgf_adv(8, 8, 1, 0.0F)
  let result = inpaint_fast_f(img, mask, radius=3)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = mask
  let _ = result
}

///|
test "inpaint_16: rejects size mismatch" {
  let img = make_img16_adv(8, 8, 3, 30000)
  let mask = make_img16_adv(4, 4, 1, 0)
  try {
    let _ = inpaint_16(img, mask)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
  let _ = mask
}

// ========== NLM ==========

///|
test "nlm_denoise_16: basic denoise" {
  let img = make_img16_adv(8, 8, 1, 30000)
  let result = nlm_denoise_16(img, patch_size=3, search_size=5, h=10)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "nlm_denoise_f: basic denoise" {
  let img = make_imgf_adv(8, 8, 1, 0.5F)
  let result = nlm_denoise_f(img, patch_size=3, search_size=5, h=10)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "nlm_denoise_fast_16: basic denoise" {
  let img = make_img16_adv(8, 8, 1, 30000)
  let result = nlm_denoise_fast_16(
    img,
    patch_size=3,
    search_size=5,
    h=10,
    step=2,
  )
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "nlm_denoise_fast_f: basic denoise" {
  let img = make_imgf_adv(8, 8, 1, 0.5F)
  let result = nlm_denoise_fast_f(
    img,
    patch_size=3,
    search_size=5,
    h=10,
    step=2,
  )
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "nlm_denoise_16: RGB input" {
  let img = make_img16_adv(8, 8, 3, 30000)
  let result = nlm_denoise_16(img)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

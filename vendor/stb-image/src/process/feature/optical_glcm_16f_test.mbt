// 光流 + GLCM 16-bit/float 变体测试

///|
fn make_img16_og(w : Int, h : Int, ch : Int, val : Int) -> @types.Image16 {
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
fn make_imgf_og(w : Int, h : Int, ch : Int, val : Float) -> @types.ImageF {
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

// ========== Lucas-Kanade ==========

///|
test "lucas_kanade_16: basic" {
  let prev = make_img16_og(32, 32, 1, 30000)
  let next = make_img16_og(32, 32, 1, 30000)
  let points : Array[(Int, Int)] = [(10, 10), (20, 20)]
  let result = lucas_kanade_16(prev, next, points)
  assert_eq(result.length(), 2)
  let _ = prev
  let _ = next
  let _ = points
  let _ = result
}

///|
test "lucas_kanade_f: basic" {
  let prev = make_imgf_og(32, 32, 1, 0.5F)
  let next = make_imgf_og(32, 32, 1, 0.5F)
  let points : Array[(Int, Int)] = [(10, 10), (20, 20)]
  let result = lucas_kanade_f(prev, next, points)
  assert_eq(result.length(), 2)
  let _ = prev
  let _ = next
  let _ = points
  let _ = result
}

// ========== Horn-Schunck ==========

///|
test "horn_schunck_16: basic" {
  let prev = make_img16_og(16, 16, 1, 30000)
  let next = make_img16_og(16, 16, 1, 30000)
  let (u, v) = horn_schunck_16(prev, next, iterations=10)
  assert_eq(u.length(), 16 * 16)
  assert_eq(v.length(), 16 * 16)
  let _ = prev
  let _ = next
  let _ = u
  let _ = v
}

///|
test "horn_schunck_f: basic" {
  let prev = make_imgf_og(16, 16, 1, 0.5F)
  let next = make_imgf_og(16, 16, 1, 0.5F)
  let (u, v) = horn_schunck_f(prev, next, iterations=10)
  assert_eq(u.length(), 16 * 16)
  assert_eq(v.length(), 16 * 16)
  let _ = prev
  let _ = next
  let _ = u
  let _ = v
}

// ========== GLCM ==========

///|
test "compute_glcm_16: basic" {
  let img = make_img16_og(16, 16, 1, 30000)
  let result = compute_glcm_16(img, 1, 0)
  assert_eq(result.length(), 256)
  let _ = img
  let _ = result
}

///|
test "compute_glcm_f: basic" {
  let img = make_imgf_og(16, 16, 1, 0.5F)
  let result = compute_glcm_f(img, 1, 0)
  assert_eq(result.length(), 256)
  let _ = img
  let _ = result
}

///|
test "glcm_features_multi_direction_16: basic" {
  let img = make_img16_og(16, 16, 1, 30000)
  let result = glcm_features_multi_direction_16(img)
  assert_eq(result.length(), 4)
  let _ = img
  let _ = result
}

///|
test "glcm_features_multi_direction_f: basic" {
  let img = make_imgf_og(16, 16, 1, 0.5F)
  let result = glcm_features_multi_direction_f(img)
  assert_eq(result.length(), 4)
  let _ = img
  let _ = result
}

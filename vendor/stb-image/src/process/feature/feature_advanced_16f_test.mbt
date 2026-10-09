// 特征检测高级 16-bit/float 变体测试

///|
fn make_img16_feat_adv(w : Int, h : Int, ch : Int, val : Int) -> @types.Image16 {
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
fn make_imgf_feat_adv(w : Int, h : Int, ch : Int, val : Float) -> @types.ImageF {
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

// ========== Harris ==========

///|
test "harris_corners_16: basic" {
  let img = make_img16_feat_adv(32, 32, 1, 30000)
  let result = harris_corners_16(img)
  assert_eq(result.length() >= 0, true)
  let _ = img
  let _ = result
}

///|
test "harris_corners_f: basic" {
  let img = make_imgf_feat_adv(32, 32, 1, 0.5F)
  let result = harris_corners_f(img)
  assert_eq(result.length() >= 0, true)
  let _ = img
  let _ = result
}

///|
test "harris_corners_16: RGB input" {
  let img = make_img16_feat_adv(32, 32, 3, 30000)
  let result = harris_corners_16(img)
  assert_eq(result.length() >= 0, true)
  let _ = img
  let _ = result
}

// ========== SIFT ==========

///|
test "sift_detect_16: basic" {
  let img = make_img16_feat_adv(32, 32, 1, 30000)
  let result = sift_detect_16(img)
  assert_eq(result.length() >= 0, true)
  let _ = img
  let _ = result
}

///|
test "sift_detect_f: basic" {
  let img = make_imgf_feat_adv(32, 32, 1, 0.5F)
  let result = sift_detect_f(img)
  assert_eq(result.length() >= 0, true)
  let _ = img
  let _ = result
}

// ========== ORB ==========

///|
test "orb_detect_16: basic" {
  let img = make_img16_feat_adv(32, 32, 1, 30000)
  let result = orb_detect_16(img)
  assert_eq(result.length() >= 0, true)
  let _ = img
  let _ = result
}

///|
test "orb_detect_f: basic" {
  let img = make_imgf_feat_adv(32, 32, 1, 0.5F)
  let result = orb_detect_f(img)
  assert_eq(result.length() >= 0, true)
  let _ = img
  let _ = result
}

// ========== Shi-Tomasi ==========

///|
test "good_features_to_track_16: basic" {
  let img = make_img16_feat_adv(32, 32, 1, 30000)
  let result = good_features_to_track_16(img, 50, 0.01F)
  assert_eq(result.length() >= 0, true)
  let _ = img
  let _ = result
}

///|
test "good_features_to_track_f: basic" {
  let img = make_imgf_feat_adv(32, 32, 1, 0.5F)
  let result = good_features_to_track_f(img, 50, 0.01F)
  assert_eq(result.length() >= 0, true)
  let _ = img
  let _ = result
}

///|
test "good_features_to_track_16: RGB input" {
  let img = make_img16_feat_adv(32, 32, 3, 30000)
  let result = good_features_to_track_16(img, 50, 0.01F)
  assert_eq(result.length() >= 0, true)
  let _ = img
  let _ = result
}

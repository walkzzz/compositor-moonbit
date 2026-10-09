// 图像分割 16-bit/float 变体测试

///|
fn make_img16_seg(w : Int, h : Int, ch : Int, val : Int) -> @types.Image16 {
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
fn make_imgf_seg(w : Int, h : Int, ch : Int, val : Float) -> @types.ImageF {
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

// ========== Watershed ==========

///|
test "watershed_16: basic segmentation" {
  let img = make_img16_seg(8, 8, 1, 30000)
  let markers : Array[Int] = Array::make(64, 0)
  markers[0] = 1
  markers[63] = 2
  let result = watershed_16(img, markers)
  assert_eq(result.length(), 64)
  let _ = img
  let _ = markers
  let _ = result
}

///|
test "watershed_f: basic segmentation" {
  let img = make_imgf_seg(8, 8, 1, 0.5F)
  let markers : Array[Int] = Array::make(64, 0)
  markers[0] = 1
  markers[63] = 2
  let result = watershed_f(img, markers)
  assert_eq(result.length(), 64)
  let _ = img
  let _ = markers
  let _ = result
}

///|
test "watershed_auto_16: auto segmentation" {
  let img = make_img16_seg(8, 8, 1, 30000)
  let (labels, num) = watershed_auto_16(img)
  assert_eq(labels.length(), 64)
  assert_true(num >= 0)
  let _ = img
  let _ = labels
  let _ = num
}

///|
test "watershed_auto_f: auto segmentation" {
  let img = make_imgf_seg(8, 8, 1, 0.5F)
  let (labels, num) = watershed_auto_f(img)
  assert_eq(labels.length(), 64)
  assert_true(num >= 0)
  let _ = img
  let _ = labels
  let _ = num
}

// ========== K-means ==========

///|
test "kmeans_segment_16: basic segmentation" {
  let img = make_img16_seg(8, 8, 3, 30000)
  let (labels, regions) = kmeans_segment_16(img, 3)
  assert_eq(regions.length(), 3)
  let _ = img
  let _ = labels
  let _ = regions
}

///|
test "kmeans_segment_f: basic segmentation" {
  let img = make_imgf_seg(8, 8, 3, 0.5F)
  let (labels, regions) = kmeans_segment_f(img, 3)
  assert_eq(regions.length(), 3)
  let _ = img
  let _ = labels
  let _ = regions
}

///|
test "kmeans_segment_16: rejects invalid k" {
  let img = make_img16_seg(4, 4, 3, 30000)
  try {
    let _ = kmeans_segment_16(img, 0)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

// ========== SLIC ==========

///|
test "slic_16: basic superpixel" {
  let img = make_img16_seg(16, 16, 3, 30000)
  let result = slic_16(img, 4, 10, 10)
  assert_true(result.labels.length() == 256)
  let _ = img
  let _ = result
}

///|
test "slic_f: basic superpixel" {
  let img = make_imgf_seg(16, 16, 3, 0.5F)
  let result = slic_f(img, 4, 10, 10)
  assert_true(result.labels.length() == 256)
  let _ = img
  let _ = result
}

///|
test "slic_16: RGBA input" {
  let img = make_img16_seg(16, 16, 4, 30000)
  let result = slic_16(img, 4, 10, 10)
  assert_true(result.labels.length() == 256)
  let _ = img
  let _ = result
}

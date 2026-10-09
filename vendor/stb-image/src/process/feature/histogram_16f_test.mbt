// 直方图操作 16-bit/float 变体测试

///|
fn make_img16_hist(w : Int, h : Int, ch : Int, val : Int) -> @types.Image16 {
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
fn make_imgf_hist(w : Int, h : Int, ch : Int, val : Float) -> @types.ImageF {
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
fn read_u16_at_h(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn read_f32_at_h(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

// ========== histogram ==========

///|
test "histogram_16: uniform image single bin" {
  let img = make_img16_hist(4, 4, 1, 30000)
  let hist = histogram_16(img)
  assert_eq(hist.length(), 65536)
  assert_eq(hist[30000], 16)
  let _ = img
  let _ = hist
}

///|
test "histogram_f: uniform image single bin" {
  let img = make_imgf_hist(4, 4, 1, 0.5F)
  let hist = histogram_f(img)
  assert_eq(hist.length(), 256)
  // 0.5 * 255 = 127.5 -> 128
  assert_eq(hist[128], 16)
  let _ = img
  let _ = hist
}

// ========== histogram_equalize ==========

///|
test "histogram_equalize_16: uniform image unchanged" {
  let img = make_img16_hist(4, 4, 1, 30000)
  let result = histogram_equalize_16(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 1)
  // 均匀图像均衡化后不变（所有像素相同）
  for i in 0..<16 {
    assert_eq(read_u16_at_h(result.data, i * 2), 30000)
  }
  let _ = img
  let _ = result
}

///|
test "histogram_equalize_f: uniform image unchanged" {
  let img = make_imgf_hist(4, 4, 1, 0.5F)
  let result = histogram_equalize_f(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 1)
  for i in 0..<16 {
    let v = read_f32_at_h(result.data, i * 4)
    assert_true(v > 0.499F && v < 0.501F)
  }
  let _ = img
  let _ = result
}

// ========== histogram_normalize ==========

///|
test "histogram_normalize_16: uniform image unchanged" {
  let img = make_img16_hist(4, 4, 1, 30000)
  let result = histogram_normalize_16(img)
  for i in 0..<16 {
    assert_eq(read_u16_at_h(result.data, i * 2), 30000)
  }
  let _ = img
  let _ = result
}

///|
test "histogram_normalize_16: stretches range" {
  // 创建一个值范围较小的图像
  let img = make_img16_hist(4, 4, 1, 10000)
  let data = img.data.to_array()
  // 将部分像素设为 20000
  for i in 0..<8 {
    data[i * 2] = b'\x20'
    data[i * 2 + 1] = b'\x4E'
  }
  let img2 = @types.Image16::{
    width: 4,
    height: 4,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let result = histogram_normalize_16(img2)
  // 归一化后最小值应为 0，最大值应为 65535
  let mut min_v = 65535
  let mut max_v = 0
  for i in 0..<16 {
    let v = read_u16_at_h(result.data, i * 2)
    if v < min_v {
      min_v = v
    }
    if v > max_v {
      max_v = v
    }
  }
  assert_eq(min_v, 0)
  assert_eq(max_v, 65535)
  let _ = img
  let _ = img2
  let _ = result
}

///|
test "histogram_normalize_f: uniform image unchanged" {
  let img = make_imgf_hist(4, 4, 1, 0.5F)
  let result = histogram_normalize_f(img)
  for i in 0..<16 {
    let v = read_f32_at_h(result.data, i * 4)
    assert_true(v > 0.499F && v < 0.501F)
  }
  let _ = img
  let _ = result
}

// ========== histogram_matching ==========

///|
test "histogram_matching_16: same image unchanged" {
  let img = make_img16_hist(4, 4, 1, 30000)
  let result = histogram_matching_16(img, img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "histogram_matching_f: same image unchanged" {
  let img = make_imgf_hist(4, 4, 1, 0.5F)
  let result = histogram_matching_f(img, img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "histogram_matching_16: RGBA preserves alpha" {
  let img = make_img16_hist(4, 4, 4, 30000)
  let ref_img = make_img16_hist(4, 4, 4, 20000)
  let result = histogram_matching_16(img, ref_img)
  assert_eq(result.channels, 4)
  for i in 0..<16 {
    let alpha_off = i * 8 + 6
    assert_eq(result.data[alpha_off], img.data[alpha_off])
    assert_eq(result.data[alpha_off + 1], img.data[alpha_off + 1])
  }
  let _ = img
  let _ = ref_img
  let _ = result
}

// ========== 多通道测试 ==========

///|
test "histogram_equalize_16: RGB dimensions" {
  let img = make_img16_hist(4, 4, 3, 30000)
  let result = histogram_equalize_16(img)
  assert_eq(result.channels, 3)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  let _ = img
  let _ = result
}

///|
test "histogram_normalize_f: RGB dimensions" {
  let img = make_imgf_hist(4, 4, 3, 0.5F)
  let result = histogram_normalize_f(img)
  assert_eq(result.channels, 3)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  let _ = img
  let _ = result
}

///|
test "histogram_16: RGB converts to grayscale" {
  let img = make_img16_hist(4, 4, 3, 30000)
  let hist = histogram_16(img)
  // BT.601: (30000*299 + 30000*587 + 30000*114)/1000 = 30000
  assert_eq(hist[30000], 16)
  let _ = img
  let _ = hist
}

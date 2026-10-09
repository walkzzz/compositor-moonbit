// image_stats 16-bit/float 变体测试

///|
fn make_uniform_image16_s(
  w : Int,
  h : Int,
  ch : Int,
  val : Int,
) -> @types.Image16 {
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
fn make_uniform_imagef_s(
  w : Int,
  h : Int,
  ch : Int,
  val : Float,
) -> @types.ImageF {
  let data : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  let bits = val.reinterpret_as_int()
  for i in 0..<(w * h * ch) {
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
fn make_image16_varied() -> @types.Image16 {
  // 4 像素，1 通道，值 0, 100, 1000, 5000
  let data : Array[Byte] = Array::make(8, b'\x00')
  let vals = [0, 100, 1000, 5000]
  for i in 0..<4 {
    data[i * 2] = (vals[i] & 0xFF).to_byte()
    data[i * 2 + 1] = ((vals[i] >> 8) & 0xFF).to_byte()
  }
  @types.Image16::{
    width: 4,
    height: 1,
    channels: 1,
    data: Bytes::from_array(data),
  }
}

///|
fn make_imagef_varied() -> @types.ImageF {
  // 4 像素，1 通道，值 0.0, 0.25, 0.5, 1.0
  let data : Array[Byte] = Array::make(16, b'\x00')
  let vals = [0.0F, 0.25F, 0.5F, 1.0F]
  for i in 0..<4 {
    let bits = vals[i].reinterpret_as_int()
    data[i * 4] = (bits & 0xFF).to_byte()
    data[i * 4 + 1] = ((bits >> 8) & 0xFF).to_byte()
    data[i * 4 + 2] = ((bits >> 16) & 0xFF).to_byte()
    data[i * 4 + 3] = ((bits >> 24) & 0xFF).to_byte()
  }
  @types.ImageF::{
    width: 4,
    height: 1,
    channels: 1,
    data: Bytes::from_array(data),
  }
}

///|
test "compute_stats_16: uniform image" {
  let img = make_uniform_image16_s(2, 2, 1, 1000)
  let stats = compute_stats_16(img)
  assert_true(stats.mean > 999.0F && stats.mean < 1001.0F)
  assert_true(stats.stddev < 1.0F)
  assert_eq(stats.min_val, 1000)
  assert_eq(stats.max_val, 1000)
  let _ = img
  let _ = stats
}

///|
test "compute_stats_16: varied image" {
  let img = make_image16_varied()
  let stats = compute_stats_16(img)
  assert_eq(stats.min_val, 0)
  assert_eq(stats.max_val, 5000)
  assert_true(stats.mean > 1000.0F && stats.mean < 2000.0F)
  let _ = img
  let _ = stats
}

///|
test "compute_stats_f: uniform image" {
  let img = make_uniform_imagef_s(2, 2, 1, 0.5F)
  let stats = compute_stats_f(img)
  assert_true(stats.mean > 0.49F && stats.mean < 0.51F)
  assert_true(stats.stddev < 0.01F)
  assert_true(stats.min_val > 0.49F && stats.min_val < 0.51F)
  assert_true(stats.max_val > 0.49F && stats.max_val < 0.51F)
  let _ = img
  let _ = stats
}

///|
test "compute_stats_f: varied image" {
  let img = make_imagef_varied()
  let stats = compute_stats_f(img)
  assert_true(stats.min_val < 0.01F)
  assert_true(stats.max_val > 0.99F)
  assert_true(stats.mean > 0.3F && stats.mean < 0.6F)
  let _ = img
  let _ = stats
}

///|
test "mean_value_16: uniform" {
  let img = make_uniform_image16_s(2, 2, 1, 3000)
  let m = mean_value_16(img)
  assert_true(m > 2999.0F && m < 3001.0F)
  let _ = img
  let _ = m
}

///|
test "mean_value_f: uniform" {
  let img = make_uniform_imagef_s(2, 2, 1, 0.7F)
  let m = mean_value_f(img)
  assert_true(m > 0.69F && m < 0.71F)
  let _ = img
  let _ = m
}

///|
test "compute_stats_f: uniform imagef" {
  let img = make_uniform_imagef_s(2, 2, 1, 0.5F)
  let stats = compute_stats_f(img)
  assert_true(stats.mean > 0.49F && stats.mean < 0.51F)
  assert_true(stats.stddev < 0.01F)
  assert_true(stats.min_val > 0.49F && stats.min_val < 0.51F)
  assert_true(stats.max_val > 0.49F && stats.max_val < 0.51F)
  let _ = img
  let _ = stats
}

// image_stats 测试

///|
test "compute_stats: uniform image" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: Array::make(4, b'\x80') |> Bytes::from_array,
  }
  let stats = compute_stats(img)
  assert_true(stats.mean >= 127.5F && stats.mean <= 128.5F)
  assert_true(stats.stddev < 1.0F)
  assert_eq(stats.min_val, 128)
  assert_eq(stats.max_val, 128)
  let _ = img
  let _ = stats
}

///|
test "compute_stats: varied image" {
  let img = @types.Image::{
    width: 4,
    height: 1,
    channels: 1,
    data: [b'\x00', b'\x40', b'\x80', b'\xFF'] |> Bytes::from_array,
  }
  let stats = compute_stats(img)
  assert_eq(stats.min_val, 0)
  assert_eq(stats.max_val, 255)
  assert_true(stats.mean > 50.0F && stats.mean < 150.0F)
  assert_true(stats.stddev > 50.0F)
  let _ = img
  let _ = stats
}

///|
test "mean_value: uniform" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: Array::make(4, b'\x80') |> Bytes::from_array,
  }
  let m = mean_value(img)
  assert_true(m >= 127.5F && m <= 128.5F)
  let _ = img
  let _ = m
}

// 色彩量化测试：floyd_steinberg / median_cut / kmeans_quantize

///|
test "floyd_steinberg: levels=2 produces binary image" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let result = floyd_steinberg(img, 2)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  // levels=2 → 每通道只有 0 或 255
  for i in 0..<result.data.length() {
    let v = result.data[i].to_int()
    assert_true(v == 0 || v == 255)
  }
  let _ = img
  let _ = result
}

///|
test "floyd_steinberg: levels=1 raises error" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  try {
    let _ = floyd_steinberg(img, 1)
    assert_true(false) // 应该抛出错误
  } catch {
    _ => assert_true(true) // 预期的错误
  }
  let _ = img
}

///|
test "floyd_steinberg: preserves alpha" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(4))
  let result = floyd_steinberg(img, 4)
  assert_eq(result.data[3].to_int(), img.data[3].to_int())
  let _ = img
  let _ = result
}

///|
test "floyd_steinberg: uniform image produces valid levels" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 3,
    data: Array::make(48, b'\x80') |> Bytes::from_array,
  }
  let result = floyd_steinberg(img, 4)
  // levels=4, step=85 → 值应为 0/85/170/255 之一
  for i in 0..<48 {
    let v = result.data[i].to_int()
    assert_true(v == 0 || v == 85 || v == 170 || v == 255)
  }
  let _ = img
  let _ = result
}

///|
test "median_cut: produces RGB output" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let result = median_cut(img, 8)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "median_cut: num_colors=2 reduces colors" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let result = median_cut(img, 2)
  // 最多 2 种不同颜色
  let colors : Array[(Int, Int, Int)] = []
  for i in 0..<(result.width * result.height) {
    let r = result.data[i * 3].to_int()
    let g = result.data[i * 3 + 1].to_int()
    let b = result.data[i * 3 + 2].to_int()
    let mut found = false
    for j in 0..<colors.length() {
      if colors[j] == (r, g, b) {
        found = true
        break
      }
    }
    if !found {
      colors.push((r, g, b))
    }
  }
  assert_true(colors.length() <= 2)
  let _ = img
  let _ = result
}

///|
test "median_cut: handles grayscale input" {
  let img = @types.Image::{
    width: 4,
    height: 1,
    channels: 1,
    data: [b'\x00', b'\x40', b'\x80', b'\xFF'] |> Bytes::from_array,
  }
  let result = median_cut(img, 4)
  assert_eq(result.channels, 3)
  assert_eq(result.width, 4)
  let _ = img
  let _ = result
}

///|
test "kmeans_quantize: k=1 gives single color" {
  let data : Array[Byte] = [
    b'\xFF', b'\x00', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\x00', b'\xFF',
    b'\xFF', b'\xFF', b'\x00',
  ]
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let result = kmeans_quantize(img, 1, 20)
  // k=1 时所有像素应该是同一个颜色（平均值）
  let r0 = result.data[0]
  let g0 = result.data[1]
  let b0 = result.data[2]
  for i in 0..<4 {
    assert_eq(result.data[i * 3], r0)
    assert_eq(result.data[i * 3 + 1], g0)
    assert_eq(result.data[i * 3 + 2], b0)
  }
  let _ = img
  let _ = result
}

///|
test "kmeans_quantize: preserves channels" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 3,
    data: Array::make(48, b'\x80') |> Bytes::from_array,
  }
  let result = kmeans_quantize(img, 4, 10)
  assert_eq(result.channels, 3)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  let _ = img
  let _ = result
}

///|
test "kmeans_quantize: RGBA preserves alpha" {
  let data : Array[Byte] = Array::make(4 * 4, b'\x80')
  for i in 0..<4 {
    data[i * 4 + 3] = b'\xFF'
  }
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 4,
    data: Bytes::from_array(data),
  }
  let result = kmeans_quantize(img, 2, 10)
  for i in 0..<4 {
    assert_eq(result.data[i * 4 + 3], b'\xFF')
  }
  let _ = img
  let _ = result
}

///|
test "kmeans_quantize: raises on invalid k" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 3,
    data: Array::make(12, b'\x80') |> Bytes::from_array,
  }
  try {
    let _ = kmeans_quantize(img, 0, 10)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "kmeans_quantize: two distinct colors with k=2" {
  let data : Array[Byte] = [
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\xFF', b'\xFF', b'\xFF',
    b'\xFF', b'\xFF', b'\xFF',
  ]
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let result = kmeans_quantize(img, 2, 20)
  // 前两个像素应该是同一个颜色，后两个也是同一个颜色
  assert_eq(result.data[0], result.data[3])
  assert_eq(result.data[6], result.data[9])
  let _ = img
  let _ = result
}

///|
test "median_cut: num_colors < 2 returns to_rgb" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 3,
    data: Bytes::from_array([
      b'\x10', b'\x20', b'\x30', b'\x40', b'\x50', b'\x60', b'\x70', b'\x80', b'\x90',
      b'\xA0', b'\xB0', b'\xC0',
    ]),
  }
  let result = median_cut(img, 1)
  assert_eq(result.channels, 3)
  assert_eq(result.width, 2)
  assert_eq(result.height, 2)
  let _ = img
  let _ = result
}

///|
test "kmeans_quantize: raises on grayscale input" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: Bytes::from_array([128, 128, 128, 128]),
  }
  try {
    let _ = kmeans_quantize(img, 4, 10)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "kmeans_quantize: empty image returns original" {
  let img = @types.Image::{
    width: 0,
    height: 0,
    channels: 3,
    data: Bytes::from_array([]),
  }
  let result = kmeans_quantize(img, 4, 10)
  assert_eq(result.width, 0)
  assert_eq(result.height, 0)
  assert_eq(result.channels, 3)
}

///|
test "median_cut: channel_value branch 1 (G channel split)" {
  // Create an image where G channel has the widest range
  // This forces channel_value to return 1 (G channel)
  let img = @types.Image::{
    width: 4,
    height: 1,
    channels: 3,
    data: Bytes::from_array([
      b'\x00', b'\x00', b'\x00', // pixel 0
       b'\x00', b'\xFF', b'\x00', // pixel 1: wide G range
       b'\x00', b'\x80', b'\x00', // pixel 2
       b'\x00', b'\x40', b'\x00', // pixel 3
    ]),
  }
  let result = median_cut(img, 2)
  assert_eq(result.channels, 3)
  assert_eq(result.width, 4)
}

///|
test "median_cut: bucket_average empty bucket returns (0,0,0)" {
  // Create an image where some buckets will be empty after sorting
  // This forces bucket_average to hit the len == 0 branch
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 3,
    data: Bytes::from_array([
      b'\xFF', b'\xFF', b'\xFF', // white
       b'\xFF', b'\xFF', b'\xFF', // white
       b'\x00', b'\x00', b'\x00', // black
       b'\x00', b'\x00', b'\x00', // black
    ]),
  }
  let result = median_cut(img, 4)
  assert_eq(result.channels, 3)
  assert_eq(result.width, 2)
}

///|
test "median_cut: bucket_max_range G channel selected" {
  // Create image where G channel range is widest
  let img = @types.Image::{
    width: 4,
    height: 1,
    channels: 3,
    data: Bytes::from_array([
      b'\x00', b'\x00', b'\x00', // pixel 0
       b'\x00', b'\xFF', b'\x80', // pixel 1: G=0..255, R=0, B=0..128
       b'\x00', b'\x80', b'\x40', // pixel 2
       b'\x00', b'\x40', b'\x20', // pixel 3
    ]),
  }
  let result = median_cut(img, 2)
  assert_eq(result.channels, 3)
  assert_eq(result.width, 4)
}

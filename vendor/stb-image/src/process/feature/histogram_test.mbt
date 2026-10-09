///|
test "histogram: returns 256 bins" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let hist = histogram(img)
  assert_eq(hist.length(), 256)
  // 总和 = 像素数
  let mut total = 0
  for i in 0..<256 {
    total += hist[i]
  }
  assert_eq(total, 16)
  let _ = img
}

///|
test "histogram: uniform image has single bin" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Array::make(16, b'\x80') |> Bytes::from_array,
  }
  let hist = histogram(img)
  // 所有像素在 bin 128
  assert_eq(hist[128], 16)
  let _ = img
}

///|
test "histogram_equalize: preserves dimensions" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let result = histogram_equalize(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "histogram_equalize: uniform image is unchanged" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Array::make(16, b'\x80') |> Bytes::from_array,
  }
  let result = histogram_equalize(img)
  assert_eq(result.data, img.data)
  let _ = img
  let _ = result
}

///|
test "histogram_equalize: preserves alpha" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(4))
  let result = histogram_equalize(img)
  assert_eq(result.data[3].to_int(), img.data[3].to_int())
  let _ = img
  let _ = result
}

///|
test "histogram_normalize: stretches range to 0-255" {
  // 像素值范围 [50, 100] → [0, 255]
  let data : Array[Byte] = Array::make(4, b'\x00')
  data[0] = (50).to_byte()
  data[1] = (100).to_byte()
  data[2] = (75).to_byte()
  data[3] = (50).to_byte()
  let img = @types.Image::{
    width: 4,
    height: 1,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let result = histogram_normalize(img)
  assert_eq(result.data[0].to_int(), 0)
  assert_eq(result.data[1].to_int(), 255)
  let _ = img
  let _ = result
}

///|
test "histogram_normalize: uniform image is unchanged" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Array::make(16, b'\x80') |> Bytes::from_array,
  }
  let result = histogram_normalize(img)
  assert_eq(result.data, img.data)
  let _ = img
  let _ = result
}

///|
test "histogram_normalize: already full range is identity" {
  let data : Array[Byte] = [b'\x00', b'\xFF', b'\x80', b'\x40']
  let img = @types.Image::{
    width: 4,
    height: 1,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let result = histogram_normalize(img)
  assert_eq(result.data[0].to_int(), 0)
  assert_eq(result.data[1].to_int(), 255)
  let _ = img
  let _ = result
}

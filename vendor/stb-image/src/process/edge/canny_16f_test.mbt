// Canny 边缘检测 16-bit/float 变体测试

///|
fn make_img16_canny(w : Int, h : Int, ch : Int, val : Int) -> @types.Image16 {
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
fn make_imgf_canny(w : Int, h : Int, ch : Int, val : Float) -> @types.ImageF {
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
fn read_u16_at_canny(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn read_f32_at_canny(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

///|
test "canny_edge_16: uniform image no edges" {
  let img = make_img16_canny(8, 8, 1, 30000)
  let result = canny_edge_16(img)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.channels, 1)
  let mut edge_count = 0
  for i in 0..<64 {
    if read_u16_at_canny(result.data, i * 2) > 0 {
      edge_count += 1
    }
  }
  assert_true(edge_count < 10)
  let _ = img
  let _ = result
}

///|
test "canny_edge_f: uniform image no edges" {
  let img = make_imgf_canny(8, 8, 1, 0.5F)
  let result = canny_edge_f(img)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.channels, 1)
  let mut edge_count = 0
  for i in 0..<64 {
    if read_f32_at_canny(result.data, i * 4) > 0.0F {
      edge_count += 1
    }
  }
  assert_true(edge_count < 10)
  let _ = img
  let _ = result
}

///|
test "canny_edge_16: rejects invalid channels" {
  let img = @types.Image16::{
    width: 4,
    height: 4,
    channels: 2,
    data: Array::make(32, b'\x00') |> Bytes::from_array,
  }
  try {
    let _ = canny_edge_16(img)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "canny_edge_16: rejects invalid threshold" {
  let img = make_img16_canny(4, 4, 1, 30000)
  try {
    let _ = canny_edge_16(img, low_threshold=70000)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "canny_edge_f: rejects invalid threshold" {
  let img = make_imgf_canny(4, 4, 1, 0.5F)
  try {
    let _ = canny_edge_f(img, low_threshold=1.5F)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "canny_edge_16: RGB converts to grayscale" {
  let img = make_img16_canny(8, 8, 3, 30000)
  let result = canny_edge_16(img)
  assert_eq(result.channels, 1)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  let _ = img
  let _ = result
}

///|
test "canny_edge_f: RGBA converts to grayscale" {
  let img = make_imgf_canny(8, 8, 4, 0.5F)
  let result = canny_edge_f(img)
  assert_eq(result.channels, 1)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  let _ = img
  let _ = result
}

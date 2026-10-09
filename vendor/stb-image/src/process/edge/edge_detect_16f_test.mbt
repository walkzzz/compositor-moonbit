// edge_detect 16-bit/float 变体测试

///|
fn make_image16_e(w : Int, h : Int, ch : Int) -> @types.Image16 {
  let data : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<ch {
        let val = (x + y + c) % 256
        let offset = ((y * w + x) * ch + c) * 2
        data[offset] = val.to_byte()
        data[offset + 1] = b'\x00'
      }
    }
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
}

///|
fn make_imagef_e(w : Int, h : Int, ch : Int) -> @types.ImageF {
  let data : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<ch {
        let val = Float::from_int((x + y + c) % 256) / 255.0F
        let offset = ((y * w + x) * ch + c) * 4
        let bits = val.reinterpret_as_int()
        data[offset] = (bits & 0xFF).to_byte()
        data[offset + 1] = ((bits >> 8) & 0xFF).to_byte()
        data[offset + 2] = ((bits >> 16) & 0xFF).to_byte()
        data[offset + 3] = ((bits >> 24) & 0xFF).to_byte()
      }
    }
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
}

///|
fn make_uniform_image16_e(
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
fn make_uniform_imagef_e(
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
test "edge_detect_sobel_16: output is single channel" {
  let img = make_image16_e(4, 4, 3)
  let result = edge_detect_sobel_16(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "edge_detect_sobel_16: uniform image has zero edges" {
  let img = make_uniform_image16_e(5, 5, 1, 1000)
  let result = edge_detect_sobel_16(img)
  for i in 0..<25 {
    let offset = i * 2
    let v = result.data[offset].to_int() +
      result.data[offset + 1].to_int() * 256
    assert_eq(v, 0)
  }
  let _ = img
  let _ = result
}

///|
test "edge_detect_sobel_f: output is single channel" {
  let img = make_imagef_e(4, 4, 3)
  let result = edge_detect_sobel_f(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "edge_detect_sobel_f: uniform image has zero edges" {
  let img = make_uniform_imagef_e(5, 5, 1, 0.5F)
  let result = edge_detect_sobel_f(img)
  for i in 0..<25 {
    let offset = i * 4
    let b0 = result.data[offset].to_int()
    let b1 = result.data[offset + 1].to_int()
    let b2 = result.data[offset + 2].to_int()
    let b3 = result.data[offset + 3].to_int()
    let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    let v = Float::reinterpret_from_int(bits)
    assert_true(v < 0.001F)
  }
  let _ = img
  let _ = result
}

///|
test "edge_detect_laplacian_16: output is single channel" {
  let img = make_image16_e(5, 5, 3)
  let result = edge_detect_laplacian_16(img)
  assert_eq(result.width, 5)
  assert_eq(result.height, 5)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "edge_detect_laplacian_f: output is single channel" {
  let img = make_imagef_e(5, 5, 3)
  let result = edge_detect_laplacian_f(img)
  assert_eq(result.width, 5)
  assert_eq(result.height, 5)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "edge_detect_prewitt_16: output is single channel" {
  let img = make_image16_e(5, 5, 3)
  let result = edge_detect_prewitt_16(img)
  assert_eq(result.width, 5)
  assert_eq(result.height, 5)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "edge_detect_prewitt_f: output is single channel" {
  let img = make_imagef_e(5, 5, 3)
  let result = edge_detect_prewitt_f(img)
  assert_eq(result.width, 5)
  assert_eq(result.height, 5)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

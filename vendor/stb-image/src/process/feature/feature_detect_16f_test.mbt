// LBP 局部二值模式 16-bit/float 变体测试

///|
fn make_img16_feat(w : Int, h : Int, ch : Int, val : Int) -> @types.Image16 {
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
fn make_imgf_feat(w : Int, h : Int, ch : Int, val : Float) -> @types.ImageF {
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
fn read_u16_at_feat(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn read_f32_at_feat(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

// ========== LBP ==========

///|
test "lbp_16: uniform image" {
  let img = make_img16_feat(5, 5, 1, 30000)
  let result = lbp_16(img)
  assert_eq(result.width, 5)
  assert_eq(result.height, 5)
  assert_eq(result.channels, 1)
  for i in 0..<25 {
    let v = read_u16_at_feat(result.data, i * 2)
    assert_true(v == 0 || v == 255)
  }
  let _ = img
  let _ = result
}

///|
test "lbp_f: uniform image" {
  let img = make_imgf_feat(5, 5, 1, 0.5F)
  let result = lbp_f(img)
  assert_eq(result.width, 5)
  assert_eq(result.height, 5)
  assert_eq(result.channels, 1)
  for i in 0..<25 {
    let v = read_f32_at_feat(result.data, i * 4)
    assert_true(v >= 0.0F && v <= 1.0F)
  }
  let _ = img
  let _ = result
}

///|
test "lbp_16: rejects invalid channels" {
  let img = @types.Image16::{
    width: 2,
    height: 2,
    channels: 2,
    data: Array::make(8, b'\x00') |> Bytes::from_array,
  }
  try {
    let _ = lbp_16(img)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "lbp_uniform_16: output range 0-9" {
  let img = make_img16_feat(5, 5, 1, 30000)
  let result = lbp_uniform_16(img)
  assert_eq(result.channels, 1)
  for i in 0..<25 {
    let v = read_u16_at_feat(result.data, i * 2)
    assert_true(v >= 0 && v <= 9)
  }
  let _ = img
  let _ = result
}

///|
test "lbp_uniform_f: output range 0-1" {
  let img = make_imgf_feat(5, 5, 1, 0.5F)
  let result = lbp_uniform_f(img)
  assert_eq(result.channels, 1)
  for i in 0..<25 {
    let v = read_f32_at_feat(result.data, i * 4)
    assert_true(v >= 0.0F && v <= 1.0F)
  }
  let _ = img
  let _ = result
}

///|
test "lbp_16: RGBA preserves alpha" {
  let img = make_img16_feat(4, 4, 4, 30000)
  let result = lbp_16(img)
  assert_eq(result.channels, 4)
  for i in 0..<16 {
    let alpha_off = i * 8 + 6
    assert_eq(result.data[alpha_off], img.data[alpha_off])
    assert_eq(result.data[alpha_off + 1], img.data[alpha_off + 1])
  }
  let _ = img
  let _ = result
}

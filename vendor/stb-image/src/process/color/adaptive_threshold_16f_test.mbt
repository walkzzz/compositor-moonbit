// adaptive_threshold 16-bit/float 变体测试

///|
fn make_img16_at(w : Int, h : Int, ch : Int) -> @types.Image16 {
  let data : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<ch {
        let val = if (x + y) % 2 == 0 { 50000 } else { 10000 }
        let offset = ((y * w + x) * ch + c) * 2
        data[offset] = (val & 0xFF).to_byte()
        data[offset + 1] = ((val >> 8) & 0xFF).to_byte()
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
fn make_imgf_at(w : Int, h : Int, ch : Int) -> @types.ImageF {
  let data : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<ch {
        let val = if (x + y) % 2 == 0 { 0.8F } else { 0.2F }
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
test "adaptive_threshold_mean_16: output is binary" {
  let img = make_img16_at(5, 5, 1)
  let result = adaptive_threshold_mean_16(img, 3, 0)
  assert_eq(result.width, 5)
  assert_eq(result.height, 5)
  assert_eq(result.channels, 1)
  // 检查输出值只能是 0 或 65535
  for i in 0..<25 {
    let v = read_u16_le_at(result.data, i * 2)
    assert_true(v == 0 || v == 65535)
  }
  let _ = img
  let _ = result
}

///|
test "adaptive_threshold_mean_16: rejects even block_size" {
  let img = make_img16_at(5, 5, 1)
  try {
    let _ = adaptive_threshold_mean_16(img, 4, 0)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "adaptive_threshold_mean_f: output is binary" {
  let img = make_imgf_at(5, 5, 1)
  let result = adaptive_threshold_mean_f(img, 3, 0.0F)
  assert_eq(result.width, 5)
  assert_eq(result.height, 5)
  assert_eq(result.channels, 1)
  for i in 0..<25 {
    let v = read_float_le_at(result.data, i * 4)
    assert_true(v < 0.001F || v > 0.999F)
  }
  let _ = img
  let _ = result
}

///|
test "adaptive_threshold_gaussian_16: output is binary" {
  let img = make_img16_at(5, 5, 1)
  let result = adaptive_threshold_gaussian_16(img, 3, 0)
  assert_eq(result.width, 5)
  assert_eq(result.height, 5)
  assert_eq(result.channels, 1)
  for i in 0..<25 {
    let v = read_u16_le_at(result.data, i * 2)
    assert_true(v == 0 || v == 65535)
  }
  let _ = img
  let _ = result
}

///|
test "adaptive_threshold_gaussian_f: output is binary" {
  let img = make_imgf_at(5, 5, 1)
  let result = adaptive_threshold_gaussian_f(img, 3, 0.0F)
  assert_eq(result.width, 5)
  assert_eq(result.height, 5)
  assert_eq(result.channels, 1)
  for i in 0..<25 {
    let v = read_float_le_at(result.data, i * 4)
    assert_true(v < 0.001F || v > 0.999F)
  }
  let _ = img
  let _ = result
}

///|
test "threshold_otsu_16: output is binary" {
  let img = make_img16_at(5, 5, 1)
  let result = threshold_otsu_16(img)
  assert_eq(result.width, 5)
  assert_eq(result.height, 5)
  assert_eq(result.channels, 1)
  for i in 0..<25 {
    let v = read_u16_le_at(result.data, i * 2)
    assert_true(v == 0 || v == 65535)
  }
  let _ = img
  let _ = result
}

///|
test "threshold_otsu_16: RGBA preserves alpha" {
  let img = make_img16_at(4, 4, 4)
  let result = threshold_otsu_16(img)
  assert_eq(result.channels, 4)
  // 检查 alpha 通道保持不变
  for i in 0..<16 {
    let alpha_off = i * 8 + 6
    assert_eq(result.data[alpha_off], img.data[alpha_off])
    assert_eq(result.data[alpha_off + 1], img.data[alpha_off + 1])
  }
  let _ = img
  let _ = result
}

///|
test "threshold_otsu_f: output is binary" {
  let img = make_imgf_at(5, 5, 1)
  let result = threshold_otsu_f(img)
  assert_eq(result.width, 5)
  assert_eq(result.height, 5)
  assert_eq(result.channels, 1)
  for i in 0..<25 {
    let v = read_float_le_at(result.data, i * 4)
    assert_true(v < 0.001F || v > 0.999F)
  }
  let _ = img
  let _ = result
}

///|
test "threshold_otsu_f: RGBA preserves alpha" {
  let img = make_imgf_at(4, 4, 4)
  let result = threshold_otsu_f(img)
  assert_eq(result.channels, 4)
  for i in 0..<16 {
    let alpha_off = i * 16 + 12
    for b in 0..<4 {
      assert_eq(result.data[alpha_off + b], img.data[alpha_off + b])
    }
  }
  let _ = img
  let _ = result
}

///|
test "adaptive_threshold_mean_16: rejects invalid channels" {
  let img = @types.Image16::{
    width: 2,
    height: 2,
    channels: 2,
    data: Array::make(8, b'\x00') |> Bytes::from_array,
  }
  try {
    let _ = adaptive_threshold_mean_16(img, 3, 0)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

// 辅助函数

///|
fn read_u16_le_at(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn read_float_le_at(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

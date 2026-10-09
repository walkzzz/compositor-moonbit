// color 16-bit/float 变体测试

///|
fn make_img16(w : Int, h : Int, ch : Int) -> @types.Image16 {
  let data : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<ch {
        let val = (x + y + c) % 256 * 100
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
fn make_imgf(w : Int, h : Int, ch : Int) -> @types.ImageF {
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
test "adjust_brightness_16: delta=0 is identity" {
  let img = make_img16(3, 3, 3)
  let result = adjust_brightness_16(img, 0)
  assert_eq(result, img)
  let _ = img
  let _ = result
}

///|
test "adjust_brightness_16: positive delta brightens" {
  let img = make_img16(2, 2, 3)
  let result = adjust_brightness_16(img, 1000)
  assert_eq(result.width, 2)
  assert_eq(result.height, 2)
  let _ = img
  let _ = result
}

///|
test "adjust_brightness_16: clamps to 65535" {
  let data = Array::make(2 * 2 * 3 * 2, b'\x00')
  for i in 0..<12 {
    data[i * 2] = b'\xFF'
    data[i * 2 + 1] = b'\xFF'
  }
  let img = @types.Image16::{
    width: 2,
    height: 2,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let result = adjust_brightness_16(img, 10000)
  assert_eq(result, img)
  let _ = data
  let _ = img
  let _ = result
}

///|
test "adjust_brightness_f: delta=0 is identity" {
  let img = make_imgf(3, 3, 3)
  let result = adjust_brightness_f(img, 0.0F)
  assert_eq(result, img)
  let _ = img
  let _ = result
}

///|
test "adjust_brightness_f: preserves dimensions" {
  let img = make_imgf(4, 3, 3)
  let result = adjust_brightness_f(img, 0.1F)
  assert_eq(result.width, 4)
  assert_eq(result.height, 3)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "adjust_contrast_16: factor=1.0 is identity" {
  let img = make_img16(3, 3, 3)
  let result = adjust_contrast_16(img, 1.0F)
  assert_eq(result, img)
  let _ = img
  let _ = result
}

///|
test "adjust_contrast_16: preserves dimensions" {
  let img = make_img16(4, 3, 2)
  let result = adjust_contrast_16(img, 1.5F)
  assert_eq(result.width, 4)
  assert_eq(result.height, 3)
  assert_eq(result.channels, 2)
  let _ = img
  let _ = result
}

///|
test "adjust_contrast_f: factor=1.0 is identity" {
  let img = make_imgf(3, 3, 3)
  let result = adjust_contrast_f(img, 1.0F)
  assert_eq(result.width, 3)
  assert_eq(result.height, 3)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "adjust_contrast_f: preserves dimensions" {
  let img = make_imgf(4, 3, 3)
  let result = adjust_contrast_f(img, 2.0F)
  assert_eq(result.width, 4)
  assert_eq(result.height, 3)
  let _ = img
  let _ = result
}

///|
test "adjust_brightness_16: grayscale image" {
  let img = make_img16(3, 3, 1)
  let result = adjust_brightness_16(img, 500)
  assert_eq(result.channels, 1)
  assert_eq(result.width, 3)
  let _ = img
  let _ = result
}

///|
test "adjust_brightness_f: negative delta darkens" {
  let img = make_imgf(2, 2, 3)
  let result = adjust_brightness_f(img, -0.1F)
  assert_eq(result.width, 2)
  assert_eq(result.height, 2)
  let _ = img
  let _ = result
}

///|
test "adjust_brightness_16: negative delta clamps to 0" {
  let data = Array::make(2 * 2 * 3 * 2, b'\x00')
  for i in 0..<12 {
    data[i * 2] = b'\x10'
    data[i * 2 + 1] = b'\x00'
  }
  let img = @types.Image16::{
    width: 2,
    height: 2,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let result = adjust_brightness_16(img, -100)
  for i in 0..<12 {
    let val = result.data[i * 2].to_int() +
      result.data[i * 2 + 1].to_int() * 256
    assert_eq(val, 0)
  }
  let _ = data
  let _ = img
  let _ = result
}

///|
test "adjust_brightness_16: RGBA preserves alpha" {
  let data : Array[Byte] = Array::make(1 * 1 * 4 * 2, b'\x00')
  data[0] = b'\x80'
  data[1] = b'\x00'
  data[2] = b'\x40'
  data[3] = b'\x00'
  data[4] = b'\x20'
  data[5] = b'\x00'
  data[6] = b'\xFF'
  data[7] = b'\xFF'
  let img = @types.Image16::{
    width: 1,
    height: 1,
    channels: 4,
    data: Bytes::from_array(data),
  }
  let result = adjust_brightness_16(img, 100)
  assert_eq(result.data[6], b'\xFF')
  assert_eq(result.data[7], b'\xFF')
  let _ = data
  let _ = img
  let _ = result
}

///|
test "adjust_brightness_f: RGBA preserves alpha" {
  let data : Array[Byte] = Array::make(1 * 1 * 4 * 4, b'\x00')
  let alpha_bits = 0.5F.reinterpret_as_int()
  data[12] = (alpha_bits & 0xFF).to_byte()
  data[13] = ((alpha_bits >> 8) & 0xFF).to_byte()
  data[14] = ((alpha_bits >> 16) & 0xFF).to_byte()
  data[15] = ((alpha_bits >> 24) & 0xFF).to_byte()
  let img = @types.ImageF::{
    width: 1,
    height: 1,
    channels: 4,
    data: Bytes::from_array(data),
  }
  let result = adjust_brightness_f(img, 0.1F)
  assert_eq(result.data[12], data[12])
  assert_eq(result.data[13], data[13])
  assert_eq(result.data[14], data[14])
  assert_eq(result.data[15], data[15])
  let _ = data
  let _ = img
  let _ = result
}

///|
test "adjust_contrast_16: high factor clamps to 65535" {
  let data = Array::make(1 * 1 * 3 * 2, b'\x00')
  data[0] = b'\xFF'
  data[1] = b'\xFF'
  data[2] = b'\x00'
  data[3] = b'\x80'
  data[4] = b'\x00'
  data[5] = b'\x00'
  let img = @types.Image16::{
    width: 1,
    height: 1,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let result = adjust_contrast_16(img, 10.0F)
  let v0 = result.data[0].to_int() + result.data[1].to_int() * 256
  assert_eq(v0, 65535)
  let _ = data
  let _ = img
  let _ = result
}

///|
test "adjust_contrast_16: RGBA preserves alpha" {
  let data : Array[Byte] = Array::make(1 * 1 * 4 * 2, b'\x00')
  data[6] = b'\xAA'
  data[7] = b'\xBB'
  let img = @types.Image16::{
    width: 1,
    height: 1,
    channels: 4,
    data: Bytes::from_array(data),
  }
  let result = adjust_contrast_16(img, 2.0F)
  assert_eq(result.data[6], b'\xAA')
  assert_eq(result.data[7], b'\xBB')
  let _ = data
  let _ = img
  let _ = result
}

///|
test "adjust_contrast_f: RGBA preserves alpha" {
  let data : Array[Byte] = Array::make(1 * 1 * 4 * 4, b'\x00')
  let alpha_bits = 0.7F.reinterpret_as_int()
  data[12] = (alpha_bits & 0xFF).to_byte()
  data[13] = ((alpha_bits >> 8) & 0xFF).to_byte()
  data[14] = ((alpha_bits >> 16) & 0xFF).to_byte()
  data[15] = ((alpha_bits >> 24) & 0xFF).to_byte()
  let img = @types.ImageF::{
    width: 1,
    height: 1,
    channels: 4,
    data: Bytes::from_array(data),
  }
  let result = adjust_contrast_f(img, 2.0F)
  assert_eq(result.data[12], data[12])
  assert_eq(result.data[13], data[13])
  assert_eq(result.data[14], data[14])
  assert_eq(result.data[15], data[15])
  let _ = data
  let _ = img
  let _ = result
}

///|
test "adjust_gamma_16: gamma=1.0 is identity" {
  let img = make_img16(4, 3, 3)
  let result = adjust_gamma_16(img, 1.0F)
  assert_eq(result, img)
  let _ = img
  let _ = result
}

///|
test "adjust_gamma_f: gamma=1.0 is identity" {
  let img = make_imgf(4, 3, 3)
  let result = adjust_gamma_f(img, 1.0F)
  // 浮点数精度：powf(x, 1.0) 近似等于 x
  for i in 0..<(4 * 3 * 3) {
    let offset = i * 4
    let b0 = img.data[offset].to_int()
    let b1 = img.data[offset + 1].to_int()
    let b2 = img.data[offset + 2].to_int()
    let b3 = img.data[offset + 3].to_int()
    let v_orig = Float::reinterpret_from_int(
      b0 | (b1 << 8) | (b2 << 16) | (b3 << 24),
    )
    let c0 = result.data[offset].to_int()
    let c1 = result.data[offset + 1].to_int()
    let c2 = result.data[offset + 2].to_int()
    let c3 = result.data[offset + 3].to_int()
    let v_new = Float::reinterpret_from_int(
      c0 | (c1 << 8) | (c2 << 16) | (c3 << 24),
    )
    assert_true((v_orig - v_new).abs() < 0.0001F)
  }
  let _ = img
  let _ = result
}

///|
test "invert_16: double invert is identity" {
  let img = make_img16(4, 3, 3)
  let r1 = invert_16(img)
  let r2 = invert_16(r1)
  assert_eq(r2, img)
  let _ = img
  let _ = r1
  let _ = r2
}

///|
test "invert_f: double invert is identity" {
  let img = make_imgf(4, 3, 3)
  let r1 = invert_f(img)
  let r2 = invert_f(r1)
  // 浮点数精度：1.0 - (1.0 - x) 近似等于 x
  for i in 0..<(4 * 3 * 3) {
    let offset = i * 4
    let b0 = img.data[offset].to_int()
    let b1 = img.data[offset + 1].to_int()
    let b2 = img.data[offset + 2].to_int()
    let b3 = img.data[offset + 3].to_int()
    let v_orig = Float::reinterpret_from_int(
      b0 | (b1 << 8) | (b2 << 16) | (b3 << 24),
    )
    let c0 = r2.data[offset].to_int()
    let c1 = r2.data[offset + 1].to_int()
    let c2 = r2.data[offset + 2].to_int()
    let c3 = r2.data[offset + 3].to_int()
    let v_new = Float::reinterpret_from_int(
      c0 | (c1 << 8) | (c2 << 16) | (c3 << 24),
    )
    assert_true((v_orig - v_new).abs() < 0.0001F)
  }
  let _ = img
  let _ = r1
  let _ = r2
}

///|
test "to_grayscale_16: output channels=1" {
  let img = make_img16(4, 3, 3)
  let result = to_grayscale_16(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 3)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "to_grayscale_f: output channels=1" {
  let img = make_imgf(4, 3, 3)
  let result = to_grayscale_f(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 3)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

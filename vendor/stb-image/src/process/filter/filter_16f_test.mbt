// filter 16-bit/float 变体测试

///|
fn make_image16_f(w : Int, h : Int, ch : Int) -> @types.Image16 {
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
fn make_imagef_f(w : Int, h : Int, ch : Int) -> @types.ImageF {
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
fn make_uniform_image16(
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
fn make_uniform_imagef(
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
fn read_u16_le_ft(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn read_f32_le_ft(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

///|
test "box_blur_16: radius=0 is identity" {
  let img = make_image16_f(4, 4, 3)
  let result = box_blur_16(img, 0)
  assert_eq(result.data, img.data)
  let _ = img
  let _ = result
}

///|
test "box_blur_16: preserves dimensions" {
  let img = make_image16_f(4, 4, 3)
  let result = box_blur_16(img, 1)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "box_blur_16: uniform image is unchanged" {
  let img = make_uniform_image16(3, 3, 1, 1000)
  let result = box_blur_16(img, 1)
  for i in 0..<9 {
    assert_eq(read_u16_le_ft(result.data, i * 2), 1000)
  }
  let _ = img
  let _ = result
}

///|
test "box_blur_f: radius=0 is identity" {
  let img = make_imagef_f(4, 4, 3)
  let result = box_blur_f(img, 0)
  assert_eq(result.data, img.data)
  let _ = img
  let _ = result
}

///|
test "box_blur_f: preserves dimensions" {
  let img = make_imagef_f(4, 4, 3)
  let result = box_blur_f(img, 1)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "box_blur_f: uniform image is unchanged" {
  let img = make_uniform_imagef(3, 3, 1, 0.5F)
  let result = box_blur_f(img, 1)
  for i in 0..<9 {
    let v = read_f32_le_ft(result.data, i * 4)
    assert_true(v > 0.49F && v < 0.51F)
  }
  let _ = img
  let _ = result
}

///|
test "gaussian_blur_16: radius=0 is identity" {
  let img = make_image16_f(4, 4, 3)
  let result = gaussian_blur_16(img, 0, 1.0F)
  assert_eq(result.data, img.data)
  let _ = img
  let _ = result
}

///|
test "gaussian_blur_16: preserves dimensions" {
  let img = make_image16_f(4, 4, 3)
  let result = gaussian_blur_16(img, 2, 1.5F)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "gaussian_blur_16: uniform image is unchanged" {
  let img = make_uniform_image16(3, 3, 1, 500)
  let result = gaussian_blur_16(img, 1, 1.0F)
  for i in 0..<9 {
    assert_eq(read_u16_le_ft(result.data, i * 2), 500)
  }
  let _ = img
  let _ = result
}

///|
test "gaussian_blur_f: radius=0 is identity" {
  let img = make_imagef_f(4, 4, 3)
  let result = gaussian_blur_f(img, 0, 1.0F)
  assert_eq(result.data, img.data)
  let _ = img
  let _ = result
}

///|
test "gaussian_blur_f: preserves dimensions" {
  let img = make_imagef_f(4, 4, 3)
  let result = gaussian_blur_f(img, 2, 1.5F)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "gaussian_blur_f: uniform image is unchanged" {
  let img = make_uniform_imagef(3, 3, 1, 0.7F)
  let result = gaussian_blur_f(img, 1, 1.0F)
  for i in 0..<9 {
    let v = read_f32_le_ft(result.data, i * 4)
    assert_true(v > 0.69F && v < 0.71F)
  }
  let _ = img
  let _ = result
}

///|
test "median_blur_16: ksize<=1 is identity" {
  let img = make_image16_f(4, 4, 3)
  let result = median_blur_16(img, 1)
  assert_eq(result.data, img.data)
  let _ = img
  let _ = result
}

///|
test "median_blur_16: preserves dimensions" {
  let img = make_image16_f(4, 4, 3)
  let result = median_blur_16(img, 3)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "median_blur_16: uniform image is unchanged" {
  let img = make_uniform_image16(3, 3, 1, 2000)
  let result = median_blur_16(img, 3)
  for i in 0..<9 {
    assert_eq(read_u16_le_ft(result.data, i * 2), 2000)
  }
  let _ = img
  let _ = result
}

///|
test "median_blur_f: ksize<=1 is identity" {
  let img = make_imagef_f(4, 4, 3)
  let result = median_blur_f(img, 1)
  assert_eq(result.data, img.data)
  let _ = img
  let _ = result
}

///|
test "median_blur_f: preserves dimensions" {
  let img = make_imagef_f(4, 4, 3)
  let result = median_blur_f(img, 3)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "median_blur_f: uniform image is unchanged" {
  let img = make_uniform_imagef(3, 3, 1, 0.3F)
  let result = median_blur_f(img, 3)
  for i in 0..<9 {
    let v = read_f32_le_ft(result.data, i * 4)
    assert_true(v > 0.29F && v < 0.31F)
  }
  let _ = img
  let _ = result
}

///|
test "sharpen_16: amount=0.0 is identity" {
  let img = make_image16_f(5, 5, 3)
  let result = sharpen_16(img, 0.0F)
  assert_eq(result, img)
  let _ = img
  let _ = result
}

///|
test "sharpen_16: output preserves dimensions" {
  let img = make_image16_f(5, 5, 3)
  let result = sharpen_16(img, 1.0F)
  assert_eq(result.width, 5)
  assert_eq(result.height, 5)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "sharpen_f: amount=0.0 is identity" {
  let img = make_imagef_f(5, 5, 3)
  let result = sharpen_f(img, 0.0F)
  // 浮点数精度：amount=0 时 center=1.0，近似恒等
  for i in 0..<(5 * 5 * 3) {
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
test "sharpen_f: output preserves dimensions" {
  let img = make_imagef_f(5, 5, 3)
  let result = sharpen_f(img, 1.0F)
  assert_eq(result.width, 5)
  assert_eq(result.height, 5)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

// color_convert 16-bit/float 变体测试

///|
fn make_img16_cc(w : Int, h : Int, ch : Int) -> @types.Image16 {
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
fn make_imgf_cc(w : Int, h : Int, ch : Int) -> @types.ImageF {
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
test "to_rgb_16: RGBA -> RGB channels=3" {
  let img = make_img16_cc(4, 3, 4)
  let result = to_rgb_16(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 3)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "to_rgb_f: RGBA -> RGB channels=3" {
  let img = make_imgf_cc(4, 3, 4)
  let result = to_rgb_f(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 3)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "to_rgba_16: RGB -> RGBA channels=4, alpha=65535" {
  let img = make_img16_cc(4, 3, 3)
  let result = to_rgba_16(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 3)
  assert_eq(result.channels, 4)
  // 检查第一个像素的 alpha 通道 = 65535
  assert_eq(result.data[6], b'\xFF')
  assert_eq(result.data[7], b'\xFF')
  let _ = img
  let _ = result
}

///|
test "to_rgba_f: RGB -> RGBA channels=4, alpha=1.0" {
  let img = make_imgf_cc(4, 3, 3)
  let result = to_rgba_f(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 3)
  assert_eq(result.channels, 4)
  // 检查第一个像素的 alpha 通道 = 1.0 (0x3F800000)
  assert_eq(result.data[12], b'\x00')
  assert_eq(result.data[13], b'\x00')
  assert_eq(result.data[14], b'\x80')
  assert_eq(result.data[15], b'\x3F')
  let _ = img
  let _ = result
}

///|
test "premultiply_alpha_16: requires channels=4" {
  let img = make_img16_cc(4, 3, 3)
  try {
    let _ = premultiply_alpha_16(img)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "premultiply_alpha_f: requires channels=4" {
  let img = make_imgf_cc(4, 3, 3)
  try {
    let _ = premultiply_alpha_f(img)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "unpremultiply_alpha_16: requires channels=4" {
  let img = make_img16_cc(4, 3, 3)
  try {
    let _ = unpremultiply_alpha_16(img)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "unpremultiply_alpha_f: requires channels=4" {
  let img = make_imgf_cc(4, 3, 3)
  try {
    let _ = unpremultiply_alpha_f(img)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "rgb_to_ycbcr_16: roundtrip preserves values" {
  let (r, g, b) = (30000, 20000, 10000)
  let (y, cb, cr) = rgb_to_ycbcr_16(r, g, b)
  let (r2, g2, b2) = ycbcr_to_rgb_16(y, cb, cr)
  assert_true((r - r2).abs() < 100)
  assert_true((g - g2).abs() < 100)
  assert_true((b - b2).abs() < 100)
}

///|
test "rgb_to_ycbcr_f: roundtrip preserves values" {
  let (r, g, b) = (0.5F, 0.3F, 0.1F)
  let (y, cb, cr) = rgb_to_ycbcr_f(r, g, b)
  let (r2, g2, b2) = ycbcr_to_rgb_f(y, cb, cr)
  assert_true((r - r2).abs() < 0.01F)
  assert_true((g - g2).abs() < 0.01F)
  assert_true((b - b2).abs() < 0.01F)
}

///|
test "rgb_to_cmyk_16: roundtrip preserves values" {
  let (r, g, b) = (30000, 20000, 10000)
  let (c, m, y, k) = rgb_to_cmyk_16(r, g, b)
  let (r2, g2, b2) = cmyk_to_rgb_16(c, m, y, k)
  assert_true((r - r2).abs() < 100)
  assert_true((g - g2).abs() < 100)
  assert_true((b - b2).abs() < 100)
}

///|
test "rgb_to_cmyk_f: roundtrip preserves values" {
  let (r, g, b) = (0.5F, 0.3F, 0.1F)
  let (c, m, y, k) = rgb_to_cmyk_f(r, g, b)
  let (r2, g2, b2) = cmyk_to_rgb_f(c, m, y, k)
  assert_true((r - r2).abs() < 0.01F)
  assert_true((g - g2).abs() < 0.01F)
  assert_true((b - b2).abs() < 0.01F)
}

///|
test "rgb_to_ycbcr_16: output in valid range" {
  let (y, cb, cr) = rgb_to_ycbcr_16(65535, 0, 0)
  assert_true(y >= 0 && y <= 65535)
  assert_true(cb >= 0 && cb <= 65535)
  assert_true(cr >= 0 && cr <= 65535)
}

///|
test "rgb_to_cmyk_16: black gives k=65535" {
  let (c, m, y, k) = rgb_to_cmyk_16(0, 0, 0)
  assert_eq(c, 0)
  assert_eq(m, 0)
  assert_eq(y, 0)
  assert_eq(k, 65535)
}

///|
test "rgb_to_cmyk_f: black gives k=1.0" {
  let (c, m, y, k) = rgb_to_cmyk_f(0.0F, 0.0F, 0.0F)
  assert_true(c < 0.001F)
  assert_true(m < 0.001F)
  assert_true(y < 0.001F)
  assert_true(k > 0.999F)
}

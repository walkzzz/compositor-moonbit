// 形态学操作 16-bit/float 变体测试

///|
fn make_img16_morph(w : Int, h : Int, ch : Int, val : Int) -> @types.Image16 {
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
fn make_imgf_morph(w : Int, h : Int, ch : Int, val : Float) -> @types.ImageF {
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
fn read_u16_at_m(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn read_f32_at_m(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

// ========== erode / dilate ==========

///|
test "erode_16: uniform image unchanged" {
  let img = make_img16_morph(5, 5, 1, 30000)
  let result = erode_16(img)
  assert_eq(result.width, 5)
  assert_eq(result.height, 5)
  assert_eq(result.channels, 1)
  for i in 0..<25 {
    assert_eq(read_u16_at_m(result.data, i * 2), 30000)
  }
  let _ = img
  let _ = result
}

///|
test "erode_f: uniform image unchanged" {
  let img = make_imgf_morph(5, 5, 1, 0.5F)
  let result = erode_f(img)
  assert_eq(result.width, 5)
  assert_eq(result.height, 5)
  assert_eq(result.channels, 1)
  for i in 0..<25 {
    let v = read_f32_at_m(result.data, i * 4)
    assert_true(v > 0.499F && v < 0.501F)
  }
  let _ = img
  let _ = result
}

///|
test "dilate_16: uniform image unchanged" {
  let img = make_img16_morph(5, 5, 1, 30000)
  let result = dilate_16(img)
  assert_eq(result.width, 5)
  assert_eq(result.height, 5)
  assert_eq(result.channels, 1)
  for i in 0..<25 {
    assert_eq(read_u16_at_m(result.data, i * 2), 30000)
  }
  let _ = img
  let _ = result
}

///|
test "dilate_f: uniform image unchanged" {
  let img = make_imgf_morph(5, 5, 1, 0.5F)
  let result = dilate_f(img)
  assert_eq(result.width, 5)
  assert_eq(result.height, 5)
  assert_eq(result.channels, 1)
  for i in 0..<25 {
    let v = read_f32_at_m(result.data, i * 4)
    assert_true(v > 0.499F && v < 0.501F)
  }
  let _ = img
  let _ = result
}

///|
test "erode_16: erode <= original" {
  // 创建一个有亮有暗的图像
  let img = make_img16_morph(5, 5, 1, 50000)
  // 中心像素设为低值
  let data = img.data.to_array()
  data[12 * 2] = b'\x00'
  data[12 * 2 + 1] = b'\x00'
  let img2 = @types.Image16::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let result = erode_16(img2)
  // 腐蚀后中心3x3区域应该都是0
  for y in 1..<4 {
    for x in 1..<4 {
      assert_eq(read_u16_at_m(result.data, (y * 5 + x) * 2), 0)
    }
  }
  let _ = img
  let _ = img2
  let _ = result
}

///|
test "dilate_16: dilate >= original" {
  let img = make_img16_morph(5, 5, 1, 0)
  let data = img.data.to_array()
  data[12 * 2] = b'\xFF'
  data[12 * 2 + 1] = b'\xFF'
  let img2 = @types.Image16::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let result = dilate_16(img2)
  // 膨胀后中心3x3区域应该都是65535
  for y in 1..<4 {
    for x in 1..<4 {
      assert_eq(read_u16_at_m(result.data, (y * 5 + x) * 2), 65535)
    }
  }
  let _ = img
  let _ = img2
  let _ = result
}

// ========== 组合操作 ==========

///|
test "morph_open_16: uniform image unchanged" {
  let img = make_img16_morph(5, 5, 1, 30000)
  let result = morph_open_16(img)
  for i in 0..<25 {
    assert_eq(read_u16_at_m(result.data, i * 2), 30000)
  }
  let _ = img
  let _ = result
}

///|
test "morph_close_16: uniform image unchanged" {
  let img = make_img16_morph(5, 5, 1, 30000)
  let result = morph_close_16(img)
  for i in 0..<25 {
    assert_eq(read_u16_at_m(result.data, i * 2), 30000)
  }
  let _ = img
  let _ = result
}

///|
test "morph_gradient_16: uniform image zero" {
  let img = make_img16_morph(5, 5, 1, 30000)
  let result = morph_gradient_16(img)
  for i in 0..<25 {
    assert_eq(read_u16_at_m(result.data, i * 2), 0)
  }
  let _ = img
  let _ = result
}

///|
test "morph_tophat_16: uniform image zero" {
  let img = make_img16_morph(5, 5, 1, 30000)
  let result = morph_tophat_16(img)
  for i in 0..<25 {
    assert_eq(read_u16_at_m(result.data, i * 2), 0)
  }
  let _ = img
  let _ = result
}

///|
test "morph_blackhat_16: uniform image zero" {
  let img = make_img16_morph(5, 5, 1, 30000)
  let result = morph_blackhat_16(img)
  for i in 0..<25 {
    assert_eq(read_u16_at_m(result.data, i * 2), 0)
  }
  let _ = img
  let _ = result
}

///|
test "morph_open_f: uniform image unchanged" {
  let img = make_imgf_morph(5, 5, 1, 0.5F)
  let result = morph_open_f(img)
  for i in 0..<25 {
    let v = read_f32_at_m(result.data, i * 4)
    assert_true(v > 0.499F && v < 0.501F)
  }
  let _ = img
  let _ = result
}

///|
test "morph_gradient_f: uniform image zero" {
  let img = make_imgf_morph(5, 5, 1, 0.5F)
  let result = morph_gradient_f(img)
  for i in 0..<25 {
    let v = read_f32_at_m(result.data, i * 4)
    assert_true(v < 0.001F)
  }
  let _ = img
  let _ = result
}

// ========== 自定义结构元素 ==========

///|
test "erode_custom_16: rect SE uniform unchanged" {
  let img = make_img16_morph(5, 5, 1, 30000)
  let se = se_rect(3, 3)
  let result = erode_custom_16(img, se)
  for i in 0..<25 {
    assert_eq(read_u16_at_m(result.data, i * 2), 30000)
  }
  let _ = img
  let _ = se
  let _ = result
}

///|
test "dilate_custom_16: cross SE uniform unchanged" {
  let img = make_img16_morph(5, 5, 1, 30000)
  let se = se_cross(3)
  let result = dilate_custom_16(img, se)
  for i in 0..<25 {
    assert_eq(read_u16_at_m(result.data, i * 2), 30000)
  }
  let _ = img
  let _ = se
  let _ = result
}

///|
test "erode_custom_f: ellipse SE uniform unchanged" {
  let img = make_imgf_morph(5, 5, 1, 0.5F)
  let se = se_ellipse(3)
  let result = erode_custom_f(img, se)
  for i in 0..<25 {
    let v = read_f32_at_m(result.data, i * 4)
    assert_true(v > 0.499F && v < 0.501F)
  }
  let _ = img
  let _ = se
  let _ = result
}

///|
test "morph_open_custom_16: works" {
  let img = make_img16_morph(5, 5, 1, 30000)
  let se = se_rect(3, 3)
  let result = morph_open_custom_16(img, se)
  assert_eq(result.width, 5)
  assert_eq(result.height, 5)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = se
  let _ = result
}

///|
test "morph_close_custom_f: works" {
  let img = make_imgf_morph(5, 5, 1, 0.5F)
  let se = se_cross(3)
  let result = morph_close_custom_f(img, se)
  assert_eq(result.width, 5)
  assert_eq(result.height, 5)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = se
  let _ = result
}

// ========== 多通道测试 ==========

///|
test "erode_16: RGBA preserves dimensions" {
  let img = make_img16_morph(4, 4, 4, 30000)
  let result = erode_16(img)
  assert_eq(result.channels, 4)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  let _ = img
  let _ = result
}

///|
test "dilate_f: RGB preserves dimensions" {
  let img = make_imgf_morph(4, 4, 3, 0.5F)
  let result = dilate_f(img)
  assert_eq(result.channels, 3)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  let _ = img
  let _ = result
}

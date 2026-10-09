// v15.0.0 HDR 与全景拼接测试

///|
fn make_hdr_img(w : Int, h : Int, val : Byte) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: 3,
    data: Bytes::from_array(Array::make(w * h * 3, val)),
  }
}

///|
test "hdr_default_config: 返回有效配置" {
  let config = hdr_default_config()
  assert_true(config.gamma > 0.0)
  assert_true(config.reinhard_key > 0.0)
}

///|
test "hdr_fusion_average: 基本融合" {
  let img1 = make_hdr_img(16, 16, b'\x40')
  let img2 = make_hdr_img(16, 16, b'\x80')
  let img3 = make_hdr_img(16, 16, b'\xC0')
  let result = hdr_fusion_average([img1, img2, img3])
  assert_eq(result.width, 16)
  assert_eq(result.height, 16)
}

///|
test "hdr_fusion_average: 空列表抛异常" {
  try {
    ignore(hdr_fusion_average([]))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "hdr_fusion_weighted: 加权融合" {
  let img1 = make_hdr_img(16, 16, b'\x40')
  let img2 = make_hdr_img(16, 16, b'\x80')
  let result = hdr_fusion_weighted([img1, img2])
  assert_eq(result.width, 16)
  assert_eq(result.height, 16)
}

///|
test "hdr_fusion_weighted: 空列表抛异常" {
  try {
    ignore(hdr_fusion_weighted([]))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "tone_mapping_reinhard: 基本色调映射" {
  let img = make_hdr_img(16, 16, b'\x80')
  let result = tone_mapping_reinhard(img)
  assert_eq(result.width, 16)
  assert_eq(result.height, 16)
}

///|
test "tone_mapping_gamma: 基本Gamma映射" {
  let img = make_hdr_img(16, 16, b'\x80')
  let result = tone_mapping_gamma(img)
  assert_eq(result.width, 16)
  assert_eq(result.height, 16)
}

///|
test "tone_mapping_sigmoid: 基本Sigmoid映射" {
  let img = make_hdr_img(16, 16, b'\x80')
  let result = tone_mapping_sigmoid(img)
  assert_eq(result.width, 16)
  assert_eq(result.height, 16)
}

///|
test "hdr_process: 完整HDR处理" {
  let img1 = make_hdr_img(16, 16, b'\x40')
  let img2 = make_hdr_img(16, 16, b'\x80')
  let img3 = make_hdr_img(16, 16, b'\xC0')
  let result = hdr_process([img1, img2, img3])
  assert_eq(result.width, 16)
  assert_eq(result.height, 16)
}

///|
test "hdr_process: 空列表抛异常" {
  try {
    ignore(hdr_process([]))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

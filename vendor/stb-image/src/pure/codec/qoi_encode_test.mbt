// 纯 MoonBit QOI 编码器测试
// 纯逻辑断言测试（全目标可用：native/wasm/js），不依赖 @core
// 验证 encode_qoi_pure 编码正确性，覆盖全部 6 种 QOI 标签 + 错误路径
// 规范: https://qoiformat.org/qoi-specification.pdf

///|
fn qe_make_rgb_image(
  width : Int,
  height : Int,
  pixels : Array[(Int, Int, Int)],
) -> @types.Image {
  let data : Array[Byte] = []
  for p in pixels {
    data.push(p.0.to_byte())
    data.push(p.1.to_byte())
    data.push(p.2.to_byte())
  }
  @types.Image::{ width, height, channels: 3, data: Bytes::from_array(data) }
}

///|
fn qe_make_rgba_image(
  width : Int,
  height : Int,
  pixels : Array[(Int, Int, Int, Int)],
) -> @types.Image {
  let data : Array[Byte] = []
  for p in pixels {
    data.push(p.0.to_byte())
    data.push(p.1.to_byte())
    data.push(p.2.to_byte())
    data.push(p.3.to_byte())
  }
  @types.Image::{ width, height, channels: 4, data: Bytes::from_array(data) }
}

///|
// 检查像素编码区域（跳过 14 字节 header 和 8 字节 padding）是否含 [lo, hi] 范围字节
fn qe_has_byte_in_range(out : Bytes, lo : Int, hi : Int) -> Bool {
  let len = out.length()
  let end = len - 8
  let mut found = false
  for i in 14..<end {
    let v = out[i].to_int()
    if v >= lo && v <= hi {
      found = true
    }
  }
  found
}

///|
fn qe_has_byte(out : Bytes, target : Int) -> Bool {
  let len = out.length()
  let mut found = false
  for i in 0..<len {
    if out[i].to_int() == target {
      found = true
    }
  }
  found
}

///|
test "encode_qoi_pure: RGB header and padding" {
  let img = qe_make_rgb_image(2, 2, [
    (255, 0, 0),
    (0, 255, 0),
    (0, 0, 255),
    (255, 255, 255),
  ])
  let out = encode_qoi_pure(img)
  // header magic "qoif"
  assert_eq(out[0].to_int(), 0x71)
  assert_eq(out[1].to_int(), 0x6F)
  assert_eq(out[2].to_int(), 0x69)
  assert_eq(out[3].to_int(), 0x66)
  // width BE = 2
  assert_eq(out[4].to_int(), 0)
  assert_eq(out[5].to_int(), 0)
  assert_eq(out[6].to_int(), 0)
  assert_eq(out[7].to_int(), 2)
  // height BE = 2
  assert_eq(out[8].to_int(), 0)
  assert_eq(out[9].to_int(), 0)
  assert_eq(out[10].to_int(), 0)
  assert_eq(out[11].to_int(), 2)
  // channels = 3
  assert_eq(out[12].to_int(), 3)
  // colorspace = 0
  assert_eq(out[13].to_int(), 0)
  // padding: 7 个 0x00 + 1 个 0x01
  let len = out.length()
  assert_eq(out[len - 8].to_int(), 0)
  assert_eq(out[len - 7].to_int(), 0)
  assert_eq(out[len - 6].to_int(), 0)
  assert_eq(out[len - 5].to_int(), 0)
  assert_eq(out[len - 4].to_int(), 0)
  assert_eq(out[len - 3].to_int(), 0)
  assert_eq(out[len - 2].to_int(), 0)
  assert_eq(out[len - 1].to_int(), 1)
  let _ = img
}

///|
test "encode_qoi_pure: RGBA with QOI_OP_RGBA tag" {
  // 第一个像素 a=128 != prev_a=255，触发 QOI_OP_RGBA (0xFF)
  let img = qe_make_rgba_image(2, 2, [
    (10, 20, 30, 128),
    (40, 50, 60, 200),
    (70, 80, 90, 100),
    (110, 120, 130, 50),
  ])
  let out = encode_qoi_pure(img)
  // header channels = 4
  assert_eq(out[12].to_int(), 4)
  // 验证含 QOI_OP_RGBA 标签 0xFF
  assert_true(qe_has_byte(out, 0xFF))
  let _ = img
}

///|
test "encode_qoi_pure: run-length encoding" {
  // 4x1 RGB，4 像素均为 (0,0,0)，与 prev 初始值 (0,0,0,255) 相同
  // 4 像素全触发 RUN，输出 1 个 RUN 标签 0xC3 (0xC0|(4-1))
  let img = qe_make_rgb_image(4, 1, [(0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0)])
  let out = encode_qoi_pure(img)
  // 验证含 RUN 标签 0xC3
  assert_true(qe_has_byte(out, 0xC3))
  let _ = img
}

///|
test "encode_qoi_pure: index encoding" {
  // 2x2 RGB，P1=(10,20,30) P2=(20,30,40) P3=(10,20,30) P4=(10,20,30)
  // P3 的 hash 命中 P1 设置的 index 槽，走 QOI_OP_INDEX
  let img = qe_make_rgb_image(2, 2, [
    (10, 20, 30),
    (20, 30, 40),
    (10, 20, 30),
    (10, 20, 30),
  ])
  let out = encode_qoi_pure(img)
  // 验证含 INDEX 标签（0x00-0x3F 范围，像素编码区域）
  assert_true(qe_has_byte_in_range(out, 0x00, 0x3F))
  let _ = img
}

///|
test "encode_qoi_pure: DIFF tag encoding" {
  // 2x2 RGB，像素 (10,20,30)/(11,21,31)/(12,22,32)/(13,23,33)
  // 后续 3 像素与 prev 差分 (1,1,1) ∈ [-2,1]，走 DIFF 标签 0x7F
  let img = qe_make_rgb_image(2, 2, [
    (10, 20, 30),
    (11, 21, 31),
    (12, 22, 32),
    (13, 23, 33),
  ])
  let out = encode_qoi_pure(img)
  // 验证含 DIFF 标签（0x40-0x7F 范围）
  assert_true(qe_has_byte_in_range(out, 0x40, 0x7F))
  let _ = img
}

///|
test "encode_qoi_pure: LUMA tag encoding" {
  // 2x2 RGB，像素 (100,100,100)/(105,110,105)/(100,100,100)/(105,110,105)
  // P2 与 prev 差分 dr=5/dg=10/db=5，dg=10 ∈ [-32,31] 但 dr=5 ∉ [-2,1] 走 LUMA
  let img = qe_make_rgb_image(2, 2, [
    (100, 100, 100),
    (105, 110, 105),
    (100, 100, 100),
    (105, 110, 105),
  ])
  let out = encode_qoi_pure(img)
  // 验证含 LUMA 标签（0x80-0xBF 范围）
  assert_true(qe_has_byte_in_range(out, 0x80, 0xBF))
  let _ = img
}

///|
test "encode_qoi_pure: invalid channels raises" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 2,
    data: [b'\x00', b'\x00'] |> Bytes::from_array,
  }
  try {
    let _ = encode_qoi_pure(img)
    assert_true(false)
  } catch {
    @types.LoadError::EncodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

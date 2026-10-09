// 纯 MoonBit APNG 编解码测试

///|
fn make_2x2_red_image() -> @types.Image {
  @types.Image::{
    width: 2,
    height: 2,
    channels: 3,
    data: b"\xFF\x00\x00\xFF\x00\x00\xFF\x00\x00\xFF\x00\x00",
  }
}

///|
fn make_2x2_green_image() -> @types.Image {
  @types.Image::{
    width: 2,
    height: 2,
    channels: 3,
    data: b"\x00\xFF\x00\x00\xFF\x00\x00\xFF\x00\x00\xFF\x00",
  }
}

///|
test "encode_apng_pure / decode_apng_pure: 单帧 APNG" {
  let img = make_2x2_red_image()
  let anim = @types.PngAnimation::{ frames: [img], delays: [100] }
  let apng = encode_apng_pure(anim)
  let decoded = decode_apng_pure(apng)
  assert_eq(decoded.frames.length(), 1)
  assert_eq(decoded.delays.length(), 1)
  assert_eq(decoded.delays[0], 100)
  let frame = decoded.frames[0]
  assert_eq(frame.width, 2)
  assert_eq(frame.height, 2)
  assert_eq(frame.channels, 3)
  assert_eq(frame.data[0].to_int(), 255)
  assert_eq(frame.data[1].to_int(), 0)
  assert_eq(frame.data[2].to_int(), 0)
}

///|
test "encode_apng_pure / decode_apng_pure: 双帧 APNG" {
  let img1 = make_2x2_red_image()
  let img2 = make_2x2_green_image()
  let anim = @types.PngAnimation::{ frames: [img1, img2], delays: [100, 200] }
  let apng = encode_apng_pure(anim)
  let decoded = decode_apng_pure(apng)
  assert_eq(decoded.frames.length(), 2)
  assert_eq(decoded.delays.length(), 2)
  assert_eq(decoded.delays[0], 100)
  assert_eq(decoded.delays[1], 200)
  // 第一帧红色
  let f0 = decoded.frames[0]
  assert_eq(f0.data[0].to_int(), 255)
  assert_eq(f0.data[1].to_int(), 0)
  assert_eq(f0.data[2].to_int(), 0)
  // 第二帧绿色
  let f1 = decoded.frames[1]
  assert_eq(f1.data[0].to_int(), 0)
  assert_eq(f1.data[1].to_int(), 255)
  assert_eq(f1.data[2].to_int(), 0)
}

///|
test "decode_apng_pure: 普通 PNG 当作单帧 APNG" {
  let img = make_2x2_red_image()
  let png = encode_png_pure(img)
  let decoded = decode_apng_pure(png)
  assert_eq(decoded.frames.length(), 1)
  assert_eq(decoded.delays.length(), 1)
  assert_eq(decoded.delays[0], 0)
  assert_eq(decoded.frames[0].width, 2)
  assert_eq(decoded.frames[0].height, 2)
}

///|
test "encode_apng_pure: 空帧报错" {
  let anim = @types.PngAnimation::{ frames: [], delays: [] }
  try {
    let _ = encode_apng_pure(anim)
    assert_true(false)
  } catch {
    @types.LoadError::EncodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "encode_apng_pure / decode_apng_pure: 三帧不同颜色" {
  let r = @types.Image::{
    width: 1,
    height: 1,
    channels: 3,
    data: b"\xFF\x00\x00",
  }
  let g = @types.Image::{
    width: 1,
    height: 1,
    channels: 3,
    data: b"\x00\xFF\x00",
  }
  let b = @types.Image::{
    width: 1,
    height: 1,
    channels: 3,
    data: b"\x00\x00\xFF",
  }
  let anim = @types.PngAnimation::{ frames: [r, g, b], delays: [50, 50, 50] }
  let apng = encode_apng_pure(anim)
  let decoded = decode_apng_pure(apng)
  assert_eq(decoded.frames.length(), 3)
  assert_eq(decoded.frames[0].data[0].to_int(), 255)
  assert_eq(decoded.frames[1].data[1].to_int(), 255)
  assert_eq(decoded.frames[2].data[2].to_int(), 255)
}

///|
test "decode_apng_pure: too short raises" {
  try {
    let _ = decode_apng_pure(b"\x89PNG\r\n\x1A\n\x00\x00\x00\x00")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_apng_pure: no IHDR raises" {
  // PNG signature + acTL but no IHDR
  let sig : Array[Byte] = [
    b'\x89', b'P', b'N', b'G', b'\r', b'\n', b'\x1A', b'\n',
  ]
  // acTL chunk: type=0x61\x63\x54\x4C, length=8, data=0x00\x00\x00\x01\x00\x00\x00\x01
  let actl : Array[Byte] = [
    0x00, 0x00, 0x00, 0x08, // length=8
     b'a', b'c', b'T', b'L', // type
     0x00, 0x00, 0x00, 0x01, // num_frames=1
     0x00, 0x00, 0x00, 0x01, // num_plays=1
     0xA1, 0xB2, 0xC3, 0xD4, // crc
  ]
  let data : Array[Byte] = []
  for b in sig {
    data.push(b)
  }
  for b in actl {
    data.push(b)
  }
  try {
    let _ = decode_apng_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

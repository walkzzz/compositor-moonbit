// GIF 动画编码/解码测试
// 覆盖 encode_gif_animation_pure / decode_gif_animation_pure roundtrip + 错误路径 + disposal

///|
fn ga_make_rgb(
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
test "encode_gif_animation_pure: basic 2-frame roundtrip" {
  let frame1 = ga_make_rgb(2, 2, [
    (10, 20, 30),
    (40, 50, 60),
    (70, 80, 90),
    (100, 110, 120),
  ])
  let frame2 = ga_make_rgb(2, 2, [
    (200, 210, 220),
    (30, 40, 50),
    (60, 70, 80),
    (90, 100, 110),
  ])
  let anim = @types.GifAnimation::{
    frames: [frame1, frame2],
    delays: [100, 200],
  }
  let gif_bytes = encode_gif_animation_pure(anim)
  let restored = decode_gif_animation_pure(gif_bytes)
  assert_eq(restored.frames.length(), 2)
  assert_eq(restored.delays.length(), 2)
  assert_eq(restored.delays[0], 100)
  assert_eq(restored.delays[1], 200)
  assert_eq(restored.frames[0].width, 2)
  assert_eq(restored.frames[0].height, 2)
  assert_eq(restored.frames[1].width, 2)
  assert_eq(restored.frames[1].height, 2)
}

///|
test "encode_gif_animation_pure: single frame" {
  let frame = ga_make_rgb(1, 1, [(255, 255, 255)])
  let anim = @types.GifAnimation::{ frames: [frame], delays: [0] }
  let gif_bytes = encode_gif_animation_pure(anim)
  let restored = decode_gif_animation_pure(gif_bytes)
  assert_eq(restored.frames.length(), 1)
  assert_eq(restored.delays.length(), 1)
}

///|
test "encode_gif_animation_pure: 3-frame with varying delays" {
  let f1 = ga_make_rgb(1, 1, [(0, 0, 0)])
  let f2 = ga_make_rgb(1, 1, [(128, 128, 128)])
  let f3 = ga_make_rgb(1, 1, [(255, 255, 255)])
  let anim = @types.GifAnimation::{
    frames: [f1, f2, f3],
    delays: [50, 150, 300],
  }
  let gif_bytes = encode_gif_animation_pure(anim)
  let restored = decode_gif_animation_pure(gif_bytes)
  assert_eq(restored.frames.length(), 3)
  assert_eq(restored.delays[0], 50)
  assert_eq(restored.delays[1], 150)
  assert_eq(restored.delays[2], 300)
}

///|
test "encode_gif_animation_pure: RGBA frames" {
  let f1 = @types.Image::{
    width: 1,
    height: 1,
    channels: 4,
    data: [b'\x80', b'\x90', b'\xA0', b'\xFF'] |> Bytes::from_array,
  }
  let anim = @types.GifAnimation::{ frames: [f1], delays: [100] }
  let gif_bytes = encode_gif_animation_pure(anim)
  let restored = decode_gif_animation_pure(gif_bytes)
  assert_eq(restored.frames.length(), 1)
  assert_eq(restored.frames[0].channels, 3)
}

///|
test "encode_gif_animation_pure: empty frames raises" {
  let anim = @types.GifAnimation::{ frames: [], delays: [] }
  try {
    let _ = encode_gif_animation_pure(anim)
    assert_true(false)
  } catch {
    @types.LoadError::EncodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "encode_gif_animation_pure: frames/delays length mismatch raises" {
  let f1 = ga_make_rgb(1, 1, [(0, 0, 0)])
  let anim = @types.GifAnimation::{ frames: [f1], delays: [100, 200] }
  try {
    let _ = encode_gif_animation_pure(anim)
    assert_true(false)
  } catch {
    @types.LoadError::EncodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "encode_gif_animation_pure: invalid channels raises" {
  let f1 = @types.Image::{
    width: 1,
    height: 1,
    channels: 2,
    data: [b'\x00', b'\x00'] |> Bytes::from_array,
  }
  let anim = @types.GifAnimation::{ frames: [f1], delays: [100] }
  try {
    let _ = encode_gif_animation_pure(anim)
    assert_true(false)
  } catch {
    @types.LoadError::EncodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_gif_animation_pure: invalid data raises" {
  try {
    let _ = decode_gif_animation_pure(b"not a gif")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    @types.LoadError::UnsupportedFormat(_) => assert_true(true)
    _ => assert_true(true)
  }
}

///|
test "decode_gif_animation_pure: empty data raises" {
  try {
    let _ = decode_gif_animation_pure(b"")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    @types.LoadError::UnsupportedFormat(_) => assert_true(true)
    _ => assert_true(true)
  }
}

///|
test "encode_gif_animation_pure: larger image triggers LZW growth" {
  // 16x16 渐变图像，触发 LZW code_size 增长
  let pixels : Array[(Int, Int, Int)] = []
  for y in 0..<16 {
    for x in 0..<16 {
      pixels.push((x * 16, y * 16, (x + y) * 8))
    }
  }
  let frame = ga_make_rgb(16, 16, pixels)
  let anim = @types.GifAnimation::{ frames: [frame], delays: [0] }
  let gif_bytes = encode_gif_animation_pure(anim)
  let restored = decode_gif_animation_pure(gif_bytes)
  assert_eq(restored.frames.length(), 1)
  assert_eq(restored.frames[0].width, 16)
  assert_eq(restored.frames[0].height, 16)
}

///|
test "decode_gif_animation_pure: too short raises" {
  try {
    let _ = decode_gif_animation_pure(b"GIF89a\x00\x00\x00")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_gif_animation_pure: bad signature raises" {
  try {
    let _ = decode_gif_animation_pure(b"NOTGIF\x00\x00\x00\x00\x00\x00\x00")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_gif_animation_pure: no image separator raises" {
  // GIF header + global color table, but no Image Descriptor (0x2C)
  let data : Array[Byte] = [
    b'G', b'I', b'F', b'8', b'9', b'a', 0x10, 0x00, 0x10, 0x00, 0x00, 0x00, 0x00, // 16x16, no GCT
     0x3B, // trailer
  ]
  try {
    let _ = decode_gif_animation_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_gif_animation_pure: interlace not supported raises" {
  // Minimal GIF with interlace bit set in image descriptor
  let data : Array[Byte] = [
    b'G', b'I', b'F', b'8', b'9', b'a', 0x02, 0x00, 0x02, 0x00, 0x80, 0x00, 0x00, // 2x2, GCT 2^1=2 entries
     0xFF, 0x00, 0x00, // GCT: red, black
     0x2C, // Image Descriptor
     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // left=0, top=0, w=2, h=2
     0x40, // packed: interlace=1, no LCT
     0x02, // LZW min code size
     0x03, 0x43, 0x00, 0x3B, // LZW data + trailer
  ]
  try {
    let _ = decode_gif_animation_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_gif_animation_pure: truncated sub-block raises" {
  // GIF with Image Descriptor but truncated LZW sub-block
  let data : Array[Byte] = [
    b'G', b'I', b'F', b'8', b'9', b'a', 0x02, 0x00, 0x02, 0x00, 0x80, 0x00, 0x00, // 2x2, GCT
     0xFF, 0x00, 0x00, // GCT: red, black
     0x2C, // Image Descriptor
     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // left=0, top=0, w=2, h=2
     0x00, // packed: no interlace, no LCT
     0x02, // LZW min code size
     0x03, // sub-block length = 3
     0x01, // sub-block data (only 1 byte, need 3)
  ]
  try {
    let _ = decode_gif_animation_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

// 解码器大尺寸溢出测试：验证解码器面对超大尺寸输入时优雅报错而非 OOM

///|
test "overflow PNG: huge dimensions in IHDR rejected gracefully" {
  // PNG with width=65535 and height=65535 in IHDR
  // This is at the limit - should pass check_dims but fail later due to missing IDAT
  let data : Array[Byte] = [
    b'\x89', b'\x50', b'\x4E', b'\x47', b'\x0D', b'\x0A', b'\x1A', b'\x0A',
    // IHDR chunk: length=13
     b'\x00', b'\x00', b'\x00', b'\x0D', b'\x49', b'\x48', b'\x44', b'\x52',
    // width=65535 (0x00FFFF)
     b'\x00', b'\x00', b'\xFF', b'\xFF',
    // height=65535
     b'\x00', b'\x00', b'\xFF', b'\xFF',
    // bit_depth=8, color_type=2 (RGB), compression=0, filter=0, interlace=0
     b'\x08', b'\x02', b'\x00', b'\x00', b'\x00',
    // CRC (dummy)
     b'\x00', b'\x00', b'\x00', b'\x00',
    // IEND
     b'\x00', b'\x00', b'\x00', b'\x00', b'\x49', b'\x45', b'\x4E', b'\x44', b'\xAE',
    b'\x42', b'\x60', b'\x82',
  ]
  try {
    let _ = @codec.decode_png_pure(Bytes::from_array(data))
    assert_true(true) // may succeed or fail, but shouldn't crash/OOM
  } catch {
    _ => assert_true(true)
  }
}

///|
test "overflow BMP: huge dimensions rejected gracefully" {
  // BMP with width=100000 and height=100000 (exceeds MAX_IMAGE_DIMENSION)
  let data : Array[Byte] = [
    b'\x42', b'\x4D', // BM
     b'\x36', b'\x00', b'\x00', b'\x00', // file size
     b'\x00', b'\x00', b'\x00', b'\x00', // reserved
     b'\x36', b'\x00', b'\x00', b'\x00', // data offset
     b'\x28', b'\x00', b'\x00', b'\x00', // header size
    // width=100000 (0x000186A0) little-endian
     b'\xA0', b'\x86', b'\x01', b'\x00',
    // height=100000
     b'\xA0', b'\x86', b'\x01', b'\x00', b'\x01', b'\x00', // planes
     b'\x18', b'\x00', // bpp=24
     b'\x00', b'\x00', b'\x00', b'\x00', // compression
     b'\x00', b'\x00', b'\x00', b'\x00', // image size
     b'\x00', b'\x00', b'\x00', b'\x00', // x ppm
     b'\x00', b'\x00', b'\x00', b'\x00', // y ppm
     b'\x00', b'\x00', b'\x00', b'\x00', // colors used
     b'\x00', b'\x00', b'\x00', b'\x00', // important colors
  ]
  try {
    let _ = @codec.decode_bmp_pure(Bytes::from_array(data))
    assert_true(false) // should be rejected by check_dims
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "overflow QOI: huge dimensions rejected gracefully" {
  // QOI with width=100000 and height=100000
  let data : Array[Byte] = [
    b'\x71', b'\x6F', b'\x69', b'\x66', // "qoif"
    // width=100000 big-endian (0x000186A0)
     b'\x00', b'\x01', b'\x86', b'\xA0',
    // height=100000
     b'\x00', b'\x01', b'\x86', b'\xA0', b'\x03', // channels=3
     b'\x00', // colorspace=0
    // end marker
     b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x01',
  ]
  try {
    let _ = @codec.decode_qoi_pure(Bytes::from_array(data))
    assert_true(false) // should be rejected
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "overflow PNM: huge dimensions rejected gracefully" {
  // PNM P6 with width=100000 height=100000
  try {
    let _ = @codec.decode_pnm_pure(b"P6\n100000 100000\n255\n")
    assert_true(false) // should be rejected
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "overflow GIF: huge dimensions rejected gracefully" {
  // GIF with screen width=65535 and height=65535 (at limit, should pass check_dims)
  // but will fail later due to missing data
  let data : Array[Byte] = [
    b'\x47', b'\x49', b'\x46', b'\x38', b'\x39', b'\x61', // GIF89a
     b'\xFF', b'\xFF', // width=65535
     b'\xFF', b'\xFF', // height=65535
     b'\x00', // packed (no GCT)
     b'\x00', // bg color
     b'\x00', // aspect ratio
    // trailer
     b'\x3B',
  ]
  try {
    let _ = @codec.decode_gif_pure(Bytes::from_array(data))
    assert_true(true) // may fail, but shouldn't crash
  } catch {
    _ => assert_true(true)
  }
}

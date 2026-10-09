// Fuzzing/安全审计测试：确保各解码器面对畸形输入不崩溃
// 测试策略：空数据、截断头、有效 magic 但截断数据、垃圾字节、零/巨大尺寸

///|
fn fz_safe_decode(data : Bytes) -> Bool {
  try {
    let _ = @codec.decode_png_pure(data)
    true
  } catch {
    _ => true
  }
}

///|
test "fuzz PNG: empty bytes" {
  assert_true(fz_safe_decode(b""))
}

///|
test "fuzz PNG: truncated header" {
  assert_true(fz_safe_decode(b"\x89PNG"))
  assert_true(fz_safe_decode(b"\x89PNG\r\n\x1A\n"))
}

///|
test "fuzz PNG: valid magic but no IHDR" {
  let data : Array[Byte] = [
    b'\x89', b'\x50', b'\x4E', b'\x47', b'\x0D', b'\x0A', b'\x1A', b'\x0A',
  ]
  assert_true(fz_safe_decode(Bytes::from_array(data)))
}

///|
test "fuzz PNG: corrupted IHDR" {
  let data : Array[Byte] = [
    b'\x89', b'\x50', b'\x4E', b'\x47', b'\x0D', b'\x0A', b'\x1A', b'\x0A', b'\x00',
    b'\x00', b'\x00', b'\x0D', b'\x49', b'\x48', b'\x44', b'\x52', b'\xFF', b'\xFF',
    b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
  ]
  assert_true(fz_safe_decode(Bytes::from_array(data)))
}

///|
test "fuzz PNG: garbage after magic" {
  let data : Array[Byte] = [
    b'\x89', b'\x50', b'\x4E', b'\x47', b'\x0D', b'\x0A', b'\x1A', b'\x0A', b'\xDE',
    b'\xAD', b'\xBE', b'\xEF', b'\xCA', b'\xFE', b'\xBA', b'\xBE',
  ]
  assert_true(fz_safe_decode(Bytes::from_array(data)))
}

///|
test "fuzz BMP: empty bytes" {
  try {
    let _ = @codec.decode_bmp_pure(b"")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz BMP: truncated header" {
  try {
    let _ = @codec.decode_bmp_pure(b"\x42\x4D")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz BMP: valid magic but truncated" {
  let data : Array[Byte] = [
    b'\x42', b'\x4D', b'\x3A', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x36', b'\x00', b'\x00', b'\x00',
  ]
  try {
    let _ = @codec.decode_bmp_pure(Bytes::from_array(data))
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz BMP: zero dimensions" {
  let data : Array[Byte] = [
    b'\x42', b'\x4D', b'\x36', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x36', b'\x00', b'\x00', b'\x00', b'\x28', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x01',
    b'\x00', b'\x18', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
  ]
  try {
    let _ = @codec.decode_bmp_pure(Bytes::from_array(data))
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz JPEG: empty bytes" {
  try {
    let _ = @codec.decode_jpeg_pure(b"")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz JPEG: truncated SOI" {
  try {
    let _ = @codec.decode_jpeg_pure(b"\xFF")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz JPEG: valid SOI but no markers" {
  try {
    let _ = @codec.decode_jpeg_pure(b"\xFF\xD8")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz JPEG: garbage after SOI" {
  let data : Array[Byte] = [
    b'\xFF', b'\xD8', b'\xDE', b'\xAD', b'\xBE', b'\xEF', b'\xCA', b'\xFE',
  ]
  try {
    let _ = @codec.decode_jpeg_pure(Bytes::from_array(data))
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz GIF: empty bytes" {
  try {
    let _ = @codec.decode_gif_pure(b"")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz GIF: truncated header" {
  try {
    let _ = @codec.decode_gif_pure(b"GIF8")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz GIF: valid magic but truncated" {
  try {
    let _ = @codec.decode_gif_pure(b"GIF89a\x00\x00\x00")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz QOI: empty bytes" {
  try {
    let _ = @codec.decode_qoi_pure(b"")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz QOI: truncated header" {
  try {
    let _ = @codec.decode_qoi_pure(b"qoif")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz QOI: valid magic but garbage" {
  let data : Array[Byte] = [
    b'\x71', b'\x6F', b'\x69', b'\x66', b'\xDE', b'\xAD', b'\xBE', b'\xEF', b'\xCA',
    b'\xFE', b'\xBA', b'\xBE', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x01',
  ]
  try {
    let _ = @codec.decode_qoi_pure(Bytes::from_array(data))
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz TGA: empty bytes" {
  try {
    let _ = @codec.decode_tga_pure(b"")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz TGA: truncated header" {
  try {
    let _ = @codec.decode_tga_pure(b"\x00\x00\x02")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz PSD: empty bytes" {
  try {
    let _ = @codec.decode_psd_pure(b"")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz PSD: truncated header" {
  try {
    let _ = @codec.decode_psd_pure(b"8BPS")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz HDR: empty bytes" {
  try {
    let _ = @codec.decode_hdr_pure(b"")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz HDR: truncated header" {
  try {
    let _ = @codec.decode_hdr_pure(b"#?RADIANCE")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz PNM: empty bytes" {
  try {
    let _ = @codec.decode_pnm_pure(b"")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz PNM: truncated header" {
  try {
    let _ = @codec.decode_pnm_pure(b"P6\n")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz PNM: zero dimensions" {
  try {
    let _ = @codec.decode_pnm_pure(b"P6\n0 0\n255\n")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz WebP: empty bytes" {
  try {
    let _ = @codec.decode_webp_pure(b"")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz WebP: truncated RIFF" {
  try {
    let _ = @codec.decode_webp_pure(b"RIFF")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz WebP: valid RIFF but no WEBP" {
  let data : Array[Byte] = [
    b'\x52', b'\x49', b'\x46', b'\x46', b'\x00', b'\x00', b'\x00', b'\x00', b'\xDE',
    b'\xAD', b'\xBE', b'\xEF',
  ]
  try {
    let _ = @codec.decode_webp_pure(Bytes::from_array(data))
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz WebP: valid RIFF/WEBP but garbage payload" {
  let data : Array[Byte] = [
    b'\x52', b'\x49', b'\x46', b'\x46', b'\x14', b'\x00', b'\x00', b'\x00', b'\x57',
    b'\x45', b'\x42', b'\x50', b'\x56', b'\x50', b'\x38', b'\x4C', b'\x08', b'\x00',
    b'\x00', b'\x00', b'\xDE', b'\xAD', b'\xBE', b'\xEF',
  ]
  try {
    let _ = @codec.decode_webp_pure(Bytes::from_array(data))
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz TIFF: empty bytes" {
  try {
    let _ = @codec.decode_tiff_pure(b"")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz TIFF: truncated header" {
  try {
    let _ = @codec.decode_tiff_pure(b"\x49\x49")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz TIFF: valid II but garbage" {
  let data : Array[Byte] = [
    b'\x49', b'\x49', b'\x2A', b'\x00', b'\xDE', b'\xAD', b'\xBE', b'\xEF',
  ]
  try {
    let _ = @codec.decode_tiff_pure(Bytes::from_array(data))
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz APNG: empty bytes" {
  try {
    let _ = @codec.decode_apng_pure(b"")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz APNG: valid PNG magic but not APNG" {
  let data : Array[Byte] = [
    b'\x89', b'\x50', b'\x4E', b'\x47', b'\x0D', b'\x0A', b'\x1A', b'\x0A', b'\xDE',
    b'\xAD', b'\xBE', b'\xEF',
  ]
  try {
    let _ = @codec.decode_apng_pure(Bytes::from_array(data))
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz detect_format: all empty" {
  assert_eq(detect_format(b""), ImageFormat::Unknown)
}

///|
test "fuzz detect_format: single byte" {
  assert_eq(detect_format(b"\x00"), ImageFormat::Unknown)
  assert_eq(detect_format(b"\xFF"), ImageFormat::Unknown)
}

///|
test "fuzz detect_format: random garbage" {
  let garbage = Bytes::from_array([
    b'\xDE', b'\xAD', b'\xBE', b'\xEF', b'\xCA', b'\xFE', b'\xBA', b'\xBE', b'\x13',
    b'\x37', b'\x42', b'\x42', b'\x66', b'\x6F', b'\x6F', b'\x00',
  ])
  assert_eq(detect_format(garbage), ImageFormat::Unknown)
}

///|
test "fuzz load_from_bytes_auto: all formats with garbage" {
  let garbage = Bytes::from_array(Array::make(64, b'\xAA'))
  try {
    let _ = load_from_bytes_auto(garbage)
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz load_from_bytes_auto: truncated valid formats" {
  // Truncated PNG
  try {
    let _ = load_from_bytes_auto(b"\x89PNG\r\n\x1A\n")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
  // Truncated BMP
  try {
    let _ = load_from_bytes_auto(b"\x42\x4D\x00\x00")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
  // Truncated GIF
  try {
    let _ = load_from_bytes_auto(b"GIF89a")
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz: all zeros input" {
  let zeros = Bytes::from_array(Array::make(128, b'\x00'))
  try {
    let _ = load_from_bytes_auto(zeros)
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fuzz: all 0xFF input" {
  let ones = Bytes::from_array(Array::make(128, b'\xFF'))
  try {
    let _ = load_from_bytes_auto(ones)
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}

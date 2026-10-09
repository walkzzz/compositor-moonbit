// 纯 MoonBit GIF 解码器测试
// 纯逻辑断言测试（全目标可用：native/wasm/js），不依赖 @core
// 手构造 GIF 字节流验证解码正确性，覆盖正例 + 错误路径
// 规范: GIF89a Specification + src/format/gif_encode.mbt

///|
/// LZW 编码辅助（用于测试，与 gif_encode.mbt 逻辑一致）
fn lzw_encode_for_test(
  indices : Array[Int],
  min_code_size : Int,
) -> Array[Byte] {
  let clear_code = 1 << min_code_size
  let end_code = clear_code + 1
  let code_width = Ref(min_code_size + 1)
  let max_code = Ref((1 << code_width.val) - 1)
  let code_table : Array[(Int, Int)] = []
  for i in 0..<clear_code {
    code_table.push((-1, i))
  }
  code_table.push((-1, -1))
  code_table.push((-1, -1))
  let next_code = Ref(clear_code + 2)
  let bit_buffer = Ref(0)
  let bit_count = Ref(0)
  let output : Array[Byte] = []
  fn emit(code : Int) -> Unit {
    bit_buffer.val = bit_buffer.val | (code << bit_count.val)
    bit_count.val += code_width.val
    while bit_count.val >= 8 {
      output.push((bit_buffer.val & 0xFF).to_byte())
      bit_buffer.val = bit_buffer.val >> 8
      bit_count.val -= 8
    }
  }
  emit(clear_code)
  if indices.length() > 0 {
    let prefix = Ref(indices[0])
    for i in 1..<indices.length() {
      let pixel = indices[i]
      let found = Ref(-1)
      for j in 0..<code_table.length() {
        let (p, v) = code_table[j]
        if p == prefix.val && v == pixel {
          found.val = j
          break
        }
      }
      if found.val >= 0 {
        prefix.val = found.val
      } else {
        emit(prefix.val)
        if next_code.val < 4096 {
          code_table.push((prefix.val, pixel))
          if next_code.val > max_code.val && code_width.val < 12 {
            code_width.val += 1
            max_code.val = (1 << code_width.val) - 1
          }
          next_code.val += 1
        }
        prefix.val = pixel
      }
    }
    emit(prefix.val)
  }
  emit(end_code)
  if bit_count.val > 0 {
    output.push((bit_buffer.val & 0xFF).to_byte())
  }
  output
}

///|
/// 构造 GIF header + LSD + GCT
fn make_gif_header_gct(
  width : Int,
  height : Int,
  gct_entries : Array[(Int, Int, Int)],
) -> Array[Byte] {
  let out : Array[Byte] = []
  // GIF89a header
  out.push(b'\x47')
  out.push(b'\x49')
  out.push(b'\x46')
  out.push(b'\x38')
  out.push(b'\x39')
  out.push(b'\x61')
  // LSD
  out.push((width & 0xFF).to_byte())
  out.push(((width >> 8) & 0xFF).to_byte())
  out.push((height & 0xFF).to_byte())
  out.push(((height >> 8) & 0xFF).to_byte())
  // packed: GCT flag=1, size = log2(entries) - 1
  let n = gct_entries.length()
  let mut size_bits = 0
  let mut m = n
  while m > 1 {
    m = m >> 1
    size_bits += 1
  }
  size_bits -= 1
  out.push((0x80 | (size_bits & 0x07)).to_byte())
  out.push(b'\x00')
  out.push(b'\x00')
  // GCT
  for i in 0..<gct_entries.length() {
    let (r, g, b) = gct_entries[i]
    out.push(r.to_byte())
    out.push(g.to_byte())
    out.push(b.to_byte())
  }
  out
}

///|
/// 追加 Image Descriptor + LZW data + Trailer
fn append_gif_image(
  out : Array[Byte],
  width : Int,
  height : Int,
  indices : Array[Int],
  min_code_size : Int,
  img_packed : Int,
  lct_entries : Array[(Int, Int, Int)],
) -> Unit {
  out.push(b'\x2C')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push((width & 0xFF).to_byte())
  out.push(((width >> 8) & 0xFF).to_byte())
  out.push((height & 0xFF).to_byte())
  out.push(((height >> 8) & 0xFF).to_byte())
  out.push(img_packed.to_byte())
  // Local Color Table
  if (img_packed & 0x80) != 0 {
    for i in 0..<lct_entries.length() {
      let (r, g, b) = lct_entries[i]
      out.push(r.to_byte())
      out.push(g.to_byte())
      out.push(b.to_byte())
    }
  }
  // LZW data
  out.push(min_code_size.to_byte())
  let lzw = lzw_encode_for_test(indices, min_code_size)
  out.push(lzw.length().to_byte())
  for b in lzw {
    out.push(b)
  }
  out.push(b'\x00')
  // Trailer
  out.push(b'\x3B')
}

///|
test "decode_gif_pure: 1x1 single color" {
  let out = make_gif_header_gct(1, 1, [(0xFF, 0x00, 0x00), (0x00, 0x00, 0x00)])
  append_gif_image(out, 1, 1, [0], 2, 0, [])
  let img = decode_gif_pure(to_bytes(out))
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 3)
  assert_eq(img.data[0].to_int(), 0xFF)
  assert_eq(img.data[1].to_int(), 0x00)
  assert_eq(img.data[2].to_int(), 0x00)
}

///|
test "decode_gif_pure: 2x2 multi color" {
  let out = make_gif_header_gct(2, 2, [
    (0xFF, 0x00, 0x00),
    (0x00, 0xFF, 0x00),
    (0x00, 0x00, 0xFF),
    (0xFF, 0xFF, 0xFF),
  ])
  append_gif_image(out, 2, 2, [0, 1, 2, 3], 2, 0, [])
  let img = decode_gif_pure(to_bytes(out))
  assert_eq(img.width, 2)
  assert_eq(img.height, 2)
  assert_eq(img.channels, 3)
  let expected = [
    0xFF, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF,
  ]
  for i in 0..<12 {
    assert_eq(img.data[i].to_int(), expected[i])
  }
}

///|
test "decode_gif_pure: with Graphic Control Extension" {
  let out = make_gif_header_gct(1, 1, [(0xFF, 0x00, 0x00), (0x00, 0x00, 0x00)])
  // Graphic Control Extension
  out.push(b'\x21')
  out.push(b'\xF9')
  out.push(b'\x04')
  out.push(b'\x00')
  out.push(b'\x0A')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  append_gif_image(out, 1, 1, [0], 2, 0, [])
  let img = decode_gif_pure(to_bytes(out))
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 3)
  assert_eq(img.data[0].to_int(), 0xFF)
}

///|
test "decode_gif_pure: with Local Color Table" {
  let out = make_gif_header_gct(2, 2, [(0xFF, 0x00, 0x00), (0x00, 0x00, 0x00)])
  // Image Descriptor with LCT: packed=0x81 (LCT flag=1, size=1 → 4 entries)
  append_gif_image(out, 2, 2, [0, 1, 2, 3], 2, 0x81, [
    (0x00, 0xFF, 0x00),
    (0xFF, 0xFF, 0x00),
    (0x00, 0xFF, 0xFF),
    (0xFF, 0x00, 0xFF),
  ])
  let img = decode_gif_pure(to_bytes(out))
  assert_eq(img.width, 2)
  assert_eq(img.height, 2)
  assert_eq(img.channels, 3)
  // LCT 优先：[0,1,2,3] → [green, yellow, cyan, magenta]
  let expected = [
    0x00, 0xFF, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0x00, 0xFF,
  ]
  for i in 0..<12 {
    assert_eq(img.data[i].to_int(), expected[i])
  }
}

///|
test "decode_gif_pure: with Plain Text Extension" {
  let out = make_gif_header_gct(1, 1, [(0xFF, 0x00, 0x00), (0x00, 0x00, 0x00)])
  // Plain Text Extension (0x01)
  out.push(b'\x21')
  out.push(b'\x01')
  // 8 字节固定 header
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x08')
  out.push(b'\x08')
  // 子块数据
  out.push(b'\x01')
  out.push(b'\x41')
  out.push(b'\x00')
  append_gif_image(out, 1, 1, [0], 2, 0, [])
  let img = decode_gif_pure(to_bytes(out))
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 3)
  assert_eq(img.data[0].to_int(), 0xFF)
}

///|
test "decode_gif_pure: too short raises" {
  let short = b"\x47\x49\x46\x38\x39\x61"
  try {
    let _ = decode_gif_pure(short)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_gif_pure: bad signature raises" {
  let out : Array[Byte] = []
  out.push(b'\x50')
  out.push(b'\x4E')
  out.push(b'\x47')
  out.push(b'\x38')
  out.push(b'\x39')
  out.push(b'\x61')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  try {
    let _ = decode_gif_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_gif_pure: no image separator raises" {
  let out = make_gif_header_gct(1, 1, [(0xFF, 0x00, 0x00), (0x00, 0x00, 0x00)])
  out.push(b'\x3B')
  try {
    let _ = decode_gif_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_gif_pure: invalid lzw min code size raises" {
  let out = make_gif_header_gct(1, 1, [(0xFF, 0x00, 0x00), (0x00, 0x00, 0x00)])
  out.push(b'\x2C')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x3B')
  try {
    let _ = decode_gif_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_gif_pure: lzw code out of range raises" {
  let out = make_gif_header_gct(1, 1, [(0xFF, 0x00, 0x00), (0x00, 0x00, 0x00)])
  out.push(b'\x2C')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x02')
  // LZW data: clear(4)=100 + invalid code(7)=111 → byte 0x3C
  out.push(b'\x01')
  out.push(b'\x3C')
  out.push(b'\x00')
  out.push(b'\x3B')
  try {
    let _ = decode_gif_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_gif_pure: sub-block length out of range raises" {
  let out = make_gif_header_gct(1, 1, [(0xFF, 0x00, 0x00), (0x00, 0x00, 0x00)])
  out.push(b'\x2C')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x02')
  out.push(b'\x0A')
  out.push(b'\x00')
  out.push(b'\x3B')
  try {
    let _ = decode_gif_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_gif_pure: color table index out of range raises" {
  let out = make_gif_header_gct(1, 1, [(0xFF, 0x00, 0x00), (0x00, 0x00, 0x00)])
  out.push(b'\x2C')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x02')
  // LZW data: clear(4)=100 + index 2=010 + end(5)=101 → byte 0x14, 0x01
  out.push(b'\x02')
  out.push(b'\x14')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x3B')
  try {
    let _ = decode_gif_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_gif_pure: interlace not supported raises" {
  let out = make_gif_header_gct(1, 1, [(0xFF, 0x00, 0x00), (0x00, 0x00, 0x00)])
  out.push(b'\x2C')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x40')
  out.push(b'\x3B')
  try {
    let _ = decode_gif_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_gif_pure: truncated LZW data raises" {
  let out = make_gif_header_gct(1, 1, [(0xFF, 0x00, 0x00), (0x00, 0x00, 0x00)])
  out.push(b'\x2C')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x02')
  // Truncated: says 2 bytes but only 1 follows
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x3B')
  try {
    let _ = decode_gif_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

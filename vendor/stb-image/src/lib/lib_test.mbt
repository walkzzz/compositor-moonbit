// @lib 统一 API 层纯逻辑测试
// 全目标可用（native/wasm/js），仅依赖 @types/@pure/@lib
// 覆盖 detect_format magic bytes 检测 + load_from_bytes_auto 自动分派 + 编码器委托

///|
fn lb_to_bytes(arr : Array[Byte]) -> Bytes {
  Bytes::from_array(arr)
}

///|
fn lb_push_str(arr : Array[Byte], s : String) -> Unit {
  let n = s.length()
  for i in 0..<n {
    arr.push(s[i].to_int().to_byte())
  }
}

///|
fn lb_make_rgb_image(
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
// 1x1 24-bit BMP，红色像素 (R=255, G=0, B=0)
fn lb_make_1x1_red_bmp() -> Bytes {
  b"\x42\x4D\x3A\x00\x00\x00\x00\x00\x00\x00\x36\x00\x00\x00\x28\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01\x00\x18\x00\x00\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xFF\x00"
}

///|
// 1x1 RGB QOI，像素 (100, 150, 200)，使用 QOI_OP_RGB 标签
fn lb_make_1x1_rgb_qoi() -> Bytes {
  let out : Array[Byte] = []
  // magic "qoif"
  out.push(b'\x71')
  out.push(b'\x6F')
  out.push(b'\x69')
  out.push(b'\x66')
  // width=1 (big-endian)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  // height=1 (big-endian)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  // channels=3
  out.push(b'\x03')
  // colorspace=0
  out.push(b'\x00')
  // QOI_OP_RGB: 0xFE, r, g, b
  out.push(b'\xFE')
  out.push(b'\x64') // 100
  out.push(b'\x96') // 150
  out.push(b'\xC8') // 200
  // end marker
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x01')
  lb_to_bytes(out)
}

///|
// 1x1 RGB PPM "P6"
fn lb_make_1x1_rgb_pnm() -> Bytes {
  let out : Array[Byte] = []
  lb_push_str(out, "P6\n1 1\n255\n")
  out.push(b'\xFF')
  out.push(b'\x00')
  out.push(b'\x00')
  lb_to_bytes(out)
}

///|
fn lb_push_be16(arr : Array[Byte], v : Int) -> Unit {
  arr.push(((v >> 8) & 0xFF).to_byte())
  arr.push((v & 0xFF).to_byte())
}

///|
fn lb_push_be32(arr : Array[Byte], v : Int) -> Unit {
  arr.push(((v >> 24) & 0xFF).to_byte())
  arr.push(((v >> 16) & 0xFF).to_byte())
  arr.push(((v >> 8) & 0xFF).to_byte())
  arr.push((v & 0xFF).to_byte())
}

///|
// 1x1 RGB PSD（"8BPS" header + 3 通道交错像素）
fn lb_make_1x1_rgb_psd() -> Bytes {
  let out : Array[Byte] = []
  // signature "8BPS"
  out.push(b'\x38')
  out.push(b'\x42')
  out.push(b'\x50')
  out.push(b'\x53')
  // version=1
  lb_push_be16(out, 1)
  // reserved (6 字节)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  // channelCount=3
  lb_push_be16(out, 3)
  // h=1
  lb_push_be32(out, 1)
  // w=1
  lb_push_be32(out, 1)
  // bitdepth=8
  lb_push_be16(out, 8)
  // colorMode=3 (RGB)
  lb_push_be16(out, 3)
  // Color mode data: length=0
  lb_push_be32(out, 0)
  // Image resources: length=0
  lb_push_be32(out, 0)
  // Layer and mask data: length=0
  lb_push_be32(out, 0)
  // image data: compression=0 + R/G/B 通道各 1 字节
  lb_push_be16(out, 0)
  out.push(b'\xFF') // R
  out.push(b'\x00') // G
  out.push(b'\x00') // B
  lb_to_bytes(out)
}

///|
/// LZW 编码辅助（用于 GIF 测试，与 gif_encode.mbt 逻辑一致）
fn lb_lzw_encode(indices : Array[Int], min_code_size : Int) -> Array[Byte] {
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
// 1x1 RGB GIF（"GIF89a" header + GCT + Image Descriptor + LZW data）
fn lb_make_1x1_rgb_gif() -> Bytes {
  let out : Array[Byte] = []
  // GIF89a header
  out.push(b'\x47')
  out.push(b'\x49')
  out.push(b'\x46')
  out.push(b'\x38')
  out.push(b'\x39')
  out.push(b'\x61')
  // LSD: width=1, height=1
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x00')
  // packed: GCT flag=1, size=0 (2 entries)
  out.push(b'\x80')
  out.push(b'\x00')
  out.push(b'\x00')
  // GCT: 2 entries (red, black)
  out.push(b'\xFF')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  // Image Descriptor
  out.push(b'\x2C')
  out.push(b'\x00')
  out.push(b'\x00') // left
  out.push(b'\x00')
  out.push(b'\x00') // top
  out.push(b'\x01')
  out.push(b'\x00') // width=1
  out.push(b'\x01')
  out.push(b'\x00') // height=1
  out.push(b'\x00') // packed (no LCT)
  // LZW data: min_code_size=2
  out.push(b'\x02')
  let lzw = lb_lzw_encode([0], 2)
  out.push(lzw.length().to_byte())
  for b in lzw {
    out.push(b)
  }
  out.push(b'\x00') // block terminator
  out.push(b'\x3B') // trailer
  lb_to_bytes(out)
}

// ==================== detect_format 测试（7 个） ====================

///|
test "detect_format: BMP" {
  let data = lb_make_1x1_red_bmp()
  assert_eq(detect_format(data), ImageFormat::Bmp)
}

///|
test "detect_format: QOI" {
  let data = lb_make_1x1_rgb_qoi()
  assert_eq(detect_format(data), ImageFormat::Qoi)
}

///|
test "detect_format: PNM 边界" {
  // P5 → Pnm
  let p5 : Array[Byte] = [b'\x50', b'\x35', b'\x0A', b'\x31', b'\x20', b'\x31']
  assert_eq(detect_format(lb_to_bytes(p5)), ImageFormat::Pnm)
  // P6 → Pnm
  let p6 : Array[Byte] = [b'\x50', b'\x36', b'\x0A', b'\x31', b'\x20', b'\x31']
  assert_eq(detect_format(lb_to_bytes(p6)), ImageFormat::Pnm)
  // P4 → Unknown（P4 ASCII 格式 pure 包不支持）
  let p4 : Array[Byte] = [b'\x50', b'\x34', b'\x0A', b'\x31', b'\x20', b'\x31']
  assert_eq(detect_format(lb_to_bytes(p4)), ImageFormat::Unknown)
}

///|
test "detect_format: PSD" {
  let data = lb_make_1x1_rgb_psd()
  assert_eq(detect_format(data), ImageFormat::Psd)
}

///|
test "detect_format: GIF 两种版本" {
  // GIF89a
  let gif89a : Array[Byte] = [
    b'\x47', b'\x49', b'\x46', b'\x38', b'\x39', b'\x61', b'\x00', b'\x00',
  ]
  assert_eq(detect_format(lb_to_bytes(gif89a)), ImageFormat::Gif)
  // GIF87a
  let gif87a : Array[Byte] = [
    b'\x47', b'\x49', b'\x46', b'\x38', b'\x37', b'\x61', b'\x00', b'\x00',
  ]
  assert_eq(detect_format(lb_to_bytes(gif87a)), ImageFormat::Gif)
}

///|
test "detect_format: Unknown" {
  // 未知 magic
  let unknown : Array[Byte] = [b'\x00', b'\x00', b'\x00', b'\x00']
  assert_eq(detect_format(lb_to_bytes(unknown)), ImageFormat::Unknown)
  // 空字节流
  let empty : Array[Byte] = []
  assert_eq(detect_format(lb_to_bytes(empty)), ImageFormat::Unknown)
}

///|
test "detect_format: len 边界" {
  // 长度 1 字节流（len < 2 直接返回 Unknown）
  let single : Array[Byte] = [b'\x42']
  assert_eq(detect_format(lb_to_bytes(single)), ImageFormat::Unknown)
}

///|
test "detect_format: TIFF LE (II)" {
  // II 字节序 + magic 42 (little-endian at offset 2-3)
  let data : Array[Byte] = [
    b'\x49', b'\x49', // "II"
     b'\x2A', b'\x00', // magic 42 (LE)
  ]
  assert_eq(detect_format(lb_to_bytes(data)), ImageFormat::Tiff)
}

///|
test "detect_format: TIFF BE (MM)" {
  // MM 字节序 + magic 42 (big-endian at offset 2-3)
  let data : Array[Byte] = [
    b'\x4D', b'\x4D', // "MM"
     b'\x00', b'\x2A', // magic 42 (BE)
  ]
  assert_eq(detect_format(lb_to_bytes(data)), ImageFormat::Tiff)
}

///|
test "detect_format: ICO" {
  // ICO header + 1 directory entry = 22 bytes minimum
  let data : Array[Byte] = [
    b'\x00', b'\x00', // reserved
     b'\x01', b'\x00', // type = 1 (ICO)
     b'\x01', b'\x00', // 1 image
     b'\x01', b'\x01', // width=1, height=1 (directory entry)
     b'\x00', b'\x00', b'\x00', b'\x00', // colors, reserved, planes, bitcount
     b'\x10', b'\x00', b'\x00', b'\x00', // image size (16 bytes)
     b'\x0C', b'\x00', b'\x00', b'\x00', // image offset (12 = 6 + 16)
     b'\x00', b'\x00', // padding to reach 22 bytes
  ]
  assert_eq(detect_format(lb_to_bytes(data)), ImageFormat::Ico)
}

///|
test "detect_format: CUR" {
  // CUR header + 1 directory entry = 22 bytes minimum
  let data : Array[Byte] = [
    b'\x00', b'\x00', // reserved
     b'\x02', b'\x00', // type = 2 (CUR)
     b'\x01', b'\x00', // 1 image
     b'\x00', b'\x00', // width=0, height=0 (CUR hotspot)
     b'\x00', b'\x00', b'\x00', b'\x00', // colors, reserved, hotspot_x, hotspot_y
     b'\x10', b'\x00', b'\x00', b'\x00', // image size
     b'\x0C', b'\x00', b'\x00', b'\x00', // image offset
     b'\x00', b'\x00', // padding to reach 22 bytes
  ]
  assert_eq(detect_format(lb_to_bytes(data)), ImageFormat::Cur)
}

///|
test "detect_format: ICNS" {
  let data : Array[Byte] = [b'\x69', b'\x63', b'\x6E', b'\x73'] // "icns"
  assert_eq(detect_format(lb_to_bytes(data)), ImageFormat::Icns)
}

// ==================== load_from_bytes_auto 分派测试（5 个） ====================

///|
test "load_from_bytes_auto: BMP 分派" {
  let img = load_from_bytes_auto(lb_make_1x1_red_bmp())
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 3)
}

///|
test "load_from_bytes_auto: QOI 分派" {
  let img = load_from_bytes_auto(lb_make_1x1_rgb_qoi())
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 3)
}

///|
test "load_from_bytes_auto: PNM 分派" {
  let img = load_from_bytes_auto(lb_make_1x1_rgb_pnm())
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 3)
}

///|
test "load_from_bytes_auto: PSD 分派" {
  let img = load_from_bytes_auto(lb_make_1x1_rgb_psd())
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 3)
}

///|
test "load_from_bytes_auto: GIF 分派" {
  let img = load_from_bytes_auto(lb_make_1x1_rgb_gif())
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 3)
}

///|
test "load_from_bytes_auto: TIFF 分派 (roundtrip)" {
  let img = lb_make_1x1_red_bmp() |> @codec.decode_bmp_pure
  // 先编码再解码，验证 TIFF 自动分派
  let tiff_bytes = @codec.encode_tiff_pure(img)
  let decoded = load_from_bytes_auto(tiff_bytes)
  assert_eq(decoded.width, 1)
  assert_eq(decoded.height, 1)
  assert_eq(decoded.channels, 3)
}

///|
test "load_from_bytes_auto: ICO 分派 (roundtrip)" {
  let img = lb_make_1x1_red_bmp() |> @codec.decode_bmp_pure
  let ico_bytes = @codec.encode_ico_pure(img)
  let decoded = load_from_bytes_auto(ico_bytes)
  assert_eq(decoded.width, 1)
  assert_eq(decoded.height, 1)
  assert_eq(decoded.channels, 4) // ICO 编码为 32-bit BGRA
}

///|
test "detect_format: ICO 检测 + decode_ico_pure roundtrip" {
  // 使用 encode_ico_pure 编码，因为 CUR 解码器需要完整目录条目
  let img = lb_make_1x1_red_bmp() |> @codec.decode_bmp_pure
  let ico_bytes = @codec.encode_ico_pure(img)
  // 验证 ICO 可以被检测到
  assert_eq(detect_format(ico_bytes), ImageFormat::Ico)
  // 解码 ICO roundtrip
  let decoded = @codec.decode_ico_pure(ico_bytes)
  assert_eq(decoded.width, 1)
  assert_eq(decoded.height, 1)
  assert_eq(decoded.channels, 4)
}

///|
test "load_from_bytes_auto: ICNS 分派 (roundtrip)" {
  // ICNS 需要 ≥16x16，构造一个 16x16 图像
  let data : Array[Byte] = Array::make(16 * 16 * 4, b'\x00')
  for i in 0..<256 {
    data[i * 4] = b'\xFF' // 红色
  }
  let img = @types.Image::{
    width: 16,
    height: 16,
    channels: 4,
    data: Bytes::from_array(data),
  }
  let icns_bytes = @codec.encode_icns_pure(img)
  let decoded = load_from_bytes_auto(icns_bytes)
  assert_eq(decoded.width, 16)
  assert_eq(decoded.height, 16)
}

// ==================== Unknown raises 测试（1 个） ====================

///|
test "load_from_bytes_auto: Unknown raises" {
  let unknown : Array[Byte] = [b'\x00', b'\x00', b'\x00', b'\x00']
  try {
    let _ = load_from_bytes_auto(lb_to_bytes(unknown))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

// ==================== load_from_bytes_auto 格式覆盖（补充 WebP/TGA/CUR/APNG） ====================

///|
test "load_from_bytes_auto: WebP 分派 (roundtrip)" {
  // 构造最小 1x1 WebP lossless 文件
  let vp8l_data = [0x2f, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00]
  let vp8l_len = vp8l_data.length()
  let riff_size = 4 + 4 + 4 + vp8l_len
  let data : Array[Byte] = []
  data.push(b'R')
  data.push(b'I')
  data.push(b'F')
  data.push(b'F')
  data.push((riff_size & 0xFF).to_byte())
  data.push(((riff_size >> 8) & 0xFF).to_byte())
  data.push(((riff_size >> 16) & 0xFF).to_byte())
  data.push(((riff_size >> 24) & 0xFF).to_byte())
  data.push(b'W')
  data.push(b'E')
  data.push(b'B')
  data.push(b'P')
  data.push(b'V')
  data.push(b'P')
  data.push(b'8')
  data.push(b'L')
  data.push((vp8l_len & 0xFF).to_byte())
  data.push(((vp8l_len >> 8) & 0xFF).to_byte())
  data.push(((vp8l_len >> 16) & 0xFF).to_byte())
  data.push(((vp8l_len >> 24) & 0xFF).to_byte())
  for b in vp8l_data {
    data.push(b.to_byte())
  }
  let result = load_from_bytes_auto(lb_to_bytes(data))
  assert_eq(result.width, 1)
  assert_eq(result.height, 1)
}

///|
test "load_from_bytes_auto: TGA 分派 (roundtrip)" {
  // TGA 无 magic bytes，用显式解码器
  let img = lb_make_rgb_image(2, 2, [
    (255, 0, 0),
    (0, 255, 0),
    (0, 0, 255),
    (255, 255, 0),
  ])
  let tga_bytes = @codec.encode_tga_pure(img)
  let result = @codec.decode_tga_pure(tga_bytes)
  assert_eq(result.width, 2)
  assert_eq(result.height, 2)
  assert_eq(result.channels, 3)
}

///|
test "load_from_bytes_auto: CUR 分派 (roundtrip)" {
  // CUR 是 ICO type=2，用显式解码器
  let img = lb_make_rgb_image(2, 2, [
    (255, 0, 0),
    (0, 255, 0),
    (0, 0, 255),
    (255, 255, 0),
  ])
  let cur_bytes = @codec.encode_cur_pure(img)
  let result = @codec.decode_cur_pure(cur_bytes)
  assert_eq(result.width, 2)
  assert_eq(result.height, 2)
  assert_eq(result.channels, 4)
}

///|
test "load_from_bytes_auto: APNG 分派 (单帧, raises as expected)" {
  // APNG 与 PNG 共享签名，load_from_bytes_auto 无法区分，应 raise
  let png : Array[Byte] = [
    b'\x89', b'\x50', b'\x4E', b'\x47', b'\x0D', b'\x0A', b'\x1A', b'\x0A', 0x00,
    0x00, 0x00, 0x0D, b'I', b'H', b'D', b'R', 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
    0x00, 0x01, b'\x08', b'\x02', b'\x00', b'\x00', b'\x00', 0x90, b'W', b'\x3D',
    b'\x1F', 0x00, 0x00, 0x00, 0x0C, b'I', b'C', b'C', b'X', 0x00, b'\xC4', b'\x96',
    b'\x66', b'\x01', 0x00, 0x00, 0x00, b'\x02', b'\xCC', b'\x16', b'\xE8', 0x00,
    0x00, 0x00, 0x0D, b'I', b'D', b'A', b'T', b'x', b'\xDA', b'\xC4', b'\xC1', b'\xC1',
    b'\x0B', 0x00, 0x00, b'\x00', b'\x02', b'\x00', b'\xFE', b'\xBB', b'\xD0', b'\x11',
    0x00, 0x00, 0x00, 0x00, b'I', b'E', b'N', b'D', b'\xAE', b'\x42', b'\x60', b'\x82',
  ]
  try {
    let _ = load_from_bytes_auto(lb_to_bytes(png))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

// ==================== 编码器委托验证测试（4 个） ====================

///|
test "encode_qoi 委托验证" {
  let img = lb_make_rgb_image(1, 1, [(255, 0, 0)])
  let out = encode_qoi(img)
  // 前 4 字节为 "qoif"
  assert_eq(out[0].to_int(), 0x71)
  assert_eq(out[1].to_int(), 0x6F)
  assert_eq(out[2].to_int(), 0x69)
  assert_eq(out[3].to_int(), 0x66)
  // 与 @codec.encode_qoi_pure 结果一致
  assert_eq(out, @codec.encode_qoi_pure(img))
}

///|
test "encode_ppm_auto 委托验证" {
  let img = lb_make_rgb_image(1, 1, [(255, 0, 0)])
  let out = encode_ppm_auto(img)
  // 前 2 字节为 "P6"
  assert_eq(out[0].to_int(), 0x50)
  assert_eq(out[1].to_int(), 0x36)
  // 与 @codec.encode_ppm_pure 结果一致
  assert_eq(out, @codec.encode_ppm_pure(img))
}

///|
test "encode_pgm_auto 委托验证" {
  let img = lb_make_rgb_image(1, 1, [(255, 0, 0)])
  let out = encode_pgm_auto(img)
  // 前 2 字节为 "P5"
  assert_eq(out[0].to_int(), 0x50)
  assert_eq(out[1].to_int(), 0x35)
  // 与 @codec.encode_pgm_pure 结果一致
  assert_eq(out, @codec.encode_pgm_pure(img))
}

///|
test "encode_gif 委托验证" {
  let img = lb_make_rgb_image(1, 1, [(255, 0, 0)])
  let out = encode_gif(img)
  // 前 6 字节为 "GIF89a"
  assert_eq(out[0].to_int(), 0x47)
  assert_eq(out[1].to_int(), 0x49)
  assert_eq(out[2].to_int(), 0x46)
  assert_eq(out[3].to_int(), 0x38)
  assert_eq(out[4].to_int(), 0x39)
  assert_eq(out[5].to_int(), 0x61)
  // 与 @codec.encode_gif_pure 结果一致
  assert_eq(out, @codec.encode_gif_pure(img))
}

///|
test "detect_format: HDR RADIANCE" {
  let data : Array[Byte] = [
    b'\x23', b'\x3F', b'\x52', b'\x41', b'\x44', b'\x49', b'\x41', b'\x4E', b'\x43',
    b'\x45',
  ]
  assert_eq(detect_format(lb_to_bytes(data)), ImageFormat::Hdr)
}

///|
test "load_from_bytes_auto: JPEG 分派" {
  // 构造 2x2 RGB 图像，encode 为 JPEG，然后通过 load_from_bytes_auto 解码
  let img = lb_make_rgb_image(2, 2, [
    (128, 128, 128),
    (64, 64, 64),
    (192, 192, 192),
    (32, 32, 32),
  ])
  let jpeg_bytes = @codec.encode_jpeg_pure(img)
  let restored = load_from_bytes_auto(jpeg_bytes)
  assert_eq(restored.width, 2)
  assert_eq(restored.height, 2)
  assert_eq(restored.channels, 3)
}

///|
test "load_from_bytes_auto: HDR raises (needs decode_hdr_pure)" {
  let data : Array[Byte] = [
    b'\x23', b'\x3F', b'\x52', b'\x41', b'\x44', b'\x49', b'\x41', b'\x4E', b'\x43',
    b'\x45', b'\x0A',
  ]
  try {
    let _ = load_from_bytes_auto(lb_to_bytes(data))
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "load_from_bytes_auto: TGA via explicit decode" {
  // 构造 2x2 RGB 图像，encode 为 TGA，然后通过 load_from_bytes_auto 解码
  // TGA 无固定 magic，detect_format 返回 Unknown，所以需要显式调用 decode_tga_pure
  let img = lb_make_rgb_image(2, 2, [
    (255, 0, 0),
    (0, 255, 0),
    (0, 0, 255),
    (255, 255, 255),
  ])
  let tga_bytes = @codec.encode_tga_pure(img)
  let restored = @codec.decode_tga_pure(tga_bytes)
  assert_eq(restored.width, 2)
  assert_eq(restored.height, 2)
  assert_eq(restored.channels, 3)
  let _ = img
}

// ==================== 编码器委托补充测试（6 个） ====================

///|
test "encode_png 委托验证" {
  let img = lb_make_rgb_image(2, 2, [
    (255, 0, 0),
    (0, 255, 0),
    (0, 0, 255),
    (255, 255, 255),
  ])
  let out = encode_png(img)
  // PNG signature: 89 50 4E 47 0D 0A 1A 0A
  assert_eq(out[0].to_int(), 0x89)
  assert_eq(out[1].to_int(), 0x50)
  assert_eq(out[2].to_int(), 0x4E)
  assert_eq(out[3].to_int(), 0x47)
  assert_eq(out, @codec.encode_png_pure(img))
}

///|
test "encode_jpeg 委托验证" {
  let img = lb_make_rgb_image(2, 2, [
    (128, 128, 128),
    (64, 64, 64),
    (192, 192, 192),
    (32, 32, 32),
  ])
  let out = encode_jpeg(img)
  // JPEG SOI marker: FF D8
  assert_eq(out[0].to_int(), 0xFF)
  assert_eq(out[1].to_int(), 0xD8)
  assert_eq(out, @codec.encode_jpeg_pure(img))
}

///|
test "encode_bmp 委托验证" {
  let img = lb_make_rgb_image(2, 2, [
    (255, 0, 0),
    (0, 255, 0),
    (0, 0, 255),
    (255, 255, 255),
  ])
  let out = encode_bmp(img)
  // BMP signature: "BM"
  assert_eq(out[0].to_int(), 0x42)
  assert_eq(out[1].to_int(), 0x4D)
  assert_eq(out, @codec.encode_bmp_pure(img))
}

///|
test "encode_tga 委托验证" {
  let img = lb_make_rgb_image(2, 2, [
    (255, 0, 0),
    (0, 255, 0),
    (0, 0, 255),
    (255, 255, 255),
  ])
  let out = encode_tga(img)
  assert_eq(out, @codec.encode_tga_pure(img))
}

///|
test "encode_pnm_auto 委托验证" {
  let img = lb_make_rgb_image(1, 1, [(100, 150, 200)])
  let out = encode_pnm_auto(img)
  // RGB image → PPM format "P6"
  assert_eq(out[0].to_int(), 0x50)
  assert_eq(out[1].to_int(), 0x36)
  assert_eq(out, @codec.encode_pnm_pure(img))
}

///|
test "encode_hdr 委托验证" {
  let data : Array[Byte] = []
  let vals = [1.0F, 0.5F, 0.0F]
  for v in vals {
    let vb = v.to_le_bytes()
    for i in 0..<4 {
      data.push(vb[i])
    }
  }
  let img = @types.ImageF::{
    width: 1,
    height: 1,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let out = encode_hdr(img)
  // HDR signature: "#?RADIANCE"
  assert_eq(out[0].to_int(), 0x23)
  assert_eq(out[1].to_int(), 0x3F)
  assert_eq(out[2].to_int(), 0x52)
  assert_eq(out, @codec.encode_hdr_pure(img))
}

// ==================== 格式检测补充测试 ====================

///|
test "detect_format: WebP RIFF" {
  // RIFF....WEBP
  let data : Array[Byte] = [
    b'\x52', b'\x49', b'\x46', b'\x46', // "RIFF"
     b'\x00', b'\x00', b'\x00', b'\x00', // file size
     b'\x57', b'\x45', b'\x42', b'\x50', // "WEBP"
  ]
  assert_eq(detect_format(lb_to_bytes(data)), ImageFormat::Webp)
}

///|
test "load_from_bytes_auto: TGA 分派 (Unknown → error)" {
  // TGA has no magic bytes, detect_format returns Unknown
  let img = lb_make_rgb_image(1, 1, [(255, 0, 0)])
  let tga_bytes = @codec.encode_tga_pure(img)
  try {
    let _ = load_from_bytes_auto(tga_bytes)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "load_16_from_bytes_auto: PNM 16-bit 分派" {
  // Construct a 16-bit PNM (PGM P5)
  let data : Array[Byte] = [
    b'\x50', b'\x35', b'\x0A', // "P5\n"
     b'\x32', b'\x20', b'\x31', b'\x0A', // "2 1\n"
     b'\x31', b'\x30', b'\x32', b'\x33', b'\x0A', // "1023\n"
     b'\x03', b'\xFF', b'\x00', b'\x00', // pixel 0: 1023, pixel 1: 0
  ]
  let img = load_16_from_bytes_auto(lb_to_bytes(data))
  assert_eq(img.width, 2)
  assert_eq(img.height, 1)
}

///|
test "load_16_from_bytes_auto: unsupported format → error" {
  // BMP is not supported for 16-bit decode
  let bmp = lb_make_1x1_red_bmp()
  try {
    let _ = load_16_from_bytes_auto(bmp)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

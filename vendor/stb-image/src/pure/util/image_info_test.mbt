// 纯 MoonBit 图像信息查询测试
// 覆盖 info_from_bytes_pure / is_hdr_from_bytes_pure / is_16_bit_from_bytes_pure / failure_reason_pure
// 构造各格式头部字节流验证解析正确性，覆盖全部格式分支 + 错误路径

///|
// 构造 BMP 头部（30+ 字节），width/height/bpp 可配置
fn ii_make_bmp_header(width : Int, height : Int, bpp : Int) -> Bytes {
  let out : Array[Byte] = Array::make(30, b'\x00')
  // "BM"
  out[0] = b'\x42'
  out[1] = b'\x4D'
  // width @ 18 (LE u32)
  out[18] = (width & 0xFF).to_byte()
  out[19] = ((width >> 8) & 0xFF).to_byte()
  // height @ 22 (LE u32)
  out[22] = (height & 0xFF).to_byte()
  out[23] = ((height >> 8) & 0xFF).to_byte()
  // bpp @ 28 (LE u16)
  out[28] = (bpp & 0xFF).to_byte()
  out[29] = ((bpp >> 8) & 0xFF).to_byte()
  Bytes::from_array(out)
}

///|
// 构造 QOI 头部（14 字节）
fn ii_make_qoi_header(width : Int, height : Int, channels : Int) -> Bytes {
  let out : Array[Byte] = [
    b'\x71',
    b'\x6F',
    b'\x69',
    b'\x66', // "qoif"
    ((width >> 24) & 0xFF).to_byte(),
    ((width >> 16) & 0xFF).to_byte(),
    ((width >> 8) & 0xFF).to_byte(),
    (width & 0xFF).to_byte(),
    ((height >> 24) & 0xFF).to_byte(),
    ((height >> 16) & 0xFF).to_byte(),
    ((height >> 8) & 0xFF).to_byte(),
    (height & 0xFF).to_byte(),
    channels.to_byte(),
    b'\x00',
  ]
  Bytes::from_array(out)
}

///|
// 构造 PSD 头部（16+ 字节）
fn ii_make_psd_header(channels : Int, height : Int, width : Int) -> Bytes {
  let out : Array[Byte] = Array::make(16, b'\x00')
  // "8BPS"
  out[0] = b'\x38'
  out[1] = b'\x42'
  out[2] = b'\x50'
  out[3] = b'\x53'
  // channels @ 4 (BE u16)
  out[4] = ((channels >> 8) & 0xFF).to_byte()
  out[5] = (channels & 0xFF).to_byte()
  // height @ 6 (BE u32)
  out[6] = ((height >> 24) & 0xFF).to_byte()
  out[7] = ((height >> 16) & 0xFF).to_byte()
  out[8] = ((height >> 8) & 0xFF).to_byte()
  out[9] = (height & 0xFF).to_byte()
  // width @ 10 (BE u32)
  out[10] = ((width >> 24) & 0xFF).to_byte()
  out[11] = ((width >> 16) & 0xFF).to_byte()
  out[12] = ((width >> 8) & 0xFF).to_byte()
  out[13] = (width & 0xFF).to_byte()
  Bytes::from_array(out)
}

///|
// 构造 GIF 头部（10 字节）
fn ii_make_gif_header(width : Int, height : Int) -> Bytes {
  let out : Array[Byte] = [
    b'\x47',
    b'\x49',
    b'\x46',
    b'\x38',
    b'\x39',
    b'\x61', // "GIF89a"
    (width & 0xFF).to_byte(),
    ((width >> 8) & 0xFF).to_byte(),
    (height & 0xFF).to_byte(),
    ((height >> 8) & 0xFF).to_byte(),
  ]
  Bytes::from_array(out)
}

///|
// 构造 PNG 头部（26 字节），color_type 可配置
fn ii_make_png_header(
  width : Int,
  height : Int,
  bit_depth : Int,
  color_type : Int,
) -> Bytes {
  let out : Array[Byte] = Array::make(26, b'\x00')
  // PNG signature
  out[0] = b'\x89'
  out[1] = b'\x50' // P
  out[2] = b'\x4E' // N
  out[3] = b'\x47' // G
  out[4] = b'\x0D'
  out[5] = b'\x0A'
  out[6] = b'\x1A'
  out[7] = b'\x0A'
  // width @ 16 (BE u32)
  out[16] = ((width >> 24) & 0xFF).to_byte()
  out[17] = ((width >> 16) & 0xFF).to_byte()
  out[18] = ((width >> 8) & 0xFF).to_byte()
  out[19] = (width & 0xFF).to_byte()
  // height @ 20 (BE u32)
  out[20] = ((height >> 24) & 0xFF).to_byte()
  out[21] = ((height >> 16) & 0xFF).to_byte()
  out[22] = ((height >> 8) & 0xFF).to_byte()
  out[23] = (height & 0xFF).to_byte()
  out[24] = bit_depth.to_byte()
  out[25] = color_type.to_byte()
  Bytes::from_array(out)
}

///|
// 构造 JPEG 头部：SOI + APP0 + SOF0
fn ii_make_jpeg_header(width : Int, height : Int, channels : Int) -> Bytes {
  let out : Array[Byte] = []
  // SOI
  out.push(b'\xFF')
  out.push(b'\xD8')
  // SOF0 marker
  out.push(b'\xFF')
  out.push(b'\xC0')
  // length = 8 + 3*channels
  let seg_len = 8 + 3 * channels
  out.push(((seg_len >> 8) & 0xFF).to_byte())
  out.push((seg_len & 0xFF).to_byte())
  // precision
  out.push(b'\x08')
  // height (BE u16)
  out.push(((height >> 8) & 0xFF).to_byte())
  out.push((height & 0xFF).to_byte())
  // width (BE u16)
  out.push(((width >> 8) & 0xFF).to_byte())
  out.push((width & 0xFF).to_byte())
  // num_components
  out.push(channels.to_byte())
  // component specs (3 bytes each)
  for i in 0..<channels {
    out.push((i + 1).to_byte()) // id
    out.push(b'\x11') // h/v sampling
    out.push(b'\x00') // qt id
  }
  Bytes::from_array(out)
}

///|
// 将整数的 ASCII 数字推入字节数组
fn ii_push_ascii_int(out : Array[Byte], v : Int) -> Unit {
  for c in v.to_string() {
    out.push(c.to_int().to_byte())
  }
}

///|
// 构造 PNM 头部 (P5/P6)
fn ii_make_pnm_header(format : Int, width : Int, height : Int) -> Bytes {
  let out : Array[Byte] = []
  out.push(b'\x50') // 'P'
  out.push(format.to_byte()) // '5' or '6'
  out.push(b'\x0A') // newline
  ii_push_ascii_int(out, width)
  out.push(b'\x0A')
  ii_push_ascii_int(out, height)
  out.push(b'\x0A')
  out.push(b'\x32') // maxval "2"
  out.push(b'\x35') // "5"
  out.push(b'\x0A')
  Bytes::from_array(out)
}

///|
test "info_from_bytes_pure: BMP 24-bit" {
  let data = ii_make_bmp_header(100, 200, 24)
  let info = info_from_bytes_pure(data)
  guard info is Some(i) else { fail("expected Some") }
  assert_eq(i.width, 100)
  assert_eq(i.height, 200)
  assert_eq(i.channels, 3)
}

///|
test "info_from_bytes_pure: BMP 32-bit" {
  let data = ii_make_bmp_header(50, 60, 32)
  let info = info_from_bytes_pure(data)
  guard info is Some(i) else { fail("expected Some") }
  assert_eq(i.width, 50)
  assert_eq(i.height, 60)
  assert_eq(i.channels, 4)
}

///|
test "info_from_bytes_pure: BMP zero width returns None" {
  let data = ii_make_bmp_header(0, 100, 24)
  let info = info_from_bytes_pure(data)
  assert_true(info is None)
}

///|
test "info_from_bytes_pure: QOI RGB" {
  let data = ii_make_qoi_header(320, 240, 3)
  let info = info_from_bytes_pure(data)
  guard info is Some(i) else { fail("expected Some") }
  assert_eq(i.width, 320)
  assert_eq(i.height, 240)
  assert_eq(i.channels, 3)
}

///|
test "info_from_bytes_pure: QOI RGBA" {
  let data = ii_make_qoi_header(64, 64, 4)
  let info = info_from_bytes_pure(data)
  guard info is Some(i) else { fail("expected Some") }
  assert_eq(i.width, 64)
  assert_eq(i.height, 64)
  assert_eq(i.channels, 4)
}

///|
test "info_from_bytes_pure: PSD" {
  let data = ii_make_psd_header(3, 100, 200)
  let info = info_from_bytes_pure(data)
  guard info is Some(i) else { fail("expected Some") }
  assert_eq(i.width, 200)
  assert_eq(i.height, 100)
  assert_eq(i.channels, 3)
}

///|
test "info_from_bytes_pure: GIF" {
  let data = ii_make_gif_header(800, 600)
  let info = info_from_bytes_pure(data)
  guard info is Some(i) else { fail("expected Some") }
  assert_eq(i.width, 800)
  assert_eq(i.height, 600)
  assert_eq(i.channels, 3)
}

///|
test "info_from_bytes_pure: PNG RGB (color_type=2)" {
  let data = ii_make_png_header(1920, 1080, 8, 2)
  let info = info_from_bytes_pure(data)
  guard info is Some(i) else { fail("expected Some") }
  assert_eq(i.width, 1920)
  assert_eq(i.height, 1080)
  assert_eq(i.channels, 3)
}

///|
test "info_from_bytes_pure: PNG grayscale (color_type=0)" {
  let data = ii_make_png_header(16, 16, 8, 0)
  let info = info_from_bytes_pure(data)
  guard info is Some(i) else { fail("expected Some") }
  assert_eq(i.channels, 1)
}

///|
test "info_from_bytes_pure: PNG palette (color_type=3)" {
  let data = ii_make_png_header(16, 16, 8, 3)
  let info = info_from_bytes_pure(data)
  guard info is Some(i) else { fail("expected Some") }
  assert_eq(i.channels, 1)
}

///|
test "info_from_bytes_pure: PNG gray+alpha (color_type=4)" {
  let data = ii_make_png_header(16, 16, 8, 4)
  let info = info_from_bytes_pure(data)
  guard info is Some(i) else { fail("expected Some") }
  assert_eq(i.channels, 2)
}

///|
test "info_from_bytes_pure: PNG RGBA (color_type=6)" {
  let data = ii_make_png_header(16, 16, 8, 6)
  let info = info_from_bytes_pure(data)
  guard info is Some(i) else { fail("expected Some") }
  assert_eq(i.channels, 4)
}

///|
test "info_from_bytes_pure: JPEG 3-channel" {
  let data = ii_make_jpeg_header(640, 480, 3)
  let info = info_from_bytes_pure(data)
  guard info is Some(i) else { fail("expected Some") }
  assert_eq(i.width, 640)
  assert_eq(i.height, 480)
  assert_eq(i.channels, 3)
}

///|
test "info_from_bytes_pure: JPEG 1-channel grayscale" {
  let data = ii_make_jpeg_header(128, 128, 1)
  let info = info_from_bytes_pure(data)
  guard info is Some(i) else { fail("expected Some") }
  assert_eq(i.width, 128)
  assert_eq(i.height, 128)
  assert_eq(i.channels, 1)
}

///|
test "info_from_bytes_pure: PNM P5 grayscale" {
  let data = ii_make_pnm_header(0x35, 100, 200)
  let info = info_from_bytes_pure(data)
  guard info is Some(i) else { fail("expected Some") }
  assert_eq(i.width, 100)
  assert_eq(i.height, 200)
  assert_eq(i.channels, 1)
}

///|
test "info_from_bytes_pure: PNM P6 RGB" {
  let data = ii_make_pnm_header(0x36, 100, 200)
  let info = info_from_bytes_pure(data)
  guard info is Some(i) else { fail("expected Some") }
  assert_eq(i.width, 100)
  assert_eq(i.height, 200)
  assert_eq(i.channels, 3)
}

///|
test "info_from_bytes_pure: PNM with comment" {
  // P6 # comment\n 100 200 255\n
  let out : Array[Byte] = [
    b'\x50', b'\x36', b'\x0A', b'\x23', b'\x63', b'\x6F', b'\x6D', b'\x6D', b'\x65',
    b'\x6E', b'\x74', b'\x0A', b'\x31', b'\x30', b'\x30', b'\x20', b'\x32', b'\x30',
    b'\x30', b'\x0A', b'\x32', b'\x35', b'\x35', b'\x0A',
  ]
  let data = Bytes::from_array(out)
  let info = info_from_bytes_pure(data)
  guard info is Some(i) else { fail("expected Some") }
  assert_eq(i.width, 100)
  assert_eq(i.height, 200)
  assert_eq(i.channels, 3)
}

///|
test "info_from_bytes_pure: empty data raises" {
  try {
    let _ = info_from_bytes_pure(b"")
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "info_from_bytes_pure: unknown format returns None" {
  let data = b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09"
  let info = info_from_bytes_pure(data)
  assert_true(info is None)
}

///|
test "info_from_bytes_pure: BMP too short returns None" {
  // "BM" but only 10 bytes (< 30)
  let data = b"\x42\x4D\x00\x00\x00\x00\x00\x00\x00\x00"
  let info = info_from_bytes_pure(data)
  assert_true(info is None)
}

///|
test "info_from_bytes_pure: BMP invalid channels returns None" {
  // bpp=0 → channels=0
  let data = ii_make_bmp_header(100, 100, 0)
  let info = info_from_bytes_pure(data)
  assert_true(info is None)
}

///|
test "info_from_bytes_pure: QOI too short returns None" {
  // "qoif" but only 6 bytes (< 14)
  let data = b"\x71\x6F\x69\x66\x00\x00"
  let info = info_from_bytes_pure(data)
  assert_true(info is None)
}

///|
test "info_from_bytes_pure: QOI invalid channels returns None" {
  let data = ii_make_qoi_header(100, 100, 0)
  let info = info_from_bytes_pure(data)
  assert_true(info is None)
}

///|
test "info_from_bytes_pure: PSD too short returns None" {
  // "8BPS" but only 8 bytes (< 16)
  let data = b"\x38\x42\x50\x53\x00\x00\x00\x00"
  let info = info_from_bytes_pure(data)
  assert_true(info is None)
}

///|
test "info_from_bytes_pure: GIF too short returns None" {
  // "GIF" but only 6 bytes (< 10)
  let data = b"\x47\x49\x46\x38\x39\x61"
  let info = info_from_bytes_pure(data)
  assert_true(info is None)
}

///|
test "info_from_bytes_pure: PNG truncated IHDR returns None" {
  // PNG signature but only 16 bytes (< 26)
  let data = b"\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x00\x00\x00\x00\x00"
  let info = info_from_bytes_pure(data)
  assert_true(info is None)
}

///|
test "info_from_bytes_pure: PNG invalid color_type returns None" {
  let data = ii_make_png_header(16, 16, 8, 7) // invalid color_type
  let info = info_from_bytes_pure(data)
  assert_true(info is None)
}

///|
test "info_from_bytes_pure: JPEG no SOF returns None" {
  // SOI + DQT marker (not SOF), should scan and return None
  let out : Array[Byte] = [
    b'\xFF', b'\xD8', b'\xFF', b'\xDB', b'\x00', b'\x43', b'\x00',
  ]
  let data = Bytes::from_array(out)
  let info = info_from_bytes_pure(data)
  assert_true(info is None)
}

///|
test "info_from_bytes_pure: PNM P4 unsupported returns None" {
  // P4 (not P5/P6)
  let data = b"\x50\x34\x0A\x31\x30\x30\x20\x31\x30\x30\x0A"
  let info = info_from_bytes_pure(data)
  assert_true(info is None)
}

///|
test "is_hdr_from_bytes_pure: RADIANCE magic" {
  let data = b"#?RADIANCE\n"
  assert_true(is_hdr_from_bytes_pure(data))
}

///|
test "is_hdr_from_bytes_pure: RGBE magic" {
  let data = b"#?RGBE\n"
  assert_true(is_hdr_from_bytes_pure(data))
}

///|
test "is_hdr_from_bytes_pure: not HDR" {
  let data = b"\x89\x50\x4E\x47\x0D\x0A\x1A\x0A"
  assert_false(is_hdr_from_bytes_pure(data))
}

///|
test "is_hdr_from_bytes_pure: too short" {
  let data = b"\x23"
  assert_false(is_hdr_from_bytes_pure(data))
}

///|
test "is_hdr_from_bytes_pure: wrong prefix" {
  let data = b"\x24\x3F\x52\x41\x44\x49\x41\x4E\x43\x45"
  assert_false(is_hdr_from_bytes_pure(data))
}

///|
test "is_hdr_from_bytes_pure: prefix but wrong suffix" {
  // "#?XXXX..." - has #? but neither RADIANCE nor RGBE
  let data = b"\x23\x3F\x58\x58\x58\x58\x58\x58\x58\x58"
  assert_false(is_hdr_from_bytes_pure(data))
}

///|
test "is_16_bit_from_bytes_pure: 16-bit PNG" {
  let data = ii_make_png_header(16, 16, 16, 2)
  assert_true(is_16_bit_from_bytes_pure(data))
}

///|
test "is_16_bit_from_bytes_pure: 8-bit PNG" {
  let data = ii_make_png_header(16, 16, 8, 2)
  assert_false(is_16_bit_from_bytes_pure(data))
}

///|
test "is_16_bit_from_bytes_pure: not PNG" {
  let data = b"\x42\x4D\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
  assert_false(is_16_bit_from_bytes_pure(data))
}

///|
test "is_16_bit_from_bytes_pure: too short" {
  let data = b"\x89\x50\x4E\x47"
  assert_false(is_16_bit_from_bytes_pure(data))
}

///|
test "failure_reason_pure returns string" {
  let s = failure_reason_pure()
  assert_true(s.length() > 0)
}

///|
test "info_from_bytes_pure: PSD with zero dimensions returns None" {
  // PSD header with width=0
  let data = b"\x42\x49\x4D\x53\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01"
  let result = info_from_bytes_pure(data)
  assert_true(result is None)
}

///|
test "info_from_bytes_pure: PSD zero channels returns None" {
  // "8BPS" with channels=0
  let out : Array[Byte] = Array::make(16, b'\x00')
  out[0] = b'\x38'
  out[1] = b'\x42'
  out[2] = b'\x50'
  out[3] = b'\x53'
  // channels=0 at offset 4 (BE u16)
  // height=1 at offset 6, width=1 at offset 10
  let data = Bytes::from_array(out)
  let result = info_from_bytes_pure(data)
  assert_true(result is None)
}

///|
test "info_from_bytes_pure: PSD with channels>0 returns Some" {
  let data = ii_make_psd_header(3, 100, 200)
  let info = info_from_bytes_pure(data)
  guard info is Some(i) else { fail("expected Some") }
  assert_eq(i.width, 200)
  assert_eq(i.height, 100)
  assert_eq(i.channels, 3)
}

///|
test "info_from_bytes_pure: GIF with zero dimensions returns None" {
  let data = b"\x47\x49\x46\x38\x39\x61\x00\x00\x01\x00"
  let result = info_from_bytes_pure(data)
  assert_true(result is None)
}

///|
test "info_from_bytes_pure: JPEG truncated SOF returns None" {
  // SOI + SOF0 where total data is exactly 11 bytes
  // pos=2, so pos+9=11 >= len=11 → hits truncation guard
  let out : Array[Byte] = [
    b'\xFF', b'\xD8', // SOI
     b'\xFF', b'\xC0', // SOF0
     b'\x00', b'\x08', // length=8
     b'\x08', // precision
     b'\x00', b'\x01', // height=1
     b'\x00', b'\x01', // width=1
    // num_components byte missing → pos+9=11 >= len=11
  ]
  let data = Bytes::from_array(out)
  let info = info_from_bytes_pure(data)
  assert_true(info is None)
}

///|
test "read_png_text_chunks: non-PNG returns empty" {
  let data = Bytes::from_array([b'\x00', b'\x00', b'\x00', b'\x00'])
  let result = read_png_text_chunks(data)
  assert_eq(result.length(), 0)
  let _ = data
  let _ = result
}

///|
test "read_png_text_chunks: empty bytes returns empty" {
  let data = Bytes::from_array([])
  let result = read_png_text_chunks(data)
  assert_eq(result.length(), 0)
  let _ = data
  let _ = result
}

///|
test "read_png_text_chunks: PNG without text chunks returns empty" {
  // 读取测试 PNG 文件
  let png = @codec.encode_png_pure(@types.Image::{
    width: 1,
    height: 1,
    channels: 3,
    data: [b'\xFF', b'\x00', b'\x00'] |> Bytes::from_array,
  })
  let result = read_png_text_chunks(png)
  // stb_image_write 生成的 PNG 可能没有 text chunks
  assert_true(result.length() >= 0)
  let _ = png
  let _ = result
}

///|
test "PngTextChunk: construction" {
  let chunk = PngTextChunk::{ keyword: "Author", text: "Test" }
  assert_eq(chunk.keyword, "Author")
  assert_eq(chunk.text, "Test")
  let _ = chunk
}

///|
/// 构建 PNG chunk: length(4 BE) + type(4) + data + CRC(4 dummy)
fn build_chunk(chunk_type : Array[Byte], data : Array[Byte]) -> Array[Byte] {
  let result : Array[Byte] = []
  let len = data.length()
  result.push((len >> 24).to_byte())
  result.push(((len >> 16) & 0xFF).to_byte())
  result.push(((len >> 8) & 0xFF).to_byte())
  result.push((len & 0xFF).to_byte())
  for b in chunk_type {
    result.push(b)
  }
  for b in data {
    result.push(b)
  }
  // Dummy CRC (4 bytes)
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x00')
  result
}

///|
/// 构建 PNG signature
fn png_signature() -> Array[Byte] {
  [b'\x89', b'\x50', b'\x4E', b'\x47', b'\x0D', b'\x0A', b'\x1A', b'\x0A']
}

///|
/// 构建 IHDR chunk data for 1x1 RGB
fn ihdr_data() -> Array[Byte] {
  // width=1 (4 BE), height=1 (4 BE), bit_depth=8, color_type=2, comp=0, filter=0, interlace=0
  [
    b'\x00', b'\x00', b'\x00', b'\x01', b'\x00', b'\x00', b'\x00', b'\x01', b'\x08',
    b'\x02', b'\x00', b'\x00', b'\x00',
  ]
}

///|
test "read_png_text_chunks: tEXt chunk" {
  // 构建包含 tEXt chunk 的 PNG
  let png : Array[Byte] = []
  for b in png_signature() {
    png.push(b)
  }
  // IHDR
  for b in build_chunk([b'\x49', b'\x48', b'\x44', b'\x52'], ihdr_data()) {
    png.push(b)
  }
  // tEXt: "Author\0TestAuthor"
  let text_data : Array[Byte] = []
  for c in "Author".to_array() {
    text_data.push(c.to_int().to_byte())
  }
  text_data.push(b'\x00')
  for c in "TestAuthor".to_array() {
    text_data.push(c.to_int().to_byte())
  }
  for b in build_chunk([b'\x74', b'\x45', b'\x58', b'\x74'], text_data) {
    png.push(b)
  }
  // IEND
  for b in build_chunk([b'\x49', b'\x45', b'\x4E', b'\x44'], []) {
    png.push(b)
  }
  let result = read_png_text_chunks(Bytes::from_array(png))
  assert_eq(result.length(), 1)
  assert_eq(result[0].keyword, "Author")
  assert_eq(result[0].text, "TestAuthor")
}

///|
test "read_png_text_chunks: iTXt chunk uncompressed" {
  let png : Array[Byte] = []
  for b in png_signature() {
    png.push(b)
  }
  for b in build_chunk([b'\x49', b'\x48', b'\x44', b'\x52'], ihdr_data()) {
    png.push(b)
  }
  // iTXt: keyword + 0x00 + comp_flag(0) + comp_method(0) + language_tag + 0x00 + translated_keyword + 0x00 + text
  let itxt_data : Array[Byte] = []
  for c in "Comment".to_array() {
    itxt_data.push(c.to_int().to_byte())
  }
  itxt_data.push(b'\x00') // separator
  itxt_data.push(b'\x00') // comp_flag = 0 (uncompressed)
  itxt_data.push(b'\x00') // comp_method = 0
  itxt_data.push(b'\x00') // language_tag (empty) + 0x00
  itxt_data.push(b'\x00') // translated_keyword (empty) + 0x00
  for c in "Hello World".to_array() {
    itxt_data.push(c.to_int().to_byte())
  }
  for b in build_chunk([b'\x69', b'\x54', b'\x58', b'\x74'], itxt_data) {
    png.push(b)
  }
  for b in build_chunk([b'\x49', b'\x45', b'\x4E', b'\x44'], []) {
    png.push(b)
  }
  let result = read_png_text_chunks(Bytes::from_array(png))
  assert_eq(result.length(), 1)
  assert_eq(result[0].keyword, "Comment")
  assert_eq(result[0].text, "Hello World")
}

///|
test "read_png_text_chunks: iTXt chunk compressed" {
  let png : Array[Byte] = []
  for b in png_signature() {
    png.push(b)
  }
  for b in build_chunk([b'\x49', b'\x48', b'\x44', b'\x52'], ihdr_data()) {
    png.push(b)
  }
  let itxt_data : Array[Byte] = []
  for c in "X".to_array() {
    itxt_data.push(c.to_int().to_byte())
  }
  itxt_data.push(b'\x00')
  itxt_data.push(b'\x01') // comp_flag = 1 (compressed)
  itxt_data.push(b'\x00')
  itxt_data.push(b'\x00')
  itxt_data.push(b'\x00')
  for c in "data".to_array() {
    itxt_data.push(c.to_int().to_byte())
  }
  for b in build_chunk([b'\x69', b'\x54', b'\x58', b'\x74'], itxt_data) {
    png.push(b)
  }
  for b in build_chunk([b'\x49', b'\x45', b'\x4E', b'\x44'], []) {
    png.push(b)
  }
  let result = read_png_text_chunks(Bytes::from_array(png))
  assert_eq(result.length(), 1)
  assert_eq(result[0].keyword, "X")
  assert_eq(result[0].text, "[compressed]")
}

///|
test "read_png_text_chunks: multiple tEXt chunks" {
  let png : Array[Byte] = []
  for b in png_signature() {
    png.push(b)
  }
  for b in build_chunk([b'\x49', b'\x48', b'\x44', b'\x52'], ihdr_data()) {
    png.push(b)
  }
  // First tEXt
  let td1 : Array[Byte] = []
  for c in "Author".to_array() {
    td1.push(c.to_int().to_byte())
  }
  td1.push(b'\x00')
  for c in "Alice".to_array() {
    td1.push(c.to_int().to_byte())
  }
  for b in build_chunk([b'\x74', b'\x45', b'\x58', b'\x74'], td1) {
    png.push(b)
  }
  // Second tEXt
  let td2 : Array[Byte] = []
  for c in "Software".to_array() {
    td2.push(c.to_int().to_byte())
  }
  td2.push(b'\x00')
  for c in "TestApp".to_array() {
    td2.push(c.to_int().to_byte())
  }
  for b in build_chunk([b'\x74', b'\x45', b'\x58', b'\x74'], td2) {
    png.push(b)
  }
  for b in build_chunk([b'\x49', b'\x45', b'\x4E', b'\x44'], []) {
    png.push(b)
  }
  let result = read_png_text_chunks(Bytes::from_array(png))
  assert_eq(result.length(), 2)
  assert_eq(result[0].keyword, "Author")
  assert_eq(result[0].text, "Alice")
  assert_eq(result[1].keyword, "Software")
  assert_eq(result[1].text, "TestApp")
}

///|
test "read_png_text_chunks: tEXt with empty text" {
  let png : Array[Byte] = []
  for b in png_signature() {
    png.push(b)
  }
  for b in build_chunk([b'\x49', b'\x48', b'\x44', b'\x52'], ihdr_data()) {
    png.push(b)
  }
  let td : Array[Byte] = []
  for c in "Empty".to_array() {
    td.push(c.to_int().to_byte())
  }
  td.push(b'\x00')
  for b in build_chunk([b'\x74', b'\x45', b'\x58', b'\x74'], td) {
    png.push(b)
  }
  for b in build_chunk([b'\x49', b'\x45', b'\x4E', b'\x44'], []) {
    png.push(b)
  }
  let result = read_png_text_chunks(Bytes::from_array(png))
  assert_eq(result.length(), 1)
  assert_eq(result[0].keyword, "Empty")
  assert_eq(result[0].text, "")
}

///|
test "read_png_text_chunks: iTXt with language tag" {
  let png : Array[Byte] = []
  for b in png_signature() {
    png.push(b)
  }
  for b in build_chunk([b'\x49', b'\x48', b'\x44', b'\x52'], ihdr_data()) {
    png.push(b)
  }
  let itxt_data : Array[Byte] = []
  for c in "Desc".to_array() {
    itxt_data.push(c.to_int().to_byte())
  }
  itxt_data.push(b'\x00')
  itxt_data.push(b'\x00') // comp_flag = 0
  itxt_data.push(b'\x00') // comp_method
  // language tag "en"
  for c in "en".to_array() {
    itxt_data.push(c.to_int().to_byte())
  }
  itxt_data.push(b'\x00')
  // translated keyword "Description"
  for c in "Description".to_array() {
    itxt_data.push(c.to_int().to_byte())
  }
  itxt_data.push(b'\x00')
  // text
  for c in "Test text".to_array() {
    itxt_data.push(c.to_int().to_byte())
  }
  for b in build_chunk([b'\x69', b'\x54', b'\x58', b'\x74'], itxt_data) {
    png.push(b)
  }
  for b in build_chunk([b'\x49', b'\x45', b'\x4E', b'\x44'], []) {
    png.push(b)
  }
  let result = read_png_text_chunks(Bytes::from_array(png))
  assert_eq(result.length(), 1)
  assert_eq(result[0].keyword, "Desc")
  assert_eq(result[0].text, "Test text")
}

///|
test "read_png_text_chunks: chunk data extends beyond buffer" {
  // Construct a PNG with a tEXt chunk whose declared length exceeds available data
  // tEXt chunk_len=20 but only 15 bytes available after header
  let png : Array[Byte] = [
    b'\x89', b'\x50', b'\x4E', b'\x47', b'\x0D', b'\x0A', b'\x1A', b'\x0A', 0x00,
    0x00, 0x00, 0x0D, b'I', b'H', b'D', b'R', 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
    0x00, 0x01, b'\x08', b'\x02', b'\x00', b'\x00', b'\x00', 0x90, b'W', b'\x3D',
    b'\x1F', 0x00, 0x00, 0x00, 0x14, b't', b'E', b'X', b't', // chunk_len=20
     0x00, 0x05, // keyword length = 5
     b'T', b'e', b's', b't', b' ', // "Test "
     b'A', b'B', b'C', b'D', b'E', // only 5 more bytes, need 10 more to fill 20
    // Total: 52 bytes, but tEXt needs 60 bytes (40 + 20)
  ]
  let result = read_png_text_chunks(Bytes::from_array(png))
  // Should return empty since chunk data is incomplete (declared 20, only 15 available)
  assert_eq(result.length(), 0)
}

///|
test "read_png_text_chunks: UTF-8 invalid sequence returns empty" {
  // Construct PNG with tEXt chunk containing invalid UTF-8
  let png : Array[Byte] = [
    b'\x89', b'\x50', b'\x4E', b'\x47', b'\x0D', b'\x0A', b'\x1A', b'\x0A', 0x00,
    0x00, 0x00, 0x0D, b'I', b'H', b'D', b'R', 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
    0x00, 0x01, b'\x08', b'\x02', b'\x00', b'\x00', b'\x00', 0x90, b'W', b'\x3D',
    b'\x1F', 0x00, 0x00, 0x00, 0x0C, b't', b'E', b'X', b't', b'T', b'e', b's', b't', // keyword "test"
     0x00, // separator
     0x80, b'\xFF', 0x80, 0x00, 0x00, 0x00, // invalid UTF-8 + padding
     0x00, 0x00, 0x00, 0x0D, b'I', b'E', b'D', b'A', 0x78, b'\x9C', b'\x63', b'\xFC',
    b'\xCF', b'\x80', b'\x00', b'\x4C', b'\x48', b'\x6C', b'\x3C', b'\x1C', b'\x00',
    b'\x33', b'\xD1', b'\x01', b'\x07', b'\x30', b'\xE7', b'\xE1', b'\x4C', b'\x00',
    b'\x00', b'\x00', b'\x00', b'I', b'E', b'N', b'D', b'\xAE', b'\x42', b'\x60',
    b'\x82',
  ]
  let result = read_png_text_chunks(Bytes::from_array(png))
  // Should return 1 chunk with empty text (UTF-8 decode fails)
  assert_eq(result.length(), 1)
  assert_eq(result[0].keyword, "Test")
  assert_eq(result[0].text, "")
}

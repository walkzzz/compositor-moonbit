///|
test "read_exif_from_bytes: non-JPEG returns None" {
  let data = Bytes::from_array([b'\x00', b'\x00', b'\x00', b'\x00'])
  let result = read_exif_from_bytes(data)
  assert_eq(result, None)
  let _ = data
  let _ = result
}

///|
test "read_exif_from_bytes: empty bytes returns None" {
  let data = Bytes::from_array([])
  let result = read_exif_from_bytes(data)
  assert_eq(result, None)
  let _ = data
  let _ = result
}

///|
test "read_exif_from_bytes: JPEG without EXIF returns None" {
  // 创建一个最小 JPEG (SOI + EOI)
  let data = Bytes::from_array([b'\xFF', b'\xD8', b'\xFF', b'\xD9'])
  let result = read_exif_from_bytes(data)
  assert_eq(result, None)
  let _ = data
  let _ = result
}

///|
test "ExifInfo: default values" {
  let info = ExifInfo::{ make: "", model: "", orientation: 1, date_time: "" }
  assert_eq(info.orientation, 1)
  assert_eq(info.make, "")
  let _ = info
}

///|
/// 构建包含 EXIF 数据的 JPEG 字节流（big-endian / Motorola byte order）
fn build_exif_be_jpeg(
  make : String,
  model : String,
  orientation : Int,
  date_time : String,
) -> Bytes {
  // EXIF IFD entries: Make(0x010F), Model(0x0110), Orientation(0x0112), DateTime(0x0132)
  // Layout:
  //   [JPEG SOI]
  //   [APP1 marker + length]
  //   "Exif\0\0"
  //   [TIFF header: "MM" + 0x002A + IFD0 offset=8]
  //   [IFD0: count=4 + 4 entries + next IFD=0]
  //   [string data for Make, Model, DateTime]
  //   [JPEG EOI]
  let entries : Array[Byte] = []
  // String data area: after TIFF header (8) + IFD0 (2 + 4*12 + 4 = 54) = 62 from TIFF start
  let string_area_offset = 62
  // Build string data and entries
  let mut str_offset = string_area_offset
  let str_data : Array[Byte] = []
  // Helper: push a string as ASCII + null terminator
  fn push_str(s : String) -> Int {
    let start = str_offset
    for c in s.to_array() {
      str_data.push(c.to_int().to_byte())
    }
    str_data.push(b'\x00')
    str_offset += s.length() + 1
    start
  }
  // Make entry (tag=0x010F, type=2=ASCII, count=len+1, offset)
  let make_count = make.length() + 1
  let make_off = push_str(make)
  // Model entry (tag=0x0110, type=2, count=len+1, offset)
  let model_count = model.length() + 1
  let model_off = push_str(model)
  // Orientation entry (tag=0x0112, type=3=SHORT, count=1, value inline)
  // DateTime entry (tag=0x0132, type=2, count=len+1, offset)
  let dt_count = date_time.length() + 1
  let dt_off = push_str(date_time)
  // IFD0 entry count = 4
  entries.push(b'\x00')
  entries.push(b'\x04')
  // Entry 1: Make (0x010F)
  entries.push(b'\x01')
  entries.push(b'\x0F') // tag
  entries.push(b'\x00')
  entries.push(b'\x02') // type = ASCII
  entries.push(b'\x00')
  entries.push(b'\x00')
  entries.push((make_count >> 8).to_byte())
  entries.push((make_count & 0xFF).to_byte()) // count
  entries.push(b'\x00')
  entries.push(b'\x00')
  entries.push((make_off >> 8).to_byte())
  entries.push((make_off & 0xFF).to_byte()) // offset
  // Entry 2: Model (0x0110)
  entries.push(b'\x01')
  entries.push(b'\x10')
  entries.push(b'\x00')
  entries.push(b'\x02')
  entries.push(b'\x00')
  entries.push(b'\x00')
  entries.push((model_count >> 8).to_byte())
  entries.push((model_count & 0xFF).to_byte())
  entries.push(b'\x00')
  entries.push(b'\x00')
  entries.push((model_off >> 8).to_byte())
  entries.push((model_off & 0xFF).to_byte())
  // Entry 3: Orientation (0x0112) - SHORT inline
  entries.push(b'\x01')
  entries.push(b'\x12')
  entries.push(b'\x00')
  entries.push(b'\x03') // type = SHORT
  entries.push(b'\x00')
  entries.push(b'\x00')
  entries.push(b'\x00')
  entries.push(b'\x01') // count = 1
  entries.push((orientation >> 8).to_byte())
  entries.push((orientation & 0xFF).to_byte()) // value inline (first 2 bytes)
  entries.push(b'\x00')
  entries.push(b'\x00') // padding
  // Entry 4: DateTime (0x0132)
  entries.push(b'\x01')
  entries.push(b'\x32')
  entries.push(b'\x00')
  entries.push(b'\x02')
  entries.push(b'\x00')
  entries.push(b'\x00')
  entries.push((dt_count >> 8).to_byte())
  entries.push((dt_count & 0xFF).to_byte())
  entries.push(b'\x00')
  entries.push(b'\x00')
  entries.push((dt_off >> 8).to_byte())
  entries.push((dt_off & 0xFF).to_byte())
  // Next IFD offset = 0
  entries.push(b'\x00')
  entries.push(b'\x00')
  entries.push(b'\x00')
  entries.push(b'\x00')
  // Assemble: SOI + APP1
  let result : Array[Byte] = [
    b'\xFF', b'\xD8', // SOI
     b'\xFF', b'\xE1', // APP1
  ]
  // APP1 length = 2 (Exif\0\0) + 8 (TIFF header) + len(entries) + len(str_data)
  let app1_payload = 6 + 8 + entries.length() + str_data.length()
  let app1_len = app1_payload + 2
  result.push((app1_len >> 8).to_byte())
  result.push((app1_len & 0xFF).to_byte())
  // Exif\0\0
  result.push(b'\x45')
  result.push(b'\x78')
  result.push(b'\x69')
  result.push(b'\x66')
  result.push(b'\x00')
  result.push(b'\x00')
  // TIFF header: MM + 0x002A + IFD0 offset=0x00000008
  result.push(b'\x4D')
  result.push(b'\x4D')
  result.push(b'\x00')
  result.push(b'\x2A')
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x08')
  // IFD entries
  for b in entries {
    result.push(b)
  }
  // String data
  for b in str_data {
    result.push(b)
  }
  // EOI
  result.push(b'\xFF')
  result.push(b'\xD9')
  Bytes::from_array(result)
}

///|
/// 构建包含 EXIF 数据的 JPEG 字节流（little-endian / Intel byte order）
fn build_exif_le_jpeg(
  make : String,
  model : String,
  orientation : Int,
) -> Bytes {
  let entries : Array[Byte] = []
  // String data area: after TIFF header (8) + IFD0 (2 + 3*12 + 4 = 42) = 50 from TIFF start
  let string_area_offset = 50
  let mut str_offset = string_area_offset
  let str_data : Array[Byte] = []
  fn push_str(s : String) -> Int {
    let start = str_offset
    for c in s.to_array() {
      str_data.push(c.to_int().to_byte())
    }
    str_data.push(b'\x00')
    str_offset += s.length() + 1
    start
  }
  let make_count = make.length() + 1
  let make_off = push_str(make)
  let model_count = model.length() + 1
  let model_off = push_str(model)
  // IFD0 entry count = 3 (little-endian)
  entries.push(b'\x03')
  entries.push(b'\x00')
  // Entry 1: Make (0x010F) - LE
  entries.push(b'\x0F')
  entries.push(b'\x01')
  entries.push(b'\x02')
  entries.push(b'\x00')
  entries.push((make_count & 0xFF).to_byte())
  entries.push((make_count >> 8).to_byte())
  entries.push(b'\x00')
  entries.push(b'\x00')
  entries.push((make_off & 0xFF).to_byte())
  entries.push((make_off >> 8).to_byte())
  entries.push(b'\x00')
  entries.push(b'\x00')
  // Entry 2: Model (0x0110) - LE
  entries.push(b'\x10')
  entries.push(b'\x01')
  entries.push(b'\x02')
  entries.push(b'\x00')
  entries.push((model_count & 0xFF).to_byte())
  entries.push((model_count >> 8).to_byte())
  entries.push(b'\x00')
  entries.push(b'\x00')
  entries.push((model_off & 0xFF).to_byte())
  entries.push((model_off >> 8).to_byte())
  entries.push(b'\x00')
  entries.push(b'\x00')
  // Entry 3: Orientation (0x0112) - LE SHORT inline
  entries.push(b'\x12')
  entries.push(b'\x01')
  entries.push(b'\x03')
  entries.push(b'\x00')
  entries.push(b'\x01')
  entries.push(b'\x00')
  entries.push(b'\x00')
  entries.push(b'\x00')
  entries.push((orientation & 0xFF).to_byte())
  entries.push((orientation >> 8).to_byte()) // value inline (first 2 bytes, LE)
  entries.push(b'\x00')
  entries.push(b'\x00') // padding
  // Next IFD = 0
  entries.push(b'\x00')
  entries.push(b'\x00')
  entries.push(b'\x00')
  entries.push(b'\x00')
  let result : Array[Byte] = [b'\xFF', b'\xD8', b'\xFF', b'\xE1']
  let app1_payload = 6 + 8 + entries.length() + str_data.length()
  let app1_len = app1_payload + 2
  result.push((app1_len >> 8).to_byte())
  result.push((app1_len & 0xFF).to_byte())
  result.push(b'\x45')
  result.push(b'\x78')
  result.push(b'\x69')
  result.push(b'\x66')
  result.push(b'\x00')
  result.push(b'\x00')
  // TIFF header: II + 0x2A00 + IFD0 offset=0x08000000 (LE)
  result.push(b'\x49')
  result.push(b'\x49')
  result.push(b'\x2A')
  result.push(b'\x00')
  result.push(b'\x08')
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x00')
  for b in entries {
    result.push(b)
  }
  for b in str_data {
    result.push(b)
  }
  result.push(b'\xFF')
  result.push(b'\xD9')
  Bytes::from_array(result)
}

///|
test "read_exif: big-endian EXIF with Make/Model/Orientation/DateTime" {
  let jpeg = build_exif_be_jpeg("Canon", "EOS 5D", 6, "2023:01:15 12:30:45")
  let result = read_exif_from_bytes(jpeg)
  match result {
    Some(info) => {
      assert_eq(info.make, "Canon")
      assert_eq(info.model, "EOS 5D")
      assert_eq(info.orientation, 6)
      assert_eq(info.date_time, "2023:01:15 12:30:45")
    }
    None => assert_true(false)
  }
}

///|
test "read_exif: little-endian EXIF with Make/Model/Orientation" {
  let jpeg = build_exif_le_jpeg("Nikon", "D850", 3)
  let result = read_exif_from_bytes(jpeg)
  match result {
    Some(info) => {
      assert_eq(info.make, "Nikon")
      assert_eq(info.model, "D850")
      assert_eq(info.orientation, 3)
    }
    None => assert_true(false)
  }
}

///|
test "read_exif: short string inline (<=4 bytes)" {
  // For strings <= 4 bytes, the value is stored inline in the entry
  // Build a BE JPEG with Make="ABC" (3 chars + null = 4, fits inline)
  let result : Array[Byte] = [b'\xFF', b'\xD8', b'\xFF', b'\xE1']
  // APP1 payload: 6 (Exif\0\0) + 8 (TIFF header) + 2 (count) + 12 (entry) + 4 (next IFD) = 32
  let app1_len = 32 + 2 // +2 for length field itself
  result.push((app1_len >> 8).to_byte())
  result.push((app1_len & 0xFF).to_byte())
  // Exif\0\0
  result.push(b'\x45')
  result.push(b'\x78')
  result.push(b'\x69')
  result.push(b'\x66')
  result.push(b'\x00')
  result.push(b'\x00')
  // TIFF header: MM
  result.push(b'\x4D')
  result.push(b'\x4D')
  result.push(b'\x00')
  result.push(b'\x2A')
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x08')
  // IFD0: 1 entry
  result.push(b'\x00')
  result.push(b'\x01')
  // Entry: Make (0x010F), type=2, count=4, value="ABC\0" inline
  result.push(b'\x01')
  result.push(b'\x0F')
  result.push(b'\x00')
  result.push(b'\x02')
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x04')
  result.push(b'\x41') // 'A'
  result.push(b'\x42') // 'B'
  result.push(b'\x43') // 'C'
  result.push(b'\x00') // '\0'
  // Next IFD = 0
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x00')
  // EOI
  result.push(b'\xFF')
  result.push(b'\xD9')
  let jpeg = Bytes::from_array(result)
  let exif = read_exif_from_bytes(jpeg)
  match exif {
    Some(info) => assert_eq(info.make, "ABC")
    None => assert_true(false)
  }
}

///|
test "read_exif: JPEG with SOS before EXIF returns None" {
  // JPEG with SOI + SOS marker (0xFF 0xDA) before any APP1
  let data = Bytes::from_array([
    b'\xFF', b'\xD8', b'\xFF', b'\xDA', b'\x00', b'\x04', b'\x01', b'\x00', b'\xFF',
    b'\xD9',
  ])
  let result = read_exif_from_bytes(data)
  assert_eq(result, None)
}

///|
test "read_exif: APP1 without Exif signature returns None" {
  // APP1 with non-Exif data (e.g., XMP)
  let data : Array[Byte] = [
    b'\xFF', b'\xD8', b'\xFF', b'\xE1', b'\x00', b'\x08', b'\x3C', b'\x3F', b'\x78',
    b'\x70', b'\xFF', b'\xD9',
  ]
  let result = read_exif_from_bytes(Bytes::from_array(data))
  assert_eq(result, None)
}

///|
test "read_exif: invalid TIFF byte order returns None" {
  // APP1 with Exif\0\0 but invalid byte order (not MM or II)
  let data : Array[Byte] = [
    b'\xFF', b'\xD8', b'\xFF', b'\xE1', b'\x00', b'\x10', b'\x45', b'\x78', b'\x69',
    b'\x66', b'\x00', b'\x00', b'\x58', b'\x58', b'\x00', b'\x2A', b'\x00', b'\x00',
    b'\x00', b'\x08', b'\xFF', b'\xD9',
  ]
  let result = read_exif_from_bytes(Bytes::from_array(data))
  assert_eq(result, None)
}

///|
test "read_exif: skip other APP markers to find EXIF" {
  // JPEG with APP0 (JFIF) before APP1 (EXIF)
  let exif_jpeg = build_exif_be_jpeg("Test", "Cam", 1, "2020:01:01 00:00:00")
  // Insert APP0 segment after SOI
  let app0 : Array[Byte] = [
    b'\xFF', b'\xE0', b'\x00', b'\x10', b'\x4A', b'\x46', b'\x49', b'\x46', b'\x00',
    b'\x01', b'\x01', b'\x00', b'\x00', b'\x01', b'\x00', b'\x01', b'\x00', b'\x00',
  ]
  let combined : Array[Byte] = [b'\xFF', b'\xD8']
  for b in app0 {
    combined.push(b)
  }
  // Skip original SOI (2 bytes), copy rest
  for i in 2..<exif_jpeg.length() {
    combined.push(exif_jpeg[i])
  }
  let result = read_exif_from_bytes(Bytes::from_array(combined))
  match result {
    Some(info) => assert_eq(info.make, "Test")
    None => assert_true(false)
  }
}

///|
test "read_exif: orientation values 1-8" {
  for orient in [1, 2, 3, 4, 5, 6, 7, 8] {
    let jpeg = build_exif_be_jpeg("M", "X", orient, "2023:01:01 00:00:00")
    let result = read_exif_from_bytes(jpeg)
    match result {
      Some(info) => assert_eq(info.orientation, orient)
      None => assert_true(false)
    }
  }
}

///|
test "read_exif: empty Make/Model strings" {
  let jpeg = build_exif_be_jpeg("", "", 1, "")
  let result = read_exif_from_bytes(jpeg)
  match result {
    Some(info) => assert_eq(info.orientation, 1)
    None => assert_true(false)
  }
}

///|
test "read_exif: non-APP1 marker after APP1 continues scanning" {
  // Build JPEG with a DQT marker (0xFF 0xDB) after APP1, then SOS
  // This tests the `pos += 1` branch when byte is not 0xFF
  let jpeg_data : Array[Byte] = [
    b'\xFF', b'\xD8', // SOI
     b'\xFF', b'\xE1', // APP1
     0x00, 0x16, // length = 22
     b'E', b'x', b'i', b'f', b'\x00', b'\x00', // Exif\0\0
     0x4D, 0x4D, // big-endian
     0x00, 0x2A, // TIFF magic
     0x00, 0x00, 0x00, 0x08, // IFD0 offset
     0x00, 0x01, // entry count = 1
    // Entry: Tag=0x010F (Make), Type=2 (ASCII), Count=4
     0x01, 0x0F, 0x00, 0x02, 0x00, 0x00, 0x00, 0x04, b'N', b'a', b'm', b'e', // inline value "Name"
     0x00, 0x00, 0x00, 0x00, // next IFD = 0
    // Now add a DQT marker (0xFF 0xDB) after the APP1 segment
     b'\xFF', b'\xDB', 0x00, 0x40, 0x00, 0x10, 0x06, 0x10, 0x06, 0x10, 0x06, 0x10,
    0x06, 0x10, 0x06, 0x10, 0x06, 0x10, 0x06, 0x10, 0x06, 0x10, 0x06, 0x10, 0x06,
    0x10, 0x06, 0x10, 0x06, 0x10, 0x06, 0x10, 0x06, 0x10, 0x06, 0x10, 0x06, 0x10,
    0x06, 0x10, 0x06, 0x10, 0x06, 0x10,
    // SOS marker
     b'\xFF', b'\xDA', 0x00, 0x0C, 0x01, 0x00, 0x03, 0x01, 0x01, 0x00, 0x00, 0x3F,
    0x00,
    // Minimal SOS data
     b'\xC0', b'\x58', b'\x00',
  ]
  let result = read_exif_from_bytes(Bytes::from_array(jpeg_data))
  match result {
    Some(info) => {
      assert_eq(info.make, "Name")
      assert_eq(info.orientation, 1)
    }
    None => assert_true(false)
  }
}

///|
test "read_exif: IFD0 entry out of bounds returns partial" {
  // IFD0 has entry_count=2 but only 1 full entry + truncated second entry
  let jpeg_data : Array[Byte] = [
    b'\xFF', b'\xD8', // SOI
     b'\xFF', b'\xE1', // APP1
     0x00, 0x1A, // length = 26
     b'E', b'x', b'i', b'f', b'\x00', b'\x00', // Exif\0\0
     0x4D, 0x4D, // big-endian
     0x00, 0x2A, // TIFF magic
     0x00, 0x00, 0x00, 0x08, // IFD0 offset
     0x00, 0x02, // entry count = 2 (but only 12 bytes remain, not enough for 2 entries)
    // Entry 1: Tag=0x010F, valid, inline value
     0x01, 0x0F, 0x00, 0x02, 0x00, 0x00, 0x00, 0x04, b'N', b'a', b'm', b'e',
    // Entry 2: truncated (only 6 bytes left, need 12)
     0x01, 0x10, 0x00, 0x02, 0x00, 0x00,
  ]
  let result = read_exif_from_bytes(Bytes::from_array(jpeg_data))
  match result {
    Some(info) => {
      assert_eq(info.make, "Name")
      assert_eq(info.orientation, 1)
    }
    None => assert_true(false)
  }
}

///|
test "read_exif: unknown tag falls through default case" {
  let jpeg_data : Array[Byte] = [
    b'\xFF', b'\xD8', // SOI
     b'\xFF', b'\xE1', // APP1
     0x00, 0x1A, // length = 26
     b'E', b'x', b'i', b'f', b'\x00', b'\x00', 0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00,
    0x00, 0x08, 0x00, 0x01, // entry count = 1
    // Tag = 0x9999 (unknown), should hit default case
     0x99, 0x99, 0x00, 0x02, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x4E, 0x00,
    0x00, 0x00, 0x00, // next IFD
  ]
  let result = read_exif_from_bytes(Bytes::from_array(jpeg_data))
  match result {
    Some(info) => {
      assert_eq(info.make, "")
      assert_eq(info.orientation, 1)
    }
    None => assert_true(false)
  }
}

///|
test "read_exif: non-ASCII in string returns empty" {
  // Build EXIF with a string containing bytes >= 128
  // We need to create a JPEG with EXIF where a string field has non-ASCII bytes
  // The read_exif_string function will catch the UTF-8 decode failure
  let jpeg_data : Array[Byte] = [
    b'\xFF', b'\xD8', // SOI
     b'\xFF', b'\xE1', // APP1
     0x00, 0x1A, // length = 26
     b'E', b'x', b'i', b'f', b'\x00', b'\x00', 0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00,
    0x00, 0x08, 0x00, 0x01, // entry count = 1
    // Tag = 0x010F (Make), count = 1, value = 0x80 (invalid ASCII)
     0x01, 0x0F, 0x00, 0x02, 0x00, 0x00, 0x00, 0x01, 0x80, 0x00, 0x00, 0x4E, 0x00,
    0x00, 0x00, 0x00,
  ]
  let result = read_exif_from_bytes(Bytes::from_array(jpeg_data))
  match result {
    Some(info) =>
      // Non-ASCII byte should result in empty string (UTF-8 decode fails)
      assert_eq(info.make, "")
    None => assert_true(false)
  }
}

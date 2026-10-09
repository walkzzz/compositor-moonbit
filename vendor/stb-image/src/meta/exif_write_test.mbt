// EXIF 写入测试

///|
test "create_exif_segment: starts with Exif\\0\\0" {
  let info = ExifInfo::{
    make: "Canon",
    model: "EOS",
    orientation: 1,
    date_time: "",
  }
  let segment = create_exif_segment(info)
  assert_eq(segment[0].to_int(), 0x45) // 'E'
  assert_eq(segment[1].to_int(), 0x78) // 'x'
  assert_eq(segment[2].to_int(), 0x69) // 'i'
  assert_eq(segment[3].to_int(), 0x66) // 'f'
  assert_eq(segment[4].to_int(), 0x00)
  assert_eq(segment[5].to_int(), 0x00)
  let _ = info
  let _ = segment
}

///|
test "create_exif_segment: TIFF header big-endian" {
  let info = ExifInfo::{ make: "", model: "", orientation: 1, date_time: "" }
  let segment = create_exif_segment(info)
  assert_eq(segment[6].to_int(), 0x4D) // 'M'
  assert_eq(segment[7].to_int(), 0x4D) // 'M'
  assert_eq(segment[8].to_int(), 0x00)
  assert_eq(segment[9].to_int(), 0x2A) // TIFF magic
  let _ = info
  let _ = segment
}

///|
test "create_exif_segment: IFD entry count is 4" {
  let info = ExifInfo::{ make: "X", model: "Y", orientation: 3, date_time: "Z" }
  let segment = create_exif_segment(info)
  // IFD0 starts at offset 14 (6 Exif + 8 TIFF header)
  assert_eq(segment[14].to_int(), 0x00)
  assert_eq(segment[15].to_int(), 0x04) // 4 entries
  let _ = info
  let _ = segment
}

///|
test "write_exif_to_bytes: invalid JPEG raises error" {
  let info = ExifInfo::{ make: "", model: "", orientation: 1, date_time: "" }
  let bad_data = Bytes::from_array([b'\x00', b'\x00'])
  try {
    let _ = write_exif_to_bytes(info, bad_data)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
  let _ = info
  let _ = bad_data
}

///|
test "write_exif_to_bytes: roundtrip with full ExifInfo" {
  let info = ExifInfo::{
    make: "Canon",
    model: "EOS 5D",
    orientation: 6,
    date_time: "2023:01:15 12:30:45",
  }
  let jpeg = Bytes::from_array([b'\xFF', b'\xD8', b'\xFF', b'\xD9'])
  let result = write_exif_to_bytes(info, jpeg)
  assert_eq(result[0].to_int(), 0xFF)
  assert_eq(result[1].to_int(), 0xD8)
  assert_eq(result[2].to_int(), 0xFF)
  assert_eq(result[3].to_int(), 0xE1)
  let read_back = read_exif_from_bytes(result)
  match read_back {
    Some(r) => {
      assert_eq(r.make, "Canon")
      assert_eq(r.model, "EOS 5D")
      assert_eq(r.orientation, 6)
      assert_eq(r.date_time, "2023:01:15 12:30:45")
    }
    None => assert_true(false)
  }
  let _ = info
  let _ = jpeg
  let _ = result
}

///|
test "write_exif_to_bytes: roundtrip with empty strings" {
  let info = ExifInfo::{ make: "", model: "", orientation: 1, date_time: "" }
  let jpeg = Bytes::from_array([b'\xFF', b'\xD8', b'\xFF', b'\xD9'])
  let result = write_exif_to_bytes(info, jpeg)
  let read_back = read_exif_from_bytes(result)
  match read_back {
    Some(r) => assert_eq(r.orientation, 1)
    None => assert_true(false)
  }
  let _ = info
  let _ = jpeg
  let _ = result
}

///|
test "write_exif_to_bytes: roundtrip with short strings (inline)" {
  let info = ExifInfo::{
    make: "ABC",
    model: "DE",
    orientation: 3,
    date_time: "FG",
  }
  let jpeg = Bytes::from_array([b'\xFF', b'\xD8', b'\xFF', b'\xD9'])
  let result = write_exif_to_bytes(info, jpeg)
  let read_back = read_exif_from_bytes(result)
  match read_back {
    Some(r) => {
      assert_eq(r.make, "ABC")
      assert_eq(r.model, "DE")
      assert_eq(r.orientation, 3)
      assert_eq(r.date_time, "FG")
    }
    None => assert_true(false)
  }
  let _ = info
  let _ = jpeg
  let _ = result
}

///|
test "write_exif_to_bytes: replaces existing APP1" {
  let original_info = ExifInfo::{
    make: "Old",
    model: "Cam",
    orientation: 1,
    date_time: "2020:01:01 00:00:00",
  }
  let original_jpeg = write_exif_to_bytes(
    original_info,
    Bytes::from_array([b'\xFF', b'\xD8', b'\xFF', b'\xD9']),
  )
  let new_info = ExifInfo::{
    make: "NewCamera",
    model: "NewModel",
    orientation: 8,
    date_time: "2025:06:15 10:20:30",
  }
  let result = write_exif_to_bytes(new_info, original_jpeg)
  let read_back = read_exif_from_bytes(result)
  match read_back {
    Some(r) => {
      assert_eq(r.make, "NewCamera")
      assert_eq(r.model, "NewModel")
      assert_eq(r.orientation, 8)
      assert_eq(r.date_time, "2025:06:15 10:20:30")
    }
    None => assert_true(false)
  }
  let _ = original_info
  let _ = original_jpeg
  let _ = new_info
  let _ = result
}

///|
test "write_exif_to_bytes: preserves JPEG data after APP1" {
  let jpeg_data : Array[Byte] = [
    b'\xFF', b'\xD8', b'\xFF', b'\xE0', b'\x00', b'\x04', b'\x00', b'\x00', b'\xFF',
    b'\xD9',
  ]
  let jpeg = Bytes::from_array(jpeg_data)
  let info = ExifInfo::{
    make: "Test",
    model: "X",
    orientation: 1,
    date_time: "",
  }
  let result = write_exif_to_bytes(info, jpeg)
  let len = result.length()
  assert_eq(result[len - 2].to_int(), 0xFF)
  assert_eq(result[len - 1].to_int(), 0xD9)
  let _ = jpeg_data
  let _ = jpeg
  let _ = info
  let _ = result
}

///|
test "write_exif_to_bytes: orientation values 1-8 roundtrip" {
  for orient in [1, 2, 3, 4, 5, 6, 7, 8] {
    let info = ExifInfo::{
      make: "M",
      model: "X",
      orientation: orient,
      date_time: "",
    }
    let jpeg = Bytes::from_array([b'\xFF', b'\xD8', b'\xFF', b'\xD9'])
    let result = write_exif_to_bytes(info, jpeg)
    let read_back = read_exif_from_bytes(result)
    match read_back {
      Some(r) => assert_eq(r.orientation, orient)
      None => assert_true(false)
    }
  }
}

///|
test "write_exif_to_bytes: non-ASCII string replaces with ?" {
  // string_to_exif_bytes should replace bytes >= 128 with '?'
  let info = ExifInfo::{
    make: "Test\u{80}\u{FF}",
    model: "X",
    orientation: 1,
    date_time: "",
  }
  let jpeg = Bytes::from_array([b'\xFF', b'\xD8', b'\xFF', b'\xD9'])
  let result = write_exif_to_bytes(info, jpeg)
  // Verify the EXIF was written (has APP1 marker)
  assert_eq(result[2].to_int(), 0xFF)
  assert_eq(result[3].to_int(), 0xE1)
  // Read back and verify non-ASCII was replaced
  let read_back = read_exif_from_bytes(result)
  match read_back {
    Some(r) =>
      // Non-ASCII bytes should be replaced with '?'
      assert_true(r.make.contains("?"))
    None => assert_true(false)
  }
}

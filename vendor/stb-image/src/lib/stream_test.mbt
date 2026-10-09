// 流式解码测试

///|
fn make_bmp(w : Int, h : Int, color : Byte) -> Bytes {
  // 构造 w x h 24-bit BMP（bottom-up，行填充到4字节）
  let row_stride = (w * 3 + 3) / 4 * 4
  let pixel_size = row_stride * h
  let file_size = 54 + pixel_size
  let data : Array[Byte] = Array::make(file_size, b'\x00')
  // BMP header
  data[0] = b'\x42'
  data[1] = b'\x4D'
  data[2] = (file_size & 0xFF).to_byte()
  data[3] = ((file_size >> 8) & 0xFF).to_byte()
  data[10] = 54
  data[14] = 40
  data[18] = (w & 0xFF).to_byte()
  data[22] = (h & 0xFF).to_byte()
  data[26] = 1
  data[28] = 24
  data[34] = (pixel_size & 0xFF).to_byte()
  data[35] = ((pixel_size >> 8) & 0xFF).to_byte()
  // 像素数据（BGR，bottom-up）
  for y in 0..<h {
    for x in 0..<w {
      let idx = 54 + y * row_stride + x * 3
      data[idx] = color // B
      data[idx + 1] = color // G
      data[idx + 2] = color // R
    }
  }
  Bytes::from_array(data)
}

///|
test "decode_stream 逐行回调" {
  let bmp = make_bmp(2, 2, b'\x80')
  let rows : Array[Int] = []
  let info = decode_stream(bmp, fn(y, _row) { rows.push(y) })
  assert_eq(info.width, 2)
  assert_eq(info.height, 2)
  assert_eq(info.channels, 3)
  assert_eq(rows.length(), 2)
  assert_eq(rows[0], 0)
  assert_eq(rows[1], 1)
}

///|
test "decode_stream 行数据长度" {
  let bmp = make_bmp(3, 1, b'\xFF')
  let row_lens : Array[Int] = []
  let info = decode_stream(bmp, fn(_y, row) { row_lens.push(row.length()) })
  assert_eq(info.width, 3)
  assert_eq(info.height, 1)
  assert_eq(row_lens[0], 9) // 3 * 3
}

///|
test "decode_stream_chunked 分块回调" {
  let bmp = make_bmp(2, 4, b'\x80')
  let chunks : Array[Int] = []
  let block_heights : Array[Int] = []
  let info = decode_stream_chunked(bmp, 2, fn(start_y, block_img) {
    chunks.push(start_y)
    block_heights.push(block_img.height)
  })
  assert_eq(info.width, 2)
  assert_eq(info.height, 4)
  assert_eq(chunks.length(), 2)
  assert_eq(chunks[0], 0)
  assert_eq(chunks[1], 2)
  assert_eq(block_heights[0], 2)
  assert_eq(block_heights[1], 2)
}

///|
test "decode_stream_chunked 不整除" {
  let bmp = make_bmp(2, 5, b'\x80')
  let heights : Array[Int] = []
  let info = decode_stream_chunked(bmp, 2, fn(_y, block_img) {
    heights.push(block_img.height)
  })
  assert_eq(info.height, 5)
  assert_eq(heights.length(), 3)
  assert_eq(heights[0], 2)
  assert_eq(heights[1], 2)
  assert_eq(heights[2], 1)
}

///|
test "decode_stream_channels 指定通道" {
  let bmp = make_bmp(2, 2, b'\x80')
  let row_lens : Array[Int] = []
  let info = decode_stream_channels(bmp, 1, fn(_y, row) {
    row_lens.push(row.length())
  })
  assert_eq(info.channels, 1)
  assert_eq(row_lens[0], 2) // 2 * 1
}

///|
test "decode_stream StreamInfo 正确" {
  let bmp = make_bmp(3, 2, b'\x80')
  let info = decode_stream(bmp, fn(_y, _row) {  })
  assert_eq(info.width, 3)
  assert_eq(info.height, 2)
  assert_eq(info.channels, 3)
}

///|
test "decode_stream 1x1 最小图" {
  // 使用现有的 1x1 红色 BMP
  let bmp = b"\x42\x4D\x3A\x00\x00\x00\x00\x00\x00\x00\x36\x00\x00\x00\x28\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01\x00\x18\x00\x00\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xFF\x00"
  let row_count : Array[Int] = []
  let info = decode_stream(bmp, fn(_y, _row) { row_count.push(1) })
  assert_eq(info.width, 1)
  assert_eq(info.height, 1)
  assert_eq(row_count.length(), 1)
}

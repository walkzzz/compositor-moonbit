// 示例 21-22：WebP 编解码 + 流式解码（v4.8 新功能）

///|
test "example_21: WebP lossy encode and decode" {
  let img = @img.load_from_bytes(test_4x4_red_png, req_channels=Some(3))
  let webp_bytes = @img.encode_webp_lossy(img)
  assert_true(webp_bytes.length() > 0)
  assert_eq(webp_bytes[0], b'R')
  assert_eq(webp_bytes[1], b'I')
  assert_eq(webp_bytes[2], b'F')
  assert_eq(webp_bytes[3], b'F')
  let webp_high = @img.encode_webp_lossy(img, quality=90)
  let webp_low = @img.encode_webp_lossy(img, quality=10)
  assert_true(webp_high.length() > 0)
  assert_true(webp_low.length() > 0)
}

///|
test "example_22: streaming decode with row callback" {
  let mut row_count = 0
  let info = @img.decode_stream(test_4x4_red_png, fn(_y, _row) {
    row_count = row_count + 1
  })
  assert_eq(row_count, info.height)
  assert_eq(info.width, 4)
  assert_eq(info.height, 4)
}

///|
test "example_22b: streaming decode chunked" {
  let mut chunk_count = 0
  let info = @img.decode_stream_chunked(test_4x4_red_png, 2, fn(
    _start_y,
    _chunk_img,
  ) {
    chunk_count = chunk_count + 1
  })
  ignore(info)
  assert_eq(chunk_count, 2)
}

///|
test "edge_detect_laplacian: uniform image returns black" {
  let img = @types.Image::{
    width: 3,
    height: 3,
    channels: 1,
    data: Array::make(9, b'\x80') |> Bytes::from_array,
  }
  let result = edge_detect_laplacian(img)
  for i in 0..<9 {
    assert_eq(result.data[i].to_int(), 0)
  }
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "edge_detect_prewitt: uniform image returns black" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Array::make(16, b'\x80') |> Bytes::from_array,
  }
  let result = edge_detect_prewitt(img)
  for i in 0..<16 {
    assert_eq(result.data[i].to_int(), 0)
  }
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "edge_detect_laplacian: detects edge in half-black image" {
  // 4x4 图像：左半黑，右半白
  let data = Array::make(16, b'\x00')
  for y in 0..<4 {
    for x in 2..<4 {
      data[y * 4 + x] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let result = edge_detect_laplacian(img)
  // 边界处应有响应（x=1 和 x=2 之间）
  let has_edge = result.data[1 * 4 + 1].to_int() > 0 ||
    result.data[1 * 4 + 2].to_int() > 0
  assert_true(has_edge)
  let _ = img
  let _ = result
}

///|
test "edge_detect_prewitt: detects edge in half-black image" {
  // 4x4 图像：上半黑，下半白
  let data = Array::make(16, b'\x00')
  for y in 2..<4 {
    for x in 0..<4 {
      data[y * 4 + x] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let result = edge_detect_prewitt(img)
  // 边界处应有响应
  let has_edge = result.data[1 * 4 + 0].to_int() > 0 ||
    result.data[2 * 4 + 0].to_int() > 0
  assert_true(has_edge)
  let _ = img
  let _ = result
}

///|
test "edge_detect_laplacian: preserves dimensions" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let result = edge_detect_laplacian(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "edge_detect_prewitt: preserves dimensions" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let result = edge_detect_prewitt(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "edge_detect_laplacian: works with RGB image" {
  // 红色图像（均匀），边缘检测应返回全黑
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let result = edge_detect_laplacian(img)
  // 均匀红色图无边缘
  for i in 0..<16 {
    assert_eq(result.data[i].to_int(), 0)
  }
  let _ = img
  let _ = result
}

///|
test "edge_detect_prewitt: works with grayscale image" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Array::make(16, b'\x40') |> Bytes::from_array,
  }
  let result = edge_detect_prewitt(img)
  for i in 0..<16 {
    assert_eq(result.data[i].to_int(), 0)
  }
  let _ = img
  let _ = result
}

///|
test "edge_detect_sobel: uniform image has no edges" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 3,
    data: Array::make(48, b'\x80') |> Bytes::from_array,
  }
  let result = edge_detect_sobel(img)
  assert_eq(result.channels, 1)
  for i in 0..<16 {
    assert_eq(result.data[i].to_int(), 0)
  }
  let _ = img
  let _ = result
}

///|
test "edge_detect_sobel: detects edges in non-uniform image" {
  // 左半黑右半白
  let data : Array[Byte] = Array::make(4 * 4 * 3, b'\x00')
  for y in 0..<4 {
    for x in 2..<4 {
      for c in 0..<3 {
        data[(y * 4 + x) * 3 + c] = b'\xFF'
      }
    }
  }
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let result = edge_detect_sobel(img)
  assert_eq(result.channels, 1)
  // 中间列应该有边缘
  let mut has_edge = false
  for i in 0..<16 {
    if result.data[i].to_int() > 0 {
      has_edge = true
    }
  }
  assert_true(has_edge)
  let _ = img
  let _ = result
}

///|
test "edge_detect_sobel: output dimensions match input" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let result = edge_detect_sobel(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

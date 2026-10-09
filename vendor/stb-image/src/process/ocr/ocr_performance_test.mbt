// v13.5.0 OCR 性能优化测试

///|
fn make_perf_img(w : Int, h : Int) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(Array::make(w * h, b'\x80')),
  }
}

///|
test "build_grayscale_lut: 256个元素" {
  let lut = build_grayscale_lut()
  assert_eq(lut.length(), 256)
  assert_eq(lut[0], 0)
  assert_eq(lut[255], 255)
}

///|
test "build_threshold_lut: 阈值128" {
  let lut = build_threshold_lut(128)
  assert_eq(lut.length(), 256)
  assert_eq(lut[0], 0)
  assert_eq(lut[127], 0)
  assert_eq(lut[128], 255)
  assert_eq(lut[255], 255)
}

///|
test "fast_threshold_lut: 基本二值化" {
  let img = make_perf_img(16, 16)
  let lut = build_threshold_lut(64)
  let result = fast_threshold_lut(img, lut)
  assert_eq(result.width, 16)
  assert_eq(result.height, 16)
}

///|
test "fast_threshold_lut: 无效图像抛异常" {
  let img = @types.Image::{
    width: 0,
    height: 0,
    channels: 1,
    data: Bytes::from_array([]),
  }
  let lut = build_threshold_lut(128)
  try {
    ignore(fast_threshold_lut(img, lut))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "cache_friendly_horizontal_projection: 基本投影" {
  let img = make_perf_img(16, 16)
  let proj = cache_friendly_horizontal_projection(img)
  assert_eq(proj.length(), 16)
  for i in 0..<16 {
    assert_true(proj[i] > 0)
  }
}

///|
test "cache_friendly_vertical_projection: 基本投影" {
  let img = make_perf_img(16, 16)
  let proj = cache_friendly_vertical_projection(img)
  assert_eq(proj.length(), 16)
  for i in 0..<16 {
    assert_true(proj[i] > 0)
  }
}

///|
test "unrolled_pixel_sum: 正确求和" {
  let img = make_perf_img(4, 4)
  let sum = unrolled_pixel_sum(img)
  // 4x4 图像，每个像素 0x80 = 128
  assert_eq(sum, 4 * 4 * 128)
}

///|
test "fast_connected_components: 基本连通域" {
  let img = make_perf_img(16, 16)
  let labels = fast_connected_components(img)
  assert_eq(labels.length(), 256)
}

///|
test "build_gaussian_kernel_lut: 核权重和为1" {
  let kernel = build_gaussian_kernel_lut(1.0, 2)
  assert_eq(kernel.length(), 5)
  let mut sum = 0.0
  for i in 0..<5 {
    sum += kernel[i]
  }
  assert_true((sum - 1.0).abs() < 0.001)
}

///|
test "build_gaussian_kernel_lut: 无效sigma抛异常" {
  try {
    ignore(build_gaussian_kernel_lut(0.0, 2))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "fast_gaussian_blur_1d: 基本模糊" {
  let img = make_perf_img(16, 16)
  let kernel = build_gaussian_kernel_lut(1.0, 2)
  let result = fast_gaussian_blur_1d(img, kernel)
  assert_eq(result.width, 16)
  assert_eq(result.height, 16)
}

///|
test "batch_recognize_chars: 批量识别" {
  let config = create_default_char_cnn_config(3)
  let labels = ["A", "B", "C"]
  let img1 = make_perf_img(16, 16)
  let img2 = make_perf_img(20, 20)
  let results = batch_recognize_chars([img1, img2], config, labels)
  assert_eq(results.length(), 2)
}

///|
test "batch_recognize_chars: 空列表抛异常" {
  let config = create_default_char_cnn_config(2)
  let labels = ["A", "B"]
  try {
    ignore(batch_recognize_chars([], config, labels))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "ocr_pipeline_stats: 基本统计" {
  let img = make_perf_img(16, 16)
  let (pixels, bytes, avg) = ocr_pipeline_stats(img)
  assert_eq(pixels, 256)
  assert_eq(bytes, 256)
  assert_true(avg >= 0.0 && avg <= 255.0)
}

///|
test "fast_downsample_2x: 基本降采样" {
  let img = make_perf_img(16, 16)
  let result = fast_downsample_2x(img)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "fast_downsample_2x: 无效尺寸抛异常" {
  let img = make_perf_img(1, 1)
  try {
    ignore(fast_downsample_2x(img))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

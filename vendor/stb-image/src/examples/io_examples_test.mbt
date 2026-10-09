// 示例 1-3：基础 I/O 操作
// 演示图像加载、保存、格式检测、格式转换

///|
test "example_01: load PNG and re-encode to BMP/JPEG/TGA" {
  // 从嵌入的测试数据加载 4x4 红色 PNG
  let img = @img.load_from_bytes(test_4x4_red_png)
  assert_eq(img.width, 4)
  assert_eq(img.height, 4)
  // 编码为 BMP
  let bmp_bytes = @img.write_bmp_to_bytes(img)
  assert_true(@img.detect_format(bmp_bytes) is @types.ImageFormat::Bmp)
  // 编码为 JPEG
  let jpeg_bytes = @img.write_jpeg_to_bytes(img)
  assert_true(@img.detect_format(jpeg_bytes) is @types.ImageFormat::Jpeg)
  // 编码为 TGA（注意：TGA 无固定 magic bytes，detect_format 返回 Unknown）
  let tga_bytes = @img.write_tga_to_bytes(img)
  assert_true(@img.detect_format(tga_bytes) is @types.ImageFormat::Unknown)
  // 编码为 PNG（往返）
  let png_bytes = @img.write_png_to_bytes(img)
  let img2 = @img.load_from_bytes(png_bytes)
  assert_eq(img2.width, img.width)
  assert_eq(img2.height, img.height)
}

///|
test "example_02: detect image format from magic bytes" {
  // PNG: \x89PNG
  assert_true(@img.detect_format(test_4x4_red_png) is @types.ImageFormat::Png)
  // BMP: BM
  assert_true(@img.detect_format(test_4x4_red_bmp) is @types.ImageFormat::Bmp)
  // GIF: GIF87a
  assert_true(@img.detect_format(test_4x4_red_gif) is @types.ImageFormat::Gif)
  // JPEG: \xFF\xD8\xFF
  assert_true(@img.detect_format(test_4x4_red_jpg) is @types.ImageFormat::Jpeg)
  // 无效数据
  assert_true(
    @img.detect_format(corrupt_random_bin) is @types.ImageFormat::Unknown,
  )
  // is_supported_format 便捷函数
  assert_true(@img.is_supported_format(test_4x4_red_png))
  assert_false(@img.is_supported_format(corrupt_random_bin))
}

///|
test "example_03: format conversion round-trip PNG -> BMP -> PNG" {
  let original = @img.load_from_bytes(test_4x4_red_png, req_channels=Some(3))
  // PNG -> BMP bytes
  let bmp_bytes = @img.write_bmp_to_bytes(original)
  // BMP -> Image
  let from_bmp = @img.load_from_bytes(bmp_bytes, req_channels=Some(3))
  assert_eq(from_bmp.width, original.width)
  assert_eq(from_bmp.height, original.height)
  // BMP -> PNG bytes
  let png_bytes = @img.write_png_to_bytes(from_bmp)
  // PNG -> Image，验证往返保持像素数据
  let round_tripped = @img.load_from_bytes(png_bytes, req_channels=Some(3))
  assert_eq(round_tripped.data, original.data)
  // 也可以用 PNM/PPM 格式
  let ppm_bytes = @img.encode_ppm(original)
  assert_true(@img.detect_format(ppm_bytes) is @types.ImageFormat::Pnm)
  let from_ppm = @img.load_from_bytes(ppm_bytes, req_channels=Some(3))
  assert_eq(from_ppm.data, original.data)
}

// reexport.mbt 公开 API 测试
// 覆盖 reexport.mbt 中未覆盖的转发函数

///|
fn re_make_rgb(
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
test "reexport: detect_format BMP" {
  let img = re_make_rgb(2, 2, [(0, 0, 0), (255, 0, 0), (0, 255, 0), (0, 0, 255)])
  let bmp_bytes = @codec.encode_bmp_pure(img)
  assert_true(detect_format(bmp_bytes) is @types.ImageFormat::Bmp)
}

///|
test "reexport: detect_format PNG" {
  let img = re_make_rgb(2, 2, [(0, 0, 0), (255, 0, 0), (0, 255, 0), (0, 0, 255)])
  let png_bytes = @codec.encode_png_pure(img)
  assert_true(detect_format(png_bytes) is @types.ImageFormat::Png)
}

///|
test "reexport: detect_format JPEG" {
  let img = re_make_rgb(2, 2, [(0, 0, 0), (255, 0, 0), (0, 255, 0), (0, 0, 255)])
  let jpeg_bytes = @codec.encode_jpeg_pure(img)
  assert_true(detect_format(jpeg_bytes) is @types.ImageFormat::Jpeg)
}

///|
test "reexport: detect_format unknown" {
  let data = b"\x00\x01\x02\x03"
  assert_true(detect_format(data) is @types.ImageFormat::Unknown)
}

///|
test "reexport: is_supported_format" {
  let img = re_make_rgb(1, 1, [(128, 128, 128)])
  let bmp_bytes = @codec.encode_bmp_pure(img)
  assert_true(is_supported_format(bmp_bytes))
  assert_false(is_supported_format(b"\x00\x01\x02\x03"))
}

///|
test "reexport: decode_any BMP" {
  let img = re_make_rgb(2, 2, [
    (10, 20, 30),
    (40, 50, 60),
    (70, 80, 90),
    (100, 110, 120),
  ])
  let bmp_bytes = @codec.encode_bmp_pure(img)
  let restored = decode_any(bmp_bytes)
  assert_eq(restored.width, 2)
  assert_eq(restored.height, 2)
}

///|
test "reexport: load_from_bytes PNG" {
  let img = re_make_rgb(2, 2, [
    (10, 20, 30),
    (40, 50, 60),
    (70, 80, 90),
    (100, 110, 120),
  ])
  let png_bytes = @codec.encode_png_pure(img)
  let restored = load_from_bytes(png_bytes)
  assert_eq(restored.width, 2)
  assert_eq(restored.height, 2)
  assert_eq(restored.channels, 3)
  // PNG 无损，像素应一致
  assert_eq(restored.data[0].to_int(), 10)
  assert_eq(restored.data[1].to_int(), 20)
  assert_eq(restored.data[2].to_int(), 30)
}

///|
test "reexport: load_from_bytes with req_channels" {
  let img = re_make_rgb(2, 2, [
    (10, 20, 30),
    (40, 50, 60),
    (70, 80, 90),
    (100, 110, 120),
  ])
  let png_bytes = @codec.encode_png_pure(img)
  let restored = load_from_bytes(png_bytes, req_channels=Some(3))
  assert_eq(restored.width, 2)
  assert_eq(restored.height, 2)
}

///|
test "reexport: load_f_from_bytes HDR" {
  // 构造 1x1 HDR ImageF
  let fdata : Array[Byte] = []
  let rb = 1.0F.to_le_bytes()
  let gb = 0.5F.to_le_bytes()
  let bb = 0.25F.to_le_bytes()
  for i in 0..<4 {
    fdata.push(rb[i])
  }
  for i in 0..<4 {
    fdata.push(gb[i])
  }
  for i in 0..<4 {
    fdata.push(bb[i])
  }
  let imgf = @types.ImageF::{
    width: 1,
    height: 1,
    channels: 3,
    data: Bytes::from_array(fdata),
  }
  let hdr_bytes = @codec.encode_hdr_pure(imgf)
  let restored = load_f_from_bytes(hdr_bytes)
  assert_eq(restored.width, 1)
  assert_eq(restored.height, 1)
  assert_eq(restored.channels, 3)
}

///|
test "reexport: write_bmp_to_bytes" {
  let img = re_make_rgb(1, 1, [(255, 0, 0)])
  let bmp_bytes = write_bmp_to_bytes(img)
  // BMP magic "BM"
  assert_eq(bmp_bytes[0].to_int(), 0x42)
  assert_eq(bmp_bytes[1].to_int(), 0x4D)
}

///|
test "reexport: write_jpeg_to_bytes" {
  let img = re_make_rgb(2, 2, [
    (128, 128, 128),
    (64, 64, 64),
    (192, 192, 192),
    (32, 32, 32),
  ])
  let jpeg_bytes = write_jpeg_to_bytes(img)
  // JPEG SOI
  assert_eq(jpeg_bytes[0].to_int(), 0xFF)
  assert_eq(jpeg_bytes[1].to_int(), 0xD8)
}

///|
test "reexport: write_tga_to_bytes" {
  let img = re_make_rgb(2, 2, [
    (255, 0, 0),
    (0, 255, 0),
    (0, 0, 255),
    (255, 255, 255),
  ])
  let tga_bytes = write_tga_to_bytes(img)
  // TGA 应可被 decode_tga_pure 解回
  let restored = @codec.decode_tga_pure(tga_bytes)
  assert_eq(restored.width, 2)
  assert_eq(restored.height, 2)
}

///|
test "reexport: resize" {
  let img = re_make_rgb(4, 4, Array::make(16, (128, 128, 128)))
  let resized = resize(img, 2, 2)
  assert_eq(resized.width, 2)
  assert_eq(resized.height, 2)
}

///|
test "reexport: resize with filter and edge" {
  let img = re_make_rgb(4, 4, Array::make(16, (100, 150, 200)))
  let resized = resize(
    img,
    8,
    8,
    filter=@types.ResizeFilter::Default,
    edge=@types.ResizeEdge::Clamp,
  )
  assert_eq(resized.width, 8)
  assert_eq(resized.height, 8)
}

///|
test "reexport: resize with PointSample filter" {
  // PointSample filter exercises resize_sample_nearest
  let img = re_make_rgb(4, 4, Array::make(16, (100, 150, 200)))
  let resized = resize(img, 8, 8, filter=@types.ResizeFilter::PointSample)
  assert_eq(resized.width, 8)
  assert_eq(resized.height, 8)
}

///|
test "reexport: resize with zero dimensions raises" {
  let img = re_make_rgb(4, 4, Array::make(16, (128, 128, 128)))
  try {
    let _ = resize(img, 0, 4)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "reexport: resize with zero height raises" {
  let img = re_make_rgb(4, 4, Array::make(16, (128, 128, 128)))
  try {
    let _ = resize(img, 4, 0)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "reexport: write_png_to_bytes" {
  let img = re_make_rgb(2, 2, [
    (10, 20, 30),
    (40, 50, 60),
    (70, 80, 90),
    (100, 110, 120),
  ])
  let png_bytes = write_png_to_bytes(img)
  // PNG signature
  assert_eq(png_bytes[0].to_int(), 0x89)
  assert_eq(png_bytes[1].to_int(), 0x50)
}

///|
test "reexport: write_hdr_to_bytes" {
  let fdata : Array[Byte] = []
  let rb = 1.0F.to_le_bytes()
  let gb = 0.5F.to_le_bytes()
  let bb = 0.25F.to_le_bytes()
  for i in 0..<4 {
    fdata.push(rb[i])
  }
  for i in 0..<4 {
    fdata.push(gb[i])
  }
  for i in 0..<4 {
    fdata.push(bb[i])
  }
  let imgf = @types.ImageF::{
    width: 1,
    height: 1,
    channels: 3,
    data: Bytes::from_array(fdata),
  }
  let hdr_bytes = write_hdr_to_bytes(imgf)
  // HDR magic "#?RADIANCE"
  assert_eq(hdr_bytes[0].to_int(), 0x23)
  assert_eq(hdr_bytes[1].to_int(), 0x3F)
}

///|
test "reexport: load_gif_from_bytes" {
  // 构造最小 GIF 动画
  let gif_bytes = @codec.encode_gif_pure(
    re_make_rgb(2, 2, [(255, 0, 0), (0, 255, 0), (0, 0, 255), (255, 255, 255)]),
  )
  let anim = load_gif_from_bytes(gif_bytes)
  assert_true(anim.frames.length() >= 1)
}

///|
test "reexport: canny_edge" {
  let img = re_make_rgb(4, 4, [
    (0, 0, 0),
    (255, 255, 255),
    (0, 0, 0),
    (255, 255, 255),
    (255, 255, 255),
    (0, 0, 0),
    (255, 255, 255),
    (0, 0, 0),
    (0, 0, 0),
    (255, 255, 255),
    (0, 0, 0),
    (255, 255, 255),
    (255, 255, 255),
    (0, 0, 0),
    (255, 255, 255),
    (0, 0, 0),
  ])
  let edges = canny_edge(img)
  assert_eq(edges.width, 4)
  assert_eq(edges.height, 4)
}

///|
test "reexport: canny_edge with thresholds" {
  let img = re_make_rgb(4, 4, Array::make(16, (128, 128, 128)))
  let edges = canny_edge(img, low_threshold=30, high_threshold=80)
  assert_eq(edges.width, 4)
}

///|
test "reexport: dehaze" {
  let img = re_make_rgb(8, 8, Array::make(64, (100, 120, 140)))
  let result = dehaze(img)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "reexport: dehaze with params" {
  let img = re_make_rgb(8, 8, Array::make(64, (50, 60, 70)))
  let result = dehaze(img, patch_size=5, omega=0.9F, t0=0.2F)
  assert_eq(result.width, 8)
}

///|
test "reexport: nlm_denoise" {
  let img = re_make_rgb(4, 4, Array::make(16, (128, 128, 128)))
  let result = nlm_denoise(img, patch_size=1, search_size=1, h=10)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "reexport: nlm_denoise_fast" {
  let img = re_make_rgb(4, 4, Array::make(16, (128, 128, 128)))
  let result = nlm_denoise_fast(img, patch_size=1, search_size=1, h=10, step=1)
  assert_eq(result.width, 4)
}

///|
test "reexport: harris_corner" {
  let img = re_make_rgb(4, 4, [
    (0, 0, 0),
    (255, 255, 255),
    (0, 0, 0),
    (255, 255, 255),
    (255, 255, 255),
    (0, 0, 0),
    (255, 255, 255),
    (0, 0, 0),
    (0, 0, 0),
    (255, 255, 255),
    (0, 0, 0),
    (255, 255, 255),
    (255, 255, 255),
    (0, 0, 0),
    (255, 255, 255),
    (0, 0, 0),
  ])
  let _ = harris_corners(img)
  assert_true(true)
}

///|
test "reexport: hough_lines" {
  let img = re_make_rgb(8, 8, Array::make(64, (0, 0, 0)))
  let _ = hough_lines(img, 100)
  assert_true(true)
}

///|
test "reexport: hough_lines_nms" {
  let lines : Array[HoughLine] = []
  let _ = hough_lines_nms(lines)
  assert_true(true)
}

///|
test "reexport: gabor_filter" {
  let img = re_make_rgb(8, 8, Array::make(64, (128, 128, 128)))
  let result = gabor_filter(img, 3, 1.0F, 0.0F)
  assert_eq(result.width, 8)
}

///|
test "reexport: gabor_filter_bank" {
  let img = re_make_rgb(8, 8, Array::make(64, (128, 128, 128)))
  let result = gabor_filter_bank(img, 3, 1.0F)
  assert_eq(result.width, 8)
}

///|
test "reexport: gabor_kernel" {
  let _ = gabor_kernel(3, 1.0F, 0.0F)
  assert_true(true)
}

///|
test "reexport: haar_transform_2d" {
  let img = re_make_rgb(4, 4, Array::make(16, (128, 128, 128)))
  let _ = haar_transform_2d(img)
  assert_true(true)
}

///|
test "reexport: haar_denoise" {
  let img = re_make_rgb(4, 4, Array::make(16, (128, 128, 128)))
  let result = haar_denoise(img)
  assert_eq(result.width, 4)
}

///|
test "reexport: kmeans_segment" {
  let img = re_make_rgb(4, 4, [
    (0, 0, 0),
    (0, 0, 0),
    (255, 255, 255),
    (255, 255, 255),
    (0, 0, 0),
    (0, 0, 0),
    (255, 255, 255),
    (255, 255, 255),
    (0, 0, 0),
    (0, 0, 0),
    (255, 255, 255),
    (255, 255, 255),
    (0, 0, 0),
    (0, 0, 0),
    (255, 255, 255),
    (255, 255, 255),
  ])
  let (labels, regions) = kmeans_segment(img, 2)
  assert_eq(regions.length(), 2)
  let _ = labels
}

///|
test "reexport: region_growing_segment" {
  let img = re_make_rgb(4, 4, [
    (0, 0, 0),
    (0, 0, 0),
    (255, 255, 255),
    (255, 255, 255),
    (0, 0, 0),
    (0, 0, 0),
    (255, 255, 255),
    (255, 255, 255),
    (0, 0, 0),
    (0, 0, 0),
    (255, 255, 255),
    (255, 255, 255),
    (0, 0, 0),
    (0, 0, 0),
    (255, 255, 255),
    (255, 255, 255),
  ])
  let (labels, regions) = region_growing_segment(img, [(0, 0), (0, 2)])
  assert_true(regions.length() >= 1)
  let _ = labels
}

///|
test "reexport: ssr" {
  let img = re_make_rgb(4, 4, Array::make(16, (128, 128, 128)))
  let result = ssr(img)
  assert_eq(result.width, 4)
}

///|
test "reexport: msr" {
  let img = re_make_rgb(4, 4, Array::make(16, (128, 128, 128)))
  let result = msr(img)
  assert_eq(result.width, 4)
}

///|
test "reexport: freq_filter" {
  let img = re_make_rgb(4, 4, Array::make(16, (128, 128, 128)))
  let result = freq_filter(img, FreqFilterType::LowPass, 10.0F)
  assert_eq(result.width, 4)
}

///|
test "reexport: freq_filter_gaussian" {
  let img = re_make_rgb(4, 4, Array::make(16, (128, 128, 128)))
  let result = freq_filter_gaussian(img, FreqFilterType::LowPass, 10.0F)
  assert_eq(result.width, 4)
}

///|
test "reexport: compute_glcm" {
  let data = Bytes::from_array(Array::make(16, b'\x80'))
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let _ = compute_glcm(img, 1, 0)
  assert_true(true)
}

///|
test "reexport: glcm_features_multi_direction" {
  let data = Bytes::from_array(Array::make(16, b'\x80'))
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let _ = glcm_features_multi_direction(img)
  assert_true(true)
}

///|
test "reexport: draw_corners" {
  let img = re_make_rgb(4, 4, Array::make(16, (128, 128, 128)))
  let corners : Array[CornerPoint] = []
  let result = draw_corners(img, corners)
  assert_eq(result.width, 4)
}

///|
test "reexport: decode_any with req_channels" {
  let img = re_make_rgb(2, 2, [
    (10, 20, 30),
    (40, 50, 60),
    (70, 80, 90),
    (100, 110, 120),
  ])
  let bmp_bytes = @codec.encode_bmp_pure(img)
  let restored = decode_any(bmp_bytes, req_channels=Some(3))
  assert_eq(restored.width, 2)
}

///|
test "reexport: sift_match" {
  let kps1 : Array[SiftDescriptor] = []
  let kps2 : Array[SiftDescriptor] = []
  let matches = sift_match(kps1, kps2)
  assert_eq(matches.length(), 0)
}

///|
test "reexport: ransac_homography empty" {
  let pts : Array[((Float, Float), (Float, Float))] = []
  let result = ransac_homography(pts)
  assert_true(result is None)
}

///|
test "reexport: approx_poly_dp empty" {
  let points : Array[ContourPoint] = []
  let result = approx_poly_dp(points, 1.0F)
  assert_eq(result.length(), 0)
}

///|
test "reexport: flood_fill raises on non-RGBA" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: [b'\x80', b'\x80', b'\x80', b'\x80'] |> Bytes::from_array,
  }
  try {
    let _ = flood_fill(img, 0, 0, [b'\x00', b'\x00', b'\x00'])
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
  let _ = img
}

///|
test "reexport: check_dims valid" {
  check_dims(100, 100, 3)
  assert_true(true)
}

///|
test "reexport: check_dims invalid raises" {
  try {
    check_dims(0, 100, 3)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "reexport: safe_mul normal" {
  let result = safe_mul(100, 200)
  assert_true(result is Some(_))
  let _ = result
}

///|
test "reexport: safe_mul overflow" {
  let result = safe_mul(0x10000, 0x10000)
  assert_true(result is None)
}

///|
test "reexport: safe_mul3 normal" {
  let result = safe_mul3(10, 10, 10)
  assert_true(result is Some(_))
  let _ = result
}

///|
test "reexport: reinhard_tonemap" {
  fn write_f32(data : Array[Byte], off : Int, v : Float) {
    let bits = v.reinterpret_as_int()
    data[off] = (bits & 0xFF).to_byte()
    data[off + 1] = ((bits >> 8) & 0xFF).to_byte()
    data[off + 2] = ((bits >> 16) & 0xFF).to_byte()
    data[off + 3] = ((bits >> 24) & 0xFF).to_byte()
  }
  let data : Array[Byte] = Array::make(24, b'\x00')
  write_f32(data, 0, 0.5F)
  write_f32(data, 4, 0.3F)
  write_f32(data, 8, 0.1F)
  write_f32(data, 12, 0.8F)
  write_f32(data, 16, 0.2F)
  write_f32(data, 20, 0.6F)
  let imgf = @types.ImageF::{
    width: 2,
    height: 1,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let result = reinhard_tonemap(imgf)
  assert_eq(result.width, 2)
  let _ = imgf
  let _ = result
}

///|
test "reexport: decode_stream_channels" {
  let img = re_make_rgb(2, 2, [
    (10, 20, 30),
    (40, 50, 60),
    (70, 80, 90),
    (100, 110, 120),
  ])
  let data = @codec.encode_png_pure(img)
  let mut row_count = 0
  let _ = decode_stream_channels(data, 3, fn(_row, _y) { row_count += 1 })
  assert_true(row_count > 0)
}

///|
test "reexport: multi_band_blend raises on size mismatch" {
  let a = re_make_rgb(2, 2, [
    (128, 128, 128),
    (128, 128, 128),
    (128, 128, 128),
    (128, 128, 128),
  ])
  let b = re_make_rgb(3, 2, [
    (64, 64, 64),
    (64, 64, 64),
    (64, 64, 64),
    (64, 64, 64),
    (64, 64, 64),
    (64, 64, 64),
  ])
  let mask = re_make_rgb(2, 2, [
    (128, 128, 128),
    (128, 128, 128),
    (128, 128, 128),
    (128, 128, 128),
  ])
  try {
    let _ = multi_band_blend(a, b, mask)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
  let _ = a
  let _ = b
  let _ = mask
}

///|
test "reexport: hough_circles empty image" {
  let img = re_make_rgb(1, 1, [(128, 128, 128)])
  let circles = hough_circles(img)
  assert_true(circles.length() >= 0)
  let _ = img
}

///|
test "reexport: template_match" {
  let img = re_make_rgb(4, 4, [
    (10, 20, 30),
    (40, 50, 60),
    (70, 80, 90),
    (100, 110, 120),
    (130, 140, 150),
    (160, 170, 180),
    (20, 30, 40),
    (50, 60, 70),
    (80, 90, 100),
    (110, 120, 130),
    (140, 150, 160),
    (180, 190, 200),
    (30, 40, 50),
    (60, 70, 80),
    (90, 100, 110),
    (120, 130, 140),
  ])
  let tpl = re_make_rgb(2, 2, [
    (10, 20, 30),
    (40, 50, 60),
    (70, 80, 90),
    (100, 110, 120),
  ])
  let results = template_match(img, tpl)
  assert_true(results.length() > 0)
  let _ = img
  let _ = tpl
}

///|
test "reexport: template_match_best" {
  let img = re_make_rgb(4, 4, [
    (10, 20, 30),
    (40, 50, 60),
    (70, 80, 90),
    (100, 110, 120),
    (130, 140, 150),
    (160, 170, 180),
    (20, 30, 40),
    (50, 60, 70),
    (80, 90, 100),
    (110, 120, 130),
    (140, 150, 160),
    (180, 190, 200),
    (30, 40, 50),
    (60, 70, 80),
    (90, 100, 110),
    (120, 130, 140),
  ])
  let tpl = re_make_rgb(2, 2, [
    (10, 20, 30),
    (40, 50, 60),
    (70, 80, 90),
    (100, 110, 120),
  ])
  let result = template_match_best(img, tpl)
  assert_true(result is Some(_))
  let _ = img
  let _ = tpl
}

///|
test "reexport: horn_schunck" {
  let img1 = re_make_rgb(4, 4, [
    (100, 110, 120),
    (130, 140, 150),
    (160, 170, 180),
    (200, 210, 220),
    (110, 120, 130),
    (140, 150, 160),
    (170, 180, 190),
    (210, 220, 230),
    (120, 130, 140),
    (150, 160, 170),
    (180, 190, 200),
    (220, 230, 240),
    (130, 140, 150),
    (160, 170, 180),
    (190, 200, 210),
    (230, 240, 250),
  ])
  let img2 = re_make_rgb(4, 4, [
    (105, 115, 125),
    (135, 145, 155),
    (165, 175, 185),
    (205, 215, 225),
    (115, 125, 135),
    (145, 155, 165),
    (175, 185, 195),
    (215, 225, 235),
    (125, 135, 145),
    (155, 165, 175),
    (185, 195, 205),
    (225, 235, 245),
    (135, 145, 155),
    (165, 175, 185),
    (195, 205, 215),
    (235, 245, 255),
  ])
  let (u, v) = horn_schunck(img1, img2)
  assert_true(u.length() == 16)
  assert_true(v.length() == 16)
  let _ = img1
  let _ = img2
}

///|
test "reexport: good_features_to_track" {
  // Use a larger image to avoid edge effects in Sobel gradient computation
  let data : Array[Byte] = []
  for i in 0..<400 {
    data.push((i * 7 % 256).to_byte())
    data.push((i * 11 % 256).to_byte())
    data.push((i * 13 % 256).to_byte())
  }
  let img = @types.Image::{
    width: 20,
    height: 20,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let corners = good_features_to_track(img, 10, 0.001F)
  assert_true(corners.length() >= 0)
  let _ = img
}

///|
test "reexport: distance_transform" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: [
      b'\x00', b'\xFF', b'\xFF', b'\x00', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF',
      b'\xFF', b'\xFF', b'\xFF', b'\x00', b'\xFF', b'\xFF', b'\x00',
    ]
    |> Bytes::from_array,
  }
  let result = distance_transform(img)
  assert_true(result.length() == 16)
  let _ = img
}

///|
test "reexport: guided_filter" {
  let img = re_make_rgb(4, 4, [
    (100, 110, 120),
    (130, 140, 150),
    (160, 170, 180),
    (200, 210, 220),
    (110, 120, 130),
    (140, 150, 160),
    (170, 180, 190),
    (210, 220, 230),
    (120, 130, 140),
    (150, 160, 170),
    (180, 190, 200),
    (220, 230, 240),
    (130, 140, 150),
    (160, 170, 180),
    (190, 200, 210),
    (230, 240, 250),
  ])
  let input : Array[Float] = [
    0.1F, 0.2F, 0.3F, 0.4F, 0.5F, 0.6F, 0.7F, 0.8F, 0.9F, 1.0F, 1.1F, 1.2F, 1.3F,
    1.4F, 1.5F, 1.6F,
  ]
  let result = guided_filter(img, input)
  assert_true(result.length() == 16)
  let _ = img
}

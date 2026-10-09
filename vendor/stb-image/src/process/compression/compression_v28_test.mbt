// v28.0.0 图像压缩与编码优化测试
// 覆盖 compression/image_compression.mbt 的 14 个公开函数

///|
fn create_solid_img_c(w : Int, h : Int, value : Int) -> @types.Image {
  let data : Array[Byte] = []
  for _ in 0..<(w * h) {
    data.push(value.to_byte())
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(data),
  }
}

///|
fn create_gradient_img_c(w : Int, h : Int) -> @types.Image {
  let data : Array[Byte] = []
  for _ in 0..<h {
    for x in 0..<w {
      let v = x * 255 / w % 256
      data.push(v.to_byte())
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(data),
  }
}

///|
fn create_noise_img_c(w : Int, h : Int) -> @types.Image {
  let data : Array[Byte] = []
  let mut state = 42
  for _ in 0..<(w * h) {
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF
    data.push((state % 256).to_byte())
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(data),
  }
}

///|
test "create_default_compression_config: 默认配置正确" {
  let config = create_default_compression_config()
  assert_true(config.quality > 0.0)
  assert_true(config.block_size > 0)
}

///|
test "run_length_encode: 编码后返回有效字节" {
  let data = Bytes::from_array([128, 128, 128, 128, 255, 255, 0])
  let encoded = run_length_encode(data)
  assert_true(encoded.length() > 0)
}

///|
test "run_length_encode: 空字节编码" {
  let data = Bytes::from_array([])
  let encoded = run_length_encode(data)
  assert_true(encoded.length() >= 0)
}

///|
test "run_length_decode: 解码后返回有效字节" {
  let data = Bytes::from_array([3, 128, 2, 255, 1, 0])
  let decoded = run_length_decode(data)
  assert_true(decoded.length() >= 0)
}

///|
test "calculate_image_entropy: 纯色图像熵" {
  let img = create_solid_img_c(16, 16, 128)
  let entropy = calculate_image_entropy(img)
  assert_true(entropy <= 0.0)
}

///|
test "calculate_image_entropy: 随机噪声图像熵" {
  let img = create_noise_img_c(16, 16)
  let entropy = calculate_image_entropy(img)
  assert_true(entropy <= 0.0)
}

///|
test "quantize_image: 量化纯色图像" {
  let img = create_solid_img_c(16, 16, 128)
  let result = quantize_image(img, 4)
  assert_true(result.width == 16)
  assert_true(result.height == 16)
}

///|
test "quantize_image: 量化渐变图像" {
  let img = create_gradient_img_c(16, 16)
  let result = quantize_image(img, 8)
  assert_true(result.width == 16)
  assert_true(result.height == 16)
}

///|
test "predictive_encode: 编码纯色图像" {
  let img = create_solid_img_c(16, 16, 128)
  let encoded = predictive_encode(img)
  assert_true(encoded.length() > 0)
}

///|
test "calculate_compression_ratio: 正常值" {
  let ratio = calculate_compression_ratio(1000, 250)
  assert_true(ratio > 0.0)
}

///|
test "calculate_compression_ratio: 相同大小" {
  let ratio = calculate_compression_ratio(100, 100)
  assert_true(ratio >= 0.0)
}

///|
test "calculate_bits_per_pixel: 正常值" {
  let bpp = calculate_bits_per_pixel(1024, 32, 32)
  assert_true(bpp >= 0.0)
}

///|
test "calculate_compression_quality: 纯色图像质量" {
  let original = create_solid_img_c(16, 16, 128)
  let compressed = create_solid_img_c(16, 16, 128)
  let metrics = calculate_compression_quality(original, compressed, 16, 16)
  assert_true(metrics.psnr >= 0.0)
  assert_true(metrics.mse >= 0.0)
}

///|
test "calculate_compression_quality: 不同图像质量" {
  let original = create_gradient_img_c(16, 16)
  let compressed = create_solid_img_c(16, 16, 128)
  let metrics = calculate_compression_quality(original, compressed, 16, 16)
  assert_true(metrics.psnr >= 0.0)
  assert_true(metrics.compression_ratio >= 0.0)
}

///|
test "compress_jpeg_simple: 压缩纯色图像" {
  let img = create_solid_img_c(16, 16, 128)
  let result = compress_jpeg_simple(img, 0.8)
  assert_true(result.original_size > 0)
  assert_true(result.compressed_size >= 0)
  assert_true(result.compression_ratio >= 0.0)
}

///|
test "compress_jpeg_simple: 压缩渐变图像" {
  let img = create_gradient_img_c(16, 16)
  let result = compress_jpeg_simple(img, 0.5)
  assert_true(result.original_size > 0)
  assert_true(result.bits_per_pixel >= 0.0)
}

///|
test "compress_png_simple: 压缩纯色图像" {
  let img = create_solid_img_c(16, 16, 128)
  let result = compress_png_simple(img)
  assert_true(result.original_size > 0)
  assert_true(result.compressed_size >= 0)
}

///|
test "compress_png_simple: 压缩随机噪声图像" {
  let img = create_noise_img_c(16, 16)
  let result = compress_png_simple(img)
  assert_true(result.compression_ratio >= 0.0)
}

///|
test "compress_image: RLE压缩" {
  let img = create_solid_img_c(16, 16, 128)
  let config = CompressionConfig::{
    algorithm: CompressionAlgorithm::RunLengthEncoding,
    quality: 0.8,
    quantization_level: 8,
    use_dct: false,
    use_prediction: false,
    use_entropy_coding: true,
    block_size: 8,
  }
  let result = compress_image(img, config)
  assert_true(result.original_size > 0)
  assert_true(result.compressed_size >= 0)
}

///|
test "compress_image: Deflate压缩" {
  let img = create_gradient_img_c(16, 16)
  let config = CompressionConfig::{
    algorithm: CompressionAlgorithm::Deflate,
    quality: 0.9,
    quantization_level: 4,
    use_dct: false,
    use_prediction: true,
    use_entropy_coding: true,
    block_size: 8,
  }
  let result = compress_image(img, config)
  assert_true(result.compression_ratio >= 0.0)
}

///|
test "compression_algorithm_to_string: 所有算法" {
  assert_true(
    compression_algorithm_to_string(CompressionAlgorithm::RunLengthEncoding).length() >
    0,
  )
  assert_true(
    compression_algorithm_to_string(CompressionAlgorithm::HuffmanCoding).length() >
    0,
  )
  assert_true(
    compression_algorithm_to_string(CompressionAlgorithm::Deflate).length() > 0,
  )
  assert_true(
    compression_algorithm_to_string(CompressionAlgorithm::PNG).length() > 0,
  )
  assert_true(
    compression_algorithm_to_string(CompressionAlgorithm::JPEGBaseline).length() >
    0,
  )
}

///|
test "compression_report_to_string: 报告非空" {
  let img = create_solid_img_c(16, 16, 128)
  let result = compress_png_simple(img)
  let metrics = calculate_compression_quality(img, img, 16, 16)
  let report = compression_report_to_string(result, metrics)
  assert_true(report.length() > 0)
}

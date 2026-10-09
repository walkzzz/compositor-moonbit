// v21.0.0 图像加密与水印增强测试 - encryption 模块
// XOR/混沌/Arnold加密、LSB/可见水印、熵/相关性/PSNR/NPCR/UACI评估

///|
fn make_enc_img(w : Int, h : Int, value : Byte) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(Array::make(w * h, value)),
  }
}

///|
fn make_varied_img(w : Int, h : Int) -> @types.Image {
  let arr : Array[Byte] = []
  for i in 0..<(w * h) {
    arr.push((i % 256).to_byte())
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(arr),
  }
}

///|
test "create_default_chaotic_params: 返回有效参数" {
  let params = create_default_chaotic_params()
  assert_true(params.a > 0.0)
  assert_true(params.b > 0.0)
  assert_true(params.iterations > 0)
}

///|
test "create_default_arnold_params: 返回有效参数" {
  let params = create_default_arnold_params()
  assert_true(params.iterations > 0)
  assert_true(params.a > 0)
  assert_true(params.b > 0)
}

///|
test "xor_encrypt: 基本加密" {
  let img = make_enc_img(4, 4, b'\x80')
  let key = [b'\xAA', b'\x55', b'\xFF']
  let result = xor_encrypt(img, key)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.encrypted_data.length(), 16)
}

///|
test "xor_decrypt: 加解密一致" {
  let img = make_varied_img(4, 4)
  let key = [b'\xAA', b'\x55', b'\xFF']
  let encrypted = xor_encrypt(img, key)
  let decrypted = xor_decrypt(encrypted, key)
  let mut all_match = true
  for i in 0..<(4 * 4) {
    if img.data[i] != decrypted.data[i] {
      all_match = false
    }
  }
  assert_true(all_match)
}

///|
test "generate_chaotic_sequence_enc: 基本生成" {
  let params = create_default_chaotic_params()
  let seq = generate_chaotic_sequence_enc(params, 100)
  assert_eq(seq.length(), 100)
}

///|
test "chaotic_encrypt: 基本加密" {
  let img = make_enc_img(4, 4, b'\x80')
  let params = create_default_chaotic_params()
  let result = chaotic_encrypt(img, params)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.encrypted_data.length(), 16)
}

///|
test "arnold_scramble: 基本置乱" {
  let img = make_varied_img(4, 4)
  let params = create_default_arnold_params()
  let result = arnold_scramble(img, params)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.encrypted_data.length(), 16)
}

///|
test "embed_watermark_lsb: 基本嵌入" {
  let img = make_enc_img(8, 8, b'\x80')
  let watermark = [b'\x41', b'\x42', b'\x43']
  let (watermarked, info) = embed_watermark_lsb(img, watermark, 0)
  assert_eq(watermarked.width, 8)
  assert_eq(watermarked.height, 8)
  assert_true(info.embedded)
}

///|
test "extract_watermark_lsb: 基本提取" {
  let img = make_enc_img(8, 8, b'\x80')
  let watermark = [b'\x41', b'\x42', b'\x43']
  let (watermarked, _) = embed_watermark_lsb(img, watermark, 0)
  let result = extract_watermark_lsb(watermarked, 3, 0)
  assert_eq(result.watermark_data.length(), 3)
  assert_true(result.extracted)
}

///|
test "embed_visible_watermark: 基本嵌入" {
  let img = make_enc_img(16, 16, b'\x40')
  let result = embed_visible_watermark(img, "AB", 2, 2, 0.5)
  assert_eq(result.width, 16)
  assert_eq(result.height, 16)
  assert_eq(result.data.length(), 256)
}

///|
test "calculate_image_entropy: 均匀图像" {
  let img = make_enc_img(4, 4, b'\x80')
  let entropy = calculate_image_entropy(img)
  assert_true(entropy <= 0.0)
}

///|
test "calculate_image_entropy: 变化图像" {
  let img = make_varied_img(4, 4)
  let entropy = calculate_image_entropy(img)
  assert_true(entropy < 0.0)
}

///|
test "calculate_correlation: 相同图像" {
  let img = make_varied_img(4, 4)
  let corr = calculate_correlation(img, img)
  assert_true((corr - 1.0).abs() < 0.001)
}

///|
test "calculate_correlation: 不同图像" {
  let img1 = make_enc_img(4, 4, b'\x00')
  let img2 = make_enc_img(4, 4, b'\xFF')
  let corr = calculate_correlation(img1, img2)
  assert_true(corr.abs() < 1.001)
}

///|
test "calculate_psnr: 相同图像" {
  let img = make_varied_img(4, 4)
  let psnr = calculate_psnr(img, img)
  assert_true(psnr > 90.0)
}

///|
test "calculate_psnr: 不同图像" {
  let img1 = make_enc_img(4, 4, b'\x00')
  let img2 = make_enc_img(4, 4, b'\xFF')
  let psnr = calculate_psnr(img1, img2)
  assert_true(psnr > 0.0)
}

///|
test "evaluate_image_encryption_quality: 基本评估" {
  let original = make_varied_img(4, 4)
  let encrypted = make_enc_img(4, 4, b'\x80')
  let quality = evaluate_image_encryption_quality(original, encrypted)
  assert_true(quality.npcr >= 0.0 && quality.npcr <= 100.0)
  assert_true(quality.key_sensitivity >= 0.0)
}

///|
test "encryption_report_to_string: 报告生成" {
  let img = make_varied_img(4, 4)
  let key = [b'\xAA']
  let enc_result = xor_encrypt(img, key)
  let wm_info = WatermarkInfo::{
    watermark_type: WatermarkType::Invisible_LSB,
    watermark_data: [b'\x41'],
    watermark_width: 1,
    watermark_height: 1,
    strength: 1.0,
    embedded: true,
    embedding_position: "LSB",
    key: "test_key",
  }
  let quality = ImageEncryptionQuality::{
    entropy: 7.5,
    correlation_horizontal: 0.01,
    correlation_vertical: 0.02,
    correlation_diagonal: 0.03,
    uaci: 33.0,
    npcr: 99.0,
    key_sensitivity: 0.99,
    psnr: 8.5,
  }
  let report = encryption_report_to_string(enc_result, wm_info, quality)
  assert_true(report.contains("图像加密与水印报告"))
  assert_true(report.contains("XOR"))
  assert_true(report.contains("NPCR"))
}

///|
test "encryption_default_config: 返回有效配置" {
  let config = encryption_default_config()
  assert_true(config.mu > 3.5 && config.mu <= 4.0)
  assert_true(config.iterations > 0)
}

///|
test "encrypt_image_logistic: 基本加密" {
  let img = make_varied_img(4, 4)
  let encrypted = encrypt_image_logistic(img)
  assert_eq(encrypted.width, 4)
  assert_eq(encrypted.height, 4)
  assert_eq(encrypted.data.length(), 16)
}

///|
test "decrypt_image_logistic: 加解密一致" {
  let img = make_varied_img(4, 4)
  let encrypted = encrypt_image_logistic(img, key=0.5)
  let decrypted = decrypt_image_logistic(encrypted, key=0.5)
  let mut all_match = true
  for i in 0..<(4 * 4) {
    if img.data[i] != decrypted.data[i] {
      all_match = false
    }
  }
  assert_true(all_match)
}

///|
test "encrypt_image_xor: 基本加密" {
  let img = make_varied_img(4, 4)
  let encrypted = encrypt_image_xor(img, "testkey")
  assert_eq(encrypted.width, 4)
  assert_eq(encrypted.height, 4)
}

///|
test "decrypt_image_xor: 加解密一致" {
  let img = make_varied_img(4, 4)
  let encrypted = encrypt_image_xor(img, "testkey")
  let decrypted = decrypt_image_xor(encrypted, "testkey")
  let mut all_match = true
  for i in 0..<(4 * 4) {
    if img.data[i] != decrypted.data[i] {
      all_match = false
    }
  }
  assert_true(all_match)
}

///|
test "histogram_entropy: 基本计算" {
  let img = make_varied_img(4, 4)
  let entropy = histogram_entropy(img)
  assert_true(entropy >= 0.0)
}

///|
test "adjacent_correlation: 基本计算" {
  let img = make_varied_img(4, 4)
  let corr = adjacent_correlation(img)
  assert_true(corr >= -1.0 && corr <= 1.0)
}

///|
test "evaluate_encryption_quality: 基本评估" {
  let original = make_varied_img(4, 4)
  let encrypted = make_enc_img(4, 4, b'\x80')
  let quality = evaluate_encryption_quality(original, encrypted)
  assert_true(quality.npcr >= 0.0)
}

///|
test "key_sensitivity_test: 基本测试" {
  let img = make_varied_img(4, 4)
  let result = key_sensitivity_test(img, 0.123456789)
  assert_true(result >= 0.0)
}

///|
test "batch_encrypt: 基本批量" {
  let img = make_varied_img(4, 4)
  let results = batch_encrypt([img, img, img], 0.5)
  assert_eq(results.length(), 3)
}

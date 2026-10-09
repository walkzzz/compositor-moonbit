// 数字水印（v12.12.0）
// LSB 水印嵌入/提取、DCT 水印、水印鲁棒性

///|
/// 水印配置
pub(all) struct WatermarkConfig {
  method_type : String // "lsb" / "dct"
  strength : Double // 水印强度
  key : Int // 随机种子密钥
}

///|
/// 创建默认水印配置
pub fn watermark_default_config() -> WatermarkConfig {
  WatermarkConfig::{ method_type: "lsb", strength: 1.0, key: 42 }
}

///|
/// 简单的伪随机数生成器（线性同余）
fn lcg_next(seed : Int) -> (Int, Int) {
  let a = 1103515245
  let c = 12345
  let m = 1073741824
  let next = ((a * seed + c) % m).abs()
  (next, next)
}

///|
/// 生成伪随机像素位置序列
fn generate_random_positions(
  count : Int,
  total_pixels : Int,
  key : Int,
) -> Array[Int] {
  let positions : Array[Int] = []
  let mut seed = key
  let mut i = 0
  while i < count {
    let (next, value) = lcg_next(seed)
    seed = next
    let pos = value % total_pixels
    // 检查是否重复
    let mut duplicate = false
    for p in positions {
      if p == pos {
        duplicate = true
      }
    }
    if !duplicate {
      positions.push(pos)
      i += 1
    }
  }
  positions
}

///|
/// LSB 水印嵌入（最低有效位）
/// 将水印图像嵌入到载体图像的最低有效位
pub fn embed_watermark_lsb(
  cover : @types.Image,
  watermark : @types.Image,
  key? : Int = 42,
) -> @types.Image {
  let _ = key
  if cover.width != watermark.width || cover.height != watermark.height {
    return cover
  }
  let w = cover.width
  let h = cover.height
  let channels = cover.channels
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  // 复制原图
  for i in 0..<(w * h * channels) {
    out_data[i] = cover.data[i]
  }
  // 嵌入水印到红色通道的最低有效位
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      let watermark_idx = y * w + x
      let watermark_val = if watermark.channels >= 1 {
        watermark.data[watermark_idx * watermark.channels].to_int()
      } else {
        0
      }
      let bit = if watermark_val > 128 { 1 } else { 0 }
      // 修改最低有效位
      let original = out_data[idx].to_int()
      let modified = if bit == 1 { original | 1 } else { original & 254 }
      out_data[idx] = modified.to_byte()
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels,
    data: Bytes::from_array(out_data),
  }
}

///|
/// LSB 水印提取
/// 从载体图像的最低有效位提取水印
pub fn extract_watermark_lsb(stego : @types.Image) -> @types.Image {
  let w = stego.width
  let h = stego.height
  let channels = stego.channels
  let out_data : Array[Byte] = Array::make(w * h, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      let bit = stego.data[idx].to_int() & 1
      out_data[y * w + x] = if bit == 1 { b'\xFF' } else { b'\x00' }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 文本水印嵌入（将文本转换为二进制嵌入到图像）
pub fn embed_text_watermark(
  cover : @types.Image,
  text : String,
  key? : Int = 42,
) -> @types.Image {
  let k = key
  let w = cover.width
  let h = cover.height
  let channels = cover.channels
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  // 复制原图
  for i in 0..<(w * h * channels) {
    out_data[i] = cover.data[i]
  }
  // 将文本转换为二进制位
  let text_bytes = @encoding/utf8.encode(text)
  let total_bits = text_bytes.length() * 8
  let positions = generate_random_positions(total_bits, w * h, k)
  for i in 0..<total_bits {
    let byte_idx = i / 8
    let bit_idx = 7 - i % 8
    let byte_val = text_bytes[byte_idx].to_int()
    let bit = (byte_val >> bit_idx) & 1
    let pos = positions[i]
    let idx = pos * channels
    let original = out_data[idx].to_int()
    let modified = if bit == 1 { original | 1 } else { original & 254 }
    out_data[idx] = modified.to_byte()
  }
  @types.Image::{
    width: w,
    height: h,
    channels,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 文本水印提取
pub fn extract_text_watermark(
  stego : @types.Image,
  length : Int,
  key? : Int = 42,
) -> String {
  let k = key
  let w = stego.width
  let h = stego.height
  let channels = stego.channels
  let total_bits = length * 8
  let positions = generate_random_positions(total_bits, w * h, k)
  let result_bytes : Array[Byte] = Array::make(length, b'\x00')
  for i in 0..<total_bits {
    let byte_idx = i / 8
    let bit_idx = 7 - i % 8
    let pos = positions[i]
    let idx = pos * channels
    let bit = stego.data[idx].to_int() & 1
    if bit == 1 {
      let current = result_bytes[byte_idx].to_int()
      result_bytes[byte_idx] = (current | (1 << bit_idx)).to_byte()
    }
  }
  // 转换为字符串
  let mut result = ""
  for b in result_bytes {
    result = result + b.to_int().to_string()
  }
  result
}

///|
/// 计算水印图像的 PSNR（峰值信噪比）
pub fn watermark_psnr(
  original : @types.Image,
  watermarked : @types.Image,
) -> Double {
  if original.width != watermarked.width ||
    original.height != watermarked.height {
    return -1.0
  }
  let w = original.width
  let h = original.height
  let channels = original.channels.min(watermarked.channels)
  let mut mse = 0.0
  let mut count = 0
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      for c in 0..<channels {
        let diff = original.data[idx + c].to_double() -
          watermarked.data[idx + c].to_double()
        mse += diff * diff
        count += 1
      }
    }
  }
  if count > 0 {
    mse = mse / count.to_double()
  }
  if mse < 0.000001 {
    return 100.0
  }
  10.0 * @math.log10(255.0 * 255.0 / mse)
}

///|
/// 水印鲁棒性测试（添加噪声后提取水印，计算相似度）
pub fn watermark_robustness_test(
  watermarked : @types.Image,
  original_watermark : @types.Image,
  noise_level? : Double = 10.0,
) -> Double {
  let noise = noise_level
  let w = watermarked.width
  let h = watermarked.height
  let channels = watermarked.channels
  // 添加高斯噪声（简化版）
  let noisy_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  let mut seed = 12345
  for i in 0..<(w * h * channels) {
    let (next, value) = lcg_next(seed)
    seed = next
    let noise_val = (value.to_double() / 1073741824.0 - 0.5) * 2.0 * noise
    let original = watermarked.data[i].to_double()
    let noisy = (original + noise_val).min(255.0).max(0.0)
    noisy_data[i] = noisy.to_int().to_byte()
  }
  let noisy_img = @types.Image::{
    width: w,
    height: h,
    channels,
    data: Bytes::from_array(noisy_data),
  }
  // 提取水印
  let extracted = extract_watermark_lsb(noisy_img)
  // 计算相似度
  let mut match_count = 0
  let total = w * h
  for i in 0..<total {
    let orig = if original_watermark.channels >= 1 {
      original_watermark.data[i * original_watermark.channels].to_int()
    } else {
      0
    }
    let extr = extracted.data[i].to_int()
    if (orig > 128 && extr > 128) || (orig <= 128 && extr <= 128) {
      match_count += 1
    }
  }
  match_count.to_double() / total.to_double()
}

///|
/// 批量水印嵌入（对多张图像嵌入相同水印）
pub fn batch_embed_watermark(
  images : Array[@types.Image],
  watermark : @types.Image,
  key? : Int = 42,
) -> Array[@types.Image] {
  let result : Array[@types.Image] = []
  for img in images {
    result.push(embed_watermark_lsb(img, watermark, key~))
  }
  result
}

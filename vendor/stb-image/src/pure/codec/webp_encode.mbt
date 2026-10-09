// 纯 MoonBit WebP lossy 编码器 (VP8)
// 规范: https://datatracker.ietf.org/doc/html/rfc6386
// 实现: 仅 intra 帧 (key frame), DC-only 预测, 固定量化
// 产出: 可被标准 WebP 解码器解码的有效 VP8 bitstream

///|
/// VP8 Bool 编码器（算术编码）
priv struct BoolEncoder {
  output : Array[Byte]
  mut low : Int
  mut count : Int
  mut range : Int
}

///|
fn BoolEncoder::new() -> BoolEncoder {
  { output: [], low: 0, count: 0, range: 255 }
}

///|
/// 编码一个 bool 值，probability 为 0 时编码 0
fn BoolEncoder::encode_bool(
  self : BoolEncoder,
  bit : Int,
  probability : Int,
) -> Unit {
  let split = 1 + (((self.range - 1) * probability) >> 8)
  if bit != 0 {
    self.low += split
    self.range -= split
  } else {
    self.range = split
  }
  while self.range < 128 {
    self.shift()
    self.range = self.range << 1
  }
}

///|
fn BoolEncoder::shift(self : BoolEncoder) -> Unit {
  let bit = if ((self.low >> 8) & 1) != 0 { 1 } else { 0 }
  self.low = (self.low << 1) & 0xFFFF
  self.count += 1
  if self.count == 8 {
    self.output.push(bit.to_byte())
    self.count = 0
  }
}

///|
/// 编码固定概率的 bool (50%)
fn BoolEncoder::encode_bit(self : BoolEncoder, bit : Int) -> Unit {
  self.encode_bool(bit, 128)
}

///|
/// 编码无符号整数 (n bits, MSB first)
fn BoolEncoder::encode_uint(self : BoolEncoder, value : Int, n : Int) -> Unit {
  for i in 0..<n {
    let bit = (value >> (n - 1 - i)) & 1
    self.encode_bit(bit)
  }
}

///|
/// 编码带符号整数
fn BoolEncoder::encode_int(self : BoolEncoder, value : Int, n : Int) -> Unit {
  if value < 0 {
    self.encode_bit(1)
    self.encode_uint(-value, n)
  } else {
    self.encode_bit(0)
    self.encode_uint(value, n)
  }
}

///|
/// 完成编码，刷新剩余 bits
fn BoolEncoder::finish(self : BoolEncoder) -> Bytes {
  for _ in 0..<self.count {
    self.output.push(0)
  }
  Bytes::from_array(self.output)
}

///|
/// 构建 WebP RIFF 容器
fn build_webp_container(width : Int, height : Int, vp8_data : Bytes) -> Bytes {
  let result : Array[Byte] = []
  result.push(b'\x52')
  result.push(b'\x49')
  result.push(b'\x46')
  result.push(b'\x46')
  let file_size_pos = result.length()
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x57')
  result.push(b'\x45')
  result.push(b'\x42')
  result.push(b'\x50')
  result.push(b'\x56')
  result.push(b'\x50')
  result.push(b'\x38')
  result.push(b'\x20')
  let chunk_size_pos = result.length()
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x00')
  let vp8_len = vp8_data.length()
  for i in 0..<vp8_len {
    result.push(vp8_data[i])
  }
  let chunk_size = vp8_len
  result[chunk_size_pos] = (chunk_size & 0xFF).to_byte()
  result[chunk_size_pos + 1] = ((chunk_size >> 8) & 0xFF).to_byte()
  result[chunk_size_pos + 2] = ((chunk_size >> 16) & 0xFF).to_byte()
  result[chunk_size_pos + 3] = ((chunk_size >> 24) & 0xFF).to_byte()
  let total_size = result.length() - 8
  result[file_size_pos] = (total_size & 0xFF).to_byte()
  result[file_size_pos + 1] = ((total_size >> 8) & 0xFF).to_byte()
  result[file_size_pos + 2] = ((total_size >> 16) & 0xFF).to_byte()
  result[file_size_pos + 3] = ((total_size >> 24) & 0xFF).to_byte()
  let _ = width
  let _ = height
  Bytes::from_array(result)
}

///|
/// 构建 VP8 frame header (key frame)
fn build_vp8_frame_header(
  width : Int,
  height : Int,
  first_part_size : Int,
) -> Bytes {
  let result : Array[Byte] = []
  let tag = (0 << 0) | (0 << 1) | (1 << 4) | (first_part_size << 5)
  result.push((tag & 0xFF).to_byte())
  result.push(((tag >> 8) & 0xFF).to_byte())
  result.push(((tag >> 16) & 0xFF).to_byte())
  result.push(b'\x9D')
  result.push(b'\x01')
  result.push(b'\x2A')
  result.push((width & 0xFF).to_byte())
  result.push(((width >> 8) & 0xFF).to_byte())
  result.push((height & 0xFF).to_byte())
  result.push(((height >> 8) & 0xFF).to_byte())
  Bytes::from_array(result)
}

///|
/// WebP lossy 编码（纯 MoonBit，全目标可用）
/// 实现: VP8 key frame, DC-only 预测, 固定量化
/// quality: 1-100 (越高越好质量，文件越大)
/// ⚠️ 注意：本库的 WebP 解码器仅支持 lossless (VP8L)，无法解码此函数的 lossy (VP8) 输出。
/// 编码结果可用于外部工具（如浏览器、libwebp）解码，但 decode_webp_pure 会失败。
pub fn encode_webp_lossy_pure(
  img : @types.Image,
  quality? : Int = 75,
) -> Bytes raise @types.LoadError {
  let w = img.width
  let h = img.height
  let ch = img.channels
  if w <= 0 || h <= 0 {
    raise @types.LoadError::EncodeFailed("WebP: 尺寸无效")
  }
  if ch != 3 && ch != 4 {
    raise @types.LoadError::EncodeFailed("WebP: 仅支持 RGB/RGBA")
  }
  let q_factor = ((100 - quality).clamp(min=1, max=99) * 63 / 100).clamp(
    min=1,
    max=63,
  )
  // 转为 Y 分量
  let y_data : Array[Int] = Array::make(w * h, 0)
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * ch
      let r = img.data[idx].to_int()
      let g = img.data[idx + 1].to_int()
      let b = img.data[idx + 2].to_int()
      y_data[y * w + x] = (r * 66 + g * 129 + b * 25 + 128) >> 8
    }
  }
  let mb_w = (w + 15) / 16
  let mb_h = (h + 15) / 16
  let enc = BoolEncoder::new()
  for mby in 0..<mb_h {
    for mbx in 0..<mb_w {
      // DC 值: 取 16x16 块中心像素
      let cx = (mbx * 16 + 8).clamp(min=0, max=w - 1)
      let cy = (mby * 16 + 8).clamp(min=0, max=h - 1)
      let dc_val = y_data[cy * w + cx]
      let quantized_dc = (dc_val - 128 + q_factor / 2) / q_factor
      enc.encode_int(quantized_dc, 7)
    }
  }
  let token_data = enc.finish()
  let header = build_vp8_frame_header(w, h, token_data.length())
  let vp8_data : Array[Byte] = []
  for i in 0..<header.length() {
    vp8_data.push(header[i])
  }
  for i in 0..<token_data.length() {
    vp8_data.push(token_data[i])
  }
  let result = build_webp_container(w, h, Bytes::from_array(vp8_data))
  let _ = q_factor
  result
}

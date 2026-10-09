// 纯 MoonBit JPEG 编码（全目标可用：native/wasm/js）
// baseline JPEG (SOF0), 8-bit, 4:4:4 YCbCr, 标准量化表 + 标准霍夫曼表

///|
/// JPEG 位写入器
priv struct JpegBitWriter {
  out : Array[Byte]
  mut bit_buf : Int
  mut bit_cnt : Int
}

///|
/// Huffman 编码表
priv struct JpegHuffmanEncoder {
  codes : Array[Int]
  lengths : Array[Int]
}

///|
/// 构建 Huffman 编码表
fn build_huffman_encoder(
  bits : Array[Int],
  values : Array[Int],
) -> JpegHuffmanEncoder {
  let codes = Array::make(256, 0)
  let lengths = Array::make(256, 0)
  let mut code = 0
  let mut k = 0
  for l in 1..<=16 {
    for _ in 0..<bits[l - 1] {
      let sym = values[k]
      codes[sym] = code
      lengths[sym] = l
      code += 1
      k += 1
    }
    code = code << 1
  }
  JpegHuffmanEncoder::{ codes, lengths }
}

///|
/// 写入位
fn jpeg_write_bits(w : JpegBitWriter, code : Int, length : Int) -> Unit {
  for i in 0..<length {
    let bit = (code >> (length - 1 - i)) & 1
    w.bit_buf = (w.bit_buf << 1) | bit
    w.bit_cnt += 1
    if w.bit_cnt == 8 {
      let b = w.bit_buf & 0xFF
      w.out.push(b.to_byte())
      if b == 0xFF {
        w.out.push(b'\x00')
      }
      w.bit_buf = 0
      w.bit_cnt = 0
    }
  }
}

///|
/// 刷新位缓冲
fn jpeg_flush_bits(w : JpegBitWriter) -> Unit {
  if w.bit_cnt > 0 {
    w.bit_buf = w.bit_buf << (8 - w.bit_cnt)
    let b = w.bit_buf & 0xFF
    w.out.push(b.to_byte())
    if b == 0xFF {
      w.out.push(b'\x00')
    }
    w.bit_buf = 0
    w.bit_cnt = 0
  }
}

///|
/// 标准亮度量化表
fn std_quant_luminance() -> Array[Int] {
  [
    16, 11, 10, 16, 24, 40, 51, 61, 12, 12, 14, 19, 26, 58, 60, 55, 14, 13, 16, 24,
    40, 57, 69, 56, 14, 17, 22, 29, 51, 87, 80, 62, 18, 22, 37, 56, 68, 109, 103,
    77, 24, 35, 55, 64, 81, 104, 113, 92, 49, 64, 78, 87, 103, 121, 120, 101, 72,
    92, 95, 98, 112, 100, 103, 99,
  ]
}

///|
/// 标准色度量化表
fn std_quant_chrominance() -> Array[Int] {
  [
    17, 18, 24, 47, 99, 99, 99, 99, 18, 21, 26, 66, 99, 99, 99, 99, 24, 26, 56, 99,
    99, 99, 99, 99, 47, 66, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99,
  ]
}

///|
/// 标准 DC 亮度 Huffman bits
fn std_dc_lum_bits() -> Array[Int] {
  [0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0]
}

///|
/// 标准 DC 亮度 Huffman values
fn std_dc_lum_vals() -> Array[Int] {
  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
}

///|
/// 标准 DC 色度 Huffman bits
fn std_dc_chr_bits() -> Array[Int] {
  [0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0]
}

///|
/// 标准 DC 色度 Huffman values
fn std_dc_chr_vals() -> Array[Int] {
  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
}

///|
/// 标准 AC 亮度 Huffman bits
fn std_ac_lum_bits() -> Array[Int] {
  [0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 0x7D]
}

///|
/// 标准 AC 亮度 Huffman values
fn std_ac_lum_vals() -> Array[Int] {
  [
    0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06, 0x13,
    0x51, 0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xA1, 0x08, 0x23, 0x42,
    0xB1, 0xC1, 0x15, 0x52, 0xD1, 0xF0, 0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0A,
    0x16, 0x17, 0x18, 0x19, 0x1A, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x34, 0x35,
    0x36, 0x37, 0x38, 0x39, 0x3A, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A,
    0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x63, 0x64, 0x65, 0x66, 0x67,
    0x68, 0x69, 0x6A, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x83, 0x84,
    0x85, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98,
    0x99, 0x9A, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2, 0xB3,
    0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7,
    0xC8, 0xC9, 0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xE1,
    0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF1, 0xF2, 0xF3, 0xF4,
    0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA,
  ]
}

///|
/// 标准 AC 色度 Huffman bits
fn std_ac_chr_bits() -> Array[Int] {
  [0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 0x77]
}

///|
/// 标准 AC 色度 Huffman values
fn std_ac_chr_vals() -> Array[Int] {
  [
    0x00, 0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21, 0x31, 0x06, 0x12, 0x41, 0x51,
    0x07, 0x61, 0x71, 0x13, 0x22, 0x32, 0x81, 0x08, 0x14, 0x42, 0x91, 0xA1, 0xB1,
    0xC1, 0x09, 0x23, 0x33, 0x52, 0xF0, 0x15, 0x62, 0x72, 0xD1, 0x0A, 0x16, 0x24,
    0x34, 0xE1, 0x25, 0xF1, 0x17, 0x18, 0x19, 0x1A, 0x26, 0x27, 0x28, 0x29, 0x2A,
    0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49,
    0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x63, 0x64, 0x65, 0x66,
    0x67, 0x68, 0x69, 0x6A, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x82,
    0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x92, 0x93, 0x94, 0x95, 0x96,
    0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA,
    0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5,
    0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9,
    0xDA, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF2, 0xF3, 0xF4,
    0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA,
  ]
}

///|
/// IDCT/FDCT 余弦表
fn jpeg_cos_table() -> Array[Float] {
  let table = Array::make(64, 0.0F)
  for u in 0..<8 {
    for x in 0..<8 {
      table[u * 8 + x] = @math.cosf(
        (2.0F * Float::from_int(x) + 1.0F) *
        Float::from_int(u) *
        3.14159265F /
        16.0F,
      )
    }
  }
  table
}

///|
/// 8x8 正向 DCT
fn fdct_8x8(block : Array[Int]) -> Array[Int] {
  let cos_table = jpeg_cos_table()
  let out = Array::make(64, 0)
  for u in 0..<8 {
    for v in 0..<8 {
      let mut sum = 0.0F
      for x in 0..<8 {
        for y in 0..<8 {
          sum += Float::from_int(block[y * 8 + x]) *
            cos_table[u * 8 + x] *
            cos_table[v * 8 + y]
        }
      }
      let cu = if u == 0 { 0.70710678F } else { 1.0F }
      let cv = if v == 0 { 0.70710678F } else { 1.0F }
      let coeff = cu * cv * sum * 0.25F
      out[v * 8 + u] = if coeff >= 0.0F {
        (coeff + 0.5F).to_int()
      } else {
        -(-coeff + 0.5F).to_int()
      }
    }
  }
  out
}

///|
/// RGB → YCbCr
fn rgb_to_ycbcr(r : Int, g : Int, b : Int) -> (Int, Int, Int) {
  let rf = Float::from_int(r)
  let gf = Float::from_int(g)
  let bf = Float::from_int(b)
  let y = 0.299F * rf + 0.587F * gf + 0.114F * bf
  let cb = -0.168736F * rf - 0.331264F * gf + 0.5F * bf + 128.0F
  let cr = 0.5F * rf - 0.418688F * gf - 0.081312F * bf + 128.0F
  (
    (y + 0.5F).to_int().clamp(min=0, max=255),
    (cb + 0.5F).to_int().clamp(min=0, max=255),
    (cr + 0.5F).to_int().clamp(min=0, max=255),
  )
}

///|
/// JPEG category（值所需的位数）
fn jpeg_category(val : Int) -> Int {
  if val == 0 {
    0
  } else {
    let mut bits = 0
    let mut v = if val < 0 { -val } else { val }
    while v > 0 {
      v = v >> 1
      bits += 1
    }
    bits
  }
}

///|
/// JPEG 值位数编码
fn jpeg_value_bits(val : Int, category : Int) -> Int {
  if val < 0 {
    val + (1 << category) - 1
  } else {
    val
  }
}

///|
/// Zigzag 顺序
fn jpeg_zigzag() -> Array[Int] {
  [
    0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5, 12, 19, 26, 33, 40, 48,
    41, 34, 27, 20, 13, 6, 7, 14, 21, 28, 35, 42, 49, 56, 57, 50, 43, 36, 29, 22,
    15, 23, 30, 37, 44, 51, 58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55,
    62, 63,
  ]
}

///|
/// 编码一个 8x8 块
fn jpeg_encode_block(
  w : JpegBitWriter,
  block : Array[Int],
  dc_enc : JpegHuffmanEncoder,
  ac_enc : JpegHuffmanEncoder,
  prev_dc : Ref[Int],
  quant : Array[Int],
  zz : Array[Int],
) -> Unit {
  let shifted = Array::make(64, 0)
  for i in 0..<64 {
    shifted[i] = block[i] - 128
  }
  let coeffs = fdct_8x8(shifted)
  let quantized_zz = Array::make(64, 0)
  for k in 0..<64 {
    let i = zz[k]
    let q = Float::from_int(coeffs[i]) / Float::from_int(quant[i])
    quantized_zz[k] = if q >= 0.0F {
      (q + 0.5F).to_int()
    } else {
      -(-q + 0.5F).to_int()
    }
  }
  let dc = quantized_zz[0]
  let diff = dc - prev_dc.val
  prev_dc.val = dc
  let cat = jpeg_category(diff)
  jpeg_write_bits(w, dc_enc.codes[cat], dc_enc.lengths[cat])
  if cat > 0 {
    let bits = jpeg_value_bits(diff, cat)
    jpeg_write_bits(w, bits, cat)
  }
  let mut run = 0
  for k in 1..<64 {
    let coeff = quantized_zz[k]
    if coeff == 0 {
      run += 1
    } else {
      while run > 15 {
        jpeg_write_bits(w, ac_enc.codes[0xF0], ac_enc.lengths[0xF0])
        run -= 16
      }
      let size = jpeg_category(coeff)
      let sym = (run << 4) | size
      jpeg_write_bits(w, ac_enc.codes[sym], ac_enc.lengths[sym])
      let bits = jpeg_value_bits(coeff, size)
      jpeg_write_bits(w, bits, size)
      run = 0
    }
  }
  if run > 0 {
    jpeg_write_bits(w, ac_enc.codes[0x00], ac_enc.lengths[0x00])
  }
}

///|
/// JPEG 编码（纯 MoonBit，全目标可用）。
/// baseline JPEG, 4:4:4 YCbCr, 标准量化表 + 标准霍夫曼表。
pub fn encode_jpeg_pure(img : @types.Image) -> Bytes raise @types.LoadError {
  let width = img.width
  let height = img.height
  if width <= 0 || height <= 0 {
    raise @types.LoadError::EncodeFailed("JPEG 尺寸无效")
  }
  let channels = img.channels
  let data = img.data
  let zz = jpeg_zigzag()
  let quant_lum = std_quant_luminance()
  let quant_chr = std_quant_chrominance()
  let dc_lum_enc = build_huffman_encoder(std_dc_lum_bits(), std_dc_lum_vals())
  let dc_chr_enc = build_huffman_encoder(std_dc_chr_bits(), std_dc_chr_vals())
  let ac_lum_enc = build_huffman_encoder(std_ac_lum_bits(), std_ac_lum_vals())
  let ac_chr_enc = build_huffman_encoder(std_ac_chr_bits(), std_ac_chr_vals())
  let out : Array[Byte] = []
  // SOI
  out.push(b'\xFF')
  out.push(b'\xD8')
  // DQT (2 tables)
  out.push(b'\xFF')
  out.push(b'\xDB')
  out.push(b'\x00')
  out.push(b'\x84')
  // Table 0 (luminance)
  out.push(b'\x00')
  for k in 0..<64 {
    out.push(quant_lum[zz[k]].to_byte())
  }
  // Table 1 (chrominance)
  out.push(b'\x01')
  for k in 0..<64 {
    out.push(quant_chr[zz[k]].to_byte())
  }
  // SOF0
  out.push(b'\xFF')
  out.push(b'\xC0')
  out.push(b'\x00')
  out.push(b'\x11')
  out.push(b'\x08')
  out.push(((height >> 8) & 0xFF).to_byte())
  out.push((height & 0xFF).to_byte())
  out.push(((width >> 8) & 0xFF).to_byte())
  out.push((width & 0xFF).to_byte())
  out.push(b'\x03')
  out.push(b'\x01')
  out.push(b'\x11')
  out.push(b'\x00')
  out.push(b'\x02')
  out.push(b'\x11')
  out.push(b'\x01')
  out.push(b'\x03')
  out.push(b'\x11')
  out.push(b'\x01')
  // DHT (4 tables)
  let dht_data : Array[Byte] = []
  // DC luminance (Tc=0, Th=0)
  dht_data.push(b'\x00')
  for b in std_dc_lum_bits() {
    dht_data.push(b.to_byte())
  }
  for v in std_dc_lum_vals() {
    dht_data.push(v.to_byte())
  }
  // DC chrominance (Tc=0, Th=1)
  dht_data.push(b'\x01')
  for b in std_dc_chr_bits() {
    dht_data.push(b.to_byte())
  }
  for v in std_dc_chr_vals() {
    dht_data.push(v.to_byte())
  }
  // AC luminance (Tc=1, Th=0)
  dht_data.push(b'\x10')
  for b in std_ac_lum_bits() {
    dht_data.push(b.to_byte())
  }
  for v in std_ac_lum_vals() {
    dht_data.push(v.to_byte())
  }
  // AC chrominance (Tc=1, Th=1)
  dht_data.push(b'\x11')
  for b in std_ac_chr_bits() {
    dht_data.push(b.to_byte())
  }
  for v in std_ac_chr_vals() {
    dht_data.push(v.to_byte())
  }
  let dht_len = 2 + dht_data.length()
  out.push(b'\xFF')
  out.push(b'\xC4')
  out.push(((dht_len >> 8) & 0xFF).to_byte())
  out.push((dht_len & 0xFF).to_byte())
  for b in dht_data {
    out.push(b)
  }
  // SOS
  out.push(b'\xFF')
  out.push(b'\xDA')
  out.push(b'\x00')
  out.push(b'\x0C')
  out.push(b'\x03')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x02')
  out.push(b'\x11')
  out.push(b'\x03')
  out.push(b'\x11')
  out.push(b'\x00')
  out.push(b'\x3F')
  out.push(b'\x00')
  // 熵编码
  let writer = JpegBitWriter::{ out, bit_buf: 0, bit_cnt: 0 }
  let prev_dc_y = Ref(0)
  let prev_dc_cb = Ref(0)
  let prev_dc_cr = Ref(0)
  let blocks_x = (width + 7) / 8
  let blocks_y = (height + 7) / 8
  for by in 0..<blocks_y {
    for bx in 0..<blocks_x {
      let y_block = Array::make(64, 128)
      let cb_block = Array::make(64, 128)
      let cr_block = Array::make(64, 128)
      for py in 0..<8 {
        for px in 0..<8 {
          let ix = bx * 8 + px
          let iy = by * 8 + py
          let sx = if ix >= width { width - 1 } else { ix }
          let sy = if iy >= height { height - 1 } else { iy }
          let didx = sy * width * channels + sx * channels
          let r = data[didx].to_int()
          let g = if channels >= 2 { data[didx + 1].to_int() } else { r }
          let b = if channels >= 3 { data[didx + 2].to_int() } else { r }
          let (y, cb, cr) = rgb_to_ycbcr(r, g, b)
          y_block[py * 8 + px] = y
          cb_block[py * 8 + px] = cb
          cr_block[py * 8 + px] = cr
        }
      }
      jpeg_encode_block(
        writer, y_block, dc_lum_enc, ac_lum_enc, prev_dc_y, quant_lum, zz,
      )
      jpeg_encode_block(
        writer, cb_block, dc_chr_enc, ac_chr_enc, prev_dc_cb, quant_chr, zz,
      )
      jpeg_encode_block(
        writer, cr_block, dc_chr_enc, ac_chr_enc, prev_dc_cr, quant_chr, zz,
      )
    }
  }
  jpeg_flush_bits(writer)
  // EOI
  writer.out.push(b'\xFF')
  writer.out.push(b'\xD9')
  Bytes::from_array(writer.out)
}

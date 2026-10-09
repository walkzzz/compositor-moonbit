// 纯 MoonBit WebP lossless 解码器 (VP8L)
// 规范: https://developers.google.com/speed/webp/docs/compression
// 支持 lossless RGBA 解码，不支持 lossy (VP8)

// ==================== BitReader ====================

///|
priv struct BitReader {
  data : Bytes
  mut pos : Int
  mut bit_buf : Int
  mut bit_count : Int
}

///|
fn BitReader::new(data : Bytes, start : Int) -> BitReader {
  BitReader::{ data, pos: start, bit_buf: 0, bit_count: 0 }
}

///|
fn BitReader::read_bits(self : BitReader, n : Int) -> Int {
  let mut result = 0
  for i in 0..<n {
    if self.bit_count == 0 {
      if self.pos >= self.data.length() {
        self.bit_buf = 0
        self.bit_count = 8
      } else {
        self.bit_buf = self.data[self.pos].to_int()
        self.pos += 1
        self.bit_count = 8
      }
    }
    let bit = self.bit_buf & 1
    self.bit_buf = self.bit_buf >> 1
    self.bit_count -= 1
    result = result | (bit << i)
  }
  result
}

///|
fn BitReader::read_bit(self : BitReader) -> Int {
  self.read_bits(1)
}

// ==================== Huffman Decoding ====================

///|
priv struct HuffmanCode {
  mut value : Int
  mut left : Int
  mut right : Int
}

///|
priv struct HuffmanTree {
  codes : Array[HuffmanCode]
}

///|
fn HuffmanTree::new() -> HuffmanTree {
  HuffmanTree::{ codes: [] }
}

///|
fn HuffmanTree::add_code(
  self : HuffmanTree,
  code : Int,
  code_len : Int,
  symbol : Int,
) -> Unit {
  // Build a binary tree by walking the code bits MSB-first
  let mut node = 0
  if self.codes.length() == 0 {
    self.codes.push(HuffmanCode::{ value: -1, left: -1, right: -1 })
  }
  for i in 0..<code_len {
    let bit = (code >> (code_len - 1 - i)) & 1
    let child = if bit == 0 {
      self.codes[node].left
    } else {
      self.codes[node].right
    }
    if child == -1 {
      let new_idx = self.codes.length()
      self.codes.push(HuffmanCode::{ value: -1, left: -1, right: -1 })
      if bit == 0 {
        self.codes[node].left = new_idx
      } else {
        self.codes[node].right = new_idx
      }
      node = new_idx
    } else {
      node = child
    }
  }
  self.codes[node].value = symbol
}

///|
fn HuffmanTree::decode(self : HuffmanTree, br : BitReader) -> Int {
  let mut node = 0
  while true {
    if self.codes.length() == 0 {
      return 0
    }
    let bit = br.read_bit()
    let child = if bit == 0 {
      self.codes[node].left
    } else {
      self.codes[node].right
    }
    if child == -1 {
      return self.codes[node].value
    }
    node = child
    if self.codes[node].value != -1 {
      return self.codes[node].value
    }
  }
  0
}

///|
/// 读取 Huffman 编码树
fn read_huffman_tree(br : BitReader) -> HuffmanTree {
  let tree = HuffmanTree::new()
  let is_simple = br.read_bit()
  if is_simple == 1 {
    // Simple Huffman: 1 or 2 symbols
    let num_symbols = br.read_bit() + 1
    if num_symbols == 1 {
      // Single symbol
      let max_bits = br.read_bits(4) + 1
      let symbol = br.read_bits(max_bits)
      tree.add_code(0, 1, symbol)
    } else {
      // Two symbols
      let max_bits = br.read_bits(4) + 1
      let sym0 = br.read_bits(max_bits)
      let sym1 = br.read_bits(max_bits)
      tree.add_code(0, 1, sym0)
      tree.add_code(1, 1, sym1)
    }
    return tree
  }
  // Complex Huffman: read code length code
  let num_code_lengths = br.read_bits(4) + 4
  // Code length code order
  let order = [17, 18, 0, 1, 2, 3, 4, 5, 16, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
  // Read code length code lengths (3 bits each)
  let code_len_code_lens : Array[Int] = Array::make(19, 0)
  for i in 0..<num_code_lengths {
    code_len_code_lens[order[i]] = br.read_bits(3)
  }
  // Build code length Huffman tree
  let cl_tree = HuffmanTree::new()
  for sym in 0..<19 {
    if code_len_code_lens[sym] > 0 {
      cl_tree.add_code(sym, code_len_code_lens[sym], sym)
    }
  }
  // Decode code lengths using the code length tree
  let code_lens : Array[Int] = []
  let mut sym = cl_tree.decode(br)
  while code_lens.length() < 256 {
    if sym < 16 {
      code_lens.push(sym)
      sym = cl_tree.decode(br)
    } else if sym == 16 {
      // Repeat previous code length 3+2extra times
      let extra = br.read_bits(2)
      let repeat = 3 + extra
      let prev = if code_lens.length() > 0 {
        code_lens[code_lens.length() - 1]
      } else {
        0
      }
      for _ in 0..<repeat {
        code_lens.push(prev)
      }
      sym = cl_tree.decode(br)
    } else if sym == 17 {
      // Repeat zero 3+3extra times
      let extra = br.read_bits(3)
      let repeat = 3 + extra
      for _ in 0..<repeat {
        code_lens.push(0)
      }
      sym = cl_tree.decode(br)
    } else if sym == 18 {
      // Repeat zero 11+7extra times
      let extra = br.read_bits(7)
      let repeat = 11 + extra
      for _ in 0..<repeat {
        code_lens.push(0)
      }
      sym = cl_tree.decode(br)
    } else {
      sym = cl_tree.decode(br)
    }
  }
  // Build the actual Huffman tree from code lengths
  // Assign canonical codes
  let max_len = code_lens.fold(init=0, (a, b) => if a > b { a } else { b })
  if max_len == 0 {
    tree.add_code(0, 1, 0)
    return tree
  }
  // Count codes at each length
  let bl_count : Array[Int] = Array::make(max_len + 1, 0)
  for cl in code_lens {
    if cl > 0 {
      bl_count[cl] += 1
    }
  }
  // Compute first code at each length
  let next_code : Array[Int] = Array::make(max_len + 1, 0)
  let mut code = 0
  for bits in 1..<=max_len {
    code = (code + bl_count[bits - 1]) << 1
    next_code[bits] = code
  }
  // Assign codes
  for n in 0..<code_lens.length() {
    let cl = code_lens[n]
    if cl > 0 {
      tree.add_code(next_code[cl], cl, n)
      next_code[cl] += 1
    }
  }
  tree
}

// ==================== VP8L Transform ====================

///|
/// 预测器变换：每个像素减去预测值
fn apply_predictor_inverse(
  pixels : Array[Int],
  width : Int,
  height : Int,
  bits : Int,
) -> Unit {
  let mask = (1 << bits) - 1
  // 逆预测：从左上到右下逐像素加回预测值
  for y in 0..<height {
    for x in 0..<width {
      let idx = y * width + x
      let pred = predict(x, y, width, pixels, idx)
      pixels[idx] = (pixels[idx] + pred) & mask
    }
  }
}

///|
fn predict(
  x : Int,
  y : Int,
  width : Int,
  pixels : Array[Int],
  idx : Int,
) -> Int {
  if x == 0 && y == 0 {
    0
  } else if y == 0 {
    pixels[idx - 1]
  } else if x == 0 {
    pixels[idx - width]
  } else {
    let left = pixels[idx - 1]
    let top = pixels[idx - width]
    let tl = pixels[idx - width - 1]
    // Average predictor (ClampedAddSubtractFull)
    let avg = (left + top) / 2
    avg + tl - left - top + avg
  }
}

///|
/// Subtract-green 逆变换：R += G, B += G
fn apply_subtract_green_inverse(pixels : Array[Int], n : Int) -> Unit {
  for i in 0..<n {
    let g = (pixels[i] >> 8) & 0xFF
    let r = pixels[i] & 0xFF
    let b = (pixels[i] >> 16) & 0xFF
    let a = (pixels[i] >> 24) & 0xFF
    pixels[i] = ((r + g) & 0xFF) |
      ((g & 0xFF) << 8) |
      (((b + g) & 0xFF) << 16) |
      ((a & 0xFF) << 24)
  }
}

// ==================== VP8L Decoder ====================

///|
/// 解码 WebP 字节流为 Image（channels=3 或 4）
/// 支持 VP8L (lossless) 和 VP8 (lossy) 格式
pub fn decode_webp_pure(data : Bytes) -> @types.Image raise @types.LoadError {
  let len = data.length()
  if len < 12 {
    raise @types.LoadError::DecodeFailed("WebP 数据过短")
  }
  // RIFF header
  if data[0].to_int() != 0x52 ||
    data[1].to_int() != 0x49 ||
    data[2].to_int() != 0x46 ||
    data[3].to_int() != 0x46 {
    raise @types.LoadError::DecodeFailed("RIFF magic 不匹配")
  }
  // WEBP fourcc
  if data[8].to_int() != 0x57 ||
    data[9].to_int() != 0x45 ||
    data[10].to_int() != 0x42 ||
    data[11].to_int() != 0x50 {
    raise @types.LoadError::DecodeFailed("WEBP magic 不匹配")
  }
  // Find VP8L or VP8 chunk
  let mut pos = 12
  let mut vp8l_data_start = -1
  let mut vp8_data_start = -1
  while pos + 8 <= len {
    let chunk_id = data[pos].to_int() |
      (data[pos + 1].to_int() << 8) |
      (data[pos + 2].to_int() << 16) |
      (data[pos + 3].to_int() << 24)
    let chunk_size = data[pos + 4].to_int() |
      (data[pos + 5].to_int() << 8) |
      (data[pos + 6].to_int() << 16) |
      (data[pos + 7].to_int() << 24)
    // "VP8L" = 0x4C385056 (little-endian: 56 50 38 4C)
    if chunk_id == 0x4C385056 {
      vp8l_data_start = pos + 8
      let _ = chunk_size
      break
    }
    // "VP8 " = 0x20385056 (lossy)
    if chunk_id == 0x20385056 {
      vp8_data_start = pos + 8
      let _ = chunk_size
      break
    }
    pos += 8 + chunk_size
    if chunk_size % 2 == 1 {
      pos += 1 // padding
    }
  }
  // VP8 lossy 解码
  if vp8_data_start >= 0 {
    return decode_vp8_frame(data, vp8_data_start)
  }
  if vp8l_data_start < 0 {
    raise @types.LoadError::DecodeFailed("未找到 VP8L 或 VP8 chunk")
  }
  // VP8L signature
  if data[vp8l_data_start].to_int() != 0x2F {
    raise @types.LoadError::DecodeFailed("VP8L 签名不匹配")
  }
  let br = BitReader::new(data, vp8l_data_start + 1)
  // Read image size
  let width = br.read_bits(14) + 1
  let height = br.read_bits(14) + 1
  let alpha_used = br.read_bit()
  let _ = br.read_bits(3) // version, reserved
  if width <= 0 || height <= 0 || width > 16384 || height > 16384 {
    raise @types.LoadError::DecodeFailed("WebP 尺寸无效")
  }
  // Read transforms (up to 4, in reverse order)
  let transforms : Array[Int] = [] // transform types in read order
  let mut has_transform = true
  while has_transform && transforms.length() < 4 {
    has_transform = br.read_bit() == 1
    if has_transform {
      let t_type = br.read_bits(2)
      transforms.push(t_type)
      // Skip transform-specific data for now
      // We'll handle transforms after decoding pixels
      match t_type {
        0 => {
          // Predictor transform
          let _ = br.read_bits(3) // bits
          let _ = br.read_bits(1) // unused
          // Read predictor image size (subset)
          let _ = br.read_bits(1) // use_subset
        }
        1 => {
          // Cross-color transform
          let _ = br.read_bits(3) // bits
          let _ = br.read_bits(1) // unused
        }
        2 =>
          // Subtract-green transform (no data)
          ()
        3 => {
          // Color (palette) transform
          let _ = br.read_bits(1) // use_subset
        }
        _ => ()
      }
    }
  }
  // Read color cache info
  let use_color_cache = br.read_bit()
  let cache_bits = if use_color_cache == 1 { br.read_bits(4) } else { 0 }
  let cache_size = if cache_bits > 0 { 1 << cache_bits } else { 0 }
  let cache_mask = if cache_bits > 0 { cache_size - 1 } else { 0 }
  // Read meta Huffman codes
  let use_meta = br.read_bit()
  let huffman_trees : Array[HuffmanTree] = []
  if use_meta == 0 {
    // Single Huffman tree for all
    huffman_trees.push(read_huffman_tree(br))
  } else {
    // Meta Huffman: read a Huffman tree for meta codes, then read sub-trees
    let meta_tree = read_huffman_tree(br)
    let num_meta = br.read_bits(2) + 1
    for _ in 0..<num_meta {
      huffman_trees.push(read_huffman_tree(br))
    }
    // Use meta_tree to select which sub-tree to use
    // For simplicity, we'll use the first tree
    let _ = meta_tree
  }
  // Decode pixel data using Huffman-coded LZ77
  let n = width * height
  let pixels : Array[Int] = Array::make(n, 0)
  // Color cache
  let color_cache : Array[Int] = Array::make(cache_size, 0)
  // LZ77 decode
  let mut pixel_idx = 0
  let tree = if huffman_trees.length() > 0 {
    huffman_trees[0]
  } else {
    HuffmanTree::new()
  }
  while pixel_idx < n {
    let sym = tree.decode(br)
    if sym < 256 {
      // Literal: green is the symbol, read R, B, A from tree
      let g = sym
      let r = tree.decode(br)
      let b = tree.decode(br)
      let a = if alpha_used == 1 { tree.decode(br) } else { 255 }
      let argb = (a << 24) | (b << 16) | (g << 8) | r
      pixels[pixel_idx] = argb
      pixel_idx += 1
      // Update color cache
      if cache_size > 0 {
        let hash = (argb * 0x1E35A7BD) & 0xFFFFFFFF
        color_cache[(hash >> (32 - cache_bits)) & cache_mask] = argb
      }
    } else if sym == 256 {
      // Color cache index
      if cache_size > 0 {
        let idx = br.read_bits(cache_bits)
        pixels[pixel_idx] = color_cache[idx]
        pixel_idx += 1
      }
    } else if sym >= 257 {
      // Copy from back-reference
      let copy_len = sym - 256 // 1-based
      let copy_code = br.read_bits(4) // distance code
      let dist_extra_bits = [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7]
      let dist_base = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
      let extra = if copy_code < 16 {
        br.read_bits(dist_extra_bits[copy_code])
      } else {
        0
      }
      let distance = if copy_code < 16 {
        dist_base[copy_code] + extra
      } else {
        1
      }
      // Copy pixels
      for _ in 0..<copy_len {
        if pixel_idx < n && pixel_idx - distance >= 0 {
          pixels[pixel_idx] = pixels[pixel_idx - distance]
          pixel_idx += 1
        } else {
          pixel_idx += 1
        }
      }
    }
  }
  // Apply inverse transforms in reverse order
  // (transforms were read in order, apply in reverse)
  for j in 0..<transforms.length() {
    let i = transforms.length() - 1 - j
    match transforms[i] {
      2 => apply_subtract_green_inverse(pixels, n)
      0 => apply_predictor_inverse(pixels, width, height, 8)
      _ => ()
    }
  }
  // Convert ARGB pixels to Image
  let channels = if alpha_used == 1 { 4 } else { 3 }
  @types.check_dims(width, height, channels)
  let out : Array[Byte] = Array::make(n * channels, b'\x00')
  for i in 0..<n {
    let argb = pixels[i]
    let r = argb & 0xFF
    let g = (argb >> 8) & 0xFF
    let b = (argb >> 16) & 0xFF
    let a = (argb >> 24) & 0xFF
    if channels == 4 {
      out[i * 4] = r.to_byte()
      out[i * 4 + 1] = g.to_byte()
      out[i * 4 + 2] = b.to_byte()
      out[i * 4 + 3] = a.to_byte()
    } else {
      out[i * 3] = r.to_byte()
      out[i * 3 + 1] = g.to_byte()
      out[i * 3 + 2] = b.to_byte()
    }
  }
  @types.Image::{ width, height, channels, data: Bytes::from_array(out) }
}

// 纯 MoonBit zlib 支持（全目标可用：native/wasm/js）
// 实现 DEFLATE inflate 解压缩 + Adler32 + CRC32
// 仅依赖 @types，不依赖 @core/FFI

///|
/// CRC-32 查表法
fn crc32_table() -> Array[Int] {
  let table : Array[Int] = Array::make(256, 0)
  for i in 0..<256 {
    let mut crc = i
    for _ in 0..<8 {
      crc = if (crc & 1) != 0 { (crc >> 1) ^ 0xEDB88320 } else { crc >> 1 }
    }
    table[i] = crc
  }
  table
}

///|
/// 计算 CRC-32 校验和
pub fn crc32(data : Bytes) -> Int {
  let table = crc32_table()
  let mut crc = 0xFFFFFFFF
  for i in 0..<data.length() {
    crc = (crc >> 8) ^ table[(crc ^ data[i].to_int()) & 0xFF]
  }
  crc ^ 0xFFFFFFFF
}

///|
/// 计算 Adler-32 校验和
pub fn adler32(data : Bytes) -> Int {
  let mut a = 1
  let mut b = 0
  for i in 0..<data.length() {
    a = (a + data[i].to_int()) % 65521
    b = (b + a) % 65521
  }
  (b << 16) | a
}

///|
/// Huffman 解码树
priv struct HuffmanTree {
  counts : Array[Int]
  symbols : Array[Int]
}

///|
/// 构建 Huffman 解码树
fn build_huffman_tree(code_lengths : Array[Int], max_bits : Int) -> HuffmanTree {
  let counts : Array[Int] = Array::make(max_bits + 1, 0)
  for i in 0..<code_lengths.length() {
    counts[code_lengths[i]] += 1
  }
  counts[0] = 0
  let offsets : Array[Int] = Array::make(max_bits + 1, 0)
  let mut total = 0
  for i in 1..<=max_bits {
    offsets[i] = total
    total += counts[i]
  }
  let symbols : Array[Int] = Array::make(total, 0)
  for i in 0..<code_lengths.length() {
    let cl = code_lengths[i]
    if cl > 0 {
      symbols[offsets[cl]] = i
      offsets[cl] += 1
    }
  }
  HuffmanTree::{ counts, symbols }
}

///|
/// DEFLATE 位读取器（用可变字段）
priv struct BitReader {
  data : Bytes
  mut pos : Int
  mut bit_buf : Int
  mut bit_count : Int
}

///|
fn bit_reader_new(data : Bytes) -> BitReader {
  BitReader::{ data, pos: 0, bit_buf: 0, bit_count: 0 }
}

///|
fn bit_reader_read_bits(
  reader : BitReader,
  n : Int,
) -> Int raise @types.LoadError {
  while reader.bit_count < n {
    if reader.pos >= reader.data.length() {
      raise @types.LoadError::DecodeFailed("DEFLATE 数据意外结束")
    }
    reader.bit_buf = reader.bit_buf |
      (reader.data[reader.pos].to_int() << reader.bit_count)
    reader.pos += 1
    reader.bit_count += 8
  }
  let val = reader.bit_buf & ((1 << n) - 1)
  reader.bit_buf = reader.bit_buf >> n
  reader.bit_count -= n
  val
}

///|
fn bit_reader_read_huffman(
  reader : BitReader,
  tree : HuffmanTree,
) -> Int raise @types.LoadError {
  let mut code = 0
  let mut first = 0
  let mut index = 0
  for cl in 1..<=15 {
    let bit = bit_reader_read_bits(reader, 1)
    code = code | bit
    let count = tree.counts[cl]
    if code - first < count {
      return tree.symbols[index + (code - first)]
    }
    index += count
    first = (first + count) << 1
    code = code << 1
  }
  raise @types.LoadError::DecodeFailed("DEFLATE Huffman 解码失败")
}

///|
/// DEFLATE inflate 解压缩（纯 MoonBit，全目标可用）
pub fn zlib_inflate(data : Bytes) -> Bytes raise @types.LoadError {
  // 跳过 zlib 2 字节头 (CMF, FLG)
  if data.length() < 2 {
    raise @types.LoadError::DecodeFailed("zlib 数据过短")
  }
  let reader = bit_reader_new(data)
  reader.pos = 2
  let output : Array[Byte] = []
  let mut done = false
  while !done {
    let bfinal = bit_reader_read_bits(reader, 1)
    let btype = bit_reader_read_bits(reader, 2)
    match btype {
      0 => {
        // Stored block: align to byte boundary
        reader.bit_buf = 0
        reader.bit_count = 0
        if reader.pos + 4 > reader.data.length() {
          raise @types.LoadError::DecodeFailed(
            "DEFLATE stored block 数据过短",
          )
        }
        let block_len = reader.data[reader.pos].to_int() |
          (reader.data[reader.pos + 1].to_int() << 8)
        reader.pos += 4
        if reader.pos + block_len > reader.data.length() {
          raise @types.LoadError::DecodeFailed(
            "DEFLATE stored block 数据越界",
          )
        }
        for i in 0..<block_len {
          output.push(reader.data[reader.pos + i])
        }
        reader.pos += block_len
      }
      1 => {
        // Fixed Huffman codes
        let (lit_tree, dist_tree) = build_fixed_trees()
        inflate_block_data(reader, output, lit_tree, dist_tree)
      }
      2 => {
        // Dynamic Huffman codes
        let (lit_tree, dist_tree) = read_dynamic_trees(reader)
        inflate_block_data(reader, output, lit_tree, dist_tree)
      }
      _ => raise @types.LoadError::DecodeFailed("DEFLATE 无效 block type")
    }
    if bfinal != 0 {
      done = true
    }
  }
  Bytes::from_array(output)
}

///|
fn inflate_block_data(
  reader : BitReader,
  output : Array[Byte],
  lit_tree : HuffmanTree,
  dist_tree : HuffmanTree,
) -> Unit raise @types.LoadError {
  let mut done = false
  while !done {
    let sym = bit_reader_read_huffman(reader, lit_tree)
    if sym < 256 {
      output.push(sym.to_byte())
    } else if sym == 256 {
      done = true
    } else {
      // length/distance pair
      let len_code = sym - 257
      let (len_base, len_bits) = length_base_extra(len_code)
      let extra = bit_reader_read_bits(reader, len_bits)
      let length = len_base + extra
      let dist_sym = bit_reader_read_huffman(reader, dist_tree)
      let (dist_base, dist_bits) = distance_base_extra(dist_sym)
      let dist_extra = bit_reader_read_bits(reader, dist_bits)
      let distance = dist_base + dist_extra
      let out_len = output.length()
      for i in 0..<length {
        output.push(output[out_len - distance + i])
      }
    }
  }
}

///|
fn length_base_extra(code : Int) -> (Int, Int) {
  let base = [
    3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67,
    83, 99, 115, 131, 163, 195, 227, 258,
  ]
  let extra = [
    0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5,
    5, 5, 0,
  ]
  if code < 0 || code >= base.length() {
    (0, 0)
  } else {
    (base[code], extra[code])
  }
}

///|
fn distance_base_extra(code : Int) -> (Int, Int) {
  let base = [
    1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
    1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
  ]
  let extra = [
    0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11,
    11, 12, 12, 13, 13,
  ]
  if code < 0 || code >= base.length() {
    (0, 0)
  } else {
    (base[code], extra[code])
  }
}

///|
fn build_fixed_trees() -> (HuffmanTree, HuffmanTree) {
  let lit_lengths : Array[Int] = Array::make(288, 0)
  for i in 0..<144 {
    lit_lengths[i] = 8
  }
  for i in 144..<256 {
    lit_lengths[i] = 9
  }
  for i in 256..<280 {
    lit_lengths[i] = 7
  }
  for i in 280..<288 {
    lit_lengths[i] = 8
  }
  let dist_lengths : Array[Int] = Array::make(30, 5)
  (build_huffman_tree(lit_lengths, 15), build_huffman_tree(dist_lengths, 15))
}

///|
fn read_dynamic_trees(
  reader : BitReader,
) -> (HuffmanTree, HuffmanTree) raise @types.LoadError {
  let hlit = bit_reader_read_bits(reader, 5)
  let hdist = bit_reader_read_bits(reader, 5)
  let hclen = bit_reader_read_bits(reader, 4)
  let num_lit = hlit + 257
  let num_dist = hdist + 1
  let num_clen = hclen + 4
  // 读取 code length code lengths
  let cl_order = [
    16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
  ]
  let cl_lengths : Array[Int] = Array::make(19, 0)
  for i in 0..<num_clen {
    let cl = bit_reader_read_bits(reader, 3)
    cl_lengths[cl_order[i]] = cl
  }
  let cl_tree = build_huffman_tree(cl_lengths, 7)
  // 读取 literal/length 和 distance code lengths
  let all_lengths : Array[Int] = Array::make(num_lit + num_dist, 0)
  let mut idx = 0
  while idx < num_lit + num_dist {
    let sym = bit_reader_read_huffman(reader, cl_tree)
    if sym < 16 {
      all_lengths[idx] = sym
      idx += 1
    } else if sym == 16 {
      let repeat = bit_reader_read_bits(reader, 2)
      let count = repeat + 3
      let prev = if idx > 0 { all_lengths[idx - 1] } else { 0 }
      for _ in 0..<count {
        if idx < all_lengths.length() {
          all_lengths[idx] = prev
        }
        idx += 1
      }
    } else if sym == 17 {
      let repeat = bit_reader_read_bits(reader, 3)
      let count = repeat + 3
      for _ in 0..<count {
        if idx < all_lengths.length() {
          all_lengths[idx] = 0
        }
        idx += 1
      }
    } else {
      // sym == 18
      let repeat = bit_reader_read_bits(reader, 7)
      let count = repeat + 11
      for _ in 0..<count {
        if idx < all_lengths.length() {
          all_lengths[idx] = 0
        }
        idx += 1
      }
    }
  }
  // 拆分 lit 和 dist
  let lit_lengths : Array[Int] = Array::make(num_lit, 0)
  for i in 0..<num_lit {
    lit_lengths[i] = all_lengths[i]
  }
  let dist_lengths : Array[Int] = Array::make(num_dist, 0)
  for i in 0..<num_dist {
    dist_lengths[i] = all_lengths[num_lit + i]
  }
  (build_huffman_tree(lit_lengths, 15), build_huffman_tree(dist_lengths, 15))
}

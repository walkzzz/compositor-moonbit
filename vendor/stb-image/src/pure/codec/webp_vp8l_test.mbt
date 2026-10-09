// WebP VP8L 位流构造与高级解码路径测试
// 覆盖: 两符号简单 Huffman、复杂 Huffman (sym16/sym17/无效符号/canonical)、
//       变换 (predictor / subtract-green / cross-color / palette)、
//       color cache、LZ77 回参考、meta huffman、RIFF 奇数 chunk padding

///|
/// 向位数组写入 n 位 (LSB-first，与解码器 BitReader 读取顺序一致)
fn wv_write_bits(bits : Array[Int], value : Int, n : Int) -> Unit {
  for i in 0..<n {
    bits.push((value >> i) & 1)
  }
}

///|
/// 写入 VP8L 图像头: width-1(14) height-1(14) alpha(1) version(3)
fn wv_header(bits : Array[Int], width : Int, height : Int, alpha : Int) -> Unit {
  wv_write_bits(bits, width - 1, 14)
  wv_write_bits(bits, height - 1, 14)
  wv_write_bits(bits, alpha, 1)
  wv_write_bits(bits, 0, 3)
}

///|
/// MSB-first 写入 Huffman 码 (add_code/decode 按码位 MSB-first 遍历树)
fn wv_write_code_msb(bits : Array[Int], code : Int, len : Int) -> Unit {
  for i in 0..<len {
    bits.push((code >> (len - 1 - i)) & 1)
  }
}

///|
/// 简单 Huffman 树 (单符号): is_simple=1, num_symbols=1
fn wv_simple_tree_1sym(bits : Array[Int], max_bits : Int, symbol : Int) -> Unit {
  wv_write_bits(bits, 1, 1)
  wv_write_bits(bits, 0, 1)
  wv_write_bits(bits, max_bits - 1, 4)
  wv_write_bits(bits, symbol, max_bits)
}

///|
/// 简单 Huffman 树 (两符号): 覆盖 add_code 右子树路径
fn wv_simple_tree_2sym(
  bits : Array[Int],
  max_bits : Int,
  s0 : Int,
  s1 : Int,
) -> Unit {
  wv_write_bits(bits, 1, 1)
  wv_write_bits(bits, 1, 1)
  wv_write_bits(bits, max_bits - 1, 4)
  wv_write_bits(bits, s0, max_bits)
  wv_write_bits(bits, s1, max_bits)
}

///|
/// 位数组打包为 VP8L 数据 (前置 0x2F 签名字节，LSB-first 填充)
fn wv_pack(bits : Array[Int]) -> Bytes {
  let out : Array[Byte] = [0x2F]
  let total = bits.length()
  let mut i = 0
  while i < total {
    let mut byte = 0
    let mut j = 0
    while j < 8 && i < total {
      byte = byte | (bits[i] << j)
      i += 1
      j += 1
    }
    out.push(byte.to_byte())
  }
  Bytes::from_array(out)
}

///|
/// 将 VP8L 数据包进 RIFF/WEBP 容器
fn wv_wrap(vp8l : Bytes) -> Bytes {
  let vp8l_len = vp8l.length()
  let riff_size = 4 + 8 + vp8l_len
  let result : Array[Byte] = []
  result.push(b'R')
  result.push(b'I')
  result.push(b'F')
  result.push(b'F')
  result.push((riff_size & 0xFF).to_byte())
  result.push(((riff_size >> 8) & 0xFF).to_byte())
  result.push(((riff_size >> 16) & 0xFF).to_byte())
  result.push(((riff_size >> 24) & 0xFF).to_byte())
  result.push(b'W')
  result.push(b'E')
  result.push(b'B')
  result.push(b'P')
  result.push(b'V')
  result.push(b'P')
  result.push(b'8')
  result.push(b'L')
  result.push((vp8l_len & 0xFF).to_byte())
  result.push(((vp8l_len >> 8) & 0xFF).to_byte())
  result.push(((vp8l_len >> 16) & 0xFF).to_byte())
  result.push(((vp8l_len >> 24) & 0xFF).to_byte())
  for i in 0..<vp8l_len {
    result.push(vp8l[i])
  }
  Bytes::from_array(result)
}

///|
test "decode_webp: 2符号简单 Huffman 解码" {
  // 覆盖 read_huffman_tree 两符号分支 + add_code 右子树
  let bits : Array[Int] = []
  wv_header(bits, 1, 1, 0)
  wv_write_bits(bits, 0, 1) // 无变换
  wv_write_bits(bits, 0, 1) // 无 color cache
  wv_write_bits(bits, 0, 1) // 无 meta huffman
  wv_simple_tree_2sym(bits, 4, 4, 9) // sym0=4 (code "0"), sym1=9 (code "1")
  // 像素: g=sym0(bit0), r=sym1(bit1), b=sym0(bit0)
  wv_write_bits(bits, 0, 1)
  wv_write_bits(bits, 1, 1)
  wv_write_bits(bits, 0, 1)
  let img = decode_webp_pure(wv_wrap(wv_pack(bits)))
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 3)
  assert_eq(img.data[0].to_int(), 9) // r
  assert_eq(img.data[1].to_int(), 4) // g
  assert_eq(img.data[2].to_int(), 4) // b
}

///|
test "decode_webp: alpha 通道 4 通道输出" {
  // alpha_used=1 → 每像素 4 次解码 (g,r,b,a)，输出 4 通道
  let bits : Array[Int] = []
  wv_header(bits, 1, 1, 1) // alpha_used=1
  wv_write_bits(bits, 0, 1)
  wv_write_bits(bits, 0, 1)
  wv_write_bits(bits, 0, 1)
  wv_simple_tree_1sym(bits, 8, 200)
  wv_write_bits(bits, 0, 4) // g,r,b,a 全部 bit=0 → 200
  let img = decode_webp_pure(wv_wrap(wv_pack(bits)))
  assert_eq(img.width, 1)
  assert_eq(img.channels, 4)
  assert_eq(img.data.length(), 4)
  for i in 0..<4 {
    assert_eq(img.data[i].to_int(), 200)
  }
}

///|
test "decode_webp: color cache 读写" {
  // sym=256 → 从 color cache 读取像素
  let bits : Array[Int] = []
  wv_header(bits, 2, 1, 0)
  wv_write_bits(bits, 0, 1) // 无变换
  wv_write_bits(bits, 1, 1) // 使用 color cache
  wv_write_bits(bits, 1, 4) // cache_bits=1 → cache_size=2
  wv_write_bits(bits, 0, 1) // 无 meta
  wv_simple_tree_2sym(bits, 9, 0, 256) // sym0=0 (literal), sym1=256 (cache)
  // 像素0: literal (g,r,b)=(0,0,0) → argb 写入 cache
  wv_write_bits(bits, 0, 3)
  // 像素1: sym=256 (bit 1) → 读 cache_bits 位索引
  let argb = (255 << 24) | (0 << 16) | (0 << 8) | 0
  let hash = (argb * 0x1E35A7BD) & 0xFFFFFFFF
  let slot = (hash >> 31) & 1
  wv_write_bits(bits, 1, 1) // sym=256
  wv_write_bits(bits, slot, 1) // cache index → 命中像素0
  let img = decode_webp_pure(wv_wrap(wv_pack(bits)))
  assert_eq(img.width, 2)
  assert_eq(img.channels, 3)
  // 命中 cache → 像素1 与像素0 相同 (全黑)
  assert_eq(img.data[0].to_int(), 0)
  assert_eq(img.data[3].to_int(), 0)
  assert_eq(img.data[4].to_int(), 0)
  assert_eq(img.data[5].to_int(), 0)
}

///|
test "decode_webp: LZ77 回参考距离越界安全" {
  // sym=257 (copy_len=1) 在 pixel_idx=0 时 distance=1 越界 → 安全跳过
  let bits : Array[Int] = []
  wv_header(bits, 2, 1, 0)
  wv_write_bits(bits, 0, 1)
  wv_write_bits(bits, 0, 1)
  wv_write_bits(bits, 0, 1)
  wv_simple_tree_2sym(bits, 9, 0, 257) // sym1=257 → copy_len=1
  // 像素0: sym=257 → copy_code=0 → distance=1; 0-1<0 → 跳过 (pixel_idx+=1)
  wv_write_bits(bits, 1, 1) // sym=257
  wv_write_bits(bits, 0, 4) // copy_code=0
  // 像素1: literal (0,0,0)
  wv_write_bits(bits, 0, 3)
  let img = decode_webp_pure(wv_wrap(wv_pack(bits)))
  assert_eq(img.width, 2)
  assert_eq(img.data.length(), 6)
  for i in 0..<6 {
    assert_eq(img.data[i].to_int(), 0)
  }
}

///|
test "decode_webp: predictor+subtract-green 变换 2x2" {
  // 变换读取顺序 [subtract-green, predictor]；应用顺序相反:
  // 先 predictor 逆变换，再 subtract-green 逆变换
  let bits : Array[Int] = []
  wv_header(bits, 2, 2, 0)
  // 变换1: subtract-green (type 2)
  wv_write_bits(bits, 1, 1) // has_transform
  wv_write_bits(bits, 2, 2) // type=2
  // 变换2: predictor (type 0)
  wv_write_bits(bits, 1, 1) // has_transform
  wv_write_bits(bits, 0, 2) // type=0
  wv_write_bits(bits, 0, 3) // bits
  wv_write_bits(bits, 0, 1) // unused
  wv_write_bits(bits, 0, 1) // use_subset
  wv_write_bits(bits, 0, 1) // 无更多变换
  wv_write_bits(bits, 0, 1) // 无 cache
  wv_write_bits(bits, 0, 1) // 无 meta
  wv_simple_tree_1sym(bits, 8, 200) // 所有解码 → 200
  // 4 像素 × 3 通道 (alpha=0) = 12 次 bit=0 → 每像素 argb=0xFF00C8C8
  wv_write_bits(bits, 0, 12)
  let img = decode_webp_pure(wv_wrap(wv_pack(bits)))
  assert_eq(img.width, 2)
  assert_eq(img.height, 2)
  assert_eq(img.channels, 3)
  // predictor 逆变换 (mask=0xFF) 后: pixels=[0xC8,0x90,0x90,0x90]
  // subtract-green 逆变换后: 像素0=(200,0,0), 其余=(144,0,0)
  assert_eq(img.data[0].to_int(), 200)
  assert_eq(img.data[1].to_int(), 0)
  assert_eq(img.data[2].to_int(), 0)
  assert_eq(img.data[3].to_int(), 144)
  assert_eq(img.data[4].to_int(), 0)
  assert_eq(img.data[5].to_int(), 0)
  assert_eq(img.data[6].to_int(), 144)
  assert_eq(img.data[9].to_int(), 144)
}

///|
test "decode_webp: cross-color+palette 变换与 meta huffman" {
  let bits : Array[Int] = []
  wv_header(bits, 1, 1, 0)
  // 变换1: cross-color (type 1)
  wv_write_bits(bits, 1, 1) // has_transform
  wv_write_bits(bits, 1, 2) // type=1
  wv_write_bits(bits, 0, 3) // bits
  wv_write_bits(bits, 0, 1) // unused
  // 变换2: color/palette (type 3)
  wv_write_bits(bits, 1, 1) // has_transform
  wv_write_bits(bits, 3, 2) // type=3
  wv_write_bits(bits, 0, 1) // use_subset
  wv_write_bits(bits, 0, 1) // 无更多变换
  wv_write_bits(bits, 0, 1) // 无 cache
  wv_write_bits(bits, 1, 1) // 使用 meta huffman
  // meta tree: 简单单符号 (symbol=0, max_bits=1)
  wv_simple_tree_1sym(bits, 1, 0)
  wv_write_bits(bits, 0, 2) // num_meta-1=0 → 1 个子树
  // 子树: 简单单符号 (symbol=0, max_bits=8)
  wv_simple_tree_1sym(bits, 8, 0)
  // 像素: (g,r,b)=(0,0,0)
  wv_write_bits(bits, 0, 3)
  let img = decode_webp_pure(wv_wrap(wv_pack(bits)))
  assert_eq(img.width, 1)
  assert_eq(img.channels, 3)
  assert_eq(img.data[0].to_int(), 0)
  assert_eq(img.data[1].to_int(), 0)
  assert_eq(img.data[2].to_int(), 0)
}

///|
test "decode_webp: 空 code-length 树解码" {
  // 复杂 Huffman 但所有 code length code lengths 为 0 → cl_tree 为空
  // → HuffmanTree::decode 的空树分支 (直接返回 0)
  let bits : Array[Int] = []
  wv_header(bits, 1, 1, 0)
  wv_write_bits(bits, 0, 1) // 无变换
  wv_write_bits(bits, 0, 1) // 无 cache
  wv_write_bits(bits, 0, 1) // 无 meta
  wv_write_bits(bits, 0, 1) // is_simple=0 (复杂 Huffman)
  wv_write_bits(bits, 0, 4) // num_code_lengths-4=0 → 4
  wv_write_bits(bits, 0, 12) // 4 × 3 bits 全 0 → cl_tree 为空
  // code_lens 循环: 256 次 sym=0 (空树 decode 不消耗位) + 像素 3 次解码
  wv_write_bits(bits, 0, 259)
  let img = decode_webp_pure(wv_wrap(wv_pack(bits)))
  assert_eq(img.width, 1)
  assert_eq(img.channels, 3)
  assert_eq(img.data[0].to_int(), 0)
  assert_eq(img.data[1].to_int(), 0)
  assert_eq(img.data[2].to_int(), 0)
}

///|
test "decode_webp: code-length sym17 与无效符号分支" {
  // cl_tree 仅含 sym17 (1-bit code "1"):
  //   bit=0 → 返回 -1 (内部节点值) → else 分支重新 decode
  //   bit=1 → sym17 → 重复 0 × (3+extra)
  let bits : Array[Int] = []
  wv_header(bits, 1, 1, 0)
  wv_write_bits(bits, 0, 1) // 无变换
  wv_write_bits(bits, 0, 1) // 无 cache
  wv_write_bits(bits, 0, 1) // 无 meta
  wv_write_bits(bits, 0, 1) // is_simple=0
  wv_write_bits(bits, 0, 4) // 4 个 code length
  // order=[17,18,0,1]: [17]=1 (len 1), 其余 0
  wv_write_bits(bits, 1, 3) // 17 → 1
  wv_write_bits(bits, 0, 3) // 18 → 0
  wv_write_bits(bits, 0, 3) // 0 → 0
  wv_write_bits(bits, 0, 3) // 1 → 0
  // 初始 decode: bit=0 → 返回 -1 (覆盖 else 分支)
  wv_write_bits(bits, 0, 1)
  // 26 次 sym17: bit=1 + extra=7 (3 bits) → 每次 push 10 个 0 → 260 ≥ 256
  for _ in 0..<26 {
    wv_write_bits(bits, 1, 1)
    wv_write_bits(bits, 7, 3)
  }
  // 最后一轮迭代结束后的 end-decode (结果被丢弃)
  wv_write_bits(bits, 1, 1)
  // 像素: 3 次 decode bit=0 → symbol 0 (code_lens 全 0 → add_code(0,1,0))
  wv_write_bits(bits, 0, 3)
  let img = decode_webp_pure(wv_wrap(wv_pack(bits)))
  assert_eq(img.width, 1)
  assert_eq(img.channels, 3)
  assert_eq(img.data[0].to_int(), 0)
}

///|
test "decode_webp: code-length sym16 与 canonical 编码" {
  // cl_tree: sym5 (code "1"), sym16 (code "00"), sym18 (code "010")
  // sym16 空 prev → 0；非空 prev → 复制前值
  // code_lens = [0,0,0,5,5,5,5,5,5,0,...] (6 个 5-bit 码，合法 Huffman 集)
  // → canonical: sym3..8 → codes 0..5
  let bits : Array[Int] = []
  wv_header(bits, 1, 1, 0)
  wv_write_bits(bits, 0, 1) // 无变换
  wv_write_bits(bits, 0, 1) // 无 cache
  wv_write_bits(bits, 0, 1) // 无 meta
  wv_write_bits(bits, 0, 1) // is_simple=0
  wv_write_bits(bits, 5, 4) // num_code_lengths-4=5 → 9
  // order=[17,18,0,1,2,3,4,5,16]: [18]=3, [5]=1, [16]=2, 其余 0
  wv_write_bits(bits, 0, 3) // 17 → 0
  wv_write_bits(bits, 3, 3) // 18 → len 3 (code "010")
  wv_write_bits(bits, 0, 3) // 0 → 0
  wv_write_bits(bits, 0, 3) // 1 → 0
  wv_write_bits(bits, 0, 3) // 2 → 0
  wv_write_bits(bits, 0, 3) // 3 → 0
  wv_write_bits(bits, 0, 3) // 4 → 0
  wv_write_bits(bits, 1, 3) // 5 → len 1 (code "1")
  wv_write_bits(bits, 2, 3) // 16 → len 2 (code "00")
  // 初始 decode "00" → sym16; extra=0 → repeat 3, code_lens 空 → prev=0
  wv_write_bits(bits, 0, 2)
  wv_write_bits(bits, 0, 2)
  // iter1 end "1" → sym5 → push 5
  wv_write_bits(bits, 1, 1)
  // iter2 end "1" → sym5 → push 5
  wv_write_bits(bits, 1, 1)
  // iter3 end "00" → sym16, extra=1 → repeat 4, prev=5 → push 4 个 5
  wv_write_bits(bits, 0, 2)
  wv_write_bits(bits, 1, 2)
  // iter4 end "010" → sym18
  wv_write_bits(bits, 0, 1)
  wv_write_bits(bits, 1, 1)
  wv_write_bits(bits, 0, 1)
  // 13 次 sym18: extra=7 → repeat 18 → 每次 push 18 个 0 (共 234)
  for _ in 0..<13 {
    wv_write_bits(bits, 7, 7)
    wv_write_bits(bits, 0, 1)
    wv_write_bits(bits, 1, 1)
    wv_write_bits(bits, 0, 1)
  }
  // 最后一次 sym18: extra=2 → repeat 13 → push 13 个 0 → 总长 256
  // 其后的 end-decode "010" 结果被丢弃 (循环因长度达标而退出)
  wv_write_bits(bits, 2, 7)
  wv_write_bits(bits, 0, 1)
  wv_write_bits(bits, 1, 1)
  wv_write_bits(bits, 0, 1)
  // canonical: sym3..8 → 5-bit codes 0..5
  // 像素: g=sym4 (code 1), r=sym5 (code 2), b=sym3 (code 0)
  // Huffman 码在流中按 MSB-first 逐位出现
  wv_write_code_msb(bits, 1, 5)
  wv_write_code_msb(bits, 2, 5)
  wv_write_code_msb(bits, 0, 5)
  let img = decode_webp_pure(wv_wrap(wv_pack(bits)))
  assert_eq(img.width, 1)
  assert_eq(img.channels, 3)
  assert_eq(img.data[0].to_int(), 5) // r
  assert_eq(img.data[1].to_int(), 4) // g
  assert_eq(img.data[2].to_int(), 3) // b
}

///|
test "decode_webp: RIFF 奇数 chunk padding 跳过" {
  // VP8L chunk 前放置一个奇数长度的 ICCP chunk → 解码器需跳过 padding 字节
  let bits : Array[Int] = []
  wv_header(bits, 1, 1, 0)
  wv_write_bits(bits, 0, 1) // 无变换
  wv_write_bits(bits, 0, 1) // 无 cache
  wv_write_bits(bits, 0, 1) // 无 meta
  wv_simple_tree_1sym(bits, 1, 0)
  wv_write_bits(bits, 0, 3) // 像素 (0,0,0)
  let vp8l = wv_pack(bits)
  let vp8l_len = vp8l.length()
  let riff_size = 4 + (8 + 3 + 1) + (8 + vp8l_len)
  let result : Array[Byte] = []
  result.push(b'R')
  result.push(b'I')
  result.push(b'F')
  result.push(b'F')
  result.push((riff_size & 0xFF).to_byte())
  result.push(((riff_size >> 8) & 0xFF).to_byte())
  result.push(((riff_size >> 16) & 0xFF).to_byte())
  result.push(((riff_size >> 24) & 0xFF).to_byte())
  result.push(b'W')
  result.push(b'E')
  result.push(b'B')
  result.push(b'P')
  // ICCP chunk (size=3, 奇数 → 1 字节 padding)
  result.push(b'I')
  result.push(b'C')
  result.push(b'C')
  result.push(b'P')
  result.push(3)
  result.push(0)
  result.push(0)
  result.push(0)
  result.push(b'\x01')
  result.push(b'\x02')
  result.push(b'\x03')
  result.push(b'\x00') // padding
  // VP8L chunk
  result.push(b'V')
  result.push(b'P')
  result.push(b'8')
  result.push(b'L')
  result.push((vp8l_len & 0xFF).to_byte())
  result.push(((vp8l_len >> 8) & 0xFF).to_byte())
  result.push(((vp8l_len >> 16) & 0xFF).to_byte())
  result.push(((vp8l_len >> 24) & 0xFF).to_byte())
  for i in 0..<vp8l_len {
    result.push(vp8l[i])
  }
  let img = decode_webp_pure(Bytes::from_array(result))
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 3)
}

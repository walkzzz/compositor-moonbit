// 纯 MoonBit JPEG 解码（全目标可用：native/wasm/js）
// 支持 baseline JPEG (SOF0), 8-bit, YCbCr 3 通道或灰度
// 实现: Huffman 解码 + 反量化 + IDCT + YCbCr→RGB + 色度上采样
// 支持 chroma subsampling: 4:4:4, 4:2:2, 4:2:0
// 不支持 progressive (SOF2)、CMYK、arithmetic coding

///|
/// JPEG 位读取器
priv struct JpegBitReader {
  data : Bytes
  len : Int
  mut pos : Int
  mut bit_buf : Int
  mut bit_cnt : Int
}

///|
/// JPEG Huffman 表（规范解码）
priv struct JpegHuffmanTable {
  maxcode : Array[Int]
  mincode : Array[Int]
  valptr : Array[Int]
  huffval : Array[Int]
}

///|
/// 空 Huffman 表
fn empty_huffman_table() -> JpegHuffmanTable {
  JpegHuffmanTable::{
    maxcode: Array::make(17, -1),
    mincode: Array::make(17, 0),
    valptr: Array::make(17, 0),
    huffval: [],
  }
}

///|
/// 构建 Huffman 表
fn build_jpeg_huffman(
  counts : Array[Int],
  values : Array[Int],
) -> JpegHuffmanTable {
  let maxcode = Array::make(17, -1)
  let mincode = Array::make(17, 0)
  let valptr = Array::make(17, 0)
  let mut code = 0
  let mut k = 0
  for l in 1..<=16 {
    valptr[l] = k
    mincode[l] = code
    code += counts[l - 1]
    if counts[l - 1] > 0 {
      maxcode[l] = code - 1
    }
    k += counts[l - 1]
    code = code << 1
  }
  JpegHuffmanTable::{ maxcode, mincode, valptr, huffval: values }
}

///|
/// 读取一位
fn jpeg_read_bit(r : JpegBitReader) -> Int raise @types.LoadError {
  if r.bit_cnt == 0 {
    if r.pos >= r.len {
      raise @types.LoadError::DecodeFailed("JPEG 数据意外结束")
    }
    let b = r.data[r.pos].to_int()
    r.pos += 1
    if b == 0xFF {
      if r.pos >= r.len {
        raise @types.LoadError::DecodeFailed("JPEG 数据意外结束于 0xFF")
      }
      let next = r.data[r.pos].to_int()
      r.pos += 1
      if next == 0x00 {
        r.bit_buf = 0xFF
      } else if next >= 0xD0 && next <= 0xD7 {
        r.bit_buf = 0
      } else {
        raise @types.LoadError::DecodeFailed("JPEG 无效标记 0xFF")
      }
    } else {
      r.bit_buf = b
    }
    r.bit_cnt = 8
  }
  let bit = (r.bit_buf >> 7) & 1
  r.bit_buf = (r.bit_buf & 0x7F) << 1
  r.bit_cnt -= 1
  bit
}

///|
/// 读取 n 位
fn jpeg_read_bits(r : JpegBitReader, n : Int) -> Int raise @types.LoadError {
  let mut result = 0
  for _ in 0..<n {
    result = (result << 1) | jpeg_read_bit(r)
  }
  result
}

///|
/// Huffman 解码
fn jpeg_decode_huffman(
  r : JpegBitReader,
  table : JpegHuffmanTable,
) -> Int raise @types.LoadError {
  let mut code = 0
  for l in 1..<=16 {
    code = (code << 1) | jpeg_read_bit(r)
    if table.maxcode[l] != -1 && code <= table.maxcode[l] {
      let idx = table.valptr[l] + code - table.mincode[l]
      if idx >= 0 && idx < table.huffval.length() {
        return table.huffval[idx]
      }
      raise @types.LoadError::DecodeFailed("JPEG Huffman 索引越界")
    }
  }
  raise @types.LoadError::DecodeFailed("JPEG Huffman 解码失败")
}

///|
/// JPEG 值扩展（符号扩展）
fn jpeg_extend(val : Int, size : Int) -> Int {
  let vt = 1 << (size - 1)
  if val < vt {
    val - (1 << size) + 1
  } else {
    val
  }
}

///|
/// IDCT 余弦表
fn idct_cos_table() -> Array[Float] {
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
/// 8x8 IDCT（含 +128 电平偏移，输出 0-255）
fn idct_8x8(block : Array[Int]) -> Array[Int] {
  let cos_table = idct_cos_table()
  let out = Array::make(64, 0)
  for y in 0..<8 {
    for x in 0..<8 {
      let mut sum = 0.0F
      for u in 0..<8 {
        for v in 0..<8 {
          let cu = if u == 0 { 0.70710678F } else { 1.0F }
          let cv = if v == 0 { 0.70710678F } else { 1.0F }
          sum += cu *
            cv *
            Float::from_int(block[v * 8 + u]) *
            cos_table[u * 8 + x] *
            cos_table[v * 8 + y]
        }
      }
      let val = (sum * 0.25F + 128.0F + 0.5F).to_int()
      out[y * 8 + x] = val.clamp(min=0, max=255)
    }
  }
  out
}

///|
/// Zigzag 顺序
fn zigzag() -> Array[Int] {
  [
    0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5, 12, 19, 26, 33, 40, 48,
    41, 34, 27, 20, 13, 6, 7, 14, 21, 28, 35, 42, 49, 56, 57, 50, 43, 36, 29, 22,
    15, 23, 30, 37, 44, 51, 58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55,
    62, 63,
  ]
}

///|
/// 解码一个 8x8 块
fn jpeg_decode_block(
  r : JpegBitReader,
  dc_table : JpegHuffmanTable,
  ac_table : JpegHuffmanTable,
  quant : Array[Int],
  prev_dc : Ref[Int],
  zz : Array[Int],
) -> Array[Int] raise @types.LoadError {
  let block = Array::make(64, 0)
  let s = jpeg_decode_huffman(r, dc_table)
  let diff = if s == 0 {
    0
  } else {
    let bits = jpeg_read_bits(r, s)
    jpeg_extend(bits, s)
  }
  block[0] = prev_dc.val + diff
  prev_dc.val = block[0]
  let mut k = 1
  while k < 64 {
    let rs = jpeg_decode_huffman(r, ac_table)
    let run = (rs >> 4) & 0x0F
    let size = rs & 0x0F
    if size == 0 {
      if run == 15 {
        k += 16
        continue
      } else {
        break
      }
    }
    k += run
    if k >= 64 {
      break
    }
    let bits = jpeg_read_bits(r, size)
    block[zz[k]] = jpeg_extend(bits, size)
    k += 1
  }
  for i in 0..<64 {
    block[i] = block[i] * quant[i]
  }
  block
}

///|
/// YCbCr → RGB
fn ycbcr_to_rgb(y : Int, cb : Int, cr : Int) -> (Int, Int, Int) {
  let cbf = Float::from_int(cb) - 128.0F
  let crf = Float::from_int(cr) - 128.0F
  let yf = Float::from_int(y)
  let r = (yf + 1.402F * crf + 0.5F).to_int()
  let g = (yf - 0.34414F * cbf - 0.71414F * crf + 0.5F).to_int()
  let b = (yf + 1.772F * cbf + 0.5F).to_int()
  (r.clamp(min=0, max=255), g.clamp(min=0, max=255), b.clamp(min=0, max=255))
}

///|
/// JPEG 解码头部信息
priv struct JpegHeader {
  width : Int
  height : Int
  num_components : Int
  quant_tables : Array[Array[Int]]
  huff_dc : Array[JpegHuffmanTable]
  huff_ac : Array[JpegHuffmanTable]
  component_h : Array[Int]
  component_v : Array[Int]
  component_qt : Array[Int]
  restart_interval : Int
  scan_comp_idx : Array[Int]
  scan_dc_table : Array[Int]
  scan_ac_table : Array[Int]
  scan_ns : Int
  entropy_start : Int
}

///|
/// 解析 JPEG 标记段（SOF0/DQT/DHT/DRI/SOS），返回头部信息
fn jpeg_parse_header(data : Bytes) -> JpegHeader raise @types.LoadError {
  let len = data.length()
  if len < 2 || data[0].to_int() != 0xFF || data[1].to_int() != 0xD8 {
    raise @types.LoadError::DecodeFailed("JPEG SOI marker 错误")
  }
  let mut pos = 2
  let mut width = 0
  let mut height = 0
  let quant_tables : Array[Array[Int]] = Array::make(4, Array::make(64, 0))
  let huff_dc : Array[JpegHuffmanTable] = Array::make(4, empty_huffman_table())
  let huff_ac : Array[JpegHuffmanTable] = Array::make(4, empty_huffman_table())
  let mut num_components = 3
  let component_ids : Array[Int] = Array::make(4, 0)
  let component_h : Array[Int] = Array::make(4, 1)
  let component_v : Array[Int] = Array::make(4, 1)
  let component_qt : Array[Int] = Array::make(4, 0)
  let mut restart_interval = 0
  let scan_comp_idx : Array[Int] = Array::make(4, 0)
  let scan_dc_table : Array[Int] = Array::make(4, 0)
  let scan_ac_table : Array[Int] = Array::make(4, 0)
  let mut scan_ns = 0
  let mut entropy_start = 0
  let zz = zigzag()
  while pos < len {
    if data[pos].to_int() != 0xFF {
      pos += 1
      continue
    }
    let marker = data[pos + 1].to_int()
    pos += 2
    match marker {
      0xC0 => {
        // SOF0: length(2) + precision(1) + height(2) + width(2) + num_components(1)
        if pos + 9 > len {
          raise @types.LoadError::DecodeFailed("JPEG SOF0 过短")
        }
        let _precision = data[pos + 2].to_int()
        height = data[pos + 3].to_int() * 256 + data[pos + 4].to_int()
        width = data[pos + 5].to_int() * 256 + data[pos + 6].to_int()
        num_components = data[pos + 7].to_int()
        pos += 8
        for i in 0..<num_components {
          if pos + 3 > len {
            raise @types.LoadError::DecodeFailed("JPEG SOF0 component 过短")
          }
          component_ids[i] = data[pos].to_int()
          let hv = data[pos + 1].to_int()
          component_h[i] = (hv >> 4) & 0x0F
          component_v[i] = hv & 0x0F
          component_qt[i] = data[pos + 2].to_int()
          pos += 3
        }
      }
      0xDB => {
        // DQT
        let seg_len = data[pos].to_int() * 256 + data[pos + 1].to_int()
        let seg_end = pos + seg_len
        pos += 2
        while pos < seg_end {
          let pq = data[pos].to_int()
          let precision = pq >> 4
          let tq = pq & 0x0F
          pos += 1
          let step = if precision == 0 { 1 } else { 2 }
          if tq < 4 {
            for i in 0..<64 {
              let v = if precision == 0 {
                data[pos].to_int()
              } else {
                data[pos].to_int() * 256 + data[pos + 1].to_int()
              }
              quant_tables[tq][zz[i]] = v
              pos += step
            }
          } else {
            pos += 64 * step
          }
        }
      }
      0xC4 => {
        // DHT
        let seg_len = data[pos].to_int() * 256 + data[pos + 1].to_int()
        let seg_end = pos + seg_len
        pos += 2
        while pos < seg_end {
          let tc_th = data[pos].to_int()
          let tc = (tc_th >> 4) & 0x0F
          let th = tc_th & 0x0F
          pos += 1
          let counts = Array::make(16, 0)
          for i in 0..<16 {
            counts[i] = data[pos + i].to_int()
          }
          pos += 16
          let total = {
            let mut s = 0
            for c in counts {
              s += c
            }
            s
          }
          let values = Array::make(total, 0)
          for i in 0..<total {
            values[i] = data[pos + i].to_int()
          }
          pos += total
          if th < 4 {
            let table = build_jpeg_huffman(counts, values)
            if tc == 0 {
              huff_dc[th] = table
            } else {
              huff_ac[th] = table
            }
          }
        }
      }
      0xDD => {
        // DRI
        let seg_len = data[pos].to_int() * 256 + data[pos + 1].to_int()
        restart_interval = data[pos + 2].to_int() * 256 + data[pos + 3].to_int()
        pos += seg_len
      }
      0xDA => {
        // SOS
        let seg_len = data[pos].to_int() * 256 + data[pos + 1].to_int()
        scan_ns = data[pos + 2].to_int()
        let mut p = pos + 3
        for i in 0..<scan_ns {
          let cs = data[p].to_int()
          let td_ta = data[p + 1].to_int()
          let mut cidx = 0
          for j in 0..<num_components {
            if component_ids[j] == cs {
              cidx = j
              break
            }
          }
          scan_comp_idx[i] = cidx
          scan_dc_table[i] = (td_ta >> 4) & 0x0F
          scan_ac_table[i] = td_ta & 0x0F
          p += 2
        }
        pos += seg_len
        entropy_start = pos
        break
      }
      0xD9 => break
      _ =>
        if pos + 2 <= len {
          let seg_len = data[pos].to_int() * 256 + data[pos + 1].to_int()
          pos += seg_len
        }
    }
  }
  JpegHeader::{
    width,
    height,
    num_components,
    quant_tables,
    huff_dc,
    huff_ac,
    component_h,
    component_v,
    component_qt,
    restart_interval,
    scan_comp_idx,
    scan_dc_table,
    scan_ac_table,
    scan_ns,
    entropy_start,
  }
}

///|
/// 写入单个 MCU 的像素到输出缓冲
fn jpeg_write_mcu_pixels(
  header : JpegHeader,
  comp_data : Array[Array[Int]],
  mx : Int,
  my : Int,
  max_h : Int,
  max_v : Int,
  mcu_width : Int,
  mcu_height : Int,
  out_channels : Int,
  rgb_data : Array[Byte],
) -> Unit {
  let width = header.width
  let height = header.height
  let num_components = header.num_components
  let scan_comp_idx = header.scan_comp_idx
  let component_h = header.component_h
  let component_v = header.component_v
  for py in 0..<mcu_height {
    for px in 0..<mcu_width {
      let ox = mx * mcu_width + px
      let oy = my * mcu_height + py
      if ox >= width || oy >= height {
        continue
      }
      if num_components == 1 {
        let ci = scan_comp_idx[0]
        let hi = component_h[ci]
        let vi = component_v[ci]
        let cx = px * hi / max_h
        let cy = py * vi / max_v
        let bx = cx / 8
        let by = cy / 8
        let ix = by * hi * 64 + bx * 64 + cy % 8 * 8 + cx % 8
        let y_val = comp_data[ci][ix]
        let oidx = oy * width * out_channels + ox * out_channels
        let yb = y_val.to_byte()
        rgb_data[oidx] = yb
        rgb_data[oidx + 1] = yb
        rgb_data[oidx + 2] = yb
      } else {
        let y_ci = scan_comp_idx[0]
        let cb_ci = scan_comp_idx[1]
        let cr_ci = scan_comp_idx[2]
        let y_hi = component_h[y_ci]
        let y_vi = component_v[y_ci]
        let ycx = px * y_hi / max_h
        let ycy = py * y_vi / max_v
        let ybx = ycx / 8
        let yby = ycy / 8
        let y_idx = yby * y_hi * 64 + ybx * 64 + ycy % 8 * 8 + ycx % 8
        let y_val = comp_data[y_ci][y_idx]
        let cb_hi = component_h[cb_ci]
        let cb_vi = component_v[cb_ci]
        let cbcx = px * cb_hi / max_h
        let cbcy = py * cb_vi / max_v
        let cbbx = cbcx / 8
        let cbby = cbcy / 8
        let cb_idx = cbby * cb_hi * 64 + cbbx * 64 + cbcy % 8 * 8 + cbcx % 8
        let cb_val = comp_data[cb_ci][cb_idx]
        let cr_hi = component_h[cr_ci]
        let cr_vi = component_v[cr_ci]
        let crcx = px * cr_hi / max_h
        let crcy = py * cr_vi / max_v
        let crbx = crcx / 8
        let crby = crcy / 8
        let cr_idx = crby * cr_hi * 64 + crbx * 64 + crcy % 8 * 8 + crcx % 8
        let cr_val = comp_data[cr_ci][cr_idx]
        let (r, g, b) = ycbcr_to_rgb(y_val, cb_val, cr_val)
        let oidx = oy * width * out_channels + ox * out_channels
        rgb_data[oidx] = r.to_byte()
        rgb_data[oidx + 1] = g.to_byte()
        rgb_data[oidx + 2] = b.to_byte()
      }
    }
  }
}

///|
/// 解码 JPEG 扫描数据（MCU 循环），返回 RGB 像素
fn jpeg_decode_scan(
  header : JpegHeader,
  data : Bytes,
) -> @types.Image raise @types.LoadError {
  let width = header.width
  let height = header.height
  let num_components = header.num_components
  let zz = zigzag()
  let reader = JpegBitReader::{
    data,
    len: data.length(),
    pos: header.entropy_start,
    bit_buf: 0,
    bit_cnt: 0,
  }
  let mut max_h = 1
  let mut max_v = 1
  for i in 0..<num_components {
    if header.component_h[i] > max_h {
      max_h = header.component_h[i]
    }
    if header.component_v[i] > max_v {
      max_v = header.component_v[i]
    }
  }
  let mcu_width = max_h * 8
  let mcu_height = max_v * 8
  let mcus_x = (width + mcu_width - 1) / mcu_width
  let mcus_y = (height + mcu_height - 1) / mcu_height
  let dc_pred : Array[Ref[Int]] = []
  for _ in 0..<num_components {
    dc_pred.push(Ref(0))
  }
  let out_channels = 3
  let rgb_data : Array[Byte] = Array::make(
    width * height * out_channels,
    b'\x00',
  )
  let mut mcu_count = 0
  for _my in 0..<mcus_y {
    for _mx in 0..<mcus_x {
      let my = _my
      let mx = _mx
      if header.restart_interval > 0 &&
        mcu_count > 0 &&
        mcu_count % header.restart_interval == 0 {
        for i in 0..<num_components {
          dc_pred[i].val = 0
        }
        reader.bit_cnt = 0
        while reader.pos < reader.len - 1 {
          if reader.data[reader.pos].to_int() == 0xFF &&
            reader.data[reader.pos + 1].to_int() >= 0xD0 &&
            reader.data[reader.pos + 1].to_int() <= 0xD7 {
            reader.pos += 2
            break
          }
          reader.pos += 1
        }
      }
      let comp_data : Array[Array[Int]] = []
      for _ in 0..<num_components {
        comp_data.push(Array::make(256, 0))
      }
      for si in 0..<header.scan_ns {
        let ci = header.scan_comp_idx[si]
        let hi = header.component_h[ci]
        let vi = header.component_v[ci]
        let nblocks = hi * vi
        let dc_tab = header.huff_dc[header.scan_dc_table[si]]
        let ac_tab = header.huff_ac[header.scan_ac_table[si]]
        let qt = header.quant_tables[header.component_qt[ci]]
        for bi in 0..<nblocks {
          let block = jpeg_decode_block(
            reader,
            dc_tab,
            ac_tab,
            qt,
            dc_pred[ci],
            zz,
          )
          let spatial = idct_8x8(block)
          let bx = bi % hi
          let by = bi / hi
          for py in 0..<8 {
            for px in 0..<8 {
              let idx = by * hi * 64 + bx * 64 + py * 8 + px
              comp_data[ci][idx] = spatial[py * 8 + px]
            }
          }
        }
      }
      jpeg_write_mcu_pixels(
        header, comp_data, mx, my, max_h, max_v, mcu_width, mcu_height, out_channels,
        rgb_data,
      )
      mcu_count += 1
    }
  }
  @types.Image::{
    width,
    height,
    channels: out_channels,
    data: Bytes::from_array(rgb_data),
  }
}

///|
/// JPEG 解码（纯 MoonBit，全目标可用）。
/// 支持 baseline JPEG (SOF0), 8-bit, YCbCr 3 通道。
/// 不支持 progressive (SOF2)、CMYK、arithmetic coding。
pub fn decode_jpeg_pure(data : Bytes) -> @types.Image raise @types.LoadError {
  let header = jpeg_parse_header(data)
  if header.width <= 0 || header.height <= 0 {
    raise @types.LoadError::DecodeFailed("JPEG 尺寸无效")
  }
  @types.check_dims(header.width, header.height, header.num_components)
  jpeg_decode_scan(header, data)
}

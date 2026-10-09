// 纯 MoonBit APNG 编解码（全目标可用：native/wasm/js）
// APNG 规范: https://wiki.mozilla.org/APNG_Specification
// APNG 是 PNG 的扩展，新增 acTL/fcTL/fdAT chunk
// 仅支持全尺寸帧（x_offset=0, y_offset=0, frame_w=width, frame_h=height）

///|
/// 从 4 字节构造 chunk type 字符串
fn apng_chunk_type(data : Bytes, offset : Int) -> String {
  let buf : Array[Byte] = [
    data[offset],
    data[offset + 1],
    data[offset + 2],
    data[offset + 3],
  ]
  @encoding/utf8.decode(Bytes::from_array(buf)) catch {
    _ => "????"
  }
}

///|
/// PNG chunk 信息
priv struct PngChunk {
  chunk_type : String
  data_offset : Int
  data_size : Int
}

///|
/// 解析所有 PNG chunk
fn apng_parse_chunks(data : Bytes) -> Array[PngChunk] raise @types.LoadError {
  let len = data.length()
  if len < 8 {
    raise @types.LoadError::DecodeFailed("PNG/APNG 数据过短")
  }
  // 验证 PNG signature
  if !is_png_signature(data, 0) {
    raise @types.LoadError::DecodeFailed("PNG signature 错误")
  }
  let chunks : Array[PngChunk] = []
  let mut pos = 8
  while pos + 8 <= len {
    let chunk_len = read_u32_be(data, pos)
    let chunk_type = apng_chunk_type(data, pos + 4)
    pos += 8
    if pos + chunk_len + 4 > len {
      raise @types.LoadError::DecodeFailed("PNG chunk 数据越界")
    }
    chunks.push(PngChunk::{ chunk_type, data_offset: pos, data_size: chunk_len })
    pos += chunk_len + 4 // 跳过数据 + CRC
  }
  chunks
}

///|
/// 从 chunk 数据中提取子字节流
fn apng_extract_chunk_data(data : Bytes, chunk : PngChunk) -> Bytes {
  let out : Array[Byte] = []
  for i in 0..<chunk.data_size {
    out.push(data[chunk.data_offset + i])
  }
  Bytes::from_array(out)
}

///|
/// 构建独立 PNG 文件（signature + IHDR + IDAT + IEND）
fn build_standalone_png(ihdr_data : Bytes, idat_data : Bytes) -> Bytes {
  let out : Array[Byte] = []
  // PNG signature
  out.push(b'\x89')
  out.push(b'\x50')
  out.push(b'\x4E')
  out.push(b'\x47')
  out.push(b'\x0D')
  out.push(b'\x0A')
  out.push(b'\x1A')
  out.push(b'\x0A')
  // IHDR
  write_u32_be(out, ihdr_data.length())
  out.push(b'\x49')
  out.push(b'\x48')
  out.push(b'\x44')
  out.push(b'\x52')
  for i in 0..<ihdr_data.length() {
    out.push(ihdr_data[i])
  }
  // IHDR CRC (simplified: compute over type+data)
  let crc_data : Array[Byte] = [b'\x49', b'\x48', b'\x44', b'\x52']
  for i in 0..<ihdr_data.length() {
    crc_data.push(ihdr_data[i])
  }
  let ihdr_crc = @util.crc32(Bytes::from_array(crc_data))
  write_u32_be(out, ihdr_crc)
  // IDAT
  write_u32_be(out, idat_data.length())
  out.push(b'\x49')
  out.push(b'\x44')
  out.push(b'\x41')
  out.push(b'\x54')
  for i in 0..<idat_data.length() {
    out.push(idat_data[i])
  }
  let idat_crc_data : Array[Byte] = [b'\x49', b'\x44', b'\x41', b'\x54']
  for i in 0..<idat_data.length() {
    idat_crc_data.push(idat_data[i])
  }
  let idat_crc = @util.crc32(Bytes::from_array(idat_crc_data))
  write_u32_be(out, idat_crc)
  // IEND
  write_u32_be(out, 0)
  out.push(b'\x49')
  out.push(b'\x45')
  out.push(b'\x4E')
  out.push(b'\x44')
  let iend_crc = @util.crc32(b"\x49\x45\x4E\x44")
  write_u32_be(out, iend_crc)
  Bytes::from_array(out)
}

///|
/// 解码 APNG 字节流为 PngAnimation
/// 如果不是 APNG（无 acTL chunk），则当作单帧 PNG 返回
pub fn decode_apng_pure(
  data : Bytes,
) -> @types.PngAnimation raise @types.LoadError {
  let chunks = apng_parse_chunks(data)
  // 查找 IHDR
  let mut ihdr_data : Bytes = b""
  let mut found_ihdr = false
  for i in 0..<chunks.length() {
    if chunks[i].chunk_type == "IHDR" {
      ihdr_data = apng_extract_chunk_data(data, chunks[i])
      found_ihdr = true
      break
    }
  }
  if !found_ihdr {
    raise @types.LoadError::DecodeFailed("PNG/APNG 缺少 IHDR")
  }
  // 查找 acTL
  let mut has_actl = false
  for i in 0..<chunks.length() {
    if chunks[i].chunk_type == "acTL" {
      has_actl = true
      break
    }
  }
  if !has_actl {
    // 普通 PNG，当作单帧动画
    let img = decode_png_pure(data)
    return @types.PngAnimation::{ frames: [img], delays: [0] }
  }
  // APNG: 收集所有帧
  let frames : Array[@types.Image] = []
  let delays : Array[Int] = []
  // 收集 IDAT 数据（第一帧可能用 IDAT）
  let mut idat_data : Bytes = b""
  let mut found_idat = false
  for i in 0..<chunks.length() {
    if chunks[i].chunk_type == "IDAT" {
      let chunk_data = apng_extract_chunk_data(data, chunks[i])
      if !found_idat {
        idat_data = chunk_data
        found_idat = true
      } else {
        // 合并多个 IDAT
        let merged : Array[Byte] = []
        for j in 0..<idat_data.length() {
          merged.push(idat_data[j])
        }
        for j in 0..<chunk_data.length() {
          merged.push(chunk_data[j])
        }
        idat_data = Bytes::from_array(merged)
      }
    }
  }
  // 遍历 chunk，处理 fcTL + IDAT/fdAT
  let mut i = 0
  let mut first_frame_done = false
  while i < chunks.length() {
    if chunks[i].chunk_type == "fcTL" {
      // 解析 fcTL
      let fctl_data = apng_extract_chunk_data(data, chunks[i])
      // delay_num (2 bytes at offset 20), delay_den (2 bytes at offset 22)
      let delay_num = read_u16_be(fctl_data, 20)
      let delay_den = read_u16_be(fctl_data, 22)
      let delay_ms = if delay_den == 0 {
        0
      } else {
        delay_num * 1000 / delay_den
      }
      // 查找对应的帧数据（IDAT 或 fdAT）
      let mut frame_idat : Bytes = b""
      let mut found_frame_data = false
      let mut j = i + 1
      while j < chunks.length() {
        if chunks[j].chunk_type == "IDAT" && !first_frame_done {
          frame_idat = idat_data
          found_frame_data = true
          first_frame_done = true
          break
        } else if chunks[j].chunk_type == "fdAT" {
          // fdAT: 前 4 字节是 seq_num，后面是 IDAT 数据
          let fdat_data = apng_extract_chunk_data(data, chunks[j])
          let fdat_idat : Array[Byte] = []
          for k in 4..<fdat_data.length() {
            fdat_idat.push(fdat_data[k])
          }
          frame_idat = Bytes::from_array(fdat_idat)
          found_frame_data = true
          break
        } else if chunks[j].chunk_type == "fcTL" {
          // 遇到下一个 fcTL，停止
          break
        }
        j += 1
      }
      if found_frame_data {
        let png = build_standalone_png(ihdr_data, frame_idat)
        let img = decode_png_pure(png)
        frames.push(img)
        delays.push(delay_ms)
      }
    }
    i += 1
  }
  if frames.length() == 0 {
    raise @types.LoadError::DecodeFailed("APNG 无有效帧")
  }
  @types.PngAnimation::{ frames, delays }
}

///|
/// 从 PNG 字节流中提取 IDAT 数据
fn extract_idat_from_png(png_data : Bytes) -> Bytes raise @types.LoadError {
  let chunks = apng_parse_chunks(png_data)
  let idat : Array[Byte] = []
  for i in 0..<chunks.length() {
    if chunks[i].chunk_type == "IDAT" {
      for j in 0..<chunks[i].data_size {
        idat.push(png_data[chunks[i].data_offset + j])
      }
    }
  }
  Bytes::from_array(idat)
}

///|
/// 从 PNG 字节流中提取 IHDR 数据
fn extract_ihdr_from_png(png_data : Bytes) -> Bytes raise @types.LoadError {
  let chunks = apng_parse_chunks(png_data)
  for i in 0..<chunks.length() {
    if chunks[i].chunk_type == "IHDR" {
      return apng_extract_chunk_data(png_data, chunks[i])
    }
  }
  raise @types.LoadError::DecodeFailed("PNG 缺少 IHDR")
}

///|
/// 写入 PNG chunk（type + data + CRC）
fn apng_write_chunk(
  out : Array[Byte],
  chunk_type : String,
  chunk_data : Bytes,
) -> Unit {
  write_u32_be(out, chunk_data.length())
  let type_bytes = @encoding/utf8.encode(chunk_type)
  for i in 0..<4 {
    out.push(type_bytes[i])
  }
  for i in 0..<chunk_data.length() {
    out.push(chunk_data[i])
  }
  // CRC
  let crc_data : Array[Byte] = []
  for i in 0..<4 {
    crc_data.push(type_bytes[i])
  }
  for i in 0..<chunk_data.length() {
    crc_data.push(chunk_data[i])
  }
  let crc = @util.crc32(Bytes::from_array(crc_data))
  write_u32_be(out, crc)
}

///|
/// 将 PngAnimation 编码为 APNG 字节流
/// 所有帧必须尺寸相同
pub fn encode_apng_pure(
  anim : @types.PngAnimation,
) -> Bytes raise @types.LoadError {
  let num_frames = anim.frames.length()
  if num_frames == 0 {
    raise @types.LoadError::EncodeFailed("APNG 至少需要一帧")
  }
  let first = anim.frames[0]
  let width = first.width
  let height = first.height
  let out : Array[Byte] = []
  // PNG signature
  out.push(b'\x89')
  out.push(b'\x50')
  out.push(b'\x4E')
  out.push(b'\x47')
  out.push(b'\x0D')
  out.push(b'\x0A')
  out.push(b'\x1A')
  out.push(b'\x0A')
  // 编码第一帧为 PNG，提取 IHDR 和 IDAT
  let first_png = encode_png_pure(first)
  let ihdr_data = extract_ihdr_from_png(first_png)
  // IHDR chunk
  apng_write_chunk(out, "IHDR", ihdr_data)
  // acTL chunk: num_frames + num_plays(0=无限)
  let actl : Array[Byte] = []
  write_u32_be(actl, num_frames)
  write_u32_be(actl, 0)
  apng_write_chunk(out, "acTL", Bytes::from_array(actl))
  // 序列号计数器
  let mut seq = 0
  // 第一帧 fcTL
  let fctl1 : Array[Byte] = []
  write_u32_be(fctl1, seq) // sequence_number
  seq += 1
  write_u32_be(fctl1, width) // width
  write_u32_be(fctl1, height) // height
  write_u32_be(fctl1, 0) // x_offset
  write_u32_be(fctl1, 0) // y_offset
  let delay1 = if anim.delays.length() > 0 { anim.delays[0] } else { 0 }
  write_u16_be(fctl1, delay1) // delay_num (ms)
  write_u16_be(fctl1, 1000) // delay_den
  fctl1.push(b'\x01') // dispose_op = APNG_DISPOSE_OP_BACKGROUND
  fctl1.push(b'\x00') // blend_op = APNG_BLEND_OP_SOURCE
  apng_write_chunk(out, "fcTL", Bytes::from_array(fctl1))
  // 第一帧 IDAT
  let first_idat = extract_idat_from_png(first_png)
  apng_write_chunk(out, "IDAT", first_idat)
  // 后续帧
  for i in 1..<num_frames {
    let frame = anim.frames[i]
    let frame_png = encode_png_pure(frame)
    let frame_idat = extract_idat_from_png(frame_png)
    // fcTL
    let fctl : Array[Byte] = []
    write_u32_be(fctl, seq) // sequence_number
    seq += 1
    write_u32_be(fctl, frame.width)
    write_u32_be(fctl, frame.height)
    write_u32_be(fctl, 0) // x_offset
    write_u32_be(fctl, 0) // y_offset
    let delay = if i < anim.delays.length() { anim.delays[i] } else { 0 }
    write_u16_be(fctl, delay) // delay_num (ms)
    write_u16_be(fctl, 1000) // delay_den
    fctl.push(b'\x01') // dispose_op
    fctl.push(b'\x00') // blend_op
    apng_write_chunk(out, "fcTL", Bytes::from_array(fctl))
    // fdAT: seq_num + IDAT data
    let fdat : Array[Byte] = []
    write_u32_be(fdat, seq) // sequence_number
    seq += 1
    for j in 0..<frame_idat.length() {
      fdat.push(frame_idat[j])
    }
    apng_write_chunk(out, "fdAT", Bytes::from_array(fdat))
  }
  // IEND
  apng_write_chunk(out, "IEND", Bytes::from_array([]))
  Bytes::from_array(out)
}

// 纯 MoonBit QOI 编码器
// 规范: https://qoiformat.org/qoi-specification.pdf
// 移植自 src/format/qoi.mbt 的 encode_qoi，仅替换类型引用：
//   @core.Image -> @types.Image, @core.LoadError -> @types.LoadError
// qoi_hash 复用 src/pure/qoi_decode.mbt 已有定义（同包私有函数跨文件可见）

///|
/// 将 Image 编码为 QOI 字节流
/// 输入 Image 的 channels 必须为 3 (RGB) 或 4 (RGBA)
/// 输出: 14 字节 header + 像素编码 + 8 字节 padding
pub fn encode_qoi_pure(img : @types.Image) -> Bytes raise @types.LoadError {
  if img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::EncodeFailed(
      "QOI 编码需要 channels 为 3 (RGB) 或 4 (RGBA)",
    )
  }
  let out : Array[Byte] = []
  out.push(b'\x71')
  out.push(b'\x6F')
  out.push(b'\x69')
  out.push(b'\x66')
  out.push(((img.width >> 24) & 0xFF).to_byte())
  out.push(((img.width >> 16) & 0xFF).to_byte())
  out.push(((img.width >> 8) & 0xFF).to_byte())
  out.push((img.width & 0xFF).to_byte())
  out.push(((img.height >> 24) & 0xFF).to_byte())
  out.push(((img.height >> 16) & 0xFF).to_byte())
  out.push(((img.height >> 8) & 0xFF).to_byte())
  out.push((img.height & 0xFF).to_byte())
  out.push(img.channels.to_byte())
  out.push(b'\x00')
  let index_r : Array[Int] = Array::make(64, 0)
  let index_g : Array[Int] = Array::make(64, 0)
  let index_b : Array[Int] = Array::make(64, 0)
  let index_a : Array[Int] = Array::make(64, 0)
  let prev_r = Ref(0)
  let prev_g = Ref(0)
  let prev_b = Ref(0)
  let prev_a = Ref(255)
  let has_alpha = img.channels == 4
  let pixel_count = img.width * img.height
  let run = Ref(0)
  for i in 0..<pixel_count {
    let r = img.data[i * img.channels].to_int()
    let g = img.data[i * img.channels + 1].to_int()
    let b = img.data[i * img.channels + 2].to_int()
    let a = if has_alpha {
      img.data[i * img.channels + 3].to_int()
    } else {
      255
    }
    if r == prev_r.val && g == prev_g.val && b == prev_b.val && a == prev_a.val {
      run.val += 1
      if run.val == 62 {
        out.push((0xC0 | (run.val - 1)).to_byte())
        run.val = 0
      }
    } else {
      if run.val > 0 {
        out.push((0xC0 | (run.val - 1)).to_byte())
        run.val = 0
      }
      let h = qoi_hash(r, g, b, a)
      if index_r[h] == r &&
        index_g[h] == g &&
        index_b[h] == b &&
        index_a[h] == a {
        out.push((h & 0x3F).to_byte())
      } else if a == prev_a.val {
        let dr = r - prev_r.val
        let dg = g - prev_g.val
        let db = b - prev_b.val
        let dr_dg = dr - dg
        let db_dg = db - dg
        if dr >= -2 && dr <= 1 && dg >= -2 && dg <= 1 && db >= -2 && db <= 1 {
          out.push(
            (0x40 | ((dr + 2) << 4) | ((dg + 2) << 2) | (db + 2)).to_byte(),
          )
        } else if dg >= -32 &&
          dg <= 31 &&
          dr_dg >= -8 &&
          dr_dg <= 7 &&
          db_dg >= -8 &&
          db_dg <= 7 {
          out.push((0x80 | ((dg + 32) & 0x3F)).to_byte())
          out.push((((dr_dg + 8) << 4) | (db_dg + 8)).to_byte())
        } else {
          out.push(b'\xFE')
          out.push(r.to_byte())
          out.push(g.to_byte())
          out.push(b.to_byte())
        }
      } else {
        out.push(b'\xFF')
        out.push(r.to_byte())
        out.push(g.to_byte())
        out.push(b.to_byte())
        out.push(a.to_byte())
      }
      index_r[h] = r
      index_g[h] = g
      index_b[h] = b
      index_a[h] = a
    }
    prev_r.val = r
    prev_g.val = g
    prev_b.val = b
    prev_a.val = a
  }
  if run.val > 0 {
    out.push((0xC0 | (run.val - 1)).to_byte())
  }
  for i in 0..<8 {
    if i == 7 {
      out.push(b'\x01')
    } else {
      out.push(b'\x00')
    }
  }
  Bytes::from_array(out)
}

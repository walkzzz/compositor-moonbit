// 纯 MoonBit GIF 解码器
// 支持 GIF89a/GIF87a 单帧解码（RGB，channels=3）
// 规范: GIF89a Specification + src/format/gif_encode.mbt
// 单帧解码委托 decode_gif_animation_pure 取第一帧

///|
/// LZW 解码（LSB 优先变长码）
/// 返回颜色索引序列
fn lzw_decode(
  data : Array[Byte],
  min_code_size : Int,
) -> Array[Int] raise @types.LoadError {
  let clear_code = 1 << min_code_size
  let end_code = clear_code + 1
  let mut code_width = min_code_size + 1
  let mut dict : Array[Array[Int]] = []
  for i in 0..<clear_code {
    dict.push([i])
  }
  dict.push([])
  dict.push([])
  let output : Array[Int] = []
  let mut bit_buffer = 0
  let mut bit_count = 0
  let mut data_pos = 0
  let mut prev : Int = -1
  let data_len = data.length()
  let mut done = false
  while !done {
    while bit_count < code_width {
      if data_pos >= data_len {
        done = true
        break
      }
      bit_buffer = bit_buffer | (data[data_pos].to_int() << bit_count)
      bit_count += 8
      data_pos += 1
    }
    if done {
      break
    }
    let code = bit_buffer & ((1 << code_width) - 1)
    bit_buffer = bit_buffer >> code_width
    bit_count -= code_width
    if code == clear_code {
      dict = []
      for i in 0..<clear_code {
        dict.push([i])
      }
      dict.push([])
      dict.push([])
      code_width = min_code_size + 1
      prev = -1
    } else if code == end_code {
      done = true
    } else {
      let entry : Array[Int] = if code < dict.length() {
        dict[code]
      } else if code == dict.length() && prev >= 0 {
        let prev_entry = dict[prev]
        let new_entry : Array[Int] = []
        for v in prev_entry {
          new_entry.push(v)
        }
        new_entry.push(prev_entry[0])
        new_entry
      } else {
        raise @types.LoadError::DecodeFailed(
          "GIF LZW 解码错误：code 超出字典范围",
        )
      }
      for v in entry {
        output.push(v)
      }
      if prev >= 0 {
        let prev_entry = dict[prev]
        let new_entry : Array[Int] = []
        for v in prev_entry {
          new_entry.push(v)
        }
        new_entry.push(entry[0])
        dict.push(new_entry)
        if dict.length() == 1 << code_width && code_width < 12 {
          code_width += 1
        }
      }
      prev = code
    }
  }
  output
}

///|
/// 解码 GIF 字节流为 Image
/// 支持 GIF89a/GIF87a 单帧解码（RGB，channels=3）
/// 不支持 interlace（packed bit6=1 时 raise LoadError）
/// 委托 decode_gif_animation_pure 取第一帧
pub fn decode_gif_pure(data : Bytes) -> @types.Image raise @types.LoadError {
  let anim = decode_gif_animation_pure(data)
  if anim.frames.length() == 0 {
    raise @types.LoadError::DecodeFailed("GIF 无有效帧")
  }
  anim.frames[0]
}

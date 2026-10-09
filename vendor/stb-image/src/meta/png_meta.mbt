// PNG 元数据读取（纯 MoonBit）：text chunks (tEXt/iTXt)

///|

///|
/// PNG text chunk（关键字-文本对）
pub(all) struct PngTextChunk {
  keyword : String
  text : String
} derive(Eq, @debug.Debug)

///|
fn read_png_bytes_as_string(data : Bytes, start : Int, end : Int) -> String {
  let chars : Array[Byte] = []
  for i in start..<end {
    chars.push(data[i])
  }
  @encoding/utf8.decode(Bytes::from_array(chars)[:]) catch {
    _ => ""
  }
}

///|
/// 从 PNG 字节流读取 text chunks（tEXt 和 iTXt）。
/// 返回关键字-文本对数组。不含 EXIF 等其他元数据。
pub fn read_png_text_chunks(data : Bytes) -> Array[PngTextChunk] {
  let result : Array[PngTextChunk] = []
  let len = data.length()
  // PNG signature: 8 bytes
  if len < 8 ||
    data[0].to_int() != 0x89 ||
    data[1].to_int() != 0x50 ||
    data[2].to_int() != 0x4E ||
    data[3].to_int() != 0x47 {
    return result
  }
  let mut pos = 8
  while pos + 8 <= len {
    // chunk length (4 bytes BE) + type (4 bytes)
    let chunk_len = data[pos].to_int() * 16777216 +
      data[pos + 1].to_int() * 65536 +
      data[pos + 2].to_int() * 256 +
      data[pos + 3].to_int()
    let type0 = data[pos + 4].to_int()
    let type1 = data[pos + 5].to_int()
    let type2 = data[pos + 6].to_int()
    let type3 = data[pos + 7].to_int()
    let data_start = pos + 8
    if data_start + chunk_len > len {
      break
    }
    // tEXt: type = 0x74 0x45 0x58 0x74
    if type0 == 0x74 && type1 == 0x45 && type2 == 0x58 && type3 == 0x74 {
      // tEXt: keyword + 0x00 + text
      let mut sep = -1
      for i in 0..<chunk_len {
        if data[data_start + i] == b'\x00' {
          sep = i
          break
        }
      }
      if sep >= 0 {
        let keyword = read_png_bytes_as_string(
          data,
          data_start,
          data_start + sep,
        )
        let text = read_png_bytes_as_string(
          data,
          data_start + sep + 1,
          data_start + chunk_len,
        )
        result.push(PngTextChunk::{ keyword, text })
      }
    }
    // iTXt: type = 0x69 0x54 0x58 0x74
    if type0 == 0x69 && type1 == 0x54 && type2 == 0x58 && type3 == 0x74 {
      // iTXt: keyword + 0x00 + compression_flag + compression_method + language_tag + 0x00 + translated_keyword + 0x00 + text
      let mut sep = -1
      for i in 0..<chunk_len {
        if data[data_start + i] == b'\x00' {
          sep = i
          break
        }
      }
      if sep >= 0 && sep + 2 < chunk_len {
        let keyword = read_png_bytes_as_string(
          data,
          data_start,
          data_start + sep,
        )
        let comp_flag = data[data_start + sep + 1].to_int()
        // 跳过 compression_method (1 byte) + language_tag + 0x00 + translated_keyword + 0x00
        let mut text_start = sep + 3 // skip comp_flag + comp_method
        // 跳过 language tag (until 0x00)
        while text_start < chunk_len && data[data_start + text_start] != b'\x00' {
          text_start += 1
        }
        text_start += 1 // skip 0x00
        // 跳过 translated keyword (until 0x00)
        while text_start < chunk_len && data[data_start + text_start] != b'\x00' {
          text_start += 1
        }
        text_start += 1 // skip 0x00
        if text_start <= chunk_len {
          let text = if comp_flag == 0 {
            read_png_bytes_as_string(
              data,
              data_start + text_start,
              data_start + chunk_len,
            )
          } else {
            // 压缩文本不支持（需要 zlib 解压）
            "[compressed]"
          }
          result.push(PngTextChunk::{ keyword, text })
        }
      }
    }
    // IEND 标志着 PNG 结束
    if type0 == 0x49 && type1 == 0x45 && type2 == 0x4E && type3 == 0x44 {
      break
    }
    // 前进到下一个 chunk: length(4) + type(4) + data(chunk_len) + CRC(4)
    pos = data_start + chunk_len + 4
  }
  result
}

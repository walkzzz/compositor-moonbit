// 流式解码接口（纯 MoonBit）
// 提供逐行/分块回调式解码接口（当前为全量解码后逐行分发，未来支持增量解码）

///|
/// 流式解码信息
pub(all) struct StreamInfo {
  width : Int
  height : Int
  channels : Int
}

///|
/// 流式解码：逐行回调处理。
/// on_row 回调接收 (行号, 行数据) 参数。
/// 行数据为 w*channels 个字节，按 RGB/RGBA 顺序排列。
pub fn decode_stream(
  data : Bytes,
  on_row : (Int, Array[Byte]) -> Unit,
) -> StreamInfo raise @types.LoadError {
  let img = load_from_bytes_auto(data)
  let w = img.width
  let h = img.height
  let ch = img.channels
  let row_data : Array[Byte] = Array::make(w * ch, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<ch {
        row_data[x * ch + c] = img.data[(y * w + x) * ch + c]
      }
    }
    on_row(y, row_data)
  }
  StreamInfo::{ width: w, height: h, channels: ch }
}

///|
/// 分块流式解码：每 chunk_height 行回调一次。
/// on_chunk 回调接收 (起始行号, 块图像) 参数。
/// 适用于分块处理大图，减少回调开销。
pub fn decode_stream_chunked(
  data : Bytes,
  chunk_height : Int,
  on_chunk : (Int, @types.Image) -> Unit,
) -> StreamInfo raise @types.LoadError {
  let img = load_from_bytes_auto(data)
  let w = img.width
  let h = img.height
  let ch = img.channels
  let chunk_h = if chunk_height < 1 { 1 } else { chunk_height }
  let mut y = 0
  while y < h {
    let end_y = if y + chunk_h > h { h } else { y + chunk_h }
    let block_h = end_y - y
    let block_data : Array[Byte] = Array::make(w * block_h * ch, b'\x00')
    for by in 0..<block_h {
      for x in 0..<w {
        for c in 0..<ch {
          block_data[(by * w + x) * ch + c] = img.data[((y + by) * w + x) * ch +
            c]
        }
      }
    }
    let block_img = @types.Image::{
      width: w,
      height: block_h,
      channels: ch,
      data: Bytes::from_array(block_data),
    }
    on_chunk(y, block_img)
    y = end_y
  }
  StreamInfo::{ width: w, height: h, channels: ch }
}

///|
/// 流式解码（带 req_channels）：指定输出通道数。
pub fn decode_stream_channels(
  data : Bytes,
  req_channels : Int,
  on_row : (Int, Array[Byte]) -> Unit,
) -> StreamInfo raise @types.LoadError {
  let img = load_from_bytes_auto(data, req_channels=Some(req_channels))
  let w = img.width
  let h = img.height
  let ch = img.channels
  let row_data : Array[Byte] = Array::make(w * ch, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<ch {
        row_data[x * ch + c] = img.data[(y * w + x) * ch + c]
      }
    }
    on_row(y, row_data)
  }
  StreamInfo::{ width: w, height: h, channels: ch }
}

// 共享的大端/小端字节读写函数与 PNG signature 验证
// 供 bmp/ico/tiff/apng/icns/psd/gif/png 等编解码器复用

///|
/// 读取 2 字节小端无符号整数
fn read_u16_le(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() | (data[offset + 1].to_int() << 8)
}

///|
/// 读取 4 字节小端无符号整数
fn read_u32_le(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() |
  (data[offset + 1].to_int() << 8) |
  (data[offset + 2].to_int() << 16) |
  (data[offset + 3].to_int() << 24)
}

///|
/// 读取 2 字节大端无符号整数
fn read_u16_be(data : Bytes, offset : Int) -> Int {
  (data[offset].to_int() << 8) | data[offset + 1].to_int()
}

///|
/// 读取 4 字节大端无符号整数

///|
fn read_u32_be(data : Bytes, offset : Int) -> Int {
  (data[offset].to_int() << 24) |
  (data[offset + 1].to_int() << 16) |
  (data[offset + 2].to_int() << 8) |
  data[offset + 3].to_int()
}

///|
/// 写入 2 字节小端
fn write_u16_le(buf : Array[Byte], val : Int) -> Unit {
  buf.push((val & 0xFF).to_byte())
  buf.push(((val >> 8) & 0xFF).to_byte())
}

///|
/// 写入 4 字节小端
fn write_u32_le(buf : Array[Byte], val : Int) -> Unit {
  buf.push((val & 0xFF).to_byte())
  buf.push(((val >> 8) & 0xFF).to_byte())
  buf.push(((val >> 16) & 0xFF).to_byte())
  buf.push(((val >> 24) & 0xFF).to_byte())
}

///|
/// 写入 2 字节大端
fn write_u16_be(buf : Array[Byte], val : Int) -> Unit {
  buf.push(((val >> 8) & 0xFF).to_byte())
  buf.push((val & 0xFF).to_byte())
}

///|
/// 写入 4 字节大端
fn write_u32_be(buf : Array[Byte], val : Int) -> Unit {
  buf.push(((val >> 24) & 0xFF).to_byte())
  buf.push(((val >> 16) & 0xFF).to_byte())
  buf.push(((val >> 8) & 0xFF).to_byte())
  buf.push((val & 0xFF).to_byte())
}

///|
/// 验证 PNG signature（8 字节：89 50 4E 47 0D 0A 1A 0A）
/// 越界时返回 false
fn is_png_signature(data : Bytes, offset : Int) -> Bool {
  if offset + 8 > data.length() {
    return false
  }
  data[offset].to_int() == 0x89 &&
  data[offset + 1].to_int() == 0x50 &&
  data[offset + 2].to_int() == 0x4E &&
  data[offset + 3].to_int() == 0x47 &&
  data[offset + 4].to_int() == 0x0D &&
  data[offset + 5].to_int() == 0x0A &&
  data[offset + 6].to_int() == 0x1A &&
  data[offset + 7].to_int() == 0x0A
}

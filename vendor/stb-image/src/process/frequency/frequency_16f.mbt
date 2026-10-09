// 频域变换 16-bit/float 变体
// FFT / DCT / Haar 支持 Image16 / ImageF

// ========== 辅助函数 ==========

///|
fn read_u16_le_freq(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn write_u16_le_freq(buf : Array[Byte], offset : Int, val : Int) -> Unit {
  buf[offset] = (val & 0xFF).to_byte()
  buf[offset + 1] = ((val >> 8) & 0xFF).to_byte()
}

///|
fn read_float_le_freq(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

///|
fn write_f32_le_freq(buf : Array[Byte], offset : Int, val : Float) -> Unit {
  let bits = val.reinterpret_as_int()
  buf[offset] = (bits & 0xFF).to_byte()
  buf[offset + 1] = ((bits >> 8) & 0xFF).to_byte()
  buf[offset + 2] = ((bits >> 16) & 0xFF).to_byte()
  buf[offset + 3] = ((bits >> 24) & 0xFF).to_byte()
}

///|
fn clamp_int_freq(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

// ========== FFT 16-bit ==========

///|
/// 16-bit 2D FFT。输入归一化到 0-1 后变换。
pub fn fft_2d_16(
  img : @types.Image16,
) -> Array[FFTResult] raise @types.LoadError {
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("fft_2d_16 仅支持 channels=1/3/4")
  }
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { 1 }
  let w = img.width
  let h = img.height
  let bpp = ch * 2
  // 转换为 8-bit 灰度图（归一化）
  let data8 : Array[Byte] = Array::make(w * h * color_ch, b'\x00')
  for i in 0..<(w * h) {
    for c in 0..<color_ch {
      let v16 = read_u16_le_freq(img.data, i * bpp + c * 2)
      data8[i * color_ch + c] = (v16 / 257).to_byte()
    }
  }
  let img8 = @types.Image::{
    width: w,
    height: h,
    channels: color_ch,
    data: Bytes::from_array(data8),
  }
  fft_2d(img8)
}

///|
/// 16-bit 逆 FFT。输出 Image16（0-65535）。
pub fn ifft_2d_16(fft : FFTResult) -> @types.Image16 {
  let img8 = ifft_2d(fft)
  let w = img8.width
  let h = img8.height
  let ch = img8.channels
  let out : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  for i in 0..<(w * h * ch) {
    let v8 = img8.data[i].to_int()
    write_u16_le_freq(out, i * 2, v8 * 257)
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 16-bit FFT 幅度谱。输出 Image16。
pub fn fft_magnitude_16(fft : FFTResult, log_scale : Bool) -> @types.Image16 {
  let img8 = fft_magnitude(fft, log_scale)
  let w = img8.width
  let h = img8.height
  let ch = img8.channels
  let out : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  for i in 0..<(w * h * ch) {
    let v8 = img8.data[i].to_int()
    write_u16_le_freq(out, i * 2, v8 * 257)
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== FFT float ==========

///|
/// float 2D FFT。输入直接使用 float 值。
pub fn fft_2d_f(img : @types.ImageF) -> Array[FFTResult] raise @types.LoadError {
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("fft_2d_f 仅支持 channels=1/3/4")
  }
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { 1 }
  let w = img.width
  let h = img.height
  let bpp = ch * 4
  // 转换为 8-bit（归一化到 0-255）
  let data8 : Array[Byte] = Array::make(w * h * color_ch, b'\x00')
  for i in 0..<(w * h) {
    for c in 0..<color_ch {
      let vf = read_float_le_freq(img.data, i * bpp + c * 4)
      let v8 = clamp_int_freq((vf * 255.0F).to_int(), 0, 255)
      data8[i * color_ch + c] = v8.to_byte()
    }
  }
  let img8 = @types.Image::{
    width: w,
    height: h,
    channels: color_ch,
    data: Bytes::from_array(data8),
  }
  fft_2d(img8)
}

///|
/// float 逆 FFT。输出 ImageF（0-1）。
pub fn ifft_2d_f(fft : FFTResult) -> @types.ImageF {
  let img8 = ifft_2d(fft)
  let w = img8.width
  let h = img8.height
  let ch = img8.channels
  let out : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  for i in 0..<(w * h * ch) {
    let v8 = img8.data[i].to_int()
    write_f32_le_freq(out, i * 4, Float::from_int(v8) / 255.0F)
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// float FFT 幅度谱。输出 ImageF。
pub fn fft_magnitude_f(fft : FFTResult, log_scale : Bool) -> @types.ImageF {
  let img8 = fft_magnitude(fft, log_scale)
  let w = img8.width
  let h = img8.height
  let ch = img8.channels
  let out : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  for i in 0..<(w * h * ch) {
    let v8 = img8.data[i].to_int()
    write_f32_le_freq(out, i * 4, Float::from_int(v8) / 255.0F)
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== DCT 16-bit ==========

///|
/// 16-bit 2D DCT。输入归一化后变换。
pub fn dct_2d_16(img : @types.Image16) -> Array[Array[Double]] {
  let w = img.width
  let h = img.height
  let ch = img.channels
  // 转换为 8-bit
  let data8 : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for i in 0..<(w * h * ch) {
    let v16 = read_u16_le_freq(img.data, i * 2)
    data8[i] = (v16 / 257).to_byte()
  }
  let img8 = @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data8),
  }
  dct_2d(img8)
}

///|
/// 16-bit 逆 DCT。输出 Image16。
pub fn idct_2d_16(coeffs : Array[Array[Double]]) -> @types.Image16 {
  let img8 = idct_2d(coeffs)
  let w = img8.width
  let h = img8.height
  let ch = img8.channels
  let out : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  for i in 0..<(w * h * ch) {
    let v8 = img8.data[i].to_int()
    write_u16_le_freq(out, i * 2, v8 * 257)
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== DCT float ==========

///|
/// float 2D DCT。
pub fn dct_2d_f(img : @types.ImageF) -> Array[Array[Double]] {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let data8 : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for i in 0..<(w * h * ch) {
    let vf = read_float_le_freq(img.data, i * 4)
    let v8 = clamp_int_freq((vf * 255.0F).to_int(), 0, 255)
    data8[i] = v8.to_byte()
  }
  let img8 = @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data8),
  }
  dct_2d(img8)
}

///|
/// float 逆 DCT。输出 ImageF。
pub fn idct_2d_f(coeffs : Array[Array[Double]]) -> @types.ImageF {
  let img8 = idct_2d(coeffs)
  let w = img8.width
  let h = img8.height
  let ch = img8.channels
  let out : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  for i in 0..<(w * h * ch) {
    let v8 = img8.data[i].to_int()
    write_f32_le_freq(out, i * 4, Float::from_int(v8) / 255.0F)
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== Haar 16-bit ==========

///|
/// 16-bit 2D Haar 小波变换。
pub fn haar_transform_2d_16(
  img : @types.Image16,
  levels? : Int = 1,
) -> HaarWaveletResult raise @types.LoadError {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let data8 : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for i in 0..<(w * h * ch) {
    let v16 = read_u16_le_freq(img.data, i * 2)
    data8[i] = (v16 / 257).to_byte()
  }
  let img8 = @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data8),
  }
  haar_transform_2d(img8, levels~)
}

///|
/// 16-bit 逆 Haar 小波变换。输出 Image16。
pub fn haar_inverse_transform_2d_16(
  result : HaarWaveletResult,
) -> @types.Image16 {
  let img8 = haar_inverse_transform_2d(result)
  let w = img8.width
  let h = img8.height
  let ch = img8.channels
  let out : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  for i in 0..<(w * h * ch) {
    let v8 = img8.data[i].to_int()
    write_u16_le_freq(out, i * 2, v8 * 257)
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 16-bit Haar 去噪。
pub fn haar_denoise_16(
  img : @types.Image16,
  threshold? : Float = 10.0F,
  soft? : Bool = true,
  levels? : Int = 3,
) -> @types.Image16 raise @types.LoadError {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let data8 : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for i in 0..<(w * h * ch) {
    let v16 = read_u16_le_freq(img.data, i * 2)
    data8[i] = (v16 / 257).to_byte()
  }
  let img8 = @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data8),
  }
  let out8 = haar_denoise(img8, threshold~, soft~, levels~)
  let out : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  for i in 0..<(w * h * ch) {
    let v8 = out8.data[i].to_int()
    write_u16_le_freq(out, i * 2, v8 * 257)
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== Haar float ==========

///|
/// float 2D Haar 小波变换。
pub fn haar_transform_2d_f(
  img : @types.ImageF,
  levels? : Int = 1,
) -> HaarWaveletResult raise @types.LoadError {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let data8 : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for i in 0..<(w * h * ch) {
    let vf = read_float_le_freq(img.data, i * 4)
    let v8 = clamp_int_freq((vf * 255.0F).to_int(), 0, 255)
    data8[i] = v8.to_byte()
  }
  let img8 = @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data8),
  }
  haar_transform_2d(img8, levels~)
}

///|
/// float 逆 Haar 小波变换。输出 ImageF。
pub fn haar_inverse_transform_2d_f(result : HaarWaveletResult) -> @types.ImageF {
  let img8 = haar_inverse_transform_2d(result)
  let w = img8.width
  let h = img8.height
  let ch = img8.channels
  let out : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  for i in 0..<(w * h * ch) {
    let v8 = img8.data[i].to_int()
    write_f32_le_freq(out, i * 4, Float::from_int(v8) / 255.0F)
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// float Haar 去噪。
pub fn haar_denoise_f(
  img : @types.ImageF,
  threshold? : Float = 10.0F,
  soft? : Bool = true,
  levels? : Int = 3,
) -> @types.ImageF raise @types.LoadError {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let data8 : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for i in 0..<(w * h * ch) {
    let vf = read_float_le_freq(img.data, i * 4)
    let v8 = clamp_int_freq((vf * 255.0F).to_int(), 0, 255)
    data8[i] = v8.to_byte()
  }
  let img8 = @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data8),
  }
  let out8 = haar_denoise(img8, threshold~, soft~, levels~)
  let out : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  for i in 0..<(w * h * ch) {
    let v8 = out8.data[i].to_int()
    write_f32_le_freq(out, i * 4, Float::from_int(v8) / 255.0F)
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

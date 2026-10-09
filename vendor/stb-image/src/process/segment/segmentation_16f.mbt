// 图像分割 16-bit/float 变体
// watershed / kmeans / SLIC 支持 Image16 / ImageF

// ========== 辅助函数 ==========

///|
fn read_u16_le_seg(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn read_float_le_seg(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

///|
fn clamp_int_seg(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
fn img16_to_img8(img : @types.Image16) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let data8 : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for i in 0..<(w * h * ch) {
    let v16 = read_u16_le_seg(img.data, i * 2)
    data8[i] = (v16 / 257).to_byte()
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data8),
  }
}

///|
fn imgf_to_img8(img : @types.ImageF) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let data8 : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for i in 0..<(w * h * ch) {
    let vf = read_float_le_seg(img.data, i * 4)
    let v8 = clamp_int_seg((vf * 255.0F).to_int(), 0, 255)
    data8[i] = v8.to_byte()
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data8),
  }
}

// ========== Watershed 16-bit ==========

///|
/// 16-bit Watershed 分割。
pub fn watershed_16(
  img : @types.Image16,
  markers : Array[Int],
) -> Array[Int] raise @types.LoadError {
  let img8 = img16_to_img8(img)
  watershed(img8, markers)
}

///|
/// 16-bit 自动 Watershed 分割。
pub fn watershed_auto_16(
  img : @types.Image16,
) -> (Array[Int], Int) raise @types.LoadError {
  let img8 = img16_to_img8(img)
  watershed_auto(img8)
}

// ========== Watershed float ==========

///|
/// float Watershed 分割。
pub fn watershed_f(
  img : @types.ImageF,
  markers : Array[Int],
) -> Array[Int] raise @types.LoadError {
  let img8 = imgf_to_img8(img)
  watershed(img8, markers)
}

///|
/// float 自动 Watershed 分割。
pub fn watershed_auto_f(
  img : @types.ImageF,
) -> (Array[Int], Int) raise @types.LoadError {
  let img8 = imgf_to_img8(img)
  watershed_auto(img8)
}

// ========== K-means 16-bit ==========

///|
/// 16-bit K-means 图像分割。
pub fn kmeans_segment_16(
  img : @types.Image16,
  k : Int,
  max_iters? : Int = 20,
) -> (SegmentLabelImage, Array[SegmentRegion]) raise @types.LoadError {
  let img8 = img16_to_img8(img)
  kmeans_segment(img8, k, max_iters~)
}

// ========== K-means float ==========

///|
/// float K-means 图像分割。
pub fn kmeans_segment_f(
  img : @types.ImageF,
  k : Int,
  max_iters? : Int = 20,
) -> (SegmentLabelImage, Array[SegmentRegion]) raise @types.LoadError {
  let img8 = imgf_to_img8(img)
  kmeans_segment(img8, k, max_iters~)
}

// ========== SLIC 16-bit ==========

///|
/// 16-bit SLIC 超像素分割。
pub fn slic_16(
  img : @types.Image16,
  k : Int,
  m : Int,
  max_iters : Int,
) -> SuperpixelResult raise @types.LoadError {
  let img8 = img16_to_img8(img)
  slic(img8, k, m, max_iters)
}

// ========== SLIC float ==========

///|
/// float SLIC 超像素分割。
pub fn slic_f(
  img : @types.ImageF,
  k : Int,
  m : Int,
  max_iters : Int,
) -> SuperpixelResult raise @types.LoadError {
  let img8 = imgf_to_img8(img)
  slic(img8, k, m, max_iters)
}

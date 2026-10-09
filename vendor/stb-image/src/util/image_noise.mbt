// 噪声生成（纯 MoonBit）：add_noise_gaussian / add_noise_salt_pepper
// 使用简单的 LCG 伪随机数生成器，种子固定以保证可测试性

///|
/// 简单 LCG 伪随机数生成器状态
priv struct LCG {
  mut state : UInt
}

///|
fn lcg_next(rng : LCG) -> UInt {
  rng.state = rng.state * 1103515245U + 12345U
  rng.state
}

///|
fn lcg_float(rng : LCG) -> Float {
  let v = lcg_next(rng)
  Float::from_int((v & 0xFFFFFFU).reinterpret_as_int()) / 16777216.0F
}

///|
/// Box-Muller 变换生成标准正态分布随机数
fn lcg_gaussian(rng : LCG) -> Float {
  let u1 = lcg_float(rng)
  let u2 = lcg_float(rng)
  let safe_u1 = if u1 < 0.0001F { 0.0001F } else { u1 }
  // ln(x) = log2(x) * ln(2), sqrt(x) = powf(x, 0.5)
  let ln_u1 = @math.log2(safe_u1.to_double()) * 0.6931471805599453
  let r = Float::from_double(ln_u1 * -2.0).sqrt()
  r * @math.cosf(2.0F * 3.14159265F * u2)
}

///|

///|
/// 添加高斯噪声。sigma 为标准差，seed 为随机种子。
/// 仅影响颜色通道，alpha 通道不变。
pub fn add_noise_gaussian(
  img : @types.Image,
  sigma : Float,
  seed : UInt,
) -> @types.Image {
  let rng = LCG::{ state: seed }
  let n = img.width * img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      let noise = lcg_gaussian(rng) * sigma
      let v = img.data[i * ch + c].to_int() + noise.to_int()
      out[i * ch + c] = clamp_b(v)
    }
    if ch == 4 {
      out[i * ch + 3] = img.data[i * ch + 3]
    }
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 添加椒盐噪声。prob 为噪声概率（0.0~1.0），seed 为随机种子。
/// 被选中的像素随机设为 0（椒）或 255（盐）。
pub fn add_noise_salt_pepper(
  img : @types.Image,
  prob : Float,
  seed : UInt,
) -> @types.Image {
  let rng = LCG::{ state: seed }
  let n = img.width * img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  for i in 0..<n {
    let r = lcg_float(rng)
    if r < prob {
      let salt = lcg_float(rng) < 0.5F
      let val = if salt { b'\xFF' } else { b'\x00' }
      for c in 0..<color_ch {
        out[i * ch + c] = val
      }
    } else {
      for c in 0..<ch {
        out[i * ch + c] = img.data[i * ch + c]
      }
    }
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

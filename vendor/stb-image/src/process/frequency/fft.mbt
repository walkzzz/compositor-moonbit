// FFT 频域变换（纯 MoonBit）

///|
/// 复数
pub struct Complex {
  re : Float
  im : Float
}

///|
/// 2D FFT 结果
pub struct FFTResult {
  width : Int
  height : Int
  data : Array[Complex]
}

///|
/// 2D 快速傅里叶变换。将图像变换到频域。
/// 图像尺寸自动补零到 2 的幂次方。
/// 对灰度图（channels=1）或 RGB 图（channels=3/4）每通道独立变换，返回各通道结果。
pub fn fft_2d(img : @types.Image) -> Array[FFTResult] raise @types.LoadError {
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("fft_2d 仅支持 channels=1/3/4")
  }
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { 1 }
  let results : Array[FFTResult] = []
  for c in 0..<color_ch {
    results.push(fft_2d_channel(img, c, ch))
  }
  results
}

///|
fn fft_2d_channel(img : @types.Image, channel : Int, ch : Int) -> FFTResult {
  let w = img.width
  let h = img.height
  let pw = next_pow2(w)
  let ph = next_pow2(h)
  let n = pw * ph
  // 分离实虚部数组，减少 Complex 对象分配，提升缓存局部性
  let re : Array[Float] = Array::make(n, 0.0F)
  let im : Array[Float] = Array::make(n, 0.0F)
  for y in 0..<h {
    for x in 0..<w {
      re[y * pw + x] = Float::from_int(
        img.data[(y * w + x) * ch + channel].to_int(),
      )
    }
  }
  // 行变换
  let row_re : Array[Float] = Array::make(pw, 0.0F)
  let row_im : Array[Float] = Array::make(pw, 0.0F)
  for y in 0..<ph {
    let base = y * pw
    for x in 0..<pw {
      row_re[x] = re[base + x]
      row_im[x] = im[base + x]
    }
    fft_1d_split(row_re, row_im, false)
    for x in 0..<pw {
      re[base + x] = row_re[x]
      im[base + x] = row_im[x]
    }
  }
  // 列变换
  let col_re : Array[Float] = Array::make(ph, 0.0F)
  let col_im : Array[Float] = Array::make(ph, 0.0F)
  for x in 0..<pw {
    for y in 0..<ph {
      col_re[y] = re[y * pw + x]
      col_im[y] = im[y * pw + x]
    }
    fft_1d_split(col_re, col_im, false)
    for y in 0..<ph {
      re[y * pw + x] = col_re[y]
      im[y * pw + x] = col_im[y]
    }
  }
  // 转换回 Array[Complex]
  let data : Array[Complex] = Array::make(n, Complex::{ re: 0.0F, im: 0.0F })
  for i in 0..<n {
    data[i] = Complex::{ re: re[i], im: im[i] }
  }
  FFTResult::{ width: pw, height: ph, data }
}

///|
/// 2D 逆快速傅里叶变换。将频域结果变换回空域灰度图。
pub fn ifft_2d(fft : FFTResult) -> @types.Image {
  let pw = fft.width
  let ph = fft.height
  let n = pw * ph
  // 分离实虚部数组
  let re : Array[Float] = Array::make(n, 0.0F)
  let im : Array[Float] = Array::make(n, 0.0F)
  for i in 0..<n {
    re[i] = fft.data[i].re
    im[i] = fft.data[i].im
  }
  // 行变换
  let row_re : Array[Float] = Array::make(pw, 0.0F)
  let row_im : Array[Float] = Array::make(pw, 0.0F)
  for y in 0..<ph {
    let base = y * pw
    for x in 0..<pw {
      row_re[x] = re[base + x]
      row_im[x] = im[base + x]
    }
    fft_1d_split(row_re, row_im, true)
    for x in 0..<pw {
      re[base + x] = row_re[x]
      im[base + x] = row_im[x]
    }
  }
  // 列变换
  let col_re : Array[Float] = Array::make(ph, 0.0F)
  let col_im : Array[Float] = Array::make(ph, 0.0F)
  for x in 0..<pw {
    for y in 0..<ph {
      col_re[y] = re[y * pw + x]
      col_im[y] = im[y * pw + x]
    }
    fft_1d_split(col_re, col_im, true)
    for y in 0..<ph {
      re[y * pw + x] = col_re[y]
      im[y * pw + x] = col_im[y]
    }
  }
  let norm = Float::from_int(n)
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    let v = re[i] / norm
    let clamped = if v < 0.0F {
      0
    } else if v > 255.0F {
      255
    } else {
      v.to_int()
    }
    out[i] = clamped.to_byte()
  }
  @types.Image::{
    width: pw,
    height: ph,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

///|
/// 计算 FFT 幅度谱（用于可视化）。
/// log_scale=true 时使用对数缩放 log(1+magnitude)。
pub fn fft_magnitude(fft : FFTResult, log_scale : Bool) -> @types.Image {
  let n = fft.width * fft.height
  let out : Array[Byte] = Array::make(n, b'\x00')
  let mut max_mag = 0.0F
  let mags : Array[Float] = Array::make(n, 0.0F)
  for i in 0..<n {
    let re = fft.data[i].re
    let im = fft.data[i].im
    let mag = (re * re + im * im).sqrt()
    let m = if log_scale {
      Float::from_double(@math.log2(mag.to_double() + 1.0) * 0.6931471805599453)
    } else {
      mag
    }
    mags[i] = m
    if m > max_mag {
      max_mag = m
    }
  }
  if max_mag > 0.0F {
    for i in 0..<n {
      let v = mags[i] / max_mag * 255.0F
      let clamped = if v < 0.0F {
        0
      } else if v > 255.0F {
        255
      } else {
        v.to_int()
      }
      out[i] = clamped.to_byte()
    }
  }
  @types.Image::{
    width: fft.width,
    height: fft.height,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

///|
/// 将零频率移到中心（fftshift）
pub fn fft_shift(fft : FFTResult) -> FFTResult {
  let w = fft.width
  let h = fft.height
  let data : Array[Complex] = Array::make(w * h, Complex::{ re: 0.0F, im: 0.0F })
  let cy = h / 2
  let cx = w / 2
  for y in 0..<h {
    for x in 0..<w {
      let sy = (y + cy) % h
      let sx = (x + cx) % w
      data[y * w + x] = fft.data[sy * w + sx]
    }
  }
  FFTResult::{ width: w, height: h, data }
}

///|
/// 原地 fft_shift，避免分配新数组
fn fft_shift_inplace(fft : FFTResult) -> Unit {
  let w = fft.width
  let h = fft.height
  let cy = h / 2
  let cx = w / 2
  for y in 0..<h {
    for x in 0..<w {
      let sy = (y + cy) % h
      let sx = (x + cx) % w
      let src_idx = sy * w + sx
      let dst_idx = y * w + x
      if src_idx > dst_idx {
        let tmp = fft.data[dst_idx]
        fft.data[dst_idx] = fft.data[src_idx]
        fft.data[src_idx] = tmp
      }
    }
  }
}

///|
/// 1D 原地 FFT（Cooley-Tukey radix-2），分离实虚部数组版本
/// inverse=true 时做逆变换（不含归一化，归一化由调用方负责）
fn fft_1d_split(re : Array[Float], im : Array[Float], inverse : Bool) -> Unit {
  let n = re.length()
  if n <= 1 {
    return
  }
  bit_reverse_split(re, im)
  let sign : Float = if inverse { 1.0F } else { -1.0F }
  let mut size = 2
  while size <= n {
    let half = size / 2
    let theta = sign * 2.0F * 3.141592653589793F / Float::from_int(size)
    let w_re = @math.cosf(theta)
    let w_im = @math.sinf(theta)
    let mut i = 0
    while i < n {
      let mut wr = 1.0F
      let mut wi = 0.0F
      for j in 0..<half {
        let idx1 = i + j
        let idx2 = i + j + half
        let a2_re = re[idx2]
        let a2_im = im[idx2]
        let tr = wr * a2_re - wi * a2_im
        let ti = wr * a2_im + wi * a2_re
        let a1_re = re[idx1]
        let a1_im = im[idx1]
        re[idx2] = a1_re - tr
        im[idx2] = a1_im - ti
        re[idx1] = a1_re + tr
        im[idx1] = a1_im + ti
        let new_wr = wr * w_re - wi * w_im
        let new_wi = wr * w_im + wi * w_re
        wr = new_wr
        wi = new_wi
      }
      i += size
    }
    size *= 2
  }
}

///|
fn bit_reverse_split(re : Array[Float], im : Array[Float]) -> Unit {
  let n = re.length()
  if n <= 1 {
    return
  }
  let bits = log2_int(n)
  let high_bit = 1 << (bits - 1)
  // 递推预计算 bit reversal：rev[i] = (rev[i>>1] >> 1) | ((i&1) << (bits-1))
  let rev : Array[Int] = Array::make(n, 0)
  for i in 1..<n {
    rev[i] = (rev[i >> 1] >> 1) | (if (i & 1) != 0 { high_bit } else { 0 })
  }
  for i in 0..<n {
    let j = rev[i]
    if j > i {
      let tmp_re = re[i]
      let tmp_im = im[i]
      re[i] = re[j]
      im[i] = im[j]
      re[j] = tmp_re
      im[j] = tmp_im
    }
  }
}

///|
fn log2_int(n : Int) -> Int {
  let mut k = 0
  let mut v = n
  while v > 1 {
    v = v >> 1
    k += 1
  }
  k
}

///|
fn next_pow2(n : Int) -> Int {
  let mut p = 1
  while p < n {
    p *= 2
  }
  p
}

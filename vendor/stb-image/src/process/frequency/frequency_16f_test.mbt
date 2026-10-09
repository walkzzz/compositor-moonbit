// 频域变换 16-bit/float 变体测试

///|
fn make_img16_freq(w : Int, h : Int, ch : Int, val : Int) -> @types.Image16 {
  let data : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  for i in 0..<(w * h * ch) {
    data[i * 2] = (val & 0xFF).to_byte()
    data[i * 2 + 1] = ((val >> 8) & 0xFF).to_byte()
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
}

///|
fn make_imgf_freq(w : Int, h : Int, ch : Int, val : Float) -> @types.ImageF {
  let data : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  for i in 0..<(w * h * ch) {
    let bits = val.reinterpret_as_int()
    data[i * 4] = (bits & 0xFF).to_byte()
    data[i * 4 + 1] = ((bits >> 8) & 0xFF).to_byte()
    data[i * 4 + 2] = ((bits >> 16) & 0xFF).to_byte()
    data[i * 4 + 3] = ((bits >> 24) & 0xFF).to_byte()
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
}

// ========== FFT ==========

///|
test "fft_2d_16: basic transform" {
  let img = make_img16_freq(4, 4, 1, 30000)
  let results = fft_2d_16(img)
  assert_eq(results.length(), 1)
  assert_true(results[0].width >= 4)
  assert_true(results[0].height >= 4)
  let _ = img
  let _ = results
}

///|
test "fft_2d_f: basic transform" {
  let img = make_imgf_freq(4, 4, 1, 0.5F)
  let results = fft_2d_f(img)
  assert_eq(results.length(), 1)
  assert_true(results[0].width >= 4)
  assert_true(results[0].height >= 4)
  let _ = img
  let _ = results
}

///|
test "fft_2d_16: rejects invalid channels" {
  let img = @types.Image16::{
    width: 2,
    height: 2,
    channels: 2,
    data: Array::make(8, b'\x00') |> Bytes::from_array,
  }
  try {
    let _ = fft_2d_16(img)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "ifft_2d_16: roundtrip" {
  let img = make_img16_freq(4, 4, 1, 30000)
  let results = fft_2d_16(img)
  let reconstructed = ifft_2d_16(results[0])
  assert_eq(reconstructed.width, results[0].width)
  assert_eq(reconstructed.height, results[0].height)
  assert_eq(reconstructed.channels, 1)
  let _ = img
  let _ = results
  let _ = reconstructed
}

///|
test "ifft_2d_f: roundtrip" {
  let img = make_imgf_freq(4, 4, 1, 0.5F)
  let results = fft_2d_f(img)
  let reconstructed = ifft_2d_f(results[0])
  assert_eq(reconstructed.width, results[0].width)
  assert_eq(reconstructed.height, results[0].height)
  assert_eq(reconstructed.channels, 1)
  let _ = img
  let _ = results
  let _ = reconstructed
}

///|
test "fft_magnitude_16: output range" {
  let img = make_img16_freq(4, 4, 1, 30000)
  let results = fft_2d_16(img)
  let mag = fft_magnitude_16(results[0], true)
  assert_eq(mag.channels, 1)
  assert_true(mag.width >= 4)
  let _ = img
  let _ = results
  let _ = mag
}

///|
test "fft_magnitude_f: output range" {
  let img = make_imgf_freq(4, 4, 1, 0.5F)
  let results = fft_2d_f(img)
  let mag = fft_magnitude_f(results[0], true)
  assert_eq(mag.channels, 1)
  assert_true(mag.width >= 4)
  let _ = img
  let _ = results
  let _ = mag
}

// ========== DCT ==========

///|
test "dct_2d_16: basic transform" {
  let img = make_img16_freq(4, 4, 1, 30000)
  let coeffs = dct_2d_16(img)
  assert_eq(coeffs.length(), 4)
  assert_eq(coeffs[0].length(), 4)
  let _ = img
  let _ = coeffs
}

///|
test "dct_2d_f: basic transform" {
  let img = make_imgf_freq(4, 4, 1, 0.5F)
  let coeffs = dct_2d_f(img)
  assert_eq(coeffs.length(), 4)
  assert_eq(coeffs[0].length(), 4)
  let _ = img
  let _ = coeffs
}

///|
test "idct_2d_16: roundtrip" {
  let img = make_img16_freq(4, 4, 1, 30000)
  let coeffs = dct_2d_16(img)
  let reconstructed = idct_2d_16(coeffs)
  assert_eq(reconstructed.width, 4)
  assert_eq(reconstructed.height, 4)
  assert_eq(reconstructed.channels, 1)
  let _ = img
  let _ = coeffs
  let _ = reconstructed
}

///|
test "idct_2d_f: roundtrip" {
  let img = make_imgf_freq(4, 4, 1, 0.5F)
  let coeffs = dct_2d_f(img)
  let reconstructed = idct_2d_f(coeffs)
  assert_eq(reconstructed.width, 4)
  assert_eq(reconstructed.height, 4)
  assert_eq(reconstructed.channels, 1)
  let _ = img
  let _ = coeffs
  let _ = reconstructed
}

// ========== Haar ==========

///|
test "haar_transform_2d_16: basic transform" {
  let img = make_img16_freq(4, 4, 1, 30000)
  let result = haar_transform_2d_16(img)
  assert_true(result.width >= 4)
  assert_true(result.height >= 4)
  let _ = img
  let _ = result
}

///|
test "haar_transform_2d_f: basic transform" {
  let img = make_imgf_freq(4, 4, 1, 0.5F)
  let result = haar_transform_2d_f(img)
  assert_true(result.width >= 4)
  assert_true(result.height >= 4)
  let _ = img
  let _ = result
}

///|
test "haar_inverse_transform_2d_16: roundtrip" {
  let img = make_img16_freq(4, 4, 1, 30000)
  let result = haar_transform_2d_16(img)
  let reconstructed = haar_inverse_transform_2d_16(result)
  assert_eq(reconstructed.channels, 1)
  let _ = img
  let _ = result
  let _ = reconstructed
}

///|
test "haar_inverse_transform_2d_f: roundtrip" {
  let img = make_imgf_freq(4, 4, 1, 0.5F)
  let result = haar_transform_2d_f(img)
  let reconstructed = haar_inverse_transform_2d_f(result)
  assert_eq(reconstructed.channels, 1)
  let _ = img
  let _ = result
  let _ = reconstructed
}

///|
test "haar_denoise_16: basic denoise" {
  let img = make_img16_freq(4, 4, 1, 30000)
  let result = haar_denoise_16(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "haar_denoise_f: basic denoise" {
  let img = make_imgf_freq(4, 4, 1, 0.5F)
  let result = haar_denoise_f(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

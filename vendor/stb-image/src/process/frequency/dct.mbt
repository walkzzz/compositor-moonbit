// DCT (离散余弦变换) 公共 API：dct_2d + idct_2d
// 2D DCT-II 和 IDCT-III，用于频域分析和图像压缩
// 优化：预计算余弦表 + 可分离 1D DCT，O(N³) 而非 O(N⁴)

///|
/// 预计算 DCT 余弦表：cos_table[m][k] = cos((2*k+1)*m*π/(2*N))
/// 注意索引顺序：第一维是频率 m，第二维是空间 k
fn dct_cos_table(n : Int) -> Array[Array[Float]] {
  let pi = 3.14159265358979F
  let nf = Float::from_int(n)
  let table : Array[Array[Float]] = Array::make(n, [])
  for m in 0..<n {
    let row : Array[Float] = Array::make(n, 0.0F)
    let mf = Float::from_int(m)
    for k in 0..<n {
      let kf = Float::from_int(2 * k + 1)
      row[k] = @math.cosf(pi * kf * mf / (2.0F * nf))
    }
    table[m] = row
  }
  table
}

///|
/// 预计算 DCT 归一化系数：C(0)=sqrt(1/N), C(k)=sqrt(2/N)
fn dct_coeffs(n : Int) -> Array[Float] {
  let nf = Float::from_int(n)
  let coeffs : Array[Float] = Array::make(n, 0.0F)
  for i in 0..<n {
    coeffs[i] = if i == 0 { (1.0F / nf).sqrt() } else { (2.0F / nf).sqrt() }
  }
  coeffs
}

///|
/// 1D DCT-II 正变换：对长度 n 的行向量执行 DCT
/// 输入 src[0..n)，输出 dst[0..n)
/// cos_table[k][n] = cos((2*k+1)*n*π/(2*N)), coeffs[n] = C(n)
fn dct_1d(
  src : ArrayView[Float],
  dst : Array[Float],
  cos_table : Array[Array[Float]],
  coeffs : ArrayView[Float],
  n : Int,
) -> Unit {
  for m in 0..<n {
    let mut sum = 0.0F
    let cos_m = cos_table[m]
    for k in 0..<n {
      sum += src[k] * cos_m[k]
    }
    dst[m] = coeffs[m] * sum
  }
}

///|
/// 1D IDCT-III 逆变换：对长度 n 的频域向量执行 IDCT
/// 输入 src[0..n)（频域），输出 dst[0..n)（空间域）
/// 公式：dst[k] = sum_m C(m) * src[m] * cos((2*k+1)*m*π/(2*N))
fn idct_1d(
  src : ArrayView[Float],
  dst : Array[Float],
  cos_table : Array[Array[Float]],
  coeffs : ArrayView[Float],
  n : Int,
) -> Unit {
  for k in 0..<n {
    let mut sum = 0.0F
    for m in 0..<n {
      sum += coeffs[m] * src[m] * cos_table[m][k]
    }
    dst[k] = sum
  }
}

///|
/// 2D DCT-II。将灰度图变换为 DCT 系数矩阵。
/// 输入图像转为灰度，输出 N×M 的系数矩阵。
/// 优化：可分离 1D DCT（先行变换再列变换），O(N³) 而非 O(N⁴)
pub fn dct_2d(img : @types.Image) -> Array[Array[Double]] {
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  // 提取灰度像素数据
  let src : Array[Float] = Array::make(n, 0.0F)
  for i in 0..<n {
    let v = if ch == 1 {
      Float::from_int(img.data[i].to_int())
    } else {
      let r = Float::from_int(img.data[i * ch].to_int())
      let g = Float::from_int(img.data[i * ch + 1].to_int())
      let b = Float::from_int(img.data[i * ch + 2].to_int())
      r * 0.299F + g * 0.587F + b * 0.114F
    }
    src[i] = v
  }
  // 预计算余弦表和归一化系数
  let cos_w = dct_cos_table(w)
  let cos_h = dct_cos_table(h)
  let coeffs_w = dct_coeffs(w)
  let coeffs_h = dct_coeffs(h)
  // 第一步：对每一行执行 1D DCT（宽度方向）
  // row_dct[y][u] = C_w(u) * sum_x src[y][x] * cos((2x+1)uπ/(2W))
  let row_dct : Array[Array[Float]] = Array::make(h, [])
  let row_buf : Array[Float] = Array::make(w, 0.0F)
  for y in 0..<h {
    let row_src : Array[Float] = Array::make(w, 0.0F)
    for x in 0..<w {
      row_src[x] = src[y * w + x]
    }
    dct_1d(row_src[:], row_buf, cos_w, coeffs_w[:], w)
    row_dct[y] = Array::make(w, 0.0F)
    for u in 0..<w {
      row_dct[y][u] = row_buf[u]
    }
  }
  // 第二步：对每一列执行 1D DCT（高度方向）
  // F(v,u) = C_h(v) * sum_y row_dct[y][u] * cos((2y+1)vπ/(2H))
  let result : Array[Array[Double]] = Array::make(h, [])
  let col_buf : Array[Float] = Array::make(h, 0.0F)
  for u in 0..<w {
    let col_src : Array[Float] = Array::make(h, 0.0F)
    for y in 0..<h {
      col_src[y] = row_dct[y][u]
    }
    dct_1d(col_src[:], col_buf, cos_h, coeffs_h[:], h)
    for v in 0..<h {
      if result[v].length() == 0 {
        result[v] = Array::make(w, 0.0)
      }
      result[v][u] = col_buf[v].to_double()
    }
  }
  result
}

///|
/// 2D IDCT-III。将 DCT 系数矩阵逆变换为灰度图。
/// 优化：可分离 1D IDCT（先列变换再行变换），O(N³) 而非 O(N⁴)
pub fn idct_2d(coeffs : Array[Array[Double]]) -> @types.Image {
  let h = coeffs.length()
  let w = if h == 0 { 0 } else { coeffs[0].length() }
  // 预计算余弦表和归一化系数
  let cos_w = dct_cos_table(w)
  let cos_h = dct_cos_table(h)
  let coeffs_w = dct_coeffs(w)
  let coeffs_h = dct_coeffs(h)
  // 第一步：对每一列执行 1D IDCT（高度方向）
  // col_idct[y][u] = sum_v C_h(v) * coeffs[v][u] * cos((2y+1)vπ/(2H))
  let col_idct : Array[Array[Float]] = Array::make(h, [])
  let col_buf : Array[Float] = Array::make(h, 0.0F)
  for u in 0..<w {
    let col_src : Array[Float] = Array::make(h, 0.0F)
    for v in 0..<h {
      col_src[v] = Float::from_double(coeffs[v][u])
    }
    idct_1d(col_src[:], col_buf, cos_h, coeffs_h[:], h)
    for y in 0..<h {
      if col_idct[y].length() == 0 {
        col_idct[y] = Array::make(w, 0.0F)
      }
      col_idct[y][u] = col_buf[y]
    }
  }
  // 第二步：对每一行执行 1D IDCT（宽度方向）
  // f(x,y) = sum_u C_w(u) * col_idct[y][u] * cos((2x+1)uπ/(2W))
  let out : Array[Byte] = Array::make(w * h, b'\x00')
  let row_buf : Array[Float] = Array::make(w, 0.0F)
  for y in 0..<h {
    idct_1d(col_idct[y][:], row_buf, cos_w, coeffs_w[:], w)
    for x in 0..<w {
      let val = (row_buf[x] + 0.5F).to_int().clamp(min=0, max=255)
      out[y * w + x] = val.to_byte()
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

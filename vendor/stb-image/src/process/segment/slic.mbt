// SLIC 超像素分割（Simple Linear Iterative Clustering）
// 纯 MoonBit 实现，基于 Achanta et al. 2012

///|
/// SLIC 超像素分割结果
pub(all) struct SuperpixelResult {
  labels : Array[Int]
  centers : Array[(Int, Int)]
  num_labels : Int
} derive(Eq, @debug.Debug)

///|
fn sqrt_d(x : Double) -> Double {
  if x <= 0.0 {
    return 0.0
  }
  let mut guess = x
  for _ in 0..<20 {
    guess = (guess + x / guess) / 2.0
  }
  guess
}

///|
/// SLIC 超像素分割
/// k: 期望超像素数量, m: 紧凑度参数(通常10-40), max_iters: 迭代次数
pub fn slic(
  img : @types.Image,
  k : Int,
  m : Int,
  max_iters : Int,
) -> SuperpixelResult raise @types.LoadError {
  let w = img.width
  let h = img.height
  let ch = img.channels
  if k <= 0 || w <= 0 || h <= 0 {
    raise @types.LoadError::DecodeFailed(
      "SLIC 参数无效：k/w/h 必须为正数",
    )
  }
  if max_iters <= 0 {
    raise @types.LoadError::DecodeFailed(
      "SLIC 参数无效：max_iters 必须为正数",
    )
  }
  let n = w * h
  let s = sqrt_d(n.to_double() / k.to_double())
  let s_int = if s.to_int() < 1 { 1 } else { s.to_int() }
  let s2 = s * s
  let m_d = m.to_double()
  let m2 = m_d * m_d
  let centers_x : Array[Int] = []
  let centers_y : Array[Int] = []
  let centers_l : Array[Double] = []
  let centers_a : Array[Double] = []
  let centers_b : Array[Double] = []
  let half_s = s_int / 2
  let mut cy = half_s
  while cy < h {
    let mut cx = half_s
    while cx < w {
      let idx = (cy * w + cx) * ch
      let r = img.data[idx].to_int()
      let g = if ch > 1 { img.data[idx + 1].to_int() } else { r }
      let b = if ch > 2 { img.data[idx + 2].to_int() } else { r }
      let (lab_l, lab_a, lab_b) = @color.rgb_to_lab(r, g, b)
      centers_x.push(cx)
      centers_y.push(cy)
      centers_l.push(lab_l.to_double())
      centers_a.push(lab_a.to_double())
      centers_b.push(lab_b.to_double())
      cx += s_int
    }
    cy += s_int
  }
  let num_centers = centers_x.length()
  let labels = Array::make(n, -1)
  let dists = Array::make(n, 1.0e20)
  for _ in 0..<max_iters {
    for i in 0..<n {
      dists[i] = 1.0e20
    }
    for k_idx in 0..<num_centers {
      let cx = centers_x[k_idx]
      let cy = centers_y[k_idx]
      let cl = centers_l[k_idx]
      let ca = centers_a[k_idx]
      let cb = centers_b[k_idx]
      let y_start = if cy - s_int < 0 { 0 } else { cy - s_int }
      let y_end = if cy + s_int >= h { h - 1 } else { cy + s_int }
      let x_start = if cx - s_int < 0 { 0 } else { cx - s_int }
      let x_end = if cx + s_int >= w { w - 1 } else { cx + s_int }
      for y in y_start..<=y_end {
        for x in x_start..<=x_end {
          let pidx = y * w + x
          let data_idx = pidx * ch
          let r = img.data[data_idx].to_int()
          let g = if ch > 1 { img.data[data_idx + 1].to_int() } else { r }
          let b = if ch > 2 { img.data[data_idx + 2].to_int() } else { r }
          let (pl, pa, pb) = @color.rgb_to_lab(r, g, b)
          let dl = pl.to_double() - cl
          let da = pa.to_double() - ca
          let db = pb.to_double() - cb
          let d_lab2 = dl * dl + da * da + db * db
          let dx = (x - cx).to_double()
          let dy = (y - cy).to_double()
          let d_xy2 = dx * dx + dy * dy
          let d2 = d_lab2 + d_xy2 / s2 * m2
          if d2 < dists[pidx] {
            dists[pidx] = d2
            labels[pidx] = k_idx
          }
        }
      }
    }
    let sum_x = Array::make(num_centers, 0)
    let sum_y = Array::make(num_centers, 0)
    let sum_l = Array::make(num_centers, 0.0)
    let sum_a = Array::make(num_centers, 0.0)
    let sum_b = Array::make(num_centers, 0.0)
    let count = Array::make(num_centers, 0)
    for y in 0..<h {
      for x in 0..<w {
        let pidx = y * w + x
        let l = labels[pidx]
        if l >= 0 {
          sum_x[l] += x
          sum_y[l] += y
          count[l] += 1
          let data_idx = pidx * ch
          let r = img.data[data_idx].to_int()
          let g = if ch > 1 { img.data[data_idx + 1].to_int() } else { r }
          let b = if ch > 2 { img.data[data_idx + 2].to_int() } else { r }
          let (pl, pa, pb) = @color.rgb_to_lab(r, g, b)
          sum_l[l] += pl.to_double()
          sum_a[l] += pa.to_double()
          sum_b[l] += pb.to_double()
        }
      }
    }
    for k_idx in 0..<num_centers {
      let cnt = count[k_idx]
      if cnt > 0 {
        centers_x[k_idx] = sum_x[k_idx] / cnt
        centers_y[k_idx] = sum_y[k_idx] / cnt
        let cnt_d = cnt.to_double()
        centers_l[k_idx] = sum_l[k_idx] / cnt_d
        centers_a[k_idx] = sum_a[k_idx] / cnt_d
        centers_b[k_idx] = sum_b[k_idx] / cnt_d
      }
    }
  }
  let centers : Array[(Int, Int)] = []
  for k_idx in 0..<num_centers {
    centers.push((centers_x[k_idx], centers_y[k_idx]))
  }
  SuperpixelResult::{ labels, centers, num_labels: num_centers }
}

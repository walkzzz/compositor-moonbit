// grabCut 分割（纯 MoonBit）
// 交互式前景提取，基于 GMM + ICM 优化
// Rother, Kolmogorov, Blake, "GrabCut" (2004)

// 标签常量

///|
let gc_bgd : Int = 0 // 确定背景

///|
let gc_fgd : Int = 1 // 确定前景

///|
let gc_pr_bgd : Int = 2 // 可能背景

///|
let gc_pr_fgd : Int = 3 // 可能前景

///|
/// grabCut 交互式前景提取。
/// rect_x, rect_y, rect_w, rect_h 指定包含前景的矩形区域。
/// 返回单通道 mask 图像（0=背景, 255=前景）。
/// iterations 控制 GMM 拟合 + ICM 优化的迭代次数。
pub fn grab_cut(
  img : @types.Image,
  rect_x : Int,
  rect_y : Int,
  rect_w : Int,
  rect_h : Int,
  iterations? : Int = 5,
) -> @types.Image raise @types.LoadError {
  if img.width < 2 || img.height < 2 {
    raise @types.LoadError::DecodeFailed("grabCut 需要至少 2x2 图像")
  }
  if img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("grabCut 需要 RGB/RGBA 图像")
  }
  let w = img.width
  let h = img.height
  let ch = img.channels
  let n = w * h
  // 提取 RGB 数据
  let r_arr : Array[Float] = Array::make(n, 0.0F)
  let g_arr : Array[Float] = Array::make(n, 0.0F)
  let b_arr : Array[Float] = Array::make(n, 0.0F)
  for i in 0..<n {
    r_arr[i] = Float::from_int(img.data[i * ch].to_int())
    g_arr[i] = Float::from_int(img.data[i * ch + 1].to_int())
    b_arr[i] = Float::from_int(img.data[i * ch + 2].to_int())
  }
  // 初始化 mask
  let mask : Array[Int] = Array::make(n, gc_bgd)
  let rx2 = (rect_x + rect_w).clamp(min=0, max=w)
  let ry2 = (rect_y + rect_h).clamp(min=0, max=h)
  let rx1 = rect_x.clamp(min=0, max=w)
  let ry1 = rect_y.clamp(min=0, max=h)
  for y in 0..<h {
    for x in 0..<w {
      if x >= rx1 && x < rx2 && y >= ry1 && y < ry2 {
        mask[y * w + x] = gc_pr_fgd
      }
    }
  }
  // GMM 参数：K 个分量
  let k_gmm = 5
  let iters = if iterations < 1 { 5 } else { iterations }
  // 迭代优化
  for _ in 0..<iters {
    // 收集前景和背景像素索引
    let fg_pixels : Array[Int] = []
    let bg_pixels : Array[Int] = []
    for i in 0..<n {
      if mask[i] == gc_fgd || mask[i] == gc_pr_fgd {
        fg_pixels.push(i)
      }
      if mask[i] == gc_bgd || mask[i] == gc_pr_bgd {
        bg_pixels.push(i)
      }
    }
    if fg_pixels.length() == 0 || bg_pixels.length() == 0 {
      break
    }
    // K-means 聚类
    let (fg_means, fg_vars) = fit_gmm(r_arr, g_arr, b_arr, fg_pixels, k_gmm)
    let (bg_means, bg_vars) = fit_gmm(r_arr, g_arr, b_arr, bg_pixels, k_gmm)
    // 计算平滑项参数
    let sigma = compute_sigma(r_arr, g_arr, b_arr, w, h)
    let gamma = 50.0F
    let two_sigma_sq = 2.0F * sigma * sigma
    // ICM 优化：对每个非确定像素更新标签
    for y in 0..<h {
      for x in 0..<w {
        let idx = y * w + x
        if mask[idx] == gc_bgd || mask[idx] == gc_fgd {
          continue
        }
        // 计算 data term
        let d_fg = gmm_distance(
          r_arr[idx],
          g_arr[idx],
          b_arr[idx],
          fg_means,
          fg_vars,
        )
        let d_bg = gmm_distance(
          r_arr[idx],
          g_arr[idx],
          b_arr[idx],
          bg_means,
          bg_vars,
        )
        // 计算平滑项
        let v_fg = smooth_term(
          mask, r_arr, g_arr, b_arr, x, y, w, h, gc_fgd, gamma, two_sigma_sq,
        )
        let v_bg = smooth_term(
          mask, r_arr, g_arr, b_arr, x, y, w, h, gc_bgd, gamma, two_sigma_sq,
        )
        // 选择能量更小的标签
        let e_fg = d_fg + v_fg
        let e_bg = d_bg + v_bg
        if e_fg < e_bg {
          mask[idx] = gc_pr_fgd
        } else {
          mask[idx] = gc_pr_bgd
        }
      }
    }
  }
  // 生成 mask 图像
  let mask_data : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    if mask[i] == gc_fgd || mask[i] == gc_pr_fgd {
      mask_data[i] = b'\xFF'
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(mask_data),
  }
}

// ==================== GMM 拟合 ====================

///|
fn fit_gmm(
  r_arr : Array[Float],
  g_arr : Array[Float],
  b_arr : Array[Float],
  pixels : Array[Int],
  k : Int,
) -> (Array[(Float, Float, Float)], Array[(Float, Float, Float)]) {
  let n = pixels.length()
  if n == 0 {
    return ([], [])
  }
  let actual_k = if n < k { n } else { k }
  // K-means 初始化
  let means_r : Array[Float] = Array::make(actual_k, 0.0F)
  let means_g : Array[Float] = Array::make(actual_k, 0.0F)
  let means_b : Array[Float] = Array::make(actual_k, 0.0F)
  let step = if n > actual_k { n / actual_k } else { 1 }
  for i in 0..<actual_k {
    let idx = pixels[(i * step).clamp(min=0, max=n - 1)]
    means_r[i] = r_arr[idx]
    means_g[i] = g_arr[idx]
    means_b[i] = b_arr[idx]
  }
  let labels : Array[Int] = Array::make(n, 0)
  // K-means 迭代
  for _ in 0..<10 {
    let mut changed = false
    for i in 0..<n {
      let idx = pixels[i]
      let r = r_arr[idx]
      let g = g_arr[idx]
      let b = b_arr[idx]
      let mut best = 0
      let mut best_dist = color_dist_sq_f(
        r,
        g,
        b,
        means_r[0],
        means_g[0],
        means_b[0],
      )
      for j in 1..<actual_k {
        let d = color_dist_sq_f(r, g, b, means_r[j], means_g[j], means_b[j])
        if d < best_dist {
          best_dist = d
          best = j
        }
      }
      if labels[i] != best {
        changed = true
        labels[i] = best
      }
    }
    if !changed {
      break
    }
    // 更新聚类中心
    let sum_r : Array[Float] = Array::make(actual_k, 0.0F)
    let sum_g : Array[Float] = Array::make(actual_k, 0.0F)
    let sum_b : Array[Float] = Array::make(actual_k, 0.0F)
    let cnt : Array[Int] = Array::make(actual_k, 0)
    for i in 0..<n {
      let idx = pixels[i]
      let lbl = labels[i]
      sum_r[lbl] += r_arr[idx]
      sum_g[lbl] += g_arr[idx]
      sum_b[lbl] += b_arr[idx]
      cnt[lbl] += 1
    }
    for j in 0..<actual_k {
      if cnt[j] > 0 {
        let cf = Float::from_int(cnt[j])
        means_r[j] = sum_r[j] / cf
        means_g[j] = sum_g[j] / cf
        means_b[j] = sum_b[j] / cf
      }
    }
  }
  // 计算方差（对角协方差）
  let vars_r : Array[Float] = Array::make(actual_k, 1.0F)
  let vars_g : Array[Float] = Array::make(actual_k, 1.0F)
  let vars_b : Array[Float] = Array::make(actual_k, 1.0F)
  let cnt : Array[Int] = Array::make(actual_k, 0)
  for i in 0..<n {
    let idx = pixels[i]
    let lbl = labels[i]
    let dr = r_arr[idx] - means_r[lbl]
    let dg = g_arr[idx] - means_g[lbl]
    let db = b_arr[idx] - means_b[lbl]
    vars_r[lbl] += dr * dr
    vars_g[lbl] += dg * dg
    vars_b[lbl] += db * db
    cnt[lbl] += 1
  }
  for j in 0..<actual_k {
    if cnt[j] > 0 {
      let cf = Float::from_int(cnt[j])
      vars_r[j] = (vars_r[j] / cf).clamp(min=1.0F, max=10000.0F)
      vars_g[j] = (vars_g[j] / cf).clamp(min=1.0F, max=10000.0F)
      vars_b[j] = (vars_b[j] / cf).clamp(min=1.0F, max=10000.0F)
    }
  }
  // 打包返回
  let means : Array[(Float, Float, Float)] = []
  let vars : Array[(Float, Float, Float)] = []
  for j in 0..<actual_k {
    means.push((means_r[j], means_g[j], means_b[j]))
    vars.push((vars_r[j], vars_g[j], vars_b[j]))
  }
  (means, vars)
}

///|
fn gmm_distance(
  r : Float,
  g : Float,
  b : Float,
  means : Array[(Float, Float, Float)],
  vars : Array[(Float, Float, Float)],
) -> Float {
  let k = means.length()
  if k == 0 {
    return 1000000.0F
  }
  // 找最近的 GMM 分量（简化：不计算完整概率，用马氏距离）
  let mut min_dist = 1000000.0F
  for j in 0..<k {
    let (mr, mg, mb) = means[j]
    let (vr, vg, vb) = vars[j]
    let dr = r - mr
    let dg = g - mg
    let db = b - mb
    // 马氏距离（对角协方差）+ log(det)
    let det = vr * vg * vb
    let log_det = @math.lnf(det)
    let dist = dr * dr / vr + dg * dg / vg + db * db / vb + log_det
    if dist < min_dist {
      min_dist = dist
    }
  }
  min_dist
}

// ==================== 平滑项 ====================

///|
fn smooth_term(
  mask : Array[Int],
  r_arr : Array[Float],
  g_arr : Array[Float],
  b_arr : Array[Float],
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  label : Int,
  gamma : Float,
  two_sigma_sq : Float,
) -> Float {
  let mut energy = 0.0F
  let idx = y * w + x
  let r = r_arr[idx]
  let g = g_arr[idx]
  let b = b_arr[idx]
  // 4 邻域
  let neighbors = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
  for i in 0..<4 {
    let (nx, ny) = neighbors[i]
    if nx < 0 || nx >= w || ny < 0 || ny >= h {
      continue
    }
    let nidx = ny * w + nx
    let n_label = mask[nidx]
    // 判断邻居标签是否与当前不同
    let n_is_fg = n_label == gc_fgd || n_label == gc_pr_fgd
    let cur_is_fg = label == gc_fgd || label == gc_pr_fgd
    if n_is_fg != cur_is_fg {
      let dr = r - r_arr[nidx]
      let dg = g - g_arr[nidx]
      let db = b - b_arr[nidx]
      let color_dist = dr * dr + dg * dg + db * db
      let weight = gamma *
        Float::from_double(
          @math.exp(-color_dist.to_double() / two_sigma_sq.to_double()),
        )
      energy += weight
    }
  }
  energy
}

///|
fn compute_sigma(
  r_arr : Array[Float],
  g_arr : Array[Float],
  b_arr : Array[Float],
  w : Int,
  h : Int,
) -> Float {
  let mut sum = 0.0F
  let mut count = 0
  for y in 0..<h {
    for x in 0..<(w - 1) {
      let idx = y * w + x
      let nidx = y * w + x + 1
      let dr = r_arr[idx] - r_arr[nidx]
      let dg = g_arr[idx] - g_arr[nidx]
      let db = b_arr[idx] - b_arr[nidx]
      sum += dr * dr + dg * dg + db * db
      count += 1
    }
  }
  for y in 0..<(h - 1) {
    for x in 0..<w {
      let idx = y * w + x
      let nidx = (y + 1) * w + x
      let dr = r_arr[idx] - r_arr[nidx]
      let dg = g_arr[idx] - g_arr[nidx]
      let db = b_arr[idx] - b_arr[nidx]
      sum += dr * dr + dg * dg + db * db
      count += 1
    }
  }
  if count == 0 {
    return 30.0F
  }
  (sum / Float::from_int(count)).sqrt().clamp(min=1.0F, max=100.0F)
}

///|
fn color_dist_sq_f(
  r1 : Float,
  g1 : Float,
  b1 : Float,
  r2 : Float,
  g2 : Float,
  b2 : Float,
) -> Float {
  let dr = r1 - r2
  let dg = g1 - g2
  let db = b1 - b2
  dr * dr + dg * dg + db * db
}

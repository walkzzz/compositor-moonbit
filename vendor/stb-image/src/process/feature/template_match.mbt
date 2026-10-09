// 模板匹配（纯 MoonBit）
// 在图像中滑动模板，计算每个位置的匹配分数
// 参考: https://docs.opencv.org/4.x/df/dfb/group__imgproc__object.html

///|
/// 模板匹配方法
pub(all) enum TemplateMatchMethod {
  SqDiff // 平方差：Σ(I-T)²，越小越好
  CCorr // 互相关：Σ(I*T)，越大越好
  CCoeff // 相关系数：Σ(I-Ī)(T-T̄)，越大越好
  SqDiffNormed // 归一化平方差：[0,1]，越小越好
  CCorrNormed // 归一化互相关：[0,1]，越大越好
  CCoeffNormed // 归一化相关系数：[-1,1]，越大越好
}

///|
/// 模板匹配结果
pub(all) struct TemplateMatchResult {
  x : Int // 匹配位置 x
  y : Int // 匹配位置 y
  score : Float // 匹配分数（语义依方法而定）
}

///|
/// 模板匹配。
/// 在 img 中滑动 template，计算每个位置的匹配分数。
/// 返回所有位置的匹配结果（未排序）。
/// 对于 SqDiff/SqDiffNormed，score 越小越好；其余方法 score 越大越好。
pub fn template_match(
  img : @types.Image,
  template : @types.Image,
  match_method? : TemplateMatchMethod = TemplateMatchMethod::CCoeffNormed,
) -> Array[TemplateMatchResult] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "template_match: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "template_match: 图像通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "template_match: 图像数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if template.width <= 0 || template.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "template_match: 模板尺寸必须大于0",
    )
  }
  let tpl_expected_size = template.width * template.height * template.channels
  if template.data.length() != tpl_expected_size {
    raise @types.LoadError::DecodeFailed(
      "template_match: 模板数据大小不匹配，期望 " +
      tpl_expected_size.to_string() +
      "，实际 " +
      template.data.length().to_string(),
    )
  }
  if img.channels != template.channels {
    raise @types.LoadError::DecodeFailed(
      "template_match: 模板与图像通道数必须一致",
    )
  }
  if template.width > img.width || template.height > img.height {
    raise @types.LoadError::DecodeFailed(
      "template_match: 模板不能大于图像",
    )
  }
  let w = img.width
  let tw = template.width
  let th = template.height
  // 转灰度以加速（多通道时按亮度公式合并）
  let (gray_img, _) = to_gray_tm(img)
  let (gray_tpl, _) = to_gray_tm(template)
  // 预计算模板统计量
  let tpl_sum = array_sum(gray_tpl)
  let tpl_sq_sum = array_sq_sum(gray_tpl)
  let tpl_n = tw * th
  let tpl_mean = Float::from_int(tpl_sum) / Float::from_int(tpl_n)
  let tpl_var_sum = tpl_sq_sum -
    2.0F * tpl_mean * Float::from_int(tpl_sum) +
    Float::from_int(tpl_n) * tpl_mean * tpl_mean
  let results : Array[TemplateMatchResult] = []
  let sw = w - tw + 1 // 搜索宽度
  let sh = img.height - th + 1 // 搜索高度
  for y in 0..<sh {
    for x in 0..<sw {
      let score = match match_method {
        SqDiff => compute_sqdiff(gray_img, w, gray_tpl, tw, th, x, y)
        CCorr => compute_ccorr(gray_img, w, gray_tpl, tw, th, x, y)
        CCoeff => compute_ccoeff(gray_img, w, gray_tpl, tw, th, x, y, tpl_mean)
        SqDiffNormed =>
          compute_sqdiff_normed(gray_img, w, gray_tpl, tw, th, x, y, tpl_sq_sum)
        CCorrNormed =>
          compute_ccorr_normed(gray_img, w, gray_tpl, tw, th, x, y, tpl_sq_sum)
        CCoeffNormed =>
          compute_ccoeff_normed(
            gray_img, w, gray_tpl, tw, th, x, y, tpl_mean, tpl_var_sum,
          )
      }
      results.push(TemplateMatchResult::{ x, y, score })
    }
  }
  results
}

///|
/// 找到最佳匹配位置
pub fn template_match_best(
  img : @types.Image,
  template : @types.Image,
  match_method? : TemplateMatchMethod = TemplateMatchMethod::CCoeffNormed,
) -> TemplateMatchResult? raise @types.LoadError {
  let results = template_match(img, template, match_method~)
  if results.length() == 0 {
    return None
  }
  // SqDiff 系列越小越好，其余越大越好
  let want_min = match match_method {
    SqDiff => true
    SqDiffNormed => true
    _ => false
  }
  let mut best = results[0]
  for i in 1..<results.length() {
    let r = results[i]
    if want_min {
      if r.score < best.score {
        best = r
      }
    } else if r.score > best.score {
      best = r
    }
  }
  Some(best)
}

// ==================== 匹配分数计算 ====================

///|
fn compute_sqdiff(
  img : Array[Int],
  w : Int,
  tpl : Array[Int],
  tw : Int,
  th : Int,
  ox : Int,
  oy : Int,
) -> Float {
  let mut sum = 0.0F
  for ty in 0..<th {
    for tx in 0..<tw {
      let diff = Float::from_int(
        img[(oy + ty) * w + (ox + tx)] - tpl[ty * tw + tx],
      )
      sum += diff * diff
    }
  }
  sum
}

///|
fn compute_ccorr(
  img : Array[Int],
  w : Int,
  tpl : Array[Int],
  tw : Int,
  th : Int,
  ox : Int,
  oy : Int,
) -> Float {
  let mut sum = 0.0F
  for ty in 0..<th {
    for tx in 0..<tw {
      sum += Float::from_int(img[(oy + ty) * w + (ox + tx)] * tpl[ty * tw + tx])
    }
  }
  sum
}

///|
fn compute_ccoeff(
  img : Array[Int],
  w : Int,
  tpl : Array[Int],
  tw : Int,
  th : Int,
  ox : Int,
  oy : Int,
  tpl_mean : Float,
) -> Float {
  let n = tw * th
  let mut img_sum = 0
  let mut cross = 0.0F
  for ty in 0..<th {
    for tx in 0..<tw {
      let iv = img[(oy + ty) * w + (ox + tx)]
      let tv = tpl[ty * tw + tx]
      img_sum += iv
      cross += Float::from_int(iv) * Float::from_int(tv)
    }
  }
  let img_mean = Float::from_int(img_sum) / Float::from_int(n)
  cross - Float::from_int(n) * img_mean * tpl_mean
}

///|
fn compute_sqdiff_normed(
  img : Array[Int],
  w : Int,
  tpl : Array[Int],
  tw : Int,
  th : Int,
  ox : Int,
  oy : Int,
  tpl_sq_sum : Float,
) -> Float {
  let mut sq_diff = 0.0F
  let mut img_sq_sum = 0.0F
  for ty in 0..<th {
    for tx in 0..<tw {
      let iv = Float::from_int(img[(oy + ty) * w + (ox + tx)])
      let tv = Float::from_int(tpl[ty * tw + tx])
      let diff = iv - tv
      sq_diff += diff * diff
      img_sq_sum += iv * iv
    }
  }
  let denom = (img_sq_sum * tpl_sq_sum).sqrt()
  if denom < 0.000001F {
    return 1.0F
  }
  sq_diff / denom
}

///|
fn compute_ccorr_normed(
  img : Array[Int],
  w : Int,
  tpl : Array[Int],
  tw : Int,
  th : Int,
  ox : Int,
  oy : Int,
  tpl_sq_sum : Float,
) -> Float {
  let mut cross = 0.0F
  let mut img_sq_sum = 0.0F
  for ty in 0..<th {
    for tx in 0..<tw {
      let iv = Float::from_int(img[(oy + ty) * w + (ox + tx)])
      let tv = Float::from_int(tpl[ty * tw + tx])
      cross += iv * tv
      img_sq_sum += iv * iv
    }
  }
  let denom = (img_sq_sum * tpl_sq_sum).sqrt()
  if denom < 0.000001F {
    return 0.0F
  }
  cross / denom
}

///|
fn compute_ccoeff_normed(
  img : Array[Int],
  w : Int,
  tpl : Array[Int],
  tw : Int,
  th : Int,
  ox : Int,
  oy : Int,
  tpl_mean : Float,
  tpl_var_sum : Float,
) -> Float {
  let n = tw * th
  let mut img_sum = 0
  let mut cross = 0.0F
  let mut img_sq_sum = 0.0F
  for ty in 0..<th {
    for tx in 0..<tw {
      let iv = img[(oy + ty) * w + (ox + tx)]
      let tv = tpl[ty * tw + tx]
      img_sum += iv
      cross += Float::from_int(iv) * Float::from_int(tv)
      img_sq_sum += Float::from_int(iv * iv)
    }
  }
  let img_mean = Float::from_int(img_sum) / Float::from_int(n)
  let img_var_sum = img_sq_sum -
    2.0F * img_mean * Float::from_int(img_sum) +
    Float::from_int(n) * img_mean * img_mean
  let numerator = cross - Float::from_int(n) * img_mean * tpl_mean
  let denom = (img_var_sum * tpl_var_sum).sqrt()
  if denom < 0.000001F {
    return 0.0F
  }
  numerator / denom
}

// ==================== 辅助函数 ====================

///|
fn to_gray_tm(img : @types.Image) -> (Array[Int], Int) {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let n = w * h
  let gray : Array[Int] = Array::make(n, 0)
  for i in 0..<n {
    if ch >= 3 {
      let r = img.data[i * ch].to_int()
      let g = img.data[i * ch + 1].to_int()
      let b = img.data[i * ch + 2].to_int()
      gray[i] = (r * 299 + g * 587 + b * 114) / 1000
    } else {
      gray[i] = img.data[i * ch].to_int()
    }
  }
  (gray, n)
}

///|
fn array_sum(arr : Array[Int]) -> Int {
  let mut s = 0
  for v in arr {
    s += v
  }
  s
}

///|
fn array_sq_sum(arr : Array[Int]) -> Float {
  let mut s = 0.0F
  for v in arr {
    let f = Float::from_int(v)
    s += f * f
  }
  s
}

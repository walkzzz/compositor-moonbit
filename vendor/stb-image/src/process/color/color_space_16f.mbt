// 颜色空间转换 16-bit/float 变体
// HSL / HSV / LAB / XYZ

// ========== 辅助函数 ==========

///|
fn clamp_float_cs(v : Float, lo : Float, hi : Float) -> Float {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
fn clamp_int_cs(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

// ========== HSL 16-bit ==========

///|
/// 16-bit RGB → HSL。输入 r,g,b ∈ [0,65535]，输出 h ∈ [0,360), s,l ∈ [0,1]
pub fn rgb_to_hsl_16(
  r : Int,
  g : Int,
  b : Int,
) -> (Float, Float, Float) raise @types.LoadError {
  // 输入验证
  if r < 0 || r > 65535 || g < 0 || g > 65535 || b < 0 || b > 65535 {
    raise @types.LoadError::DecodeFailed(
      "rgb_to_hsl_16: r,g,b必须在[0,65535]范围内",
    )
  }
  let rf = Float::from_int(r) / 65535.0F
  let gf = Float::from_int(g) / 65535.0F
  let bf = Float::from_int(b) / 65535.0F
  let mx = rf.max(gf).max(bf)
  let mn = rf.min(gf).min(bf)
  let delta = mx - mn
  let l = (mx + mn) / 2.0F
  let s = if delta == 0.0F {
    0.0F
  } else {
    delta / (1.0F - (2.0F * l - 1.0F).abs())
  }
  let h = if delta == 0.0F {
    0.0F
  } else if mx == rf {
    60.0F * ((gf - bf) / delta)
  } else if mx == gf {
    60.0F * ((bf - rf) / delta + 2.0F)
  } else {
    60.0F * ((rf - gf) / delta + 4.0F)
  }
  let h_norm = if h < 0.0F { h + 360.0F } else { h }
  (h_norm, s, l)
}

///|
/// 16-bit HSL → RGB。输入 h ∈ [0,360), s,l ∈ [0,1]，输出 r,g,b ∈ [0,65535]
pub fn hsl_to_rgb_16(
  h : Float,
  s : Float,
  l : Float,
) -> (Int, Int, Int) raise @types.LoadError {
  // 输入验证
  if s < 0.0F || s > 1.0F || l < 0.0F || l > 1.0F {
    raise @types.LoadError::DecodeFailed(
      "hsl_to_rgb_16: s,l必须在[0,1]范围内",
    )
  }
  let c = (1.0F - (2.0F * l - 1.0F).abs()) * s
  let mut hp = h / 60.0F
  if hp < 0.0F {
    hp = hp + 6.0F
  }
  if hp >= 6.0F {
    hp = hp - 6.0F
  }
  let x = c * (1.0F - (hp % 2.0F - 1.0F).abs())
  let m = l - c / 2.0F
  let (r1, g1, b1) = if hp < 1.0F {
    (c, x, 0.0F)
  } else if hp < 2.0F {
    (x, c, 0.0F)
  } else if hp < 3.0F {
    (0.0F, c, x)
  } else if hp < 4.0F {
    (0.0F, x, c)
  } else if hp < 5.0F {
    (x, 0.0F, c)
  } else {
    (c, 0.0F, x)
  }
  let r = clamp_int_cs(((r1 + m) * 65535.0F + 0.5F).to_int(), 0, 65535)
  let g = clamp_int_cs(((g1 + m) * 65535.0F + 0.5F).to_int(), 0, 65535)
  let b = clamp_int_cs(((b1 + m) * 65535.0F + 0.5F).to_int(), 0, 65535)
  (r, g, b)
}

// ========== HSL float ==========

///|
/// float RGB → HSL。输入 r,g,b ∈ [0,1]，输出 h ∈ [0,360), s,l ∈ [0,1]
pub fn rgb_to_hsl_f(
  r : Float,
  g : Float,
  b : Float,
) -> (Float, Float, Float) raise @types.LoadError {
  // 输入验证
  if r < 0.0F || r > 1.0F || g < 0.0F || g > 1.0F || b < 0.0F || b > 1.0F {
    raise @types.LoadError::DecodeFailed(
      "rgb_to_hsl_f: r,g,b必须在[0,1]范围内",
    )
  }
  let rf = clamp_float_cs(r, 0.0F, 1.0F)
  let gf = clamp_float_cs(g, 0.0F, 1.0F)
  let bf = clamp_float_cs(b, 0.0F, 1.0F)
  let mx = rf.max(gf).max(bf)
  let mn = rf.min(gf).min(bf)
  let delta = mx - mn
  let l = (mx + mn) / 2.0F
  let s = if delta == 0.0F {
    0.0F
  } else {
    delta / (1.0F - (2.0F * l - 1.0F).abs())
  }
  let h = if delta == 0.0F {
    0.0F
  } else if mx == rf {
    60.0F * ((gf - bf) / delta)
  } else if mx == gf {
    60.0F * ((bf - rf) / delta + 2.0F)
  } else {
    60.0F * ((rf - gf) / delta + 4.0F)
  }
  let h_norm = if h < 0.0F { h + 360.0F } else { h }
  (h_norm, s, l)
}

///|
/// float HSL → RGB。输入 h ∈ [0,360), s,l ∈ [0,1]，输出 r,g,b ∈ [0,1]
pub fn hsl_to_rgb_f(
  h : Float,
  s : Float,
  l : Float,
) -> (Float, Float, Float) raise @types.LoadError {
  // 输入验证
  if s < 0.0F || s > 1.0F || l < 0.0F || l > 1.0F {
    raise @types.LoadError::DecodeFailed(
      "hsl_to_rgb_f: s,l必须在[0,1]范围内",
    )
  }
  let c = (1.0F - (2.0F * l - 1.0F).abs()) * s
  let mut hp = h / 60.0F
  if hp < 0.0F {
    hp = hp + 6.0F
  }
  if hp >= 6.0F {
    hp = hp - 6.0F
  }
  let x = c * (1.0F - (hp % 2.0F - 1.0F).abs())
  let m = l - c / 2.0F
  let (r1, g1, b1) = if hp < 1.0F {
    (c, x, 0.0F)
  } else if hp < 2.0F {
    (x, c, 0.0F)
  } else if hp < 3.0F {
    (0.0F, c, x)
  } else if hp < 4.0F {
    (0.0F, x, c)
  } else if hp < 5.0F {
    (x, 0.0F, c)
  } else {
    (c, 0.0F, x)
  }
  (
    clamp_float_cs(r1 + m, 0.0F, 1.0F),
    clamp_float_cs(g1 + m, 0.0F, 1.0F),
    clamp_float_cs(b1 + m, 0.0F, 1.0F),
  )
}

// ========== HSV 16-bit ==========

///|
/// 16-bit RGB → HSV。输入 r,g,b ∈ [0,65535]，输出 h ∈ [0,360), s,v ∈ [0,1]
pub fn rgb_to_hsv_16(
  r : Int,
  g : Int,
  b : Int,
) -> (Float, Float, Float) raise @types.LoadError {
  // 输入验证
  if r < 0 || r > 65535 || g < 0 || g > 65535 || b < 0 || b > 65535 {
    raise @types.LoadError::DecodeFailed(
      "rgb_to_hsv_16: r,g,b必须在[0,65535]范围内",
    )
  }
  let rf = Float::from_int(r) / 65535.0F
  let gf = Float::from_int(g) / 65535.0F
  let bf = Float::from_int(b) / 65535.0F
  let mx = rf.max(gf).max(bf)
  let mn = rf.min(gf).min(bf)
  let delta = mx - mn
  let v = mx
  let s = if mx == 0.0F { 0.0F } else { delta / mx }
  let h = if delta == 0.0F {
    0.0F
  } else if mx == rf {
    60.0F * ((gf - bf) / delta)
  } else if mx == gf {
    60.0F * ((bf - rf) / delta + 2.0F)
  } else {
    60.0F * ((rf - gf) / delta + 4.0F)
  }
  let h_norm = if h < 0.0F { h + 360.0F } else { h }
  (h_norm, s, v)
}

///|
/// 16-bit HSV → RGB。输入 h ∈ [0,360), s,v ∈ [0,1]，输出 r,g,b ∈ [0,65535]
pub fn hsv_to_rgb_16(
  h : Float,
  s : Float,
  v : Float,
) -> (Int, Int, Int) raise @types.LoadError {
  // 输入验证
  if s < 0.0F || s > 1.0F || v < 0.0F || v > 1.0F {
    raise @types.LoadError::DecodeFailed(
      "hsv_to_rgb_16: s,v必须在[0,1]范围内",
    )
  }
  let c = v * s
  let mut hp = h / 60.0F
  if hp < 0.0F {
    hp = hp + 6.0F
  }
  if hp >= 6.0F {
    hp = hp - 6.0F
  }
  let x = c * (1.0F - (hp % 2.0F - 1.0F).abs())
  let m = v - c
  let (r1, g1, b1) = if hp < 1.0F {
    (c, x, 0.0F)
  } else if hp < 2.0F {
    (x, c, 0.0F)
  } else if hp < 3.0F {
    (0.0F, c, x)
  } else if hp < 4.0F {
    (0.0F, x, c)
  } else if hp < 5.0F {
    (x, 0.0F, c)
  } else {
    (c, 0.0F, x)
  }
  let r = clamp_int_cs(((r1 + m) * 65535.0F + 0.5F).to_int(), 0, 65535)
  let g = clamp_int_cs(((g1 + m) * 65535.0F + 0.5F).to_int(), 0, 65535)
  let b = clamp_int_cs(((b1 + m) * 65535.0F + 0.5F).to_int(), 0, 65535)
  (r, g, b)
}

// ========== HSV float ==========

///|
/// float RGB → HSV。输入 r,g,b ∈ [0,1]，输出 h ∈ [0,360), s,v ∈ [0,1]
pub fn rgb_to_hsv_f(
  r : Float,
  g : Float,
  b : Float,
) -> (Float, Float, Float) raise @types.LoadError {
  // 输入验证
  if r < 0.0F || r > 1.0F || g < 0.0F || g > 1.0F || b < 0.0F || b > 1.0F {
    raise @types.LoadError::DecodeFailed(
      "rgb_to_hsv_f: r,g,b必须在[0,1]范围内",
    )
  }
  let rf = clamp_float_cs(r, 0.0F, 1.0F)
  let gf = clamp_float_cs(g, 0.0F, 1.0F)
  let bf = clamp_float_cs(b, 0.0F, 1.0F)
  let mx = rf.max(gf).max(bf)
  let mn = rf.min(gf).min(bf)
  let delta = mx - mn
  let v = mx
  let s = if mx == 0.0F { 0.0F } else { delta / mx }
  let h = if delta == 0.0F {
    0.0F
  } else if mx == rf {
    60.0F * ((gf - bf) / delta)
  } else if mx == gf {
    60.0F * ((bf - rf) / delta + 2.0F)
  } else {
    60.0F * ((rf - gf) / delta + 4.0F)
  }
  let h_norm = if h < 0.0F { h + 360.0F } else { h }
  (h_norm, s, v)
}

///|
/// float HSV → RGB。输入 h ∈ [0,360), s,v ∈ [0,1]，输出 r,g,b ∈ [0,1]
pub fn hsv_to_rgb_f(
  h : Float,
  s : Float,
  v : Float,
) -> (Float, Float, Float) raise @types.LoadError {
  // 输入验证
  if s < 0.0F || s > 1.0F || v < 0.0F || v > 1.0F {
    raise @types.LoadError::DecodeFailed(
      "hsv_to_rgb_f: s,v必须在[0,1]范围内",
    )
  }
  let c = v * s
  let mut hp = h / 60.0F
  if hp < 0.0F {
    hp = hp + 6.0F
  }
  if hp >= 6.0F {
    hp = hp - 6.0F
  }
  let x = c * (1.0F - (hp % 2.0F - 1.0F).abs())
  let m = v - c
  let (r1, g1, b1) = if hp < 1.0F {
    (c, x, 0.0F)
  } else if hp < 2.0F {
    (x, c, 0.0F)
  } else if hp < 3.0F {
    (0.0F, c, x)
  } else if hp < 4.0F {
    (0.0F, x, c)
  } else if hp < 5.0F {
    (x, 0.0F, c)
  } else {
    (c, 0.0F, x)
  }
  (
    clamp_float_cs(r1 + m, 0.0F, 1.0F),
    clamp_float_cs(g1 + m, 0.0F, 1.0F),
    clamp_float_cs(b1 + m, 0.0F, 1.0F),
  )
}

// ========== XYZ 16-bit ==========

///|
/// 16-bit RGB → XYZ。输入 r,g,b ∈ [0,65535]，输出 x,y,z ∈ [0,1]
pub fn rgb_to_xyz_16(
  r : Int,
  g : Int,
  b : Int,
) -> (Float, Float, Float) raise @types.LoadError {
  // 输入验证
  if r < 0 || r > 65535 || g < 0 || g > 65535 || b < 0 || b > 65535 {
    raise @types.LoadError::DecodeFailed(
      "rgb_to_xyz_16: r,g,b必须在[0,65535]范围内",
    )
  }
  fn linearize(c : Int) -> Float {
    let cf = Float::from_int(c) / 65535.0F
    if cf <= 0.04045F {
      cf / 12.92F
    } else {
      @math.powf((cf + 0.055F) / 1.055F, 2.4F)
    }
  }
  let rl = linearize(r)
  let gl = linearize(g)
  let bl = linearize(b)
  let x = 0.4124F * rl + 0.3576F * gl + 0.1805F * bl
  let y = 0.2126F * rl + 0.7152F * gl + 0.0722F * bl
  let z = 0.0193F * rl + 0.1192F * gl + 0.9505F * bl
  (x, y, z)
}

///|
/// 16-bit XYZ → RGB。输入 x,y,z ∈ [0,1]，输出 r,g,b ∈ [0,65535]
pub fn xyz_to_rgb_16(
  x : Float,
  y : Float,
  z : Float,
) -> (Int, Int, Int) raise @types.LoadError {
  // 输入验证（XYZ空间允许z值超过1.0）
  if x < 0.0F || y < 0.0F || z < 0.0F {
    raise @types.LoadError::DecodeFailed("xyz_to_rgb_16: x,y,z必须>=0")
  }
  let rl = 3.2406F * x - 1.5372F * y - 0.4986F * z
  let gl = -0.9689F * x + 1.8758F * y + 0.0415F * z
  let bl = 0.0557F * x - 0.2040F * y + 1.0570F * z
  fn srgb(c : Float) -> Int {
    let v = if c <= 0.0031308F {
      c * 12.92F
    } else {
      1.055F * @math.powf(c, 1.0F / 2.4F) - 0.055F
    }
    clamp_int_cs((v * 65535.0F + 0.5F).to_int(), 0, 65535)
  }
  (srgb(rl), srgb(gl), srgb(bl))
}

// ========== XYZ float ==========

///|
/// float RGB → XYZ。输入 r,g,b ∈ [0,1]，输出 x,y,z ∈ [0,1]
pub fn rgb_to_xyz_f(
  r : Float,
  g : Float,
  b : Float,
) -> (Float, Float, Float) raise @types.LoadError {
  // 输入验证
  if r < 0.0F || r > 1.0F || g < 0.0F || g > 1.0F || b < 0.0F || b > 1.0F {
    raise @types.LoadError::DecodeFailed(
      "rgb_to_xyz_f: r,g,b必须在[0,1]范围内",
    )
  }
  fn linearize(c : Float) -> Float {
    let cf = clamp_float_cs(c, 0.0F, 1.0F)
    if cf <= 0.04045F {
      cf / 12.92F
    } else {
      @math.powf((cf + 0.055F) / 1.055F, 2.4F)
    }
  }
  let rl = linearize(r)
  let gl = linearize(g)
  let bl = linearize(b)
  let x = 0.4124F * rl + 0.3576F * gl + 0.1805F * bl
  let y = 0.2126F * rl + 0.7152F * gl + 0.0722F * bl
  let z = 0.0193F * rl + 0.1192F * gl + 0.9505F * bl
  (x, y, z)
}

///|
/// float XYZ → RGB。输入 x,y,z ∈ [0,1]，输出 r,g,b ∈ [0,1]
pub fn xyz_to_rgb_f(
  x : Float,
  y : Float,
  z : Float,
) -> (Float, Float, Float) raise @types.LoadError {
  // 输入验证（XYZ空间允许z值超过1.0）
  if x < 0.0F || y < 0.0F || z < 0.0F {
    raise @types.LoadError::DecodeFailed("xyz_to_rgb_f: x,y,z必须>=0")
  }
  let rl = 3.2406F * x - 1.5372F * y - 0.4986F * z
  let gl = -0.9689F * x + 1.8758F * y + 0.0415F * z
  let bl = 0.0557F * x - 0.2040F * y + 1.0570F * z
  fn srgb(c : Float) -> Float {
    let v = if c <= 0.0031308F {
      c * 12.92F
    } else {
      1.055F * @math.powf(c, 1.0F / 2.4F) - 0.055F
    }
    clamp_float_cs(v, 0.0F, 1.0F)
  }
  (srgb(rl), srgb(gl), srgb(bl))
}

// ========== LAB 16-bit ==========

///|
/// 16-bit RGB → LAB。输入 r,g,b ∈ [0,65535]，输出 L ∈ [0,100], a,b ∈ [-128,127]
pub fn rgb_to_lab_16(
  r : Int,
  g : Int,
  b : Int,
) -> (Float, Float, Float) raise @types.LoadError {
  // 输入验证
  if r < 0 || r > 65535 || g < 0 || g > 65535 || b < 0 || b > 65535 {
    raise @types.LoadError::DecodeFailed(
      "rgb_to_lab_16: r,g,b必须在[0,65535]范围内",
    )
  }
  let (x, y, z) = rgb_to_xyz_16(r, g, b)
  let xn = 0.9505F
  let yn = 1.0F
  let zn = 1.089F
  fn f(t : Float) -> Float {
    if t > 0.008856F {
      @math.powf(t, 1.0F / 3.0F)
    } else {
      7.787F * t + 16.0F / 116.0F
    }
  }
  let fx = f(x / xn)
  let fy = f(y / yn)
  let fz = f(z / zn)
  let l = 116.0F * fy - 16.0F
  let a = 500.0F * (fx - fy)
  let b_val = 200.0F * (fy - fz)
  (l, a, b_val)
}

///|
/// 16-bit LAB → RGB。输入 L ∈ [0,100], a,b ∈ [-128,127]，输出 r,g,b ∈ [0,65535]
pub fn lab_to_rgb_16(
  l : Float,
  a : Float,
  b : Float,
) -> (Int, Int, Int) raise @types.LoadError {
  // 输入验证
  if l < 0.0F || l > 100.0F {
    raise @types.LoadError::DecodeFailed(
      "lab_to_rgb_16: L必须在[0,100]范围内",
    )
  }
  let xn = 0.9505F
  let yn = 1.0F
  let zn = 1.089F
  let fy = (l + 16.0F) / 116.0F
  let fx = a / 500.0F + fy
  let fz = fy - b / 200.0F
  fn finv(t : Float) -> Float {
    if t * t * t > 0.008856F {
      t * t * t
    } else {
      (t - 16.0F / 116.0F) / 7.787F
    }
  }
  let x = xn * finv(fx)
  let y = yn * finv(fy)
  let z = zn * finv(fz)
  xyz_to_rgb_16(x, y, z)
}

// ========== LAB float ==========

///|
/// float RGB → LAB。输入 r,g,b ∈ [0,1]，输出 L ∈ [0,100], a,b ∈ [-128,127]
pub fn rgb_to_lab_f(
  r : Float,
  g : Float,
  b : Float,
) -> (Float, Float, Float) raise @types.LoadError {
  // 输入验证
  if r < 0.0F || r > 1.0F || g < 0.0F || g > 1.0F || b < 0.0F || b > 1.0F {
    raise @types.LoadError::DecodeFailed(
      "rgb_to_lab_f: r,g,b必须在[0,1]范围内",
    )
  }
  let (x, y, z) = rgb_to_xyz_f(r, g, b)
  let xn = 0.9505F
  let yn = 1.0F
  let zn = 1.089F
  fn f(t : Float) -> Float {
    if t > 0.008856F {
      @math.powf(t, 1.0F / 3.0F)
    } else {
      7.787F * t + 16.0F / 116.0F
    }
  }
  let fx = f(x / xn)
  let fy = f(y / yn)
  let fz = f(z / zn)
  let l = 116.0F * fy - 16.0F
  let a = 500.0F * (fx - fy)
  let b_val = 200.0F * (fy - fz)
  (l, a, b_val)
}

///|
/// float LAB → RGB。输入 L ∈ [0,100], a,b ∈ [-128,127]，输出 r,g,b ∈ [0,1]
pub fn lab_to_rgb_f(
  l : Float,
  a : Float,
  b : Float,
) -> (Float, Float, Float) raise @types.LoadError {
  // 输入验证
  if l < 0.0F || l > 100.0F {
    raise @types.LoadError::DecodeFailed(
      "lab_to_rgb_f: L必须在[0,100]范围内",
    )
  }
  let xn = 0.9505F
  let yn = 1.0F
  let zn = 1.089F
  let fy = (l + 16.0F) / 116.0F
  let fx = a / 500.0F + fy
  let fz = fy - b / 200.0F
  fn finv(t : Float) -> Float {
    if t * t * t > 0.008856F {
      t * t * t
    } else {
      (t - 16.0F / 116.0F) / 7.787F
    }
  }
  let x = xn * finv(fx)
  let y = yn * finv(fy)
  let z = zn * finv(fz)
  xyz_to_rgb_f(x, y, z)
}

///|
/// CPU image algorithms: solid fills, brush stamping with hard/soft edges,
/// layer compositing with blend modes and masks, and color adjustments.
///
/// These routines operate on mutable `Array[Byte]` RGBA8 buffers. The core
/// stores rasters as immutable `Bytes`; callers convert with `to_array()` /
/// `Bytes::from_array`. All RGB math uses non-premultiplied channels
/// normalized to `[0.0, 1.0]`.

// ---------------------------------------------------------------------------
// Small numeric helpers
// ---------------------------------------------------------------------------

fn clamp01(x : Double) -> Double {
  if x < 0.0 {
    0.0
  } else if x > 1.0 {
    1.0
  } else {
    x
  }
}

///|
fn dmin(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn dmax(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
/// Smooth Hermite interpolation over `[0, 1]`.
fn smoothstep(t : Double) -> Double {
  let t = clamp01(t)
  t * t * (3.0 - 2.0 * t)
}

///|
/// Linear interpolation.
fn lerp(a : Double, b : Double, t : Double) -> Double {
  a + (b - a) * t
}

// ---------------------------------------------------------------------------
// Raster construction
// ---------------------------------------------------------------------------

///|
/// Create a solid RGBA8 raster.
pub fn solid_rgba(width : Int, height : Int, color : Color) -> Bytes {
  let r = (clamp01(color.r) * 255.0).round().to_int().to_byte()
  let g = (clamp01(color.g) * 255.0).round().to_int().to_byte()
  let b = (clamp01(color.b) * 255.0).round().to_int().to_byte()
  let a = (clamp01(color.a) * 255.0).round().to_int().to_byte()
  let buf = Array::makei(width * height * 4, i => {
    match i % 4 {
      0 => r
      1 => g
      2 => b
      _ => a
    }
  })
  Bytes::from_array(buf)
}

///|
/// A fully transparent RGBA8 raster.
pub fn transparent_rgba(width : Int, height : Int) -> Bytes {
  Bytes::new(width * height * 4)
}

// ---------------------------------------------------------------------------
// Brush
// ---------------------------------------------------------------------------

///|
/// Brush coverage for a sample at normalized distance `d` (`0` center,
/// `1` outer edge). `hardness` is in `[0, 1]`.
fn brush_coverage(d : Double, hardness : Double) -> Double {
  if d <= hardness {
    1.0
  } else if hardness >= 1.0 {
    0.0
  } else {
    let t = (d - hardness) / (1.0 - hardness)
    1.0 - smoothstep(t)
  }
}

///|
/// Stamp one brush center onto an RGBA buffer (source-over).
fn stamp_rgba(
  buf : Array[Byte],
  width : Int,
  height : Int,
  cx : Double,
  cy : Double,
  brush : Brush,
) -> Unit {
  let radius = brush.size / 2.0
  let r0 = (cx - radius).floor()
  let r1 = (cx + radius).ceil()
  let c0 = (cy - radius).floor()
  let c1 = (cy + radius).ceil()
  let cr = clamp01(brush.color.r)
  let cg = clamp01(brush.color.g)
  let cb = clamp01(brush.color.b)
  let ca = clamp01(brush.color.a) * clamp01(brush.opacity)
  let y0 = dmax(c0, 0.0).to_int()
  let y1 = dmin(c1, (height - 1).to_double()).to_int() + 1
  let x0 = dmax(r0, 0.0).to_int()
  let x1 = dmin(r1, (width - 1).to_double()).to_int() + 1
  for y in y0..<y1 {
    for x in x0..<x1 {
      let dx = x.to_double() + 0.5 - cx
      let dy = y.to_double() + 0.5 - cy
      let d = (dx * dx + dy * dy).sqrt() / radius
      if d <= 1.0 {
        let pa = ca * brush_coverage(d, brush.hardness)
        if pa > 0.0 {
          let i = (y * width + x) * 4
          let ba = buf[i + 3].to_int().to_double() / 255.0
          let out_a = pa + ba * (1.0 - pa)
          if out_a > 0.0 {
            let br = buf[i].to_int().to_double() / 255.0
            let bg = buf[i + 1].to_int().to_double() / 255.0
            let bb = buf[i + 2].to_int().to_double() / 255.0
            let nr = (cr * pa + br * ba * (1.0 - pa)) / out_a
            let ng = (cg * pa + bg * ba * (1.0 - pa)) / out_a
            let nb = (cb * pa + bb * ba * (1.0 - pa)) / out_a
            buf[i] = (clamp01(nr) * 255.0).round().to_int().to_byte()
            buf[i + 1] = (clamp01(ng) * 255.0).round().to_int().to_byte()
            buf[i + 2] = (clamp01(nb) * 255.0).round().to_int().to_byte()
            buf[i + 3] = (clamp01(out_a) * 255.0).round().to_int().to_byte()
          }
        }
      }
    }
  }
}

///|
/// Paint an interpolated segment between two pointer positions so fast
/// strokes stay continuous. Stamps are spaced at roughly a quarter radius.
pub fn paint_segment_rgba(
  image : Bytes,
  width : Int,
  height : Int,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  brush : Brush,
) -> Bytes {
  let buf = image.to_array()
  let radius = dmax(brush.size / 2.0, 0.5)
  let dx = x1 - x0
  let dy = y1 - y0
  let dist = (dx * dx + dy * dy).sqrt()
  let steps = dmax((dist / (radius * 0.25)).ceil(), 1.0).to_int()
  let count = steps + 1
  for s in 0..<count {
    let t = s.to_double() / steps.to_double()
    stamp_rgba(buf, width, height, lerp(x0, x1, t), lerp(y0, y1, t), brush)
  }
  Bytes::from_array(buf)
}

///|
/// Stamp one eraser center onto an RGBA buffer: reduce alpha within the
/// brush footprint, effectively erasing pixels.
fn stamp_erase(
  buf : Array[Byte],
  width : Int,
  height : Int,
  cx : Double,
  cy : Double,
  brush : Brush,
) -> Unit {
  let radius = brush.size / 2.0
  let r0 = (cx - radius).floor()
  let r1 = (cx + radius).ceil()
  let c0 = (cy - radius).floor()
  let c1 = (cy + radius).ceil()
  let ea = clamp01(brush.opacity)
  let y0 = dmax(c0, 0.0).to_int()
  let y1 = dmin(c1, (height - 1).to_double()).to_int() + 1
  let x0 = dmax(r0, 0.0).to_int()
  let x1 = dmin(r1, (width - 1).to_double()).to_int() + 1
  for y in y0..<y1 {
    for x in x0..<x1 {
      let dx = x.to_double() + 0.5 - cx
      let dy = y.to_double() + 0.5 - cy
      let d = (dx * dx + dy * dy).sqrt() / radius
      if d <= 1.0 {
        let coverage = ea * brush_coverage(d, brush.hardness)
        let i = (y * width + x) * 4
        let ba = buf[i + 3].to_int().to_double() / 255.0
        let na = ba * (1.0 - coverage)
        buf[i + 3] = (clamp01(na) * 255.0).round().to_int().to_byte()
      }
    }
  }
}

///|
/// Erase an interpolated segment between two pointer positions, reducing
/// alpha within the brush footprint.
pub fn erase_segment_rgba(
  image : Bytes,
  width : Int,
  height : Int,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  brush : Brush,
) -> Bytes {
  let buf = image.to_array()
  let radius = dmax(brush.size / 2.0, 0.5)
  let dx = x1 - x0
  let dy = y1 - y0
  let dist = (dx * dx + dy * dy).sqrt()
  let steps = dmax((dist / (radius * 0.25)).ceil(), 1.0).to_int()
  let count = steps + 1
  for s in 0..<count {
    let t = s.to_double() / steps.to_double()
    stamp_erase(buf, width, height, lerp(x0, x1, t), lerp(y0, y1, t), brush)
  }
  Bytes::from_array(buf)
}

///|
/// Stamp one grayscale value onto a mask buffer using the brush footprint.
fn stamp_mask(
  buf : Array[Byte],
  width : Int,
  height : Int,
  cx : Double,
  cy : Double,
  brush : Brush,
  value : Int,
) -> Unit {
  let radius = brush.size / 2.0
  let r0 = (cx - radius).floor()
  let r1 = (cx + radius).ceil()
  let c0 = (cy - radius).floor()
  let c1 = (cy + radius).ceil()
  let target = value.to_double()
  let ca = clamp01(brush.opacity)
  let y0 = dmax(c0, 0.0).to_int()
  let y1 = dmin(c1, (height - 1).to_double()).to_int() + 1
  let x0 = dmax(r0, 0.0).to_int()
  let x1 = dmin(r1, (width - 1).to_double()).to_int() + 1
  for y in y0..<y1 {
    for x in x0..<x1 {
      let dx = x.to_double() + 0.5 - cx
      let dy = y.to_double() + 0.5 - cy
      let d = (dx * dx + dy * dy).sqrt() / radius
      if d <= 1.0 {
        let pa = ca * brush_coverage(d, brush.hardness)
        let i = y * width + x
        let old = buf[i].to_int().to_double()
        let nv = target * pa + old * (1.0 - pa)
        buf[i] = (clamp01(nv / 255.0) * 255.0).round().to_int().to_byte()
      }
    }
  }
}

///|
/// Paint an interpolated mask segment. `value` is `255` (white, reveal) or
/// `0` (black, conceal).
pub fn paint_segment_mask(
  mask : Mask,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  brush : Brush,
  value : Int,
) -> Mask {
  let buf = mask.data.to_array()
  let radius = dmax(brush.size / 2.0, 0.5)
  let dx = x1 - x0
  let dy = y1 - y0
  let dist = (dx * dx + dy * dy).sqrt()
  let steps = dmax((dist / (radius * 0.25)).ceil(), 1.0).to_int()
  let count = steps + 1
  for s in 0..<count {
    let t = s.to_double() / steps.to_double()
    stamp_mask(
      buf,
      mask.width,
      mask.height,
      lerp(x0, x1, t),
      lerp(y0, y1, t),
      brush,
      value,
    )
  }
  { width: mask.width, height: mask.height, data: Bytes::from_array(buf), }
}

// ---------------------------------------------------------------------------
// Flood fill
// ---------------------------------------------------------------------------

///|
/// Flood-fill a connected region starting at `(start_x, start_y)` with the
/// given color.  Pixels whose RGBA matches the start pixel are replaced.
/// Uses an iterative scanline fill to avoid stack overflow on large regions.
pub fn flood_fill(
  image : Bytes,
  width : Int,
  height : Int,
  start_x : Int,
  start_y : Int,
  color : Color,
) -> Bytes {
  if start_x < 0 || start_x >= width || start_y < 0 || start_y >= height {
    return image
  }
  let buf = image.to_array()
  let si = (start_y * width + start_x) * 4
  let tr = buf[si]
  let tg = buf[si + 1]
  let tb = buf[si + 2]
  let ta = buf[si + 3]
  let fr = (clamp01(color.r) * 255.0).round().to_int().to_byte()
  let fg = (clamp01(color.g) * 255.0).round().to_int().to_byte()
  let fb = (clamp01(color.b) * 255.0).round().to_int().to_byte()
  let fa = (clamp01(color.a) * 255.0).round().to_int().to_byte()
  // Nothing to do if the fill color matches the target.
  if tr == fr && tg == fg && tb == fb && ta == fa {
    return image
  }
  // Scanline flood fill with an explicit stack of (x, y) pairs.
  let stack_x = [start_x]
  let stack_y = [start_y]
  while stack_x.length() > 0 {
    let x = stack_x[stack_x.length() - 1]
    ignore(stack_x.pop())
    let y = stack_y[stack_y.length() - 1]
    ignore(stack_y.pop())
    // Scan left to find the left boundary.
    let mut lx = x
    while lx >= 0 {
      let i = (y * width + lx) * 4
      if buf[i] != tr ||
        buf[i + 1] != tg ||
        buf[i + 2] != tb ||
        buf[i + 3] != ta {
        break
      }
      lx -= 1
    }
    lx += 1
    // Scan right, filling pixels and checking above/below.
    let mut rx = lx
    while rx < width {
      let i = (y * width + rx) * 4
      if buf[i] != tr ||
        buf[i + 1] != tg ||
        buf[i + 2] != tb ||
        buf[i + 3] != ta {
        break
      }
      buf[i] = fr
      buf[i + 1] = fg
      buf[i + 2] = fb
      buf[i + 3] = fa
      // Check pixel above.
      if y > 0 {
        let ai = ((y - 1) * width + rx) * 4
        if buf[ai] == tr &&
          buf[ai + 1] == tg &&
          buf[ai + 2] == tb &&
          buf[ai + 3] == ta {
          stack_x.push(rx)
          stack_y.push(y - 1)
        }
      }
      // Check pixel below.
      if y < height - 1 {
        let bi = ((y + 1) * width + rx) * 4
        if buf[bi] == tr &&
          buf[bi + 1] == tg &&
          buf[bi + 2] == tb &&
          buf[bi + 3] == ta {
          stack_x.push(rx)
          stack_y.push(y + 1)
        }
      }
      rx += 1
    }
  }
  Bytes::from_array(buf)
}

// ---------------------------------------------------------------------------
// Blend modes
// ---------------------------------------------------------------------------

///|
/// Separable blend applied per channel; `cb` is backdrop, `cs` source.
fn blend_separable(mode : BlendMode, cb : Double, cs : Double) -> Double {
  match mode {
    Normal => cs
    Multiply => cb * cs
    Screen => cb + cs - cb * cs
    Overlay =>
      // HardLight with source/backdrop swapped.
      if cb <= 0.5 {
        cb * (2.0 * cs)
      } else {
        cb + 2.0 * cs - 2.0 * cb * cs - 1.0
      }
    Darken => dmin(cb, cs)
    Lighten => dmax(cb, cs)
    ColorDodge =>
      if cb <= 0.0 {
        0.0
      } else if cs >= 1.0 {
        1.0
      } else {
        dmin(1.0, cb / (1.0 - cs))
      }
    ColorBurn =>
      if cb >= 1.0 {
        1.0
      } else if cs <= 0.0 {
        0.0
      } else {
        1.0 - dmin(1.0, (1.0 - cb) / cs)
      }
    HardLight =>
      if cs <= 0.5 {
        cb * 2.0 * cs
      } else {
        cb + 2.0 * cs - 2.0 * cb * cs - 1.0
      }
    SoftLight =>
      if cs <= 0.5 {
        cb - (1.0 - 2.0 * cs) * cb * (1.0 - cb)
      } else {
        let d = if cb <= 0.25 {
          ((16.0 * cb - 12.0) * cb + 4.0) * cb
        } else {
          cb.sqrt()
        }
        cb + (2.0 * cs - 1.0) * (d - cb)
      }
    Difference => (cb - cs).abs()
    Exclusion => cb + cs - 2.0 * cb * cs
    _ => cs
  }
}

// Non-separable helpers (W3C compositing).

///|
fn lum(r : Double, g : Double, b : Double) -> Double {
  0.3 * r + 0.59 * g + 0.11 * b
}

///|
fn clip_color(r : Double, g : Double, b : Double) -> (Double, Double, Double) {
  let mut r = r
  let mut g = g
  let mut b = b
  let l = lum(r, g, b)
  let n = dmin(r, dmin(g, b))
  let x = dmax(r, dmax(g, b))
  if n < 0.0 {
    r = l + (r - l) * l / (l - n)
    g = l + (g - l) * l / (l - n)
    b = l + (b - l) * l / (l - n)
  }
  if x > 1.0 {
    r = l + (r - l) * (1.0 - l) / (x - l)
    g = l + (g - l) * (1.0 - l) / (x - l)
    b = l + (b - l) * (1.0 - l) / (x - l)
  }
  (r, g, b)
}

///|
fn set_lum(
  r : Double,
  g : Double,
  b : Double,
  l : Double,
) -> (Double, Double, Double) {
  let d = l - lum(r, g, b)
  clip_color(r + d, g + d, b + d)
}

///|
fn sat(r : Double, g : Double, b : Double) -> Double {
  dmax(r, dmax(g, b)) - dmin(r, dmin(g, b))
}

///|
fn set_sat(
  r : Double,
  g : Double,
  b : Double,
  s : Double,
) -> (Double, Double, Double) {
  // Sort channels to distribute saturation like the reference algorithm.
  let cols = [r, g, b]
  // Simple selection sort on values while keeping the W3C min/max/mid mapping.
  let (min_i, max_i) = minmax_index(cols)
  let out = [0.0, 0.0, 0.0]
  if cols[max_i] > cols[min_i] {
    out[max_i] = s
    out[min_i] = 0.0
    let mid_i = 3 - min_i - max_i
    out[mid_i] = (cols[mid_i] - cols[min_i]) * s / (cols[max_i] - cols[min_i])
  }
  (out[0], out[1], out[2])
}

///|
fn minmax_index(cols : Array[Double]) -> (Int, Int) {
  let mut min_i = 0
  let mut max_i = 0
  for i in 1..<3 {
    if cols[i] < cols[min_i] {
      min_i = i
    }
    if cols[i] > cols[max_i] {
      max_i = i
    }
  }
  (min_i, max_i)
}

///|
/// Blend a full RGB triple, dispatching the non-separable modes.
fn blend_rgb(
  mode : BlendMode,
  cb : (Double, Double, Double),
  cs : (Double, Double, Double),
) -> (Double, Double, Double) {
  let (br, bg, bb) = cb
  let (sr, sg, sb) = cs
  match mode {
    Hue => {
      let (r, g, b) = set_lum(sr, sg, sb, lum(br, bg, bb))
      set_sat(r, g, b, sat(br, bg, bb))
    }
    Saturation => {
      let (r, g, b) = set_lum(br, bg, bb, lum(br, bg, bb))
      set_sat(r, g, b, sat(sr, sg, sb))
    }
    Color => set_lum(sr, sg, sb, lum(br, bg, bb))
    Luminosity => set_lum(br, bg, bb, lum(sr, sg, sb))
    _ =>
      (
        blend_separable(mode, br, sr),
        blend_separable(mode, bg, sg),
        blend_separable(mode, bb, sb),
      )
  }
}

// ---------------------------------------------------------------------------
// Compositing
// ---------------------------------------------------------------------------

///|
/// Flatten the visible layer stack into a single RGBA8 raster. Layer order in
/// the array is bottom to top. Each layer's opacity, blend mode, and optional
/// mask are applied.
pub fn flatten(model : Model) -> Bytes {
  let w = model.width
  let h = model.height
  let zero = Int::to_byte(0)
  let acc = Array::make(w * h * 4, zero)
  let count = model.layers.length()
  for li in 0..<count {
    let layer = model.layers[li]
    if layer.visible && layer.image is Some(image) {
      let src = image // Bytes
      let ox = layer.offset_x.round().to_int()
      let oy = layer.offset_y.round().to_int()
      for y in 0..<h {
        for x in 0..<w {
          // Source pixel after applying layer offset.
          let sx = x - ox
          let sy = y - oy
          if sx < 0 || sx >= w || sy < 0 || sy >= h {
            continue
          }
          let i = (y * w + x) * 4
          let si = (sy * w + sx) * 4
          let mut sa = src.at(si + 3).to_int().to_double() /
            255.0 *
            layer.opacity
          // Mask modulates source alpha.
          if layer.mask is Some(mask) {
            sa *= mask.data.at(sy * w + sx).to_int().to_double() / 255.0
          }
          if sa > 0.0 {
            let sr = src.at(si).to_int().to_double() / 255.0
            let sg = src.at(si + 1).to_int().to_double() / 255.0
            let sb = src.at(si + 2).to_int().to_double() / 255.0
            let da = acc[i + 3].to_int().to_double() / 255.0
            let (fr, fg, fb) = blend_rgb(
              layer.blend,
              (
                acc[i].to_int().to_double() / 255.0,
                acc[i + 1].to_int().to_double() / 255.0,
                acc[i + 2].to_int().to_double() / 255.0,
              ),
              (sr, sg, sb),
            )
            let out_a = sa + da * (1.0 - sa)
            if out_a > 0.0 {
              let nr = (
                  fr * sa +
                  acc[i].to_int().to_double() / 255.0 * da * (1.0 - sa)
                ) /
                out_a
              let ng = (
                  fg * sa +
                  acc[i + 1].to_int().to_double() / 255.0 * da * (1.0 - sa)
                ) /
                out_a
              let nb = (
                  fb * sa +
                  acc[i + 2].to_int().to_double() / 255.0 * da * (1.0 - sa)
                ) /
                out_a
              acc[i] = (clamp01(nr) * 255.0).round().to_int().to_byte()
              acc[i + 1] = (clamp01(ng) * 255.0).round().to_int().to_byte()
              acc[i + 2] = (clamp01(nb) * 255.0).round().to_int().to_byte()
              acc[i + 3] = (clamp01(out_a) * 255.0).round().to_int().to_byte()
            }
          }
        }
      }
    }
  }
  Bytes::from_array(acc)
}

// ---------------------------------------------------------------------------
// Color adjustments (mutate one layer)
// ---------------------------------------------------------------------------

///|
fn rgb_to_hsl(r : Double, g : Double, b : Double) -> (Double, Double, Double) {
  let mx = dmax(r, dmax(g, b))
  let mn = dmin(r, dmin(g, b))
  let l = (mx + mn) / 2.0
  if mx == mn {
    (0.0, 0.0, l)
  } else {
    let d = mx - mn
    let s = if l > 0.5 { d / (2.0 - mx - mn) } else { d / (mx + mn) }
    let mut h = 0.0
    if mx == r {
      h = (g - b) / d + (if g < b { 6.0 } else { 0.0 })
    } else if mx == g {
      h = (b - r) / d + 2.0
    } else {
      h = (r - g) / d + 4.0
    }
    (h / 6.0, s, l)
  }
}

///|
fn hsl_to_rgb(h : Double, s : Double, l : Double) -> (Double, Double, Double) {
  if s == 0.0 {
    (l, l, l)
  } else {
    let hue_to_rgb = fn(p : Double, q : Double, t0 : Double) -> Double {
      let mut t = t0
      if t < 0.0 {
        t += 1.0
      }
      if t > 1.0 {
        t -= 1.0
      }
      if t < 1.0 / 6.0 {
        p + (q - p) * 6.0 * t
      } else if t < 1.0 / 2.0 {
        q
      } else if t < 2.0 / 3.0 {
        p + (q - p) * (2.0 / 3.0 - t) * 6.0
      } else {
        p
      }
    }
    let q = if l < 0.5 { l * (1.0 + s) } else { l + s - l * s }
    let p = 2.0 * l - q
    (
      hue_to_rgb(p, q, h + 1.0 / 3.0),
      hue_to_rgb(p, q, h),
      hue_to_rgb(p, q, h - 1.0 / 3.0),
    )
  }
}

///|
/// Apply one of the adjustment messages to a raster, returning a new raster.
fn adjust_pixels(
  image : Bytes,
  f : (Double, Double, Double) -> (Double, Double, Double),
) -> Bytes {
  let src = image.to_array()
  let n = src.length() / 4
  for p in 0..<n {
    let i = p * 4
    let r = src[i].to_int().to_double() / 255.0
    let g = src[i + 1].to_int().to_double() / 255.0
    let b = src[i + 2].to_int().to_double() / 255.0
    let (nr, ng, nb) = f(r, g, b)
    src[i] = (clamp01(nr) * 255.0).round().to_int().to_byte()
    src[i + 1] = (clamp01(ng) * 255.0).round().to_int().to_byte()
    src[i + 2] = (clamp01(nb) * 255.0).round().to_int().to_byte()
  }
  Bytes::from_array(src)
}

///|
pub fn adjust_brightness(image : Bytes, amount : Double) -> Bytes {
  // amount in [-1, 1]
  adjust_pixels(image, (r, g, b) => (r + amount, g + amount, b + amount))
}

///|
pub fn adjust_contrast(image : Bytes, amount : Double) -> Bytes {
  // amount in [-1, 1]; pivot around 0.5
  let factor = 1.0 + amount
  adjust_pixels(image, (r, g, b) => {
    (
      (r - 0.5) * factor + 0.5,
      (g - 0.5) * factor + 0.5,
      (b - 0.5) * factor + 0.5,
    )
  })
}

///|
pub fn adjust_hue(image : Bytes, degrees : Double) -> Bytes {
  let shift = degrees / 360.0
  adjust_pixels(image, (r, g, b) => {
    let (h, s, l) = rgb_to_hsl(r, g, b)
    let mut nh = h + shift
    nh = nh - nh.floor() // wrap into [0,1)
    hsl_to_rgb(nh, s, l)
  })
}

///|
pub fn adjust_saturation(image : Bytes, amount : Double) -> Bytes {
  // amount in [-1, 1]
  let factor = 1.0 + amount
  adjust_pixels(image, (r, g, b) => {
    let (h, s, l) = rgb_to_hsl(r, g, b)
    hsl_to_rgb(h, clamp01(s * factor), l)
  })
}

// ---------------------------------------------------------------------------
// Gaussian blur
// ---------------------------------------------------------------------------

///|
/// Apply a Gaussian blur with the given radius (in pixels) to an RGBA8
/// raster.  Uses a separable kernel: horizontal pass then vertical pass.
/// Only RGB channels are blurred; alpha is preserved.  Radius is clamped
/// to `[0, 50]`; a radius of 0 returns the image unchanged.
pub fn gaussian_blur(
  image : Bytes,
  width : Int,
  height : Int,
  radius : Double,
) -> Bytes {
  let r = clamp01(radius / 50.0) * 50.0
  if r < 0.5 {
    return image
  }
  let sigma = r / 2.0
  let two_sigma_sq = 2.0 * sigma * sigma
  // Kernel half-size: 3*sigma covers >99% of the Gaussian.
  let half_raw = (r * 3.0).ceil().to_int()
  let half = if half_raw > 50 { 50 } else { half_raw }
  let kernel_size = half * 2 + 1
  // Build 1D Gaussian kernel.
  let kernel = Array::make(kernel_size, 0.0)
  let mut ksum = 0.0
  for k in 0..<kernel_size {
    let d = (k - half).to_double()
    let w = @math.exp(-(d * d) / two_sigma_sq)
    kernel[k] = w
    ksum += w
  }
  for k in 0..<kernel_size {
    kernel[k] /= ksum
  }
  let src = image.to_array()
  let n = width * height
  // Horizontal pass: write into a temporary buffer.
  let tmp = Array::make(width * height * 4, Int::to_byte(0))
  for y in 0..<height {
    for x in 0..<width {
      let mut r_acc = 0.0
      let mut g_acc = 0.0
      let mut b_acc = 0.0
      for k in 0..<kernel_size {
        let sx = x + k - half
        if sx >= 0 && sx < width {
          let i = (y * width + sx) * 4
          let w = kernel[k]
          r_acc += src[i].to_int().to_double() / 255.0 * w
          g_acc += src[i + 1].to_int().to_double() / 255.0 * w
          b_acc += src[i + 2].to_int().to_double() / 255.0 * w
        }
      }
      let oi = (y * width + x) * 4
      tmp[oi] = (clamp01(r_acc) * 255.0).round().to_int().to_byte()
      tmp[oi + 1] = (clamp01(g_acc) * 255.0).round().to_int().to_byte()
      tmp[oi + 2] = (clamp01(b_acc) * 255.0).round().to_int().to_byte()
      tmp[oi + 3] = src[oi + 3]
    }
  }
  // Vertical pass: read from tmp, write into result.
  let result = Array::make(width * height * 4, Int::to_byte(0))
  for y in 0..<height {
    for x in 0..<width {
      let mut r_acc = 0.0
      let mut g_acc = 0.0
      let mut b_acc = 0.0
      for k in 0..<kernel_size {
        let sy = y + k - half
        if sy >= 0 && sy < height {
          let i = (sy * width + x) * 4
          let w = kernel[k]
          r_acc += tmp[i].to_int().to_double() / 255.0 * w
          g_acc += tmp[i + 1].to_int().to_double() / 255.0 * w
          b_acc += tmp[i + 2].to_int().to_double() / 255.0 * w
        }
      }
      let oi = (y * width + x) * 4
      result[oi] = (clamp01(r_acc) * 255.0).round().to_int().to_byte()
      result[oi + 1] = (clamp01(g_acc) * 255.0).round().to_int().to_byte()
      result[oi + 2] = (clamp01(b_acc) * 255.0).round().to_int().to_byte()
      result[oi + 3] = tmp[oi + 3]
    }
  }
  ignore(n)
  Bytes::from_array(result)
}

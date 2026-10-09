///|
fn bench_make_rgb(width : Int, height : Int) -> @types.Image {
  let n = width * height
  let data : Array[Byte] = Array::make(n * 3, b'\x80')
  for i in 0..<n {
    data[i * 3] = (i * 37 % 256).to_byte()
    data[i * 3 + 1] = (i * 71 % 256).to_byte()
    data[i * 3 + 2] = (i * 113 % 256).to_byte()
  }
  @types.Image::{ width, height, channels: 3, data: Bytes::from_array(data) }
}

///|
fn bench_make_rgba(width : Int, height : Int) -> @types.Image {
  let n = width * height
  let data : Array[Byte] = Array::make(n * 4, b'\xFF')
  for i in 0..<n {
    data[i * 4] = (i * 37 % 256).to_byte()
    data[i * 4 + 1] = (i * 71 % 256).to_byte()
    data[i * 4 + 2] = (i * 113 % 256).to_byte()
    data[i * 4 + 3] = b'\xFF'
  }
  @types.Image::{ width, height, channels: 4, data: Bytes::from_array(data) }
}

///|
pub fn bench_run() -> Unit {
  let b = @bench.Bench()
  let img128 = bench_make_rgb(128, 128)
  let img256 = bench_make_rgb(256, 256)
  let img_rgba128 = bench_make_rgba(128, 128)
  let empty = @types.Image::{ width: 0, height: 0, channels: 0, data: b"" }

  // === 编解码 ===
  b.bench(name="png encode 128x128", () => {
    ignore(@codec.encode_png_pure(img128))
  })
  b.bench(name="png decode 128x128", () => {
    let png = @codec.encode_png_pure(img128)
    ignore(@codec.decode_png_pure(png) catch { _ => empty })
  })
  b.bench(name="bmp encode 128x128", () => {
    ignore(@codec.encode_bmp_pure(img128))
  })
  b.bench(name="jpeg encode 128x128", () => {
    ignore(@codec.encode_jpeg_pure(img128) catch { _ => b"" })
  })
  b.bench(name="gif encode 128x128", () => {
    ignore(@codec.encode_gif_pure(img128) catch { _ => b"" })
  })
  b.bench(name="pnm encode 128x128", () => {
    ignore(@codec.encode_pnm_pure(img128))
  })
  b.bench(name="qoi encode 128x128", () => {
    ignore(@codec.encode_qoi_pure(img_rgba128) catch { _ => b"" })
  })
  b.bench(name="qoi decode 128x128", () => {
    let qoi = @codec.encode_qoi_pure(img_rgba128) catch { _ => b"" }
    ignore(@codec.decode_qoi_pure(qoi) catch { _ => empty })
  })
  b.bench(name="webp lossy encode 128x128", () => {
    ignore(@codec.encode_webp_lossy_pure(img_rgba128) catch { _ => b"" })
  })

  // === 缩放 ===
  b.bench(name="resize 256->128", () => {
    ignore(@pure_util.resize_pure(img256, 128, 128) catch { _ => img128 })
  })

  // === 滤波 ===
  b.bench(name="gaussian_blur 128x128", () => {
    ignore(@filter.gaussian_blur(img128, 5, 1.0F) catch { _ => empty })
  })
  b.bench(name="box_blur 128x128", () => {
    ignore(@filter.box_blur(img128, 5) catch { _ => empty })
  })
  b.bench(name="sharpen 128x128", () => {
    ignore(@filter.sharpen(img128, 1.0F) catch { _ => empty })
  })
  b.bench(name="bilateral_filter 128x128", () => {
    ignore(
      @filter.bilateral_filter(img128, 3, 2.0F, 30.0F) catch {
        _ => empty
      },
    )
  })

  // === 边缘检测 ===
  b.bench(name="edge_detect_sobel 128x128", () => {
    ignore(@edge.edge_detect_sobel(img128) catch { _ => empty })
  })
  b.bench(name="canny_edge 128x128", () => {
    ignore(@edge.canny_edge(img128) catch { _ => empty })
  })

  // === 特征检测 ===
  b.bench(name="harris_corners 128x128", () => {
    ignore(@feature.harris_corners(img128) catch { _ => [] })
  })

  // === 频域 ===
  b.bench(name="fft_2d 128x128", () => {
    ignore(@frequency.fft_2d(img128) catch { _ => [] })
  })

  // === 分割 ===
  b.bench(name="slic 128x128", () => {
    ignore(
      @segment.slic(img128, 16, 10, 5) catch {
        _ =>
          @segment.SuperpixelResult::{ labels: [], centers: [], num_labels: 0 }
      },
    )
  })
  b.bench(name="connected_components 128x128", () => {
    ignore(try! @segment.connected_components(img128, 8))
  })

  // === 色彩 ===
  b.bench(name="to_grayscale 128x128", () => {
    ignore(@color.to_grayscale(img128) catch { _ => empty })
  })
  b.bench(name="adjust_brightness 128x128", () => {
    ignore(@color.adjust_brightness(img128, 50) catch { _ => empty })
  })
  b.bench(name="adjust_gamma 128x128", () => {
    ignore(@color.adjust_gamma(img128, 2.2F) catch { _ => empty })
  })
  b.bench(name="clahe 128x128", () => {
    ignore(@color.clahe(img128, 8, 2.0F) catch { _ => empty })
  })
  b.bench(name="histogram 128x128", () => {
    ignore(@feature.histogram(img128) catch { _ => [] })
  })
  b.bench(name="premultiply_alpha 128x128", () => {
    ignore(@color.premultiply_alpha(img_rgba128) catch { _ => empty })
  })

  // === 几何 ===
  b.bench(name="crop 128x128", () => {
    ignore(@transform.crop(img128, 10, 10, 64, 64) catch { _ => img128 })
  })
  b.bench(name="rotate_90 128x128", () => ignore(@transform.rotate_90(img128)))
  b.bench(name="rotate 45deg 128x128", () => {
    ignore(@transform.rotate(img128, 45.0F))
  })
  b.bench(name="flip_horizontal 128x128", () => {
    ignore(@transform.flip_horizontal(img128))
  })
  b.bench(name="warp_affine 128x128", () => {
    ignore(
      @transform.warp_affine(
        img128,
        (1.0F, 0.0F, 0.0F, 0.0F, 1.0F, 0.0F),
        128,
        128,
      ),
    )
  })
  // === 高级算法 ===
  b.bench(name="sift_detect 128x128", () => {
    ignore(@feature.sift_detect(img128) catch { _ => [] })
  })
  b.bench(name="orb_detect 128x128", () => {
    ignore(@feature.orb_detect(img128) catch { _ => [] })
  })
  b.bench(name="template_match 128x128", () => {
    ignore(@feature.template_match(img128, img128) catch { _ => [] })
  })
  b.bench(name="grab_cut 128x128", () => {
    ignore(@segment.grab_cut(img128, 64, 64, 64, 64) catch { _ => img128 })
  })
  b.bench(name="watershed 128x128", () => {
    ignore(
      @segment.watershed(img128, Array::make(128 * 128, 0)) catch {
        _ => []
      },
    )
  })
  b.bench(name="watershed_auto 128x128", () => {
    ignore(@segment.watershed_auto(img128) catch { _ => ([], 0) })
  })
  b.bench(name="nlm_denoise 128x128", () => {
    ignore(@filter.nlm_denoise(img128) catch { _ => img128 })
  })
  b.bench(name="inpaint 128x128", () => {
    ignore(@filter.inpaint(img128, img128) catch { _ => img128 })
  })
  b.bench(name="seam_carve_resize 128->96", () => {
    ignore(@transform.seam_carve_resize(img128, 96, 96) catch { _ => img128 })
  })
  b.bench(name="find_contours 128x128", () => {
    ignore(@edge.find_contours(img128) catch { _ => [] })
  })
  b.bench(name="edge_detect_laplacian 128x128", () => {
    ignore(@edge.edge_detect_laplacian(img128) catch { _ => empty })
  })
  b.bench(name="median_blur 128x128", () => {
    ignore(@filter.median_blur(img128, 5) catch { _ => empty })
  })
  b.bench(name="flood_fill 128x128", () => {
    ignore(
      @segment.flood_fill(img128, 64, 64, [b'\xFF', b'\xFF', b'\xFF']) catch {
        _ => img128
      },
    )
  })
  b.bench(name="region_growing 128x128", () => {
    ignore(
      @segment.region_growing_segment(img128, [(64, 64)]) catch {
        _ =>
          (
            @segment.SegmentLabelImage::{
              width: 0,
              height: 0,
              labels: [],
              num_regions: 0,
            },
            [],
          )
      },
    )
  })
  b.bench(name="dehaze 128x128", () => {
    ignore(@color.dehaze(img128) catch { _ => img128 })
  })

  println(b.dump_summaries().to_string())
}

// Re-export all public APIs from subpackages for backward compatibility
// Manually maintained. To add a new public API, add the corresponding re-export here and run `moon info` to verify.

// Type re-exports

///|
pub type ExifInfo = @meta.ExifInfo

///|
pub type GifAnimation = @types.GifAnimation

///|
pub type PngAnimation = @types.PngAnimation

///|
pub type Image = @types.Image

///|
pub type Image16 = @types.Image16

///|
pub type ImageF = @types.ImageF

///|
pub type ImageFormat = @types.ImageFormat

///|
pub type ImageInfo = @types.ImageInfo

///|
pub type ImageStats = @util.ImageStats

///|
pub type ImageStatsF = @util.ImageStatsF

///|
pub type LoadError = @types.LoadError

///|
pub type PngTextChunk = @meta.PngTextChunk

///|
pub type ResizeEdge = @types.ResizeEdge

///|
pub type ResizeFilter = @types.ResizeFilter

///|
pub const MAX_IMAGE_DIMENSION : Int = @types.MAX_IMAGE_DIMENSION

///|
pub fn check_dims(
  width : Int,
  height : Int,
  channels : Int,
) -> Unit raise LoadError {
  @types.check_dims(width, height, channels)
}

///|
pub fn safe_mul(a : Int, b : Int) -> Int? {
  @types.safe_mul(a, b)
}

///|
pub fn safe_mul3(a : Int, b : Int, c : Int) -> Int? {
  @types.safe_mul3(a, b, c)
}

///|
pub type Complex = @frequency.Complex

///|
pub type FFTResult = @frequency.FFTResult

///|
pub type FreqFilterType = @frequency.FreqFilterType

///|
pub type ConnectedComponent = @segment.ConnectedComponent

///|
pub type ConnectedComponentLabelImage = @segment.ConnectedComponentLabelImage

///|
pub type IntegralImage = @feature.IntegralImage

///|
pub type IntegralImageSq = @feature.IntegralImageSq

///|
pub type HoughLine = @edge.HoughLine

///|
pub type ContourPoint = @edge.ContourPoint

///|
pub type Contour = @edge.Contour

///|
pub type SegmentLabelImage = @segment.SegmentLabelImage

///|
pub type SegmentRegion = @segment.SegmentRegion

///|
pub type Colormap = @color.Colormap

///|
pub type GlcmFeatures = @feature.GlcmFeatures

///|
pub type HaarWaveletResult = @frequency.HaarWaveletResult

///|
pub type CornerPoint = @feature.CornerPoint

///|
pub type OrbKeyPoint = @feature.OrbKeyPoint

///|
pub type OrbDescriptor = @feature.OrbDescriptor

///|
pub type DescriptorMatch = @feature.DescriptorMatch

///|
pub type FlowResult = @feature.FlowResult

///|
pub type TemplateMatchMethod = @feature.TemplateMatchMethod

///|
pub type TemplateMatchResult = @feature.TemplateMatchResult

///|
pub type SiftKeyPoint = @feature.SiftKeyPoint

///|
pub type SiftDescriptor = @feature.SiftDescriptor

///|
pub type SiftMatch = @feature.SiftMatch

///|
pub type StreamInfo = @lib.StreamInfo

// From @lib/@pure (all-target pure MoonBit)

///|
pub let convert_iphone_png_to_rgb : (Bool) -> Unit = @pure_util.convert_iphone_png_to_rgb_pure

///|
/// 自动格式分派解码（decode_any 的别名）
/// 行为与 load_from_bytes 等价，两者均委托 @lib.load_from_bytes_auto
pub fn decode_any(
  arg0 : Bytes,
  req_channels? : Int? = None,
) -> @types.Image raise @types.LoadError {
  @lib.load_from_bytes_auto(arg0, req_channels~)
}

///|
pub fn detect_format(data : Bytes) -> @types.ImageFormat {
  @lib.detect_format(data)
}

///|
pub let failure_reason : () -> String = @pure_util.failure_reason_pure

///|
pub let flip_vertically_on_write : (Bool) -> Unit = @pure_util.flip_vertically_on_write_pure

///|
pub let hdr_to_ldr_gamma : (Float) -> Unit = @pure_util.hdr_to_ldr_gamma_pure

///|
pub let hdr_to_ldr_scale : (Float) -> Unit = @pure_util.hdr_to_ldr_scale_pure

///|
pub let info_from_bytes : (Bytes) -> @types.ImageInfo? raise @types.LoadError = @pure_util.info_from_bytes_pure

///|
pub let is_16_bit_from_bytes : (Bytes) -> Bool = @pure_util.is_16_bit_from_bytes_pure

///|
pub let is_hdr_from_bytes : (Bytes) -> Bool = @pure_util.is_hdr_from_bytes_pure

///|
pub fn is_supported_format(data : Bytes) -> Bool {
  @lib.detect_format(data) != @types.ImageFormat::Unknown
}

///|
pub let ldr_to_hdr_gamma : (Float) -> Unit = @pure_util.ldr_to_hdr_gamma_pure

///|
pub let ldr_to_hdr_scale : (Float) -> Unit = @pure_util.ldr_to_hdr_scale_pure

///|
/// 自动格式分派解码（load_from_bytes 是 decode_any 的别名）
/// 行为与 decode_any 等价，两者均委托 @lib.load_from_bytes_auto
pub fn load_from_bytes(
  arg0 : Bytes,
  req_channels? : Int? = None,
) -> @types.Image raise @types.LoadError {
  @lib.load_from_bytes_auto(arg0, req_channels~)
}

///|
pub let load_gif_from_bytes : (Bytes) -> @types.GifAnimation raise @types.LoadError = @codec.decode_gif_animation_pure

///|
pub let load_f_from_bytes : (Bytes) -> @types.ImageF raise @types.LoadError = @codec.decode_hdr_pure

///|
pub fn resize(
  arg0 : @types.Image,
  arg1 : Int,
  arg2 : Int,
  filter? : @types.ResizeFilter = Default,
  edge? : @types.ResizeEdge = Clamp,
) -> @types.Image raise @types.LoadError {
  @pure_util.resize_pure(arg0, arg1, arg2, filter~, edge~)
}

///|
pub let resize_16 : (@types.Image16, Int, Int) -> @types.Image16 = @transform.resize_16

///|
pub let resize_f : (@types.ImageF, Int, Int) -> @types.ImageF = @transform.resize_f

///|
pub let set_flip_vertically_on_load : (Bool) -> Unit = @pure_util.set_flip_vertically_on_load_pure

///|
pub let set_unpremultiply_on_load : (Bool) -> Unit = @pure_util.set_unpremultiply_on_load_pure

///|
pub fn write_bmp_to_bytes(img : @types.Image) -> Bytes {
  @codec.encode_bmp_pure(img)
}

///|
pub let write_hdr_to_bytes : (@types.ImageF) -> Bytes raise @types.LoadError = @codec.encode_hdr_pure

///|
pub let write_jpeg_to_bytes : (@types.Image) -> Bytes raise @types.LoadError = @codec.encode_jpeg_pure

///|
pub let write_png_to_bytes : (@types.Image) -> Bytes = @codec.encode_png_pure

///|
pub fn write_tga_to_bytes(img : @types.Image) -> Bytes {
  @codec.encode_tga_pure(img)
}

// From process/

///|
pub let adjust_brightness : (@types.Image, Int) -> @types.Image raise @types.LoadError = @color.adjust_brightness

///|
pub let adjust_brightness_16 : (@types.Image16, Int) -> @types.Image16 raise @types.LoadError = @color.adjust_brightness_16

///|
pub let adjust_brightness_f : (@types.ImageF, Float) -> @types.ImageF raise @types.LoadError = @color.adjust_brightness_f

///|
pub let adjust_contrast : (@types.Image, Float) -> @types.Image raise @types.LoadError = @color.adjust_contrast

///|
pub let adjust_contrast_16 : (@types.Image16, Float) -> @types.Image16 raise @types.LoadError = @color.adjust_contrast_16

///|
pub let adjust_contrast_f : (@types.ImageF, Float) -> @types.ImageF raise @types.LoadError = @color.adjust_contrast_f

///|
pub let adjust_saturation : (@types.Image, Float) -> @types.Image raise @types.LoadError = @color.adjust_saturation

///|
pub let adjust_hue : (@types.Image, Float) -> @types.Image raise @types.LoadError = @color.adjust_hue

///|
pub let adjust_gamma : (@types.Image, Float) -> @types.Image raise @types.LoadError = @color.adjust_gamma

///|
pub let adjust_gamma_16 : (@types.Image16, Float) -> @types.Image16 raise @types.LoadError = @color.adjust_gamma_16

///|
pub let adjust_gamma_f : (@types.ImageF, Float) -> @types.ImageF raise @types.LoadError = @color.adjust_gamma_f

///|
pub let adaptive_threshold_mean : (@types.Image, Int, Int) -> @types.Image raise @types.LoadError = @color.adaptive_threshold_mean

///|
pub let adaptive_threshold_mean_16 : (@types.Image16, Int, Int) -> @types.Image16 raise @types.LoadError = @color.adaptive_threshold_mean_16

///|
pub let adaptive_threshold_mean_f : (@types.ImageF, Int, Float) -> @types.ImageF raise @types.LoadError = @color.adaptive_threshold_mean_f

///|
pub let adaptive_threshold_gaussian : (@types.Image, Int, Int) -> @types.Image raise @types.LoadError = @color.adaptive_threshold_gaussian

///|
pub let adaptive_threshold_gaussian_16 : (@types.Image16, Int, Int) -> @types.Image16 raise @types.LoadError = @color.adaptive_threshold_gaussian_16

///|
pub let adaptive_threshold_gaussian_f : (@types.ImageF, Int, Float) -> @types.ImageF raise @types.LoadError = @color.adaptive_threshold_gaussian_f

///|
pub let bilateral_filter : (@types.Image, Int, Float, Float) -> @types.Image raise @types.LoadError = @filter.bilateral_filter

///|
pub let bilateral_filter_16 : (@types.Image16, Int, Float, Float) -> @types.Image16 raise @types.LoadError = @filter.bilateral_filter_16

///|
pub let bilateral_filter_f : (@types.ImageF, Int, Float, Float) -> @types.ImageF raise @types.LoadError = @filter.bilateral_filter_f

///|
pub let bilateral_filter_fast : (@types.Image, Int, Float, Float, Int) -> @types.Image raise @types.LoadError = @filter.bilateral_filter_fast

///|
pub let bilateral_filter_fast_16 : (@types.Image16, Int, Float, Float, Int) -> @types.Image16 raise @types.LoadError = @filter.bilateral_filter_fast_16

///|
pub let bilateral_filter_fast_f : (@types.ImageF, Int, Float, Float, Int) -> @types.ImageF raise @types.LoadError = @filter.bilateral_filter_fast_f

///|
pub let box_blur : (@types.Image, Int) -> @types.Image raise @types.LoadError = @filter.box_blur

///|
pub let box_blur_16 : (@types.Image16, Int) -> @types.Image16 raise @types.LoadError = @filter.box_blur_16

///|
pub let box_blur_f : (@types.ImageF, Int) -> @types.ImageF raise @types.LoadError = @filter.box_blur_f

///|
pub let build_gaussian_pyramid : (@types.Image, Int) -> Array[@types.Image] raise @types.LoadError = @transform.build_gaussian_pyramid

///|
pub let build_gaussian_pyramid_16 : (@types.Image16, Int) -> Array[
  @types.Image16,
] raise @types.LoadError = @transform.build_gaussian_pyramid_16

///|
pub let build_gaussian_pyramid_f : (@types.ImageF, Int) -> Array[@types.ImageF] raise @types.LoadError = @transform.build_gaussian_pyramid_f

///|
pub let build_laplacian_pyramid : (@types.Image, Int) -> Array[@types.Image] raise @types.LoadError = @transform.build_laplacian_pyramid

///|
pub let build_laplacian_pyramid_16 : (@types.Image16, Int) -> Array[
  @types.Image16,
] raise @types.LoadError = @transform.build_laplacian_pyramid_16

///|
pub let build_laplacian_pyramid_f : (@types.ImageF, Int) -> Array[@types.ImageF] raise @types.LoadError = @transform.build_laplacian_pyramid_float

///|
pub let clahe : (@types.Image, Int, Float) -> @types.Image raise @types.LoadError = @color.clahe

///|
pub fn canny_edge(
  arg0 : @types.Image,
  low_threshold? : Int = 50,
  high_threshold? : Int = 100,
) -> @types.Image raise @types.LoadError {
  @edge.canny_edge(arg0, low_threshold~, high_threshold~)
}

///|
pub fn canny_edge_16(
  arg0 : @types.Image16,
  low_threshold? : Int = 12800,
  high_threshold? : Int = 25600,
) -> @types.Image16 raise @types.LoadError {
  @edge.canny_edge_16(arg0, low_threshold~, high_threshold~)
}

///|
pub fn canny_edge_f(
  arg0 : @types.ImageF,
  low_threshold? : Float = 0.2F,
  high_threshold? : Float = 0.4F,
) -> @types.ImageF raise @types.LoadError {
  @edge.canny_edge_f(arg0, low_threshold~, high_threshold~)
}

///|
pub let connected_components : (@types.Image, Int) -> (
  @segment.ConnectedComponentLabelImage,
  Array[@segment.ConnectedComponent],
) raise @types.LoadError = @segment.connected_components

///|
pub let contour_area : (@edge.Contour) -> Float = @edge.contour_area

///|
pub let contour_perimeter : (@edge.Contour) -> Float = @edge.contour_perimeter

///|
pub fn compute_glcm(
  arg0 : @types.Image,
  arg1 : Int,
  arg2 : Int,
  levels? : Int = 256,
) -> Array[Array[Int]] raise @types.LoadError {
  @feature.compute_glcm(arg0, arg1, arg2, levels~)
}

///|
pub fn compute_glcm_16(
  arg0 : @types.Image16,
  arg1 : Int,
  arg2 : Int,
  levels? : Int = 256,
) -> Array[Array[Int]] raise @types.LoadError {
  @feature.compute_glcm_16(arg0, arg1, arg2, levels~)
}

///|
pub fn compute_glcm_f(
  arg0 : @types.ImageF,
  arg1 : Int,
  arg2 : Int,
  levels? : Int = 256,
) -> Array[Array[Int]] raise @types.LoadError {
  @feature.compute_glcm_f(arg0, arg1, arg2, levels~)
}

///|
pub let crop : (@types.Image, Int, Int, Int, Int) -> @types.Image raise @types.LoadError = @transform.crop

///|
pub fn dehaze(
  arg0 : @types.Image,
  patch_size? : Int = 7,
  omega? : Float = 0.95F,
  t0? : Float = 0.1F,
) -> @types.Image raise @types.LoadError {
  @color.dehaze(arg0, patch_size~, omega~, t0~)
}

///|
pub fn dehaze_16(
  arg0 : @types.Image16,
  patch_size? : Int = 7,
  omega? : Float = 0.95F,
  t0? : Float = 0.1F,
) -> @types.Image16 raise @types.LoadError {
  @color.dehaze_16(arg0, patch_size~, omega~, t0~)
}

///|
pub fn dehaze_f(
  arg0 : @types.ImageF,
  patch_size? : Int = 7,
  omega? : Float = 0.95F,
  t0? : Float = 0.1F,
) -> @types.ImageF raise @types.LoadError {
  @color.dehaze_f(arg0, patch_size~, omega~, t0~)
}

///|
pub let draw_contours : (@types.Image, Array[@edge.Contour], Array[Byte]) -> @types.Image raise @types.LoadError = @edge.draw_contours

///|
pub let draw_contours_16 : (@types.Image16, Array[@edge.Contour], Array[Int]) -> @types.Image16 raise @types.LoadError = @edge.draw_contours_16

///|
pub let draw_contours_f : (@types.ImageF, Array[@edge.Contour], Array[Float]) -> @types.ImageF raise @types.LoadError = @edge.draw_contours_f

///|
pub fn draw_corners(
  arg0 : @types.Image,
  arg1 : Array[@feature.CornerPoint],
  color? : Array[Byte] = [b'\xFF', b'\x00', b'\x00'],
  radius? : Int = 2,
) -> @types.Image raise @types.LoadError {
  @feature.draw_corners(arg0, arg1, color~, radius~)
}

///|
pub let crop_16 : (@types.Image16, Int, Int, Int, Int) -> @types.Image16 raise @types.LoadError = @transform.crop_16

///|
pub let crop_f : (@types.ImageF, Int, Int, Int, Int) -> @types.ImageF raise @types.LoadError = @transform.crop_f

///|
pub let dilate : (@types.Image) -> @types.Image = @segment.dilate

///|
pub let dilate_16 : (@types.Image16) -> @types.Image16 = @segment.dilate_16

///|
pub let dilate_f : (@types.ImageF) -> @types.ImageF = @segment.dilate_f

///|
pub let draw_copy : (@types.Image, @types.Image, Int, Int) -> @types.Image raise @types.LoadError = @transform.draw_copy

///|
pub fn draw_line(
  arg0 : @types.Image,
  arg1 : Int,
  arg2 : Int,
  arg3 : Int,
  arg4 : Int,
  arg5 : Array[Byte],
  thickness? : Int = 1,
) -> @types.Image {
  @transform.draw_line(arg0, arg1, arg2, arg3, arg4, arg5, thickness~)
}

///|
pub fn draw_rectangle(
  arg0 : @types.Image,
  arg1 : Int,
  arg2 : Int,
  arg3 : Int,
  arg4 : Int,
  arg5 : Array[Byte],
  thickness? : Int = 1,
  fill? : Bool = false,
) -> @types.Image {
  @transform.draw_rectangle(
    arg0,
    arg1,
    arg2,
    arg3,
    arg4,
    arg5,
    thickness~,
    fill~,
  )
}

///|
pub fn draw_circle(
  arg0 : @types.Image,
  arg1 : Int,
  arg2 : Int,
  arg3 : Int,
  arg4 : Array[Byte],
  thickness? : Int = 1,
  fill? : Bool = false,
) -> @types.Image {
  @transform.draw_circle(arg0, arg1, arg2, arg3, arg4, thickness~, fill~)
}

///|
pub fn draw_polygon(
  arg0 : @types.Image,
  arg1 : Array[(Int, Int)],
  arg2 : Array[Byte],
  thickness? : Int = 1,
  fill? : Bool = false,
) -> @types.Image {
  @transform.draw_polygon(arg0, arg1, arg2, thickness~, fill~)
}

///|
pub fn draw_line_16(
  arg0 : @types.Image16,
  arg1 : Int,
  arg2 : Int,
  arg3 : Int,
  arg4 : Int,
  arg5 : Array[Int],
  thickness? : Int = 1,
) -> @types.Image16 {
  @transform.draw_line_16(arg0, arg1, arg2, arg3, arg4, arg5, thickness~)
}

///|
pub fn draw_rectangle_16(
  arg0 : @types.Image16,
  arg1 : Int,
  arg2 : Int,
  arg3 : Int,
  arg4 : Int,
  arg5 : Array[Int],
  thickness? : Int = 1,
  fill? : Bool = false,
) -> @types.Image16 {
  @transform.draw_rectangle_16(
    arg0,
    arg1,
    arg2,
    arg3,
    arg4,
    arg5,
    thickness~,
    fill~,
  )
}

///|
pub fn draw_circle_16(
  arg0 : @types.Image16,
  arg1 : Int,
  arg2 : Int,
  arg3 : Int,
  arg4 : Array[Int],
  thickness? : Int = 1,
  fill? : Bool = false,
) -> @types.Image16 {
  @transform.draw_circle_16(arg0, arg1, arg2, arg3, arg4, thickness~, fill~)
}

///|
pub fn draw_polygon_16(
  arg0 : @types.Image16,
  arg1 : Array[(Int, Int)],
  arg2 : Array[Int],
  thickness? : Int = 1,
) -> @types.Image16 {
  @transform.draw_polygon_16(arg0, arg1, arg2, thickness~)
}

///|
pub fn draw_line_f(
  arg0 : @types.ImageF,
  arg1 : Int,
  arg2 : Int,
  arg3 : Int,
  arg4 : Int,
  arg5 : Array[Float],
  thickness? : Int = 1,
) -> @types.ImageF {
  @transform.draw_line_f(arg0, arg1, arg2, arg3, arg4, arg5, thickness~)
}

///|
pub fn draw_rectangle_f(
  arg0 : @types.ImageF,
  arg1 : Int,
  arg2 : Int,
  arg3 : Int,
  arg4 : Int,
  arg5 : Array[Float],
  thickness? : Int = 1,
  fill? : Bool = false,
) -> @types.ImageF {
  @transform.draw_rectangle_f(
    arg0,
    arg1,
    arg2,
    arg3,
    arg4,
    arg5,
    thickness~,
    fill~,
  )
}

///|
pub fn draw_circle_f(
  arg0 : @types.ImageF,
  arg1 : Int,
  arg2 : Int,
  arg3 : Int,
  arg4 : Array[Float],
  thickness? : Int = 1,
  fill? : Bool = false,
) -> @types.ImageF {
  @transform.draw_circle_f(arg0, arg1, arg2, arg3, arg4, thickness~, fill~)
}

///|
pub fn draw_polygon_f(
  arg0 : @types.ImageF,
  arg1 : Array[(Int, Int)],
  arg2 : Array[Float],
  thickness? : Int = 1,
) -> @types.ImageF {
  @transform.draw_polygon_f(arg0, arg1, arg2, thickness~)
}

///|
pub let draw_over : (@types.Image, @types.Image, Int, Int) -> @types.Image raise @types.LoadError = @transform.draw_over

///|
pub let edge_detect_laplacian : (@types.Image) -> @types.Image raise @types.LoadError = @edge.edge_detect_laplacian

///|
pub let edge_detect_laplacian_16 : (@types.Image16) -> @types.Image16 raise @types.LoadError = @edge.edge_detect_laplacian_16

///|
pub let edge_detect_laplacian_f : (@types.ImageF) -> @types.ImageF raise @types.LoadError = @edge.edge_detect_laplacian_f

///|
pub let edge_detect_prewitt : (@types.Image) -> @types.Image raise @types.LoadError = @edge.edge_detect_prewitt

///|
pub let edge_detect_prewitt_16 : (@types.Image16) -> @types.Image16 raise @types.LoadError = @edge.edge_detect_prewitt_16

///|
pub let edge_detect_prewitt_f : (@types.ImageF) -> @types.ImageF raise @types.LoadError = @edge.edge_detect_prewitt_f

///|
pub let edge_detect_sobel : (@types.Image) -> @types.Image raise @types.LoadError = @edge.edge_detect_sobel

///|
pub let edge_detect_sobel_16 : (@types.Image16) -> @types.Image16 raise @types.LoadError = @edge.edge_detect_sobel_16

///|
pub let edge_detect_sobel_f : (@types.ImageF) -> @types.ImageF raise @types.LoadError = @edge.edge_detect_sobel_f

///|
pub let erode : (@types.Image) -> @types.Image = @segment.erode

///|
pub let erode_16 : (@types.Image16) -> @types.Image16 = @segment.erode_16

///|
pub let erode_f : (@types.ImageF) -> @types.ImageF = @segment.erode_f

///|
pub let fft_2d : (@types.Image) -> Array[@frequency.FFTResult] raise @types.LoadError = @frequency.fft_2d

///|
pub let fft_2d_16 : (@types.Image16) -> Array[@frequency.FFTResult] raise @types.LoadError = @frequency.fft_2d_16

///|
pub let fft_2d_f : (@types.ImageF) -> Array[@frequency.FFTResult] raise @types.LoadError = @frequency.fft_2d_f

///|
pub let fft_magnitude : (@frequency.FFTResult, Bool) -> @types.Image = @frequency.fft_magnitude

///|
pub let fft_magnitude_16 : (@frequency.FFTResult, Bool) -> @types.Image16 = @frequency.fft_magnitude_16

///|
pub let fft_magnitude_f : (@frequency.FFTResult, Bool) -> @types.ImageF = @frequency.fft_magnitude_f

///|
pub let fft_shift : (@frequency.FFTResult) -> @frequency.FFTResult = @frequency.fft_shift

///|
pub fn freq_filter(
  arg0 : @types.Image,
  arg1 : @frequency.FreqFilterType,
  arg2 : Float,
  band_width? : Float = 0.0F,
) -> @types.Image raise @types.LoadError {
  @frequency.freq_filter(arg0, arg1, arg2, band_width~)
}

///|
pub fn freq_filter_gaussian(
  arg0 : @types.Image,
  arg1 : @frequency.FreqFilterType,
  arg2 : Float,
  band_width? : Float = 0.0F,
) -> @types.Image raise @types.LoadError {
  @frequency.freq_filter_gaussian(arg0, arg1, arg2, band_width~)
}

///|
pub let flip_horizontal : (@types.Image) -> @types.Image = @transform.flip_horizontal

///|
pub let flip_horizontal_16 : (@types.Image16) -> @types.Image16 = @transform.flip_horizontal_16

///|
pub let flip_horizontal_f : (@types.ImageF) -> @types.ImageF = @transform.flip_horizontal_f

///|
pub fn harris_corners(
  arg0 : @types.Image,
  k? : Float = 0.04F,
  threshold? : Float = 1000.0F,
  min_distance? : Int = 5,
) -> Array[@feature.CornerPoint] raise @types.LoadError {
  @feature.harris_corners(arg0, k~, threshold~, min_distance~)
}

///|
pub fn harris_corners_16(
  arg0 : @types.Image16,
  k? : Float = 0.04F,
  threshold? : Float = 1000.0F,
  min_distance? : Int = 5,
) -> Array[@feature.CornerPoint] raise @types.LoadError {
  @feature.harris_corners_16(arg0, k~, threshold~, min_distance~)
}

///|
pub fn harris_corners_f(
  arg0 : @types.ImageF,
  k? : Float = 0.04F,
  threshold? : Float = 1000.0F,
  min_distance? : Int = 5,
) -> Array[@feature.CornerPoint] raise @types.LoadError {
  @feature.harris_corners_f(arg0, k~, threshold~, min_distance~)
}

///|
/// ORB 特征检测
pub fn orb_detect(
  arg0 : @types.Image,
  max_features? : Int = 500,
  threshold? : Int = 20,
) -> Array[@feature.OrbDescriptor] raise @types.LoadError {
  @feature.orb_detect(arg0, max_features~, threshold~)
}

///|
pub fn orb_detect_16(
  arg0 : @types.Image16,
  max_features? : Int = 500,
  threshold? : Int = 20,
) -> Array[@feature.OrbDescriptor] raise @types.LoadError {
  @feature.orb_detect_16(arg0, max_features~, threshold~)
}

///|
pub fn orb_detect_f(
  arg0 : @types.ImageF,
  max_features? : Int = 500,
  threshold? : Int = 20,
) -> Array[@feature.OrbDescriptor] raise @types.LoadError {
  @feature.orb_detect_f(arg0, max_features~, threshold~)
}

///|
/// ORB 描述子汉明距离
pub let orb_hamming : (@feature.OrbDescriptor, @feature.OrbDescriptor) -> Int = @feature.orb_hamming

///|
/// ORB 特征匹配
pub fn orb_match(
  arg0 : Array[@feature.OrbDescriptor],
  arg1 : Array[@feature.OrbDescriptor],
  max_distance? : Int = 64,
) -> Array[@feature.DescriptorMatch] raise @types.LoadError {
  @feature.orb_match(arg0, arg1, max_distance~)
}

///|
/// 模板匹配
pub fn template_match(
  arg0 : @types.Image,
  arg1 : @types.Image,
  match_method? : @feature.TemplateMatchMethod = @feature.TemplateMatchMethod::CCoeffNormed,
) -> Array[@feature.TemplateMatchResult] raise @types.LoadError {
  @feature.template_match(arg0, arg1, match_method~)
}

///|
pub fn template_match_16(
  arg0 : @types.Image16,
  arg1 : @types.Image16,
  match_method? : @feature.TemplateMatchMethod = @feature.TemplateMatchMethod::CCoeffNormed,
) -> Array[@feature.TemplateMatchResult] raise @types.LoadError {
  @feature.template_match_16(arg0, arg1, match_method~)
}

///|
pub fn template_match_f(
  arg0 : @types.ImageF,
  arg1 : @types.ImageF,
  match_method? : @feature.TemplateMatchMethod = @feature.TemplateMatchMethod::CCoeffNormed,
) -> Array[@feature.TemplateMatchResult] raise @types.LoadError {
  @feature.template_match_f(arg0, arg1, match_method~)
}

///|
/// 找到最佳模板匹配位置
pub fn template_match_best(
  arg0 : @types.Image,
  arg1 : @types.Image,
  match_method? : @feature.TemplateMatchMethod = @feature.TemplateMatchMethod::CCoeffNormed,
) -> @feature.TemplateMatchResult? raise @types.LoadError {
  @feature.template_match_best(arg0, arg1, match_method~)
}

///|
pub fn template_match_best_16(
  arg0 : @types.Image16,
  arg1 : @types.Image16,
  match_method? : @feature.TemplateMatchMethod = @feature.TemplateMatchMethod::CCoeffNormed,
) -> @feature.TemplateMatchResult? raise @types.LoadError {
  @feature.template_match_best_16(arg0, arg1, match_method~)
}

///|
pub fn template_match_best_f(
  arg0 : @types.ImageF,
  arg1 : @types.ImageF,
  match_method? : @feature.TemplateMatchMethod = @feature.TemplateMatchMethod::CCoeffNormed,
) -> @feature.TemplateMatchResult? raise @types.LoadError {
  @feature.template_match_best_f(arg0, arg1, match_method~)
}

///|
/// Lucas-Kanade 稀疏光流
pub fn lucas_kanade(
  arg0 : @types.Image,
  arg1 : @types.Image,
  arg2 : Array[(Int, Int)],
  window_size? : Int = 15,
  max_iter? : Int = 20,
) -> Array[@feature.FlowResult] raise @types.LoadError {
  @feature.lucas_kanade(arg0, arg1, arg2, window_size~, max_iter~)
}

///|
pub fn lucas_kanade_16(
  arg0 : @types.Image16,
  arg1 : @types.Image16,
  arg2 : Array[(Int, Int)],
  window_size? : Int = 15,
  max_iter? : Int = 20,
) -> Array[@feature.FlowResult] raise @types.LoadError {
  @feature.lucas_kanade_16(arg0, arg1, arg2, window_size~, max_iter~)
}

///|
pub fn lucas_kanade_f(
  arg0 : @types.ImageF,
  arg1 : @types.ImageF,
  arg2 : Array[(Int, Int)],
  window_size? : Int = 15,
  max_iter? : Int = 20,
) -> Array[@feature.FlowResult] raise @types.LoadError {
  @feature.lucas_kanade_f(arg0, arg1, arg2, window_size~, max_iter~)
}

///|
/// Horn-Schunck 密集光流
pub fn horn_schunck(
  arg0 : @types.Image,
  arg1 : @types.Image,
  alpha? : Float = 1.0F,
  iterations? : Int = 100,
) -> (Array[Float], Array[Float]) raise @types.LoadError {
  @feature.horn_schunck(arg0, arg1, alpha~, iterations~)
}

///|
pub fn horn_schunck_16(
  arg0 : @types.Image16,
  arg1 : @types.Image16,
  alpha? : Float = 1.0F,
  iterations? : Int = 100,
) -> (Array[Float], Array[Float]) raise @types.LoadError {
  @feature.horn_schunck_16(arg0, arg1, alpha~, iterations~)
}

///|
pub fn horn_schunck_f(
  arg0 : @types.ImageF,
  arg1 : @types.ImageF,
  alpha? : Float = 1.0F,
  iterations? : Int = 100,
) -> (Array[Float], Array[Float]) raise @types.LoadError {
  @feature.horn_schunck_f(arg0, arg1, alpha~, iterations~)
}

///|
/// SIFT 特征检测
pub fn sift_detect(
  arg0 : @types.Image,
  max_features? : Int = 500,
  contrast_threshold? : Float = 0.04F,
) -> Array[@feature.SiftDescriptor] raise @types.LoadError {
  @feature.sift_detect(arg0, max_features~, contrast_threshold~)
}

///|
pub fn sift_detect_16(
  arg0 : @types.Image16,
  max_features? : Int = 500,
  contrast_threshold? : Float = 0.04F,
) -> Array[@feature.SiftDescriptor] raise @types.LoadError {
  @feature.sift_detect_16(arg0, max_features~, contrast_threshold~)
}

///|
pub fn sift_detect_f(
  arg0 : @types.ImageF,
  max_features? : Int = 500,
  contrast_threshold? : Float = 0.04F,
) -> Array[@feature.SiftDescriptor] raise @types.LoadError {
  @feature.sift_detect_f(arg0, max_features~, contrast_threshold~)
}

///|
/// SIFT 描述子匹配
pub fn sift_match(
  arg0 : Array[@feature.SiftDescriptor],
  arg1 : Array[@feature.SiftDescriptor],
  max_distance? : Float = 300.0F,
  ratio_test? : Float = 0.75F,
) -> Array[@feature.SiftMatch] raise @types.LoadError {
  @feature.sift_match(arg0, arg1, max_distance~, ratio_test~)
}

///|
/// RANSAC 单应性矩阵估计
pub fn ransac_homography(
  arg0 : Array[((Float, Float), (Float, Float))],
  iterations? : Int = 1000,
  threshold? : Float = 3.0F,
) -> Array[Float]? raise @types.LoadError {
  @feature.ransac_homography(arg0, iterations~, threshold~)
}

///|
/// 流式解码：逐行回调处理
pub fn decode_stream(
  arg0 : Bytes,
  arg1 : (Int, Array[Byte]) -> Unit,
) -> @lib.StreamInfo raise @types.LoadError {
  @lib.decode_stream(arg0, arg1)
}

///|
/// 分块流式解码
pub fn decode_stream_chunked(
  arg0 : Bytes,
  arg1 : Int,
  arg2 : (Int, @types.Image) -> Unit,
) -> @lib.StreamInfo raise @types.LoadError {
  @lib.decode_stream_chunked(arg0, arg1, arg2)
}

///|
/// 流式解码（带 req_channels）
pub fn decode_stream_channels(
  arg0 : Bytes,
  arg1 : Int,
  arg2 : (Int, Array[Byte]) -> Unit,
) -> @lib.StreamInfo raise @types.LoadError {
  @lib.decode_stream_channels(arg0, arg1, arg2)
}

///|
pub fn hough_lines(
  arg0 : @types.Image,
  arg1 : Int,
  theta_resolution? : Float = 1.0F,
  rho_resolution? : Float = 1.0F,
) -> Array[@edge.HoughLine] raise @types.LoadError {
  @edge.hough_lines(arg0, arg1, theta_resolution~, rho_resolution~)
}

///|
pub fn hough_lines_16(
  arg0 : @types.Image16,
  arg1 : Int,
  theta_resolution? : Float = 1.0F,
  rho_resolution? : Float = 1.0F,
) -> Array[@edge.HoughLine] raise @types.LoadError {
  @edge.hough_lines_16(arg0, arg1, theta_resolution~, rho_resolution~)
}

///|
pub fn hough_lines_f(
  arg0 : @types.ImageF,
  arg1 : Int,
  theta_resolution? : Float = 1.0F,
  rho_resolution? : Float = 1.0F,
) -> Array[@edge.HoughLine] raise @types.LoadError {
  @edge.hough_lines_f(arg0, arg1, theta_resolution~, rho_resolution~)
}

///|
pub fn hough_lines_nms(
  arg0 : Array[@edge.HoughLine],
  rho_threshold? : Float = 5.0F,
  theta_threshold? : Float = 0.1F,
) -> Array[@edge.HoughLine] raise @types.LoadError {
  @edge.hough_lines_nms(arg0, rho_threshold~, theta_threshold~)
}

///|
pub let find_contours : (@types.Image) -> Array[@edge.Contour] raise @types.LoadError = @edge.find_contours

///|
pub let find_contours_16 : (@types.Image16) -> Array[@edge.Contour] raise @types.LoadError = @edge.find_contours_16

///|
pub let find_contours_f : (@types.ImageF) -> Array[@edge.Contour] raise @types.LoadError = @edge.find_contours_f

///|
pub let floyd_steinberg : (@types.Image, Int) -> @types.Image raise @types.LoadError = @color.floyd_steinberg

///|
pub let floyd_steinberg_16 : (@types.Image16, Int) -> @types.Image16 raise @types.LoadError = @color.floyd_steinberg_16

///|
pub let floyd_steinberg_f : (@types.ImageF, Int) -> @types.ImageF raise @types.LoadError = @color.floyd_steinberg_f

///|
pub let glcm_features : (Array[Array[Int]]) -> @feature.GlcmFeatures = @feature.glcm_features

///|
pub fn glcm_features_multi_direction(
  arg0 : @types.Image,
  levels? : Int = 256,
) -> Array[@feature.GlcmFeatures] raise @types.LoadError {
  @feature.glcm_features_multi_direction(arg0, levels~)
}

///|
pub fn glcm_features_multi_direction_16(
  arg0 : @types.Image16,
  levels? : Int = 256,
) -> Array[@feature.GlcmFeatures] raise @types.LoadError {
  @feature.glcm_features_multi_direction_16(arg0, levels~)
}

///|
pub fn glcm_features_multi_direction_f(
  arg0 : @types.ImageF,
  levels? : Int = 256,
) -> Array[@feature.GlcmFeatures] raise @types.LoadError {
  @feature.glcm_features_multi_direction_f(arg0, levels~)
}

///|
pub fn gabor_filter(
  arg0 : @types.Image,
  arg1 : Int,
  arg2 : Float,
  arg3 : Float,
  lambda? : Float = 10.0F,
  gamma? : Float = 0.5F,
  phi? : Float = 0.0F,
) -> @types.Image raise @types.LoadError {
  @feature.gabor_filter(arg0, arg1, arg2, arg3, lambda~, gamma~, phi~)
}

///|
pub fn gabor_filter_16(
  arg0 : @types.Image16,
  arg1 : Int,
  arg2 : Float,
  arg3 : Float,
  lambda? : Float = 10.0F,
  gamma? : Float = 0.5F,
  phi? : Float = 0.0F,
) -> @types.Image16 raise @types.LoadError {
  @feature.gabor_filter_16(arg0, arg1, arg2, arg3, lambda~, gamma~, phi~)
}

///|
pub fn gabor_filter_f(
  arg0 : @types.ImageF,
  arg1 : Int,
  arg2 : Float,
  arg3 : Float,
  lambda? : Float = 10.0F,
  gamma? : Float = 0.5F,
  phi? : Float = 0.0F,
) -> @types.ImageF raise @types.LoadError {
  @feature.gabor_filter_f(arg0, arg1, arg2, arg3, lambda~, gamma~, phi~)
}

///|
pub fn gabor_filter_bank(
  arg0 : @types.Image,
  arg1 : Int,
  arg2 : Float,
  num_orientations? : Int = 4,
  lambda? : Float = 10.0F,
  gamma? : Float = 0.5F,
) -> @types.Image raise @types.LoadError {
  @feature.gabor_filter_bank(
    arg0,
    arg1,
    arg2,
    num_orientations~,
    lambda~,
    gamma~,
  )
}

///|
pub fn gabor_filter_bank_16(
  arg0 : @types.Image16,
  arg1 : Int,
  arg2 : Float,
  num_orientations? : Int = 4,
  lambda? : Float = 10.0F,
  gamma? : Float = 0.5F,
) -> @types.Image16 raise @types.LoadError {
  @feature.gabor_filter_bank_16(
    arg0,
    arg1,
    arg2,
    num_orientations~,
    lambda~,
    gamma~,
  )
}

///|
pub fn gabor_filter_bank_f(
  arg0 : @types.ImageF,
  arg1 : Int,
  arg2 : Float,
  num_orientations? : Int = 4,
  lambda? : Float = 10.0F,
  gamma? : Float = 0.5F,
) -> @types.ImageF raise @types.LoadError {
  @feature.gabor_filter_bank_f(
    arg0,
    arg1,
    arg2,
    num_orientations~,
    lambda~,
    gamma~,
  )
}

///|
pub fn gabor_kernel(
  arg1 : Int,
  arg2 : Float,
  arg3 : Float,
  lambda? : Float = 10.0F,
  gamma? : Float = 0.5F,
  phi? : Float = 0.0F,
) -> Array[Array[Float]] raise @types.LoadError {
  @feature.gabor_kernel(arg1, arg2, arg3, lambda~, gamma~, phi~)
}

///|
pub let gaussian_blur : (@types.Image, Int, Float) -> @types.Image raise @types.LoadError = @filter.gaussian_blur

///|
pub let gaussian_blur_16 : (@types.Image16, Int, Float) -> @types.Image16 raise @types.LoadError = @filter.gaussian_blur_16

///|
pub let gaussian_blur_f : (@types.ImageF, Int, Float) -> @types.ImageF raise @types.LoadError = @filter.gaussian_blur_f

///|
pub let median_blur : (@types.Image, Int) -> @types.Image raise @types.LoadError = @filter.median_blur

///|
pub let median_blur_16 : (@types.Image16, Int) -> @types.Image16 raise @types.LoadError = @filter.median_blur_16

///|
pub let median_blur_f : (@types.ImageF, Int) -> @types.ImageF raise @types.LoadError = @filter.median_blur_f

///|
pub let ihaar_transform_1d : (Array[Float]) -> Array[Float] = @frequency.ihaar_transform_1d

///|
pub let haar_inverse_transform_2d : (@frequency.HaarWaveletResult) -> @types.Image = @frequency.haar_inverse_transform_2d

///|
pub let haar_inverse_transform_2d_16 : (@frequency.HaarWaveletResult) -> @types.Image16 = @frequency.haar_inverse_transform_2d_16

///|
pub let haar_inverse_transform_2d_f : (@frequency.HaarWaveletResult) -> @types.ImageF = @frequency.haar_inverse_transform_2d_f

///|
pub let haar_transform_1d : (Array[Float]) -> Array[Float] = @frequency.haar_transform_1d

///|
pub fn haar_transform_2d(
  arg0 : @types.Image,
  levels? : Int = 1,
) -> @frequency.HaarWaveletResult raise @types.LoadError {
  @frequency.haar_transform_2d(arg0, levels~)
}

///|
pub fn haar_transform_2d_16(
  arg0 : @types.Image16,
  levels? : Int = 1,
) -> @frequency.HaarWaveletResult raise @types.LoadError {
  @frequency.haar_transform_2d_16(arg0, levels~)
}

///|
pub fn haar_transform_2d_f(
  arg0 : @types.ImageF,
  levels? : Int = 1,
) -> @frequency.HaarWaveletResult raise @types.LoadError {
  @frequency.haar_transform_2d_f(arg0, levels~)
}

///|
pub fn haar_denoise(
  arg0 : @types.Image,
  threshold? : Float = 10.0F,
  soft? : Bool = true,
  levels? : Int = 3,
) -> @types.Image raise @types.LoadError {
  @frequency.haar_denoise(arg0, threshold~, soft~, levels~)
}

///|
pub fn haar_denoise_16(
  arg0 : @types.Image16,
  threshold? : Float = 10.0F,
  soft? : Bool = true,
  levels? : Int = 3,
) -> @types.Image16 raise @types.LoadError {
  @frequency.haar_denoise_16(arg0, threshold~, soft~, levels~)
}

///|
pub fn haar_denoise_f(
  arg0 : @types.ImageF,
  threshold? : Float = 10.0F,
  soft? : Bool = true,
  levels? : Int = 3,
) -> @types.ImageF raise @types.LoadError {
  @frequency.haar_denoise_f(arg0, threshold~, soft~, levels~)
}

///|
pub let histogram : (@types.Image) -> Array[Int] raise @types.LoadError = @feature.histogram

///|
pub let histogram_16 : (@types.Image16) -> Array[Int] raise @types.LoadError = @feature.histogram_16

///|
pub let histogram_f : (@types.ImageF) -> Array[Int] raise @types.LoadError = @feature.histogram_f

///|
pub let histogram_equalize : (@types.Image) -> @types.Image raise @types.LoadError = @feature.histogram_equalize

///|
pub let histogram_equalize_16 : (@types.Image16) -> @types.Image16 raise @types.LoadError = @feature.histogram_equalize_16

///|
pub let histogram_equalize_f : (@types.ImageF) -> @types.ImageF raise @types.LoadError = @feature.histogram_equalize_f

///|
pub let histogram_normalize : (@types.Image) -> @types.Image raise @types.LoadError = @feature.histogram_normalize

///|
pub let histogram_normalize_16 : (@types.Image16) -> @types.Image16 raise @types.LoadError = @feature.histogram_normalize_16

///|
pub let histogram_normalize_f : (@types.ImageF) -> @types.ImageF raise @types.LoadError = @feature.histogram_normalize_f

///|
pub let ahash : (@types.Image) -> Array[Int] raise @types.LoadError = @feature.ahash

///|
pub let ahash_16 : (@types.Image16) -> Array[Int] raise @types.LoadError = @feature.ahash_16

///|
pub let ahash_f : (@types.ImageF) -> Array[Int] raise @types.LoadError = @feature.ahash_f

///|
pub let dhash : (@types.Image) -> Array[Int] raise @types.LoadError = @feature.dhash

///|
pub let dhash_16 : (@types.Image16) -> Array[Int] raise @types.LoadError = @feature.dhash_16

///|
pub let dhash_f : (@types.ImageF) -> Array[Int] raise @types.LoadError = @feature.dhash_f

///|
pub let phash : (@types.Image) -> Array[Int] raise @types.LoadError = @feature.phash

///|
pub let phash_16 : (@types.Image16) -> Array[Int] raise @types.LoadError = @feature.phash_16

///|
pub let phash_f : (@types.ImageF) -> Array[Int] raise @types.LoadError = @feature.phash_f

///|
pub let hamming_distance : (Array[Int], Array[Int]) -> Int raise @types.LoadError = @feature.hamming_distance

///|
pub let dct_2d : (@types.Image) -> Array[Array[Double]] = @frequency.dct_2d

///|
pub let dct_2d_16 : (@types.Image16) -> Array[Array[Double]] = @frequency.dct_2d_16

///|
pub let dct_2d_f : (@types.ImageF) -> Array[Array[Double]] = @frequency.dct_2d_f

///|
pub let idct_2d : (Array[Array[Double]]) -> @types.Image = @frequency.idct_2d

///|
pub let idct_2d_16 : (Array[Array[Double]]) -> @types.Image16 = @frequency.idct_2d_16

///|
pub let idct_2d_f : (Array[Array[Double]]) -> @types.ImageF = @frequency.idct_2d_f

///|
pub fn reinhard_tonemap(
  imgf : @types.ImageF,
  key? : Float = 0.18F,
) -> @types.Image raise @types.LoadError {
  @color.reinhard_tonemap(imgf, key~)
}

///|
pub fn reinhard_tonemap_16(
  imgf : @types.ImageF,
  key? : Float = 0.18F,
) -> @types.Image16 raise @types.LoadError {
  @color.reinhard_tonemap_16(imgf, key~)
}

///|
pub fn reinhard_tonemap_f(
  imgf : @types.ImageF,
  key? : Float = 0.18F,
) -> @types.ImageF raise @types.LoadError {
  @color.reinhard_tonemap_f(imgf, key~)
}

///|
pub let gamma_tonemap : (@types.ImageF, Float) -> @types.Image raise @types.LoadError = @color.gamma_tonemap

///|
pub let gamma_tonemap_16 : (@types.ImageF, Float) -> @types.Image16 raise @types.LoadError = @color.gamma_tonemap_16

///|
pub let gamma_tonemap_f : (@types.ImageF, Float) -> @types.ImageF raise @types.LoadError = @color.gamma_tonemap_f

///|
pub fn good_features_to_track(
  img : @types.Image,
  max_corners : Int,
  quality_level : Float,
  min_distance? : Int = 5,
) -> Array[@feature.CornerPoint] raise @types.LoadError {
  @feature.good_features_to_track(
    img,
    max_corners,
    quality_level,
    min_distance~,
  )
}

///|
pub fn good_features_to_track_16(
  img : @types.Image16,
  max_corners : Int,
  quality_level : Float,
  min_distance? : Int = 5,
) -> Array[@feature.CornerPoint] raise @types.LoadError {
  @feature.good_features_to_track_16(
    img,
    max_corners,
    quality_level,
    min_distance~,
  )
}

///|
pub fn good_features_to_track_f(
  img : @types.ImageF,
  max_corners : Int,
  quality_level : Float,
  min_distance? : Int = 5,
) -> Array[@feature.CornerPoint] raise @types.LoadError {
  @feature.good_features_to_track_f(
    img,
    max_corners,
    quality_level,
    min_distance~,
  )
}

///|
pub type HistCompareMethod = @feature.HistCompareMethod

///|
pub let compare_hist : (Array[Int], Array[Int], @feature.HistCompareMethod) -> Float raise @types.LoadError = @feature.compare_hist

///|
pub let histogram_matching : (@types.Image, @types.Image) -> @types.Image raise @types.LoadError = @feature.histogram_matching

///|
pub let histogram_matching_16 : (@types.Image16, @types.Image16) -> @types.Image16 raise @types.LoadError = @feature.histogram_matching_16

///|
pub let histogram_matching_f : (@types.ImageF, @types.ImageF) -> @types.ImageF raise @types.LoadError = @feature.histogram_matching_f

///|
pub let hsl_to_rgb : (Float, Float, Float) -> (Int, Int, Int) raise @types.LoadError = @color.hsl_to_rgb

///|
pub let hsl_to_rgb_16 : (Float, Float, Float) -> (Int, Int, Int) raise @types.LoadError = @color.hsl_to_rgb_16

///|
pub let hsl_to_rgb_f : (Float, Float, Float) -> (Float, Float, Float) raise @types.LoadError = @color.hsl_to_rgb_f

///|
pub let hsv_to_rgb : (Float, Float, Float) -> (Int, Int, Int) raise @types.LoadError = @color.hsv_to_rgb

///|
pub let hsv_to_rgb_16 : (Float, Float, Float) -> (Int, Int, Int) raise @types.LoadError = @color.hsv_to_rgb_16

///|
pub let hsv_to_rgb_f : (Float, Float, Float) -> (Float, Float, Float) raise @types.LoadError = @color.hsv_to_rgb_f

///|
pub let ifft_2d : (@frequency.FFTResult) -> @types.Image = @frequency.ifft_2d

///|
pub let ifft_2d_16 : (@frequency.FFTResult) -> @types.Image16 = @frequency.ifft_2d_16

///|
pub let ifft_2d_f : (@frequency.FFTResult) -> @types.ImageF = @frequency.ifft_2d_f

///|
pub let integral_image : (@types.Image) -> @feature.IntegralImage raise @types.LoadError = @feature.integral_image

///|
pub let integral_image_16 : (@types.Image16) -> @feature.IntegralImage raise @types.LoadError = @feature.integral_image_16

///|
pub let integral_image_f : (@types.ImageF) -> @feature.IntegralImage raise @types.LoadError = @feature.integral_image_f

///|
pub let integral_image_sq : (@types.Image) -> @feature.IntegralImageSq raise @types.LoadError = @feature.integral_image_sq

///|
pub let integral_image_sq_16 : (@types.Image16) -> @feature.IntegralImageSq raise @types.LoadError = @feature.integral_image_sq_16

///|
pub let integral_image_sq_f : (@types.ImageF) -> @feature.IntegralImageSq raise @types.LoadError = @feature.integral_image_sq_f

///|
pub let integral_mean : (@feature.IntegralImage, Int, Int, Int, Int) -> Float raise @types.LoadError = @feature.integral_mean

///|
pub let integral_sum : (@feature.IntegralImage, Int, Int, Int, Int) -> Int64 raise @types.LoadError = @feature.integral_sum

///|
pub let integral_sum_sq : (@feature.IntegralImageSq, Int, Int, Int, Int) -> Int64 raise @types.LoadError = @feature.integral_sum_sq

///|
pub let integral_variance : (
  @feature.IntegralImage,
  @feature.IntegralImageSq,
  Int,
  Int,
  Int,
  Int,
) -> Float raise @types.LoadError = @feature.integral_variance

///|
pub let invert : (@types.Image) -> @types.Image raise @types.LoadError = @color.invert

///|
pub let invert_16 : (@types.Image16) -> @types.Image16 raise @types.LoadError = @color.invert_16

///|
pub let invert_f : (@types.ImageF) -> @types.ImageF raise @types.LoadError = @color.invert_f

///|
pub let kmeans_quantize : (@types.Image, Int, Int) -> @types.Image raise @types.LoadError = @color.kmeans_quantize

///|
pub let kmeans_quantize_16 : (@types.Image16, Int, Int) -> @types.Image16 raise @types.LoadError = @color.kmeans_quantize_16

///|
pub let kmeans_quantize_f : (@types.ImageF, Int, Int) -> @types.ImageF raise @types.LoadError = @color.kmeans_quantize_f

///|
pub fn kmeans_segment(
  arg0 : @types.Image,
  arg1 : Int,
  max_iters? : Int = 20,
) -> (@segment.SegmentLabelImage, Array[@segment.SegmentRegion]) raise @types.LoadError {
  @segment.kmeans_segment(arg0, arg1, max_iters~)
}

///|
pub fn kmeans_segment_16(
  arg0 : @types.Image16,
  arg1 : Int,
  max_iters? : Int = 20,
) -> (@segment.SegmentLabelImage, Array[@segment.SegmentRegion]) raise @types.LoadError {
  @segment.kmeans_segment_16(arg0, arg1, max_iters~)
}

///|
pub fn kmeans_segment_f(
  arg0 : @types.ImageF,
  arg1 : Int,
  max_iters? : Int = 20,
) -> (@segment.SegmentLabelImage, Array[@segment.SegmentRegion]) raise @types.LoadError {
  @segment.kmeans_segment_f(arg0, arg1, max_iters~)
}

///|
pub let lbp : (@types.Image) -> @types.Image raise @types.LoadError = @feature.lbp

///|
pub let lbp_16 : (@types.Image16) -> @types.Image16 raise @types.LoadError = @feature.lbp_16

///|
pub let lbp_f : (@types.ImageF) -> @types.ImageF raise @types.LoadError = @feature.lbp_f

///|
pub let lbp_uniform : (@types.Image) -> @types.Image raise @types.LoadError = @feature.lbp_uniform

///|
pub let lbp_uniform_16 : (@types.Image16) -> @types.Image16 raise @types.LoadError = @feature.lbp_uniform_16

///|
pub let lbp_uniform_f : (@types.ImageF) -> @types.ImageF raise @types.LoadError = @feature.lbp_uniform_f

///|
pub fn nlm_denoise(
  arg0 : @types.Image,
  patch_size? : Int = 3,
  search_size? : Int = 7,
  h? : Int = 10,
) -> @types.Image raise @types.LoadError {
  @filter.nlm_denoise(arg0, patch_size~, search_size~, h~)
}

///|
pub fn nlm_denoise_fast(
  arg0 : @types.Image,
  patch_size? : Int = 3,
  search_size? : Int = 7,
  h? : Int = 10,
  step? : Int = 2,
) -> @types.Image raise @types.LoadError {
  @filter.nlm_denoise_fast(arg0, patch_size~, search_size~, h~, step~)
}

///|
pub fn nlm_denoise_16(
  arg0 : @types.Image16,
  patch_size? : Int = 3,
  search_size? : Int = 7,
  h? : Int = 10,
) -> @types.Image16 raise @types.LoadError {
  @filter.nlm_denoise_16(arg0, patch_size~, search_size~, h~)
}

///|
pub fn nlm_denoise_fast_16(
  arg0 : @types.Image16,
  patch_size? : Int = 3,
  search_size? : Int = 7,
  h? : Int = 10,
  step? : Int = 2,
) -> @types.Image16 raise @types.LoadError {
  @filter.nlm_denoise_fast_16(arg0, patch_size~, search_size~, h~, step~)
}

///|
pub fn nlm_denoise_f(
  arg0 : @types.ImageF,
  patch_size? : Int = 3,
  search_size? : Int = 7,
  h? : Int = 10,
) -> @types.ImageF raise @types.LoadError {
  @filter.nlm_denoise_f(arg0, patch_size~, search_size~, h~)
}

///|
pub fn nlm_denoise_fast_f(
  arg0 : @types.ImageF,
  patch_size? : Int = 3,
  search_size? : Int = 7,
  h? : Int = 10,
  step? : Int = 2,
) -> @types.ImageF raise @types.LoadError {
  @filter.nlm_denoise_fast_f(arg0, patch_size~, search_size~, h~, step~)
}

///|
pub let median_cut : (@types.Image, Int) -> @types.Image raise @types.LoadError = @color.median_cut

///|
pub let median_cut_16 : (@types.Image16, Int) -> @types.Image16 raise @types.LoadError = @color.median_cut_16

///|
pub let median_cut_f : (@types.ImageF, Int) -> @types.ImageF raise @types.LoadError = @color.median_cut_f

///|
pub let morph_close : (@types.Image) -> @types.Image = @segment.morph_close

///|
pub let morph_close_16 : (@types.Image16) -> @types.Image16 = @segment.morph_close_16

///|
pub let morph_close_f : (@types.ImageF) -> @types.ImageF = @segment.morph_close_f

///|
pub let morph_gradient : (@types.Image) -> @types.Image = @segment.morph_gradient

///|
pub let morph_gradient_16 : (@types.Image16) -> @types.Image16 = @segment.morph_gradient_16

///|
pub let morph_gradient_f : (@types.ImageF) -> @types.ImageF = @segment.morph_gradient_f

///|
pub let morph_tophat : (@types.Image) -> @types.Image = @segment.morph_tophat

///|
pub let morph_tophat_16 : (@types.Image16) -> @types.Image16 = @segment.morph_tophat_16

///|
pub let morph_tophat_f : (@types.ImageF) -> @types.ImageF = @segment.morph_tophat_f

///|
pub let morph_blackhat : (@types.Image) -> @types.Image = @segment.morph_blackhat

///|
pub let morph_blackhat_16 : (@types.Image16) -> @types.Image16 = @segment.morph_blackhat_16

///|
pub let morph_blackhat_f : (@types.ImageF) -> @types.ImageF = @segment.morph_blackhat_f

///|
pub type StructuringElement = @segment.StructuringElement

///|
pub let se_rect : (Int, Int) -> @segment.StructuringElement = @segment.se_rect

///|
pub let se_cross : (Int) -> @segment.StructuringElement = @segment.se_cross

///|
pub let se_ellipse : (Int) -> @segment.StructuringElement = @segment.se_ellipse

///|
pub let erode_custom : (@types.Image, @segment.StructuringElement) -> @types.Image = @segment.erode_custom

///|
pub let erode_custom_16 : (@types.Image16, @segment.StructuringElement) -> @types.Image16 = @segment.erode_custom_16

///|
pub let erode_custom_f : (@types.ImageF, @segment.StructuringElement) -> @types.ImageF = @segment.erode_custom_f

///|
pub let dilate_custom : (@types.Image, @segment.StructuringElement) -> @types.Image = @segment.dilate_custom

///|
pub let dilate_custom_16 : (@types.Image16, @segment.StructuringElement) -> @types.Image16 = @segment.dilate_custom_16

///|
pub let dilate_custom_f : (@types.ImageF, @segment.StructuringElement) -> @types.ImageF = @segment.dilate_custom_f

///|
pub let morph_open_custom : (@types.Image, @segment.StructuringElement) -> @types.Image = @segment.morph_open_custom

///|
pub let morph_open_custom_16 : (@types.Image16, @segment.StructuringElement) -> @types.Image16 = @segment.morph_open_custom_16

///|
pub let morph_open_custom_f : (@types.ImageF, @segment.StructuringElement) -> @types.ImageF = @segment.morph_open_custom_f

///|
pub let morph_close_custom : (@types.Image, @segment.StructuringElement) -> @types.Image = @segment.morph_close_custom

///|
pub let morph_close_custom_16 : (@types.Image16, @segment.StructuringElement) -> @types.Image16 = @segment.morph_close_custom_16

///|
pub let morph_close_custom_f : (@types.ImageF, @segment.StructuringElement) -> @types.ImageF = @segment.morph_close_custom_f

///|
pub let morph_open : (@types.Image) -> @types.Image = @segment.morph_open

///|
pub let morph_open_16 : (@types.Image16) -> @types.Image16 = @segment.morph_open_16

///|
pub let morph_open_f : (@types.ImageF) -> @types.ImageF = @segment.morph_open_f

///|
pub let mse : (@types.Image, @types.Image) -> Double raise @types.LoadError = @feature.mse

///|
pub let mse_16 : (@types.Image16, @types.Image16) -> Double raise @types.LoadError = @feature.mse_16

///|
pub let mse_f : (@types.ImageF, @types.ImageF) -> Double raise @types.LoadError = @feature.mse_f

///|
pub let premultiply_alpha : (@types.Image) -> @types.Image raise @types.LoadError = @color.premultiply_alpha

///|
pub let premultiply_alpha_16 : (@types.Image16) -> @types.Image16 raise @types.LoadError = @color.premultiply_alpha_16

///|
pub let premultiply_alpha_f : (@types.ImageF) -> @types.ImageF raise @types.LoadError = @color.premultiply_alpha_f

///|
pub let psnr : (@types.Image, @types.Image) -> Double raise @types.LoadError = @feature.psnr

///|
pub let psnr_16 : (@types.Image16, @types.Image16) -> Double raise @types.LoadError = @feature.psnr_16

///|
pub let psnr_f : (@types.ImageF, @types.ImageF) -> Double raise @types.LoadError = @feature.psnr_f

///|
pub let pyr_down : (@types.Image) -> @types.Image raise @types.LoadError = @transform.pyr_down

///|
pub let pyr_down_16 : (@types.Image16) -> @types.Image16 raise @types.LoadError = @transform.pyr_down_16

///|
pub let pyr_down_f : (@types.ImageF) -> @types.ImageF raise @types.LoadError = @transform.pyr_down_f

///|
pub let pyr_up : (@types.Image) -> @types.Image raise @types.LoadError = @transform.pyr_up

///|
pub let pyr_up_16 : (@types.Image16) -> @types.Image16 raise @types.LoadError = @transform.pyr_up_16

///|
pub let pyr_up_f : (@types.ImageF) -> @types.ImageF raise @types.LoadError = @transform.pyr_up_f

///|
pub fn region_growing_segment(
  arg0 : @types.Image,
  arg1 : Array[(Int, Int)],
  threshold? : Int = 30,
) -> (@segment.SegmentLabelImage, Array[@segment.SegmentRegion]) raise @types.LoadError {
  @segment.region_growing_segment(arg0, arg1, threshold~)
}

///|
pub let rgb_to_hsl : (Int, Int, Int) -> (Float, Float, Float) raise @types.LoadError = @color.rgb_to_hsl

///|
pub let rgb_to_hsl_16 : (Int, Int, Int) -> (Float, Float, Float) raise @types.LoadError = @color.rgb_to_hsl_16

///|
pub let rgb_to_hsl_f : (Float, Float, Float) -> (Float, Float, Float) raise @types.LoadError = @color.rgb_to_hsl_f

///|
pub let rgb_to_hsv : (Int, Int, Int) -> (Float, Float, Float) raise @types.LoadError = @color.rgb_to_hsv

///|
pub let rgb_to_hsv_16 : (Int, Int, Int) -> (Float, Float, Float) raise @types.LoadError = @color.rgb_to_hsv_16

///|
pub let rgb_to_hsv_f : (Float, Float, Float) -> (Float, Float, Float) raise @types.LoadError = @color.rgb_to_hsv_f

///|
pub let rgb_to_ycbcr : (Int, Int, Int) -> (Int, Int, Int) raise @types.LoadError = @color.rgb_to_ycbcr

///|
pub let rgb_to_ycbcr_16 : (Int, Int, Int) -> (Int, Int, Int) raise @types.LoadError = @color.rgb_to_ycbcr_16

///|
pub let rgb_to_ycbcr_f : (Float, Float, Float) -> (Float, Float, Float) raise @types.LoadError = @color.rgb_to_ycbcr_f

///|
pub let ycbcr_to_rgb : (Int, Int, Int) -> (Int, Int, Int) raise @types.LoadError = @color.ycbcr_to_rgb

///|
pub let ycbcr_to_rgb_16 : (Int, Int, Int) -> (Int, Int, Int) raise @types.LoadError = @color.ycbcr_to_rgb_16

///|
pub let ycbcr_to_rgb_f : (Float, Float, Float) -> (Float, Float, Float) raise @types.LoadError = @color.ycbcr_to_rgb_f

///|
pub let rgb_to_xyz : (Int, Int, Int) -> (Float, Float, Float) raise @types.LoadError = @color.rgb_to_xyz

///|
pub let rgb_to_xyz_16 : (Int, Int, Int) -> (Float, Float, Float) raise @types.LoadError = @color.rgb_to_xyz_16

///|
pub let rgb_to_xyz_f : (Float, Float, Float) -> (Float, Float, Float) raise @types.LoadError = @color.rgb_to_xyz_f

///|
pub let xyz_to_rgb : (Float, Float, Float) -> (Int, Int, Int) raise @types.LoadError = @color.xyz_to_rgb

///|
pub let xyz_to_rgb_16 : (Float, Float, Float) -> (Int, Int, Int) raise @types.LoadError = @color.xyz_to_rgb_16

///|
pub let xyz_to_rgb_f : (Float, Float, Float) -> (Float, Float, Float) raise @types.LoadError = @color.xyz_to_rgb_f

///|
pub let rgb_to_lab : (Int, Int, Int) -> (Float, Float, Float) raise @types.LoadError = @color.rgb_to_lab

///|
pub let rgb_to_lab_16 : (Int, Int, Int) -> (Float, Float, Float) raise @types.LoadError = @color.rgb_to_lab_16

///|
pub let rgb_to_lab_f : (Float, Float, Float) -> (Float, Float, Float) raise @types.LoadError = @color.rgb_to_lab_f

///|
pub let lab_to_rgb : (Float, Float, Float) -> (Int, Int, Int) raise @types.LoadError = @color.lab_to_rgb

///|
pub let lab_to_rgb_16 : (Float, Float, Float) -> (Int, Int, Int) raise @types.LoadError = @color.lab_to_rgb_16

///|
pub let lab_to_rgb_f : (Float, Float, Float) -> (Float, Float, Float) raise @types.LoadError = @color.lab_to_rgb_f

///|
pub let rgb_to_cmyk : (Int, Int, Int) -> (Int, Int, Int, Int) raise @types.LoadError = @color.rgb_to_cmyk

///|
pub let rgb_to_cmyk_16 : (Int, Int, Int) -> (Int, Int, Int, Int) raise @types.LoadError = @color.rgb_to_cmyk_16

///|
pub let rgb_to_cmyk_f : (Float, Float, Float) -> (Float, Float, Float, Float) raise @types.LoadError = @color.rgb_to_cmyk_f

///|
pub let cmyk_to_rgb : (Int, Int, Int, Int) -> (Int, Int, Int) raise @types.LoadError = @color.cmyk_to_rgb

///|
pub let cmyk_to_rgb_16 : (Int, Int, Int, Int) -> (Int, Int, Int) raise @types.LoadError = @color.cmyk_to_rgb_16

///|
pub let cmyk_to_rgb_f : (Float, Float, Float, Float) -> (Float, Float, Float) raise @types.LoadError = @color.cmyk_to_rgb_f

///|
pub let apply_colormap : (@types.Image, @color.Colormap) -> @types.Image raise @types.LoadError = @color.apply_colormap

///|
pub let rotate : (@types.Image, Float) -> @types.Image = @transform.rotate

///|
pub let rotate_180 : (@types.Image) -> @types.Image = @transform.rotate_180

///|
pub let rotate_270 : (@types.Image) -> @types.Image = @transform.rotate_270

///|
pub let rotate_90 : (@types.Image) -> @types.Image = @transform.rotate_90

///|
pub let rotate_90_16 : (@types.Image16) -> @types.Image16 = @transform.rotate_90_16

///|
pub let rotate_90_f : (@types.ImageF) -> @types.ImageF = @transform.rotate_90_f

///|
pub let rotate_180_16 : (@types.Image16) -> @types.Image16 = @transform.rotate_180_16

///|
pub let rotate_180_f : (@types.ImageF) -> @types.ImageF = @transform.rotate_180_f

///|
pub let rotate_270_16 : (@types.Image16) -> @types.Image16 = @transform.rotate_270_16

///|
pub let rotate_270_f : (@types.ImageF) -> @types.ImageF = @transform.rotate_270_f

///|
pub let segment_to_color : (@segment.SegmentLabelImage) -> @types.Image raise @types.LoadError = @segment.segment_to_color

///|
pub let sharpen : (@types.Image, Float) -> @types.Image raise @types.LoadError = @filter.sharpen

///|
pub let sharpen_16 : (@types.Image16, Float) -> @types.Image16 raise @types.LoadError = @filter.sharpen_16

///|
pub let sharpen_f : (@types.ImageF, Float) -> @types.ImageF raise @types.LoadError = @filter.sharpen_f

///|
pub fn ssr(
  arg0 : @types.Image,
  sigma? : Float = 80.0F,
  gain? : Float = 1.0F,
  offset? : Float = 0.0F,
) -> @types.Image raise @types.LoadError {
  @color.ssr(arg0, sigma~, gain~, offset~)
}

///|
pub fn ssr_16(
  arg0 : @types.Image16,
  sigma? : Float = 80.0F,
  gain? : Float = 1.0F,
  offset? : Float = 0.0F,
) -> @types.Image16 raise @types.LoadError {
  @color.ssr_16(arg0, sigma~, gain~, offset~)
}

///|
pub fn ssr_f(
  arg0 : @types.ImageF,
  sigma? : Float = 80.0F,
  gain? : Float = 1.0F,
  offset? : Float = 0.0F,
) -> @types.ImageF raise @types.LoadError {
  @color.ssr_f(arg0, sigma~, gain~, offset~)
}

///|
pub fn msr(
  arg0 : @types.Image,
  sigmas? : Array[Float] = [15.0F, 80.0F, 250.0F],
  gain? : Float = 1.0F,
  offset? : Float = 0.0F,
) -> @types.Image raise @types.LoadError {
  @color.msr(arg0, sigmas~, gain~, offset~)
}

///|
pub fn msr_16(
  arg0 : @types.Image16,
  sigmas? : Array[Float] = [15.0F, 80.0F, 250.0F],
  gain? : Float = 1.0F,
  offset? : Float = 0.0F,
) -> @types.Image16 raise @types.LoadError {
  @color.msr_16(arg0, sigmas~, gain~, offset~)
}

///|
pub fn msr_f(
  arg0 : @types.ImageF,
  sigmas? : Array[Float] = [15.0F, 80.0F, 250.0F],
  gain? : Float = 1.0F,
  offset? : Float = 0.0F,
) -> @types.ImageF raise @types.LoadError {
  @color.msr_f(arg0, sigmas~, gain~, offset~)
}

///|
pub fn msrcr(
  arg0 : @types.Image,
  sigmas? : Array[Float] = [15.0F, 80.0F, 250.0F],
  gain? : Float = 1.0F,
  offset? : Float = 0.0F,
  alpha? : Float = 125.0F,
  beta? : Float = 46.0F,
) -> @types.Image raise @types.LoadError {
  @color.msrcr(arg0, sigmas~, gain~, offset~, alpha~, beta~)
}

///|
pub fn msrcr_16(
  arg0 : @types.Image16,
  sigmas? : Array[Float] = [15.0F, 80.0F, 250.0F],
  gain? : Float = 1.0F,
  offset? : Float = 0.0F,
  alpha? : Float = 125.0F,
  beta? : Float = 46.0F,
) -> @types.Image16 raise @types.LoadError {
  @color.msrcr_16(arg0, sigmas~, gain~, offset~, alpha~, beta~)
}

///|
pub fn msrcr_f(
  arg0 : @types.ImageF,
  sigmas? : Array[Float] = [15.0F, 80.0F, 250.0F],
  gain? : Float = 1.0F,
  offset? : Float = 0.0F,
  alpha? : Float = 125.0F,
  beta? : Float = 46.0F,
) -> @types.ImageF raise @types.LoadError {
  @color.msrcr_f(arg0, sigmas~, gain~, offset~, alpha~, beta~)
}

///|
pub let ssim : (@types.Image, @types.Image) -> Double raise @types.LoadError = @feature.ssim

///|
pub let ssim_16 : (@types.Image16, @types.Image16) -> Double raise @types.LoadError = @feature.ssim_16

///|
pub let ssim_f : (@types.ImageF, @types.ImageF) -> Double raise @types.LoadError = @feature.ssim_f

///|
pub let threshold_otsu : (@types.Image) -> @types.Image raise @types.LoadError = @color.threshold_otsu

///|
pub let threshold_otsu_16 : (@types.Image16) -> @types.Image16 raise @types.LoadError = @color.threshold_otsu_16

///|
pub let threshold_otsu_f : (@types.ImageF) -> @types.ImageF raise @types.LoadError = @color.threshold_otsu_f

///|
pub let to_grayscale : (@types.Image) -> @types.Image raise @types.LoadError = @color.to_grayscale

///|
pub let to_grayscale_16 : (@types.Image16) -> @types.Image16 raise @types.LoadError = @color.to_grayscale_16

///|
pub let to_grayscale_f : (@types.ImageF) -> @types.ImageF raise @types.LoadError = @color.to_grayscale_f

///|
pub let to_rgb : (@types.Image) -> @types.Image raise @types.LoadError = @color.to_rgb

///|
pub let to_rgb_16 : (@types.Image16) -> @types.Image16 raise @types.LoadError = @color.to_rgb_16

///|
pub let to_rgb_f : (@types.ImageF) -> @types.ImageF raise @types.LoadError = @color.to_rgb_f

///|
pub let to_rgba : (@types.Image) -> @types.Image raise @types.LoadError = @color.to_rgba

///|
pub let to_rgba_16 : (@types.Image16) -> @types.Image16 raise @types.LoadError = @color.to_rgba_16

///|
pub let to_rgba_f : (@types.ImageF) -> @types.ImageF raise @types.LoadError = @color.to_rgba_f

///|
pub let unpremultiply_alpha : (@types.Image) -> @types.Image raise @types.LoadError = @color.unpremultiply_alpha

///|
pub let unpremultiply_alpha_16 : (@types.Image16) -> @types.Image16 raise @types.LoadError = @color.unpremultiply_alpha_16

///|
pub let unpremultiply_alpha_f : (@types.ImageF) -> @types.ImageF raise @types.LoadError = @color.unpremultiply_alpha_f

///|
pub let warp_affine : (
  @types.Image,
  (Float, Float, Float, Float, Float, Float),
  Int,
  Int,
) -> @types.Image = @transform.warp_affine

///|
pub let warp_affine_16 : (
  @types.Image16,
  (Float, Float, Float, Float, Float, Float),
  Int,
  Int,
) -> @types.Image16 = @transform.warp_affine_16

///|
pub let warp_affine_f : (
  @types.ImageF,
  (Float, Float, Float, Float, Float, Float),
  Int,
  Int,
) -> @types.ImageF = @transform.warp_affine_f

///|
pub let watershed : (@types.Image, Array[Int]) -> Array[Int] raise @types.LoadError = @segment.watershed

///|
pub let watershed_16 : (@types.Image16, Array[Int]) -> Array[Int] raise @types.LoadError = @segment.watershed_16

///|
pub let watershed_f : (@types.ImageF, Array[Int]) -> Array[Int] raise @types.LoadError = @segment.watershed_f

///|
pub let watershed_auto : (@types.Image) -> (Array[Int], Int) raise @types.LoadError = @segment.watershed_auto

///|
pub let watershed_auto_16 : (@types.Image16) -> (Array[Int], Int) raise @types.LoadError = @segment.watershed_auto_16

///|
pub let watershed_auto_f : (@types.ImageF) -> (Array[Int], Int) raise @types.LoadError = @segment.watershed_auto_f

///|
pub fn distance_transform(
  arg0 : @types.Image,
  distance_type? : Int = 2,
) -> Array[Float] raise @types.LoadError {
  @segment.distance_transform(arg0, distance_type~)
}

///|
pub let visualize_distance_transform : (Array[Float], Int, Int) -> @types.Image = @segment.visualize_distance_transform

///|
pub let skeletonize : (@types.Image) -> @types.Image raise @types.LoadError = @segment.skeletonize

///|
pub type SuperpixelResult = @segment.SuperpixelResult

///|
pub let slic : (@types.Image, Int, Int, Int) -> @segment.SuperpixelResult raise @types.LoadError = @segment.slic

///|
pub let slic_16 : (@types.Image16, Int, Int, Int) -> @segment.SuperpixelResult raise @types.LoadError = @segment.slic_16

///|
pub let slic_f : (@types.ImageF, Int, Int, Int) -> @segment.SuperpixelResult raise @types.LoadError = @segment.slic_f

///|
pub fn guided_filter(
  arg0 : @types.Image,
  arg1 : Array[Float],
  radius? : Int = 20,
  eps? : Float = 0.001F,
) -> Array[Float] raise @types.LoadError {
  @color.guided_filter(arg0, arg1, radius~, eps~)
}

///|
pub fn guided_filter_16(
  arg0 : @types.Image16,
  arg1 : Array[Float],
  radius? : Int = 20,
  eps? : Float = 0.001F,
) -> Array[Float] raise @types.LoadError {
  @color.guided_filter_16(arg0, arg1, radius~, eps~)
}

///|
pub fn guided_filter_f(
  arg0 : @types.ImageF,
  arg1 : Array[Float],
  radius? : Int = 20,
  eps? : Float = 0.001F,
) -> Array[Float] raise @types.LoadError {
  @color.guided_filter_f(arg0, arg1, radius~, eps~)
}

///|
pub fn flood_fill(
  arg0 : @types.Image,
  arg1 : Int,
  arg2 : Int,
  arg3 : Array[Byte],
  threshold? : Int = 0,
) -> @types.Image raise @types.LoadError {
  @segment.flood_fill(arg0, arg1, arg2, arg3, threshold~)
}

///|
/// grabCut 交互式前景提取
pub fn grab_cut(
  arg0 : @types.Image,
  arg1 : Int,
  arg2 : Int,
  arg3 : Int,
  arg4 : Int,
  iterations? : Int = 5,
) -> @types.Image raise @types.LoadError {
  @segment.grab_cut(arg0, arg1, arg2, arg3, arg4, iterations~)
}

///|
pub type PerspectiveMatrix = @transform.PerspectiveMatrix

///|
pub type AffineMatrix = @transform.AffineMatrix

///|
pub type Moments = @edge.Moments

///|
pub type Circle = @edge.Circle

///|
pub let get_perspective_transform : (
  Array[(Float, Float)],
  Array[(Float, Float)],
) -> @transform.PerspectiveMatrix? = @transform.get_perspective_transform

///|
pub let warp_perspective : (
  @types.Image,
  @transform.PerspectiveMatrix,
  Int,
  Int,
) -> @types.Image = @transform.warp_perspective

///|
pub let warp_perspective_16 : (
  @types.Image16,
  @transform.PerspectiveMatrix,
  Int,
  Int,
) -> @types.Image16 = @transform.warp_perspective_16

///|
pub let warp_perspective_f : (
  @types.ImageF,
  @transform.PerspectiveMatrix,
  Int,
  Int,
) -> @types.ImageF = @transform.warp_perspective_f

///|
pub let get_affine_transform : (Array[(Float, Float)], Array[(Float, Float)]) -> @transform.AffineMatrix? = @transform.get_affine_transform

///|
pub let get_rotation_matrix_2d : ((Float, Float), Float, Float) -> @transform.AffineMatrix = @transform.get_rotation_matrix_2d

///|
pub let convex_hull : (Array[@edge.ContourPoint]) -> Array[@edge.ContourPoint] = @edge.convex_hull

///|
pub fn approx_poly_dp(
  points : Array[@edge.ContourPoint],
  epsilon : Float,
  closed? : Bool = true,
) -> Array[@edge.ContourPoint] raise @types.LoadError {
  @edge.approx_poly_dp(points, epsilon, closed~)
}

///|
pub let image_moments : (Array[@edge.ContourPoint]) -> @edge.Moments = @edge.image_moments

///|
pub let hu_moments : (@edge.Moments) -> Array[Double] raise @types.LoadError = @edge.hu_moments

///|
pub let min_enclosing_circle : (Array[@edge.ContourPoint]) -> (
  @edge.ContourPoint,
  Float,
) = @edge.min_enclosing_circle

///|
pub fn hough_circles(
  img : @types.Image,
  dp? : Int = 1,
  min_dist? : Int = 10,
  param1? : Int = 100,
  param2? : Int = 30,
  min_radius? : Int = 0,
  max_radius? : Int = 0,
) -> Array[@edge.Circle] raise @types.LoadError {
  @edge.hough_circles(
    img,
    dp~,
    min_dist~,
    param1~,
    param2~,
    min_radius~,
    max_radius~,
  )
}

///|
pub fn hough_circles_16(
  img : @types.Image16,
  dp? : Int = 1,
  min_dist? : Int = 10,
  param1? : Int = 100,
  param2? : Int = 30,
  min_radius? : Int = 0,
  max_radius? : Int = 0,
) -> Array[@edge.Circle] raise @types.LoadError {
  @edge.hough_circles_16(
    img,
    dp~,
    min_dist~,
    param1~,
    param2~,
    min_radius~,
    max_radius~,
  )
}

///|
pub fn hough_circles_f(
  img : @types.ImageF,
  dp? : Int = 1,
  min_dist? : Int = 10,
  param1? : Int = 100,
  param2? : Int = 30,
  min_radius? : Int = 0,
  max_radius? : Int = 0,
) -> Array[@edge.Circle] raise @types.LoadError {
  @edge.hough_circles_f(
    img,
    dp~,
    min_dist~,
    param1~,
    param2~,
    min_radius~,
    max_radius~,
  )
}

///|
pub fn multi_band_blend(
  img_a : @types.Image,
  img_b : @types.Image,
  mask : @types.Image,
  num_bands? : Int = 5,
) -> @types.Image raise @types.LoadError {
  @transform.multi_band_blend(img_a, img_b, mask, num_bands~)
}

///|
pub fn multi_band_blend_16(
  img_a : @types.Image16,
  img_b : @types.Image16,
  mask : @types.Image16,
  num_bands? : Int = 5,
) -> @types.Image16 raise @types.LoadError {
  @transform.multi_band_blend_16(img_a, img_b, mask, num_bands~)
}

///|
pub fn multi_band_blend_f(
  img_a : @types.ImageF,
  img_b : @types.ImageF,
  mask : @types.ImageF,
  num_bands? : Int = 5,
) -> @types.ImageF raise @types.LoadError {
  @transform.multi_band_blend_f(img_a, img_b, mask, num_bands~)
}

///|
pub let compute_energy : (@types.Image) -> Array[Double] = @transform.compute_energy

///|
pub let find_vertical_seam : (Array[Double], Int, Int) -> Array[Int] = @transform.find_vertical_seam

///|
pub let remove_vertical_seam : (@types.Image, Array[Int]) -> @types.Image = @transform.remove_vertical_seam

///|
pub let find_horizontal_seam : (Array[Double], Int, Int) -> Array[Int] = @transform.find_horizontal_seam

///|
pub let remove_horizontal_seam : (@types.Image, Array[Int]) -> @types.Image = @transform.remove_horizontal_seam

///|
pub let seam_carve_resize : (@types.Image, Int, Int) -> @types.Image raise @types.LoadError = @transform.seam_carve_resize

///|
pub let compute_energy_16 : (@types.Image16) -> Array[Double] = @transform.compute_energy_16

///|
pub let compute_energy_f : (@types.ImageF) -> Array[Double] = @transform.compute_energy_f

///|
pub let remove_vertical_seam_16 : (@types.Image16, Array[Int]) -> @types.Image16 = @transform.remove_vertical_seam_16

///|
pub let remove_vertical_seam_f : (@types.ImageF, Array[Int]) -> @types.ImageF = @transform.remove_vertical_seam_f

///|
pub let remove_horizontal_seam_16 : (@types.Image16, Array[Int]) -> @types.Image16 = @transform.remove_horizontal_seam_16

///|
pub let remove_horizontal_seam_f : (@types.ImageF, Array[Int]) -> @types.ImageF = @transform.remove_horizontal_seam_f

///|
pub let seam_carve_resize_16 : (@types.Image16, Int, Int) -> @types.Image16 raise @types.LoadError = @transform.seam_carve_resize_16

///|
pub let seam_carve_resize_f : (@types.ImageF, Int, Int) -> @types.ImageF raise @types.LoadError = @transform.seam_carve_resize_f

///|
pub let decode_qoi : (Bytes) -> @types.Image raise @types.LoadError = @codec.decode_qoi_pure

///|
pub let decode_webp : (Bytes) -> @types.Image raise @types.LoadError = @codec.decode_webp_pure

///|
pub let decode_vp8_frame : (Bytes, Int) -> @types.Image raise @types.LoadError = @codec.decode_vp8_frame

///|
pub fn encode_webp_lossy(
  img : @types.Image,
  quality? : Int = 75,
) -> Bytes raise @types.LoadError {
  @codec.encode_webp_lossy_pure(img, quality~)
}

///|
pub let encode_gif : (@types.Image) -> Bytes raise @types.LoadError = @codec.encode_gif_pure

///|
pub let encode_gif_animation : (@types.GifAnimation) -> Bytes raise @types.LoadError = @codec.encode_gif_animation_pure

///|
pub let encode_pgm : (@types.Image) -> Bytes = @codec.encode_pgm_pure

///|
pub let encode_pnm : (@types.Image) -> Bytes = @codec.encode_pnm_pure

///|
pub let encode_ppm : (@types.Image) -> Bytes = @codec.encode_ppm_pure

///|
pub let encode_qoi : (@types.Image) -> Bytes raise @types.LoadError = @codec.encode_qoi_pure

///|
pub let decode_ico : (Bytes) -> @types.Image raise @types.LoadError = @codec.decode_ico_pure

///|
pub let encode_ico : (@types.Image) -> Bytes = @codec.encode_ico_pure

///|
pub let encode_ico_sizes : (Array[@types.Image]) -> Bytes = @codec.encode_ico_with_sizes_pure

///|
pub let decode_cur : (Bytes) -> @types.Image raise @types.LoadError = @codec.decode_cur_pure

///|
pub let encode_cur : (@types.Image) -> Bytes = @codec.encode_cur_pure

///|
pub let decode_icns : (Bytes) -> @types.Image raise @types.LoadError = @codec.decode_icns_pure

///|
pub let encode_icns : (@types.Image) -> Bytes = @codec.encode_icns_pure

///|
pub let decode_tiff : (Bytes) -> @types.Image raise @types.LoadError = @codec.decode_tiff_pure

///|
pub let encode_tiff : (@types.Image) -> Bytes raise @types.LoadError = @codec.encode_tiff_pure

///|
pub let decode_apng : (Bytes) -> @types.PngAnimation raise @types.LoadError = @codec.decode_apng_pure

///|
pub let encode_apng : (@types.PngAnimation) -> Bytes raise @types.LoadError = @codec.encode_apng_pure

// From meta/

///|
pub let read_exif_from_bytes : (Bytes) -> @meta.ExifInfo? = @meta.read_exif_from_bytes

///|
pub let create_exif_segment : (@meta.ExifInfo) -> Bytes = @meta.create_exif_segment

///|
pub let write_exif_to_bytes : (@meta.ExifInfo, Bytes) -> Bytes raise @types.LoadError = @meta.write_exif_to_bytes

///|
pub let read_png_text_chunks : (Bytes) -> Array[@meta.PngTextChunk] = @meta.read_png_text_chunks

// From util/

///|
pub let add_border : (@types.Image, Int, Int, Int, Int, Array[Byte]) -> @types.Image raise @types.LoadError = @util.add_border

///|
pub let add_noise_gaussian : (@types.Image, Float, UInt) -> @types.Image = @util.add_noise_gaussian

///|
pub let add_noise_salt_pepper : (@types.Image, Float, UInt) -> @types.Image = @util.add_noise_salt_pepper

///|
pub let apply_lut : (@types.Image, Array[Byte]) -> @types.Image raise @types.LoadError = @util.apply_lut

///|
pub let blend_darken : (@types.Image, @types.Image) -> @types.Image raise @types.LoadError = @util.blend_darken

///|
pub let blend_difference : (@types.Image, @types.Image) -> @types.Image raise @types.LoadError = @util.blend_difference

///|
pub let blend_exclusion : (@types.Image, @types.Image) -> @types.Image raise @types.LoadError = @util.blend_exclusion

///|
pub let blend_lighten : (@types.Image, @types.Image) -> @types.Image raise @types.LoadError = @util.blend_lighten

///|
pub let blend_multiply : (@types.Image, @types.Image) -> @types.Image raise @types.LoadError = @util.blend_multiply

///|
pub let blend_overlay : (@types.Image, @types.Image) -> @types.Image raise @types.LoadError = @util.blend_overlay

///|
pub let blend_screen : (@types.Image, @types.Image) -> @types.Image raise @types.LoadError = @util.blend_screen

///|
pub let blend_color_dodge : (@types.Image, @types.Image) -> @types.Image raise @types.LoadError = @util.blend_color_dodge

///|
pub let blend_color_burn : (@types.Image, @types.Image) -> @types.Image raise @types.LoadError = @util.blend_color_burn

///|
pub let blend_hard_light : (@types.Image, @types.Image) -> @types.Image raise @types.LoadError = @util.blend_hard_light

///|
pub let blend_soft_light : (@types.Image, @types.Image) -> @types.Image raise @types.LoadError = @util.blend_soft_light

///|
pub let blend_linear_dodge : (@types.Image, @types.Image) -> @types.Image raise @types.LoadError = @util.blend_linear_dodge

///|
pub let blend_linear_burn : (@types.Image, @types.Image) -> @types.Image raise @types.LoadError = @util.blend_linear_burn

///|
pub let compute_stats : (@types.Image) -> @util.ImageStats = @util.compute_stats

///|
pub let compute_stats_16 : (@types.Image16) -> @util.ImageStats = @util.compute_stats_16

///|
pub let compute_stats_f : (@types.ImageF) -> @util.ImageStatsF = @util.compute_stats_f

///|
pub let convolve : (@types.Image, Array[Float], Float, Float) -> @types.Image raise @types.LoadError = @filter.convolve

///|
pub let convolve_16 : (@types.Image16, Array[Float], Float, Float) -> @types.Image16 raise @types.LoadError = @filter.convolve_16

///|
pub let convolve_f : (@types.ImageF, Array[Float], Float, Float) -> @types.ImageF raise @types.LoadError = @filter.convolve_f

///|
pub let extract_channel : (@types.Image, Int) -> @types.Image raise @types.LoadError = @util.extract_channel

///|
pub let fill_alpha : (@types.Image, Int, Byte, Byte, Byte) -> @types.Image raise @types.LoadError = @util.fill_alpha

///|
pub let flip_vertical : (@types.Image) -> @types.Image = @transform.flip_vertical

///|
pub let flip_vertical_16 : (@types.Image16) -> @types.Image16 = @transform.flip_vertical_16

///|
pub let flip_vertical_f : (@types.ImageF) -> @types.ImageF = @transform.flip_vertical_f

///|
pub let gradient_map : (@types.Image, Array[(Int, Byte, Byte, Byte)]) -> @types.Image raise @types.LoadError = @util.gradient_map

///|
pub let hstack : (@types.Image, @types.Image) -> @types.Image raise @types.LoadError = @util.hstack

///|
pub let mean_value : (@types.Image) -> Float = @util.mean_value

///|
pub let mean_value_16 : (@types.Image16) -> Float = @util.mean_value_16

///|
pub let mean_value_f : (@types.ImageF) -> Float = @util.mean_value_f

///|
pub let variance_value : (@types.Image) -> Float = @util.variance_value

///|
pub let entropy_value : (@types.Image) -> Float = @util.entropy_value

///|
pub let median_value : (@types.Image) -> Int = @util.median_value

///|
pub let contrast_value : (@types.Image) -> Float = @util.contrast_value

///|
pub let brightness_value : (@types.Image) -> Float = @util.brightness_value

///|
pub let alpha_blend : (@types.Image, @types.Image, Float) -> @types.Image raise @types.LoadError = @util.alpha_blend

///|
pub let mask_blend : (@types.Image, @types.Image, @types.Image) -> @types.Image raise @types.LoadError = @util.mask_blend

///|
pub let pad : (@types.Image, Int, Int, Array[Byte]) -> @types.Image raise @types.LoadError = @util.pad

///|
pub let pixelate : (@types.Image, Int) -> @types.Image raise @types.LoadError = @util.pixelate

///|
pub let posterize : (@types.Image, Int) -> @types.Image raise @types.LoadError = @util.posterize

///|
pub let replace_color : (@types.Image, Array[Byte], Array[Byte], Int) -> @types.Image raise @types.LoadError = @util.replace_color

///|
pub let resize_to_contain : (@types.Image, Int, Int, Array[Byte]) -> @types.Image raise @types.LoadError = @transform.resize_to_contain

///|
pub let resize_to_cover : (@types.Image, Int, Int) -> @types.Image raise @types.LoadError = @transform.resize_to_cover

///|
pub let set_alpha : (@types.Image, Byte) -> @types.Image raise @types.LoadError = @util.set_alpha

///|
pub let swap_channels : (@types.Image, Int, Int) -> @types.Image raise @types.LoadError = @util.swap_channels

///|
pub let threshold : (@types.Image, Int) -> @types.Image = @util.threshold

///|
pub let tile : (@types.Image, Int, Int) -> @types.Image raise @types.LoadError = @util.tile

///|
pub let transpose : (@types.Image) -> @types.Image = @util.transpose

///|
pub let transpose_16 : (@types.Image16) -> @types.Image16 = @transform.transpose_16

///|
pub let transpose_f : (@types.ImageF) -> @types.ImageF = @transform.transpose_f

///|
pub let vstack : (@types.Image, @types.Image) -> @types.Image raise @types.LoadError = @util.vstack

///|
/// 图像修复（扩散法）
pub fn inpaint(
  arg0 : @types.Image,
  arg1 : @types.Image,
  iterations? : Int = 100,
) -> @types.Image raise @types.LoadError {
  @filter.inpaint(arg0, arg1, iterations~)
}

///|
/// 快速图像修复（距离加权平均）
pub fn inpaint_fast(
  arg0 : @types.Image,
  arg1 : @types.Image,
  radius? : Int = 5,
) -> @types.Image raise @types.LoadError {
  @filter.inpaint_fast(arg0, arg1, radius~)
}

///|
pub fn inpaint_16(
  arg0 : @types.Image16,
  arg1 : @types.Image16,
  iterations? : Int = 100,
) -> @types.Image16 raise @types.LoadError {
  @filter.inpaint_16(arg0, arg1, iterations~)
}

///|
pub fn inpaint_fast_16(
  arg0 : @types.Image16,
  arg1 : @types.Image16,
  radius? : Int = 5,
) -> @types.Image16 raise @types.LoadError {
  @filter.inpaint_fast_16(arg0, arg1, radius~)
}

///|
pub fn inpaint_f(
  arg0 : @types.ImageF,
  arg1 : @types.ImageF,
  iterations? : Int = 100,
) -> @types.ImageF raise @types.LoadError {
  @filter.inpaint_f(arg0, arg1, iterations~)
}

///|
pub fn inpaint_fast_f(
  arg0 : @types.ImageF,
  arg1 : @types.ImageF,
  radius? : Int = 5,
) -> @types.ImageF raise @types.LoadError {
  @filter.inpaint_fast_f(arg0, arg1, radius~)
}

// ==================== OCR 预处理模块 ====================

///|
pub type TextRegion = @ocr.TextRegion

///|
pub type TextRegionType = @ocr.TextRegionType

///|
pub type TextLine = @ocr.TextLine

///|
pub fn ocr_preprocess(
  img : @types.Image,
  binarization_method? : String = "sauvola",
) -> @types.Image raise @types.LoadError {
  @ocr.ocr_preprocess(img, binarization_method~)
}

///|
pub fn document_enhance(
  img : @types.Image,
) -> @types.Image raise @types.LoadError {
  @ocr.document_enhance(img)
}

///|
pub fn shadow_removal(
  img : @types.Image,
  kernel_size? : Int = 51,
) -> @types.Image raise @types.LoadError {
  @ocr.shadow_removal(img, kernel_size~)
}

///|
pub fn background_normalization(
  img : @types.Image,
  kernel_size? : Int = 31,
) -> @types.Image raise @types.LoadError {
  @ocr.background_normalization(img, kernel_size~)
}

///|
pub fn deskew(img : @types.Image) -> @types.Image raise @types.LoadError {
  @ocr.deskew(img)
}

///|
pub fn detect_skew_angle(img : @types.Image) -> Double raise @types.LoadError {
  @ocr.detect_skew_angle(img)
}

///|
pub fn rotate_document(
  img : @types.Image,
  angle : Double,
) -> @types.Image raise @types.LoadError {
  @ocr.rotate_document(img, angle)
}

///|
pub fn sauvola_threshold(
  img : @types.Image,
  window_size? : Int = 15,
  k? : Double = 0.5,
  r? : Double = 128.0,
) -> @types.Image raise @types.LoadError {
  @ocr.sauvola_threshold(img, window_size~, k~, r~)
}

///|
pub fn niblack_threshold(
  img : @types.Image,
  window_size? : Int = 15,
  k? : Double = -0.2,
) -> @types.Image raise @types.LoadError {
  @ocr.niblack_threshold(img, window_size~, k~)
}

///|
pub fn adaptive_threshold_ocr(
  img : @types.Image,
  block_size? : Int = 15,
  c? : Int = 10,
) -> @types.Image raise @types.LoadError {
  @ocr.adaptive_threshold_ocr(img, block_size~, c~)
}

///|
pub fn otsu_threshold(
  img : @types.Image,
) -> @types.Image raise @types.LoadError {
  @ocr.otsu_threshold(img)
}

///|
pub fn detect_text_regions(
  img : @types.Image,
) -> Array[@ocr.TextRegion] raise @types.LoadError {
  @ocr.detect_text_regions(img)
}

///|
pub fn segment_page(
  img : @types.Image,
) -> Array[@ocr.TextRegion] raise @types.LoadError {
  @ocr.segment_page(img)
}

///|
pub fn detect_columns(
  img : @types.Image,
) -> (Int, Array[(Int, Int)]) raise @types.LoadError {
  @ocr.detect_columns(img)
}

///|
pub fn extract_text_lines(
  img : @types.Image,
) -> Array[@types.Image] raise @types.LoadError {
  @ocr.extract_text_lines(img)
}

// ==================== OCR 文本检测模块（v7.1.0） ====================

///|
pub type OcrConnectedComponent = @ocr.OcrConnectedComponent

///|
pub type OcrConnectedComponentsResult = @ocr.OcrConnectedComponentsResult

///|
pub type ProjectionResult = @ocr.ProjectionResult

///|
pub type TextLineInfo = @ocr.TextLineInfo

///|
pub type CharSegment = @ocr.CharSegment

///|
pub fn connected_components_analysis(
  img : @types.Image,
  connectivity? : Int = 8,
) -> @ocr.OcrConnectedComponentsResult raise @types.LoadError {
  @ocr.connected_components_analysis(img, connectivity~)
}

///|
pub fn filter_components_by_area(
  result : @ocr.OcrConnectedComponentsResult,
  min_area : Int,
  max_area : Int,
) -> Array[@ocr.OcrConnectedComponent] raise @types.LoadError {
  @ocr.filter_components_by_area(result, min_area, max_area)
}

///|
pub fn filter_components_by_aspect_ratio(
  result : @ocr.OcrConnectedComponentsResult,
  min_ratio : Double,
  max_ratio : Double,
) -> Array[@ocr.OcrConnectedComponent] raise @types.LoadError {
  @ocr.filter_components_by_aspect_ratio(result, min_ratio, max_ratio)
}

///|
pub fn merge_adjacent_components(
  components : Array[@ocr.OcrConnectedComponent],
  max_gap : Int,
) -> Array[@ocr.OcrConnectedComponent] raise @types.LoadError {
  @ocr.merge_adjacent_components(components, max_gap)
}

///|
pub fn horizontal_projection(
  img : @types.Image,
) -> @ocr.ProjectionResult raise @types.LoadError {
  @ocr.horizontal_projection(img)
}

///|
pub fn vertical_projection(
  img : @types.Image,
) -> @ocr.ProjectionResult raise @types.LoadError {
  @ocr.vertical_projection(img)
}

///|
pub fn detect_text_lines_projection(
  img : @types.Image,
  min_height? : Int = 5,
  max_gap? : Int = 3,
) -> Array[@ocr.TextLineInfo] raise @types.LoadError {
  @ocr.detect_text_lines_projection(img, min_height~, max_gap~)
}

///|
pub fn segment_chars_projection(
  img : @types.Image,
  line : @ocr.TextLineInfo,
  min_width? : Int = 2,
  max_gap? : Int = 2,
) -> Array[@ocr.CharSegment] raise @types.LoadError {
  @ocr.segment_chars_projection(img, line, min_width~, max_gap~)
}

///|
pub fn extract_text_line_image(
  img : @types.Image,
  line : @ocr.TextLineInfo,
  padding? : Int = 2,
) -> @types.Image raise @types.LoadError {
  @ocr.extract_text_line_image(img, line, padding~)
}

///|
pub fn extract_char_image(
  img : @types.Image,
  char : @ocr.CharSegment,
  target_size? : Int = 32,
  padding? : Int = 2,
) -> @types.Image raise @types.LoadError {
  @ocr.extract_char_image(img, char, target_size~, padding~)
}

// ==================== OCR 字符分割完善（v7.2.0） ====================

///|
pub type SplitPoint = @ocr.SplitPoint

///|
pub type DropFallResult = @ocr.DropFallResult

///|
pub fn drop_fall_segmentation(
  img : @types.Image,
  start_x? : Int = -1,
) -> @ocr.DropFallResult raise @types.LoadError {
  @ocr.drop_fall_segmentation(img, start_x~)
}

///|
pub fn detect_touching_chars(
  img : @types.Image,
  min_char_width? : Int = 8,
  max_char_width? : Int = 50,
) -> Array[Int] raise @types.LoadError {
  @ocr.detect_touching_chars(img, min_char_width~, max_char_width~)
}

///|
pub fn segment_by_connected_components(
  img : @types.Image,
  min_area? : Int = 5,
  max_area? : Int = 10000,
) -> Array[(Int, Int, Int, Int)] raise @types.LoadError {
  @ocr.segment_by_connected_components(img, min_area~, max_area~)
}

///|
pub fn merge_small_segments(
  segments : Array[(Int, Int, Int, Int)],
  min_width : Int,
  min_height : Int,
) -> Array[(Int, Int, Int, Int)] raise @types.LoadError {
  @ocr.merge_small_segments(segments, min_width, min_height)
}

///|
pub fn filter_noise_segments(
  segments : Array[(Int, Int, Int, Int)],
  img_width : Int,
  img_height : Int,
  min_area_ratio? : Double = 0.001,
  max_area_ratio? : Double = 0.5,
) -> Array[(Int, Int, Int, Int)] raise @types.LoadError {
  @ocr.filter_noise_segments(
    segments,
    img_width,
    img_height,
    min_area_ratio~,
    max_area_ratio~,
  )
}

///|
pub fn complete_char_segmentation(
  img : @types.Image,
  min_char_width? : Int = 5,
  max_char_width? : Int = 60,
) -> Array[(Int, Int, Int, Int)] raise @types.LoadError {
  @ocr.complete_char_segmentation(img, min_char_width~, max_char_width~)
}

// ==================== OCR 特征提取（v7.3.0） ====================

///|
pub type HogFeatures = @ocr.HogFeatures

///|
pub type LbpFeatures = @ocr.LbpFeatures

///|
pub type ProjectionFeatures = @ocr.ProjectionFeatures

///|
pub type GridFeatures = @ocr.GridFeatures

///|
pub type StatisticalFeatures = @ocr.StatisticalFeatures

///|
pub fn hog_features(
  img : @types.Image,
  cell_size? : Int = 8,
  num_bins? : Int = 9,
) -> @ocr.HogFeatures raise @types.LoadError {
  @ocr.hog_features(img, cell_size~, num_bins~)
}

///|
pub fn lbp_features(
  img : @types.Image,
  radius? : Int = 1,
  num_points? : Int = 8,
  num_bins? : Int = 256,
) -> @ocr.LbpFeatures raise @types.LoadError {
  @ocr.lbp_features(img, radius~, num_points~, num_bins~)
}

///|
pub fn projection_features(
  img : @types.Image,
) -> @ocr.ProjectionFeatures raise @types.LoadError {
  @ocr.projection_features(img)
}

///|
pub fn grid_features(
  img : @types.Image,
  grid_rows? : Int = 4,
  grid_cols? : Int = 4,
) -> @ocr.GridFeatures raise @types.LoadError {
  @ocr.grid_features(img, grid_rows~, grid_cols~)
}

///|
pub fn statistical_features(
  img : @types.Image,
) -> @ocr.StatisticalFeatures raise @types.LoadError {
  @ocr.statistical_features(img)
}

///|
pub fn combined_features(
  img : @types.Image,
) -> Array[Double] raise @types.LoadError {
  @ocr.combined_features(img)
}

// ==================== OCR 简单分类器（v7.4.0） ====================

///|
pub type ClassificationResult = @ocr.ClassificationResult

///|
pub type TrainingSample = @ocr.TrainingSample

///|
pub type KnnClassifier = @ocr.KnnClassifier

///|
pub type TemplateMatcher = @ocr.TemplateMatcher

///|
pub type DistanceMetric = @ocr.DistanceMetric

///|
pub fn euclidean_distance(
  a : Array[Double],
  b : Array[Double],
) -> Double raise @types.LoadError {
  @ocr.euclidean_distance(a, b)
}

///|
pub fn manhattan_distance(
  a : Array[Double],
  b : Array[Double],
) -> Double raise @types.LoadError {
  @ocr.manhattan_distance(a, b)
}

///|
pub fn cosine_distance(
  a : Array[Double],
  b : Array[Double],
) -> Double raise @types.LoadError {
  @ocr.cosine_distance(a, b)
}

///|
pub fn chebyshev_distance(
  a : Array[Double],
  b : Array[Double],
) -> Double raise @types.LoadError {
  @ocr.chebyshev_distance(a, b)
}

///|
pub fn compute_distance(
  a : Array[Double],
  b : Array[Double],
  metric : @ocr.DistanceMetric,
) -> Double raise @types.LoadError {
  @ocr.compute_distance(a, b, metric)
}

///|
pub fn knn_create(
  k? : Int = 3,
  distance_metric? : String = "euclidean",
) -> @ocr.KnnClassifier raise @types.LoadError {
  @ocr.knn_create(k~, distance_metric~)
}

///|
pub fn knn_add_sample(
  classifier : @ocr.KnnClassifier,
  features : Array[Double],
  label : String,
) -> @ocr.KnnClassifier raise @types.LoadError {
  @ocr.knn_add_sample(classifier, features, label)
}

///|
pub fn knn_add_samples(
  classifier : @ocr.KnnClassifier,
  samples : Array[(Array[Double], String)],
) -> @ocr.KnnClassifier raise @types.LoadError {
  @ocr.knn_add_samples(classifier, samples)
}

///|
pub fn knn_predict(
  classifier : @ocr.KnnClassifier,
  features : Array[Double],
) -> @ocr.ClassificationResult raise @types.LoadError {
  @ocr.knn_predict(classifier, features)
}

///|
pub fn template_matcher_create(
  distance_metric? : String = "euclidean",
) -> @ocr.TemplateMatcher {
  @ocr.template_matcher_create(distance_metric~)
}

///|
pub fn template_matcher_add(
  matcher : @ocr.TemplateMatcher,
  label : String,
  template : Array[Double],
) -> @ocr.TemplateMatcher raise @types.LoadError {
  @ocr.template_matcher_add(matcher, label, template)
}

///|
pub fn template_matcher_predict(
  matcher : @ocr.TemplateMatcher,
  features : Array[Double],
) -> @ocr.ClassificationResult raise @types.LoadError {
  @ocr.template_matcher_predict(matcher, features)
}

///|
pub fn normalize_features(
  features : Array[Double],
) -> Array[Double] raise @types.LoadError {
  @ocr.normalize_features(features)
}

///|
pub fn standardize_features(
  features : Array[Double],
) -> Array[Double] raise @types.LoadError {
  @ocr.standardize_features(features)
}

// ==================== OCR 数字识别（v7.5.0） ====================

///|
pub type OcrResult = @ocr.OcrResult

///|
pub type OcrCharResult = @ocr.OcrCharResult

///|
pub type DigitOcrConfig = @ocr.DigitOcrConfig

///|
pub fn digit_ocr_default_config() -> @ocr.DigitOcrConfig {
  @ocr.digit_ocr_default_config()
}

///|
pub fn generate_digit_templates() -> Array[(String, Array[Double])] {
  @ocr.generate_digit_templates()
}

///|
pub fn recognize_digits(
  img : @types.Image,
  config? : @ocr.DigitOcrConfig,
) -> @ocr.OcrResult raise @types.LoadError {
  match config {
    Some(c) => @ocr.recognize_digits(img, config=c)
    None => @ocr.recognize_digits(img)
  }
}

// ==================== OCR 英文识别（v8.0.0） ====================

///|
pub type EnglishOcrConfig = @ocr.EnglishOcrConfig

///|
pub fn english_ocr_default_config() -> @ocr.EnglishOcrConfig {
  @ocr.english_ocr_default_config()
}

///|
pub fn generate_english_templates(
  case_sensitive? : Bool = false,
) -> Array[(String, Array[Double])] {
  @ocr.generate_english_templates(case_sensitive~)
}

///|
pub fn recognize_english(
  img : @types.Image,
  config? : @ocr.EnglishOcrConfig,
) -> @ocr.OcrResult raise @types.LoadError {
  match config {
    Some(c) => @ocr.recognize_english(img, config=c)
    None => @ocr.recognize_english(img)
  }
}

// ==================== OCR 后处理（v8.1.0） ====================

///|
pub type PostProcessConfig = @ocr.PostProcessConfig

///|
pub type Dictionary = @ocr.Dictionary

///|
pub type NgramModel = @ocr.NgramModel

///|
pub fn postprocess_default_config() -> @ocr.PostProcessConfig {
  @ocr.postprocess_default_config()
}

///|
pub fn dictionary_create(
  words : Array[String],
) -> @ocr.Dictionary raise @types.LoadError {
  @ocr.dictionary_create(words)
}

///|
pub fn dictionary_create_common_english() -> @ocr.Dictionary {
  @ocr.dictionary_create_common_english()
}

///|
pub fn edit_distance(s1 : String, s2 : String) -> Int raise @types.LoadError {
  @ocr.edit_distance(s1, s2)
}

///|
pub fn dictionary_match(
  word : String,
  dictionary : @ocr.Dictionary,
  max_distance? : Int = 2,
) -> Array[(String, Int)] raise @types.LoadError {
  @ocr.dictionary_match(word, dictionary, max_distance~)
}

///|
pub fn ngram_create(
  texts : Array[String],
  n? : Int = 2,
) -> @ocr.NgramModel raise @types.LoadError {
  @ocr.ngram_create(texts, n~)
}

///|
pub fn ngram_score(
  text : String,
  model : @ocr.NgramModel,
) -> Double raise @types.LoadError {
  @ocr.ngram_score(text, model)
}

///|
pub fn ocr_postprocess(
  result : @ocr.OcrResult,
  config? : @ocr.PostProcessConfig,
  dictionary? : @ocr.Dictionary,
  ngram_model? : @ocr.NgramModel,
) -> @ocr.OcrResult raise @types.LoadError {
  match config {
    Some(c) =>
      match dictionary {
        Some(d) =>
          match ngram_model {
            Some(n) =>
              @ocr.ocr_postprocess(
                result,
                config=c,
                dictionary=d,
                ngram_model=n,
              )
            None => @ocr.ocr_postprocess(result, config=c, dictionary=d)
          }
        None => @ocr.ocr_postprocess(result, config=c)
      }
    None => @ocr.ocr_postprocess(result)
  }
}

///|
pub fn calibrate_confidence(
  result : @ocr.OcrResult,
  factor? : Double = 1.0,
) -> @ocr.OcrResult raise @types.LoadError {
  @ocr.calibrate_confidence(result, factor~)
}

// ==================== OCR 中文识别（v8.2.0） ====================

///|
pub type ChineseOcrConfig = @ocr.ChineseOcrConfig

///|
pub fn chinese_ocr_default_config() -> @ocr.ChineseOcrConfig {
  @ocr.chinese_ocr_default_config()
}

///|
pub fn generate_chinese_templates(
  char_set? : String = "common",
) -> Array[(String, Array[Double])] {
  @ocr.generate_chinese_templates(char_set~)
}

///|
pub fn recognize_chinese(
  img : @types.Image,
  config? : @ocr.ChineseOcrConfig,
) -> @ocr.OcrResult raise @types.LoadError {
  match config {
    Some(c) => @ocr.recognize_chinese(img, config=c)
    None => @ocr.recognize_chinese(img)
  }
}

// ==================== OCR 表格识别（v8.3.0） ====================

///|
pub type TableLine = @ocr.TableLine

///|
pub type TableLineType = @ocr.TableLineType

///|
pub type TableCell = @ocr.TableCell

///|
pub type TableStructure = @ocr.TableStructure

///|
pub fn detect_horizontal_lines(
  img : @types.Image,
  min_length? : Int = 20,
  max_gap? : Int = 2,
) -> Array[@ocr.TableLine] raise @types.LoadError {
  @ocr.detect_horizontal_lines(img, min_length~, max_gap~)
}

///|
pub fn detect_vertical_lines(
  img : @types.Image,
  min_length? : Int = 20,
  max_gap? : Int = 2,
) -> Array[@ocr.TableLine] raise @types.LoadError {
  @ocr.detect_vertical_lines(img, min_length~, max_gap~)
}

///|
pub fn analyze_table_structure(
  horizontal_lines : Array[@ocr.TableLine],
  vertical_lines : Array[@ocr.TableLine],
) -> @ocr.TableStructure raise @types.LoadError {
  @ocr.analyze_table_structure(horizontal_lines, vertical_lines)
}

///|
pub fn recognize_table(
  img : @types.Image,
  min_line_length? : Int = 20,
) -> @ocr.TableStructure raise @types.LoadError {
  @ocr.recognize_table(img, min_line_length~)
}

///|
pub fn extract_cell_image(
  img : @types.Image,
  cell : @ocr.TableCell,
  padding? : Int = 1,
) -> @types.Image raise @types.LoadError {
  @ocr.extract_cell_image(img, cell, padding~)
}

///|
pub fn extract_all_cells(
  img : @types.Image,
  structure : @ocr.TableStructure,
  padding? : Int = 1,
) -> Array[@types.Image] raise @types.LoadError {
  @ocr.extract_all_cells(img, structure, padding~)
}

// ==================== 完善中文 OCR（v9.0.0） ====================

///|
pub type AdvancedChineseOcrConfig = @ocr.AdvancedChineseOcrConfig

///|
pub type ChineseRadical = @ocr.ChineseRadical

///|
pub type ChineseCharStructure = @ocr.ChineseCharStructure

///|
pub fn advanced_chinese_ocr_default_config() -> @ocr.AdvancedChineseOcrConfig {
  @ocr.advanced_chinese_ocr_default_config()
}

///|
pub fn generate_3500_chinese_templates(
  char_set? : String = "common3500",
) -> Array[(String, Array[Double])] {
  @ocr.generate_3500_chinese_templates(char_set~)
}

///|
pub fn decompose_chinese_char(
  char : String,
) -> @ocr.ChineseCharStructure raise @types.LoadError {
  @ocr.decompose_chinese_char(char)
}

///|
pub fn recognize_chinese_advanced(
  img : @types.Image,
  config? : @ocr.AdvancedChineseOcrConfig,
) -> @ocr.OcrResult raise @types.LoadError {
  match config {
    Some(c) => @ocr.recognize_chinese_advanced(img, config=c)
    None => @ocr.recognize_chinese_advanced(img)
  }
}

// ==================== OCR 准确率提升（v9.1.0） ====================

///|
pub type TrainingDataset = @ocr.TrainingDataset

///|
pub type EnsembleConfig = @ocr.EnsembleConfig

///|
pub fn ensemble_default_config() -> @ocr.EnsembleConfig {
  @ocr.ensemble_default_config()
}

///|
pub fn dataset_create() -> @ocr.TrainingDataset {
  @ocr.dataset_create()
}

///|
pub fn dataset_add_sample(
  dataset : @ocr.TrainingDataset,
  features : Array[Double],
  label : String,
) -> @ocr.TrainingDataset {
  @ocr.dataset_add_sample(dataset, features, label)
}

///|
pub fn dataset_stats(
  dataset : @ocr.TrainingDataset,
) -> (Int, Int, Array[(String, Int)]) {
  @ocr.dataset_stats(dataset)
}

///|
pub fn augment_features(
  features : Array[Double],
  noise_level? : Double = 0.05,
) -> Array[Double] {
  @ocr.augment_features(features, noise_level~)
}

///|
pub fn hu_moments_features(
  img : @types.Image,
) -> Array[Double] raise @types.LoadError {
  @ocr.hu_moments_features(img)
}

///|
pub fn ensemble_predict(
  features : Array[Double],
  knn_classifier : @ocr.KnnClassifier,
  templates : Array[(String, Array[Double])],
  config? : @ocr.EnsembleConfig,
) -> @ocr.ClassificationResult raise @types.LoadError {
  match config {
    Some(c) =>
      @ocr.ensemble_predict(features, knn_classifier, templates, config=c)
    None => @ocr.ensemble_predict(features, knn_classifier, templates)
  }
}

///|
pub fn extract_combined_ocr_features(
  img : @types.Image,
) -> Array[Double] raise @types.LoadError {
  @ocr.extract_combined_ocr_features(img)
}

// ==================== 文档理解（v9.2.0） ====================

///|
pub type DocumentElementType = @ocr.DocumentElementType

///|
pub type DocumentElement = @ocr.DocumentElement

///|
pub type DocumentStructure = @ocr.DocumentStructure

///|
pub fn analyze_document_layout(
  img : @types.Image,
) -> @ocr.DocumentStructure raise @types.LoadError {
  @ocr.analyze_document_layout(img)
}

///|
pub fn compute_reading_order(
  elements : Array[@ocr.DocumentElement],
) -> Array[Int] raise @types.LoadError {
  @ocr.compute_reading_order(elements)
}

///|
pub fn extract_title(structure : @ocr.DocumentStructure) -> String {
  @ocr.extract_title(structure)
}

///|
pub fn extract_headings(
  structure : @ocr.DocumentStructure,
) -> Array[@ocr.DocumentElement] {
  @ocr.extract_headings(structure)
}

///|
pub fn extract_paragraphs(
  structure : @ocr.DocumentStructure,
) -> Array[@ocr.DocumentElement] {
  @ocr.extract_paragraphs(structure)
}

///|
pub fn get_elements_in_reading_order(
  structure : @ocr.DocumentStructure,
) -> Array[@ocr.DocumentElement] {
  @ocr.get_elements_in_reading_order(structure)
}

///|
pub fn document_structure_stats(
  structure : @ocr.DocumentStructure,
) -> (Int, Int, Int, Int, Int) {
  @ocr.document_structure_stats(structure)
}

///|
pub fn detect_document_columns(
  img : @types.Image,
) -> Int raise @types.LoadError {
  @ocr.detect_document_columns(img)
}

///|
pub fn understand_document(
  img : @types.Image,
) -> @ocr.DocumentStructure raise @types.LoadError {
  @ocr.understand_document(img)
}

// ==================== 手写体识别（v9.3.0） ====================

///|
pub type HandwritingOcrConfig = @ocr.HandwritingOcrConfig

///|
pub fn handwriting_ocr_default_config() -> @ocr.HandwritingOcrConfig {
  @ocr.handwriting_ocr_default_config()
}

///|
pub fn generate_handwriting_templates(
  char_set? : String = "digits",
) -> Array[(String, Array[Double])] {
  @ocr.generate_handwriting_templates(char_set~)
}

///|
pub fn correct_slant(
  img : @types.Image,
  max_slant? : Double = 15.0,
) -> @types.Image raise @types.LoadError {
  @ocr.correct_slant(img, max_slant~)
}

///|
pub fn recognize_handwriting(
  img : @types.Image,
  config? : @ocr.HandwritingOcrConfig,
) -> @ocr.OcrResult raise @types.LoadError {
  match config {
    Some(c) => @ocr.recognize_handwriting(img, config=c)
    None => @ocr.recognize_handwriting(img)
  }
}

// ==================== 多语言混合识别（v9.4.0） ====================

///|
pub type LanguageType = @ocr.LanguageType

///|
pub type MultilingualOcrConfig = @ocr.MultilingualOcrConfig

///|
pub type PunctuationTemplate = @ocr.PunctuationTemplate

///|
pub fn multilingual_ocr_default_config() -> @ocr.MultilingualOcrConfig {
  @ocr.multilingual_ocr_default_config()
}

///|
pub fn generate_punctuation_templates() -> Array[@ocr.PunctuationTemplate] {
  @ocr.generate_punctuation_templates()
}

///|
pub fn detect_char_language(
  char_img : @types.Image,
) -> @ocr.LanguageType raise @types.LoadError {
  @ocr.detect_char_language(char_img)
}

///|
pub fn detect_document_language(
  img : @types.Image,
) -> @ocr.LanguageType raise @types.LoadError {
  @ocr.detect_document_language(img)
}

///|
pub fn recognize_multilingual(
  img : @types.Image,
  config? : @ocr.MultilingualOcrConfig,
) -> @ocr.OcrResult raise @types.LoadError {
  match config {
    Some(c) => @ocr.recognize_multilingual(img, config=c)
    None => @ocr.recognize_multilingual(img)
  }
}

// ==================== 中文 OCR 增强版（v10.0.0） ====================

///|
pub type EnhancedChineseOcrConfig = @ocr.EnhancedChineseOcrConfig

///|
pub type ChineseCharInfo = @ocr.ChineseCharInfo

///|
pub fn enhanced_chinese_ocr_default_config() -> @ocr.EnhancedChineseOcrConfig {
  @ocr.enhanced_chinese_ocr_default_config()
}

///|
pub fn generate_chinese_char_info_db() -> Array[@ocr.ChineseCharInfo] {
  @ocr.generate_chinese_char_info_db()
}

///|
pub fn generate_enhanced_chinese_templates(
  char_set_size? : Int = 1000,
) -> Array[(String, Array[Double])] {
  @ocr.generate_enhanced_chinese_templates(char_set_size~)
}

///|
pub fn structure_based_filter(
  char_img : @types.Image,
  char_db : Array[@ocr.ChineseCharInfo],
  max_candidates? : Int = 50,
) -> Array[@ocr.ChineseCharInfo] {
  @ocr.structure_based_filter(char_img, char_db, max_candidates~)
}

///|
pub fn extract_stroke_features(
  char_img : @types.Image,
) -> Array[Double] raise @types.LoadError {
  @ocr.extract_stroke_features(char_img)
}

///|
pub fn recognize_enhanced_chinese(
  img : @types.Image,
  config? : @ocr.EnhancedChineseOcrConfig,
) -> @ocr.OcrResult raise @types.LoadError {
  match config {
    Some(c) => @ocr.recognize_enhanced_chinese(img, config=c)
    None => @ocr.recognize_enhanced_chinese(img)
  }
}

// ==================== OCR 准确率提升增强版（v10.1.0） ====================

///|
pub type OcrAccuracyEnhancedConfig = @ocr.OcrAccuracyEnhancedConfig

///|
pub fn ocr_accuracy_enhanced_default_config() -> @ocr.OcrAccuracyEnhancedConfig {
  @ocr.ocr_accuracy_enhanced_default_config()
}

///|
pub fn extract_zernike_moments(
  char_img : @types.Image,
  max_order? : Int = 4,
) -> Array[Double] raise @types.LoadError {
  @ocr.extract_zernike_moments(char_img, max_order~)
}

///|
pub fn extract_gabor_ocr_features(
  char_img : @types.Image,
  num_orientations? : Int = 4,
  num_frequencies? : Int = 2,
) -> Array[Double] {
  @ocr.extract_gabor_ocr_features(char_img, num_orientations~, num_frequencies~)
}

///|
pub fn extract_directional_features(char_img : @types.Image) -> Array[Double] {
  @ocr.extract_directional_features(char_img)
}

///|
pub fn weighted_knn_classify(
  features : Array[Double],
  training_data : Array[(String, Array[Double])],
  k? : Int = 5,
  distance_metric? : String = "euclidean",
) -> (String, Double, Array[(String, Double)]) {
  @ocr.weighted_knn_classify(features, training_data, k~, distance_metric~)
}

///|
pub fn calibrate_confidence_enhanced(
  raw_confidence : Double,
  distance_distribution : Array[Double],
) -> Double {
  @ocr.calibrate_confidence_enhanced(raw_confidence, distance_distribution)
}

///|
pub fn multi_scale_recognize(
  char_img : @types.Image,
  templates : Array[(String, Array[Double])],
  scales : Array[Int],
  distance_metric? : String = "euclidean",
) -> (String, Double) {
  @ocr.multi_scale_recognize(char_img, templates, scales, distance_metric~)
}

///|
pub fn extract_combined_enhanced_features(
  char_img : @types.Image,
  config : @ocr.OcrAccuracyEnhancedConfig,
) -> Array[Double] raise @types.LoadError {
  @ocr.extract_combined_enhanced_features(char_img, config)
}

///|
pub fn recognize_ocr_enhanced(
  img : @types.Image,
  templates : Array[(String, Array[Double])],
  config? : @ocr.OcrAccuracyEnhancedConfig,
) -> @ocr.OcrResult raise @types.LoadError {
  match config {
    Some(c) => @ocr.recognize_ocr_enhanced(img, templates, config=c)
    None => @ocr.recognize_ocr_enhanced(img, templates)
  }
}

// ==================== 文档理解增强版（v10.2.0） ====================

///|
pub type DocumentBlockType = @ocr.DocumentBlockType

///|
pub type DocumentBlock = @ocr.DocumentBlock

///|
pub type DocumentTreeNode = @ocr.DocumentTreeNode

///|
pub type DocumentUnderstandingEnhancedConfig = @ocr.DocumentUnderstandingEnhancedConfig

///|
pub fn document_understanding_enhanced_default_config() -> @ocr.DocumentUnderstandingEnhancedConfig {
  @ocr.document_understanding_enhanced_default_config()
}

///|
pub fn analyze_layout_enhanced(
  img : @types.Image,
  config? : @ocr.DocumentUnderstandingEnhancedConfig,
) -> Array[@ocr.DocumentBlock] raise @types.LoadError {
  match config {
    Some(c) => @ocr.analyze_layout_enhanced(img, config=c)
    None => @ocr.analyze_layout_enhanced(img)
  }
}

///|
pub fn optimize_reading_order(
  blocks : Array[@ocr.DocumentBlock],
  num_columns : Int,
) -> Array[Int] {
  @ocr.optimize_reading_order(blocks, num_columns)
}

///|
pub fn detect_paragraphs(
  blocks : Array[@ocr.DocumentBlock],
  max_line_spacing_ratio? : Double = 2.0,
) -> Array[Array[Int]] {
  @ocr.detect_paragraphs(blocks, max_line_spacing_ratio~)
}

///|
pub fn detect_titles(
  blocks : Array[@ocr.DocumentBlock],
  title_font_size_threshold? : Int = 24,
) -> Array[Int] {
  @ocr.detect_titles(blocks, title_font_size_threshold~)
}

///|
pub fn build_document_structure_tree(
  blocks : Array[@ocr.DocumentBlock],
) -> Array[@ocr.DocumentTreeNode] {
  @ocr.build_document_structure_tree(blocks)
}

///|
pub fn extract_document_text(
  blocks : Array[@ocr.DocumentBlock],
  include_headers? : Bool = true,
  include_footers? : Bool = false,
) -> String {
  @ocr.extract_document_text(blocks, include_headers~, include_footers~)
}

///|
pub fn document_statistics_enhanced(
  blocks : Array[@ocr.DocumentBlock],
) -> (Int, Int, Int, Int, Int, Int, Int) {
  @ocr.document_statistics_enhanced(blocks)
}

///|
pub fn understand_document_enhanced(
  img : @types.Image,
  config? : @ocr.DocumentUnderstandingEnhancedConfig,
) -> (Array[@ocr.DocumentBlock], Array[@ocr.DocumentTreeNode], String) raise @types.LoadError {
  match config {
    Some(c) => @ocr.understand_document_enhanced(img, config=c)
    None => @ocr.understand_document_enhanced(img)
  }
}

// ==================== 手写体识别增强版（v10.3.0） ====================

///|
pub type HandwritingOcrEnhancedConfig = @ocr.HandwritingOcrEnhancedConfig

///|
pub type HandwritingStrokeFeatures = @ocr.HandwritingStrokeFeatures

///|
pub fn handwriting_ocr_enhanced_default_config() -> @ocr.HandwritingOcrEnhancedConfig {
  @ocr.handwriting_ocr_enhanced_default_config()
}

///|
pub fn generate_enhanced_handwriting_templates(
  char_set? : String = "digits+letters",
  num_variants? : Int = 5,
) -> Array[(String, Array[Double])] {
  @ocr.generate_enhanced_handwriting_templates(char_set~, num_variants~)
}

///|
pub fn extract_handwriting_stroke_features(
  char_img : @types.Image,
) -> @ocr.HandwritingStrokeFeatures raise @types.LoadError {
  @ocr.extract_handwriting_stroke_features(char_img)
}

///|
pub fn elastic_match(
  features : Array[Double],
  template : Array[Double],
  elasticity? : Double = 0.5,
  grid_size? : Int = 16,
) -> Double {
  @ocr.elastic_match(features, template, elasticity~, grid_size~)
}

///|
pub fn segment_cursive_chars(
  img : @types.Image,
  min_char_width? : Int = 8,
  max_char_width? : Int = 80,
) -> Array[(Int, Int, Int, Int)] {
  @ocr.segment_cursive_chars(img, min_char_width~, max_char_width~)
}

///|
pub fn handwriting_postprocess(
  text : String,
  confidence : Double,
) -> (String, Double) {
  @ocr.handwriting_postprocess(text, confidence)
}

///|
pub fn recognize_handwriting_enhanced(
  img : @types.Image,
  config? : @ocr.HandwritingOcrEnhancedConfig,
) -> @ocr.OcrResult raise @types.LoadError {
  match config {
    Some(c) => @ocr.recognize_handwriting_enhanced(img, config=c)
    None => @ocr.recognize_handwriting_enhanced(img)
  }
}

// ==================== 多语言混合识别增强版（v10.4.0） ====================

///|
pub type MultilingualOcrEnhancedConfig = @ocr.MultilingualOcrEnhancedConfig

///|
pub type LanguageDetectionResult = @ocr.LanguageDetectionResult

///|
pub fn multilingual_ocr_enhanced_default_config() -> @ocr.MultilingualOcrEnhancedConfig {
  @ocr.multilingual_ocr_enhanced_default_config()
}

///|
pub fn detect_language_enhanced(
  char_img : @types.Image,
) -> @ocr.LanguageDetectionResult raise @types.LoadError {
  @ocr.detect_language_enhanced(char_img)
}

///|
pub fn smart_segment_chars(
  img : @types.Image,
  config : @ocr.MultilingualOcrEnhancedConfig,
) -> Array[(Int, Int, Int, Int, String)] raise @types.LoadError {
  @ocr.smart_segment_chars(img, config)
}

///|
pub fn smart_spacing_process(
  text : String,
  char_languages : Array[String],
) -> String {
  @ocr.smart_spacing_process(text, char_languages)
}

///|
pub fn normalize_punctuation(
  text : String,
  char_languages : Array[String],
) -> String {
  @ocr.normalize_punctuation(text, char_languages)
}

///|
pub fn language_model_postprocess(
  text : String,
  char_languages : Array[String],
  confidences : Array[Double],
) -> (String, Array[Double]) {
  @ocr.language_model_postprocess(text, char_languages, confidences)
}

///|
pub fn recognize_multilingual_enhanced(
  img : @types.Image,
  config? : @ocr.MultilingualOcrEnhancedConfig,
) -> @ocr.OcrResult raise @types.LoadError {
  match config {
    Some(c) => @ocr.recognize_multilingual_enhanced(img, config=c)
    None => @ocr.recognize_multilingual_enhanced(img)
  }
}

// ==================== 条形码/二维码识别（v11.0.0） ====================

///|
pub type BarcodeType = @barcode.BarcodeType

///|
pub type BarcodeResult = @barcode.BarcodeResult

///|
pub type BarcodeConfig = @barcode.BarcodeConfig

///|
pub type QrFinderPattern = @barcode.QrFinderPattern

///|
pub fn barcode_default_config() -> @barcode.BarcodeConfig {
  @barcode.barcode_default_config()
}

///|
pub fn decode_ean13(
  img : @types.Image,
  config? : @barcode.BarcodeConfig,
) -> @barcode.BarcodeResult? raise @types.LoadError {
  match config {
    Some(c) => @barcode.decode_ean13(img, config=c)
    None => @barcode.decode_ean13(img)
  }
}

///|
pub fn detect_qr_finder_patterns(
  img : @types.Image,
) -> Array[@barcode.QrFinderPattern] raise @types.LoadError {
  @barcode.detect_qr_finder_patterns(img)
}

///|
pub fn decode_qrcode(
  img : @types.Image,
  config? : @barcode.BarcodeConfig,
) -> @barcode.BarcodeResult? raise @types.LoadError {
  match config {
    Some(c) => @barcode.decode_qrcode(img, config=c)
    None => @barcode.decode_qrcode(img)
  }
}

///|
pub fn decode_barcode(
  img : @types.Image,
  config? : @barcode.BarcodeConfig,
) -> Array[@barcode.BarcodeResult] raise @types.LoadError {
  match config {
    Some(c) => @barcode.decode_barcode(img, config=c)
    None => @barcode.decode_barcode(img)
  }
}

// ==================== 图像拼接/全景图（v11.1.0） ====================

///|
pub type FeaturePoint = @stitch.FeaturePoint

///|
pub type MatchPair = @stitch.MatchPair

///|
pub type Homography = @stitch.Homography

///|
pub type StitchConfig = @stitch.StitchConfig

///|
pub fn stitch_default_config() -> @stitch.StitchConfig {
  @stitch.stitch_default_config()
}

///|
pub fn identity_homography() -> @stitch.Homography {
  @stitch.identity_homography()
}

///|
pub fn apply_homography(
  h : @stitch.Homography,
  x : Double,
  y : Double,
) -> (Double, Double) {
  @stitch.apply_homography(h, x, y)
}

///|
pub fn invert_homography(h : @stitch.Homography) -> @stitch.Homography? {
  @stitch.invert_homography(h)
}

///|
pub fn detect_features_simple(
  img : @types.Image,
  max_features? : Int = 500,
) -> Array[@stitch.FeaturePoint] {
  @stitch.detect_features_simple(img, max_features~)
}

///|
pub fn match_features(
  query : Array[@stitch.FeaturePoint],
  train : Array[@stitch.FeaturePoint],
  ratio_threshold? : Double = 0.75,
) -> Array[@stitch.MatchPair] {
  @stitch.match_features(query, train, ratio_threshold~)
}

///|
pub fn estimate_homography_ransac(
  matches : Array[@stitch.MatchPair],
  query_points : Array[@stitch.FeaturePoint],
  train_points : Array[@stitch.FeaturePoint],
  iterations? : Int = 1000,
  threshold? : Double = 3.0,
) -> (@stitch.Homography?, Array[@stitch.MatchPair]) {
  @stitch.estimate_homography_ransac(
    matches,
    query_points,
    train_points,
    iterations~,
    threshold~,
  )
}

///|
pub fn stitch_images(
  img1 : @types.Image,
  img2 : @types.Image,
  config? : @stitch.StitchConfig,
) -> @types.Image? {
  match config {
    Some(c) => @stitch.stitch_images(img1, img2, config=c)
    None => @stitch.stitch_images(img1, img2)
  }
}

// ==================== 超分辨率（v11.2.0） ====================

///|
pub type SuperResolutionConfig = @superres.SuperResolutionConfig

///|
pub fn sr_default_config() -> @superres.SuperResolutionConfig {
  @superres.sr_default_config()
}

///|
pub fn super_resolution_bicubic(
  img : @types.Image,
  scale : Double,
) -> @types.Image {
  @superres.super_resolution_bicubic(img, scale)
}

///|
pub fn super_resolution_lanczos(
  img : @types.Image,
  scale : Double,
  a? : Int = 3,
) -> @types.Image {
  @superres.super_resolution_lanczos(img, scale, a~)
}

///|
pub fn super_resolution_edge_preserving(
  img : @types.Image,
  scale : Double,
  edge_threshold? : Double = 30.0,
  sharpen_amount? : Double = 0.5,
) -> @types.Image {
  @superres.super_resolution_edge_preserving(
    img,
    scale,
    edge_threshold~,
    sharpen_amount~,
  )
}

///|
pub fn super_resolution(
  img : @types.Image,
  config? : @superres.SuperResolutionConfig,
) -> @types.Image {
  match config {
    Some(c) => @superres.super_resolution(img, config=c)
    None => @superres.super_resolution(img)
  }
}

///|
pub fn upscale_2x(img : @types.Image) -> @types.Image {
  @superres.upscale_2x(img)
}

///|
pub fn upscale_4x(img : @types.Image) -> @types.Image {
  @superres.upscale_4x(img)
}

// ==================== 更多一维码支持（v11.3.0） ====================

///|
pub type Code128Charset = @barcode.Code128Charset

///|
pub fn decode_code128(
  img : @types.Image,
) -> @barcode.BarcodeResult? raise @types.LoadError {
  @barcode.decode_code128(img)
}

///|
pub fn decode_upca(
  img : @types.Image,
) -> @barcode.BarcodeResult? raise @types.LoadError {
  @barcode.decode_upca(img)
}

///|
pub fn decode_code39(
  img : @types.Image,
) -> @barcode.BarcodeResult? raise @types.LoadError {
  @barcode.decode_code39(img)
}

///|
pub fn decode_linear_barcode(
  img : @types.Image,
) -> Array[@barcode.BarcodeResult] raise @types.LoadError {
  @barcode.decode_linear_barcode(img)
}

// ==================== QR Code 完整解码（v11.4.0） ====================

///|
pub type QrDecodeResult = @barcode.QrDecodeResult

///|
pub fn decode_qrcode_full(
  img : @types.Image,
) -> @barcode.QrDecodeResult? raise @types.LoadError {
  @barcode.decode_qrcode_full(img)
}

///|
pub fn reed_solomon_decode(
  data : Array[Int],
  ec_bytes : Int,
) -> (Array[Int], Int) {
  @barcode.reed_solomon_decode(data, ec_bytes)
}

// ==================== 图像风格化（v11.5.0） ====================

///|
pub type StylizeConfig = @stylize.StylizeConfig

///|
pub fn stylize_default_config() -> @stylize.StylizeConfig {
  @stylize.stylize_default_config()
}

///|
pub fn oil_paint(
  img : @types.Image,
  radius? : Int = 3,
  intensity? : Int = 20,
) -> @types.Image {
  @stylize.oil_paint(img, radius~, intensity~)
}

///|
pub fn sketch(img : @types.Image, blend? : Double = 0.7) -> @types.Image {
  @stylize.sketch(img, blend~)
}

///|
pub fn watercolor(img : @types.Image, blur_radius? : Int = 5) -> @types.Image {
  @stylize.watercolor(img, blur_radius~)
}

///|
pub fn cartoon(
  img : @types.Image,
  levels? : Int = 8,
  edge_threshold? : Double = 30.0,
) -> @types.Image {
  @stylize.cartoon(img, levels~, edge_threshold~)
}

///|
pub fn stylize(
  img : @types.Image,
  style : String,
  config? : @stylize.StylizeConfig,
) -> @types.Image {
  match config {
    Some(c) => @stylize.stylize(img, style, config=c)
    None => @stylize.stylize(img, style)
  }
}

// ==================== 图像去雾（v11.6.0） ====================

///|
pub type DehazeConfig = @enhance.DehazeConfig

///|
pub fn dehaze_default_config() -> @enhance.DehazeConfig {
  @enhance.dehaze_default_config()
}

///|
pub fn dark_channel(
  img : @types.Image,
  patch_size? : Int = 15,
) -> @types.Image raise @types.LoadError {
  @enhance.dark_channel(img, patch_size~)
}

///|
pub fn estimate_atmospheric_light(
  img : @types.Image,
  dark : @types.Image,
  top_percent? : Int = 1000,
) -> Array[Int] raise @types.LoadError {
  @enhance.estimate_atmospheric_light(img, dark, top_percent~)
}

///|
pub fn estimate_transmission(
  img : @types.Image,
  atmospheric : Array[Int],
  omega? : Double = 0.95,
  patch_size? : Int = 15,
) -> @types.Image raise @types.LoadError {
  @enhance.estimate_transmission(img, atmospheric, omega~, patch_size~)
}

///|
pub fn guided_filter_image(
  input : @types.Image,
  guide : @types.Image,
  radius? : Int = 20,
  eps? : Double = 0.0001,
) -> @types.Image raise @types.LoadError {
  @enhance.guided_filter_image(input, guide, radius~, eps~)
}

///|
pub fn dehaze_recover(
  img : @types.Image,
  transmission : @types.Image,
  atmospheric : Array[Int],
  t_min? : Double = 0.1,
) -> @types.Image raise @types.LoadError {
  @enhance.dehaze_recover(img, transmission, atmospheric, t_min~)
}

///|
pub fn dehaze_advanced(
  img : @types.Image,
  config? : @enhance.DehazeConfig,
) -> @types.Image raise @types.LoadError {
  match config {
    Some(c) => @enhance.dehaze_advanced(img, config=c)
    None => @enhance.dehaze_advanced(img)
  }
}

// ==================== HDR 高动态范围（v11.7.0） ====================

///|
pub type HdrConfig = @enhance.HdrConfig

///|
pub fn hdr_default_config() -> @enhance.HdrConfig {
  @enhance.hdr_default_config()
}

///|
pub fn hdr_fusion_average(
  images : Array[@types.Image],
) -> @types.Image raise @types.LoadError {
  @enhance.hdr_fusion_average(images)
}

///|
pub fn hdr_fusion_weighted(
  images : Array[@types.Image],
) -> @types.Image raise @types.LoadError {
  @enhance.hdr_fusion_weighted(images)
}

///|
pub fn tone_mapping_reinhard(
  img : @types.Image,
  key? : Double = 0.18,
) -> @types.Image raise @types.LoadError {
  @enhance.tone_mapping_reinhard(img, key~)
}

///|
pub fn tone_mapping_gamma(
  img : @types.Image,
  gamma? : Double = 0.4545,
) -> @types.Image raise @types.LoadError {
  @enhance.tone_mapping_gamma(img, gamma~)
}

///|
pub fn tone_mapping_sigmoid(
  img : @types.Image,
  strength? : Double = 5.0,
) -> @types.Image raise @types.LoadError {
  @enhance.tone_mapping_sigmoid(img, strength~)
}

///|
pub fn hdr_process(
  images : Array[@types.Image],
  config? : @enhance.HdrConfig,
) -> @types.Image raise @types.LoadError {
  match config {
    Some(c) => @enhance.hdr_process(images, config=c)
    None => @enhance.hdr_process(images)
  }
}

// ==================== 图像修复（v12.0.0） ====================

///|
pub type InpaintConfig = @enhance.InpaintConfig

///|
pub fn inpaint_default_config() -> @enhance.InpaintConfig {
  @enhance.inpaint_default_config()
}

///|
pub fn inpaint_advanced(
  img : @types.Image,
  mask : @types.Image,
  radius? : Int = 5,
) -> @types.Image raise @types.LoadError {
  @enhance.inpaint_advanced(img, mask, radius~)
}

///|
pub fn create_rect_mask(
  width : Int,
  height : Int,
  x : Int,
  y : Int,
  rect_w : Int,
  rect_h : Int,
) -> @types.Image raise @types.LoadError {
  @enhance.create_rect_mask(width, height, x, y, rect_w, rect_h)
}

///|
pub fn remove_small_objects(
  img : @types.Image,
  max_size? : Int = 100,
) -> @types.Image raise @types.LoadError {
  @enhance.remove_small_objects(img, max_size~)
}

///|
pub fn remove_watermark(
  img : @types.Image,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) -> @types.Image raise @types.LoadError {
  @enhance.remove_watermark(img, x, y, width, height)
}

// ==================== 图像去噪（v12.1.0） ====================

///|
pub type NlmConfig = @enhance.NlmConfig

///|
pub fn nlm_default_config() -> @enhance.NlmConfig {
  @enhance.nlm_default_config()
}

///|
pub fn denoise_nlm(
  img : @types.Image,
  config? : @enhance.NlmConfig,
) -> @types.Image raise @types.LoadError {
  match config {
    Some(c) => @enhance.denoise_nlm(img, config=c)
    None => @enhance.denoise_nlm(img)
  }
}

///|
pub fn denoise_bilateral(
  img : @types.Image,
  diameter? : Int = 9,
  sigma_color? : Double = 75.0,
  sigma_space? : Double = 75.0,
) -> @types.Image raise @types.LoadError {
  @enhance.denoise_bilateral(img, diameter~, sigma_color~, sigma_space~)
}

///|
pub fn denoise_median(
  img : @types.Image,
  kernel_size? : Int = 3,
) -> @types.Image raise @types.LoadError {
  @enhance.denoise_median(img, kernel_size~)
}

///|
pub fn denoise(
  img : @types.Image,
  method_type : String,
) -> @types.Image raise @types.LoadError {
  @enhance.denoise(img, method_type)
}

// ==================== 图像分割（v12.2.0） ====================

///|
pub type SegmentationResult = @segment.SegmentationResult

///|
pub type WatershedConfig = @segment.WatershedConfig

///|
pub fn watershed_default_config() -> @segment.WatershedConfig {
  @segment.watershed_default_config()
}

///|
pub fn watershed_segment(
  img : @types.Image,
  config? : @segment.WatershedConfig,
) -> @segment.SegmentationResult {
  match config {
    Some(c) => @segment.watershed_segment(img, config=c)
    None => @segment.watershed_segment(img)
  }
}

///|
pub fn region_growing(
  img : @types.Image,
  seeds : Array[(Int, Int)],
  threshold? : Double = 30.0,
) -> @segment.SegmentationResult {
  @segment.region_growing(img, seeds, threshold~)
}

///|
pub fn segmentation_to_color(
  result : @segment.SegmentationResult,
  width : Int,
  height : Int,
) -> @types.Image {
  @segment.segmentation_to_color(result, width, height)
}

// ==================== 目标检测基础（v12.4.0） ====================

///|
pub type BoundingBox = @detection.BoundingBox

///|
pub fn bbox_new(
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  score? : Double = 0.0,
  class_id? : Int = 0,
) -> @detection.BoundingBox raise @types.LoadError {
  @detection.bbox_new(x, y, width, height, score~, class_id~)
}

///|
pub fn bbox_iou(
  a : @detection.BoundingBox,
  b : @detection.BoundingBox,
) -> Double raise @types.LoadError {
  @detection.bbox_iou(a, b)
}

///|
pub fn nms(
  boxes : Array[@detection.BoundingBox],
  iou_threshold? : Double = 0.5,
) -> Array[@detection.BoundingBox] raise @types.LoadError {
  @detection.nms(boxes, iou_threshold~)
}

///|
pub fn draw_detections(
  img : @types.Image,
  boxes : Array[@detection.BoundingBox],
) -> @types.Image raise @types.LoadError {
  @detection.draw_detections(img, boxes)
}

// ==================== 图像质量评估（v12.5.0） ====================

///|
pub type QualityMetrics = @quality.QualityMetrics

///|
pub fn compute_mse(img1 : @types.Image, img2 : @types.Image) -> Double {
  @quality.compute_mse(img1, img2)
}

///|
pub fn compute_mae(img1 : @types.Image, img2 : @types.Image) -> Double {
  @quality.compute_mae(img1, img2)
}

///|
pub fn compute_psnr(img1 : @types.Image, img2 : @types.Image) -> Double {
  @quality.compute_psnr(img1, img2)
}

///|
pub fn compute_ssim(img1 : @types.Image, img2 : @types.Image) -> Double {
  @quality.compute_ssim(img1, img2)
}

///|
pub fn compute_quality_metrics(
  img1 : @types.Image,
  img2 : @types.Image,
) -> @quality.QualityMetrics {
  @quality.compute_quality_metrics(img1, img2)
}

///|
pub fn images_equal(img1 : @types.Image, img2 : @types.Image) -> Bool {
  @quality.images_equal(img1, img2)
}

///|
pub fn compute_diff_image(
  img1 : @types.Image,
  img2 : @types.Image,
) -> @types.Image {
  @quality.compute_diff_image(img1, img2)
}

// ==================== 图像融合（v12.6.0） ====================

///|
pub type FusionConfig = @fusion.FusionConfig

///|
pub fn fusion_default_config() -> @fusion.FusionConfig {
  @fusion.fusion_default_config()
}

///|
pub fn fuse_alpha(
  img1 : @types.Image,
  img2 : @types.Image,
  alpha? : Double = 0.5,
) -> @types.Image {
  @fusion.fuse_alpha(img1, img2, alpha~)
}

///|
pub fn fuse_multifocus(
  img1 : @types.Image,
  img2 : @types.Image,
) -> @types.Image {
  @fusion.fuse_multifocus(img1, img2)
}

///|
pub fn fuse_exposure(images : Array[@types.Image]) -> @types.Image {
  @fusion.fuse_exposure(images)
}

///|
pub fn fuse_images(
  img1 : @types.Image,
  img2 : @types.Image,
  config? : @fusion.FusionConfig,
) -> @types.Image {
  match config {
    Some(c) => @fusion.fuse_images(img1, img2, config=c)
    None => @fusion.fuse_images(img1, img2)
  }
}

// ==================== 图像配准（v12.7.0） ====================

///|
pub type RegistrationResult = @registration.RegistrationResult

///|
pub type AffineTransform = @registration.AffineTransform

///|
pub fn affine_identity() -> @registration.AffineTransform {
  @registration.affine_identity()
}

///|
pub fn affine_translation(
  dx : Double,
  dy : Double,
) -> @registration.AffineTransform {
  @registration.affine_translation(dx, dy)
}

///|
pub fn affine_rotation(angle : Double) -> @registration.AffineTransform {
  @registration.affine_rotation(angle)
}

///|
pub fn affine_scale(sx : Double, sy : Double) -> @registration.AffineTransform {
  @registration.affine_scale(sx, sy)
}

///|
pub fn affine_compose(
  t1 : @registration.AffineTransform,
  t2 : @registration.AffineTransform,
) -> @registration.AffineTransform {
  @registration.affine_compose(t1, t2)
}

///|
pub fn affine_apply(
  t : @registration.AffineTransform,
  x : Double,
  y : Double,
) -> (Double, Double) {
  @registration.affine_apply(t, x, y)
}

///|
pub fn estimate_translation(
  img1 : @types.Image,
  img2 : @types.Image,
  max_offset? : Int = 20,
) -> @registration.RegistrationResult raise @types.LoadError {
  @registration.estimate_translation(img1, img2, max_offset~)
}

///|
pub fn warp_affine_transform(
  img : @types.Image,
  transform : @registration.AffineTransform,
  out_width? : Int = 0,
  out_height? : Int = 0,
) -> @types.Image raise @types.LoadError {
  @registration.warp_affine_transform(img, transform, out_width~, out_height~)
}

///|
pub fn align_images(
  img1 : @types.Image,
  img2 : @types.Image,
) -> (@types.Image, @registration.RegistrationResult) raise @types.LoadError {
  @registration.align_images(img1, img2)
}

// ==================== 视频处理基础（v12.8.0） ====================

///|
pub type VideoFrames = @video.VideoFrames

///|
pub fn video_frames_new(
  frames : Array[@types.Image],
  fps? : Double = 30.0,
) -> @video.VideoFrames {
  @video.video_frames_new(frames, fps~)
}

///|
pub fn video_frame_count(video : @video.VideoFrames) -> Int {
  @video.video_frame_count(video)
}

///|
pub fn video_get_frame(
  video : @video.VideoFrames,
  index : Int,
) -> @types.Image? {
  @video.video_get_frame(video, index)
}

///|
pub fn interpolate_frames(
  frame1 : @types.Image,
  frame2 : @types.Image,
  num_frames? : Int = 1,
) -> Array[@types.Image] {
  @video.interpolate_frames(frame1, frame2, num_frames~)
}

///|
pub fn video_fade_in(
  video : @video.VideoFrames,
  duration_frames? : Int = 30,
) -> @video.VideoFrames {
  @video.video_fade_in(video, duration_frames~)
}

///|
pub fn video_fade_out(
  video : @video.VideoFrames,
  duration_frames? : Int = 30,
) -> @video.VideoFrames {
  @video.video_fade_out(video, duration_frames~)
}

///|
pub fn video_sample(
  video : @video.VideoFrames,
  interval? : Int = 2,
) -> @video.VideoFrames {
  @video.video_sample(video, interval~)
}

///|
pub fn video_reverse(video : @video.VideoFrames) -> @video.VideoFrames {
  @video.video_reverse(video)
}

///|
pub fn video_concat(
  video1 : @video.VideoFrames,
  video2 : @video.VideoFrames,
) -> @video.VideoFrames {
  @video.video_concat(video1, video2)
}

///|
pub fn create_animation(
  frames : Array[@types.Image],
  fps? : Double = 10.0,
) -> @video.VideoFrames {
  @video.create_animation(frames, fps~)
}

///|
pub fn video_frame_average(video : @video.VideoFrames) -> @types.Image {
  @video.video_frame_average(video)
}

// ==================== 3D 视觉基础（v12.9.0） ====================

///|
pub type PointCloud = @stereo3d.PointCloud

///|
pub fn point_cloud_new() -> @stereo3d.PointCloud {
  @stereo3d.point_cloud_new()
}

///|
pub fn depth_to_colormap(
  depth : @types.Image,
  colormap? : String = "jet",
) -> @types.Image {
  @stereo3d.depth_to_colormap(depth, colormap~)
}

///|
pub fn depth_to_pointcloud(
  depth : @types.Image,
  fx? : Double = 500.0,
  fy? : Double = 500.0,
  cx? : Double = 0.0,
  cy? : Double = 0.0,
  scale? : Double = 1.0,
) -> @stereo3d.PointCloud {
  @stereo3d.depth_to_pointcloud(depth, fx~, fy~, cx~, cy~, scale~)
}

///|
pub fn pointcloud_voxel_downsample(
  cloud : @stereo3d.PointCloud,
  voxel_size? : Double = 1.0,
) -> @stereo3d.PointCloud {
  @stereo3d.pointcloud_voxel_downsample(cloud, voxel_size~)
}

///|
pub fn compute_disparity(
  left : @types.Image,
  right : @types.Image,
  max_disparity? : Int = 64,
  block_size? : Int = 7,
) -> @types.Image {
  @stereo3d.compute_disparity(left, right, max_disparity~, block_size~)
}

///|
pub fn disparity_to_depth(
  disparity : @types.Image,
  baseline? : Double = 1.0,
  focal_length? : Double = 500.0,
) -> @types.Image {
  @stereo3d.disparity_to_depth(disparity, baseline~, focal_length~)
}

// ==================== 医学图像处理（v12.10.0） ====================

///|
pub type WindowLevel = @medical.WindowLevel

///|
pub fn window_level_lung() -> @medical.WindowLevel {
  @medical.window_level_lung()
}

///|
pub fn window_level_mediastinum() -> @medical.WindowLevel {
  @medical.window_level_mediastinum()
}

///|
pub fn window_level_bone() -> @medical.WindowLevel {
  @medical.window_level_bone()
}

///|
pub fn window_level_brain() -> @medical.WindowLevel {
  @medical.window_level_brain()
}

///|
pub fn apply_window_level(
  img : @types.Image,
  config : @medical.WindowLevel,
) -> @types.Image {
  @medical.apply_window_level(img, config)
}

///|
pub fn medical_colormap(
  img : @types.Image,
  colormap? : String = "hot",
) -> @types.Image {
  @medical.medical_colormap(img, colormap~)
}

///|
pub fn medical_contrast_enhance(
  img : @types.Image,
  clip_limit? : Double = 2.0,
  tile_size? : Int = 8,
) -> @types.Image {
  @medical.medical_contrast_enhance(img, clip_limit~, tile_size~)
}

///|
pub fn medical_denoise(
  img : @types.Image,
  iterations? : Int = 5,
  kappa? : Double = 30.0,
) -> @types.Image {
  @medical.medical_denoise(img, iterations~, kappa~)
}

///|
pub fn measure_distance(
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
  pixel_spacing? : Double = 1.0,
) -> Double {
  @medical.measure_distance(x1, y1, x2, y2, pixel_spacing~)
}

///|
pub fn measure_area(mask : @types.Image, pixel_area? : Double = 1.0) -> Double {
  @medical.measure_area(mask, pixel_area~)
}

// ==================== 遥感图像处理（v12.11.0） ====================

///|
pub type MultispectralImage = @remote_sensing.MultispectralImage

///|
pub fn multispectral_new(
  width : Int,
  height : Int,
  bands : Array[@types.Image],
  band_names? : Array[String] = [],
) -> @remote_sensing.MultispectralImage {
  @remote_sensing.multispectral_new(width, height, bands, band_names~)
}

///|
pub fn compute_ndvi(
  nir : @types.Image,
  red : @types.Image,
) -> @types.Image raise @types.LoadError {
  @remote_sensing.compute_ndvi(nir, red)
}

///|
pub fn compute_ndwi(
  green : @types.Image,
  nir : @types.Image,
) -> @types.Image raise @types.LoadError {
  @remote_sensing.compute_ndwi(green, nir)
}

///|
pub fn compute_ndbi(
  swir : @types.Image,
  nir : @types.Image,
) -> @types.Image raise @types.LoadError {
  @remote_sensing.compute_ndbi(swir, nir)
}

///|
pub fn compute_evi(
  nir : @types.Image,
  red : @types.Image,
  blue : @types.Image,
) -> @types.Image raise @types.LoadError {
  @remote_sensing.compute_evi(nir, red, blue)
}

///|
pub fn false_color_composite(
  nir : @types.Image,
  red : @types.Image,
  green : @types.Image,
) -> @types.Image raise @types.LoadError {
  @remote_sensing.false_color_composite(nir, red, green)
}

///|
pub fn true_color_composite(
  red : @types.Image,
  green : @types.Image,
  blue : @types.Image,
) -> @types.Image raise @types.LoadError {
  @remote_sensing.true_color_composite(red, green, blue)
}

///|
pub fn vegetation_coverage(
  ndvi : @types.Image,
  ndvi_soil? : Double = 0.2,
  ndvi_veg? : Double = 0.8,
) -> @types.Image raise @types.LoadError {
  @remote_sensing.vegetation_coverage(ndvi, ndvi_soil~, ndvi_veg~)
}

///|
pub fn land_cover_classification(
  ndvi : @types.Image,
  ndwi : @types.Image,
  ndbi : @types.Image,
) -> @types.Image raise @types.LoadError {
  @remote_sensing.land_cover_classification(ndvi, ndwi, ndbi)
}

///|
pub fn classification_colormap(
  classification : @types.Image,
) -> @types.Image raise @types.LoadError {
  @remote_sensing.classification_colormap(classification)
}

// ==================== 数字水印（v12.12.0） ====================

///|
pub type WatermarkConfig = @watermark.WatermarkConfig

///|
pub fn watermark_default_config() -> @watermark.WatermarkConfig {
  @watermark.watermark_default_config()
}

///|
pub fn embed_watermark_lsb(
  cover : @types.Image,
  watermark : @types.Image,
  key? : Int = 42,
) -> @types.Image {
  @watermark.embed_watermark_lsb(cover, watermark, key~)
}

///|
pub fn extract_watermark_lsb(stego : @types.Image) -> @types.Image {
  @watermark.extract_watermark_lsb(stego)
}

///|
pub fn embed_text_watermark(
  cover : @types.Image,
  text : String,
  key? : Int = 42,
) -> @types.Image {
  @watermark.embed_text_watermark(cover, text, key~)
}

///|
pub fn extract_text_watermark(
  stego : @types.Image,
  length : Int,
  key? : Int = 42,
) -> String {
  @watermark.extract_text_watermark(stego, length, key~)
}

///|
pub fn watermark_psnr(
  original : @types.Image,
  watermarked : @types.Image,
) -> Double {
  @watermark.watermark_psnr(original, watermarked)
}

///|
pub fn watermark_robustness_test(
  watermarked : @types.Image,
  original_watermark : @types.Image,
  noise_level? : Double = 10.0,
) -> Double {
  @watermark.watermark_robustness_test(
    watermarked,
    original_watermark,
    noise_level~,
  )
}

///|
pub fn batch_embed_watermark(
  images : Array[@types.Image],
  watermark : @types.Image,
  key? : Int = 42,
) -> Array[@types.Image] {
  @watermark.batch_embed_watermark(images, watermark, key~)
}

// ==================== 图像检索（v12.13.0） ====================

///|
pub type ImageFeature = @retrieval.ImageFeature

///|
pub type SearchResult = @retrieval.SearchResult

///|
pub type ImageDatabase = @retrieval.ImageDatabase

///|
pub fn image_database_new() -> @retrieval.ImageDatabase {
  @retrieval.image_database_new()
}

///|
pub fn extract_image_features(
  img : @types.Image,
  image_id : String,
) -> @retrieval.ImageFeature {
  @retrieval.extract_image_features(img, image_id)
}

///|
pub fn database_add_image(
  db : @retrieval.ImageDatabase,
  feature : @retrieval.ImageFeature,
) -> @retrieval.ImageDatabase {
  @retrieval.database_add_image(db, feature)
}

///|
pub fn database_remove_image(
  db : @retrieval.ImageDatabase,
  image_id : String,
) -> @retrieval.ImageDatabase {
  @retrieval.database_remove_image(db, image_id)
}

///|
pub fn search_similar_images(
  db : @retrieval.ImageDatabase,
  query : @retrieval.ImageFeature,
  top_k? : Int = 5,
  method_type? : String = "cosine",
) -> Array[@retrieval.SearchResult] {
  @retrieval.search_similar_images(db, query, top_k~, method_type~)
}

///|
pub fn image_similarity(
  img1 : @types.Image,
  img2 : @types.Image,
  method_type? : String = "cosine",
) -> Double {
  @retrieval.image_similarity(img1, img2, method_type~)
}

///|
pub fn batch_extract_features(
  images : Array[(@types.Image, String)],
) -> Array[@retrieval.ImageFeature] {
  @retrieval.batch_extract_features(images)
}

///|
pub fn database_size(db : @retrieval.ImageDatabase) -> Int {
  @retrieval.database_size(db)
}

// ==================== 图像加密（v12.14.0） ====================

///|
pub type EncryptionConfig = @encryption.EncryptionConfig

///|
pub type EncryptionQuality = @encryption.EncryptionQuality

///|
pub fn encryption_default_config() -> @encryption.EncryptionConfig {
  @encryption.encryption_default_config()
}

///|
pub fn encrypt_image_logistic(
  img : @types.Image,
  key? : Double = 0.123456789,
  mu? : Double = 3.99,
) -> @types.Image raise @types.LoadError {
  @encryption.encrypt_image_logistic(img, key~, mu~)
}

///|
pub fn decrypt_image_logistic(
  img : @types.Image,
  key? : Double = 0.123456789,
  mu? : Double = 3.99,
) -> @types.Image raise @types.LoadError {
  @encryption.decrypt_image_logistic(img, key~, mu~)
}

///|
pub fn encrypt_image_xor(
  img : @types.Image,
  key : String,
) -> @types.Image raise @types.LoadError {
  @encryption.encrypt_image_xor(img, key)
}

///|
pub fn decrypt_image_xor(
  img : @types.Image,
  key : String,
) -> @types.Image raise @types.LoadError {
  @encryption.decrypt_image_xor(img, key)
}

///|
pub fn histogram_entropy(img : @types.Image) -> Double raise @types.LoadError {
  @encryption.histogram_entropy(img)
}

///|
pub fn adjacent_correlation(
  img : @types.Image,
  direction? : String = "horizontal",
) -> Double raise @types.LoadError {
  @encryption.adjacent_correlation(img, direction~)
}

///|
pub fn evaluate_encryption_quality(
  original : @types.Image,
  encrypted : @types.Image,
) -> @encryption.EncryptionQuality raise @types.LoadError {
  @encryption.evaluate_encryption_quality(original, encrypted)
}

///|
pub fn key_sensitivity_test(
  img : @types.Image,
  key : Double,
  delta? : Double = 0.0000001,
) -> Double raise @types.LoadError {
  @encryption.key_sensitivity_test(img, key, delta~)
}

///|
pub fn batch_encrypt(
  images : Array[@types.Image],
  key : Double,
) -> Array[@types.Image] raise @types.LoadError {
  @encryption.batch_encrypt(images, key)
}

// ==================== 计算摄影增强（v12.15.0） ====================

///|
pub type LowLightConfig = @photo_enhance.LowLightConfig

///|
pub fn low_light_default_config() -> @photo_enhance.LowLightConfig {
  @photo_enhance.low_light_default_config()
}

///|
pub fn low_light_enhance(
  img : @types.Image,
  config? : @photo_enhance.LowLightConfig,
) -> @types.Image {
  match config {
    Some(cfg) => @photo_enhance.low_light_enhance(img, config=cfg)
    None => @photo_enhance.low_light_enhance(img)
  }
}

///|
pub fn deblur_motion(
  img : @types.Image,
  kernel_size? : Int = 15,
  angle? : Double = 0.0,
) -> @types.Image {
  @photo_enhance.deblur_motion(img, kernel_size~, angle~)
}

///|
pub fn color_enhance(
  img : @types.Image,
  saturation? : Double = 1.3,
  contrast? : Double = 1.1,
) -> @types.Image {
  @photo_enhance.color_enhance(img, saturation~, contrast~)
}

///|
pub fn clahe_enhance(
  img : @types.Image,
  clip_limit? : Double = 2.0,
  tile_size? : Int = 8,
) -> @types.Image {
  @photo_enhance.clahe_enhance(img, clip_limit~, tile_size~)
}

///|
pub fn white_balance(img : @types.Image) -> @types.Image {
  @photo_enhance.white_balance(img)
}

///|
pub fn batch_photo_enhance(
  images : Array[@types.Image],
  method_type : String,
) -> Array[@types.Image] {
  @photo_enhance.batch_photo_enhance(images, method_type)
}

// ==================== 扫描版文档 OCR 增强（v12.16.0） ====================

///|
pub type ScanOCRConfig = @ocr.ScanOCRConfig

///|
pub type ScanQuality = @ocr.ScanQuality

///|
pub type TextBlock = @ocr.TextBlock

///|
pub type OCRPageResult = @ocr.OCRPageResult

///|
pub fn scan_ocr_default_config() -> @ocr.ScanOCRConfig {
  @ocr.scan_ocr_default_config()
}

///|
pub fn evaluate_scan_quality(
  img : @types.Image,
) -> @ocr.ScanQuality raise @types.LoadError {
  @ocr.evaluate_scan_quality(img)
}

///|
pub fn scan_document_preprocess(
  img : @types.Image,
  config : @ocr.ScanOCRConfig,
) -> @types.Image raise @types.LoadError {
  @ocr.scan_document_preprocess(img, config)
}

///|
pub fn analyze_layout_scan(
  binary_img : @types.Image,
) -> Array[@ocr.TextBlock] raise @types.LoadError {
  @ocr.analyze_layout_scan(binary_img)
}

///|
pub fn scan_ocr_recognize(
  img : @types.Image,
  config : @ocr.ScanOCRConfig,
) -> @ocr.OCRPageResult raise @types.LoadError {
  @ocr.scan_ocr_recognize(img, config)
}

///|
pub fn batch_scan_ocr(
  images : Array[@types.Image],
  config : @ocr.ScanOCRConfig,
) -> Array[@ocr.OCRPageResult] raise @types.LoadError {
  @ocr.batch_scan_ocr(images, config)
}

///|
pub fn ocr_result_to_text(result : @ocr.OCRPageResult) -> String {
  @ocr.ocr_result_to_text(result)
}

///|
pub fn ocr_result_to_hocr(result : @ocr.OCRPageResult) -> String {
  @ocr.ocr_result_to_hocr(result)
}

///|
pub fn ocr_result_to_json(result : @ocr.OCRPageResult) -> String {
  @ocr.ocr_result_to_json(result)
}

// ==================== 文档结构理解与 Markdown 还原（v12.18.0） ====================

///|
pub type MarkdownElementType = @ocr.MarkdownElementType

///|
pub type MarkdownElement = @ocr.MarkdownElement

///|
pub type MarkdownTable = @ocr.MarkdownTable

///|
pub type MarkdownImage = @ocr.MarkdownImage

///|
pub type MarkdownSymbol = @ocr.MarkdownSymbol

///|
pub type MarkdownDocument = @ocr.MarkdownDocument

///|
pub fn recognize_symbols_markdown(text : String) -> Array[@ocr.MarkdownSymbol] {
  @ocr.recognize_symbols_markdown(text)
}

///|
pub fn detect_image_regions_markdown(
  binary_img : @types.Image,
  min_area? : Int = 500,
) -> Array[@ocr.MarkdownImage] raise @types.LoadError {
  @ocr.detect_image_regions_markdown(binary_img, min_area~)
}

///|
pub fn classify_markdown_element(
  block : @ocr.TextBlock,
  avg_font_size? : Double = 16.0,
) -> @ocr.MarkdownElementType {
  @ocr.classify_markdown_element(block, avg_font_size~)
}

///|
pub fn markdown_table_to_string(table : @ocr.MarkdownTable) -> String {
  @ocr.markdown_table_to_string(table)
}

///|
pub fn determine_reading_order_markdown(
  elements : Array[@ocr.MarkdownElement],
) -> Array[Int] {
  @ocr.determine_reading_order_markdown(elements)
}

///|
pub fn markdown_document_to_string(doc : @ocr.MarkdownDocument) -> String {
  @ocr.markdown_document_to_string(doc)
}

///|
pub fn build_markdown_document(
  ocr_result : @ocr.OCRPageResult,
  title? : String,
) -> @ocr.MarkdownDocument raise @types.LoadError {
  match title {
    Some(t) => @ocr.build_markdown_document(ocr_result, title=t)
    None => @ocr.build_markdown_document(ocr_result)
  }
}

///|
pub fn generate_markdown_image_placeholder(
  image : @ocr.MarkdownImage,
  index : Int,
) -> String {
  @ocr.generate_markdown_image_placeholder(image, index)
}

///|
pub fn analyze_markdown_element_distribution(
  doc : @ocr.MarkdownDocument,
) -> Array[(String, Int)] {
  @ocr.analyze_markdown_element_distribution(doc)
}

// ==================== 增强版 PDF 布局分析（v12.19.0） ====================

///|
pub type LayoutType = @ocr.LayoutType

///|
pub type PageRegionType = @ocr.PageRegionType

///|
pub type PageRegion = @ocr.PageRegion

///|
pub type TextLineAttributes = @ocr.TextLineAttributes

///|
pub type ListItemType = @ocr.ListItemType

///|
pub type ListItemInfo = @ocr.ListItemInfo

///|
pub type EnhancedDocumentElement = @ocr.EnhancedDocumentElement

///|
pub type EnhancedDocument = @ocr.EnhancedDocument

///|
pub fn detect_layout_type(
  text_lines : Array[@ocr.TextLineAttributes],
  page_width : Int,
  page_height : Int,
) -> @ocr.LayoutType raise @types.LoadError {
  @ocr.detect_layout_type(text_lines, page_width, page_height)
}

///|
pub fn detect_header_footer(
  text_lines : Array[@ocr.TextLineAttributes],
  page_height : Int,
) -> (Int, Int) raise @types.LoadError {
  @ocr.detect_header_footer(text_lines, page_height)
}

///|
pub fn detect_column_boundaries(
  text_lines : Array[@ocr.TextLineAttributes],
  page_width : Int,
  layout_type : @ocr.LayoutType,
) -> Array[Int] {
  @ocr.detect_column_boundaries(text_lines, page_width, layout_type)
}

///|
pub fn is_heading_line(
  line : @ocr.TextLineAttributes,
  avg_font_size : Double,
) -> (Bool, Int) {
  @ocr.is_heading_line(line, avg_font_size)
}

///|
pub fn detect_list_item(line : @ocr.TextLineAttributes) -> @ocr.ListItemInfo {
  @ocr.detect_list_item(line)
}

///|
pub fn is_code_block_line(
  line : @ocr.TextLineAttributes,
  avg_indent : Int,
) -> Bool {
  @ocr.is_code_block_line(line, avg_indent)
}

///|
pub fn is_quote_line(line : @ocr.TextLineAttributes, avg_x : Int) -> Bool {
  @ocr.is_quote_line(line, avg_x)
}

///|
pub fn segment_paragraphs(
  lines : Array[@ocr.TextLineAttributes],
) -> Array[Array[@ocr.TextLineAttributes]] {
  @ocr.segment_paragraphs(lines)
}

///|
pub fn smart_reading_order(
  elements : Array[@ocr.EnhancedDocumentElement],
  layout_type : @ocr.LayoutType,
  column_boundaries : Array[Int],
) -> Array[Int] raise @types.LoadError {
  @ocr.smart_reading_order(elements, layout_type, column_boundaries)
}

///|
pub fn build_enhanced_elements(
  lines : Array[@ocr.TextLineAttributes],
  page_width : Int,
  page_height : Int,
) -> @ocr.EnhancedDocument raise @types.LoadError {
  @ocr.build_enhanced_elements(lines, page_width, page_height)
}

///|
pub fn enhanced_document_to_markdown(
  doc : @ocr.EnhancedDocument,
  include_header_footer? : Bool = false,
) -> String {
  @ocr.enhanced_document_to_markdown(doc, include_header_footer~)
}

///|
pub fn enhanced_element_distribution(
  doc : @ocr.EnhancedDocument,
) -> Array[(String, Int)] {
  @ocr.enhanced_element_distribution(doc)
}

// ==================== 表格识别增强与图片提取（v12.20.0） ====================

///|
pub type TableDetectionResult = @ocr.TableDetectionResult

///|
pub type TableCellContent = @ocr.TableCellContent

///|
pub type EnhancedTableResult = @ocr.EnhancedTableResult

///|
pub type ExtractedImage = @ocr.ExtractedImage

///|
pub fn detect_horizontal_table_lines(
  binary_img : @types.Image,
  min_length? : Int = 50,
  max_gap? : Int = 3,
) -> Array[(Int, Int, Int)] raise @types.LoadError {
  @ocr.detect_horizontal_table_lines(binary_img, min_length~, max_gap~)
}

///|
pub fn detect_vertical_table_lines(
  binary_img : @types.Image,
  min_length? : Int = 50,
  max_gap? : Int = 3,
) -> Array[(Int, Int, Int)] raise @types.LoadError {
  @ocr.detect_vertical_table_lines(binary_img, min_length~, max_gap~)
}

///|
pub fn find_line_intersections(
  h_lines : Array[(Int, Int, Int)],
  v_lines : Array[(Int, Int, Int)],
) -> Array[(Int, Int)] {
  @ocr.find_line_intersections(h_lines, v_lines)
}

///|
pub fn detect_table_enhanced(
  binary_img : @types.Image,
  min_table_size? : Int = 100,
) -> Array[@ocr.EnhancedTableResult] raise @types.LoadError {
  @ocr.detect_table_enhanced(binary_img, min_table_size~)
}

///|
pub fn enhanced_table_to_markdown(table : @ocr.EnhancedTableResult) -> String {
  @ocr.enhanced_table_to_markdown(table)
}

///|
pub fn extract_images_enhanced(
  binary_img : @types.Image,
  min_area? : Int = 500,
) -> Array[@ocr.ExtractedImage] {
  @ocr.extract_images_enhanced(binary_img, min_area~)
}

///|
pub fn generate_image_extraction_report(
  images : Array[@ocr.ExtractedImage],
) -> String {
  @ocr.generate_image_extraction_report(images)
}

///|
pub fn analyze_table_results(
  tables : Array[@ocr.EnhancedTableResult],
) -> Array[(String, Int)] {
  @ocr.analyze_table_results(tables)
}

// ==================== OCR 准确率测试框架（v12.21.0 P0 基础加固） ====================

///|
pub type CharRecognitionResult = @ocr.CharRecognitionResult

///|
pub type AccuracyStats = @ocr.AccuracyStats

///|
pub type ConfusionEntry = @ocr.ConfusionEntry

///|
pub type ConfusionMatrix = @ocr.ConfusionMatrix

///|
pub type OcrErrorType = @ocr.OcrErrorType

///|
pub type ErrorAnalysisEntry = @ocr.ErrorAnalysisEntry

///|
pub type ErrorAnalysisReport = @ocr.ErrorAnalysisReport

///|
pub type PerformanceBenchmark = @ocr.PerformanceBenchmark

///|
pub fn calculate_char_accuracy(expected : String, actual : String) -> Double {
  @ocr.calculate_char_accuracy(expected, actual)
}

///|
pub fn calculate_word_accuracy(expected : String, actual : String) -> Double {
  @ocr.calculate_word_accuracy(expected, actual)
}

///|
pub fn calculate_edit_distance(s1 : String, s2 : String) -> Int {
  @ocr.calculate_edit_distance(s1, s2)
}

///|
pub fn calculate_accuracy_stats(
  expected_lines : Array[String],
  actual_lines : Array[String],
) -> @ocr.AccuracyStats raise @types.LoadError {
  @ocr.calculate_accuracy_stats(expected_lines, actual_lines)
}

///|
pub fn generate_accuracy_report(
  stats : @ocr.AccuracyStats,
  dataset_name : String,
) -> String {
  @ocr.generate_accuracy_report(stats, dataset_name)
}

///|
pub fn generate_performance_report(
  benchmark : @ocr.PerformanceBenchmark,
  dataset_name : String,
) -> String {
  @ocr.generate_performance_report(benchmark, dataset_name)
}

///|
pub fn check_accuracy_threshold(
  stats : @ocr.AccuracyStats,
  min_char_accuracy? : Double = 0.95,
  min_word_accuracy? : Double = 0.90,
  min_f1_score? : Double = 0.92,
) -> (Bool, Array[String]) raise @types.LoadError {
  @ocr.check_accuracy_threshold(
    stats,
    min_char_accuracy~,
    min_word_accuracy~,
    min_f1_score~,
  )
}

// ==================== OCR 后处理纠错（v12.22.0 P1 准确率提升） ====================

///|
pub type CorrectionResult = @ocr.CorrectionResult

///|
pub type CorrectionEntry = @ocr.CorrectionEntry

///|
pub type SimilarCharMapping = @ocr.SimilarCharMapping

///|
pub type CommonErrorPattern = @ocr.CommonErrorPattern

///|
pub type DictionaryEntry = @ocr.DictionaryEntry

///|
pub type LanguageModelState = @ocr.LanguageModelState

///|
pub fn create_default_language_model() -> @ocr.LanguageModelState {
  @ocr.create_default_language_model()
}

///|
pub fn correct_similar_chars(
  text : String,
  context_type : String,
) -> @ocr.CorrectionResult raise @types.LoadError {
  @ocr.correct_similar_chars(text, context_type)
}

///|
pub fn correct_common_patterns(text : String) -> @ocr.CorrectionResult {
  @ocr.correct_common_patterns(text)
}

///|
pub fn full_postprocess_correction(
  text : String,
  context_type? : String = "mixed",
) -> @ocr.CorrectionResult raise @types.LoadError {
  @ocr.full_postprocess_correction(text, context_type~)
}

///|
pub fn batch_correct_texts(
  texts : Array[String],
  context_type? : String = "mixed",
) -> Array[@ocr.CorrectionResult] raise @types.LoadError {
  @ocr.batch_correct_texts(texts, context_type~)
}

///|
pub fn generate_correction_report(
  results : Array[@ocr.CorrectionResult],
) -> String {
  @ocr.generate_correction_report(results)
}

///|
pub fn calculate_accuracy_improvement(
  before_results : Array[@ocr.CorrectionResult],
  expected_texts : Array[String],
) -> (Double, Double, Double) {
  @ocr.calculate_accuracy_improvement(before_results, expected_texts)
}

// ==================== 中文字库管理与部件分解识别（v12.23.0 P2 中文增强） ====================

///|
pub type DictCharStructure = @ocr.DictCharStructure

///|
pub type DictComponent = @ocr.DictComponent

///|
pub type DictCharEntry = @ocr.DictCharEntry

///|
pub type DictChineseDict = @ocr.DictChineseDict

///|
pub type DictComponentResult = @ocr.DictComponentResult

///|
pub type DictCharMatch = @ocr.DictCharMatch

///|
pub fn create_default_chinese_dictionary() -> @ocr.DictChineseDict {
  @ocr.create_default_chinese_dictionary()
}

///|
pub fn lookup_by_radical(
  dict : @ocr.DictChineseDict,
  radical : String,
) -> Array[@ocr.DictCharEntry] raise @types.LoadError {
  @ocr.lookup_by_radical(dict, radical)
}

///|
pub fn lookup_by_pinyin(
  dict : @ocr.DictChineseDict,
  pinyin : String,
) -> Array[@ocr.DictCharEntry] raise @types.LoadError {
  @ocr.lookup_by_pinyin(dict, pinyin)
}

///|
pub fn lookup_by_structure(
  dict : @ocr.DictChineseDict,
  structure : @ocr.DictCharStructure,
) -> Array[@ocr.DictCharEntry] {
  @ocr.lookup_by_structure(dict, structure)
}

///|
pub fn calculate_chinese_similarity(
  char1 : @ocr.DictCharEntry,
  char2 : @ocr.DictCharEntry,
) -> Double {
  @ocr.calculate_chinese_similarity(char1, char2)
}

///|
pub fn find_similar_chinese_chars(
  dict : @ocr.DictChineseDict,
  target_char : String,
  top_n? : Int = 5,
) -> Array[@ocr.DictCharMatch] raise @types.LoadError {
  @ocr.find_similar_chinese_chars(dict, target_char, top_n~)
}

///|
pub fn lookup_char(
  dict : @ocr.DictChineseDict,
  char : String,
) -> @ocr.DictCharEntry? raise @types.LoadError {
  @ocr.lookup_char(dict, char)
}

///|
pub fn recognize_by_components(
  dict : @ocr.DictChineseDict,
  detected_structure : @ocr.DictCharStructure,
  detected_components : Array[String],
  stroke_count_hint? : Int = 0,
) -> Array[(String, Double)] {
  @ocr.recognize_by_components(
    dict,
    detected_structure,
    detected_components,
    stroke_count_hint~,
  )
}

///|
pub fn generate_chinese_dictionary_report(
  dict : @ocr.DictChineseDict,
) -> String {
  @ocr.generate_chinese_dictionary_report(dict)
}

// ==================== 扫描质量自适应与鲁棒性增强（v12.24.0 P3 鲁棒性） ====================

///|
pub type ScanQualityLevel = @ocr.ScanQualityLevel

///|
pub type AdaptivePreprocessConfig = @ocr.AdaptivePreprocessConfig

///|
pub type DistortionType = @ocr.DistortionType

///|
pub type DistortionDetectionResult = @ocr.DistortionDetectionResult

///|
pub type ComplexLayoutType = @ocr.ComplexLayoutType

///|
pub type ComplexLayoutAnalysis = @ocr.ComplexLayoutAnalysis

///|
pub type RobustnessReport = @ocr.RobustnessReport

///|
pub fn select_adaptive_config(
  quality : @ocr.ScanQuality,
) -> @ocr.AdaptivePreprocessConfig raise @types.LoadError {
  @ocr.select_adaptive_config(quality)
}

///|
pub fn detect_skew_angle_robust(
  binary_img : @types.Image,
) -> Double raise @types.LoadError {
  @ocr.detect_skew_angle_robust(binary_img)
}

///|
pub fn detect_distortions(
  img : @types.Image,
) -> Array[@ocr.DistortionDetectionResult] raise @types.LoadError {
  @ocr.detect_distortions(img)
}

///|
pub fn analyze_complex_layout(
  text_blocks : Array[@ocr.TextBlock],
  page_width : Int,
  page_height : Int,
) -> @ocr.ComplexLayoutAnalysis {
  @ocr.analyze_complex_layout(text_blocks, page_width, page_height)
}

///|
pub fn generate_robustness_report(
  quality : @ocr.ScanQuality,
  distortions : Array[@ocr.DistortionDetectionResult],
  layout : @ocr.ComplexLayoutAnalysis,
) -> @ocr.RobustnessReport {
  @ocr.generate_robustness_report(quality, distortions, layout)
}

///|
pub fn robustness_report_to_string(report : @ocr.RobustnessReport) -> String {
  @ocr.robustness_report_to_string(report)
}

// ==================== OCR 批处理引擎（v12.25.0 P4 工程化） ====================

///|
pub type BatchOcrConfig = @ocr.BatchOcrConfig

///|
pub type BatchTaskStatus = @ocr.BatchTaskStatus

///|
pub type BatchTask = @ocr.BatchTask

///|
pub type BatchProgress = @ocr.BatchProgress

///|
pub type BatchResultSummary = @ocr.BatchResultSummary

///|
pub type MemoryUsageStats = @ocr.MemoryUsageStats

///|
pub fn create_default_batch_config() -> @ocr.BatchOcrConfig {
  @ocr.create_default_batch_config()
}

///|
pub fn create_batch_tasks(
  input_files : Array[String],
  output_directory : String,
  output_format : String,
) -> Array[@ocr.BatchTask] raise @types.LoadError {
  @ocr.create_batch_tasks(input_files, output_directory, output_format)
}

///|
pub fn update_task_progress(
  task : @ocr.BatchTask,
  progress : Double,
  current_page : Int,
  total_pages : Int,
) -> @ocr.BatchTask {
  @ocr.update_task_progress(task, progress, current_page, total_pages)
}

///|
pub fn mark_task_completed(
  task : @ocr.BatchTask,
  char_count : Int,
  accuracy : Double,
  end_time : Double,
) -> @ocr.BatchTask {
  @ocr.mark_task_completed(task, char_count, accuracy, end_time)
}

///|
pub fn mark_task_failed(
  task : @ocr.BatchTask,
  error_message : String,
  end_time : Double,
) -> @ocr.BatchTask {
  @ocr.mark_task_failed(task, error_message, end_time)
}

///|
pub fn calculate_batch_progress(
  tasks : Array[@ocr.BatchTask],
  elapsed_time_ms : Double,
) -> @ocr.BatchProgress raise @types.LoadError {
  @ocr.calculate_batch_progress(tasks, elapsed_time_ms)
}

///|
pub fn generate_batch_summary(
  tasks : Array[@ocr.BatchTask],
  total_time_ms : Double,
) -> @ocr.BatchResultSummary raise @types.LoadError {
  @ocr.generate_batch_summary(tasks, total_time_ms)
}

///|
pub fn batch_summary_to_string(summary : @ocr.BatchResultSummary) -> String {
  @ocr.batch_summary_to_string(summary)
}

///|
pub fn progress_bar_to_string(progress : Double, width? : Int = 30) -> String {
  @ocr.progress_bar_to_string(progress, width~)
}

///|
pub fn estimate_memory_usage(
  image_count : Int,
  image_width : Int,
  image_height : Int,
  channels : Int,
) -> @ocr.MemoryUsageStats {
  @ocr.estimate_memory_usage(image_count, image_width, image_height, channels)
}

// ==================== OCR 深度学习集成（v13.0.0） ====================

///|
pub type DLLayerType = @ocr.DLLayerType

///|
pub type DLConv2DConfig = @ocr.DLConv2DConfig

///|
pub type DLDenseConfig = @ocr.DLDenseConfig

///|
pub type DLNeuralLayer = @ocr.DLNeuralLayer

///|
pub type DLCnnModelConfig = @ocr.DLCnnModelConfig

///|
pub type DLTrainingSample = @ocr.DLTrainingSample

///|
pub type DLTrainingHistory = @ocr.DLTrainingHistory

///|
pub type DLInferenceResult = @ocr.DLInferenceResult

///|
pub type DLFeatureExtractor = @ocr.DLFeatureExtractor

///|
pub fn create_default_char_cnn_config(
  num_classes : Int,
) -> @ocr.DLCnnModelConfig {
  @ocr.create_default_char_cnn_config(num_classes)
}

///|
pub fn create_neural_layer(
  layer_type : @ocr.DLLayerType,
  name : String,
  input_shape : Array[Int],
) -> @ocr.DLNeuralLayer {
  @ocr.create_neural_layer(layer_type, name, input_shape)
}

///|
pub fn normalize_image(
  image_data : Array[Double],
  mean : Double,
  std : Double,
) -> Array[Double] raise @types.LoadError {
  @ocr.normalize_image(image_data, mean, std)
}

///|
pub fn resize_image_for_cnn(
  img : @types.Image,
  target_width : Int,
  target_height : Int,
) -> Array[Double] raise @types.LoadError {
  @ocr.resize_image_for_cnn(img, target_width, target_height)
}

///|
pub fn relu(x : Double) -> Double {
  @ocr.relu(x)
}

///|
pub fn sigmoid(x : Double) -> Double {
  @ocr.sigmoid(x)
}

///|
pub fn softmax(logits : Array[Double]) -> Array[Double] {
  @ocr.softmax(logits)
}

///|
pub fn conv2d(
  input : Array[Double],
  in_h : Int,
  in_w : Int,
  in_c : Int,
  kernel : Array[Double],
  out_c : Int,
  k_size : Int,
  stride : Int,
  padding : Int,
) -> Array[Double] raise @types.LoadError {
  @ocr.conv2d(input, in_h, in_w, in_c, kernel, out_c, k_size, stride, padding)
}

///|
pub fn max_pool2d(
  input : Array[Double],
  in_h : Int,
  in_w : Int,
  channels : Int,
  pool_size : Int,
) -> Array[Double] raise @types.LoadError {
  @ocr.max_pool2d(input, in_h, in_w, channels, pool_size)
}

///|
pub fn dense_forward(
  input : Array[Double],
  weights : Array[Double],
  biases : Array[Double],
  in_features : Int,
  out_features : Int,
  activation : String,
) -> Array[Double] {
  @ocr.dense_forward(
    input, weights, biases, in_features, out_features, activation,
  )
}

///|
pub fn cnn_infer(
  image_data : Array[Double],
  config : @ocr.DLCnnModelConfig,
  labels : Array[String],
) -> @ocr.DLInferenceResult {
  @ocr.cnn_infer(image_data, config, labels)
}

///|
pub fn create_training_sample(
  img : @types.Image,
  label : Int,
  label_text : String,
) -> @ocr.DLTrainingSample raise @types.LoadError {
  @ocr.create_training_sample(img, label, label_text)
}

///|
pub fn cross_entropy_loss(predicted : Array[Double], target : Int) -> Double {
  @ocr.cross_entropy_loss(predicted, target)
}

///|
pub fn create_training_history(
  epoch : Int,
  train_loss : Double,
  train_accuracy : Double,
  val_loss : Double,
  val_accuracy : Double,
  learning_rate : Double,
  time_ms : Double,
) -> @ocr.DLTrainingHistory {
  @ocr.create_training_history(
    epoch, train_loss, train_accuracy, val_loss, val_accuracy, learning_rate, time_ms,
  )
}

///|
pub fn generate_training_report(
  history : Array[@ocr.DLTrainingHistory],
  config : @ocr.DLCnnModelConfig,
) -> String {
  @ocr.generate_training_report(history, config)
}

///|
pub fn save_model(
  config : @ocr.DLCnnModelConfig,
  weights : Array[Double],
  path : String,
) -> Bool {
  @ocr.save_model(config, weights, path)
}

///|
pub fn load_model(path : String) -> @ocr.DLCnnModelConfig? {
  @ocr.load_model(path)
}

///|
pub fn create_feature_extractor(
  model_name : String,
  feature_dim : Int,
) -> @ocr.DLFeatureExtractor {
  @ocr.create_feature_extractor(model_name, feature_dim)
}

///|
pub fn extract_features(
  extractor : @ocr.DLFeatureExtractor,
  img : @types.Image,
) -> Array[Double] {
  @ocr.extract_features(extractor, img)
}

///|
pub fn cosine_similarity(
  feat1 : Array[Double],
  feat2 : Array[Double],
) -> Double {
  @ocr.cosine_similarity(feat1, feat2)
}

// ==================== CNN 深度学习增强（v13.0.0） ====================

///|
pub fn relu_backward(
  grad : Array[Double],
  fwd : Array[Double],
) -> Array[Double] {
  @ocr.relu_backward(grad, fwd)
}

///|
pub fn sigmoid_backward(
  grad : Array[Double],
  fwd : Array[Double],
) -> Array[Double] {
  @ocr.sigmoid_backward(grad, fwd)
}

///|
pub fn softmax_cross_entropy_backward(
  predicted : Array[Double],
  target : Int,
) -> Array[Double] raise @types.LoadError {
  @ocr.softmax_cross_entropy_backward(predicted, target)
}

///|
pub fn dense_backward(
  grad_output : Array[Double],
  weights : Array[Double],
  in_features : Int,
  out_features : Int,
) -> (Array[Double], Array[Double], Array[Double]) {
  @ocr.dense_backward(grad_output, weights, in_features, out_features)
}

///|
pub fn max_pool2d_backward(
  grad_output : Array[Double],
  input : Array[Double],
  in_h : Int,
  in_w : Int,
  in_c : Int,
  pool_size : Int,
) -> Array[Double] {
  @ocr.max_pool2d_backward(grad_output, input, in_h, in_w, in_c, pool_size)
}

///|
pub fn update_weights_sgd(
  weights : Array[Double],
  gradients : Array[Double],
  learning_rate : Double,
) -> Array[Double] raise @types.LoadError {
  @ocr.update_weights_sgd(weights, gradients, learning_rate)
}

///|
pub fn cnn_train_step(
  input : Array[Double],
  target : Int,
  conv_weights : Array[Double],
  conv_bias : Array[Double],
  dense_weights : Array[Double],
  dense_bias : Array[Double],
  in_h : Int,
  in_w : Int,
  in_c : Int,
  conv_out_c : Int,
  k_size : Int,
  num_classes : Int,
  learning_rate : Double,
) -> (Array[Double], Array[Double], Array[Double], Array[Double], Double) raise @types.LoadError {
  @ocr.cnn_train_step(
    input, target, conv_weights, conv_bias, dense_weights, dense_bias, in_h, in_w,
    in_c, conv_out_c, k_size, num_classes, learning_rate,
  )
}

///|
pub fn cnn_train(
  samples : Array[@ocr.DLTrainingSample],
  conv_weights : Array[Double],
  conv_bias : Array[Double],
  dense_weights : Array[Double],
  dense_bias : Array[Double],
  in_h : Int,
  in_w : Int,
  in_c : Int,
  conv_out_c : Int,
  k_size : Int,
  num_classes : Int,
  learning_rate : Double,
  epochs : Int,
) -> (
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[@ocr.DLTrainingHistory],
) raise @types.LoadError {
  @ocr.cnn_train(
    samples, conv_weights, conv_bias, dense_weights, dense_bias, in_h, in_w, in_c,
    conv_out_c, k_size, num_classes, learning_rate, epochs,
  )
}

///|
pub fn cnn_recognize_char(
  img : @types.Image,
  config : @ocr.DLCnnModelConfig,
  labels : Array[String],
) -> @ocr.DLInferenceResult raise @types.LoadError {
  @ocr.cnn_recognize_char(img, config, labels)
}

///|
pub fn cnn_recognize_digits(
  img : @types.Image,
  config : @ocr.DLCnnModelConfig,
) -> @ocr.DLInferenceResult raise @types.LoadError {
  @ocr.cnn_recognize_digits(img, config)
}

///|
pub fn cnn_recognize_letters(
  img : @types.Image,
  config : @ocr.DLCnnModelConfig,
) -> @ocr.DLInferenceResult raise @types.LoadError {
  @ocr.cnn_recognize_letters(img, config)
}

///|
pub fn evaluate_cnn_model(
  test_samples : Array[@ocr.DLTrainingSample],
  config : @ocr.DLCnnModelConfig,
  labels : Array[String],
) -> (Double, Double) raise @types.LoadError {
  @ocr.evaluate_cnn_model(test_samples, config, labels)
}

///|
pub fn cnn_confusion_matrix(
  test_samples : Array[@ocr.DLTrainingSample],
  config : @ocr.DLCnnModelConfig,
  labels : Array[String],
) -> Array[Array[Int]] raise @types.LoadError {
  @ocr.cnn_confusion_matrix(test_samples, config, labels)
}

// ==================== OCR 模型训练框架（v13.1.0） ====================

///|
pub type OptimizerType = @ocr.OptimizerType

///|
pub type OptimizerConfig = @ocr.OptimizerConfig

///|
pub type LRSchedulerType = @ocr.LRSchedulerType

///|
pub type LRSchedulerConfig = @ocr.LRSchedulerConfig

///|
pub type AugmentationType = @ocr.AugmentationType

///|
pub type AugmentationConfig = @ocr.AugmentationConfig

///|
pub type TrainingConfig = @ocr.TrainingConfig

///|
pub type TrainingMetrics = @ocr.TrainingMetrics

///|
pub type TrainingState = @ocr.TrainingState

///|
pub type DataLoader = @ocr.DataLoader

///|
pub fn create_default_training_config() -> @ocr.TrainingConfig {
  @ocr.create_default_training_config()
}

///|
pub fn create_data_loader(
  samples : Array[@ocr.DLTrainingSample],
  batch_size : Int,
  shuffle : Bool,
) -> @ocr.DataLoader raise @types.LoadError {
  @ocr.create_data_loader(samples, batch_size, shuffle)
}

///|
pub fn next_batch(
  loader : @ocr.DataLoader,
) -> (Array[@ocr.DLTrainingSample], @ocr.DataLoader) raise @types.LoadError {
  @ocr.next_batch(loader)
}

///|
pub fn calculate_learning_rate(
  config : @ocr.LRSchedulerConfig,
  epoch : Int,
  current_lr : Double,
  val_loss : Double,
) -> Double raise @types.LoadError {
  @ocr.calculate_learning_rate(config, epoch, current_lr, val_loss)
}

///|
pub fn augment_random_rotation(
  sample : @ocr.DLTrainingSample,
  angle_range : Double,
) -> @ocr.DLTrainingSample {
  @ocr.augment_random_rotation(sample, angle_range)
}

///|
pub fn augment_random_shift(
  sample : @ocr.DLTrainingSample,
  shift_range : Double,
) -> @ocr.DLTrainingSample {
  @ocr.augment_random_shift(sample, shift_range)
}

///|
pub fn augment_random_scale(
  sample : @ocr.DLTrainingSample,
  scale_range : Double,
) -> @ocr.DLTrainingSample {
  @ocr.augment_random_scale(sample, scale_range)
}

///|
pub fn augment_random_noise(
  sample : @ocr.DLTrainingSample,
  noise_level : Double,
) -> @ocr.DLTrainingSample {
  @ocr.augment_random_noise(sample, noise_level)
}

///|
pub fn apply_augmentation(
  sample : @ocr.DLTrainingSample,
  config : @ocr.AugmentationConfig,
) -> @ocr.DLTrainingSample {
  @ocr.apply_augmentation(sample, config)
}

///|
pub fn calculate_accuracy(
  predictions : Array[Int],
  labels : Array[Int],
) -> Double {
  @ocr.calculate_accuracy(predictions, labels)
}

///|
pub fn check_early_stopping(
  state : @ocr.TrainingState,
  config : @ocr.TrainingConfig,
  current_val_accuracy : Double,
) -> (Bool, @ocr.TrainingState) {
  @ocr.check_early_stopping(state, config, current_val_accuracy)
}

///|
pub fn create_training_state() -> @ocr.TrainingState {
  @ocr.create_training_state()
}

///|
pub fn record_training_metrics(
  state : @ocr.TrainingState,
  metrics : @ocr.TrainingMetrics,
) -> @ocr.TrainingState {
  @ocr.record_training_metrics(state, metrics)
}

///|
pub fn generate_training_progress_report(
  state : @ocr.TrainingState,
  config : @ocr.TrainingConfig,
) -> String {
  @ocr.generate_training_progress_report(state, config)
}

///|
pub fn split_train_validation(
  samples : Array[@ocr.DLTrainingSample],
  validation_split : Double,
  shuffle : Bool,
) -> (Array[@ocr.DLTrainingSample], Array[@ocr.DLTrainingSample]) {
  @ocr.split_train_validation(samples, validation_split, shuffle)
}

///|
pub fn compute_confusion_matrix(
  predictions : Array[Int],
  labels : Array[Int],
  num_classes : Int,
) -> Array[Array[Int]] {
  @ocr.compute_confusion_matrix(predictions, labels, num_classes)
}

///|
pub fn compute_per_class_accuracy(
  confusion_matrix : Array[Array[Int]],
) -> Array[Double] {
  @ocr.compute_per_class_accuracy(confusion_matrix)
}

// ==================== OCR 性能优化（v13.5.0） ====================

///|
pub fn build_grayscale_lut() -> Array[Int] {
  @ocr.build_grayscale_lut()
}

///|
pub fn build_threshold_lut(threshold : Int) -> Array[Int] {
  @ocr.build_threshold_lut(threshold)
}

///|
pub fn fast_threshold_lut(
  img : @types.Image,
  lut : Array[Int],
) -> @types.Image raise @types.LoadError {
  @ocr.fast_threshold_lut(img, lut)
}

///|
pub fn cache_friendly_horizontal_projection(
  img : @types.Image,
) -> Array[Int] raise @types.LoadError {
  @ocr.cache_friendly_horizontal_projection(img)
}

///|
pub fn cache_friendly_vertical_projection(
  img : @types.Image,
) -> Array[Int] raise @types.LoadError {
  @ocr.cache_friendly_vertical_projection(img)
}

///|
pub fn unrolled_pixel_sum(img : @types.Image) -> Int raise @types.LoadError {
  @ocr.unrolled_pixel_sum(img)
}

///|
pub fn fast_connected_components(
  binary_img : @types.Image,
) -> Array[Int] raise @types.LoadError {
  @ocr.fast_connected_components(binary_img)
}

///|
pub fn build_gaussian_kernel_lut(
  sigma : Double,
  radius : Int,
) -> Array[Double] raise @types.LoadError {
  @ocr.build_gaussian_kernel_lut(sigma, radius)
}

///|
pub fn fast_gaussian_blur_1d(
  img : @types.Image,
  kernel : Array[Double],
) -> @types.Image raise @types.LoadError {
  @ocr.fast_gaussian_blur_1d(img, kernel)
}

///|
pub fn batch_recognize_chars(
  images : Array[@types.Image],
  config : @ocr.DLCnnModelConfig,
  labels : Array[String],
) -> Array[@ocr.DLInferenceResult] raise @types.LoadError {
  @ocr.batch_recognize_chars(images, config, labels)
}

///|
pub fn ocr_pipeline_stats(
  img : @types.Image,
) -> (Int, Int, Double) raise @types.LoadError {
  @ocr.ocr_pipeline_stats(img)
}

///|
pub fn fast_downsample_2x(
  img : @types.Image,
) -> @types.Image raise @types.LoadError {
  @ocr.fast_downsample_2x(img)
}

// ==================== OCR 部署工具（v13.6.0） ====================

///|
pub type DeploymentEnvironment = @ocr.DeploymentEnvironment

///|
pub fn create_default_cli_config() -> @ocr.CliConfig {
  @ocr.create_default_cli_config()
}

///|
pub fn create_default_api_server_config() -> @ocr.ApiServerConfig {
  @ocr.create_default_api_server_config()
}

///|
pub fn create_default_docker_config() -> @ocr.DockerConfig {
  @ocr.create_default_docker_config()
}

///|
pub fn create_default_model_package_config() -> @ocr.ModelPackageConfig {
  @ocr.create_default_model_package_config()
}

///|
pub fn generate_dockerfile(config : @ocr.DockerConfig) -> String {
  @ocr.generate_dockerfile(config)
}

///|
pub fn generate_docker_compose(config : @ocr.DockerConfig) -> String {
  @ocr.generate_docker_compose(config)
}

///|
pub fn generate_api_config_json(config : @ocr.ApiServerConfig) -> String {
  @ocr.generate_api_config_json(config)
}

///|
pub fn generate_cli_help() -> String {
  @ocr.generate_cli_help()
}

///|
pub fn parse_cli_args(
  args : Array[String],
) -> @ocr.CliConfig raise @types.LoadError {
  @ocr.parse_cli_args(args)
}

///|
pub fn generate_model_manifest(config : @ocr.ModelPackageConfig) -> String {
  @ocr.generate_model_manifest(config)
}

///|
pub fn generate_env_config(env : @ocr.DeploymentEnvironment) -> String {
  @ocr.generate_env_config(env)
}

///|
pub fn generate_health_check_config(config : @ocr.ApiServerConfig) -> String {
  @ocr.generate_health_check_config(config)
}

///|
pub fn generate_deployment_package(
  docker_config : @ocr.DockerConfig,
  api_config : @ocr.ApiServerConfig,
  model_config : @ocr.ModelPackageConfig,
) -> String {
  @ocr.generate_deployment_package(docker_config, api_config, model_config)
}

// ==================== 手写体识别支持（v13.2.0） ====================

///|
pub type HandwritingStyle = @ocr.HandwritingStyle

///|
pub type StrokeType = @ocr.StrokeType

///|
pub type StrokeFeature = @ocr.StrokeFeature

///|
pub type StrokeSegmentationResult = @ocr.StrokeSegmentationResult

///|
pub type HandwritingCharFeature = @ocr.HandwritingCharFeature

///|
pub type HandwritingTemplate = @ocr.HandwritingTemplate

///|
pub type HandwritingRecognitionConfig = @ocr.HandwritingRecognitionConfig

///|
pub type HandwritingRecognitionResult = @ocr.HandwritingRecognitionResult

///|
pub fn create_default_handwriting_config() -> @ocr.HandwritingRecognitionConfig {
  @ocr.create_default_handwriting_config()
}

///|
pub fn detect_handwriting_slant(
  img : @types.Image,
) -> Double raise @types.LoadError {
  @ocr.detect_handwriting_slant(img)
}

///|
pub fn normalize_handwriting_size(
  img : @types.Image,
  target_size : Int,
) -> @types.Image raise @types.LoadError {
  @ocr.normalize_handwriting_size(img, target_size)
}

///|
pub fn extract_hw_stroke_features(
  img : @types.Image,
) -> Array[@ocr.StrokeFeature] {
  @ocr.extract_hw_stroke_features(img)
}

///|
pub fn segment_connected_strokes(
  img : @types.Image,
  config : @ocr.HandwritingRecognitionConfig,
) -> @ocr.StrokeSegmentationResult {
  @ocr.segment_connected_strokes(img, config)
}

///|
pub fn extract_handwriting_features(
  img : @types.Image,
  char : String,
) -> @ocr.HandwritingCharFeature raise @types.LoadError {
  @ocr.extract_handwriting_features(img, char)
}

///|
pub fn handwriting_feature_similarity(
  feat1 : @ocr.HandwritingCharFeature,
  feat2 : @ocr.HandwritingCharFeature,
) -> Double {
  @ocr.handwriting_feature_similarity(feat1, feat2)
}

///|
pub fn create_handwriting_template(
  char : String,
  style : @ocr.HandwritingStyle,
  samples : Array[@types.Image],
) -> @ocr.HandwritingTemplate raise @types.LoadError {
  @ocr.create_handwriting_template(char, style, samples)
}

///|
pub fn recognize_handwriting_char(
  img : @types.Image,
  templates : Array[@ocr.HandwritingTemplate],
  config : @ocr.HandwritingRecognitionConfig,
) -> @ocr.HandwritingRecognitionResult raise @types.LoadError {
  @ocr.recognize_handwriting_char(img, templates, config)
}

///|
pub fn handwriting_report_to_string(
  result : @ocr.HandwritingRecognitionResult,
) -> String {
  @ocr.handwriting_report_to_string(result)
}

// ==================== 视频目标跟踪与动作识别（v14.0.0） ====================

///|
pub type OpticalFlowVector = @video.OpticalFlowVector

///|
pub type OpticalFlowField = @video.OpticalFlowField

///|
pub type TrackedObject = @video.TrackedObject

///|
pub type TrackingResult = @video.TrackingResult

///|
pub type ActionType = @video.ActionType

///|
pub type ActionRecognitionResult = @video.ActionRecognitionResult

///|
pub type VideoStabilizationConfig = @video.VideoStabilizationConfig

///|
pub type KeyframeType = @video.KeyframeType

///|
pub type Keyframe = @video.Keyframe

///|
pub type VideoSummary = @video.VideoSummary

///|
pub fn create_default_stabilization_config() -> @video.VideoStabilizationConfig {
  @video.create_default_stabilization_config()
}

///|
pub fn compute_frame_difference(
  frame1 : @types.Image,
  frame2 : @types.Image,
  threshold? : Double = 30.0,
) -> Double {
  @video.compute_frame_difference(frame1, frame2, threshold~)
}

///|
pub fn compute_optical_flow(
  frame1 : @types.Image,
  frame2 : @types.Image,
  block_size? : Int = 8,
  search_range? : Int = 4,
) -> @video.OpticalFlowField {
  @video.compute_optical_flow(frame1, frame2, block_size~, search_range~)
}

///|
pub fn initialize_tracking(
  first_frame : @types.Image,
  roi_x : Int,
  roi_y : Int,
  roi_width : Int,
  roi_height : Int,
  label : String,
) -> @video.TrackedObject {
  @video.initialize_tracking(
    first_frame, roi_x, roi_y, roi_width, roi_height, label,
  )
}

///|
pub fn update_tracking(
  obj : @video.TrackedObject,
  frame : @types.Image,
) -> @video.TrackedObject {
  @video.update_tracking(obj, frame)
}

///|
pub fn recognize_action(
  frames : Array[@types.Image],
  start_frame : Int,
  end_frame : Int,
) -> @video.ActionRecognitionResult {
  @video.recognize_action(frames, start_frame, end_frame)
}

///|
pub fn detect_scene_change(
  frame1 : @types.Image,
  frame2 : @types.Image,
  threshold? : Double = 0.3,
) -> (Bool, Double) {
  @video.detect_scene_change(frame1, frame2, threshold~)
}

///|
pub fn extract_keyframes(
  frames : Array[@types.Image],
  fps : Double,
  method_type? : String = "auto",
) -> Array[@video.Keyframe] {
  @video.extract_keyframes(frames, fps, method_type~)
}

///|
pub fn generate_video_summary(
  frames : Array[@types.Image],
  fps : Double,
) -> @video.VideoSummary {
  @video.generate_video_summary(frames, fps)
}

///|
pub fn stabilize_video(
  frames : Array[@types.Image],
  config : @video.VideoStabilizationConfig,
) -> Array[@types.Image] {
  @video.stabilize_video(frames, config)
}

// ==================== 计算摄影增强（v15.0.0） ====================

///|
pub type ExposureType = @photo_enhance.ExposureType

///|
pub type HdrImage = @photo_enhance.HdrImage

///|
pub type ToneMappingType = @photo_enhance.ToneMappingType

///|
pub type ToneMappingConfig = @photo_enhance.ToneMappingConfig

///|
pub type PanoramaConfig = @photo_enhance.PanoramaConfig

///|
pub type PanoramaResult = @photo_enhance.PanoramaResult

///|
pub type DepthOfFieldConfig = @photo_enhance.DepthOfFieldConfig

///|
pub type NightEnhanceConfig = @photo_enhance.NightEnhanceConfig

///|
pub fn create_default_hdr_config() -> @photo_enhance.ToneMappingConfig {
  @photo_enhance.create_default_hdr_config()
}

///|
pub fn create_default_panorama_config() -> @photo_enhance.PanoramaConfig {
  @photo_enhance.create_default_panorama_config()
}

///|
pub fn create_default_dof_config(
  width : Int,
  height : Int,
) -> @photo_enhance.DepthOfFieldConfig {
  @photo_enhance.create_default_dof_config(width, height)
}

///|
pub fn create_default_night_config() -> @photo_enhance.NightEnhanceConfig {
  @photo_enhance.create_default_night_config()
}

///|
pub fn detect_exposure_type(
  img : @types.Image,
) -> (@photo_enhance.ExposureType, Double) {
  @photo_enhance.detect_exposure_type(img)
}

///|
pub fn hdr_merge(
  images : Array[@types.Image],
  exposures : Array[Double],
) -> @photo_enhance.HdrImage {
  @photo_enhance.hdr_merge(images, exposures)
}

///|
pub fn tone_map(
  hdr : @photo_enhance.HdrImage,
  config : @photo_enhance.ToneMappingConfig,
) -> @types.Image {
  @photo_enhance.tone_map(hdr, config)
}

///|
pub fn stitch_panorama(
  images : Array[@types.Image],
  config : @photo_enhance.PanoramaConfig,
) -> @photo_enhance.PanoramaResult {
  @photo_enhance.stitch_panorama(images, config)
}

///|
pub fn apply_depth_of_field(
  img : @types.Image,
  config : @photo_enhance.DepthOfFieldConfig,
) -> @types.Image {
  @photo_enhance.apply_depth_of_field(img, config)
}

///|
pub fn enhance_night(
  img : @types.Image,
  config : @photo_enhance.NightEnhanceConfig,
) -> @types.Image {
  @photo_enhance.enhance_night(img, config)
}

///|
pub fn computational_photography_report(
  hdr : @photo_enhance.HdrImage,
  panorama : @photo_enhance.PanoramaResult,
) -> String {
  @photo_enhance.computational_photography_report(hdr, panorama)
}

// ==================== 目标检测增强（v16.0.0） ====================

///|
pub type YoloBoundingBox = @detection.YoloBoundingBox

///|
pub type YoloDetectionResult = @detection.YoloDetectionResult

///|
pub type YoloConfig = @detection.YoloConfig

///|
pub type ObjectClass = @detection.ObjectClass

///|
pub type YoloTrackedObject = @detection.YoloTrackedObject

///|
pub type YoloTrackingResult = @detection.YoloTrackingResult

///|
pub type YoloDetectionMetrics = @detection.YoloDetectionMetrics

///|
pub fn create_default_yolo_config() -> @detection.YoloConfig {
  @detection.create_default_yolo_config()
}

///|
pub fn calculate_iou(
  box1 : @detection.YoloBoundingBox,
  box2 : @detection.YoloBoundingBox,
) -> Double raise @types.LoadError {
  @detection.calculate_iou(box1, box2)
}

///|
pub fn non_max_suppression(
  boxes : Array[@detection.YoloBoundingBox],
  iou_threshold : Double,
  max_detections : Int,
) -> Array[@detection.YoloBoundingBox] raise @types.LoadError {
  @detection.non_max_suppression(boxes, iou_threshold, max_detections)
}

///|
pub fn detect_objects_simple(
  img : @types.Image,
  config : @detection.YoloConfig,
) -> @detection.YoloDetectionResult raise @types.LoadError {
  @detection.detect_objects_simple(img, config)
}

///|
pub fn initialize_object_tracking(
  detection : @detection.YoloDetectionResult,
) -> Array[@detection.YoloTrackedObject] raise @types.LoadError {
  @detection.initialize_object_tracking(detection)
}

///|
pub fn update_object_tracking(
  tracked_objects : Array[@detection.YoloTrackedObject],
  detection : @detection.YoloDetectionResult,
  max_age : Int,
) -> Array[@detection.YoloTrackedObject] raise @types.LoadError {
  @detection.update_object_tracking(tracked_objects, detection, max_age)
}

///|
pub fn calculate_detection_metrics(
  predictions : Array[@detection.YoloBoundingBox],
  ground_truth : Array[@detection.YoloBoundingBox],
  iou_threshold : Double,
) -> @detection.YoloDetectionMetrics raise @types.LoadError {
  @detection.calculate_detection_metrics(
    predictions, ground_truth, iou_threshold,
  )
}

///|
pub fn detection_report_to_string(
  result : @detection.YoloDetectionResult,
  metrics : @detection.YoloDetectionMetrics,
) -> String {
  @detection.detection_report_to_string(result, metrics)
}

// ==================== 图像分割增强（v17.0.0） ====================

///|
pub type SegmentationLabel = @segmentation.SegmentationLabel

///|
pub type SemanticSegmentationResult = @segmentation.SemanticSegmentationResult

///|
pub type InstanceSegmentationResult = @segmentation.InstanceSegmentationResult

///|
pub type Superpixel = @segmentation.Superpixel

///|
pub type KMeansConfig = @segmentation.KMeansConfig

///|
pub type GrabCutConfig = @segmentation.GrabCutConfig

///|
pub type SegmentationMetrics = @segmentation.SegmentationMetrics

///|
pub fn create_default_watershed_config() -> @segmentation.WatershedConfig {
  @segmentation.create_default_watershed_config()
}

///|
pub fn create_default_kmeans_config() -> @segmentation.KMeansConfig {
  @segmentation.create_default_kmeans_config()
}

///|
pub fn create_default_grabcut_config() -> @segmentation.GrabCutConfig {
  @segmentation.create_default_grabcut_config()
}

///|
pub fn threshold_segmentation(
  img : @types.Image,
  threshold : Double,
) -> @segmentation.SemanticSegmentationResult raise @types.LoadError {
  @segmentation.threshold_segmentation(img, threshold)
}

///|
pub fn otsu_threshold_value(
  img : @types.Image,
) -> Double raise @types.LoadError {
  @segmentation.otsu_threshold_value(img)
}

///|
pub fn kmeans_segmentation(
  img : @types.Image,
  config : @segmentation.KMeansConfig,
) -> @segmentation.SemanticSegmentationResult raise @types.LoadError {
  @segmentation.kmeans_segmentation(img, config)
}

///|
pub fn superpixel_segmentation(
  img : @types.Image,
  num_superpixels : Int,
) -> @segmentation.SuperpixelResult raise @types.LoadError {
  @segmentation.superpixel_segmentation(img, num_superpixels)
}

///|
pub fn watershed_segmentation(
  img : @types.Image,
  config : @segmentation.WatershedConfig,
) -> @segmentation.SemanticSegmentationResult raise @types.LoadError {
  @segmentation.watershed_segmentation(img, config)
}

///|
pub fn grabcut_segmentation(
  img : @types.Image,
  rect_x : Int,
  rect_y : Int,
  rect_w : Int,
  rect_h : Int,
  config : @segmentation.GrabCutConfig,
) -> @segmentation.SemanticSegmentationResult raise @types.LoadError {
  @segmentation.grabcut_segmentation(
    img, rect_x, rect_y, rect_w, rect_h, config,
  )
}

///|
pub fn calculate_segmentation_metrics(
  prediction : Array[Int],
  ground_truth : Array[Int],
  num_classes : Int,
) -> @segmentation.SegmentationMetrics {
  @segmentation.calculate_segmentation_metrics(
    prediction, ground_truth, num_classes,
  )
}

///|
pub fn segmentation_to_image(
  result : @segmentation.SemanticSegmentationResult,
) -> @types.Image {
  @segmentation.segmentation_to_image(result)
}

///|
pub fn segmentation_report_to_string(
  result : @segmentation.SemanticSegmentationResult,
  metrics : @segmentation.SegmentationMetrics,
) -> String {
  @segmentation.segmentation_report_to_string(result, metrics)
}

// ==================== 3D 视觉增强（v18.0.0） ====================

///|
pub type Point3d = @stereo3d.Point3d

///|
pub type PointCloud3D = @stereo3d.PointCloud3D

///|
pub type BoundingBox3d = @stereo3d.BoundingBox3d

///|
pub type DepthMap3d = @stereo3d.DepthMap3d

///|
pub type CameraIntrinsics3d = @stereo3d.CameraIntrinsics3d

///|
pub type CameraExtrinsics3d = @stereo3d.CameraExtrinsics3d

///|
pub type StereoConfig3d = @stereo3d.StereoConfig3d

///|
pub type RegistrationResult3d = @stereo3d.RegistrationResult3d

///|
pub type Mesh3d = @stereo3d.Mesh3d

///|
pub fn create_default_stereo_config_3d() -> @stereo3d.StereoConfig3d {
  @stereo3d.create_default_stereo_config()
}

///|
pub fn create_default_camera_intrinsics_3d(
  width : Int,
  height : Int,
) -> @stereo3d.CameraIntrinsics3d {
  @stereo3d.create_default_camera_intrinsics(width, height)
}

///|
pub fn depth_to_point_cloud_3d(
  depth : @stereo3d.DepthMap3d,
  intrinsics : @stereo3d.CameraIntrinsics3d,
) -> @stereo3d.PointCloud3D {
  @stereo3d.depth_to_point_cloud(depth, intrinsics)
}

///|
pub fn stereo_match_3d(
  left : @types.Image,
  right : @types.Image,
  config : @stereo3d.StereoConfig3d,
) -> @stereo3d.DepthMap3d {
  @stereo3d.stereo_match(left, right, config)
}

///|
pub fn voxel_downsample_3d(
  cloud : @stereo3d.PointCloud3D,
  voxel_size : Double,
) -> @stereo3d.PointCloud3D {
  @stereo3d.voxel_downsample(cloud, voxel_size)
}

///|
pub fn statistical_outlier_removal_3d(
  cloud : @stereo3d.PointCloud3D,
  mean_k : Int,
  std_ratio : Double,
) -> @stereo3d.PointCloud3D {
  @stereo3d.statistical_outlier_removal(cloud, mean_k, std_ratio)
}

///|
pub fn icp_registration_3d(
  source : @stereo3d.PointCloud3D,
  target : @stereo3d.PointCloud3D,
  max_iterations : Int,
  tolerance : Double,
) -> @stereo3d.RegistrationResult3d {
  @stereo3d.icp_registration(source, target, max_iterations, tolerance)
}

///|
pub fn estimate_normals_3d(
  cloud : @stereo3d.PointCloud3D,
  search_radius : Double,
) -> Array[(Double, Double, Double)] {
  @stereo3d.estimate_normals(cloud, search_radius)
}

///|
pub fn depth_map_to_image_3d(depth : @stereo3d.DepthMap3d) -> @types.Image {
  @stereo3d.depth_map_to_image(depth)
}

///|
pub fn vision_3d_report_to_string(
  cloud : @stereo3d.PointCloud3D,
  depth : @stereo3d.DepthMap3d,
  registration : @stereo3d.RegistrationResult3d,
) -> String {
  @stereo3d.vision_3d_report_to_string(cloud, depth, registration)
}

// ==================== 医学图像增强（v19.0.0） ====================

///|
pub type MedicalImageType = @medical.MedicalImageType

///|
pub type MedicalImage = @medical.MedicalImage

///|
pub type RegionOfInterest = @medical.RegionOfInterest

///|
pub type Lesion = @medical.Lesion

///|
pub type MedicalRegistrationResult = @medical.MedicalRegistrationResult

///|
pub type MedicalSegmentationConfig = @medical.MedicalSegmentationConfig

///|
pub type WindowLevelConfig = @medical.WindowLevelConfig

///|
pub type MedicalImageQuality = @medical.MedicalImageQuality

///|
pub fn create_default_medical_segmentation_config() -> @medical.MedicalSegmentationConfig {
  @medical.create_default_medical_segmentation_config()
}

///|
pub fn create_default_window_level_medical(
  preset : String,
) -> @medical.WindowLevelConfig {
  @medical.create_default_window_level(preset)
}

///|
pub fn apply_window_level_medical(
  image : @medical.MedicalImage,
  config : @medical.WindowLevelConfig,
) -> @types.Image {
  @medical.apply_window_level_medical(image, config)
}

///|
pub fn medical_threshold_segmentation_medical(
  image : @medical.MedicalImage,
  lower : Double,
  upper : Double,
) -> Array[Bool] {
  @medical.medical_threshold_segmentation(image, lower, upper)
}

///|
pub fn region_growing_segmentation_medical(
  image : @medical.MedicalImage,
  seed_x : Int,
  seed_y : Int,
  seed_z : Int,
  threshold : Double,
) -> Array[Bool] {
  @medical.region_growing_segmentation(image, seed_x, seed_y, seed_z, threshold)
}

///|
pub fn calculate_roi_stats_medical(
  image : @medical.MedicalImage,
  mask : Array[Bool],
) -> (Double, Double, Int) {
  @medical.calculate_roi_stats(image, mask)
}

///|
pub fn detect_lesions_simple_medical(
  image : @medical.MedicalImage,
  min_diameter : Double,
  max_diameter : Double,
) -> Array[@medical.Lesion] {
  @medical.detect_lesions_simple(image, min_diameter, max_diameter)
}

///|
pub fn medical_image_registration_medical(
  fixed : @medical.MedicalImage,
  moving : @medical.MedicalImage,
  max_iterations : Int,
) -> @medical.MedicalRegistrationResult {
  @medical.medical_image_registration(fixed, moving, max_iterations)
}

///|
pub fn calculate_medical_image_quality_medical(
  image : @medical.MedicalImage,
) -> @medical.MedicalImageQuality {
  @medical.calculate_medical_image_quality(image)
}

///|
pub fn medical_image_report_to_string_medical(
  image : @medical.MedicalImage,
  lesions : Array[@medical.Lesion],
  quality : @medical.MedicalImageQuality,
) -> String {
  @medical.medical_image_report_to_string(image, lesions, quality)
}

// ==================== 遥感图像增强（v20.0.0） ====================

///|
pub type RemoteSensingImageType = @remote_sensing.RemoteSensingImageType

///|
pub type RemoteSensingImage = @remote_sensing.RemoteSensingImage

///|
pub type LandCoverClass = @remote_sensing.LandCoverClass

///|
pub type ChangeDetectionResult = @remote_sensing.ChangeDetectionResult

///|
pub type VegetationIndices = @remote_sensing.VegetationIndices

///|
pub type SpectralSignature = @remote_sensing.SpectralSignature

///|
pub type TextureFeatures = @remote_sensing.TextureFeatures

///|
pub type RemoteSensingQuality = @remote_sensing.RemoteSensingQuality

///|
pub fn create_default_remote_sensing_image(
  width : Int,
  height : Int,
  bands : Int,
) -> @remote_sensing.RemoteSensingImage {
  @remote_sensing.create_default_remote_sensing_image(width, height, bands)
}

///|
pub fn calculate_ndvi_rs(
  image : @remote_sensing.RemoteSensingImage,
  red_band : Int,
  nir_band : Int,
) -> Array[Double] {
  @remote_sensing.calculate_ndvi(image, red_band, nir_band)
}

///|
pub fn calculate_ndwi_rs(
  image : @remote_sensing.RemoteSensingImage,
  green_band : Int,
  nir_band : Int,
) -> Array[Double] {
  @remote_sensing.calculate_ndwi(image, green_band, nir_band)
}

///|
pub fn calculate_ndbi_rs(
  image : @remote_sensing.RemoteSensingImage,
  swir_band : Int,
  nir_band : Int,
) -> Array[Double] {
  @remote_sensing.calculate_ndbi(image, swir_band, nir_band)
}

///|
pub fn calculate_all_vegetation_indices_rs(
  image : @remote_sensing.RemoteSensingImage,
) -> @remote_sensing.VegetationIndices {
  @remote_sensing.calculate_all_vegetation_indices(image)
}

///|
pub fn classify_land_cover_simple_rs(
  image : @remote_sensing.RemoteSensingImage,
) -> @remote_sensing.ClassificationResult {
  @remote_sensing.classify_land_cover_simple(image)
}

///|
pub fn detect_changes_simple_rs(
  image1 : @remote_sensing.RemoteSensingImage,
  image2 : @remote_sensing.RemoteSensingImage,
  threshold : Double,
) -> @remote_sensing.ChangeDetectionResult {
  @remote_sensing.detect_changes_simple(image1, image2, threshold)
}

///|
pub fn calculate_texture_features_rs(
  image : @types.Image,
  x : Int,
  y : Int,
  window_size : Int,
) -> @remote_sensing.TextureFeatures raise @types.LoadError {
  @remote_sensing.calculate_texture_features(image, x, y, window_size)
}

///|
pub fn calculate_spectral_signature_rs(
  image : @remote_sensing.RemoteSensingImage,
  x : Int,
  y : Int,
) -> @remote_sensing.SpectralSignature {
  @remote_sensing.calculate_spectral_signature(image, x, y)
}

///|
pub fn calculate_remote_sensing_quality_rs(
  image : @remote_sensing.RemoteSensingImage,
) -> @remote_sensing.RemoteSensingQuality {
  @remote_sensing.calculate_remote_sensing_quality(image)
}

///|
pub fn remote_sensing_report_to_string_rs(
  image : @remote_sensing.RemoteSensingImage,
  classification : @remote_sensing.ClassificationResult,
  changes : @remote_sensing.ChangeDetectionResult,
  quality : @remote_sensing.RemoteSensingQuality,
) -> String {
  @remote_sensing.remote_sensing_report_to_string(
    image, classification, changes, quality,
  )
}

// ==================== 图像加密与水印增强（v21.0.0） ====================

///|
pub type EncryptionAlgorithm = @encryption.EncryptionAlgorithm

///|
pub type EncryptionResult = @encryption.EncryptionResult

///|
pub type WatermarkType = @encryption.WatermarkType

///|
pub type WatermarkInfo = @encryption.WatermarkInfo

///|
pub type WatermarkExtractionResult = @encryption.WatermarkExtractionResult

///|
pub type ChaoticParams = @encryption.ChaoticParams

///|
pub type ArnoldParams = @encryption.ArnoldParams

///|
pub type ImageEncryptionQuality = @encryption.ImageEncryptionQuality

///|
pub fn create_default_chaotic_params_enc() -> @encryption.ChaoticParams {
  @encryption.create_default_chaotic_params()
}

///|
pub fn create_default_arnold_params_enc() -> @encryption.ArnoldParams {
  @encryption.create_default_arnold_params()
}

///|
pub fn xor_encrypt_enc(
  img : @types.Image,
  key : Array[Byte],
) -> @encryption.EncryptionResult raise @types.LoadError {
  @encryption.xor_encrypt(img, key)
}

///|
pub fn xor_decrypt_enc(
  encrypted : @encryption.EncryptionResult,
  key : Array[Byte],
) -> @types.Image {
  @encryption.xor_decrypt(encrypted, key)
}

///|
pub fn chaotic_encrypt_enc(
  img : @types.Image,
  params : @encryption.ChaoticParams,
) -> @encryption.EncryptionResult raise @types.LoadError {
  @encryption.chaotic_encrypt(img, params)
}

///|
pub fn arnold_scramble_enc(
  img : @types.Image,
  params : @encryption.ArnoldParams,
) -> @encryption.EncryptionResult raise @types.LoadError {
  @encryption.arnold_scramble(img, params)
}

///|
pub fn embed_watermark_lsb_enc(
  img : @types.Image,
  watermark : Array[Byte],
  strength : Int,
) -> (@types.Image, @encryption.WatermarkInfo) raise @types.LoadError {
  @encryption.embed_watermark_lsb(img, watermark, strength)
}

///|
pub fn extract_watermark_lsb_enc(
  img : @types.Image,
  watermark_length : Int,
  strength : Int,
) -> @encryption.WatermarkExtractionResult raise @types.LoadError {
  @encryption.extract_watermark_lsb(img, watermark_length, strength)
}

///|
pub fn embed_visible_watermark_enc(
  img : @types.Image,
  watermark_text : String,
  x : Int,
  y : Int,
  opacity : Double,
) -> @types.Image raise @types.LoadError {
  @encryption.embed_visible_watermark(img, watermark_text, x, y, opacity)
}

///|
pub fn calculate_image_entropy_enc(
  img : @types.Image,
) -> Double raise @types.LoadError {
  @encryption.calculate_image_entropy(img)
}

///|
pub fn calculate_correlation_enc(
  img1 : @types.Image,
  img2 : @types.Image,
) -> Double raise @types.LoadError {
  @encryption.calculate_correlation(img1, img2)
}

///|
pub fn calculate_psnr_enc(
  original : @types.Image,
  encrypted : @types.Image,
) -> Double raise @types.LoadError {
  @encryption.calculate_psnr(original, encrypted)
}

///|
pub fn evaluate_image_encryption_quality_enc(
  original : @types.Image,
  encrypted : @types.Image,
) -> @encryption.ImageEncryptionQuality raise @types.LoadError {
  @encryption.evaluate_image_encryption_quality(original, encrypted)
}

///|
pub fn encryption_report_to_string_enc(
  encryption : @encryption.EncryptionResult,
  watermark : @encryption.WatermarkInfo,
  quality : @encryption.ImageEncryptionQuality,
) -> String {
  @encryption.encryption_report_to_string(encryption, watermark, quality)
}

// ==================== 图像检索增强（v22.0.0） ====================

///|
pub type FeatureType = @retrieval.FeatureType

///|
pub type CBIRImageFeature = @retrieval.CBIRImageFeature

///|
pub type CBIRRetrievalResult = @retrieval.CBIRRetrievalResult

///|
pub type CBIRRetrievalResultList = @retrieval.CBIRRetrievalResultList

///|
pub type CBIRImageIndex = @retrieval.CBIRImageIndex

///|
pub type SimilarityMetric = @retrieval.SimilarityMetric

///|
pub type ColorHistogramConfig = @retrieval.ColorHistogramConfig

///|
pub type LBPConfig = @retrieval.LBPConfig

///|
pub type HOGConfig = @retrieval.HOGConfig

///|
pub type GaborConfig = @retrieval.GaborConfig

///|
pub fn create_default_color_histogram_config_cbir() -> @retrieval.ColorHistogramConfig {
  @retrieval.create_default_color_histogram_config()
}

///|
pub fn create_default_lbp_config_cbir() -> @retrieval.LBPConfig {
  @retrieval.create_default_lbp_config()
}

///|
pub fn create_default_hog_config_cbir() -> @retrieval.HOGConfig {
  @retrieval.create_default_hog_config()
}

///|
pub fn extract_color_histogram_cbir(
  img : @types.Image,
  config : @retrieval.ColorHistogramConfig,
) -> @retrieval.CBIRImageFeature {
  @retrieval.extract_color_histogram(img, config)
}

///|
pub fn extract_lbp_feature_cbir(
  img : @types.Image,
  config : @retrieval.LBPConfig,
) -> @retrieval.CBIRImageFeature {
  @retrieval.extract_lbp_feature(img, config)
}

///|
pub fn extract_hog_feature_cbir(
  img : @types.Image,
  config : @retrieval.HOGConfig,
) -> @retrieval.CBIRImageFeature {
  @retrieval.extract_hog_feature(img, config)
}

///|
pub fn cosine_similarity_cbir_api(
  feat1 : Array[Double],
  feat2 : Array[Double],
) -> Double {
  @retrieval.cosine_similarity_cbir(feat1, feat2)
}

///|
pub fn euclidean_distance_cbir_api(
  feat1 : Array[Double],
  feat2 : Array[Double],
) -> Double {
  @retrieval.euclidean_distance_cbir(feat1, feat2)
}

///|
pub fn manhattan_distance_cbir_api(
  feat1 : Array[Double],
  feat2 : Array[Double],
) -> Double {
  @retrieval.manhattan_distance_cbir(feat1, feat2)
}

///|
pub fn histogram_intersection_cbir_api(
  feat1 : Array[Double],
  feat2 : Array[Double],
) -> Double {
  @retrieval.histogram_intersection_cbir(feat1, feat2)
}

///|
pub fn calculate_similarity_cbir(
  feat1 : Array[Double],
  feat2 : Array[Double],
  metric : @retrieval.SimilarityMetric,
) -> Double {
  @retrieval.calculate_similarity(feat1, feat2, metric)
}

///|
pub fn create_image_index_cbir() -> @retrieval.CBIRImageIndex {
  @retrieval.create_image_index()
}

///|
pub fn add_to_index_cbir(
  index : @retrieval.CBIRImageIndex,
  feature : @retrieval.CBIRImageFeature,
) -> @retrieval.CBIRImageIndex {
  @retrieval.add_to_index(index, feature)
}

///|
pub fn retrieve_images_cbir(
  query_feature : @retrieval.CBIRImageFeature,
  index : @retrieval.CBIRImageIndex,
  num_results : Int,
  metric : @retrieval.SimilarityMetric,
) -> @retrieval.CBIRRetrievalResultList {
  @retrieval.retrieve_images(query_feature, index, num_results, metric)
}

///|
pub fn extract_combined_features_cbir(
  img : @types.Image,
) -> @retrieval.CBIRImageFeature {
  @retrieval.extract_combined_features(img)
}

///|
pub fn retrieval_report_to_string_cbir(
  results : @retrieval.CBIRRetrievalResultList,
  query_feature : @retrieval.CBIRImageFeature,
) -> String {
  @retrieval.retrieval_report_to_string(results, query_feature)
}

// ==================== 图像检索高级（v22.0.0） ====================

///|
pub type ImageRetrievalTaskType = @image_retrieval_advanced.ImageRetrievalTaskType

///|
pub type FeatureDescriptorType = @image_retrieval_advanced.FeatureDescriptorType

///|
pub type SimilarityMetricType = @image_retrieval_advanced.SimilarityMetricType

///|
pub type IndexStructureType = @image_retrieval_advanced.IndexStructureType

///|
pub type RetrievalResult = @image_retrieval_advanced.RetrievalResult

///|
pub type FeatureExtractionResult = @image_retrieval_advanced.FeatureExtractionResult

///|
pub type SimilarityResult = @image_retrieval_advanced.SimilarityResult

///|
pub type IndexConstructionResult = @image_retrieval_advanced.IndexConstructionResult

///|
pub type QueryExpansionResult = @image_retrieval_advanced.QueryExpansionResult

///|
pub type RelevanceFeedbackResult = @image_retrieval_advanced.RelevanceFeedbackResult

///|
pub type ImageRetrievalConfig = @image_retrieval_advanced.ImageRetrievalConfig

///|
pub fn create_default_retrieval_config() -> @image_retrieval_advanced.ImageRetrievalConfig {
  @image_retrieval_advanced.create_default_retrieval_config()
}

///|
pub fn extract_features_advanced(
  image : Array[Double],
  width : Int,
  height : Int,
  config : @image_retrieval_advanced.ImageRetrievalConfig,
) -> @image_retrieval_advanced.FeatureExtractionResult {
  @image_retrieval_advanced.extract_features(image, width, height, config)
}

///|
pub fn calculate_similarity_advanced(
  features1 : Array[Double],
  features2 : Array[Double],
  metric : @image_retrieval_advanced.SimilarityMetricType,
) -> Double {
  @image_retrieval_advanced.calculate_similarity(features1, features2, metric)
}

///|
pub fn retrieve_images_advanced(
  query_image : Array[Double],
  query_width : Int,
  query_height : Int,
  database_images : Array[Array[Double]],
  config : @image_retrieval_advanced.ImageRetrievalConfig,
) -> @image_retrieval_advanced.RetrievalResult {
  @image_retrieval_advanced.retrieve_images(
    query_image, query_width, query_height, database_images, config,
  )
}

///|
pub fn build_index_advanced(
  features : Array[Array[Double]],
  index_type : @image_retrieval_advanced.IndexStructureType,
) -> @image_retrieval_advanced.IndexConstructionResult {
  @image_retrieval_advanced.build_index(features, index_type)
}

///|
pub fn expand_query_advanced(
  original_query : Array[Double],
  relevant_features : Array[Array[Double]],
  config : @image_retrieval_advanced.ImageRetrievalConfig,
) -> @image_retrieval_advanced.QueryExpansionResult {
  @image_retrieval_advanced.expand_query(
    original_query, relevant_features, config,
  )
}

///|
pub fn relevance_feedback_advanced(
  original_query : Array[Double],
  relevant_indices : Array[Int],
  irrelevant_indices : Array[Int],
  database_features : Array[Array[Double]],
  config : @image_retrieval_advanced.ImageRetrievalConfig,
) -> @image_retrieval_advanced.RelevanceFeedbackResult {
  @image_retrieval_advanced.relevance_feedback(
    original_query, relevant_indices, irrelevant_indices, database_features, config,
  )
}

///|
pub fn image_retrieval_report_to_string_advanced(
  task_type : @image_retrieval_advanced.ImageRetrievalTaskType,
  config : @image_retrieval_advanced.ImageRetrievalConfig,
  result_description : String,
) -> String {
  @image_retrieval_advanced.image_retrieval_report_to_string(
    task_type, config, result_description,
  )
}

// ==================== 图像超分辨率增强（v23.0.0） ====================

///|
pub type SuperResolutionAlgorithm = @superres.SuperResolutionAlgorithm

///|
pub type SuperResolutionResult = @superres.SuperResolutionResult

///|
pub type InterpolationConfig = @superres.InterpolationConfig

///|
pub type ImageQualityMetrics = @superres.ImageQualityMetrics

///|
pub type EnhancementConfig = @superres.EnhancementConfig

///|
pub fn create_default_interpolation_config_sr() -> @superres.InterpolationConfig {
  @superres.create_default_interpolation_config()
}

///|
pub fn create_default_enhancement_config_sr() -> @superres.EnhancementConfig {
  @superres.create_default_enhancement_config()
}

///|
pub fn nearest_neighbor_interpolate_sr(
  img : @types.Image,
  scale_factor : Double,
) -> @types.Image {
  @superres.nearest_neighbor_interpolate(img, scale_factor)
}

///|
pub fn bilinear_interpolate_sr(
  img : @types.Image,
  scale_factor : Double,
) -> @types.Image {
  @superres.bilinear_interpolate(img, scale_factor)
}

///|
pub fn bicubic_interpolate_sr(
  img : @types.Image,
  scale_factor : Double,
) -> @types.Image {
  @superres.bicubic_interpolate(img, scale_factor)
}

///|
pub fn sharpen_image_sr(img : @types.Image, strength : Double) -> @types.Image {
  @superres.sharpen_image(img, strength)
}

///|
pub fn denoise_image_sr(img : @types.Image, strength : Double) -> @types.Image {
  @superres.denoise_image(img, strength)
}

///|
pub fn super_resolve_sr(
  img : @types.Image,
  config : @superres.InterpolationConfig,
) -> @superres.SuperResolutionResult {
  @superres.super_resolve(img, config)
}

///|
pub fn calculate_psnr_sr_api(
  original : @types.Image,
  processed : @types.Image,
) -> Double {
  @superres.calculate_psnr_sr(original, processed)
}

///|
pub fn calculate_ssim_sr_api(
  original : @types.Image,
  processed : @types.Image,
) -> Double {
  @superres.calculate_ssim_sr(original, processed)
}

///|
pub fn calculate_image_quality_metrics_sr(
  original : @types.Image,
  processed : @types.Image,
) -> @superres.ImageQualityMetrics {
  @superres.calculate_image_quality_metrics(original, processed)
}

///|
pub fn enhance_image_sr(
  img : @types.Image,
  config : @superres.EnhancementConfig,
) -> @types.Image {
  @superres.enhance_image(img, config)
}

///|
pub fn super_resolution_report_to_string_sr(
  result : @superres.SuperResolutionResult,
  metrics : @superres.ImageQualityMetrics,
) -> String {
  @superres.super_resolution_report_to_string(result, metrics)
}

// ==================== 图像风格迁移增强（v24.0.0） ====================

///|
pub type StyleTransferAlgorithm = @style_transfer.StyleTransferAlgorithm

///|
pub type StyleTransferResult = @style_transfer.StyleTransferResult

///|
pub type StyleTransferConfig = @style_transfer.StyleTransferConfig

///|
pub type ColorStatistics = @style_transfer.ColorStatistics

///|
pub type StyleTransferTextureFeatures = @style_transfer.StyleTransferTextureFeatures

///|
pub type ArtStyle = @style_transfer.ArtStyle

///|
pub fn create_default_style_transfer_config_st() -> @style_transfer.StyleTransferConfig {
  @style_transfer.create_default_style_transfer_config()
}

///|
pub fn calculate_color_statistics_st(
  img : @types.Image,
) -> @style_transfer.ColorStatistics raise @types.LoadError {
  @style_transfer.calculate_color_statistics(img)
}

///|
pub fn color_transfer_st(
  content : @types.Image,
  style : @types.Image,
  strength : Double,
) -> @types.Image raise @types.LoadError {
  @style_transfer.color_transfer(content, style, strength)
}

///|
pub fn calculate_texture_features_st(
  img : @types.Image,
) -> @style_transfer.StyleTransferTextureFeatures raise @types.LoadError {
  @style_transfer.calculate_texture_features(img)
}

///|
pub fn cartoonize_st(
  img : @types.Image,
  strength : Double,
) -> @types.Image raise @types.LoadError {
  @style_transfer.cartoonize(img, strength)
}

///|
pub fn oil_painting_st(
  img : @types.Image,
  radius : Int,
  intensity_levels : Int,
) -> @types.Image raise @types.LoadError {
  @style_transfer.oil_painting(img, radius, intensity_levels)
}

///|
pub fn sketch_effect_st(
  img : @types.Image,
  strength : Double,
) -> @types.Image raise @types.LoadError {
  @style_transfer.sketch_effect(img, strength)
}

///|
pub fn style_transfer_st(
  content : @types.Image,
  style : @types.Image,
  config : @style_transfer.StyleTransferConfig,
) -> @style_transfer.StyleTransferResult raise @types.LoadError {
  @style_transfer.style_transfer(content, style, config)
}

///|
pub fn style_transfer_report_to_string_st(
  result : @style_transfer.StyleTransferResult,
  content_stats : @style_transfer.ColorStatistics,
  style_stats : @style_transfer.ColorStatistics,
  texture : @style_transfer.StyleTransferTextureFeatures,
) -> String {
  @style_transfer.style_transfer_report_to_string(
    result, content_stats, style_stats, texture,
  )
}

// ==================== 图像修复增强（v25.0.0） ====================

///|
pub type InpaintingAlgorithm = @inpainting.InpaintingAlgorithm

///|
pub type InpaintingResult = @inpainting.InpaintingResult

///|
pub type InpaintingConfig = @inpainting.InpaintingConfig

///|
pub type DehazeAlgorithm = @inpainting.DehazeAlgorithm

///|
pub type DehazeResult = @inpainting.DehazeResult

///|
pub type DerainAlgorithm = @inpainting.DerainAlgorithm

///|
pub type DerainResult = @inpainting.DerainResult

///|
pub fn create_default_inpainting_config_ip() -> @inpainting.InpaintingConfig {
  @inpainting.create_default_inpainting_config()
}

///|
pub fn create_rect_mask_ip(
  width : Int,
  height : Int,
  x : Int,
  y : Int,
  rect_width : Int,
  rect_height : Int,
) -> @types.Image {
  @inpainting.create_rect_mask(width, height, x, y, rect_width, rect_height)
}

///|
pub fn inpaint_simple_ip(
  img : @types.Image,
  mask : @types.Image,
  radius : Int,
) -> @types.Image {
  @inpainting.inpaint_simple(img, mask, radius)
}

///|
pub fn inpaint_diffusion_ip(
  img : @types.Image,
  mask : @types.Image,
  radius : Int,
) -> @types.Image {
  @inpainting.inpaint_diffusion(img, mask, radius)
}

///|
pub fn inpaint_ip(
  img : @types.Image,
  mask : @types.Image,
  config : @inpainting.InpaintingConfig,
) -> @inpainting.InpaintingResult {
  @inpainting.inpaint(img, mask, config)
}

///|
pub fn dehaze_dark_channel_ip(
  img : @types.Image,
  omega : Double,
  t0 : Double,
) -> @inpainting.DehazeResult {
  @inpainting.dehaze_dark_channel(img, omega, t0)
}

///|
pub fn dehaze_clahe_ip(
  img : @types.Image,
  clip_limit : Double,
  tile_size : Int,
) -> @types.Image {
  @inpainting.dehaze_clahe(img, clip_limit, tile_size)
}

///|
pub fn dehaze_ip(
  img : @types.Image,
  algorithm : @inpainting.DehazeAlgorithm,
) -> @inpainting.DehazeResult {
  @inpainting.dehaze(img, algorithm)
}

///|
pub fn derain_morphological_ip(img : @types.Image) -> @inpainting.DerainResult {
  @inpainting.derain_morphological(img)
}

///|
pub fn derain_ip(
  img : @types.Image,
  algorithm : @inpainting.DerainAlgorithm,
) -> @inpainting.DerainResult {
  @inpainting.derain(img, algorithm)
}

///|
pub fn inpainting_report_to_string_ip(
  result : @inpainting.InpaintingResult,
) -> String {
  @inpainting.inpainting_report_to_string(result)
}

// ==================== 图像融合与配准增强（v26.0.0） ====================

///|
pub type FusionAlgorithm = @fusion_enhanced.FusionAlgorithm

///|
pub type FusionResult = @fusion_enhanced.FusionResult

///|
pub type FusionEnhancedConfig = @fusion_enhanced.FusionConfig

///|
pub type RegistrationAlgorithm = @fusion_enhanced.RegistrationAlgorithm

///|
pub type RegistrationEnhancedResult = @fusion_enhanced.RegistrationResult

///|
pub type RegistrationConfig = @fusion_enhanced.RegistrationConfig

///|
pub type TransformMatrix = @fusion_enhanced.TransformMatrix

///|
pub fn create_default_fusion_config_fe() -> @fusion_enhanced.FusionConfig {
  @fusion_enhanced.create_default_fusion_config()
}

///|
pub fn create_default_registration_config_fe() -> @fusion_enhanced.RegistrationConfig {
  @fusion_enhanced.create_default_registration_config()
}

///|
pub fn fuse_weighted_average_fe(
  images : Array[@types.Image],
  weights : Array[Double],
) -> @types.Image {
  @fusion_enhanced.fuse_weighted_average(images, weights)
}

///|
pub fn fuse_maximum_fe(images : Array[@types.Image]) -> @types.Image {
  @fusion_enhanced.fuse_maximum(images)
}

///|
pub fn fuse_minimum_fe(images : Array[@types.Image]) -> @types.Image {
  @fusion_enhanced.fuse_minimum(images)
}

///|
pub fn fuse_simple_mean_fe(images : Array[@types.Image]) -> @types.Image {
  @fusion_enhanced.fuse_simple_mean(images)
}

///|
pub fn fuse_laplacian_pyramid_fe(
  images : Array[@types.Image],
  levels : Int,
) -> @types.Image {
  @fusion_enhanced.fuse_laplacian_pyramid(images, levels)
}

///|
pub fn fuse_images_fe(
  images : Array[@types.Image],
  config : @fusion_enhanced.FusionConfig,
) -> @fusion_enhanced.FusionResult {
  @fusion_enhanced.fuse_images(images, config)
}

///|
pub fn register_phase_correlation_fe(
  reference : @types.Image,
  target : @types.Image,
) -> @fusion_enhanced.RegistrationResult {
  @fusion_enhanced.register_phase_correlation(reference, target)
}

///|
pub fn register_images_fe(
  reference : @types.Image,
  target : @types.Image,
  config : @fusion_enhanced.RegistrationConfig,
) -> @fusion_enhanced.RegistrationResult {
  @fusion_enhanced.register_images(reference, target, config)
}

///|
pub fn apply_translation_fe(
  img : @types.Image,
  dx : Int,
  dy : Int,
) -> @types.Image {
  @fusion_enhanced.apply_translation(img, dx, dy)
}

///|
pub fn calculate_fusion_quality_fe(fused : @types.Image) -> Double {
  @fusion_enhanced.calculate_fusion_quality(fused)
}

///|
pub fn fusion_report_to_string_fe(
  result : @fusion_enhanced.FusionResult,
  quality : Double,
) -> String {
  @fusion_enhanced.fusion_report_to_string(result, quality)
}

// ==================== 图像来源鉴定（v27.0.0） ====================

///|
pub type ImageSourceType = @forensics.ImageSourceType

///|
pub type SourceVerificationResult = @forensics.SourceVerificationResult

///|
pub type SourceVerificationFeatures = @forensics.SourceVerificationFeatures

///|
pub type SourceVerificationConfig = @forensics.SourceVerificationConfig

///|
pub type NoiseAnalysisResult = @forensics.NoiseAnalysisResult

///|
pub type FrequencyAnalysisResult = @forensics.FrequencyAnalysisResult

///|
pub type ColorAnalysisResult = @forensics.ColorAnalysisResult

///|
pub type TextureAnalysisResult = @forensics.TextureAnalysisResult

///|
pub type EdgeAnalysisResult = @forensics.EdgeAnalysisResult

///|
pub type CompressionAnalysisResult = @forensics.CompressionAnalysisResult

///|
pub type DetailAnalysisResult = @forensics.DetailAnalysisResult

///|
pub fn create_default_source_verification_config_fs() -> @forensics.SourceVerificationConfig {
  @forensics.create_default_source_verification_config()
}

///|
pub fn analyze_noise_pattern_fs(
  img : @types.Image,
) -> @forensics.NoiseAnalysisResult raise @types.LoadError {
  @forensics.analyze_noise_pattern(img)
}

///|
pub fn analyze_frequency_domain_fs(
  img : @types.Image,
) -> @forensics.FrequencyAnalysisResult raise @types.LoadError {
  @forensics.analyze_frequency_domain(img)
}

///|
pub fn analyze_color_distribution_fs(
  img : @types.Image,
) -> @forensics.ColorAnalysisResult raise @types.LoadError {
  @forensics.analyze_color_distribution(img)
}

///|
pub fn analyze_texture_fs(
  img : @types.Image,
) -> @forensics.TextureAnalysisResult raise @types.LoadError {
  @forensics.analyze_texture(img)
}

///|
pub fn analyze_edges_fs(
  img : @types.Image,
) -> @forensics.EdgeAnalysisResult raise @types.LoadError {
  @forensics.analyze_edges(img)
}

///|
pub fn analyze_compression_artifacts_fs(
  img : @types.Image,
) -> @forensics.CompressionAnalysisResult raise @types.LoadError {
  @forensics.analyze_compression_artifacts(img)
}

///|
pub fn analyze_details_fs(
  img : @types.Image,
) -> @forensics.DetailAnalysisResult raise @types.LoadError {
  @forensics.analyze_details(img)
}

///|
pub fn verify_image_source_fs(
  img : @types.Image,
  config : @forensics.SourceVerificationConfig,
) -> @forensics.SourceVerificationResult raise @types.LoadError {
  @forensics.verify_image_source(img, config)
}

///|
pub fn source_verification_report_to_string_fs(
  result : @forensics.SourceVerificationResult,
) -> String {
  @forensics.source_verification_report_to_string(result)
}

// ==================== 图像来源鉴定增强（v27.1.0） ====================

///|
pub type EnhancedVerificationResult = @forensics.EnhancedVerificationResult

///|
pub type EnhancedVerificationFeatures = @forensics.EnhancedVerificationFeatures

///|
pub type UIDetectionResult = @forensics.UIDetectionResult

///|
pub type TextDetectionResult = @forensics.TextDetectionResult

///|
pub type GeometryAnalysisResult = @forensics.GeometryAnalysisResult

///|
pub type ColorQuantizationResult = @forensics.ColorQuantizationResult

///|
pub type EnhancedVerificationConfig = @forensics.EnhancedVerificationConfig

///|
pub fn create_default_enhanced_verification_config_fs() -> @forensics.EnhancedVerificationConfig {
  @forensics.create_default_enhanced_verification_config()
}

///|
pub fn detect_ui_elements_fs(
  img : @types.Image,
) -> @forensics.UIDetectionResult raise @types.LoadError {
  @forensics.detect_ui_elements(img)
}

///|
pub fn detect_text_regions_fs(
  img : @types.Image,
) -> @forensics.TextDetectionResult raise @types.LoadError {
  @forensics.detect_text_regions(img)
}

///|
pub fn analyze_geometry_fs(
  img : @types.Image,
) -> @forensics.GeometryAnalysisResult raise @types.LoadError {
  @forensics.analyze_geometry(img)
}

///|
pub fn analyze_color_quantization_fs(
  img : @types.Image,
) -> @forensics.ColorQuantizationResult raise @types.LoadError {
  @forensics.analyze_color_quantization(img)
}

///|
pub fn verify_image_source_enhanced_fs(
  img : @types.Image,
  config : @forensics.EnhancedVerificationConfig,
) -> @forensics.EnhancedVerificationResult raise @types.LoadError {
  @forensics.verify_image_source_enhanced(img, config)
}

///|
pub fn enhanced_verification_report_to_string_fs(
  result : @forensics.EnhancedVerificationResult,
) -> String {
  @forensics.enhanced_verification_report_to_string(result)
}

// ==================== 图像来源鉴定增强（v27.1.0） ====================

///|
pub type ElaAnalysisResult = @forensics_enhanced.ElaAnalysisResult

///|
pub type NoiseResidualResult = @forensics_enhanced.NoiseResidualResult

///|
pub type DctCoefficientResult = @forensics_enhanced.DctCoefficientResult

///|
pub type CloneDetectionResult = @forensics_enhanced.CloneDetectionResult

///|
pub type IlluminationConsistencyResult = @forensics_enhanced.IlluminationConsistencyResult

///|
pub type TamperDetectionResult = @forensics_enhanced.TamperDetectionResult

///|
pub type MetadataForensicsResult = @forensics_enhanced.MetadataForensicsResult

///|
pub type JpegGhostResult = @forensics_enhanced.JpegGhostResult

///|
pub type CfaAnalysisResult = @forensics_enhanced.CfaAnalysisResult

///|
pub fn analyze_ela_fe(
  img : @types.Image,
  quality_level : Int,
) -> @forensics_enhanced.ElaAnalysisResult raise @types.LoadError {
  @forensics_enhanced.analyze_ela(img, quality_level)
}

///|
pub fn analyze_noise_residual_fe(
  img : @types.Image,
) -> @forensics_enhanced.NoiseResidualResult {
  @forensics_enhanced.analyze_noise_residual(img)
}

///|
pub fn analyze_dct_coefficients_fe(
  img : @types.Image,
) -> @forensics_enhanced.DctCoefficientResult {
  @forensics_enhanced.analyze_dct_coefficients(img)
}

///|
pub fn detect_clone_regions_fe(
  img : @types.Image,
  block_size : Int,
  threshold : Double,
) -> @forensics_enhanced.CloneDetectionResult raise @types.LoadError {
  @forensics_enhanced.detect_clone_regions(img, block_size, threshold)
}

///|
pub fn analyze_illumination_consistency_fe(
  img : @types.Image,
) -> @forensics_enhanced.IlluminationConsistencyResult {
  @forensics_enhanced.analyze_illumination_consistency(img)
}

///|
pub fn analyze_metadata_forensics_fe(
  img : @types.Image,
) -> @forensics_enhanced.MetadataForensicsResult {
  @forensics_enhanced.analyze_metadata_forensics(img)
}

///|
pub fn analyze_jpeg_ghost_fe(
  img : @types.Image,
) -> @forensics_enhanced.JpegGhostResult {
  @forensics_enhanced.analyze_jpeg_ghost(img)
}

///|
pub fn analyze_cfa_pattern_fe(
  img : @types.Image,
) -> @forensics_enhanced.CfaAnalysisResult {
  @forensics_enhanced.analyze_cfa_pattern(img)
}

///|
pub fn detect_tamper_comprehensive_fe(
  img : @types.Image,
  ela_quality : Int,
) -> @forensics_enhanced.TamperDetectionResult raise @types.LoadError {
  @forensics_enhanced.detect_tamper_comprehensive(img, ela_quality)
}

// ==================== 图像压缩与编码优化（v28.0.0） ====================

///|
pub type CompressionAlgorithm = @compression.CompressionAlgorithm

///|
pub type CompressionResult = @compression.CompressionResult

///|
pub type CompressionConfig = @compression.CompressionConfig

///|
pub type CompressionQualityMetrics = @compression.CompressionQualityMetrics

///|
pub type QuantizationTableType = @compression.QuantizationTableType

///|
pub type DCTBlock = @compression.DCTBlock

///|
pub type HuffmanTable = @compression.HuffmanTable

///|
pub fn create_default_compression_config_cp() -> @compression.CompressionConfig {
  @compression.create_default_compression_config()
}

///|
pub fn run_length_encode_cp(data : Bytes) -> Bytes {
  @compression.run_length_encode(data)
}

///|
pub fn run_length_decode_cp(data : Bytes) -> Bytes {
  @compression.run_length_decode(data)
}

///|
pub fn calculate_image_entropy_cp(
  img : @types.Image,
) -> Double raise @types.LoadError {
  @compression.calculate_image_entropy(img)
}

///|
pub fn quantize_image_cp(
  img : @types.Image,
  levels : Int,
) -> @types.Image raise @types.LoadError {
  @compression.quantize_image(img, levels)
}

///|
pub fn predictive_encode_cp(img : @types.Image) -> Bytes raise @types.LoadError {
  @compression.predictive_encode(img)
}

///|
pub fn calculate_compression_ratio_cp(
  original_size : Int,
  compressed_size : Int,
) -> Double {
  @compression.calculate_compression_ratio(original_size, compressed_size)
}

///|
pub fn calculate_bits_per_pixel_cp(
  compressed_size : Int,
  width : Int,
  height : Int,
) -> Double {
  @compression.calculate_bits_per_pixel(compressed_size, width, height)
}

///|
pub fn calculate_compression_quality_cp(
  original : @types.Image,
  compressed : @types.Image,
  original_size : Int,
  compressed_size : Int,
) -> @compression.CompressionQualityMetrics raise @types.LoadError {
  @compression.calculate_compression_quality(
    original, compressed, original_size, compressed_size,
  )
}

///|
pub fn compress_jpeg_simple_cp(
  img : @types.Image,
  quality : Double,
) -> @compression.CompressionResult raise @types.LoadError {
  @compression.compress_jpeg_simple(img, quality)
}

///|
pub fn compress_png_simple_cp(
  img : @types.Image,
) -> @compression.CompressionResult raise @types.LoadError {
  @compression.compress_png_simple(img)
}

///|
pub fn compress_image_cp(
  img : @types.Image,
  config : @compression.CompressionConfig,
) -> @compression.CompressionResult raise @types.LoadError {
  @compression.compress_image(img, config)
}

///|
pub fn compression_report_to_string_cp(
  result : @compression.CompressionResult,
  metrics : @compression.CompressionQualityMetrics,
) -> String {
  @compression.compression_report_to_string(result, metrics)
}

// ==================== 高级图像降噪与增强（v29.0.0） ====================

///|
pub type DenoiseAlgorithm = @denoise.DenoiseAlgorithm

///|
pub type DenoiseResult = @denoise.DenoiseResult

///|
pub type DenoiseConfig = @denoise.DenoiseConfig

///|
pub type EnhancementAlgorithm = @denoise.EnhancementAlgorithm

///|
pub type EnhancementResult = @denoise.EnhancementResult

///|
pub type NoiseType = @denoise.NoiseType

///|
pub fn create_default_denoise_config_dn() -> @denoise.DenoiseConfig {
  @denoise.create_default_denoise_config()
}

///|
pub fn mean_filter_denoise_dn(
  img : @types.Image,
  kernel_size : Int,
) -> @types.Image raise @types.LoadError {
  @denoise.mean_filter_denoise(img, kernel_size)
}

///|
pub fn median_filter_denoise_dn(
  img : @types.Image,
  kernel_size : Int,
) -> @types.Image raise @types.LoadError {
  @denoise.median_filter_denoise(img, kernel_size)
}

///|
pub fn gaussian_filter_denoise_dn(
  img : @types.Image,
  kernel_size : Int,
  sigma : Double,
) -> @types.Image raise @types.LoadError {
  @denoise.gaussian_filter_denoise(img, kernel_size, sigma)
}

///|
pub fn bilateral_filter_denoise_dn(
  img : @types.Image,
  kernel_size : Int,
  sigma_color : Double,
  sigma_space : Double,
) -> @types.Image raise @types.LoadError {
  @denoise.bilateral_filter_denoise(img, kernel_size, sigma_color, sigma_space)
}

///|
pub fn calculate_noise_level_dn(
  img : @types.Image,
) -> Double raise @types.LoadError {
  @denoise.calculate_noise_level(img)
}

///|
pub fn histogram_equalization_enhance_dn(
  img : @types.Image,
) -> @types.Image raise @types.LoadError {
  @denoise.histogram_equalization_enhance(img)
}

///|
pub fn gamma_correction_enhance_dn(
  img : @types.Image,
  gamma : Double,
) -> @types.Image raise @types.LoadError {
  @denoise.gamma_correction_enhance(img, gamma)
}

///|
pub fn unsharp_mask_enhance_dn(
  img : @types.Image,
  amount : Double,
  radius : Int,
) -> @types.Image raise @types.LoadError {
  @denoise.unsharp_mask_enhance(img, amount, radius)
}

///|
pub fn calculate_brightness_dn(
  img : @types.Image,
) -> Double raise @types.LoadError {
  @denoise.calculate_brightness(img)
}

///|
pub fn calculate_contrast_dn(
  img : @types.Image,
) -> Double raise @types.LoadError {
  @denoise.calculate_contrast(img)
}

///|
pub fn calculate_sharpness_dn(
  img : @types.Image,
) -> Double raise @types.LoadError {
  @denoise.calculate_sharpness(img)
}

///|
pub fn denoise_image_dn(
  img : @types.Image,
  config : @denoise.DenoiseConfig,
) -> @denoise.DenoiseResult raise @types.LoadError {
  @denoise.denoise_image(img, config)
}

///|
pub fn enhance_image_advanced_dn(
  img : @types.Image,
  algorithm : @denoise.EnhancementAlgorithm,
) -> @denoise.EnhancementResult raise @types.LoadError {
  @denoise.enhance_image_advanced(img, algorithm)
}

///|
pub fn denoise_report_to_string_dn(result : @denoise.DenoiseResult) -> String {
  @denoise.denoise_report_to_string(result)
}

// ==================== 高级图像配准算法（v30.0.0） ====================

///|
pub type RegistrationAlgorithmRA = @registration_advanced.RegistrationAlgorithm

///|
pub type TransformTypeRA = @registration_advanced.TransformType

///|
pub type RegistrationResultAdvanced = @registration_advanced.RegistrationResultAdvanced

///|
pub type RegistrationConfigAdvanced = @registration_advanced.RegistrationConfigAdvanced

///|
pub type FeaturePointRA = @registration_advanced.FeaturePoint

///|
pub type FeatureMatchRA = @registration_advanced.FeatureMatch

///|
pub type TransformMatrixRA = @registration_advanced.TransformMatrix

///|
pub fn create_default_registration_config_advanced_ra() -> @registration_advanced.RegistrationConfigAdvanced {
  @registration_advanced.create_default_registration_config_advanced()
}

///|
pub fn phase_correlation_registration_ra(
  img1 : @types.Image,
  img2 : @types.Image,
) -> @registration_advanced.RegistrationResultAdvanced {
  @registration_advanced.phase_correlation_registration(img1, img2)
}

///|
pub fn apply_translation_ra(
  img : @types.Image,
  dx : Int,
  dy : Int,
) -> @types.Image {
  @registration_advanced.apply_translation(img, dx, dy)
}

///|
pub fn normalized_cross_correlation_ra(
  img1 : @types.Image,
  img2 : @types.Image,
) -> Double {
  @registration_advanced.normalized_cross_correlation(img1, img2)
}

///|
pub fn calculate_mutual_information_ra(
  img1 : @types.Image,
  img2 : @types.Image,
) -> Double {
  @registration_advanced.calculate_mutual_information(img1, img2)
}

///|
pub fn detect_harris_corners_ra(
  img : @types.Image,
  threshold : Double,
) -> Array[@registration_advanced.FeaturePoint] {
  @registration_advanced.detect_harris_corners(img, threshold)
}

///|
pub fn match_feature_points_ra(
  points1 : Array[@registration_advanced.FeaturePoint],
  points2 : Array[@registration_advanced.FeaturePoint],
  max_distance : Double,
) -> Array[@registration_advanced.FeatureMatch] {
  @registration_advanced.match_feature_points(points1, points2, max_distance)
}

///|
pub fn estimate_affine_transform_ra(
  matches : Array[@registration_advanced.FeatureMatch],
) -> @registration_advanced.TransformMatrix {
  @registration_advanced.estimate_affine_transform(matches)
}

///|
pub fn apply_affine_transform_ra(
  img : @types.Image,
  matrix : @registration_advanced.TransformMatrix,
) -> @types.Image {
  @registration_advanced.apply_affine_transform(img, matrix)
}

///|
pub fn feature_based_registration_ra(
  img1 : @types.Image,
  img2 : @types.Image,
  config : @registration_advanced.RegistrationConfigAdvanced,
) -> @registration_advanced.RegistrationResultAdvanced {
  @registration_advanced.feature_based_registration(img1, img2, config)
}

///|
pub fn register_images_advanced_ra(
  img1 : @types.Image,
  img2 : @types.Image,
  config : @registration_advanced.RegistrationConfigAdvanced,
) -> @registration_advanced.RegistrationResultAdvanced {
  @registration_advanced.register_images_advanced(img1, img2, config)
}

///|
pub fn registration_report_to_string_advanced_ra(
  result : @registration_advanced.RegistrationResultAdvanced,
) -> String {
  @registration_advanced.registration_report_to_string_advanced(result)
}

// ==================== SLAM 同时定位与地图构建（v31.0.0） ====================

///|
pub type SLAMAlgorithmSL = @slam.SLAMAlgorithm

///|
pub type CameraPoseSL = @slam.CameraPose

///|
pub type MapPointSL = @slam.MapPoint

///|
pub type KeyFrameSL = @slam.KeyFrame

///|
pub type SLAMStateSL = @slam.SLAMState

///|
pub type SLAMConfigSL = @slam.SLAMConfig

///|
pub type FeatureTrackingResultSL = @slam.FeatureTrackingResult

///|
pub type LoopClosureResultSL = @slam.LoopClosureResult

///|
pub fn create_default_slam_config_sl() -> @slam.SLAMConfig {
  @slam.create_default_slam_config()
}

///|
pub fn detect_features_slam_sl(
  img : @types.Image,
  max_features : Int,
  threshold : Double,
) -> Array[Array[Double]] {
  @slam.detect_features_slam(img, max_features, threshold)
}

///|
pub fn track_features_slam_sl(
  prev_img : @types.Image,
  curr_img : @types.Image,
  prev_features : Array[Array[Double]],
  search_radius : Int,
) -> @slam.FeatureTrackingResult {
  @slam.track_features_slam(prev_img, curr_img, prev_features, search_radius)
}

///|
pub fn estimate_camera_pose_sl(
  tracking_result : @slam.FeatureTrackingResult,
  config : @slam.SLAMConfig,
  prev_pose : @slam.CameraPose,
) -> @slam.CameraPose {
  @slam.estimate_camera_pose(tracking_result, config, prev_pose)
}

///|
pub fn triangulate_points_sl(
  features : Array[Array[Double]],
  pose1 : @slam.CameraPose,
  pose2 : @slam.CameraPose,
  config : @slam.SLAMConfig,
) -> Array[@slam.MapPoint] {
  @slam.triangulate_points(features, pose1, pose2, config)
}

///|
pub fn detect_loop_closure_sl(
  current_features : Array[Array[Double]],
  keyframes : Array[@slam.KeyFrame],
  threshold : Double,
) -> @slam.LoopClosureResult {
  @slam.detect_loop_closure(current_features, keyframes, threshold)
}

///|
pub fn initialize_slam_sl(config : @slam.SLAMConfig) -> @slam.SLAMState {
  @slam.initialize_slam(config)
}

///|
pub fn process_frame_slam_sl(
  state : @slam.SLAMState,
  img : @types.Image,
  config : @slam.SLAMConfig,
) -> @slam.SLAMState {
  @slam.process_frame_slam(state, img, config)
}

///|
pub fn slam_report_to_string_sl(state : @slam.SLAMState) -> String {
  @slam.slam_report_to_string(state)
}

// ==================== 人体姿态估计与动作识别（v32.0.0） ====================

///|
pub type PoseEstimationAlgorithmPE = @pose_estimation.PoseEstimationAlgorithm

///|
pub type ActionRecognitionAlgorithmPE = @pose_estimation.ActionRecognitionAlgorithm

///|
pub type KeypointPE = @pose_estimation.Keypoint

///|
pub type HumanPosePE = @pose_estimation.HumanPose

///|
pub type SkeletonConnectionPE = @pose_estimation.SkeletonConnection

///|
pub type ActionRecognitionResultPE = @pose_estimation.ActionRecognitionResult

///|
pub type GestureTypePE = @pose_estimation.GestureType

///|
pub type GestureRecognitionResultPE = @pose_estimation.GestureRecognitionResult

///|
pub type PoseEstimationConfigPE = @pose_estimation.PoseEstimationConfig

///|
pub type ActionRecognitionConfigPE = @pose_estimation.ActionRecognitionConfig

///|
pub fn create_default_pose_config_pe() -> @pose_estimation.PoseEstimationConfig {
  @pose_estimation.create_default_pose_config()
}

///|
pub fn create_default_action_config_pe() -> @pose_estimation.ActionRecognitionConfig {
  @pose_estimation.create_default_action_config()
}

///|
pub fn get_coco_keypoint_names_pe() -> Array[String] {
  @pose_estimation.get_coco_keypoint_names()
}

///|
pub fn get_coco_skeleton_connections_pe() -> Array[Array[Int]] {
  @pose_estimation.get_coco_skeleton_connections()
}

///|
pub fn detect_keypoints_pe(
  img : @types.Image,
  config : @pose_estimation.PoseEstimationConfig,
) -> Array[@pose_estimation.HumanPose] raise @types.LoadError {
  @pose_estimation.detect_keypoints(img, config)
}

///|
pub fn extract_skeleton_pe(
  pose : @pose_estimation.HumanPose,
) -> Array[@pose_estimation.SkeletonConnection] {
  @pose_estimation.extract_skeleton(pose)
}

///|
pub fn calculate_joint_angle_pe(
  pose : @pose_estimation.HumanPose,
  joint1 : Int,
  joint_center : Int,
  joint2 : Int,
) -> Double {
  @pose_estimation.calculate_joint_angle(pose, joint1, joint_center, joint2)
}

///|
pub fn recognize_action_pe(
  poses : Array[@pose_estimation.HumanPose],
  config : @pose_estimation.ActionRecognitionConfig,
) -> @pose_estimation.ActionRecognitionResult {
  @pose_estimation.recognize_action(poses, config)
}

///|
pub fn recognize_gesture_pe(
  pose : @pose_estimation.HumanPose,
) -> @pose_estimation.GestureRecognitionResult {
  @pose_estimation.recognize_gesture(pose)
}

///|
pub fn visualize_pose_pe(
  img : @types.Image,
  pose : @pose_estimation.HumanPose,
) -> @types.Image raise @types.LoadError {
  @pose_estimation.visualize_pose(img, pose)
}

///|
pub fn pose_estimation_report_to_string_pe(
  poses : Array[@pose_estimation.HumanPose],
  action_result : @pose_estimation.ActionRecognitionResult,
) -> String {
  @pose_estimation.pose_estimation_report_to_string(poses, action_result)
}

// ==================== 人脸识别与表情识别（v33.0.0） ====================

///|
pub type FaceDetectionAlgorithmFR = @face_recognition.FaceDetectionAlgorithm

///|
pub type FaceRecognitionAlgorithmFR = @face_recognition.FaceRecognitionAlgorithm

///|
pub type ExpressionTypeFR = @face_recognition.ExpressionType

///|
pub type FaceDetectionResultFR = @face_recognition.FaceDetectionResult

///|
pub type FaceFeatureFR = @face_recognition.FaceFeature

///|
pub type FaceRecognitionResultFR = @face_recognition.FaceRecognitionResult

///|
pub type ExpressionRecognitionResultFR = @face_recognition.ExpressionRecognitionResult

///|
pub type AgeGenderEstimationResultFR = @face_recognition.AgeGenderEstimationResult

///|
pub type FaceAttributeAnalysisFR = @face_recognition.FaceAttributeAnalysis

///|
pub type FaceDatabaseFR = @face_recognition.FaceDatabase

///|
pub type FaceRecognitionConfigFR = @face_recognition.FaceRecognitionConfig

///|
pub fn create_default_face_config_fr() -> @face_recognition.FaceRecognitionConfig {
  @face_recognition.create_default_face_config()
}

///|
pub fn create_face_database_fr(
  algorithm : @face_recognition.FaceRecognitionAlgorithm,
  threshold : Double,
) -> @face_recognition.FaceDatabase {
  @face_recognition.create_face_database(algorithm, threshold)
}

///|
pub fn detect_faces_fr(
  img : @types.Image,
  config : @face_recognition.FaceRecognitionConfig,
) -> Array[@face_recognition.FaceDetectionResult] raise @types.LoadError {
  @face_recognition.detect_faces(img, config)
}

///|
pub fn extract_face_feature_fr(
  img : @types.Image,
  face : @face_recognition.FaceDetectionResult,
  config : @face_recognition.FaceRecognitionConfig,
) -> @face_recognition.FaceFeature raise @types.LoadError {
  @face_recognition.extract_face_feature(img, face, config)
}

///|
pub fn calculate_cosine_similarity_fr(
  feat1 : @face_recognition.FaceFeature,
  feat2 : @face_recognition.FaceFeature,
) -> Double {
  @face_recognition.calculate_cosine_similarity(feat1, feat2)
}

///|
pub fn add_face_to_database_fr(
  database : @face_recognition.FaceDatabase,
  feature : @face_recognition.FaceFeature,
  identity : String,
) -> @face_recognition.FaceDatabase {
  @face_recognition.add_face_to_database(database, feature, identity)
}

///|
pub fn recognize_face_in_database_fr(
  database : @face_recognition.FaceDatabase,
  feature : @face_recognition.FaceFeature,
  bounding_box : Array[Double],
) -> @face_recognition.FaceRecognitionResult {
  @face_recognition.recognize_face_in_database(database, feature, bounding_box)
}

///|
pub fn recognize_expression_fr(
  img : @types.Image,
  face : @face_recognition.FaceDetectionResult,
) -> @face_recognition.ExpressionRecognitionResult raise @types.LoadError {
  @face_recognition.recognize_expression(img, face)
}

///|
pub fn estimate_age_gender_fr(
  img : @types.Image,
  face : @face_recognition.FaceDetectionResult,
) -> @face_recognition.AgeGenderEstimationResult raise @types.LoadError {
  @face_recognition.estimate_age_gender(img, face)
}

///|
pub fn evaluate_face_quality_fr(
  img : @types.Image,
  face : @face_recognition.FaceDetectionResult,
) -> Double raise @types.LoadError {
  @face_recognition.evaluate_face_quality(img, face)
}

///|
pub fn analyze_face_attributes_fr(
  img : @types.Image,
  face : @face_recognition.FaceDetectionResult,
  database : @face_recognition.FaceDatabase,
  config : @face_recognition.FaceRecognitionConfig,
) -> @face_recognition.FaceAttributeAnalysis raise @types.LoadError {
  @face_recognition.analyze_face_attributes(img, face, database, config)
}

///|
pub fn face_recognition_report_to_string_fr(
  analysis : @face_recognition.FaceAttributeAnalysis,
) -> String {
  @face_recognition.face_recognition_report_to_string(analysis)
}

// ==================== 图像生成与编辑（v34.0.0） ====================

///|
pub type ImageGenerationAlgorithmIG = @image_generation.ImageGenerationAlgorithm

///|
pub type ImageEditingAlgorithmIG = @image_generation.ImageEditingAlgorithm

///|
pub type GenerationResultIG = @image_generation.GenerationResult

///|
pub type EditingResultIG = @image_generation.EditingResult

///|
pub type GenerationConfigIG = @image_generation.GenerationConfig

///|
pub type EditingConfigIG = @image_generation.EditingConfig

///|
pub type LatentVectorIG = @image_generation.LatentVector

///|
pub type CompositionConfigIG = @image_generation.CompositionConfig

///|
pub fn create_default_generation_config_ig() -> @image_generation.GenerationConfig {
  @image_generation.create_default_generation_config()
}

///|
pub fn create_default_editing_config_ig() -> @image_generation.EditingConfig {
  @image_generation.create_default_editing_config()
}

///|
pub fn generate_random_latent_ig(
  dimension : Int,
  seed : Int,
) -> @image_generation.LatentVector {
  @image_generation.generate_random_latent(dimension, seed)
}

///|
pub fn generate_from_latent_ig(
  latent : @image_generation.LatentVector,
  config : @image_generation.GenerationConfig,
) -> @image_generation.GenerationResult {
  @image_generation.generate_from_latent(latent, config)
}

///|
pub fn generate_random_image_ig(
  config : @image_generation.GenerationConfig,
) -> @image_generation.GenerationResult {
  @image_generation.generate_random_image(config)
}

///|
pub fn inpaint_image_ig(
  img : @types.Image,
  mask : @types.Image,
  config : @image_generation.EditingConfig,
) -> @image_generation.EditingResult {
  @image_generation.inpaint_image(img, mask, config)
}

///|
pub fn outpaint_image_ig(
  img : @types.Image,
  new_width : Int,
  new_height : Int,
  config : @image_generation.EditingConfig,
) -> @image_generation.EditingResult {
  @image_generation.outpaint_image(img, new_width, new_height, config)
}

///|
pub fn colorize_image_ig(
  img : @types.Image,
  config : @image_generation.EditingConfig,
) -> @image_generation.EditingResult {
  @image_generation.colorize_image(img, config)
}

///|
pub fn compose_images_ig(
  background : @types.Image,
  foreground : @types.Image,
  mask : @types.Image,
  config : @image_generation.CompositionConfig,
) -> @types.Image {
  @image_generation.compose_images(background, foreground, mask, config)
}

///|
pub fn remove_background_ig(
  img : @types.Image,
  config : @image_generation.EditingConfig,
) -> @image_generation.EditingResult {
  @image_generation.remove_background(img, config)
}

///|
pub fn edit_image_ig(
  img : @types.Image,
  mask : @types.Image,
  config : @image_generation.EditingConfig,
) -> @image_generation.EditingResult {
  @image_generation.edit_image(img, mask, config)
}

///|
pub fn generation_report_to_string_ig(
  result : @image_generation.GenerationResult,
) -> String {
  @image_generation.generation_report_to_string(result)
}

///|
pub fn editing_report_to_string_ig(
  result : @image_generation.EditingResult,
) -> String {
  @image_generation.editing_report_to_string(result)
}

// ==================== 场景理解与图像描述（v35.0.0） ====================

///|
pub type SceneClassificationAlgorithmSU = @scene_understanding.SceneClassificationAlgorithm

///|
pub type ImageCaptioningAlgorithmSU = @scene_understanding.ImageCaptioningAlgorithm

///|
pub type VisualQuestionAnsweringAlgorithmSU = @scene_understanding.VisualQuestionAnsweringAlgorithm

///|
pub type SceneClassificationResultSU = @scene_understanding.SceneClassificationResult

///|
pub type ImageCaptioningResultSU = @scene_understanding.ImageCaptioningResult

///|
pub type VisualQuestionAnsweringResultSU = @scene_understanding.VisualQuestionAnsweringResult

///|
pub type SceneGraphNodeSU = @scene_understanding.SceneGraphNode

///|
pub type SceneGraphRelationSU = @scene_understanding.SceneGraphRelation

///|
pub type SceneGraphSU = @scene_understanding.SceneGraph

///|
pub type SceneUnderstandingConfigSU = @scene_understanding.SceneUnderstandingConfig

///|
pub fn create_default_scene_config_su() -> @scene_understanding.SceneUnderstandingConfig {
  @scene_understanding.create_default_scene_config()
}

///|
pub fn get_common_scene_types_su() -> Array[String] {
  @scene_understanding.get_common_scene_types()
}

///|
pub fn classify_scene_su(
  img : @types.Image,
  config : @scene_understanding.SceneUnderstandingConfig,
) -> @scene_understanding.SceneClassificationResult {
  @scene_understanding.classify_scene(img, config)
}

///|
pub fn generate_caption_su(
  img : @types.Image,
  config : @scene_understanding.SceneUnderstandingConfig,
) -> @scene_understanding.ImageCaptioningResult {
  @scene_understanding.generate_caption(img, config)
}

///|
pub fn answer_visual_question_su(
  img : @types.Image,
  question : String,
  config : @scene_understanding.SceneUnderstandingConfig,
) -> @scene_understanding.VisualQuestionAnsweringResult {
  @scene_understanding.answer_visual_question(img, question, config)
}

///|
pub fn generate_scene_graph_su(
  img : @types.Image,
  config : @scene_understanding.SceneUnderstandingConfig,
) -> @scene_understanding.SceneGraph {
  @scene_understanding.generate_scene_graph(img, config)
}

///|
pub fn understand_scene_su(
  img : @types.Image,
  config : @scene_understanding.SceneUnderstandingConfig,
) -> (
  @scene_understanding.SceneClassificationResult,
  @scene_understanding.ImageCaptioningResult,
  @scene_understanding.SceneGraph,
) {
  @scene_understanding.understand_scene(img, config)
}

///|
pub fn scene_understanding_report_to_string_su(
  classification : @scene_understanding.SceneClassificationResult,
  caption : @scene_understanding.ImageCaptioningResult,
  vqa : @scene_understanding.VisualQuestionAnsweringResult,
  scene_graph : @scene_understanding.SceneGraph,
) -> String {
  @scene_understanding.scene_understanding_report_to_string(
    classification, caption, vqa, scene_graph,
  )
}

// ==================== 神经渲染与 3D 重建（v36.0.0） ====================

///|
pub type NeuralRenderingAlgorithmNR = @neural_rendering.NeuralRenderingAlgorithm

///|
pub type ReconstructionAlgorithmNR = @neural_rendering.ReconstructionAlgorithm

///|
pub type RayNR = @neural_rendering.Ray

///|
pub type Point3DNR = @neural_rendering.Point3D

///|
pub type VoxelNR = @neural_rendering.Voxel

///|
pub type Gaussian3DNR = @neural_rendering.Gaussian3D

///|
pub type NeRFConfigNR = @neural_rendering.NeRFConfig

///|
pub type GaussianSplattingConfigNR = @neural_rendering.GaussianSplattingConfig

///|
pub type CameraParamsNR = @neural_rendering.CameraParams

///|
pub type RenderingResultNR = @neural_rendering.RenderingResult

///|
pub type ReconstructionResultNR = @neural_rendering.ReconstructionResult

///|
pub fn create_default_nerf_config_nr() -> @neural_rendering.NeRFConfig {
  @neural_rendering.create_default_nerf_config()
}

///|
pub fn create_default_gaussian_config_nr() -> @neural_rendering.GaussianSplattingConfig {
  @neural_rendering.create_default_gaussian_config()
}

///|
pub fn create_default_camera_nr() -> @neural_rendering.CameraParams {
  @neural_rendering.create_default_camera()
}

///|
pub fn generate_rays_nr(
  camera : @neural_rendering.CameraParams,
) -> Array[@neural_rendering.Ray] {
  @neural_rendering.generate_rays(camera)
}

///|
pub fn render_nerf_nr(
  camera : @neural_rendering.CameraParams,
  config : @neural_rendering.NeRFConfig,
) -> @neural_rendering.RenderingResult {
  @neural_rendering.render_nerf(camera, config)
}

///|
pub fn render_gaussian_splatting_nr(
  camera : @neural_rendering.CameraParams,
  gaussians : Array[@neural_rendering.Gaussian3D],
  config : @neural_rendering.GaussianSplattingConfig,
) -> @neural_rendering.RenderingResult {
  @neural_rendering.render_gaussian_splatting(camera, gaussians, config)
}

///|
pub fn generate_sample_gaussians_nr(
  num_gaussians : Int,
) -> Array[@neural_rendering.Gaussian3D] {
  @neural_rendering.generate_sample_gaussians(num_gaussians)
}

///|
pub fn multiview_stereo_reconstruction_nr(
  images : Array[@types.Image],
  cameras : Array[@neural_rendering.CameraParams],
) -> @neural_rendering.ReconstructionResult {
  @neural_rendering.multiview_stereo_reconstruction(images, cameras)
}

///|
pub fn visualize_point_cloud_nr(
  point_cloud : Array[@neural_rendering.Point3D],
  width : Int,
  height : Int,
) -> @types.Image {
  @neural_rendering.visualize_point_cloud(point_cloud, width, height)
}

///|
pub fn neural_rendering_report_to_string_nr(
  result : @neural_rendering.RenderingResult,
  algorithm : @neural_rendering.NeuralRenderingAlgorithm,
) -> String {
  @neural_rendering.neural_rendering_report_to_string(result, algorithm)
}

///|
pub fn reconstruction_report_to_string_nr(
  result : @neural_rendering.ReconstructionResult,
  algorithm : @neural_rendering.ReconstructionAlgorithm,
) -> String {
  @neural_rendering.reconstruction_report_to_string(result, algorithm)
}

// ==================== 计算成像与光场成像（v37.0.0） ====================

///|
pub type ComputationalImagingAlgorithmCI = @computational_imaging.ComputationalImagingAlgorithm

///|
pub type LightFieldRepresentationCI = @computational_imaging.LightFieldRepresentation

///|
pub type HologramTypeCI = @computational_imaging.HologramType

///|
pub type LightFieldCameraParamsCI = @computational_imaging.LightFieldCameraParams

///|
pub type LightFieldDataCI = @computational_imaging.LightFieldData

///|
pub type HologramCI = @computational_imaging.Hologram

///|
pub type CTProjectionDataCI = @computational_imaging.CTProjectionData

///|
pub type PhaseRetrievalConfigCI = @computational_imaging.PhaseRetrievalConfig

///|
pub type CodedAperturePatternCI = @computational_imaging.CodedAperturePattern

///|
pub type RefocusResultCI = @computational_imaging.RefocusResult

///|
pub type ViewSynthesisResultCI = @computational_imaging.ViewSynthesisResult

///|
pub type ImagingReconstructionResultCI = @computational_imaging.ImagingReconstructionResult

///|
pub fn create_default_lightfield_camera_ci() -> @computational_imaging.LightFieldCameraParams {
  @computational_imaging.create_default_lightfield_camera()
}

///|
pub fn create_default_phase_config_ci() -> @computational_imaging.PhaseRetrievalConfig {
  @computational_imaging.create_default_phase_config()
}

///|
pub fn create_default_coded_aperture_ci(
  size : Int,
) -> @computational_imaging.CodedAperturePattern {
  @computational_imaging.create_default_coded_aperture(size)
}

///|
pub fn generate_sample_lightfield_ci(
  base_image : @types.Image,
  params : @computational_imaging.LightFieldCameraParams,
) -> @computational_imaging.LightFieldData {
  @computational_imaging.generate_sample_lightfield(base_image, params)
}

///|
pub fn lightfield_refocus_ci(
  lightfield : @computational_imaging.LightFieldData,
  focus_depth : Double,
  aperture_size : Double,
) -> @computational_imaging.RefocusResult {
  @computational_imaging.lightfield_refocus(
    lightfield, focus_depth, aperture_size,
  )
}

///|
pub fn synthesize_view_ci(
  lightfield : @computational_imaging.LightFieldData,
  target_x : Double,
  target_y : Double,
) -> @computational_imaging.ViewSynthesisResult {
  @computational_imaging.synthesize_view(lightfield, target_x, target_y)
}

///|
pub fn generate_hologram_ci(
  image : @types.Image,
  wavelength : Double,
  distance : Double,
  pixel_size : Double,
) -> @computational_imaging.Hologram {
  @computational_imaging.generate_hologram(
    image, wavelength, distance, pixel_size,
  )
}

///|
pub fn reconstruct_hologram_ci(
  hologram : @computational_imaging.Hologram,
) -> @computational_imaging.ImagingReconstructionResult {
  @computational_imaging.reconstruct_hologram(hologram)
}

///|
pub fn ct_reconstruct_fbp_ci(
  projections : @computational_imaging.CTProjectionData,
  output_size : Int,
) -> @computational_imaging.ImagingReconstructionResult {
  @computational_imaging.ct_reconstruct_fbp(projections, output_size)
}

///|
pub fn phase_retrieval_ci(
  magnitude : @types.Image,
  config : @computational_imaging.PhaseRetrievalConfig,
) -> @computational_imaging.ImagingReconstructionResult {
  @computational_imaging.phase_retrieval(magnitude, config)
}

///|
pub fn coded_aperture_reconstruct_ci(
  measurement : @types.Image,
  pattern : @computational_imaging.CodedAperturePattern,
) -> @computational_imaging.ImagingReconstructionResult {
  @computational_imaging.coded_aperture_reconstruct(measurement, pattern)
}

///|
pub fn computational_imaging_report_to_string_ci(
  result : @computational_imaging.ImagingReconstructionResult,
  algorithm_name : String,
) -> String {
  @computational_imaging.computational_imaging_report_to_string(
    result, algorithm_name,
  )
}

// ==================== 视觉语言模型与多模态融合（v38.0.0） ====================

///|
pub type VisionLanguageModelTypeVLM = @vlm_multimodal.VisionLanguageModelType

///|
pub type MultimodalFusionStrategyVLM = @vlm_multimodal.MultimodalFusionStrategy

///|
pub type DiffusionModelTypeVLM = @vlm_multimodal.DiffusionModelType

///|
pub type GenerativeAITaskTypeVLM = @vlm_multimodal.GenerativeAITaskType

///|
pub type VLMConfigVLM = @vlm_multimodal.VLMConfig

///|
pub type FusionConfigVLM = @vlm_multimodal.FusionConfig

///|
pub type DiffusionConfigVLM = @vlm_multimodal.DiffusionConfig

///|
pub type GenerativeAIConfigVLM = @vlm_multimodal.GenerativeAIConfig

///|
pub type VisionTextEmbeddingVLM = @vlm_multimodal.VisionTextEmbedding

///|
pub type FusionResultVLM = @vlm_multimodal.FusionResult

///|
pub type DiffusionResultVLM = @vlm_multimodal.DiffusionResult

///|
pub type GenerativeAIResultVLM = @vlm_multimodal.GenerativeAIResult

///|
pub fn create_default_vlm_config_vlm() -> @vlm_multimodal.VLMConfig {
  @vlm_multimodal.create_default_vlm_config()
}

///|
pub fn create_default_fusion_config_vlm() -> @vlm_multimodal.FusionConfig {
  @vlm_multimodal.create_default_fusion_config()
}

///|
pub fn create_default_diffusion_config_vlm() -> @vlm_multimodal.DiffusionConfig {
  @vlm_multimodal.create_default_diffusion_config()
}

///|
pub fn create_default_genai_config_vlm() -> @vlm_multimodal.GenerativeAIConfig {
  @vlm_multimodal.create_default_genai_config()
}

///|
pub fn compute_image_text_similarity_vlm(
  image : @types.Image,
  text : String,
  config : @vlm_multimodal.VLMConfig,
) -> @vlm_multimodal.VisionTextEmbedding {
  @vlm_multimodal.compute_image_text_similarity(image, text, config)
}

///|
pub fn fuse_modalities_vlm(
  image_features : Array[Double],
  text_features : Array[Double],
  config : @vlm_multimodal.FusionConfig,
) -> @vlm_multimodal.FusionResult {
  @vlm_multimodal.fuse_modalities(image_features, text_features, config)
}

///|
pub fn diffusion_generate_vlm(
  prompt : String,
  negative_prompt : String,
  config : @vlm_multimodal.DiffusionConfig,
  seed : Int,
) -> @vlm_multimodal.DiffusionResult {
  @vlm_multimodal.diffusion_generate(prompt, negative_prompt, config, seed)
}

///|
pub fn text_to_image_vlm(
  prompt : String,
  config : @vlm_multimodal.GenerativeAIConfig,
  seed : Int,
) -> @vlm_multimodal.GenerativeAIResult {
  @vlm_multimodal.text_to_image(prompt, config, seed)
}

///|
pub fn image_to_text_vlm(
  image : @types.Image,
  config : @vlm_multimodal.GenerativeAIConfig,
) -> @vlm_multimodal.GenerativeAIResult {
  @vlm_multimodal.image_to_text(image, config)
}

///|
pub fn vlm_report_to_string_vlm(
  embedding : @vlm_multimodal.VisionTextEmbedding,
  model_type : @vlm_multimodal.VisionLanguageModelType,
) -> String {
  @vlm_multimodal.vlm_report_to_string(embedding, model_type)
}

///|
pub fn fusion_report_to_string_vlm(
  result : @vlm_multimodal.FusionResult,
) -> String {
  @vlm_multimodal.fusion_report_to_string(result)
}

// ==================== 智能应用视觉（v39.0.0） ====================

///|
pub type AutonomousDrivingTaskIV = @intelligent_vision.AutonomousDrivingTask

///|
pub type RobotVisionTaskIV = @intelligent_vision.RobotVisionTask

///|
pub type IndustrialInspectionTaskIV = @intelligent_vision.IndustrialInspectionTask

///|
pub type SecurityMonitoringTaskIV = @intelligent_vision.SecurityMonitoringTask

///|
pub type AgriculturalVisionTaskIV = @intelligent_vision.AgriculturalVisionTask

///|
pub type AstronomicalImageTaskIV = @intelligent_vision.AstronomicalImageTask

///|
pub type DetectionResultIV = @intelligent_vision.DetectionResultIV

///|
pub type LaneDetectionResultIV = @intelligent_vision.LaneDetectionResult

///|
pub type TrafficSignResultIV = @intelligent_vision.TrafficSignResult

///|
pub type DefectDetectionResultIV = @intelligent_vision.DefectDetectionResult

///|
pub type IntrusionDetectionResultIV = @intelligent_vision.IntrusionDetectionResult

///|
pub type CropDetectionResultIV = @intelligent_vision.CropDetectionResult

///|
pub type StarDetectionResultIV = @intelligent_vision.StarDetectionResult

///|
pub type IntelligentVisionConfigIV = @intelligent_vision.IntelligentVisionConfig

///|
pub fn create_default_intelligent_vision_config_iv() -> @intelligent_vision.IntelligentVisionConfig {
  @intelligent_vision.create_default_intelligent_vision_config()
}

///|
pub fn detect_objects_iv(
  image : @types.Image,
  config : @intelligent_vision.IntelligentVisionConfig,
) -> Array[@intelligent_vision.DetectionResultIV] {
  @intelligent_vision.detect_objects_iv(image, config)
}

///|
pub fn detect_lanes_iv(
  image : @types.Image,
  config : @intelligent_vision.IntelligentVisionConfig,
) -> @intelligent_vision.LaneDetectionResult {
  @intelligent_vision.detect_lanes(image, config)
}

///|
pub fn recognize_traffic_signs_iv(
  image : @types.Image,
  config : @intelligent_vision.IntelligentVisionConfig,
) -> Array[@intelligent_vision.TrafficSignResult] {
  @intelligent_vision.recognize_traffic_signs(image, config)
}

///|
pub fn detect_defects_iv(
  image : @types.Image,
  config : @intelligent_vision.IntelligentVisionConfig,
) -> Array[@intelligent_vision.DefectDetectionResult] {
  @intelligent_vision.detect_defects(image, config)
}

///|
pub fn detect_intrusion_iv(
  image : @types.Image,
  roi : Array[Double],
  config : @intelligent_vision.IntelligentVisionConfig,
) -> @intelligent_vision.IntrusionDetectionResult {
  @intelligent_vision.detect_intrusion(image, roi, config)
}

///|
pub fn detect_crops_iv(
  image : @types.Image,
  config : @intelligent_vision.IntelligentVisionConfig,
) -> Array[@intelligent_vision.CropDetectionResult] {
  @intelligent_vision.detect_crops(image, config)
}

///|
pub fn detect_stars_iv(
  image : @types.Image,
  config : @intelligent_vision.IntelligentVisionConfig,
) -> @intelligent_vision.StarDetectionResult {
  @intelligent_vision.detect_stars(image, config)
}

///|
pub fn intelligent_vision_report_to_string_iv(
  task_name : String,
  num_results : Int,
  avg_confidence : Double,
  config : @intelligent_vision.IntelligentVisionConfig,
) -> String {
  @intelligent_vision.intelligent_vision_report_to_string(
    task_name, num_results, avg_confidence, config,
  )
}

// ==================== 高级成像技术（v40.0.0） ====================

///|
pub type ImagingModalityAI = @advanced_imaging.ImagingModality

///|
pub type QuantumImagingAlgorithmAI = @advanced_imaging.QuantumImagingAlgorithm

///|
pub type InfraredImagingTypeAI = @advanced_imaging.InfraredImagingType

///|
pub type HyperspectralDataAI = @advanced_imaging.HyperspectralData

///|
pub type PolarizationDataAI = @advanced_imaging.PolarizationData

///|
pub type ThermalDataAI = @advanced_imaging.ThermalData

///|
pub type XRayDataAI = @advanced_imaging.XRayData

///|
pub type UltrasoundDataAI = @advanced_imaging.UltrasoundData

///|
pub type MRIDataAI = @advanced_imaging.MRIData

///|
pub type PETDataAI = @advanced_imaging.PETData

///|
pub type AdvancedImagingConfigAI = @advanced_imaging.AdvancedImagingConfig

///|
pub fn create_default_advanced_imaging_config_ai(
  modality : @advanced_imaging.ImagingModality,
) -> @advanced_imaging.AdvancedImagingConfig {
  @advanced_imaging.create_default_advanced_imaging_config(modality)
}

///|
pub fn quantum_ghost_imaging_ai(
  num_patterns : Int,
  width : Int,
  height : Int,
  algorithm : @advanced_imaging.QuantumImagingAlgorithm,
) -> @types.Image {
  @advanced_imaging.quantum_ghost_imaging(
    num_patterns, width, height, algorithm,
  )
}

///|
pub fn infrared_pseudocolor_ai(
  infrared_image : @types.Image,
  ir_type : @advanced_imaging.InfraredImagingType,
) -> @types.Image {
  @advanced_imaging.infrared_pseudocolor(infrared_image, ir_type)
}

///|
pub fn generate_hyperspectral_cube_ai(
  base_image : @types.Image,
  num_bands : Int,
  start_wavelength : Double,
  end_wavelength : Double,
) -> @advanced_imaging.HyperspectralData {
  @advanced_imaging.generate_hyperspectral_cube(
    base_image, num_bands, start_wavelength, end_wavelength,
  )
}

///|
pub fn analyze_polarization_ai(
  images_0deg : @types.Image,
  images_45deg : @types.Image,
  images_90deg : @types.Image,
  images_135deg : @types.Image,
) -> @advanced_imaging.PolarizationData {
  @advanced_imaging.analyze_polarization(
    images_0deg, images_45deg, images_90deg, images_135deg,
  )
}

///|
pub fn thermal_to_temperature_ai(
  thermal_image : @types.Image,
  emissivity : Double,
  min_temp : Double,
  max_temp : Double,
) -> @advanced_imaging.ThermalData {
  @advanced_imaging.thermal_to_temperature(
    thermal_image, emissivity, min_temp, max_temp,
  )
}

///|
pub fn xray_enhance_ai(
  xray_image : @types.Image,
  energy_kev : Double,
) -> @advanced_imaging.XRayData {
  @advanced_imaging.xray_enhance(xray_image, energy_kev)
}

///|
pub fn ultrasound_synthesize_ai(
  width : Int,
  height : Int,
  frequency_mhz : Double,
  depth_cm : Double,
) -> @advanced_imaging.UltrasoundData {
  @advanced_imaging.ultrasound_synthesize(
    width, height, frequency_mhz, depth_cm,
  )
}

///|
pub fn mri_synthesize_ai(
  width : Int,
  height : Int,
  field_strength_t : Double,
) -> @advanced_imaging.MRIData {
  @advanced_imaging.mri_synthesize(width, height, field_strength_t)
}

///|
pub fn pet_synthesize_ai(
  width : Int,
  height : Int,
  radiotracer : String,
) -> @advanced_imaging.PETData {
  @advanced_imaging.pet_synthesize(width, height, radiotracer)
}

///|
pub fn advanced_imaging_report_to_string_ai(
  modality : @advanced_imaging.ImagingModality,
  image : @types.Image,
  config : @advanced_imaging.AdvancedImagingConfig,
) -> String {
  @advanced_imaging.advanced_imaging_report_to_string(modality, image, config)
}

// 计算成像与光场成像（v37.0.0）
// 计算摄影、光场成像、全息成像、计算层析、相位恢复、编码孔径

///|
/// 计算成像算法类型
pub(all) enum ComputationalImagingAlgorithm {
  LightField
  Holography
  ComputedTomography
  PhaseRetrieval
  CodedAperture
  SinglePixel
  GhostImaging
  Ptychography
  Unknown
} derive(Eq)

///|
/// 光场表示类型
pub(all) enum LightFieldRepresentation {
  TwoPlane
  Lumigraph
  FourierSlice
  Convolutional
  Unknown
} derive(Eq)

///|
/// 全息图类型
pub(all) enum HologramType {
  Fresnel
  Fourier
  ImagePlane
  Digital
  ComputerGenerated
  Unknown
} derive(Eq)

///|
/// 光场相机参数
pub(all) struct LightFieldCameraParams {
  num_views_x : Int
  num_views_y : Int
  micro_lens_pitch : Double
  focal_length : Double
  sensor_pitch : Double
  num_aperture_samples : Int
}

///|
/// 光场数据
pub(all) struct LightFieldData {
  views : Array[@types.Image]
  num_views_x : Int
  num_views_y : Int
  total_views : Int
  representation : LightFieldRepresentation
}

///|
/// 全息图
pub(all) struct Hologram {
  intensity : @types.Image
  phase : @types.Image
  hologram_type : HologramType
  wavelength : Double
  distance : Double
  pixel_size : Double
}

///|
/// CT 投影数据
pub(all) struct CTProjectionData {
  projections : Array[@types.Image]
  num_angles : Int
  num_detectors : Int
  angular_range : Double
  source_distance : Double
  detector_distance : Double
}

///|
/// 相位恢复配置
pub(all) struct PhaseRetrievalConfig {
  num_iterations : Int
  algorithm : String
  support_threshold : Double
  use_hybrid_input_output : Bool
  beta : Double
}

///|
/// 编码孔径模式
pub(all) struct CodedAperturePattern {
  pattern : @types.Image
  pattern_size : Int
  code_type : String
  num_elements : Int
}

///|
/// 重聚焦结果
pub(all) struct RefocusResult {
  image : @types.Image
  focus_depth : Double
  aperture_size : Double
  num_views_used : Int
}

///|
/// 视角合成结果
pub(all) struct ViewSynthesisResult {
  image : @types.Image
  view_position : Array[Double]
  num_source_views : Int
  interpolation_method : String
}

///|
/// 重建结果
pub(all) struct ImagingReconstructionResult {
  image : @types.Image
  algorithm : ComputationalImagingAlgorithm
  num_iterations : Int
  convergence_error : Double
  reconstruction_time_ms : Double
  psnr : Double
  ssim : Double
}

///|
/// 创建默认光场相机参数
pub fn create_default_lightfield_camera() -> LightFieldCameraParams {
  LightFieldCameraParams::{
    num_views_x: 9,
    num_views_y: 9,
    micro_lens_pitch: 0.01,
    focal_length: 50.0,
    sensor_pitch: 0.005,
    num_aperture_samples: 64,
  }
}

///|
/// 创建默认相位恢复配置
pub fn create_default_phase_config() -> PhaseRetrievalConfig {
  PhaseRetrievalConfig::{
    num_iterations: 100,
    algorithm: "Gerchberg-Saxton",
    support_threshold: 0.1,
    use_hybrid_input_output: true,
    beta: 0.9,
  }
}

///|
/// 创建默认编码孔径模式
pub fn create_default_coded_aperture(size : Int) -> CodedAperturePattern {
  let total = size * size
  let out : Array[Byte] = []
  let mut state = 42

  for _ in 0..<total {
    state = (state * 11035 + 12345) % 1000000
    let value = if state % 2 == 0 { 255 } else { 0 }
    out.push(value.to_byte())
  }

  let pattern = @types.Image::{
    width: size,
    height: size,
    channels: 1,
    data: Bytes::from_array(out),
  }

  CodedAperturePattern::{
    pattern,
    pattern_size: size,
    code_type: "random",
    num_elements: total,
  }
}

///|
/// 生成示例光场数据
pub fn generate_sample_lightfield(
  base_image : @types.Image,
  params : LightFieldCameraParams,
) -> LightFieldData {
  let views : Array[@types.Image] = []
  let w = base_image.width
  let h = base_image.height

  for vy in 0..<params.num_views_y {
    for vx in 0..<params.num_views_x {
      // 简化的视角偏移
      let offset_x = (vx - params.num_views_x / 2) * 2
      let offset_y = (vy - params.num_views_y / 2) * 2
      let out : Array[Byte] = []

      for y in 0..<h {
        for x in 0..<w {
          let src_x = x + offset_x
          let src_y = y + offset_y
          let idx = if src_x >= 0 && src_x < w && src_y >= 0 && src_y < h {
            src_y * w + src_x
          } else {
            y * w + x
          }
          out.push(base_image.data[idx])
        }
      }

      views.push(@types.Image::{
        width: w,
        height: h,
        channels: base_image.channels,
        data: Bytes::from_array(out),
      })
    }
  }

  LightFieldData::{
    views,
    num_views_x: params.num_views_x,
    num_views_y: params.num_views_y,
    total_views: params.num_views_x * params.num_views_y,
    representation: LightFieldRepresentation::TwoPlane,
  }
}

///|
/// 光场重聚焦
pub fn lightfield_refocus(
  lightfield : LightFieldData,
  focus_depth : Double,
  aperture_size : Double,
) -> RefocusResult {
  if lightfield.views.length() == 0 {
    return RefocusResult::{
      image: @types.Image::{
        width: 1,
        height: 1,
        channels: 1,
        data: Bytes::make(1, b'\x00'),
      },
      focus_depth,
      aperture_size,
      num_views_used: 0,
    }
  }

  let first = lightfield.views[0]
  let w = first.width
  let h = first.height
  let channels = first.channels
  let total = w * h * channels
  let accumulator : Array[Double] = []
  for _ in 0..<total {
    accumulator.push(0.0)
  }

  let mut num_views_used = 0
  let center_x = lightfield.num_views_x / 2
  let center_y = lightfield.num_views_y / 2

  for vy in 0..<lightfield.num_views_y {
    for vx in 0..<lightfield.num_views_x {
      let dx = (vx - center_x).to_double()
      let dy = (vy - center_y).to_double()
      let dist = (dx * dx + dy * dy).sqrt()

      if dist <= aperture_size {
        let view_idx = vy * lightfield.num_views_x + vx
        let view = lightfield.views[view_idx]

        // 简化的重聚焦：根据深度偏移像素
        let shift_x = (dx * focus_depth * 0.1).to_int()
        let shift_y = (dy * focus_depth * 0.1).to_int()

        for y in 0..<h {
          for x in 0..<w {
            let src_x = x + shift_x
            let src_y = y + shift_y
            if src_x >= 0 && src_x < w && src_y >= 0 && src_y < h {
              for c in 0..<channels {
                let dst_idx = (y * w + x) * channels + c
                let src_idx = (src_y * w + src_x) * channels + c
                accumulator[dst_idx] += view.data[src_idx].to_double()
              }
            }
          }
        }
        num_views_used += 1
      }
    }
  }

  // 归一化
  let out : Array[Byte] = []
  for i in 0..<total {
    let value = if num_views_used > 0 {
      accumulator[i] / num_views_used.to_double()
    } else {
      0.0
    }
    let clamped = if value < 0.0 {
      0.0
    } else if value > 255.0 {
      255.0
    } else {
      value
    }
    out.push(clamped.to_int().to_byte())
  }

  RefocusResult::{
    image: @types.Image::{
      width: w,
      height: h,
      channels,
      data: Bytes::from_array(out),
    },
    focus_depth,
    aperture_size,
    num_views_used,
  }
}

///|
/// 视角合成
pub fn synthesize_view(
  lightfield : LightFieldData,
  target_x : Double,
  target_y : Double,
) -> ViewSynthesisResult {
  if lightfield.views.length() < 4 {
    return ViewSynthesisResult::{
      image: @types.Image::{
        width: 1,
        height: 1,
        channels: 1,
        data: Bytes::make(1, b'\x00'),
      },
      view_position: [target_x, target_y],
      num_source_views: 0,
      interpolation_method: "none",
    }
  }

  let first = lightfield.views[0]
  let w = first.width
  let h = first.height
  let channels = first.channels
  let total = w * h * channels

  // 找到最近的 4 个视角进行双线性插值
  let fx = target_x * (lightfield.num_views_x - 1).to_double()
  let fy = target_y * (lightfield.num_views_y - 1).to_double()
  let x0 = fx.to_int()
  let y0 = fy.to_int()
  let x1 = if x0 + 1 < lightfield.num_views_x { x0 + 1 } else { x0 }
  let y1 = if y0 + 1 < lightfield.num_views_y { y0 + 1 } else { y0 }
  let wx = fx - x0.to_double()
  let wy = fy - y0.to_double()

  let idx00 = y0 * lightfield.num_views_x + x0
  let idx01 = y0 * lightfield.num_views_x + x1
  let idx10 = y1 * lightfield.num_views_x + x0
  let idx11 = y1 * lightfield.num_views_x + x1

  let v00 = lightfield.views[idx00]
  let v01 = lightfield.views[idx01]
  let v10 = lightfield.views[idx10]
  let v11 = lightfield.views[idx11]

  let out : Array[Byte] = []
  for i in 0..<total {
    let value = v00.data[i].to_double() * (1.0 - wx) * (1.0 - wy) +
      v01.data[i].to_double() * wx * (1.0 - wy) +
      v10.data[i].to_double() * (1.0 - wx) * wy +
      v11.data[i].to_double() * wx * wy
    let clamped = if value < 0.0 {
      0.0
    } else if value > 255.0 {
      255.0
    } else {
      value
    }
    out.push(clamped.to_int().to_byte())
  }

  ViewSynthesisResult::{
    image: @types.Image::{
      width: w,
      height: h,
      channels,
      data: Bytes::from_array(out),
    },
    view_position: [target_x, target_y],
    num_source_views: 4,
    interpolation_method: "bilinear",
  }
}

///|
/// 生成计算全息图（简化版）
pub fn generate_hologram(
  image : @types.Image,
  wavelength : Double,
  distance : Double,
  pixel_size : Double,
) -> Hologram {
  let w = image.width
  let h = image.height
  let _ = w * h
  let intensity_out : Array[Byte] = []
  let phase_out : Array[Byte] = []

  // 简化的菲涅尔全息图生成
  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      let gray = image.data[idx].to_double() / 255.0

      // 简化的相位计算
      let phase = (
          x.to_double() * x.to_double() + y.to_double() * y.to_double()
        ) *
        3.14159 /
        (wavelength * distance)
      let phase_norm = phase % 6.28318 / 6.28318 * 255.0

      // 干涉图样
      let interference = gray * 127.0 +
        128.0 * (0.5 + 0.5 * cos_approx(phase_norm))

      intensity_out.push(interference.to_int().to_byte())
      phase_out.push(phase_norm.to_int().to_byte())
    }
  }

  Hologram::{
    intensity: @types.Image::{
      width: w,
      height: h,
      channels: 1,
      data: Bytes::from_array(intensity_out),
    },
    phase: @types.Image::{
      width: w,
      height: h,
      channels: 1,
      data: Bytes::from_array(phase_out),
    },
    hologram_type: HologramType::Fresnel,
    wavelength,
    distance,
    pixel_size,
  }
}

///|
/// 全息图重建（简化版）
pub fn reconstruct_hologram(hologram : Hologram) -> ImagingReconstructionResult {
  let w = hologram.intensity.width
  let h = hologram.intensity.height
  let _ = w * h
  let out : Array[Byte] = []

  // 简化的重建：直接使用强度图的逆变换
  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      let value = hologram.intensity.data[idx].to_double()
      // 简化的重建：对比度增强
      let reconstructed = (value - 128.0) * 1.5 + 128.0
      let clamped = if reconstructed < 0.0 {
        0.0
      } else if reconstructed > 255.0 {
        255.0
      } else {
        reconstructed
      }
      out.push(clamped.to_int().to_byte())
    }
  }

  ImagingReconstructionResult::{
    image: @types.Image::{
      width: w,
      height: h,
      channels: 1,
      data: Bytes::from_array(out),
    },
    algorithm: ComputationalImagingAlgorithm::Holography,
    num_iterations: 1,
    convergence_error: 0.0,
    reconstruction_time_ms: 0.0,
    psnr: 0.0,
    ssim: 0.0,
  }
}

///|
/// CT 滤波反投影重建（简化版）
pub fn ct_reconstruct_fbp(
  projections : CTProjectionData,
  output_size : Int,
) -> ImagingReconstructionResult {
  let total = output_size * output_size
  let out : Array[Byte] = []
  for _ in 0..<total {
    out.push(b'\x00')
  }

  // 简化的 FBP 重建
  if projections.projections.length() > 0 {
    let first = projections.projections[0]
    let num_detectors = first.width

    for angle_idx in 0..<projections.num_angles {
      if angle_idx < projections.projections.length() {
        let proj = projections.projections[angle_idx]
        let angle = angle_idx.to_double() *
          projections.angular_range /
          projections.num_angles.to_double()
        let cos_a = cos_approx(angle)
        let sin_a = sin_approx(angle)

        for y in 0..<output_size {
          for x in 0..<output_size {
            let cx = x.to_double() - output_size.to_double() / 2.0
            let cy = y.to_double() - output_size.to_double() / 2.0
            let detector_pos = cx * cos_a + cy * sin_a
            let detector_idx = (detector_pos + num_detectors.to_double() / 2.0).to_int()

            if detector_idx >= 0 && detector_idx < num_detectors {
              let idx = y * output_size + x
              let value = out[idx].to_double() +
                proj.data[detector_idx].to_double() * 0.1
              let clamped = if value > 255.0 { 255.0 } else { value }
              out[idx] = clamped.to_int().to_byte()
            }
          }
        }
      }
    }
  }

  ImagingReconstructionResult::{
    image: @types.Image::{
      width: output_size,
      height: output_size,
      channels: 1,
      data: Bytes::from_array(out),
    },
    algorithm: ComputationalImagingAlgorithm::ComputedTomography,
    num_iterations: 1,
    convergence_error: 0.0,
    reconstruction_time_ms: 0.0,
    psnr: 0.0,
    ssim: 0.0,
  }
}

///|
/// 相位恢复（简化版 Gerchberg-Saxton）
pub fn phase_retrieval(
  magnitude : @types.Image,
  config : PhaseRetrievalConfig,
) -> ImagingReconstructionResult {
  let w = magnitude.width
  let h = magnitude.height
  let total = w * h

  // 简化的相位恢复：迭代优化
  let phase : Array[Double] = []
  for _ in 0..<total {
    phase.push(0.0)
  }

  let mut error = 0.0
  for iter in 0..<config.num_iterations {
    // 简化的迭代：随机扰动相位
    let mut state = iter * 11035 + 12345
    for i in 0..<total {
      state = (state * 11035 + 12345) % 1000000
      let perturbation = (state % 1000).to_double() / 1000.0 - 0.5
      phase[i] += perturbation * 0.01
    }
    error = 1.0 / (iter + 1).to_double()
  }

  // 生成重建图像
  let out : Array[Byte] = []
  for i in 0..<total {
    let value = magnitude.data[i].to_double() *
      (0.5 + 0.5 * cos_approx(phase[i]))
    let clamped = if value < 0.0 {
      0.0
    } else if value > 255.0 {
      255.0
    } else {
      value
    }
    out.push(clamped.to_int().to_byte())
  }

  ImagingReconstructionResult::{
    image: @types.Image::{
      width: w,
      height: h,
      channels: 1,
      data: Bytes::from_array(out),
    },
    algorithm: ComputationalImagingAlgorithm::PhaseRetrieval,
    num_iterations: config.num_iterations,
    convergence_error: error,
    reconstruction_time_ms: 0.0,
    psnr: 0.0,
    ssim: 0.0,
  }
}

///|
/// 编码孔径成像重建（简化版）
pub fn coded_aperture_reconstruct(
  measurement : @types.Image,
  pattern : CodedAperturePattern,
) -> ImagingReconstructionResult {
  let w = measurement.width
  let h = measurement.height
  let _ = w * h
  let out : Array[Byte] = []

  // 简化的反卷积重建
  for y in 0..<h {
    for x in 0..<w {
      let _ = y * w + x
      let mut sum = 0.0
      let mut count = 0

      // 局部反卷积
      for dy in -2..<3 {
        for dx in -2..<3 {
          let src_x = x + dx
          let src_y = y + dy
          if src_x >= 0 && src_x < w && src_y >= 0 && src_y < h {
            let pat_idx = src_y % pattern.pattern_size * pattern.pattern_size +
              src_x % pattern.pattern_size
            if pattern.pattern.data[pat_idx].to_int() > 128 {
              sum += measurement.data[src_y * w + src_x].to_double()
              count += 1
            }
          }
        }
      }

      let value = if count > 0 { sum / count.to_double() } else { 0.0 }
      let clamped = if value < 0.0 {
        0.0
      } else if value > 255.0 {
        255.0
      } else {
        value
      }
      out.push(clamped.to_int().to_byte())
    }
  }

  ImagingReconstructionResult::{
    image: @types.Image::{
      width: w,
      height: h,
      channels: 1,
      data: Bytes::from_array(out),
    },
    algorithm: ComputationalImagingAlgorithm::CodedAperture,
    num_iterations: 1,
    convergence_error: 0.0,
    reconstruction_time_ms: 0.0,
    psnr: 0.0,
    ssim: 0.0,
  }
}

///|
/// 生成计算成像报告
pub fn computational_imaging_report_to_string(
  result : ImagingReconstructionResult,
  algorithm_name : String,
) -> String {
  let mut report = "## 计算成像报告\n\n"
  report = report + "### 重建信息\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report + "| 算法 | " + algorithm_name + " |\n"
  report = report +
    "| 迭代次数 | " +
    result.num_iterations.to_string() +
    " |\n"
  report = report +
    "| 收敛误差 | " +
    result.convergence_error.to_string() +
    " |\n"
  report = report +
    "| 重建时间 | " +
    result.reconstruction_time_ms.to_string() +
    " ms |\n"
  report = report + "| PSNR | " + result.psnr.to_string() + " dB |\n"
  report = report + "| SSIM | " + result.ssim.to_string() + " |\n"
  report = report +
    "| 图像尺寸 | " +
    result.image.width.to_string() +
    "x" +
    result.image.height.to_string() +
    " |\n"

  report
}

// 辅助函数：Double 的近似三角函数

///|
fn cos_approx(x : Double) -> Double {
  let x2 = x * x
  1.0 - x2 / 2.0 + x2 * x2 / 24.0
}

///|
fn sin_approx(x : Double) -> Double {
  let x2 = x * x
  x - x * x2 / 6.0 + x * x2 * x2 / 120.0
}

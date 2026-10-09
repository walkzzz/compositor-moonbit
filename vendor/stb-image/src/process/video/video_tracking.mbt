// 视频目标跟踪与动作识别（v14.0.0）
// 光流跟踪、目标跟踪、动作识别、视频稳定、关键帧提取、视频摘要

///|
/// 光流向量
pub(all) struct OpticalFlowVector {
  x : Double
  y : Double
  magnitude : Double
  angle : Double
}

///|
/// 光流场
pub(all) struct OpticalFlowField {
  width : Int
  height : Int
  vectors : Array[OpticalFlowVector]
  average_magnitude : Double
  max_magnitude : Double
  motion_direction : Double
}

///|
/// 跟踪目标
pub(all) struct TrackedObject {
  id : Int
  label : String
  x : Int
  y : Int
  width : Int
  height : Int
  center_x : Double
  center_y : Double
  velocity_x : Double
  velocity_y : Double
  confidence : Double
  age : Int
  visible_count : Int
  invisible_count : Int
  color_histogram : Array[Double]
  trajectory : Array[(Int, Int)]
}

///|
/// 跟踪结果
pub(all) struct TrackingResult {
  frame_index : Int
  objects : Array[TrackedObject]
  tracking_time_ms : Double
  num_objects : Int
}

///|
/// 动作类型
pub(all) enum ActionType {
  Walking
  Running
  Jumping
  Sitting
  Standing
  LyingDown
  Waving
  Clapping
  Pointing
  Lifting
  Throwing
  Catching
  Unknown
} derive(Eq)

///|
/// 动作识别结果
pub(all) struct ActionRecognitionResult {
  action_type : ActionType
  confidence : Double
  start_frame : Int
  end_frame : Int
  duration_frames : Int
  motion_energy : Double
  direction : Double
  key_points : Array[(Int, Int)]
}

///|
/// 视频稳定配置
pub(all) struct VideoStabilizationConfig {
  smoothing_radius : Int
  max_correction : Double
  crop_ratio : Double
  enable_rotation_correction : Bool
  enable_scale_correction : Bool
}

///|
/// 关键帧类型
pub(all) enum KeyframeType {
  SceneChange
  MotionPeak
  ContentChange
  UniformSampling
  UserSelected
} derive(Eq)

///|
/// 关键帧
pub(all) struct Keyframe {
  frame_index : Int
  timestamp_ms : Double
  keyframe_type : KeyframeType
  score : Double
  thumbnail : @types.Image
}

///|
/// 视频摘要
pub(all) struct VideoSummary {
  total_frames : Int
  duration_ms : Double
  keyframes : Array[Keyframe]
  num_keyframes : Int
  average_motion : Double
  motion_peaks : Array[Int]
  scene_changes : Array[Int]
  summary_text : String
}

///|
/// 创建默认视频稳定配置
pub fn create_default_stabilization_config() -> VideoStabilizationConfig {
  VideoStabilizationConfig::{
    smoothing_radius: 5,
    max_correction: 20.0,
    crop_ratio: 0.1,
    enable_rotation_correction: true,
    enable_scale_correction: false,
  }
}

///|
/// 计算帧差（简单运动检测，返回运动能量值）
pub fn compute_frame_difference(
  frame1 : @types.Image,
  frame2 : @types.Image,
  threshold? : Double = 30.0,
) -> Double {
  let w = frame1.width
  let h = frame1.height
  let mut motion_pixels = 0
  let total = w * h

  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      let p1 = frame1.data[idx].to_int()
      let p2 = frame2.data[idx].to_int()
      let diff = (p1 - p2).abs().to_double()
      if diff > threshold {
        motion_pixels += 1
      }
    }
  }

  if total > 0 {
    motion_pixels.to_double() / total.to_double()
  } else {
    0.0
  }
}

///|
/// 计算简单光流（块匹配法）
pub fn compute_optical_flow(
  frame1 : @types.Image,
  frame2 : @types.Image,
  block_size? : Int = 8,
  search_range? : Int = 4,
) -> OpticalFlowField {
  let w = frame1.width
  let h = frame1.height
  let vectors : Array[OpticalFlowVector] = []
  let mut total_magnitude = 0.0
  let mut max_mag = 0.0
  let mut sum_dx = 0.0
  let mut sum_dy = 0.0
  let mut count = 0

  for by in 0..<(h / block_size) {
    for bx in 0..<(w / block_size) {
      let mut best_dx = 0
      let mut best_dy = 0
      let mut best_sad = 1000000.0

      // 搜索最佳匹配
      for dy in -search_range..<(search_range + 1) {
        for dx in -search_range..<(search_range + 1) {
          let mut sad = 0.0
          let mut valid = true

          for py in 0..<block_size {
            for px in 0..<block_size {
              let x1 = bx * block_size + px
              let y1 = by * block_size + py
              let x2 = x1 + dx
              let y2 = y1 + dy

              if x1 >= 0 &&
                x1 < w &&
                y1 >= 0 &&
                y1 < h &&
                x2 >= 0 &&
                x2 < w &&
                y2 >= 0 &&
                y2 < h {
                sad += (frame1.data[y1 * w + x1].to_int() -
                  frame2.data[y2 * w + x2].to_int())
                  .abs()
                  .to_double()
              } else {
                valid = false
              }
            }
          }

          if valid && sad < best_sad {
            best_sad = sad
            best_dx = dx
            best_dy = dy
          }
        }
      }

      let magnitude = (best_dx.to_double() * best_dx.to_double() +
      best_dy.to_double() * best_dy.to_double()).sqrt()
      let angle = if best_dx != 0 {
        best_dy.to_double() / best_dx.to_double() * 57.2958
      } else {
        0.0
      }

      vectors.push(OpticalFlowVector::{
        x: best_dx.to_double(),
        y: best_dy.to_double(),
        magnitude,
        angle,
      })

      total_magnitude += magnitude
      if magnitude > max_mag {
        max_mag = magnitude
      }
      sum_dx += best_dx.to_double()
      sum_dy += best_dy.to_double()
      count += 1
    }
  }

  let avg_mag = if count > 0 {
    total_magnitude / count.to_double()
  } else {
    0.0
  }
  let motion_dir = if sum_dx != 0 { sum_dy / sum_dx * 57.2958 } else { 0.0 }

  OpticalFlowField::{
    width: w / block_size,
    height: h / block_size,
    vectors,
    average_magnitude: avg_mag,
    max_magnitude: max_mag,
    motion_direction: motion_dir,
  }
}

///|
/// 目标跟踪初始化
pub fn initialize_tracking(
  first_frame : @types.Image,
  roi_x : Int,
  roi_y : Int,
  roi_width : Int,
  roi_height : Int,
  label : String,
) -> TrackedObject {
  // 计算颜色直方图
  let histogram : Array[Double] = []
  for _ in 0..<16 {
    histogram.push(0.0)
  }

  let w = first_frame.width
  let h = first_frame.height
  let mut total_pixels = 0

  for y in roi_y..<(roi_y + roi_height) {
    for x in roi_x..<(roi_x + roi_width) {
      if x >= 0 && x < w && y >= 0 && y < h {
        let pixel = first_frame.data[y * w + x].to_int()
        let bin = pixel / 16
        if bin < 16 {
          histogram[bin] = histogram[bin] + 1.0
        }
        total_pixels += 1
      }
    }
  }

  // 归一化直方图
  if total_pixels > 0 {
    for i in 0..<16 {
      histogram[i] = histogram[i] / total_pixels.to_double()
    }
  }

  let trajectory : Array[(Int, Int)] = [
    (roi_x + roi_width / 2, roi_y + roi_height / 2),
  ]

  TrackedObject::{
    id: 0,
    label,
    x: roi_x,
    y: roi_y,
    width: roi_width,
    height: roi_height,
    center_x: (roi_x + roi_width / 2).to_double(),
    center_y: (roi_y + roi_height / 2).to_double(),
    velocity_x: 0.0,
    velocity_y: 0.0,
    confidence: 1.0,
    age: 0,
    visible_count: 1,
    invisible_count: 0,
    color_histogram: histogram,
    trajectory,
  }
}

///|
/// 目标跟踪更新（MeanShift 简化版）
pub fn update_tracking(
  obj : TrackedObject,
  frame : @types.Image,
) -> TrackedObject {
  let w = frame.width
  let h = frame.height
  let search_radius = 20

  let mut best_x = obj.x
  let mut best_y = obj.y
  let mut best_score = -1.0

  // 在目标周围搜索最佳匹配
  for dy in -search_radius..<(search_radius + 1) {
    for dx in -search_radius..<(search_radius + 1) {
      let new_x = obj.x + dx
      let new_y = obj.y + dy

      // 计算当前位置的颜色直方图
      let current_hist : Array[Double] = []
      for _ in 0..<16 {
        current_hist.push(0.0)
      }
      let mut total = 0

      for py in 0..<obj.height {
        for px in 0..<obj.width {
          let x = new_x + px
          let y = new_y + py
          if x >= 0 && x < w && y >= 0 && y < h {
            let pixel = frame.data[y * w + x].to_int()
            let bin = pixel / 16
            if bin < 16 {
              current_hist[bin] = current_hist[bin] + 1.0
            }
            total += 1
          }
        }
      }

      if total > 0 {
        // 归一化
        for i in 0..<16 {
          current_hist[i] = current_hist[i] / total.to_double()
        }

        // 计算直方图交集（相似度）
        let mut score = 0.0
        for i in 0..<16 {
          score += if current_hist[i] < obj.color_histogram[i] {
            current_hist[i]
          } else {
            obj.color_histogram[i]
          }
        }

        if score > best_score {
          best_score = score
          best_x = new_x
          best_y = new_y
        }
      }
    }
  }

  // 更新速度
  let new_center_x = (best_x + obj.width / 2).to_double()
  let new_center_y = (best_y + obj.height / 2).to_double()
  let velocity_x = new_center_x - obj.center_x
  let velocity_y = new_center_y - obj.center_y

  // 更新轨迹
  let mut new_trajectory = obj.trajectory
  new_trajectory.push((best_x + obj.width / 2, best_y + obj.height / 2))
  if new_trajectory.length() > 100 {
    // 保留最近 100 个点
    let trimmed : Array[(Int, Int)] = []
    for i in (new_trajectory.length() - 100)..<new_trajectory.length() {
      trimmed.push(new_trajectory[i])
    }
    new_trajectory = trimmed
  }

  TrackedObject::{
    id: obj.id,
    label: obj.label,
    x: best_x,
    y: best_y,
    width: obj.width,
    height: obj.height,
    center_x: new_center_x,
    center_y: new_center_y,
    velocity_x,
    velocity_y,
    confidence: best_score,
    age: obj.age + 1,
    visible_count: obj.visible_count + 1,
    invisible_count: 0,
    color_histogram: obj.color_histogram,
    trajectory: new_trajectory,
  }
}

///|
/// 动作识别（基于运动特征）
pub fn recognize_action(
  frames : Array[@types.Image],
  start_frame : Int,
  end_frame : Int,
) -> ActionRecognitionResult {
  if frames.length() < 2 || end_frame <= start_frame {
    return ActionRecognitionResult::{
      action_type: ActionType::Unknown,
      confidence: 0.0,
      start_frame,
      end_frame,
      duration_frames: 0,
      motion_energy: 0.0,
      direction: 0.0,
      key_points: [],
    }
  }

  // 计算运动能量序列
  let mut total_energy = 0.0
  let mut energy_count = 0
  let mut max_energy = 0.0
  let mut motion_dx = 0.0
  let mut motion_dy = 0.0

  for i in start_frame..<(end_frame - 1) {
    if i + 1 < frames.length() {
      let energy = compute_frame_difference(frames[i], frames[i + 1])
      total_energy += energy
      energy_count += 1
      if energy > max_energy {
        max_energy = energy
      }

      // 计算运动方向（简化版）
      let _ = compute_optical_flow(
        frames[i],
        frames[i + 1],
        block_size=16,
        search_range=2,
      )
      motion_dx += 1.0
      motion_dy += 0.0
    }
  }

  let avg_energy = if energy_count > 0 {
    total_energy / energy_count.to_double()
  } else {
    0.0
  }
  let direction = if motion_dx != 0 {
    motion_dy / motion_dx * 57.2958
  } else {
    0.0
  }

  // 根据运动特征分类动作
  let (action_type, confidence) = if avg_energy < 0.01 {
    (ActionType::Standing, 0.7)
  } else if avg_energy < 0.05 {
    (ActionType::Walking, 0.6)
  } else if avg_energy < 0.1 {
    (ActionType::Running, 0.6)
  } else if max_energy > 0.2 && avg_energy > 0.05 {
    (ActionType::Jumping, 0.5)
  } else if avg_energy > 0.15 {
    (ActionType::Waving, 0.5)
  } else {
    (ActionType::Unknown, 0.3)
  }

  let key_points : Array[(Int, Int)] = []

  ActionRecognitionResult::{
    action_type,
    confidence,
    start_frame,
    end_frame,
    duration_frames: end_frame - start_frame,
    motion_energy: avg_energy,
    direction,
    key_points,
  }
}

///|
/// 检测场景切换
pub fn detect_scene_change(
  frame1 : @types.Image,
  frame2 : @types.Image,
  threshold? : Double = 0.3,
) -> (Bool, Double) {
  let w = frame1.width
  let h = frame1.height
  let mut diff_sum = 0.0
  let total = w * h

  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      diff_sum += (frame1.data[idx].to_int() - frame2.data[idx].to_int())
        .abs()
        .to_double() /
        255.0
    }
  }

  let avg_diff = if total > 0 { diff_sum / total.to_double() } else { 0.0 }
  (avg_diff > threshold, avg_diff)
}

///|
/// 提取关键帧
pub fn extract_keyframes(
  frames : Array[@types.Image],
  fps : Double,
  method_type? : String = "auto",
) -> Array[Keyframe] {
  ignore(method_type)
  let keyframes : Array[Keyframe] = []

  if frames.length() == 0 {
    return keyframes
  }

  // 第一帧总是关键帧
  keyframes.push(Keyframe::{
    frame_index: 0,
    timestamp_ms: 0.0,
    keyframe_type: KeyframeType::UniformSampling,
    score: 1.0,
    thumbnail: frames[0],
  })

  // 检测场景切换
  for i in 1..<frames.length() {
    let (is_change, score) = detect_scene_change(frames[i - 1], frames[i])
    if is_change {
      keyframes.push(Keyframe::{
        frame_index: i,
        timestamp_ms: i.to_double() * 1000.0 / fps,
        keyframe_type: KeyframeType::SceneChange,
        score,
        thumbnail: frames[i],
      })
    }
  }

  // 均匀采样（如果关键帧太少）
  let min_keyframes = if frames.length() / 30 > 5 {
    frames.length() / 30
  } else {
    5
  }
  if keyframes.length() < min_keyframes {
    let interval = frames.length() / min_keyframes
    for i in 1..<min_keyframes {
      let idx = i * interval
      let mut exists = false
      for kf in keyframes {
        if kf.frame_index == idx {
          exists = true
        }
      }
      if !exists && idx < frames.length() {
        keyframes.push(Keyframe::{
          frame_index: idx,
          timestamp_ms: idx.to_double() * 1000.0 / fps,
          keyframe_type: KeyframeType::UniformSampling,
          score: 0.5,
          thumbnail: frames[idx],
        })
      }
    }
  }

  keyframes
}

///|
/// 生成视频摘要
pub fn generate_video_summary(
  frames : Array[@types.Image],
  fps : Double,
) -> VideoSummary {
  let total_frames = frames.length()
  let duration_ms = if fps > 0 {
    total_frames.to_double() * 1000.0 / fps
  } else {
    0.0
  }

  // 提取关键帧
  let keyframes = extract_keyframes(frames, fps)

  // 计算运动能量序列
  let motion_peaks : Array[Int] = []
  let scene_changes : Array[Int] = []
  let mut total_motion = 0.0
  let mut motion_count = 0

  for i in 1..<total_frames {
    let energy = compute_frame_difference(frames[i - 1], frames[i])
    total_motion += energy
    motion_count += 1

    if energy > 0.15 {
      motion_peaks.push(i)
    }

    let (is_change, _) = detect_scene_change(frames[i - 1], frames[i])
    if is_change {
      scene_changes.push(i)
    }
  }

  let avg_motion = if motion_count > 0 {
    total_motion / motion_count.to_double()
  } else {
    0.0
  }

  // 生成摘要文本
  let summary_text = "视频共 " +
    total_frames.to_string() +
    " 帧，时长 " +
    (duration_ms / 1000.0).to_string() +
    " 秒。" +
    "检测到 " +
    scene_changes.length().to_string() +
    " 个场景切换，" +
    motion_peaks.length().to_string() +
    " 个运动峰值。" +
    "平均运动能量 " +
    avg_motion.to_string() +
    "。" +
    "提取 " +
    keyframes.length().to_string() +
    " 个关键帧。"

  VideoSummary::{
    total_frames,
    duration_ms,
    keyframes,
    num_keyframes: keyframes.length(),
    average_motion: avg_motion,
    motion_peaks,
    scene_changes,
    summary_text,
  }
}

///|
/// 视频稳定（简化版，基于帧间偏移）
pub fn stabilize_video(
  frames : Array[@types.Image],
  config : VideoStabilizationConfig,
) -> Array[@types.Image] {
  if frames.length() < 2 {
    return frames
  }

  let stabilized : Array[@types.Image] = []
  stabilized.push(frames[0])

  // 计算帧间偏移
  let offsets_x : Array[Double] = []
  let offsets_y : Array[Double] = []
  offsets_x.push(0.0)
  offsets_y.push(0.0)

  for i in 1..<frames.length() {
    let flow = compute_optical_flow(
      frames[i - 1],
      frames[i],
      block_size=32,
      search_range=4,
    )
    // 平均光流作为全局偏移
    let mut avg_dx = 0.0
    let mut avg_dy = 0.0
    for v in flow.vectors {
      avg_dx += v.x
      avg_dy += v.y
    }
    if flow.vectors.length() > 0 {
      avg_dx = avg_dx / flow.vectors.length().to_double()
      avg_dy = avg_dy / flow.vectors.length().to_double()
    }
    offsets_x.push(avg_dx)
    offsets_y.push(avg_dy)
  }

  // 平滑偏移
  let smoothed_x : Array[Double] = []
  let smoothed_y : Array[Double] = []
  let radius = config.smoothing_radius

  for i in 0..<frames.length() {
    let mut sum_x = 0.0
    let mut sum_y = 0.0
    let mut count = 0
    for j in (i - radius)..<(i + radius + 1) {
      if j >= 0 && j < frames.length() {
        sum_x += offsets_x[j]
        sum_y += offsets_y[j]
        count += 1
      }
    }
    smoothed_x.push(if count > 0 { sum_x / count.to_double() } else { 0.0 })
    smoothed_y.push(if count > 0 { sum_y / count.to_double() } else { 0.0 })
  }

  // 应用稳定（简化版：直接返回原帧，实际应进行仿射变换）
  for i in 1..<frames.length() {
    stabilized.push(frames[i])
  }

  stabilized
}

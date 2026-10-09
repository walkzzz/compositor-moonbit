// 视频处理基础（v12.8.0）
// 帧动画创建、帧插值、简单视频效果

///|
/// 视频帧序列
pub(all) struct VideoFrames {
  frames : Array[@types.Image]
  width : Int
  height : Int
  channels : Int
  fps : Double
}

///|
/// 创建视频帧序列
pub fn video_frames_new(
  frames : Array[@types.Image],
  fps? : Double = 30.0,
) -> VideoFrames {
  if frames.length() == 0 {
    return VideoFrames::{ frames: [], width: 0, height: 0, channels: 1, fps }
  }
  let first = frames[0]
  VideoFrames::{
    frames,
    width: first.width,
    height: first.height,
    channels: first.channels,
    fps,
  }
}

///|
/// 获取帧数
pub fn video_frame_count(video : VideoFrames) -> Int {
  video.frames.length()
}

///|
/// 获取指定帧
pub fn video_get_frame(video : VideoFrames, index : Int) -> @types.Image? {
  if index >= 0 && index < video.frames.length() {
    Some(video.frames[index])
  } else {
    None
  }
}

///|
/// 帧插值（在两帧之间生成中间帧）
/// 使用简单的线性插值
pub fn interpolate_frames(
  frame1 : @types.Image,
  frame2 : @types.Image,
  num_frames? : Int = 1,
) -> Array[@types.Image] {
  let n = num_frames
  if frame1.width != frame2.width || frame1.height != frame2.height {
    return []
  }
  let w = frame1.width
  let h = frame1.height
  let channels = frame1.channels.min(frame2.channels)
  let result : Array[@types.Image] = []
  for i in 1..<(n + 1) {
    let alpha = i.to_double() / (n + 1).to_double()
    let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
    for y in 0..<h {
      for x in 0..<w {
        let idx = (y * w + x) * channels
        for c in 0..<channels {
          let v1 = frame1.data[idx + c].to_double()
          let v2 = frame2.data[idx + c].to_double()
          let interpolated = v1 * (1.0 - alpha) + v2 * alpha
          out_data[idx + c] = interpolated
            .min(255.0)
            .max(0.0)
            .to_int()
            .to_byte()
        }
      }
    }
    result.push(@types.Image::{
      width: w,
      height: h,
      channels,
      data: Bytes::from_array(out_data),
    })
  }
  result
}

///|
/// 视频淡入效果
pub fn video_fade_in(
  video : VideoFrames,
  duration_frames? : Int = 30,
) -> VideoFrames {
  let duration = duration_frames
  let frames = video.frames
  let result : Array[@types.Image] = []
  for i in 0..<frames.length() {
    let frame = frames[i]
    if i < duration {
      let alpha = i.to_double() / duration.to_double()
      let w = frame.width
      let h = frame.height
      let channels = frame.channels
      let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
      for y in 0..<h {
        for x in 0..<w {
          let idx = (y * w + x) * channels
          for c in 0..<channels {
            let v = frame.data[idx + c].to_double() * alpha
            out_data[idx + c] = v.min(255.0).max(0.0).to_int().to_byte()
          }
        }
      }
      result.push(@types.Image::{
        width: w,
        height: h,
        channels,
        data: Bytes::from_array(out_data),
      })
    } else {
      result.push(frame)
    }
  }
  VideoFrames::{
    frames: result,
    width: video.width,
    height: video.height,
    channels: video.channels,
    fps: video.fps,
  }
}

///|
/// 视频淡出效果
pub fn video_fade_out(
  video : VideoFrames,
  duration_frames? : Int = 30,
) -> VideoFrames {
  let duration = duration_frames
  let frames = video.frames
  let n = frames.length()
  let result : Array[@types.Image] = []
  for i in 0..<n {
    let frame = frames[i]
    if i >= n - duration {
      let alpha = (n - 1 - i).to_double() / duration.to_double()
      let w = frame.width
      let h = frame.height
      let channels = frame.channels
      let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
      for y in 0..<h {
        for x in 0..<w {
          let idx = (y * w + x) * channels
          for c in 0..<channels {
            let v = frame.data[idx + c].to_double() * alpha
            out_data[idx + c] = v.min(255.0).max(0.0).to_int().to_byte()
          }
        }
      }
      result.push(@types.Image::{
        width: w,
        height: h,
        channels,
        data: Bytes::from_array(out_data),
      })
    } else {
      result.push(frame)
    }
  }
  VideoFrames::{
    frames: result,
    width: video.width,
    height: video.height,
    channels: video.channels,
    fps: video.fps,
  }
}

///|
/// 视频抽帧（按间隔抽取帧）
pub fn video_sample(video : VideoFrames, interval? : Int = 2) -> VideoFrames {
  let step = interval
  let frames = video.frames
  let result : Array[@types.Image] = []
  let mut i = 0
  while i < frames.length() {
    result.push(frames[i])
    i += step
  }
  VideoFrames::{
    frames: result,
    width: video.width,
    height: video.height,
    channels: video.channels,
    fps: video.fps / step.to_double(),
  }
}

///|
/// 视频倒放
pub fn video_reverse(video : VideoFrames) -> VideoFrames {
  let frames = video.frames
  let result : Array[@types.Image] = []
  let mut i = frames.length() - 1
  while i >= 0 {
    result.push(frames[i])
    i -= 1
  }
  VideoFrames::{
    frames: result,
    width: video.width,
    height: video.height,
    channels: video.channels,
    fps: video.fps,
  }
}

///|
/// 视频拼接（将两个视频首尾相接）
pub fn video_concat(video1 : VideoFrames, video2 : VideoFrames) -> VideoFrames {
  let frames : Array[@types.Image] = []
  for frame in video1.frames {
    frames.push(frame)
  }
  for frame in video2.frames {
    frames.push(frame)
  }
  VideoFrames::{
    frames,
    width: video1.width,
    height: video1.height,
    channels: video1.channels,
    fps: video1.fps,
  }
}

///|
/// 生成 GIF 动画的简化版（输出为帧序列，不编码）
/// 实际 GIF 编码需要额外的库支持
pub fn create_animation(
  frames : Array[@types.Image],
  fps? : Double = 10.0,
) -> VideoFrames {
  video_frames_new(frames, fps~)
}

///|
/// 视频帧平均（将多帧平均为一帧，用于降噪）
pub fn video_frame_average(video : VideoFrames) -> @types.Image {
  let frames = video.frames
  if frames.length() == 0 {
    return @types.Image::{
      width: 1,
      height: 1,
      channels: 1,
      data: Bytes::from_array([b'\x00']),
    }
  }
  let w = video.width
  let h = video.height
  let channels = video.channels
  let n = frames.length().to_double()
  let sum : Array[Double] = Array::make(w * h * channels, 0.0)
  for frame in frames {
    for i in 0..<(w * h * channels) {
      sum[i] += frame.data[i].to_double()
    }
  }
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  for i in 0..<(w * h * channels) {
    out_data[i] = (sum[i] / n).min(255.0).max(0.0).to_int().to_byte()
  }
  @types.Image::{
    width: w,
    height: h,
    channels,
    data: Bytes::from_array(out_data),
  }
}

// production_utils.mbt：生产级工具函数
// 提供统一的输入验证、错误处理、性能监控、内存安全等功能

///|
/// 图像验证结果
pub(all) struct ImageValidationResult {
  is_valid : Bool
  errors : Array[String]
  warnings : Array[String]
  width : Int
  height : Int
  channels : Int
  data_size : Int
  expected_data_size : Int
}

///|
/// 验证图像有效性
pub fn validate_image(img : @types.Image) -> ImageValidationResult {
  let errors : Array[String] = []
  let warnings : Array[String] = []

  // 验证尺寸
  if img.width <= 0 {
    errors.push("宽度必须大于0")
  }
  if img.height <= 0 {
    errors.push("高度必须大于0")
  }
  if img.width > 65535 {
    warnings.push("宽度超过65535，可能导致内存问题")
  }
  if img.height > 65535 {
    warnings.push("高度超过65535，可能导致内存问题")
  }

  // 验证通道数
  if img.channels < 1 || img.channels > 4 {
    errors.push("通道数必须在1-4之间")
  }

  // 验证数据大小
  let expected_size = img.width * img.height * img.channels
  let actual_size = img.data.length()
  if actual_size != expected_size {
    errors.push(
      "数据大小不匹配：期望 " +
      expected_size.to_string() +
      "，实际 " +
      actual_size.to_string(),
    )
  }

  // 检查潜在的整数溢出
  if img.width > 0 && img.height > 0 {
    let pixel_count = img.width * img.height
    if pixel_count / img.width != img.height {
      errors.push("像素计数溢出")
    }
  }

  ImageValidationResult::{
    is_valid: errors.length() == 0,
    errors,
    warnings,
    width: img.width,
    height: img.height,
    channels: img.channels,
    data_size: actual_size,
    expected_data_size: expected_size,
  }
}

///|
/// 验证图像并在无效时抛出错误
pub fn validate_image_or_raise(
  img : @types.Image,
) -> Unit raise @types.LoadError {
  let result = validate_image(img)
  if !result.is_valid {
    let mut error_msg = "图像验证失败："
    for err in result.errors {
      error_msg = error_msg + err + "; "
    }
    raise @types.LoadError::DecodeFailed(error_msg)
  }
}

///|
/// 验证图像通道数
pub fn validate_channels(
  img : @types.Image,
  expected_channels : Array[Int],
) -> Bool {
  for ch in expected_channels {
    if img.channels == ch {
      return true
    }
  }
  false
}

///|
/// 验证图像通道数并在无效时抛出错误
pub fn validate_channels_or_raise(
  img : @types.Image,
  expected_channels : Array[Int],
  function_name : String,
) -> Unit raise @types.LoadError {
  if !validate_channels(img, expected_channels) {
    let mut expected_str = ""
    for i in 0..<expected_channels.length() {
      if i > 0 {
        expected_str = expected_str + ", "
      }
      expected_str = expected_str + expected_channels[i].to_string()
    }
    raise @types.LoadError::DecodeFailed(
      function_name +
      " 需要通道数为 [" +
      expected_str +
      "]，实际为 " +
      img.channels.to_string(),
    )
  }
}

///|
/// 验证参数范围
pub fn validate_range(
  value : Double,
  min : Double,
  max : Double,
  param_name : String,
) -> Result[Unit, String] {
  if value < min || value > max {
    Result::Err(
      param_name +
      " 必须在 [" +
      min.to_string() +
      ", " +
      max.to_string() +
      "] 范围内，实际为 " +
      value.to_string(),
    )
  } else {
    Result::Ok(())
  }
}

///|
/// 验证参数范围并在无效时抛出错误
pub fn validate_range_or_raise(
  value : Double,
  min : Double,
  max : Double,
  param_name : String,
) -> Unit raise @types.LoadError {
  let result = validate_range(value, min, max, param_name)
  match result {
    Result::Err(msg) => raise @types.LoadError::DecodeFailed(msg)
    Result::Ok(_) => ()
  }
}

///|
/// 验证整数参数范围
pub fn validate_int_range(
  value : Int,
  min : Int,
  max : Int,
  param_name : String,
) -> Result[Unit, String] {
  if value < min || value > max {
    Result::Err(
      param_name +
      " 必须在 [" +
      min.to_string() +
      ", " +
      max.to_string() +
      "] 范围内，实际为 " +
      value.to_string(),
    )
  } else {
    Result::Ok(())
  }
}

///|
/// 验证整数参数范围并在无效时抛出错误
pub fn validate_int_range_or_raise(
  value : Int,
  min : Int,
  max : Int,
  param_name : String,
) -> Unit raise @types.LoadError {
  let result = validate_int_range(value, min, max, param_name)
  match result {
    Result::Err(msg) => raise @types.LoadError::DecodeFailed(msg)
    Result::Ok(_) => ()
  }
}

///|
/// 安全的像素值钳制
pub fn clamp_pixel_value(value : Int) -> Int {
  if value < 0 {
    0
  } else if value > 255 {
    255
  } else {
    value
  }
}

///|
/// 安全的浮点像素值钳制
pub fn clamp_pixel_value_double(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 255.0 {
    255.0
  } else {
    value
  }
}

///|
/// 安全的索引检查
pub fn is_valid_index(index : Int, length : Int) -> Bool {
  index >= 0 && index < length
}

///|
/// 安全的2D索引检查
pub fn is_valid_2d_index(x : Int, y : Int, width : Int, height : Int) -> Bool {
  x >= 0 && x < width && y >= 0 && y < height
}

///|
/// 性能计时器
pub(all) struct PerformanceTimer {
  start_time_ms : Double
  end_time_ms : Double
  elapsed_ms : Double
  operation_name : String
}

///|
/// 创建性能计时器
pub fn create_performance_timer(operation_name : String) -> PerformanceTimer {
  PerformanceTimer::{
    start_time_ms: 0.0,
    end_time_ms: 0.0,
    elapsed_ms: 0.0,
    operation_name,
  }
}

///|
/// 内存使用统计
pub(all) struct MemoryUsageStats {
  allocated_bytes : Int
  freed_bytes : Int
  current_usage_bytes : Int
  peak_usage_bytes : Int
  allocation_count : Int
  free_count : Int
}

///|
/// 创建内存使用统计
pub fn create_memory_stats() -> MemoryUsageStats {
  MemoryUsageStats::{
    allocated_bytes: 0,
    freed_bytes: 0,
    current_usage_bytes: 0,
    peak_usage_bytes: 0,
    allocation_count: 0,
    free_count: 0,
  }
}

///|
/// 错误码枚举
pub(all) enum ProductionErrorCode {
  InvalidInput
  OutOfMemory
  IndexOutOfBounds
  UnsupportedFormat
  OperationFailed
  Timeout
  InternalError
  Unknown
} derive(Eq)

///|
/// 生产级错误
pub(all) struct ProductionError {
  code : ProductionErrorCode
  message : String
  function_name : String
  timestamp_ms : Double
  recoverable : Bool
}

///|
/// 创建生产级错误
pub fn create_production_error(
  code : ProductionErrorCode,
  message : String,
  function_name : String,
) -> ProductionError {
  ProductionError::{
    code,
    message,
    function_name,
    timestamp_ms: 0.0,
    recoverable: code != ProductionErrorCode::InternalError,
  }
}

///|
/// 重试配置
pub(all) struct RetryConfig {
  max_retries : Int
  initial_delay_ms : Double
  max_delay_ms : Double
  backoff_factor : Double
  retry_on_timeout : Bool
  retry_on_internal_error : Bool
}

///|
/// 创建默认重试配置
pub fn create_default_retry_config() -> RetryConfig {
  RetryConfig::{
    max_retries: 3,
    initial_delay_ms: 100.0,
    max_delay_ms: 5000.0,
    backoff_factor: 2.0,
    retry_on_timeout: true,
    retry_on_internal_error: false,
  }
}

///|
/// 计算重试延迟
pub fn calculate_retry_delay(config : RetryConfig, attempt : Int) -> Double {
  let mut factor = 1.0
  for _ in 0..<attempt {
    factor = factor * config.backoff_factor
  }
  let base_delay = config.initial_delay_ms * factor
  if base_delay > config.max_delay_ms {
    config.max_delay_ms
  } else {
    base_delay
  }
}

///|
/// 验证结果转字符串
pub fn validation_result_to_string(result : ImageValidationResult) -> String {
  let mut report = "## 图像验证报告\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report +
    "| 验证结果 | " +
    (if result.is_valid { "通过" } else { "失败" }) +
    " |\n"
  report = report + "| 宽度 | " + result.width.to_string() + " |\n"
  report = report + "| 高度 | " + result.height.to_string() + " |\n"
  report = report + "| 通道数 | " + result.channels.to_string() + " |\n"
  report = report + "| 数据大小 | " + result.data_size.to_string() + " |\n"
  report = report +
    "| 期望数据大小 | " +
    result.expected_data_size.to_string() +
    " |\n"

  if result.errors.length() > 0 {
    report = report + "\n### 错误\n\n"
    for err in result.errors {
      report = report + "- " + err + "\n"
    }
  }

  if result.warnings.length() > 0 {
    report = report + "\n### 警告\n\n"
    for warn in result.warnings {
      report = report + "- " + warn + "\n"
    }
  }

  report
}

///|
/// 生产级错误转字符串
pub fn production_error_to_string(err : ProductionError) -> String {
  let code_str = match err.code {
    ProductionErrorCode::InvalidInput => "无效输入"
    ProductionErrorCode::OutOfMemory => "内存不足"
    ProductionErrorCode::IndexOutOfBounds => "索引越界"
    ProductionErrorCode::UnsupportedFormat => "不支持的格式"
    ProductionErrorCode::OperationFailed => "操作失败"
    ProductionErrorCode::Timeout => "超时"
    ProductionErrorCode::InternalError => "内部错误"
    _ => "未知错误"
  }

  "[" + code_str + "] " + err.function_name + ": " + err.message
}

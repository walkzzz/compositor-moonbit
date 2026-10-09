// OCR 模型训练框架（v13.1.0）
// 数据增强、优化器、学习率调度、训练循环、模型评估、早停机制

///|
/// 优化器类型
pub(all) enum OptimizerType {
  SGD
  Momentum
  Adam
  RMSprop
  Adagrad
} derive(Eq)

///|
/// 优化器配置
pub(all) struct OptimizerConfig {
  optimizer_type : OptimizerType
  learning_rate : Double
  momentum : Double
  beta1 : Double
  beta2 : Double
  epsilon : Double
  weight_decay : Double
  grad_clip : Double
}

///|
/// 学习率调度器类型
pub(all) enum LRSchedulerType {
  Constant
  StepDecay
  ExponentialDecay
  CosineAnnealing
  WarmupCosine
  ReduceOnPlateau
} derive(Eq)

///|
/// 学习率调度器配置
pub(all) struct LRSchedulerConfig {
  scheduler_type : LRSchedulerType
  initial_lr : Double
  min_lr : Double
  decay_rate : Double
  decay_steps : Int
  warmup_steps : Int
  patience : Int
  factor : Double
}

///|
/// 数据增强类型
pub(all) enum AugmentationType {
  RandomRotation
  RandomShift
  RandomScale
  RandomShear
  RandomNoise
  RandomBlur
  RandomBrightness
  RandomContrast
  ElasticTransform
} derive(Eq)

///|
/// 数据增强配置
pub(all) struct AugmentationConfig {
  enabled : Bool
  augmentation_types : Array[AugmentationType]
  rotation_range : Double // 度
  shift_range : Double // 比例
  scale_range : Double // 比例
  noise_level : Double
  blur_sigma : Double
  brightness_range : Double
  contrast_range : Double
  probability : Double // 每个增强的应用概率
}

///|
/// 训练配置
pub(all) struct TrainingConfig {
  epochs : Int
  batch_size : Int
  optimizer : OptimizerConfig
  lr_scheduler : LRSchedulerConfig
  augmentation : AugmentationConfig
  early_stopping_patience : Int
  early_stopping_min_delta : Double
  save_best_only : Bool
  checkpoint_interval : Int
  log_interval : Int
  validation_split : Double
  shuffle : Bool
  random_seed : Int
}

///|
/// 训练指标
pub(all) struct TrainingMetrics {
  epoch : Int
  train_loss : Double
  train_accuracy : Double
  val_loss : Double
  val_accuracy : Double
  learning_rate : Double
  time_ms : Double
  is_best : Bool
}

///|
/// 训练状态
pub(all) struct TrainingState {
  current_epoch : Int
  best_val_accuracy : Double
  best_epoch : Int
  epochs_without_improvement : Int
  total_training_time_ms : Double
  history : Array[TrainingMetrics]
  is_completed : Bool
  stop_reason : String
}

///|
/// 数据加载器
pub(all) struct DataLoader {
  samples : Array[DLTrainingSample]
  batch_size : Int
  shuffle : Bool
  current_index : Int
  epoch : Int
}

///|
/// 创建默认训练配置
pub fn create_default_training_config() -> TrainingConfig {
  TrainingConfig::{
    epochs: 50,
    batch_size: 32,
    optimizer: OptimizerConfig::{
      optimizer_type: OptimizerType::Adam,
      learning_rate: 0.001,
      momentum: 0.9,
      beta1: 0.9,
      beta2: 0.999,
      epsilon: 0.0000001,
      weight_decay: 0.0001,
      grad_clip: 1.0,
    },
    lr_scheduler: LRSchedulerConfig::{
      scheduler_type: LRSchedulerType::CosineAnnealing,
      initial_lr: 0.001,
      min_lr: 0.00001,
      decay_rate: 0.1,
      decay_steps: 10,
      warmup_steps: 5,
      patience: 5,
      factor: 0.5,
    },
    augmentation: AugmentationConfig::{
      enabled: true,
      augmentation_types: [
        AugmentationType::RandomRotation,
        AugmentationType::RandomShift,
        AugmentationType::RandomScale,
        AugmentationType::RandomNoise,
      ],
      rotation_range: 15.0,
      shift_range: 0.1,
      scale_range: 0.1,
      noise_level: 0.05,
      blur_sigma: 1.0,
      brightness_range: 0.2,
      contrast_range: 0.2,
      probability: 0.5,
    },
    early_stopping_patience: 10,
    early_stopping_min_delta: 0.001,
    save_best_only: true,
    checkpoint_interval: 5,
    log_interval: 1,
    validation_split: 0.2,
    shuffle: true,
    random_seed: 42,
  }
}

///|
/// 创建数据加载器
pub fn create_data_loader(
  samples : Array[DLTrainingSample],
  batch_size : Int,
  shuffle : Bool,
) -> DataLoader raise @types.LoadError {
  // 输入验证
  if samples.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "create_data_loader: 样本列表不能为空",
    )
  }
  if batch_size <= 0 {
    raise @types.LoadError::DecodeFailed(
      "create_data_loader: 批大小必须大于0",
    )
  }
  DataLoader::{ samples, batch_size, shuffle, current_index: 0, epoch: 0 }
}

///|
/// 获取下一批数据
pub fn next_batch(
  loader : DataLoader,
) -> (Array[DLTrainingSample], DataLoader) raise @types.LoadError {
  // 输入验证
  if loader.samples.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "next_batch: 数据加载器的样本列表不能为空",
    )
  }
  if loader.batch_size <= 0 {
    raise @types.LoadError::DecodeFailed("next_batch: 批大小必须大于0")
  }
  let end_index = if loader.current_index + loader.batch_size <
    loader.samples.length() {
    loader.current_index + loader.batch_size
  } else {
    loader.samples.length()
  }
  let batch : Array[DLTrainingSample] = []
  for i in loader.current_index..<end_index {
    batch.push(loader.samples[i])
  }
  let new_index = if end_index >= loader.samples.length() {
    0
  } else {
    end_index
  }
  let new_epoch = if end_index >= loader.samples.length() {
    loader.epoch + 1
  } else {
    loader.epoch
  }
  (
    batch,
    DataLoader::{
      samples: loader.samples,
      batch_size: loader.batch_size,
      shuffle: loader.shuffle,
      current_index: new_index,
      epoch: new_epoch,
    },
  )
}

///|
/// 幂运算
fn power_double(base : Double, exp : Int) -> Double {
  let mut result = 1.0
  for _ in 0..<exp {
    result = result * base
  }
  result
}

///|
/// 近似 cos 函数（泰勒级数）
fn approx_cos(x : Double) -> Double {
  // 归一化到 [-pi, pi]
  let pi = 3.141592653589793
  let mut t = x % (2.0 * pi)
  if t > pi {
    t = t - 2.0 * pi
  }
  if t < -pi {
    t = t + 2.0 * pi
  }
  // 泰勒级数
  let mut result = 1.0
  let mut term = 1.0
  for i in 1..<10 {
    term = term *
      (-t * t) /
      ((2.0 * i.to_double() - 1.0) * (2.0 * i.to_double()))
    result = result + term
  }
  result
}

///|
/// 计算学习率
pub fn calculate_learning_rate(
  config : LRSchedulerConfig,
  epoch : Int,
  current_lr : Double,
  val_loss : Double,
) -> Double raise @types.LoadError {
  // 输入验证
  if epoch < 0 {
    raise @types.LoadError::DecodeFailed(
      "calculate_learning_rate: 轮次不能为负",
    )
  }
  if current_lr <= 0.0 {
    raise @types.LoadError::DecodeFailed(
      "calculate_learning_rate: 当前学习率必须大于0",
    )
  }
  if val_loss < 0.0 {
    raise @types.LoadError::DecodeFailed(
      "calculate_learning_rate: 验证损失不能为负",
    )
  }
  if config.initial_lr <= 0.0 {
    raise @types.LoadError::DecodeFailed(
      "calculate_learning_rate: 初始学习率必须大于0",
    )
  }
  if config.min_lr < 0.0 {
    raise @types.LoadError::DecodeFailed(
      "calculate_learning_rate: 最小学习率不能为负",
    )
  }
  match config.scheduler_type {
    LRSchedulerType::Constant => config.initial_lr
    LRSchedulerType::StepDecay => {
      let decay_factor = (epoch / config.decay_steps).to_double()
      let lr = config.initial_lr *
        power_double(config.decay_rate, decay_factor.to_int())
      if lr > config.min_lr {
        lr
      } else {
        config.min_lr
      }
    }
    LRSchedulerType::ExponentialDecay => {
      let lr = config.initial_lr * power_double(config.decay_rate, epoch)
      if lr > config.min_lr {
        lr
      } else {
        config.min_lr
      }
    }
    LRSchedulerType::CosineAnnealing => {
      let pi = 3.141592653589793
      let cos_val = approx_cos(pi * epoch.to_double() / 50.0)
      let lr = config.min_lr +
        0.5 * (config.initial_lr - config.min_lr) * (1.0 + cos_val)
      lr
    }
    LRSchedulerType::WarmupCosine =>
      if epoch < config.warmup_steps {
        config.initial_lr *
        (epoch.to_double() + 1.0) /
        config.warmup_steps.to_double()
      } else {
        let pi = 3.141592653589793
        let progress = (epoch - config.warmup_steps).to_double() /
          (50.0 - config.warmup_steps.to_double())
        let cos_val = approx_cos(pi * progress)
        config.min_lr +
        0.5 * (config.initial_lr - config.min_lr) * (1.0 + cos_val)
      }
    LRSchedulerType::ReduceOnPlateau => current_lr
  }
}

///|
/// 数据增强：随机旋转
pub fn augment_random_rotation(
  sample : DLTrainingSample,
  angle_range : Double,
) -> DLTrainingSample {
  ignore(angle_range)
  // 简化版：实际应旋转图像
  sample
}

///|
/// 数据增强：随机平移
pub fn augment_random_shift(
  sample : DLTrainingSample,
  shift_range : Double,
) -> DLTrainingSample {
  ignore(shift_range)
  // 简化版：实际应平移图像
  sample
}

///|
/// 数据增强：随机缩放
pub fn augment_random_scale(
  sample : DLTrainingSample,
  scale_range : Double,
) -> DLTrainingSample {
  ignore(scale_range)
  // 简化版：实际应缩放图像
  sample
}

///|
/// 数据增强：随机噪声
pub fn augment_random_noise(
  sample : DLTrainingSample,
  noise_level : Double,
) -> DLTrainingSample {
  let augmented_data : Array[Double] = []
  for pixel in sample.image_data {
    let noise = pixel * noise_level * (if pixel > 0.5 { 1.0 } else { -1.0 })
    let new_pixel = if pixel + noise > 1.0 {
      1.0
    } else if pixel + noise < 0.0 {
      0.0
    } else {
      pixel + noise
    }
    augmented_data.push(new_pixel)
  }
  DLTrainingSample::{
    image_data: augmented_data,
    label: sample.label,
    label_text: sample.label_text,
    width: sample.width,
    height: sample.height,
  }
}

///|
/// 应用数据增强
pub fn apply_augmentation(
  sample : DLTrainingSample,
  config : AugmentationConfig,
) -> DLTrainingSample {
  if !config.enabled {
    return sample
  }
  let mut augmented = sample
  for aug_type in config.augmentation_types {
    // 简化：固定应用噪声增强
    match aug_type {
      AugmentationType::RandomNoise =>
        augmented = augment_random_noise(augmented, config.noise_level)
      _ => ()
    }
  }
  augmented
}

///|
/// 计算准确率
pub fn calculate_accuracy(
  predictions : Array[Int],
  labels : Array[Int],
) -> Double {
  if predictions.length() == 0 || labels.length() == 0 {
    return 0.0
  }
  let mut correct = 0
  let len = if predictions.length() < labels.length() {
    predictions.length()
  } else {
    labels.length()
  }
  for i in 0..<len {
    if predictions[i] == labels[i] {
      correct += 1
    }
  }
  correct.to_double() / len.to_double()
}

///|
/// 早停检查
pub fn check_early_stopping(
  state : TrainingState,
  config : TrainingConfig,
  current_val_accuracy : Double,
) -> (Bool, TrainingState) {
  let improvement = current_val_accuracy - state.best_val_accuracy
  if improvement > config.early_stopping_min_delta {
    let new_state = TrainingState::{
      current_epoch: state.current_epoch,
      best_val_accuracy: current_val_accuracy,
      best_epoch: state.current_epoch,
      epochs_without_improvement: 0,
      total_training_time_ms: state.total_training_time_ms,
      history: state.history,
      is_completed: false,
      stop_reason: "",
    }
    (false, new_state)
  } else {
    let new_epochs_without = state.epochs_without_improvement + 1
    let should_stop = new_epochs_without >= config.early_stopping_patience
    let new_state = TrainingState::{
      current_epoch: state.current_epoch,
      best_val_accuracy: state.best_val_accuracy,
      best_epoch: state.best_epoch,
      epochs_without_improvement: new_epochs_without,
      total_training_time_ms: state.total_training_time_ms,
      history: state.history,
      is_completed: should_stop,
      stop_reason: if should_stop {
        "early_stopping"
      } else {
        ""
      },
    }
    (should_stop, new_state)
  }
}

///|
/// 创建训练状态
pub fn create_training_state() -> TrainingState {
  TrainingState::{
    current_epoch: 0,
    best_val_accuracy: 0.0,
    best_epoch: 0,
    epochs_without_improvement: 0,
    total_training_time_ms: 0.0,
    history: [],
    is_completed: false,
    stop_reason: "",
  }
}

///|
/// 记录训练指标
pub fn record_training_metrics(
  state : TrainingState,
  metrics : TrainingMetrics,
) -> TrainingState {
  let new_history = state.history
  new_history.push(metrics)
  TrainingState::{
    current_epoch: metrics.epoch,
    best_val_accuracy: if metrics.val_accuracy > state.best_val_accuracy {
      metrics.val_accuracy
    } else {
      state.best_val_accuracy
    },
    best_epoch: if metrics.val_accuracy > state.best_val_accuracy {
      metrics.epoch
    } else {
      state.best_epoch
    },
    epochs_without_improvement: if metrics.val_accuracy >
      state.best_val_accuracy {
      0
    } else {
      state.epochs_without_improvement + 1
    },
    total_training_time_ms: state.total_training_time_ms + metrics.time_ms,
    history: new_history,
    is_completed: state.is_completed,
    stop_reason: state.stop_reason,
  }
}

///|
/// 生成训练进度报告
pub fn generate_training_progress_report(
  state : TrainingState,
  config : TrainingConfig,
) -> String {
  let mut report = "## 训练进度报告\n\n"
  report = report + "### 当前状态\n\n"
  report = report + "| 指标 | 值 |\n"
  report = report + "|------|------|\n"
  report = report +
    "| 当前轮次 | " +
    state.current_epoch.to_string() +
    " / " +
    config.epochs.to_string() +
    " |\n"
  report = report +
    "| 最佳验证准确率 | " +
    (state.best_val_accuracy * 100.0).to_string() +
    "% |\n"
  report = report + "| 最佳轮次 | " + state.best_epoch.to_string() + " |\n"
  report = report +
    "| 无改进轮次 | " +
    state.epochs_without_improvement.to_string() +
    " / " +
    config.early_stopping_patience.to_string() +
    " |\n"
  report = report +
    "| 总训练时间 | " +
    (state.total_training_time_ms / 1000.0).to_string() +
    " 秒 |\n"
  report = report +
    "| 训练状态 | " +
    (if state.is_completed {
      "已完成 (" + state.stop_reason + ")"
    } else {
      "进行中"
    }) +
    " |\n\n"

  if state.history.length() > 0 {
    report = report + "### 最近 5 轮训练记录\n\n"
    report = report +
      "| Epoch | Train Loss | Train Acc | Val Loss | Val Acc | LR |\n"
    report = report +
      "|-------|------------|-----------|----------|---------|----|\n"
    let start = if state.history.length() > 5 {
      state.history.length() - 5
    } else {
      0
    }
    for i in start..<state.history.length() {
      let h = state.history[i]
      report = report + "| " + h.epoch.to_string() + " | "
      report = report + h.train_loss.to_string() + " | "
      report = report + (h.train_accuracy * 100.0).to_string() + "% | "
      report = report + h.val_loss.to_string() + " | "
      report = report + (h.val_accuracy * 100.0).to_string() + "% | "
      report = report + h.learning_rate.to_string() + " |\n"
    }
  }

  report
}

///|
/// 划分训练集和验证集
pub fn split_train_validation(
  samples : Array[DLTrainingSample],
  validation_split : Double,
  shuffle : Bool,
) -> (Array[DLTrainingSample], Array[DLTrainingSample]) {
  ignore(shuffle)
  let total = samples.length()
  let val_count = (total.to_double() * validation_split).to_int()
  let train_count = total - val_count

  let train_samples : Array[DLTrainingSample] = []
  let val_samples : Array[DLTrainingSample] = []

  for i in 0..<train_count {
    train_samples.push(samples[i])
  }
  for i in train_count..<total {
    val_samples.push(samples[i])
  }

  (train_samples, val_samples)
}

///|
/// 混淆矩阵计算
pub fn compute_confusion_matrix(
  predictions : Array[Int],
  labels : Array[Int],
  num_classes : Int,
) -> Array[Array[Int]] {
  let matrix : Array[Array[Int]] = []
  for _ in 0..<num_classes {
    let row : Array[Int] = []
    for _ in 0..<num_classes {
      row.push(0)
    }
    matrix.push(row)
  }
  let len = if predictions.length() < labels.length() {
    predictions.length()
  } else {
    labels.length()
  }
  for i in 0..<len {
    let true_label = labels[i]
    let pred_label = predictions[i]
    if true_label < num_classes && pred_label < num_classes {
      let row = matrix[true_label]
      row[pred_label] = row[pred_label] + 1
    }
  }
  matrix
}

///|
/// 计算每类准确率
pub fn compute_per_class_accuracy(
  confusion_matrix : Array[Array[Int]],
) -> Array[Double] {
  let accuracies : Array[Double] = []
  for i in 0..<confusion_matrix.length() {
    let mut total = 0
    for j in 0..<confusion_matrix[i].length() {
      total += confusion_matrix[i][j]
    }
    let accuracy = if total > 0 {
      confusion_matrix[i][i].to_double() / total.to_double()
    } else {
      0.0
    }
    accuracies.push(accuracy)
  }
  accuracies
}

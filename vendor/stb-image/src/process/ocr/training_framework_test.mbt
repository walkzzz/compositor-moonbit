// v13.1.0 OCR 模型训练框架测试

///|
fn create_test_sample(
  label : Int,
  label_text : String,
) -> DLTrainingSample raise @types.LoadError {
  let img = @types.Image::{
    width: 8,
    height: 8,
    channels: 1,
    data: Bytes::from_array(Array::make(64, b'\x80')),
  }
  create_training_sample(img, label, label_text)
}

///|
test "create_default_training_config: 返回有效配置" {
  let config = create_default_training_config()
  assert_true(config.epochs > 0)
  assert_true(config.batch_size > 0)
  assert_true(config.optimizer.learning_rate > 0.0)
  assert_true(config.lr_scheduler.initial_lr > 0.0)
  assert_true(config.augmentation.enabled)
  assert_true(config.early_stopping_patience > 0)
}

///|
test "create_data_loader: 基本创建" {
  let sample1 = create_test_sample(0, "A")
  let sample2 = create_test_sample(1, "B")
  let loader = create_data_loader([sample1, sample2], 1, true)
  assert_eq(loader.samples.length(), 2)
  assert_eq(loader.batch_size, 1)
  assert_eq(loader.current_index, 0)
  assert_eq(loader.epoch, 0)
}

///|
test "create_data_loader: 空样本抛异常" {
  try {
    let _ = create_data_loader([], 32, true)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "create_data_loader: 批大小为零抛异常" {
  let sample = create_test_sample(0, "A")
  try {
    let _ = create_data_loader([sample], 0, true)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "next_batch: 获取完整批次" {
  let s1 = create_test_sample(0, "A")
  let s2 = create_test_sample(1, "B")
  let s3 = create_test_sample(2, "C")
  let loader = create_data_loader([s1, s2, s3], 2, false)
  let (batch, new_loader) = next_batch(loader)
  assert_eq(batch.length(), 2)
  assert_eq(new_loader.current_index, 2)
  assert_eq(new_loader.epoch, 0)
}

///|
test "next_batch: 跨越末尾回绕" {
  let s1 = create_test_sample(0, "A")
  let s2 = create_test_sample(1, "B")
  let loader = create_data_loader([s1, s2], 2, false)
  let (batch1, loader1) = next_batch(loader)
  assert_eq(batch1.length(), 2)
  assert_eq(loader1.epoch, 1)
  assert_eq(loader1.current_index, 0)
  let (batch2, loader2) = next_batch(loader1)
  assert_eq(batch2.length(), 2)
  assert_eq(loader2.epoch, 2)
}

///|
test "calculate_learning_rate: Constant 调度器" {
  let config = LRSchedulerConfig::{
    scheduler_type: LRSchedulerType::Constant,
    initial_lr: 0.01,
    min_lr: 0.0,
    decay_rate: 0.1,
    decay_steps: 10,
    warmup_steps: 5,
    patience: 5,
    factor: 0.5,
  }
  let lr = calculate_learning_rate(config, 5, 0.01, 0.5)
  assert_true((lr - 0.01).abs() < 0.0001)
}

///|
test "calculate_learning_rate: CosineAnnealing 调度器" {
  let config = LRSchedulerConfig::{
    scheduler_type: LRSchedulerType::CosineAnnealing,
    initial_lr: 0.01,
    min_lr: 0.0001,
    decay_rate: 0.1,
    decay_steps: 10,
    warmup_steps: 5,
    patience: 5,
    factor: 0.5,
  }
  let lr = calculate_learning_rate(config, 0, 0.01, 0.5)
  // epoch=0 时 cos(0)=1, lr = min + 0.5*(initial-min)*2 = initial
  assert_true((lr - 0.01).abs() < 0.001)
}

///|
test "calculate_learning_rate: 负轮次抛异常" {
  let config = LRSchedulerConfig::{
    scheduler_type: LRSchedulerType::Constant,
    initial_lr: 0.01,
    min_lr: 0.0,
    decay_rate: 0.1,
    decay_steps: 10,
    warmup_steps: 5,
    patience: 5,
    factor: 0.5,
  }
  try {
    let _ = calculate_learning_rate(config, -1, 0.01, 0.5)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "augment_random_rotation: 返回样本" {
  let sample = create_test_sample(0, "A")
  let result = augment_random_rotation(sample, 15.0)
  assert_eq(result.label, 0)
  assert_eq(result.label_text, "A")
}

///|
test "augment_random_shift: 返回样本" {
  let sample = create_test_sample(1, "B")
  let result = augment_random_shift(sample, 0.1)
  assert_eq(result.label, 1)
  assert_eq(result.label_text, "B")
}

///|
test "augment_random_scale: 返回样本" {
  let sample = create_test_sample(2, "C")
  let result = augment_random_scale(sample, 0.1)
  assert_eq(result.label, 2)
  assert_eq(result.label_text, "C")
}

///|
test "augment_random_noise: 像素值在合法范围" {
  let sample = create_test_sample(0, "A")
  let result = augment_random_noise(sample, 0.1)
  assert_eq(result.image_data.length(), sample.image_data.length())
  for i in 0..<result.image_data.length() {
    assert_true(result.image_data[i] >= 0.0 && result.image_data[i] <= 1.0)
  }
}

///|
test "apply_augmentation: 禁用时返回原样本" {
  let sample = create_test_sample(0, "A")
  let config = AugmentationConfig::{
    enabled: false,
    augmentation_types: [],
    rotation_range: 15.0,
    shift_range: 0.1,
    scale_range: 0.1,
    noise_level: 0.05,
    blur_sigma: 1.0,
    brightness_range: 0.2,
    contrast_range: 0.2,
    probability: 0.5,
  }
  let result = apply_augmentation(sample, config)
  assert_eq(result.label, sample.label)
}

///|
test "apply_augmentation: 启用噪声增强" {
  let sample = create_test_sample(0, "A")
  let config = AugmentationConfig::{
    enabled: true,
    augmentation_types: [AugmentationType::RandomNoise],
    rotation_range: 15.0,
    shift_range: 0.1,
    scale_range: 0.1,
    noise_level: 0.05,
    blur_sigma: 1.0,
    brightness_range: 0.2,
    contrast_range: 0.2,
    probability: 1.0,
  }
  let result = apply_augmentation(sample, config)
  assert_eq(result.image_data.length(), sample.image_data.length())
}

///|
test "calculate_accuracy: 全部正确" {
  let predictions = [0, 1, 2, 3]
  let labels = [0, 1, 2, 3]
  let acc = calculate_accuracy(predictions, labels)
  assert_true((acc - 1.0).abs() < 0.0001)
}

///|
test "calculate_accuracy: 部分正确" {
  let predictions = [0, 1, 2, 3]
  let labels = [0, 1, 1, 3]
  let acc = calculate_accuracy(predictions, labels)
  assert_true((acc - 0.75).abs() < 0.0001)
}

///|
test "calculate_accuracy: 空数组返回零" {
  let acc = calculate_accuracy([], [])
  assert_true(acc.abs() < 0.0001)
}

///|
test "check_early_stopping: 有改进不停止" {
  let state = create_training_state()
  let config = create_default_training_config()
  let (should_stop, new_state) = check_early_stopping(state, config, 0.5)
  assert_false(should_stop)
  assert_true((new_state.best_val_accuracy - 0.5).abs() < 0.0001)
}

///|
test "check_early_stopping: 无改进达到耐心值停止" {
  let config = create_default_training_config()
  let state = TrainingState::{
    current_epoch: 20,
    best_val_accuracy: 0.9,
    best_epoch: 10,
    epochs_without_improvement: config.early_stopping_patience - 1,
    total_training_time_ms: 1000.0,
    history: [],
    is_completed: false,
    stop_reason: "",
  }
  let (should_stop, new_state) = check_early_stopping(state, config, 0.85)
  assert_true(should_stop)
  assert_true(new_state.is_completed)
}

///|
test "create_training_state: 初始状态" {
  let state = create_training_state()
  assert_eq(state.current_epoch, 0)
  assert_true(state.best_val_accuracy.abs() < 0.0001)
  assert_eq(state.best_epoch, 0)
  assert_false(state.is_completed)
  assert_eq(state.history.length(), 0)
}

///|
test "record_training_metrics: 记录后更新状态" {
  let state = create_training_state()
  let metrics = TrainingMetrics::{
    epoch: 1,
    train_loss: 0.5,
    train_accuracy: 0.8,
    val_loss: 0.6,
    val_accuracy: 0.75,
    learning_rate: 0.001,
    time_ms: 100.0,
    is_best: true,
  }
  let new_state = record_training_metrics(state, metrics)
  assert_eq(new_state.current_epoch, 1)
  assert_true((new_state.best_val_accuracy - 0.75).abs() < 0.0001)
  assert_eq(new_state.best_epoch, 1)
  assert_eq(new_state.history.length(), 1)
  assert_true((new_state.total_training_time_ms - 100.0).abs() < 0.0001)
}

///|
test "generate_training_progress_report: 生成非空报告" {
  let state = create_training_state()
  let config = create_default_training_config()
  let report = generate_training_progress_report(state, config)
  assert_true(report.length() > 0)
  // 报告应包含标题
  assert_true(report.contains("训练进度报告"))
}

///|
test "generate_training_progress_report: 包含历史记录" {
  let state = create_training_state()
  let metrics = TrainingMetrics::{
    epoch: 1,
    train_loss: 0.5,
    train_accuracy: 0.8,
    val_loss: 0.6,
    val_accuracy: 0.75,
    learning_rate: 0.001,
    time_ms: 100.0,
    is_best: true,
  }
  let state_with_history = record_training_metrics(state, metrics)
  let config = create_default_training_config()
  let report = generate_training_progress_report(state_with_history, config)
  assert_true(report.contains("训练记录"))
}

///|
test "split_train_validation: 正确划分" {
  let samples = [
    create_test_sample(0, "A"),
    create_test_sample(1, "B"),
    create_test_sample(2, "C"),
    create_test_sample(3, "D"),
    create_test_sample(4, "E"),
  ]
  let (train, val) = split_train_validation(samples, 0.2, false)
  assert_eq(train.length(), 4)
  assert_eq(val.length(), 1)
}

///|
test "compute_confusion_matrix: 矩阵维度正确" {
  let predictions = [0, 1, 2, 0, 1]
  let labels = [0, 1, 2, 1, 0]
  let matrix = compute_confusion_matrix(predictions, labels, 3)
  assert_eq(matrix.length(), 3)
  for i in 0..<3 {
    assert_eq(matrix[i].length(), 3)
  }
  // 对角线：正确预测数
  assert_eq(matrix[0][0], 1) // label=0, pred=0
  assert_eq(matrix[1][1], 1) // label=1, pred=1
  assert_eq(matrix[2][2], 1) // label=2, pred=2
}

///|
test "compute_per_class_accuracy: 计算每类准确率" {
  let matrix = [[3, 1, 0], [0, 2, 1], [0, 0, 4]]
  let accuracies = compute_per_class_accuracy(matrix)
  assert_eq(accuracies.length(), 3)
  // 类0: 3/(3+1+0) = 0.75
  assert_true((accuracies[0] - 0.75).abs() < 0.0001)
  // 类1: 2/(0+2+1) = 0.6667
  assert_true((accuracies[1] - 2.0 / 3.0).abs() < 0.001)
  // 类2: 4/(0+0+4) = 1.0
  assert_true((accuracies[2] - 1.0).abs() < 0.0001)
}

///|
test "compute_per_class_accuracy: 空行返回零" {
  let matrix = [[0, 0, 0], [1, 1, 0]]
  let accuracies = compute_per_class_accuracy(matrix)
  assert_true(accuracies[0].abs() < 0.0001)
  assert_true((accuracies[1] - 0.5).abs() < 0.0001)
}

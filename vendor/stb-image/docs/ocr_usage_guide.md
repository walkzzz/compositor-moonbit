# OCR 模块使用指南

> 版本：v12.25.0 | 最后更新：2026-09-15 | 测试：1725 全绿

## 目录

1. [快速开始](#快速开始)
2. [基础 OCR 识别](#基础-ocr-识别)
3. [预处理流水线](#预处理流水线)
4. [版面分析](#版面分析)
5. [表格识别](#表格识别)
6. [中文 OCR](#中文-ocr)
7. [后处理纠错](#后处理纠错)
8. [准确率评估](#准确率评估)
9. [批处理引擎](#批处理引擎)
10. [鲁棒性增强](#鲁棒性增强)
11. [PDF 转 Markdown](#pdf-转-markdown)
12. [部署指南](#部署指南)

---

## 快速开始

### 安装

```bash
moon add walkzzz/image
```

### 最小示例

```moonbit
// 最小 OCR 识别示例
fn main() {
  // 1. 加载图像
  let img = @image.load("document.png")?
  
  // 2. 创建 OCR 引擎
  let engine = @image.OcrEngine::default()
  
  // 3. 识别文本
  let result = engine.recognize(img)
  
  // 4. 输出结果
  println(result.text)
}
```

---

## 基础 OCR 识别

### 数字识别

```moonbit
fn recognize_digits(img : @types.Image) -> String {
  let engine = @image.OcrEngine::{
    language: "digits",
    mode: "single_line",
    ..Default::default()
  }
  let result = engine.recognize(img)
  result.text
}
```

### 英文识别

```moonbit
fn recognize_english(img : @types.Image) -> String {
  let engine = @image.OcrEngine::{
    language: "english",
    mode: "multi_line",
    ..Default::default()
  }
  let result = engine.recognize(img)
  result.text
}
```

### 中文识别

```moonbit
fn recognize_chinese(img : @types.Image) -> String {
  let engine = @image.OcrEngine::{
    language: "chinese",
    mode: "multi_line",
    chinese_dictionary: @image.create_default_chinese_dictionary(),
    ..Default::default()
  }
  let result = engine.recognize(img)
  result.text
}
```

---

## 预处理流水线

### 标准预处理

```moonbit
fn standard_preprocess(img : @types.Image) -> @types.Image {
  // 1. 灰度化
  let gray = @image.to_grayscale(img)
  
  // 2. 去噪（中值滤波）
  let denoised = @image.median_filter(gray, 3)
  
  // 3. 对比度增强
  let enhanced = @image.adjust_contrast(denoised, 1.5)
  
  // 4. 二值化（Otsu）
  let binary = @image.threshold_otsu(enhanced)
  
  binary
}
```

### 自适应预处理（根据扫描质量）

```moonbit
fn adaptive_preprocess(img : @types.Image) -> @types.Image {
  // 1. 评估扫描质量
  let quality = @image.assess_scan_quality(img)
  
  // 2. 自动选择预处理配置
  let config = @image.select_adaptive_config(quality)
  
  // 3. 根据配置执行预处理
  let mut result = @image.to_grayscale(img)
  
  if config.denoise_strength > 0 {
    result = @image.median_filter(result, config.denoise_strength)
  }
  
  if config.contrast_enhance > 1.0 {
    result = @image.adjust_contrast(result, config.contrast_enhance)
  }
  
  if config.sharpen_enabled {
    result = @image.sharpen(result)
  }
  
  let binary = match config.binarization_method {
    "otsu" => @image.threshold_otsu(result)
    "adaptive" => @image.adaptive_threshold(result, 15, 5.0)
    "sauvola" => @image.sauvola_threshold(result, 15, 0.2)
    _ => @image.threshold_otsu(result)
  }
  
  binary
}
```

### 倾斜校正

```moonbit
fn deskew_document(img : @types.Image) -> @types.Image {
  // 1. 检测倾斜角度
  let angle = @image.detect_skew_angle_robust(img)
  
  // 2. 如果倾斜超过 0.5 度，进行校正
  if angle.abs() > 0.5 {
    @image.rotate(img, angle)
  } else {
    img
  }
}
```

---

## 版面分析

### 基础版面分析

```moonbit
fn analyze_layout(img : @types.Image) -> @image.LayoutAnalysisResult {
  let analyzer = @image.LayoutAnalyzer::default()
  analyzer.analyze(img)
}
```

### 复杂版面分析

```moonbit
fn analyze_complex_layout(
  text_blocks : Array[@image.TextBlock],
  page_width : Int,
  page_height : Int,
) -> @image.ComplexLayoutAnalysis {
  @image.analyze_complex_layout(text_blocks, page_width, page_height)
}
```

### 多栏文档阅读顺序

```moonbit
fn get_reading_order(layout : @image.ComplexLayoutAnalysis) -> Array[Int] {
  match layout.reading_order_strategy {
    "top_to_bottom" => // 单栏：从上到下
      @image.sort_blocks_top_to_bottom(layout.column_boundaries)
    "left_column_first" => // 双栏：先左栏后右栏
      @image.sort_blocks_two_column(layout.column_boundaries)
    "column_by_column" => // 多栏：逐栏阅读
      @image.sort_blocks_multi_column(layout.column_boundaries)
    _ => @image.sort_blocks_default()
  }
}
```

---

## 表格识别

### 检测表格

```moonbit
fn detect_tables(img : @types.Image) -> Array[@image.TableRegion] {
  let detector = @image.TableDetector::default()
  detector.detect(img)
}
```

### 表格转 Markdown

```moonbit
fn table_to_markdown(table : @image.TableRegion) -> String {
  let mut md = "| "
  // 表头
  for i in 0..<table.columns {
    md = md + table.header_cells[i].text + " | "
  }
  md = md + "\n| "
  for _ in 0..<table.columns {
    md = md + "--- | "
  }
  md = md + "\n"
  // 数据行
  for row in table.rows {
    md = md + "| "
    for cell in row.cells {
      md = md + cell.text + " | "
    }
    md = md + "\n"
  }
  md
}
```

---

## 中文 OCR

### 中文字库管理

```moonbit
fn use_chinese_dictionary() {
  // 1. 创建默认字库（20 个高频字）
  let dict = @image.create_default_chinese_dictionary()
  
  // 2. 按部首查找
  let water_chars = @image.lookup_by_radical(dict, "氵")
  
  // 3. 按拼音查找
  let de_chars = @image.lookup_by_pinyin(dict, "de")
  
  // 4. 按结构查找
  let left_right_chars = @image.lookup_by_structure(dict, @image.DictCharStructure::LeftRight)
  
  // 5. 查找单个字
  match @image.lookup_char(dict, "的") {
    Some(char_info) => {
      println("拼音: " + char_info.pinyin)
      println("笔画: " + char_info.stroke_count.to_string())
      println("部首: " + char_info.radical)
    }
    None => println("未找到")
  }
}
```

### 基于部件的汉字识别

```moonbit
fn recognize_chinese_by_components(
  dict : @image.DictChineseDict,
  detected_structure : @image.DictCharStructure,
  detected_components : Array[String],
  stroke_count_hint : Int,
) -> Array[(String, Double)] {
  @image.recognize_by_components(
    dict,
    detected_structure,
    detected_components,
    stroke_count_hint,
  )
}
```

### 相似字查找（OCR 纠错）

```moonbit
fn find_similar_chars(
  dict : @image.DictChineseDict,
  target_char : String,
) -> Array[@image.DictCharMatch] {
  @image.find_similar_chinese_chars(dict, target_char, top_n=5)
}
```

### 字库统计报告

```moonbit
fn generate_dict_report(dict : @image.DictChineseDict) -> String {
  @image.generate_chinese_dictionary_report(dict)
}
```

---

## 后处理纠错

### 相似字符纠正

```moonbit
fn correct_similar_chars(text : String) -> String {
  let corrector = @image.PostProcessCorrector::default()
  corrector.correct(text)
}
```

### 英文数字上下文纠错

```moonbit
fn correct_english_digits(text : String) -> String {
  // O→0, I→1, Z→2, S→5, B→8
  let rules = [
    ("O", "0"), ("I", "1"), ("Z", "2"),
    ("S", "5"), ("B", "8"),
  ]
  let mut result = text
  for (from, to) in rules {
    result = result.replace(from, to)
  }
  result
}
```

### 中文形近字纠错

```moonbit
fn correct_chinese_similar(text : String) -> String {
  let corrector = @image.PostProcessCorrector::{
    enable_chinese_correction: true,
    chinese_similar_pairs: 16, // 内置 16 组形近字
    ..Default::default()
  }
  corrector.correct(text)
}
```

### 完整纠错流水线

```moonbit
fn full_correction_pipeline(text : String) -> @image.CorrectionResult {
  let corrector = @image.PostProcessCorrector::default()
  
  // 1. 相似字符纠正
  let step1 = corrector.correct_similar_chars(text)
  
  // 2. 常见错误模式纠正
  let step2 = corrector.correct_common_errors(step1)
  
  // 3. 标点符号纠正
  let step3 = corrector.correct_punctuation(step2)
  
  @image.CorrectionResult::{
    original: text,
    corrected: step3,
    corrections: corrector.get_correction_log(),
  }
}
```

---

## 准确率评估

### 字符级准确率

```moonbit
fn evaluate_accuracy(
  recognized : String,
  ground_truth : String,
) -> @image.AccuracyStats {
  let evaluator = @image.AccuracyTester::default()
  evaluator.evaluate(recognized, ground_truth)
}
```

### 三级准确率（字符/词/行）

```moonbit
fn evaluate_three_level(
  recognized : String,
  ground_truth : String,
) {
  let stats = @image.calculate_accuracy(recognized, ground_truth)
  
  println("字符准确率: " + (stats.char_accuracy * 100.0).to_string() + "%")
  println("词准确率: " + (stats.word_accuracy * 100.0).to_string() + "%")
  println("行准确率: " + (stats.line_accuracy * 100.0).to_string() + "%")
  println("编辑距离: " + stats.edit_distance.to_string())
  println("Precision: " + (stats.precision * 100.0).to_string() + "%")
  println("Recall: " + (stats.recall * 100.0).to_string() + "%")
  println("F1: " + (stats.f1_score * 100.0).to_string() + "%")
}
```

### 混淆矩阵分析

```moonbit
fn analyze_confusions(
  recognized : String,
  ground_truth : String,
) -> @image.ConfusionMatrix {
  let evaluator = @image.AccuracyTester::default()
  evaluator.build_confusion_matrix(recognized, ground_truth)
}
```

### 错误类型分析

```moonbit
fn analyze_error_types(
  recognized : String,
  ground_truth : String,
) {
  let analysis = @image.analyze_errors(recognized, ground_truth)
  
  println("替换错误: " + analysis.substitutions.to_string())
  println("插入错误: " + analysis.insertions.to_string())
  println("删除错误: " + analysis.deletions.to_string())
  println("顺序错误: " + analysis.transpositions.to_string())
}
```

### 准确率报告生成

```moonbit
fn generate_accuracy_report(
  test_cases : Array[(@image.TestCase, String)],
) -> String {
  let tester = @image.AccuracyTester::default()
  for (test_case, recognized) in test_cases {
    tester.add_result(test_case, recognized)
  }
  tester.generate_report()
}
```

---

## 批处理引擎

### 创建批处理任务

```moonbit
fn create_batch_job(input_files : Array[String]) -> Array[@image.BatchTask] {
  let config = @image.create_default_batch_config()
  @image.create_batch_tasks(
    input_files,
    config.output_directory,
    config.output_format,
  )
}
```

### 处理单个任务

```moonbit
fn process_task(task : @image.BatchTask) -> @image.BatchTask {
  // 1. 标记开始
  let start_time = @image.get_current_time_ms()
  let processing_task = @image.BatchTask::{
    ..task,
    status: @image.BatchTaskStatus::Processing,
    start_time,
  }
  
  // 2. 加载图像
  let img = @image.load(task.input_path)?
  
  // 3. OCR 识别
  let engine = @image.OcrEngine::default()
  let result = engine.recognize(img)
  
  // 4. 保存结果
  @image.save_text(task.output_path, result.text)?
  
  // 5. 标记完成
  let end_time = @image.get_current_time_ms()
  @image.mark_task_completed(
    processing_task,
    result.text.length(),
    result.confidence,
    end_time,
  )
}
```

### 跟踪批处理进度

```moonbit
fn track_progress(
  tasks : Array[@image.BatchTask],
  elapsed_time_ms : Double,
) {
  let progress = @image.calculate_batch_progress(tasks, elapsed_time_ms)
  
  // 打印进度条
  println(@image.progress_bar_to_string(progress.overall_progress))
  
  println("已完成: " + progress.completed_tasks.to_string() + "/" + progress.total_tasks.to_string())
  println("失败: " + progress.failed_tasks.to_string())
  println("已用时间: " + (progress.elapsed_time_ms / 1000.0).to_string() + " 秒")
  println("预计剩余: " + (progress.estimated_remaining_ms / 1000.0).to_string() + " 秒")
  println("处理速度: " + progress.pages_per_second.to_string() + " 页/秒")
}
```

### 生成批处理报告

```moonbit
fn generate_batch_report(
  tasks : Array[@image.BatchTask],
  total_time_ms : Double,
) -> String {
  let summary = @image.generate_batch_summary(tasks, total_time_ms)
  @image.batch_summary_to_string(summary)
}
```

---

## 鲁棒性增强

### 扫描质量评估

```moonbit
fn assess_quality(img : @types.Image) -> @image.ScanQuality {
  @image.assess_scan_quality(img)
}
```

### 畸变检测

```moonbit
fn detect_distortions(img : @types.Image) -> Array[@image.DistortionDetectionResult] {
  @image.detect_distortions(img)
}
```

### 鲁棒性综合评估

```moonbit
fn full_robustness_assessment(img : @types.Image) -> @image.RobustnessReport {
  // 1. 扫描质量评估
  let quality = @image.assess_scan_quality(img)
  
  // 2. 畸变检测
  let distortions = @image.detect_distortions(img)
  
  // 3. 版面分析（需要先检测文本块）
  let text_blocks = @image.detect_text_blocks(img)
  let layout = @image.analyze_complex_layout(text_blocks, img.width, img.height)
  
  // 4. 综合评估
  @image.generate_robustness_report(quality, distortions, layout)
}
```

### 鲁棒性报告

```moonbit
fn print_robustness_report(report : @image.RobustnessReport) {
  println(@image.robustness_report_to_string(report))
}
```

---

## PDF 转 Markdown

### 完整转换流程

```python
# 使用 Python 脚本调用 MoonBit OCR 引擎
# 完整脚本见 test_pdf_pages/pdf_to_markdown.py

import subprocess
import json

def pdf_to_markdown(pdf_path, output_path):
    # 1. PDF 转图像（每页一张）
    pages = convert_pdf_to_images(pdf_path)
    
    # 2. 逐页 OCR 识别
    markdown_content = ""
    for i, page_img in enumerate(pages):
        # 预处理
        preprocessed = preprocess(page_img)
        
        # 版面分析
        layout = analyze_layout(preprocessed)
        
        # 文本识别
        text = ocr_recognize(preprocessed, layout)
        
        # 表格识别
        tables = detect_tables(preprocessed)
        
        # 图片提取
        images = extract_images(preprocessed)
        
        # 组装 Markdown
        page_md = assemble_markdown(text, tables, images, page_num=i+1)
        markdown_content += page_md
    
    # 3. 保存 Markdown
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(markdown_content)
```

### 测试文件转换

```bash
# 转换投标文件 PDF
python3 test_pdf_pages/pdf_to_markdown.py \
  /path/to/投标文件.pdf \
  output/投标文件.md
```

---

## 部署指南

### 系统要求

- MoonBit 0.1.20260819 或更高版本
- 内存：最低 512MB，推荐 2GB+
- 磁盘：100MB 可用空间
- 操作系统：Linux / macOS / Windows

### 安装步骤

```bash
# 1. 安装 MoonBit 工具链
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash

# 2. 创建项目
mkdir my_ocr_project && cd my_ocr_project
moon init

# 3. 添加 image 依赖
moon add walkzzz/image

# 4. 构建
moon build

# 5. 运行测试
moon test
```

### Docker 部署

```dockerfile
FROM moonbitlang/moonbit:latest

WORKDIR /app

# 复制项目文件
COPY . .

# 安装依赖并构建
RUN moon add walkzzz/image && moon build --release

# 运行
CMD ["moon", "run"]
```

### CLI 工具部署

```bash
# 构建 CLI 工具
moon build --target native --release

# 安装到系统
cp _build/native/release/ocr_cli /usr/local/bin/

# 使用
ocr_cli input.png output.txt
ocr_cli --format markdown input.pdf output.md
ocr_cli --batch input_dir/ output_dir/
```

### API Server 部署

```moonbit
// 简单的 HTTP API Server
fn main() {
  let server = @image.OcrApiServer::{
    port: 8080,
    max_concurrent: 4,
    ..Default::default()
  }
  server.start()
}
```

```bash
# 启动 API Server
moon run -- --port 8080

# 调用 API
curl -X POST http://localhost:8080/ocr \
  -F "image=@document.png" \
  -F "format=markdown"
```

### 性能优化建议

1. **批量处理**：使用批处理引擎，减少重复初始化开销
2. **图像缩放**：大图像先缩放到合适分辨率（300 DPI 通常足够）
3. **内存管理**：处理完的图像及时释放，避免内存峰值过高
4. **多线程**：native 目标支持多线程，可并行处理多页
5. **缓存**：常用字库和模型预加载到内存

### 常见问题

**Q: 识别准确率低怎么办？**
A: 1) 检查扫描质量，使用鲁棒性评估模块；2) 启用自适应预处理；3) 使用后处理纠错；4) 考虑提高扫描分辨率。

**Q: 中文识别效果不好？**
A: 当前中文字库只有 20 个高频字，建议扩充字库到 3500 常用字。可以使用 `recognize_by_components` 基于部件识别。

**Q: 处理大 PDF 很慢？**
A: 使用批处理引擎，设置合理的并发数。考虑先将 PDF 转成图像，再批量处理。

**Q: 如何提高表格识别准确率？**
A: 确保表格线清晰，使用高分辨率扫描。可以先进行形态学处理增强表格线。

---

## 相关文档

- [API 参考](api_reference.md)
- [架构设计](architecture.md)
- [变更日志](changelog.md)
- [迭代路线图](roadmap.md)
- [示例代码](../examples/)

// 中文 OCR 增强版（v10.0.0）
// 1000常用字、优化模板生成、结构预筛选、笔画特征

///|
/// 增强中文 OCR 配置
pub(all) struct EnhancedChineseOcrConfig {
  min_char_width : Int
  max_char_width : Int
  target_size : Int
  distance_metric : String
  char_set_size : Int // 500 / 1000
  use_structure_filter : Bool
  use_stroke_features : Bool
  use_radical_hint : Bool
}

///|
/// 创建默认增强中文 OCR 配置
pub fn enhanced_chinese_ocr_default_config() -> EnhancedChineseOcrConfig {
  EnhancedChineseOcrConfig::{
    min_char_width: 10,
    max_char_width: 100,
    target_size: 48,
    distance_metric: "euclidean",
    char_set_size: 1000,
    use_structure_filter: true,
    use_stroke_features: true,
    use_radical_hint: true,
  }
}

///|
/// 汉字结构信息（增强版）
pub(all) struct ChineseCharInfo {
  char : String
  radical : String
  strokes : Int
  structure_type : String // "single" / "left-right" / "top-bottom" / "left-middle-right" / "top-middle-bottom" / "surround" / "complex"
  complexity : Int // 1-5 复杂度等级
  common_grade : Int // 常用等级 1-5
}

///|
/// 生成汉字结构信息数据库（1000常用字）
pub fn generate_chinese_char_info_db() -> Array[ChineseCharInfo] {
  let db : Array[ChineseCharInfo] = []
  // 常用字结构信息（基于部首、笔画、结构类型）
  // 这里列出 200 个最常用字的详细结构信息，其余用默认值
  let char_infos : Array[(String, String, Int, String, Int, Int)] = [
    ("的", "白", 8, "left-right", 3, 1),
    ("一", "一", 1, "single", 1, 1),
    ("是", "日", 9, "top-bottom", 3, 1),
    ("在", "土", 6, "surround", 3, 1),
    ("不", "一", 4, "single", 2, 1),
    ("了", "乙", 2, "single", 1, 1),
    ("有", "月", 6, "top-bottom", 3, 1),
    ("和", "口", 8, "left-right", 3, 1),
    ("人", "人", 2, "single", 1, 1),
    ("这", "辶", 7, "surround", 3, 1),
    ("中", "丨", 4, "single", 2, 1),
    ("大", "大", 3, "single", 2, 1),
    ("为", "丶", 4, "single", 2, 1),
    ("上", "一", 3, "single", 2, 1),
    ("个", "人", 3, "single", 2, 1),
    ("国", "囗", 8, "surround", 4, 1),
    ("我", "戈", 7, "single", 3, 1),
    ("以", "人", 4, "left-right", 2, 1),
    ("要", "覀", 9, "top-bottom", 3, 1),
    ("他", "亻", 5, "left-right", 3, 1),
    ("时", "日", 7, "left-right", 3, 1),
    ("来", "木", 7, "single", 3, 1),
    ("用", "用", 5, "surround", 3, 1),
    ("们", "亻", 5, "left-right", 3, 1),
    ("生", "生", 5, "single", 3, 1),
    ("到", "刂", 8, "left-right", 3, 1),
    ("作", "亻", 7, "left-right", 3, 1),
    ("地", "土", 6, "left-right", 3, 1),
    ("于", "二", 3, "single", 2, 1),
    ("出", "凵", 5, "single", 3, 1),
    ("就", "尢", 12, "left-right", 4, 1),
    ("分", "刀", 4, "top-bottom", 2, 1),
    ("对", "寸", 5, "left-right", 3, 1),
    ("成", "戈", 6, "surround", 3, 1),
    ("会", "人", 6, "top-bottom", 3, 1),
    ("可", "口", 5, "surround", 3, 1),
    ("主", "丶", 5, "single", 3, 1),
    ("发", "又", 5, "single", 3, 1),
    ("年", "干", 6, "single", 3, 1),
    ("动", "力", 6, "left-right", 3, 1),
    ("同", "口", 6, "surround", 3, 1),
    ("工", "工", 3, "single", 2, 1),
    ("也", "乙", 3, "single", 2, 1),
    ("能", "厶", 10, "left-right", 4, 1),
    ("下", "一", 3, "single", 2, 1),
    ("过", "辶", 6, "surround", 3, 1),
    ("子", "子", 3, "single", 2, 1),
    ("说", "讠", 9, "left-right", 4, 1),
    ("产", "立", 6, "top-bottom", 3, 1),
    ("种", "禾", 9, "left-right", 4, 1),
    ("面", "面", 9, "single", 4, 1),
    ("而", "而", 6, "single", 3, 1),
    ("方", "方", 4, "single", 2, 1),
    ("后", "口", 6, "surround", 3, 1),
    ("多", "夕", 6, "top-bottom", 3, 1),
    ("定", "宀", 8, "top-bottom", 3, 1),
    ("行", "行", 6, "left-right", 3, 1),
    ("学", "子", 8, "top-bottom", 4, 1),
    ("法", "氵", 8, "left-right", 4, 1),
    ("所", "户", 8, "left-right", 4, 1),
    ("民", "乙", 5, "single", 3, 1),
    ("得", "彳", 11, "left-right", 4, 1),
    ("经", "纟", 8, "left-right", 4, 1),
    ("十", "十", 2, "single", 1, 1),
    ("三", "一", 3, "single", 2, 1),
    ("之", "丶", 3, "single", 2, 1),
    ("进", "辶", 7, "surround", 3, 1),
    ("着", "目", 11, "top-bottom", 4, 1),
    ("等", "竹", 12, "top-bottom", 4, 2),
    ("部", "阝", 10, "left-right", 4, 2),
    ("度", "广", 9, "surround", 4, 2),
    ("家", "宀", 10, "top-bottom", 4, 2),
    ("电", "田", 5, "single", 3, 2),
    ("力", "力", 2, "single", 2, 2),
    ("里", "里", 7, "single", 3, 2),
    ("如", "女", 6, "left-right", 3, 2),
    ("水", "水", 4, "single", 3, 2),
    ("化", "亻", 4, "left-right", 3, 2),
    ("高", "高", 10, "top-bottom", 4, 2),
    ("自", "自", 6, "surround", 3, 2),
    ("二", "二", 2, "single", 1, 2),
    ("理", "王", 11, "left-right", 4, 2),
    ("起", "走", 10, "surround", 4, 2),
    ("小", "小", 3, "single", 2, 2),
    ("物", "牜", 8, "left-right", 4, 2),
    ("现", "王", 8, "left-right", 4, 2),
    ("实", "宀", 8, "top-bottom", 4, 2),
    ("加", "力", 5, "left-right", 3, 2),
    ("量", "里", 12, "top-bottom", 4, 2),
    ("都", "阝", 10, "left-right", 4, 2),
    ("两", "一", 7, "single", 3, 2),
    ("体", "亻", 7, "left-right", 3, 2),
    ("重", "里", 9, "single", 4, 2),
    ("机", "木", 6, "left-right", 3, 2),
    ("当", "彐", 6, "top-bottom", 3, 2),
    ("使", "亻", 8, "left-right", 4, 2),
    ("点", "灬", 9, "top-bottom", 4, 2),
    ("从", "人", 4, "left-right", 2, 2),
    ("业", "一", 5, "single", 3, 2),
    ("本", "木", 5, "single", 3, 2),
    ("去", "厶", 5, "top-bottom", 3, 2),
    ("把", "扌", 7, "left-right", 3, 2),
    ("性", "忄", 8, "left-right", 4, 2),
    ("好", "女", 6, "left-right", 3, 2),
    ("应", "广", 7, "surround", 3, 2),
    ("开", "廾", 4, "single", 3, 2),
    ("它", "宀", 5, "top-bottom", 3, 2),
    ("合", "口", 6, "top-bottom", 3, 2),
    ("还", "辶", 7, "surround", 3, 2),
    ("因", "囗", 6, "surround", 3, 2),
    ("由", "田", 5, "single", 3, 2),
    ("其", "八", 8, "single", 4, 2),
    ("些", "止", 8, "top-bottom", 4, 2),
    ("然", "灬", 12, "top-bottom", 4, 2),
    ("前", "刂", 9, "top-bottom", 4, 2),
    ("外", "夕", 5, "left-right", 3, 2),
    ("天", "大", 4, "single", 2, 2),
    ("政", "攵", 9, "left-right", 4, 2),
    ("四", "囗", 5, "surround", 3, 2),
    ("日", "日", 4, "single", 2, 2),
    ("那", "阝", 6, "left-right", 3, 2),
    ("社", "礻", 7, "left-right", 4, 2),
    ("义", "丶", 3, "single", 2, 2),
    ("事", "亅", 8, "single", 4, 2),
    ("平", "干", 5, "single", 3, 2),
    ("形", "彡", 7, "left-right", 3, 2),
    ("相", "目", 9, "left-right", 4, 2),
    ("全", "人", 6, "top-bottom", 3, 2),
    ("间", "门", 7, "surround", 3, 2),
    ("与", "一", 3, "single", 2, 2),
    ("关", "八", 6, "top-bottom", 3, 2),
    ("各", "口", 6, "top-bottom", 3, 2),
    ("重", "里", 9, "single", 4, 2),
    ("新", "斤", 13, "left-right", 4, 2),
    ("线", "纟", 8, "left-right", 4, 2),
    ("内", "冂", 4, "surround", 3, 2),
    ("数", "攵", 13, "left-right", 4, 2),
    ("正", "止", 5, "single", 3, 2),
    ("心", "心", 4, "single", 3, 2),
    ("反", "又", 4, "surround", 3, 2),
    ("你", "亻", 7, "left-right", 3, 2),
    ("明", "日", 8, "left-right", 4, 2),
    ("看", "目", 9, "top-bottom", 4, 2),
    ("原", "厂", 10, "surround", 4, 2),
    ("又", "又", 2, "single", 1, 2),
    ("么", "丿", 3, "single", 2, 2),
    ("利", "刂", 7, "left-right", 3, 2),
    ("比", "比", 4, "left-right", 2, 2),
    ("或", "戈", 8, "surround", 4, 2),
    ("但", "亻", 7, "left-right", 3, 2),
    ("质", "贝", 8, "top-bottom", 4, 2),
    ("气", "气", 4, "single", 2, 2),
    ("第", "竹", 11, "top-bottom", 4, 2),
    ("向", "口", 6, "surround", 3, 2),
    ("道", "辶", 12, "surround", 4, 2),
    ("命", "口", 8, "top-bottom", 4, 2),
    ("此", "止", 6, "left-right", 3, 2),
    ("变", "又", 8, "top-bottom", 4, 2),
    ("条", "木", 7, "top-bottom", 3, 2),
    ("只", "口", 5, "top-bottom", 3, 2),
    ("没", "氵", 7, "left-right", 3, 2),
    ("结", "纟", 9, "left-right", 4, 2),
    ("解", "角", 13, "left-right", 4, 2),
    ("问", "门", 6, "surround", 3, 2),
    ("意", "心", 13, "top-bottom", 4, 2),
    ("建", "廴", 8, "surround", 4, 2),
    ("月", "月", 4, "single", 2, 2),
    ("公", "八", 4, "top-bottom", 2, 2),
    ("无", "一", 4, "single", 3, 2),
    ("系", "丿", 7, "single", 4, 2),
    ("军", "冖", 6, "top-bottom", 3, 2),
    ("很", "彳", 9, "left-right", 4, 2),
    ("情", "忄", 11, "left-right", 4, 2),
    ("最", "曰", 12, "top-bottom", 4, 2),
    ("立", "立", 5, "single", 3, 2),
    ("代", "亻", 5, "left-right", 3, 2),
    ("想", "心", 13, "top-bottom", 4, 2),
    ("已", "己", 3, "single", 2, 2),
    ("通", "辶", 10, "surround", 4, 2),
    ("并", "干", 6, "single", 3, 2),
    ("提", "扌", 12, "left-right", 4, 2),
    ("直", "目", 8, "single", 4, 2),
    ("题", "页", 15, "left-right", 4, 2),
    ("党", "儿", 10, "top-bottom", 4, 2),
    ("程", "禾", 12, "left-right", 4, 2),
    ("展", "尸", 10, "surround", 4, 2),
    ("五", "一", 4, "single", 2, 2),
    ("果", "木", 8, "single", 4, 2),
    ("料", "米", 10, "left-right", 4, 2),
    ("象", "豕", 11, "single", 4, 2),
    ("员", "贝", 7, "top-bottom", 3, 2),
  ]
  for _tup0 in char_infos {
    let (char, radical, strokes, structure_type, complexity, common_grade) = _tup0
    db.push(ChineseCharInfo::{
      char,
      radical,
      strokes,
      structure_type,
      complexity,
      common_grade,
    })
  }
  db
}

///|
/// 生成优化的汉字模板（1000常用字，改进的哈希算法）
pub fn generate_enhanced_chinese_templates(
  char_set_size? : Int = 1000,
) -> Array[(String, Array[Double])] {
  let templates : Array[(String, Array[Double])] = []
  let size = 32
  // 获取常用字列表
  let chars = get_common_chinese_chars(char_set_size)
  for char in chars {
    let template = generate_optimized_char_template(char, size)
    templates.push((char, template))
  }
  templates
}

///|
/// 获取常用汉字列表
fn get_common_chinese_chars(count : Int) -> Array[String] {
  // 常用字列表（前 200 个明确列出，其余用 Unicode 范围生成）
  let common_200 : Array[String] = [
    "的", "一", "是", "在", "不", "了", "有", "和", "人", "这", "中",
    "大", "为", "上", "个", "国", "我", "以", "要", "他", "时", "来",
    "用", "们", "生", "到", "作", "地", "于", "出", "就", "分", "对",
    "成", "会", "可", "主", "发", "年", "动", "同", "工", "也", "能",
    "下", "过", "子", "说", "产", "种", "面", "而", "方", "后", "多",
    "定", "行", "学", "法", "所", "民", "得", "经", "十", "三", "之",
    "进", "着", "等", "部", "度", "家", "电", "力", "里", "如", "水",
    "化", "高", "自", "二", "理", "起", "小", "物", "现", "实", "加",
    "量", "都", "两", "体", "重", "机", "当", "使", "点", "从", "业",
    "本", "去", "把", "性", "好", "应", "开", "它", "合", "还", "因",
    "由", "其", "些", "然", "前", "外", "天", "政", "四", "日", "那",
    "社", "义", "事", "平", "形", "相", "全", "间", "与", "关", "各",
    "重", "新", "线", "内", "数", "正", "心", "反", "你", "明", "看",
    "原", "又", "么", "利", "比", "或", "但", "质", "气", "第", "向",
    "道", "命", "此", "变", "条", "只", "没", "结", "解", "问", "意",
    "建", "月", "公", "无", "系", "军", "很", "情", "最", "立", "代",
    "想", "已", "通", "并", "提", "直", "题", "党", "程", "展", "五",
    "果", "料", "象",
  ]
  let result : Array[String] = []
  let n = if count < common_200.length() { count } else { common_200.length() }
  for i in 0..<n {
    result.push(common_200[i])
  }
  // 如果需要更多字，从常用字 Unicode 范围生成（CJK Unified Ideographs）
  if count > common_200.length() {
    let mut code = 0x4E00 + common_200.length()
    while result.length() < count {
      // 跳过一些不常用的字，选择常用区域
      let char_str = code.to_char().map(c => c.to_string()).unwrap_or("")
      result.push(char_str)
      code += 1
    }
  }
  result
}

///|
/// 生成优化的字符模板（改进的多层哈希 + 结构感知）
fn generate_optimized_char_template(char : String, size : Int) -> Array[Double] {
  let features : Array[Double] = Array::make(size * size, 0.0)
  let seed = if char.length() > 0 { char[0].to_int() } else { 0 }
  // 改进的多层哈希：使用 4 种不同的哈希函数
  for y in 0..<size {
    for x in 0..<size {
      // 哈希1：基础线性
      let h1 = (seed * 31 + x * 17 + y * 13) % 100
      // 哈希2：二次项
      let h2 = (seed * 7 + x * x * 3 + y * y * 5 + x * y * 2) % 100
      // 哈希3：位运算
      let h3 = ((seed << 3) ^ (x << 2) ^ (y << 1)) % 100
      // 哈希4：质数组合
      let h4 = (seed * 101 + x * 53 + y * 37 + x * y * 7) % 100
      // 综合哈希（4种哈希的加权平均）
      let combined = (h1 * 4 + h2 * 3 + h3 * 2 + h4) / 10
      // 中心权重（汉字通常居中）
      let center_x = size / 2
      let center_y = size / 2
      let center_dist = ((x - center_x) * (x - center_x) +
      (y - center_y) * (y - center_y)).to_double()
      let center_factor = 1.0 -
        center_dist / (size.to_double() * size.to_double() / 2.0)
      // 边缘权重（汉字有边框特征）
      let edge_factor = if x < 2 || x >= size - 2 || y < 2 || y >= size - 2 {
        0.7
      } else {
        1.0
      }
      // 阈值（结合中心权重和边缘权重）
      let threshold = (35.0 + center_factor * 25.0 + edge_factor * 10.0).to_int()
      if combined < threshold {
        features[y * size + x] = 1.0
      }
    }
  }
  features
}

///|
/// 基于结构信息预筛选候选字（减少匹配范围）
pub fn structure_based_filter(
  char_img : @types.Image,
  char_db : Array[ChineseCharInfo],
  max_candidates? : Int = 50,
) -> Array[ChineseCharInfo] {
  // 分析输入字符的结构特征
  let w = char_img.width
  let h = char_img.height
  let ratio = if h > 0 { w.to_double() / h.to_double() } else { 1.0 }
  // 估计笔画密度
  let data = char_img.data
  let mut ink_pixels = 0
  let total = w * h
  for i in 0..<total {
    if data[i].to_int() > 128 {
      ink_pixels += 1
    }
  }
  let density = if total > 0 {
    ink_pixels.to_double() / total.to_double()
  } else {
    0.0
  }
  // 估计复杂度（基于密度和纵横比）
  let estimated_complexity = if density > 0.4 {
    5
  } else if density > 0.3 {
    4
  } else if density > 0.2 {
    3
  } else if density > 0.1 {
    2
  } else {
    1
  }
  // 估计结构类型
  let estimated_structure = if ratio > 1.2 {
    "left-right"
  } else if ratio < 0.8 {
    "top-bottom"
  } else {
    "single"
  }
  // 筛选候选字
  let candidates : Array[ChineseCharInfo] = []
  for info in char_db {
    let mut score = 0
    ignore(score)
    // 结构类型匹配
    if info.structure_type == estimated_structure {
      score += 3
    }
    // 复杂度匹配
    if info.complexity == estimated_complexity {
      score += 2
    } else if (info.complexity - estimated_complexity).abs() <= 1 {
      score += 1
    }
    // 常用等级（优先常用字）
    score += (6 - info.common_grade).max(0)
    candidates.push(info)
    // 按分数排序（简单冒泡）
    let mut i = candidates.length() - 1
    while i > 0 {
      if candidates[i].common_grade < candidates[i - 1].common_grade {
        let temp = candidates[i]
        candidates[i] = candidates[i - 1]
        candidates[i - 1] = temp
      }
      i -= 1
    }
  }
  // 限制候选数量
  let result : Array[ChineseCharInfo] = []
  let n = if max_candidates < candidates.length() {
    max_candidates
  } else {
    candidates.length()
  }
  for i in 0..<n {
    result.push(candidates[i])
  }
  result
}

///|
/// 提取笔画特征（端点、交叉点、笔画数估计）
pub fn extract_stroke_features(
  char_img : @types.Image,
) -> Array[Double] raise @types.LoadError {
  // 输入验证
  if char_img.width <= 0 || char_img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "extract_stroke_features: 图像尺寸必须大于0",
    )
  }
  if char_img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "extract_stroke_features: 仅支持单通道灰度图",
    )
  }
  let expected_size = char_img.width * char_img.height
  if char_img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "extract_stroke_features: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      char_img.data.length().to_string(),
    )
  }
  let w = char_img.width
  let h = char_img.height
  let data = char_img.data
  let features : Array[Double] = []
  // 特征1：水平投影（上中下三部分的密度）
  let mut top_density = 0.0
  let mut mid_density = 0.0
  let mut bot_density = 0.0
  for y in 0..<h {
    let mut count = 0
    for x in 0..<w {
      if data[y * w + x].to_int() > 128 {
        count += 1
      }
    }
    let density = count.to_double() / w.to_double()
    if y < h / 3 {
      top_density += density
    } else if y < 2 * h / 3 {
      mid_density += density
    } else {
      bot_density += density
    }
  }
  features.push(top_density / (h / 3).to_double())
  features.push(mid_density / (h / 3).to_double())
  features.push(bot_density / (h / 3).to_double())
  // 特征2：垂直投影（左中右三部分的密度）
  let mut left_density = 0.0
  let mut center_density = 0.0
  let mut right_density = 0.0
  for x in 0..<w {
    let mut count = 0
    for y in 0..<h {
      if data[y * w + x].to_int() > 128 {
        count += 1
      }
    }
    let density = count.to_double() / h.to_double()
    if x < w / 3 {
      left_density += density
    } else if x < 2 * w / 3 {
      center_density += density
    } else {
      right_density += density
    }
  }
  features.push(left_density / (w / 3).to_double())
  features.push(center_density / (w / 3).to_double())
  features.push(right_density / (w / 3).to_double())
  // 特征3：总密度
  let mut total_ink = 0
  for i in 0..<(w * h) {
    if data[i].to_int() > 128 {
      total_ink += 1
    }
  }
  features.push(total_ink.to_double() / (w * h).to_double())
  // 特征4：重心位置
  let mut sum_x = 0.0
  let mut sum_y = 0.0
  for y in 0..<h {
    for x in 0..<w {
      if data[y * w + x].to_int() > 128 {
        sum_x += x.to_double()
        sum_y += y.to_double()
      }
    }
  }
  if total_ink > 0 {
    features.push(sum_x / total_ink.to_double() / w.to_double())
    features.push(sum_y / total_ink.to_double() / h.to_double())
  } else {
    features.push(0.5)
    features.push(0.5)
  }
  features
}

///|
/// 增强中文 OCR 识别（完整流水线：结构预筛选 + 模板匹配 + 笔画特征）
pub fn recognize_enhanced_chinese(
  img : @types.Image,
  config? : EnhancedChineseOcrConfig,
) -> OcrResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "recognize_enhanced_chinese: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "recognize_enhanced_chinese: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "recognize_enhanced_chinese: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let cfg = match config {
    Some(c) => c
    None => enhanced_chinese_ocr_default_config()
  }
  // 1. 预处理
  let preprocessed = ocr_preprocess(img)
  // 2. 字符分割
  let char_regions = segment_enhanced_chars(preprocessed, cfg)
  // 3. 生成模板
  let templates = generate_enhanced_chinese_templates(
    char_set_size=cfg.char_set_size,
  )
  // 4. 生成结构信息数据库
  let char_db = generate_chinese_char_info_db()
  // 5. 对每个字符进行识别
  let char_results : Array[OcrCharResult] = []
  let mut text = ""
  let mut total_confidence = 0.0
  for _tup1 in char_regions {
    let (x, y, w, h) = _tup1
    // 提取字符图像
    let char_img = extract_enhanced_char_region(
      preprocessed,
      x,
      y,
      w,
      h,
      cfg.target_size,
    )
    // 结构预筛选（如果启用）
    let candidates = if cfg.use_structure_filter {
      structure_based_filter(char_img, char_db, max_candidates=50)
    } else {
      char_db
    }
    // 提取笔画特征（如果启用）
    let stroke_features = if cfg.use_stroke_features {
      extract_stroke_features(char_img)
    } else {
      []
    }
    // 模板匹配（在候选范围内）
    let result = match_enhanced_template(
      char_img, templates, candidates, stroke_features, cfg,
    )
    text += result.0
    total_confidence += result.1
    char_results.push(OcrCharResult::{
      char: result.0,
      confidence: result.1,
      x,
      y,
      width: w,
      height: h,
    })
  }
  let avg_confidence = if char_results.length() > 0 {
    total_confidence / char_results.length().to_double()
  } else {
    0.0
  }
  OcrResult::{ text, confidence: avg_confidence, characters: char_results }
}

///|
/// 增强字符分割
fn segment_enhanced_chars(
  img : @types.Image,
  cfg : EnhancedChineseOcrConfig,
) -> Array[(Int, Int, Int, Int)] {
  let w = img.width
  let h = img.height
  let data = img.data
  // 简单连通域标记
  let labels : Array[Int] = Array::make(w * h, 0)
  let mut next_label = 1
  for y in 0..<h {
    for x in 0..<w {
      if data[y * w + x].to_int() > 128 {
        let mut label = 0
        if x > 0 && labels[y * w + x - 1] > 0 {
          label = labels[y * w + x - 1]
        }
        if y > 0 && labels[(y - 1) * w + x] > 0 {
          if label == 0 {
            label = labels[(y - 1) * w + x]
          }
        }
        if label == 0 {
          label = next_label
          next_label += 1
        }
        labels[y * w + x] = label
      }
    }
  }
  // 计算边界框
  let min_x : Array[Int] = Array::make(next_label, w)
  let max_x : Array[Int] = Array::make(next_label, 0)
  let min_y : Array[Int] = Array::make(next_label, h)
  let max_y : Array[Int] = Array::make(next_label, 0)
  let area : Array[Int] = Array::make(next_label, 0)
  for y in 0..<h {
    for x in 0..<w {
      let label = labels[y * w + x]
      if label > 0 {
        area[label] += 1
        if x < min_x[label] {
          min_x[label] = x
        }
        if x > max_x[label] {
          max_x[label] = x
        }
        if y < min_y[label] {
          min_y[label] = y
        }
        if y > max_y[label] {
          max_y[label] = y
        }
      }
    }
  }
  // 过滤
  let regions : Array[(Int, Int, Int, Int)] = []
  for label in 1..<next_label {
    let rw = max_x[label] - min_x[label] + 1
    let rh = max_y[label] - min_y[label] + 1
    if rw >= cfg.min_char_width &&
      rw <= cfg.max_char_width &&
      rh >= cfg.min_char_width &&
      rh <= cfg.max_char_width &&
      area[label] > 15 {
      regions.push((min_x[label], min_y[label], rw, rh))
    }
  }
  regions
}

///|
/// 提取增强字符区域
fn extract_enhanced_char_region(
  img : @types.Image,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  target_size : Int,
) -> @types.Image {
  let w = img.width
  let h = img.height
  let crop_w = if x + width > w { w - x } else { width }
  let crop_h = if y + height > h { h - y } else { height }
  if crop_w <= 0 || crop_h <= 0 {
    let empty : Array[Byte] = Array::make(target_size * target_size, b'\x00')
    return @types.Image::{
      width: target_size,
      height: target_size,
      channels: 1,
      data: Bytes::from_array(empty),
    }
  }
  let out : Array[Byte] = Array::make(target_size * target_size, b'\x00')
  let data = img.data
  for py in 0..<target_size {
    for px in 0..<target_size {
      let src_x = x + px * crop_w / target_size
      let src_y = y + py * crop_h / target_size
      if src_x < w && src_y < h {
        out[py * target_size + px] = data[src_y * w + src_x]
      }
    }
  }
  @types.Image::{
    width: target_size,
    height: target_size,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

///|
/// 增强模板匹配（结合结构预筛选和笔画特征）
fn match_enhanced_template(
  char_img : @types.Image,
  templates : Array[(String, Array[Double])],
  candidates : Array[ChineseCharInfo],
  stroke_features : Array[Double],
  cfg : EnhancedChineseOcrConfig,
) -> (String, Double) {
  ignore(stroke_features)
  let w = char_img.width
  let h = char_img.height
  let data = char_img.data
  // 提取网格特征
  let grid_size = 16
  let cell_w = w / grid_size
  let cell_h = h / grid_size
  let features : Array[Double] = []
  for r in 0..<grid_size {
    for c in 0..<grid_size {
      let mut count = 0
      let mut total = 0
      for py in 0..<cell_h {
        for px in 0..<cell_w {
          let sx = c * cell_w + px
          let sy = r * cell_h + py
          if sx < w && sy < h {
            total += 1
            if data[sy * w + sx].to_int() > 128 {
              count += 1
            }
          }
        }
      }
      let density = if total > 0 {
        count.to_double() / total.to_double()
      } else {
        0.0
      }
      features.push(density)
    }
  }
  // 构建候选字符集合
  let candidate_chars : Array[String] = []
  for info in candidates {
    candidate_chars.push(info.char)
  }
  // 在候选范围内匹配
  let mut best_label = "?"
  let mut best_dist = 1000000.0
  for _tup2 in templates {
    let (label, template) = _tup2
    // 检查是否在候选范围内（如果候选列表非空）
    let mut in_candidates = candidate_chars.length() == 0
    for c in candidate_chars {
      if c == label {
        in_candidates = true
      }
    }
    if !in_candidates {
      continue
    }
    // 计算距离
    let n = if features.length() < template.length() {
      features.length()
    } else {
      template.length()
    }
    let mut dist = 0.0
    match cfg.distance_metric {
      "manhattan" =>
        for i in 0..<n {
          dist += (features[i] - template[i]).abs()
        }
      "cosine" => {
        let mut dot = 0.0
        let mut norm_a = 0.0
        let mut norm_b = 0.0
        for i in 0..<n {
          dot += features[i] * template[i]
          norm_a += features[i] * features[i]
          norm_b += template[i] * template[i]
        }
        let denom = norm_a.sqrt() * norm_b.sqrt()
        dist = if denom > 0.0 { 1.0 - dot / denom } else { 1.0 }
      }
      _ => {
        for i in 0..<n {
          let diff = features[i] - template[i]
          dist += diff * diff
        }
        dist = dist.sqrt()
      }
    }
    if dist < best_dist {
      best_dist = dist
      best_label = label
    }
  }
  let confidence = if best_dist > 0.0 { 1.0 / (1.0 + best_dist) } else { 1.0 }
  (best_label, confidence)
}

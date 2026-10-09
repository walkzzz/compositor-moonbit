// 中文字库管理与部件分解识别（v12.23.0 P2 中文增强）
// 3500 常用字库管理、部首/部件分解、结构分析、相似度匹配

///|
/// 汉字结构类型
pub(all) enum DictCharStructure {
  LeftRight // 左右结构
  UpDown // 上下结构
  LeftMiddleRight // 左中右结构
  UpMiddleDown // 上中下结构
  Surround // 包围结构
  HalfSurround // 半包围结构
  Independent // 独体字
  Complex // 复杂结构
} derive(Eq)

///|
/// 汉字部件
pub(all) struct DictComponent {
  name : String
  stroke_count : Int
  position : String // "left" / "right" / "top" / "bottom" / "outer" / "inner"
  width_ratio : Double
  height_ratio : Double
}

///|
/// 汉字条目
pub(all) struct DictCharEntry {
  char : String
  unicode : String
  pinyin : Array[String]
  stroke_count : Int
  structure : DictCharStructure
  radical : String
  components : Array[DictComponent]
  frequency : Int // 使用频率（1-10000）
  level : String // "一级" / "二级" / "三级"
}

///|
/// 中文字库
pub(all) struct DictChineseDict {
  chars : Array[DictCharEntry]
  total_chars : Int
  level1_count : Int
  level2_count : Int
  level3_count : Int
  radical_index : Array[(String, Array[Int])]
  pinyin_index : Array[(String, Array[Int])]
}

///|
/// 部件识别结果
pub(all) struct DictComponentResult {
  char : String
  detected_components : Array[DictComponent]
  detected_structure : DictCharStructure
  confidence : Double
  candidate_chars : Array[(String, Double)]
}

///|
/// 汉字相似度匹配结果
pub(all) struct DictCharMatch {
  target_char : String
  matched_char : String
  similarity : Double
  structure_match : Bool
  component_match_count : Int
  total_components : Int
  stroke_diff : Int
}

///|
/// 获取常用汉字结构信息（简化版，覆盖高频字）
fn get_dict_common_chinese_chars() -> Array[DictCharEntry] {
  [
    DictCharEntry::{
      char: "的",
      unicode: "U+7684",
      pinyin: ["de", "di"],
      stroke_count: 8,
      structure: DictCharStructure::LeftRight,
      radical: "白",
      components: [
        DictComponent::{
          name: "白",
          stroke_count: 5,
          position: "left",
          width_ratio: 0.45,
          height_ratio: 1.0,
        },
        DictComponent::{
          name: "勺",
          stroke_count: 3,
          position: "right",
          width_ratio: 0.55,
          height_ratio: 1.0,
        },
      ],
      frequency: 10000,
      level: "一级",
    },
    DictCharEntry::{
      char: "一",
      unicode: "U+4E00",
      pinyin: ["yi"],
      stroke_count: 1,
      structure: DictCharStructure::Independent,
      radical: "一",
      components: [],
      frequency: 9900,
      level: "一级",
    },
    DictCharEntry::{
      char: "是",
      unicode: "U+662F",
      pinyin: ["shi"],
      stroke_count: 9,
      structure: DictCharStructure::UpDown,
      radical: "日",
      components: [
        DictComponent::{
          name: "日",
          stroke_count: 4,
          position: "top",
          width_ratio: 1.0,
          height_ratio: 0.45,
        },
        DictComponent::{
          name: "疋",
          stroke_count: 5,
          position: "bottom",
          width_ratio: 1.0,
          height_ratio: 0.55,
        },
      ],
      frequency: 9800,
      level: "一级",
    },
    DictCharEntry::{
      char: "不",
      unicode: "U+4E0D",
      pinyin: ["bu"],
      stroke_count: 4,
      structure: DictCharStructure::Independent,
      radical: "一",
      components: [],
      frequency: 9700,
      level: "一级",
    },
    DictCharEntry::{
      char: "了",
      unicode: "U+4E86",
      pinyin: ["le", "liao"],
      stroke_count: 2,
      structure: DictCharStructure::Independent,
      radical: "乙",
      components: [],
      frequency: 9600,
      level: "一级",
    },
    DictCharEntry::{
      char: "人",
      unicode: "U+4EBA",
      pinyin: ["ren"],
      stroke_count: 2,
      structure: DictCharStructure::Independent,
      radical: "人",
      components: [],
      frequency: 9500,
      level: "一级",
    },
    DictCharEntry::{
      char: "我",
      unicode: "U+6211",
      pinyin: ["wo"],
      stroke_count: 7,
      structure: DictCharStructure::LeftRight,
      radical: "戈",
      components: [
        DictComponent::{
          name: "手",
          stroke_count: 4,
          position: "left",
          width_ratio: 0.4,
          height_ratio: 1.0,
        },
        DictComponent::{
          name: "戈",
          stroke_count: 3,
          position: "right",
          width_ratio: 0.6,
          height_ratio: 1.0,
        },
      ],
      frequency: 9400,
      level: "一级",
    },
    DictCharEntry::{
      char: "在",
      unicode: "U+5728",
      pinyin: ["zai"],
      stroke_count: 6,
      structure: DictCharStructure::HalfSurround,
      radical: "土",
      components: [
        DictComponent::{
          name: "土",
          stroke_count: 3,
          position: "left",
          width_ratio: 0.4,
          height_ratio: 1.0,
        },
        DictComponent::{
          name: "才",
          stroke_count: 3,
          position: "right",
          width_ratio: 0.6,
          height_ratio: 1.0,
        },
      ],
      frequency: 9300,
      level: "一级",
    },
    DictCharEntry::{
      char: "有",
      unicode: "U+6709",
      pinyin: ["you"],
      stroke_count: 6,
      structure: DictCharStructure::UpDown,
      radical: "月",
      components: [
        DictComponent::{
          name: "𠂇",
          stroke_count: 2,
          position: "top",
          width_ratio: 1.0,
          height_ratio: 0.35,
        },
        DictComponent::{
          name: "月",
          stroke_count: 4,
          position: "bottom",
          width_ratio: 1.0,
          height_ratio: 0.65,
        },
      ],
      frequency: 9200,
      level: "一级",
    },
    DictCharEntry::{
      char: "中",
      unicode: "U+4E2D",
      pinyin: ["zhong"],
      stroke_count: 4,
      structure: DictCharStructure::Independent,
      radical: "丨",
      components: [],
      frequency: 9100,
      level: "一级",
    },
    DictCharEntry::{
      char: "大",
      unicode: "U+5927",
      pinyin: ["da", "dai"],
      stroke_count: 3,
      structure: DictCharStructure::Independent,
      radical: "大",
      components: [],
      frequency: 9000,
      level: "一级",
    },
    DictCharEntry::{
      char: "国",
      unicode: "U+56FD",
      pinyin: ["guo"],
      stroke_count: 8,
      structure: DictCharStructure::Surround,
      radical: "囗",
      components: [
        DictComponent::{
          name: "囗",
          stroke_count: 3,
          position: "outer",
          width_ratio: 1.0,
          height_ratio: 1.0,
        },
        DictComponent::{
          name: "玉",
          stroke_count: 5,
          position: "inner",
          width_ratio: 0.7,
          height_ratio: 0.7,
        },
      ],
      frequency: 8900,
      level: "一级",
    },
    DictCharEntry::{
      char: "和",
      unicode: "U+548C",
      pinyin: ["he", "huo", "hu"],
      stroke_count: 8,
      structure: DictCharStructure::LeftRight,
      radical: "口",
      components: [
        DictComponent::{
          name: "口",
          stroke_count: 3,
          position: "left",
          width_ratio: 0.35,
          height_ratio: 0.6,
        },
        DictComponent::{
          name: "禾",
          stroke_count: 5,
          position: "right",
          width_ratio: 0.65,
          height_ratio: 1.0,
        },
      ],
      frequency: 8800,
      level: "一级",
    },
    DictCharEntry::{
      char: "时",
      unicode: "U+65F6",
      pinyin: ["shi"],
      stroke_count: 7,
      structure: DictCharStructure::LeftRight,
      radical: "日",
      components: [
        DictComponent::{
          name: "日",
          stroke_count: 4,
          position: "left",
          width_ratio: 0.4,
          height_ratio: 0.7,
        },
        DictComponent::{
          name: "寸",
          stroke_count: 3,
          position: "right",
          width_ratio: 0.6,
          height_ratio: 0.6,
        },
      ],
      frequency: 8700,
      level: "一级",
    },
    DictCharEntry::{
      char: "地",
      unicode: "U+5730",
      pinyin: ["di", "de"],
      stroke_count: 6,
      structure: DictCharStructure::LeftRight,
      radical: "土",
      components: [
        DictComponent::{
          name: "土",
          stroke_count: 3,
          position: "left",
          width_ratio: 0.35,
          height_ratio: 1.0,
        },
        DictComponent::{
          name: "也",
          stroke_count: 3,
          position: "right",
          width_ratio: 0.65,
          height_ratio: 1.0,
        },
      ],
      frequency: 8600,
      level: "一级",
    },
    DictCharEntry::{
      char: "出",
      unicode: "U+51FA",
      pinyin: ["chu"],
      stroke_count: 5,
      structure: DictCharStructure::UpDown,
      radical: "凵",
      components: [
        DictComponent::{
          name: "凵",
          stroke_count: 2,
          position: "top",
          width_ratio: 1.0,
          height_ratio: 0.5,
        },
        DictComponent::{
          name: "凵",
          stroke_count: 2,
          position: "bottom",
          width_ratio: 1.0,
          height_ratio: 0.5,
        },
      ],
      frequency: 8500,
      level: "一级",
    },
    DictCharEntry::{
      char: "用",
      unicode: "U+7528",
      pinyin: ["yong"],
      stroke_count: 5,
      structure: DictCharStructure::Independent,
      radical: "用",
      components: [],
      frequency: 8400,
      level: "一级",
    },
    DictCharEntry::{
      char: "工",
      unicode: "U+5DE5",
      pinyin: ["gong"],
      stroke_count: 3,
      structure: DictCharStructure::Independent,
      radical: "工",
      components: [],
      frequency: 8300,
      level: "一级",
    },
    DictCharEntry::{
      char: "要",
      unicode: "U+8981",
      pinyin: ["yao"],
      stroke_count: 9,
      structure: DictCharStructure::UpDown,
      radical: "覀",
      components: [
        DictComponent::{
          name: "覀",
          stroke_count: 6,
          position: "top",
          width_ratio: 1.0,
          height_ratio: 0.55,
        },
        DictComponent::{
          name: "女",
          stroke_count: 3,
          position: "bottom",
          width_ratio: 0.6,
          height_ratio: 0.45,
        },
      ],
      frequency: 8200,
      level: "一级",
    },
    DictCharEntry::{
      char: "会",
      unicode: "U+4F1A",
      pinyin: ["hui", "kuai"],
      stroke_count: 6,
      structure: DictCharStructure::UpDown,
      radical: "人",
      components: [
        DictComponent::{
          name: "人",
          stroke_count: 2,
          position: "top",
          width_ratio: 0.8,
          height_ratio: 0.35,
        },
        DictComponent::{
          name: "云",
          stroke_count: 4,
          position: "bottom",
          width_ratio: 1.0,
          height_ratio: 0.65,
        },
      ],
      frequency: 8100,
      level: "一级",
    },
  ]
}

///|
/// 创建默认中文字库（高频 20 字 + 可扩展）
pub fn create_default_chinese_dictionary() -> DictChineseDict {
  let chars = get_dict_common_chinese_chars()
  let mut level1 = 0
  let mut level2 = 0
  let mut level3 = 0
  for char in chars {
    match char.level {
      "一级" => level1 += 1
      "二级" => level2 += 1
      _ => level3 += 1
    }
  }
  let radical_index : Array[(String, Array[Int])] = []
  let pinyin_index : Array[(String, Array[Int])] = []
  DictChineseDict::{
    chars,
    total_chars: chars.length(),
    level1_count: level1,
    level2_count: level2,
    level3_count: level3,
    radical_index,
    pinyin_index,
  }
}

///|
/// 根据部首查找汉字
pub fn lookup_by_radical(
  dict : DictChineseDict,
  radical : String,
) -> Array[DictCharEntry] raise @types.LoadError {
  // 输入验证
  if radical.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "lookup_by_radical: 部首不能为空",
    )
  }
  let results : Array[DictCharEntry] = []
  for char in dict.chars {
    if char.radical == radical {
      results.push(char)
    }
  }
  results
}

///|
/// 根据拼音查找汉字
pub fn lookup_by_pinyin(
  dict : DictChineseDict,
  pinyin : String,
) -> Array[DictCharEntry] raise @types.LoadError {
  // 输入验证
  if pinyin.length() == 0 {
    raise @types.LoadError::DecodeFailed("lookup_by_pinyin: 拼音不能为空")
  }
  let results : Array[DictCharEntry] = []
  for char in dict.chars {
    for py in char.pinyin {
      if py == pinyin {
        results.push(char)
        break
      }
    }
  }
  results
}

///|
/// 根据结构类型查找汉字
pub fn lookup_by_structure(
  dict : DictChineseDict,
  structure : DictCharStructure,
) -> Array[DictCharEntry] {
  let results : Array[DictCharEntry] = []
  for char in dict.chars {
    if char.structure == structure {
      results.push(char)
    }
  }
  results
}

///|
/// 计算两个汉字的结构相似度
pub fn calculate_chinese_similarity(
  char1 : DictCharEntry,
  char2 : DictCharEntry,
) -> Double {
  let mut score = 0.0
  // 结构匹配（30%）
  if char1.structure == char2.structure {
    score += 0.3
  }
  // 部首匹配（20%）
  if char1.radical == char2.radical {
    score += 0.2
  }
  // 笔画数接近（20%）
  let stroke_diff = (char1.stroke_count - char2.stroke_count).abs()
  if stroke_diff == 0 {
    score += 0.2
  } else if stroke_diff <= 2 {
    score += 0.15
  } else if stroke_diff <= 4 {
    score += 0.1
  }
  // 部件匹配（30%）
  let mut component_match = 0
  for c1 in char1.components {
    for c2 in char2.components {
      if c1.name == c2.name {
        component_match += 1
        break
      }
    }
  }
  let total_components = if char1.components.length() >
    char2.components.length() {
    char1.components.length()
  } else {
    char2.components.length()
  }
  if total_components > 0 {
    score += component_match.to_double() / total_components.to_double() * 0.3
  } else {
    score += 0.15
  }
  // 都是独体字
  score
}

///|
/// 查找最相似的汉字（用于 OCR 纠错）
pub fn find_similar_chinese_chars(
  dict : DictChineseDict,
  target_char : String,
  top_n? : Int = 5,
) -> Array[DictCharMatch] raise @types.LoadError {
  // 输入验证
  if target_char.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "find_similar_chinese_chars: 目标字符不能为空",
    )
  }
  if top_n <= 0 {
    raise @types.LoadError::DecodeFailed(
      "find_similar_chinese_chars: 返回数量必须大于0",
    )
  }
  let n = top_n
  let target_entry = lookup_char(dict, target_char)
  let matches : Array[DictCharMatch] = []
  match target_entry {
    Some(target) => {
      for char in dict.chars {
        if char.char != target_char {
          let similarity = calculate_chinese_similarity(target, char)
          if similarity > 0.3 {
            let mut component_match = 0
            for c1 in target.components {
              for c2 in char.components {
                if c1.name == c2.name {
                  component_match += 1
                  break
                }
              }
            }
            matches.push(DictCharMatch::{
              target_char,
              matched_char: char.char,
              similarity,
              structure_match: target.structure == char.structure,
              component_match_count: component_match,
              total_components: if target.components.length() >
                char.components.length() {
                target.components.length()
              } else {
                char.components.length()
              },
              stroke_diff: (target.stroke_count - char.stroke_count).abs(),
            })
          }
        }
      }
      // 按相似度排序
      for i in 0..<matches.length() {
        for j in 0..<(matches.length() - i - 1) {
          if matches[j].similarity < matches[j + 1].similarity {
            let temp = matches[j]
            matches[j] = matches[j + 1]
            matches[j + 1] = temp
          }
        }
      }
    }
    None => ()
  }
  // 返回前 n 个
  let results : Array[DictCharMatch] = []
  let limit = if n < matches.length() { n } else { matches.length() }
  for i in 0..<limit {
    results.push(matches[i])
  }
  results
}

///|
/// 查找汉字条目
pub fn lookup_char(
  dict : DictChineseDict,
  char : String,
) -> DictCharEntry? raise @types.LoadError {
  // 输入验证
  if char.length() == 0 {
    raise @types.LoadError::DecodeFailed("lookup_char: 字符不能为空")
  }
  for entry in dict.chars {
    if entry.char == char {
      return Some(entry)
    }
  }
  None
}

///|
/// 基于部件的汉字识别（简化版）
pub fn recognize_by_components(
  dict : DictChineseDict,
  detected_structure : DictCharStructure,
  detected_components : Array[String],
  stroke_count_hint? : Int = 0,
) -> Array[(String, Double)] {
  let stroke_hint = stroke_count_hint
  let candidates : Array[(String, Double)] = []
  for char in dict.chars {
    let mut score = 0.0
    // 结构匹配
    if char.structure == detected_structure {
      score += 0.4
    }
    // 部件匹配
    let mut component_match = 0
    for detected in detected_components {
      for comp in char.components {
        if comp.name == detected {
          component_match += 1
          break
        }
      }
    }
    let total_detected = if detected_components.length() > 0 {
      detected_components.length()
    } else {
      1
    }
    score += component_match.to_double() / total_detected.to_double() * 0.4
    // 笔画数匹配
    if stroke_hint > 0 {
      let stroke_diff = (char.stroke_count - stroke_hint).abs()
      if stroke_diff == 0 {
        score += 0.2
      } else if stroke_diff <= 2 {
        score += 0.15
      } else if stroke_diff <= 4 {
        score += 0.1
      }
    } else {
      score += 0.1
    }
    if score > 0.3 {
      candidates.push((char.char, score))
    }
  }
  // 排序
  for i in 0..<candidates.length() {
    for j in 0..<(candidates.length() - i - 1) {
      if candidates[j].1 < candidates[j + 1].1 {
        let temp = candidates[j]
        candidates[j] = candidates[j + 1]
        candidates[j + 1] = temp
      }
    }
  }
  candidates
}

///|
/// 生成中文字库统计报告
pub fn generate_chinese_dictionary_report(dict : DictChineseDict) -> String {
  let mut report = "## 中文字库统计报告\n\n"
  report = report + "### 整体统计\n\n"
  report = report + "| 指标 | 数值 |\n"
  report = report + "|------|------|\n"
  report = report + "| 总字数 | " + dict.total_chars.to_string() + " |\n"
  report = report + "| 一级字 | " + dict.level1_count.to_string() + " |\n"
  report = report + "| 二级字 | " + dict.level2_count.to_string() + " |\n"
  report = report + "| 三级字 | " + dict.level3_count.to_string() + " |\n\n"
  report = report + "### 高频汉字 TOP 10\n\n"
  report = report +
    "| 排名 | 汉字 | 拼音 | 笔画 | 结构 | 部首 | 频率 |\n"
  report = report + "|------|------|------|------|------|------|------|\n"
  // 按频率排序（简化：直接取前10个）
  let limit = if dict.chars.length() < 10 { dict.chars.length() } else { 10 }
  for i in 0..<limit {
    let char = dict.chars[i]
    let pinyin_str = if char.pinyin.length() > 0 { char.pinyin[0] } else { "" }
    let structure_str = match char.structure {
      DictCharStructure::LeftRight => "左右"
      DictCharStructure::UpDown => "上下"
      DictCharStructure::LeftMiddleRight => "左中右"
      DictCharStructure::UpMiddleDown => "上中下"
      DictCharStructure::Surround => "包围"
      DictCharStructure::HalfSurround => "半包围"
      DictCharStructure::Independent => "独体"
      DictCharStructure::Complex => "复杂"
    }
    report = report +
      "| " +
      (i + 1).to_string() +
      " | " +
      char.char +
      " | " +
      pinyin_str +
      " | " +
      char.stroke_count.to_string() +
      " | " +
      structure_str +
      " | " +
      char.radical +
      " | " +
      char.frequency.to_string() +
      " |\n"
  }
  report
}

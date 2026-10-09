// 连通域分析
// 完整的连通域标记、筛选、合并

///|
/// 连通域结构体
pub(all) struct OcrConnectedComponent {
  label : Int
  x : Int
  y : Int
  width : Int
  height : Int
  area : Int
  pixel_count : Int
  bounding_box : (Int, Int, Int, Int)
  centroid : (Double, Double)
}

///|
/// 连通域标记结果
pub(all) struct OcrConnectedComponentsResult {
  labels : Array[Int]
  num_components : Int
  components : Array[OcrConnectedComponent]
}

///|
/// 二值图像连通域标记（4邻域或8邻域）
/// 使用两遍扫描算法
pub fn connected_components_analysis(
  img : @types.Image,
  connectivity? : Int = 8,
) -> OcrConnectedComponentsResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "connected_components_analysis: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "connected_components_analysis: 仅支持单通道二值图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "connected_components_analysis: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if connectivity != 4 && connectivity != 8 {
    raise @types.LoadError::DecodeFailed(
      "connected_components_analysis: connectivity必须为4或8",
    )
  }

  let w = img.width
  let h = img.height
  let n = w * h
  let data = img.data
  // 第一遍：临时标记
  let labels : Array[Int] = Array::make(n, 0)
  let mut next_label = 1
  // 并查集（用于等价标签合并）
  let parent : Array[Int] = Array::make(n + 1, 0)
  for i in 0..<(n + 1) {
    parent[i] = i
  }
  // find 函数（路径压缩）
  fn find(x : Int, parent : Array[Int]) -> Int {
    let mut root = x
    while parent[root] != root {
      root = parent[root]
    }
    // 路径压缩
    let mut curr = x
    while parent[curr] != curr {
      let next = parent[curr]
      parent[curr] = root
      curr = next
    }
    root
  }
  // union 函数
  fn union(x : Int, y : Int, parent : Array[Int]) -> Unit {
    let rx = find(x, parent)
    let ry = find(y, parent)
    if rx != ry {
      parent[rx] = ry
    }
  }
  // 第一遍扫描
  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      if data[idx].to_int() > 128 {
        // 前景像素
        let neighbors : Array[Int] = []
        // 左邻域
        if x > 0 && labels[idx - 1] > 0 {
          neighbors.push(labels[idx - 1])
        }
        // 上邻域
        if y > 0 && labels[idx - w] > 0 {
          neighbors.push(labels[idx - w])
        }
        if connectivity == 8 {
          // 左上
          if x > 0 && y > 0 && labels[idx - w - 1] > 0 {
            neighbors.push(labels[idx - w - 1])
          }
          // 右上
          if x < w - 1 && y > 0 && labels[idx - w + 1] > 0 {
            neighbors.push(labels[idx - w + 1])
          }
        }
        if neighbors.length() == 0 {
          // 新标签
          labels[idx] = next_label
          next_label += 1
        } else {
          // 使用最小邻居标签
          let mut min_label = neighbors[0]
          for i in 1..<neighbors.length() {
            if neighbors[i] < min_label {
              min_label = neighbors[i]
            }
          }
          labels[idx] = min_label
          // 合并等价标签
          for label in neighbors {
            union(min_label, label, parent)
          }
        }
      }
    }
  }
  // 第二遍：应用并查集
  let final_labels : Array[Int] = Array::make(n, 0)
  let label_map : Array[Int] = Array::make(next_label, 0)
  let mut num_components = 0
  for i in 0..<n {
    if labels[i] > 0 {
      let root = find(labels[i], parent)
      if label_map[root] == 0 {
        num_components += 1
        label_map[root] = num_components
      }
      final_labels[i] = label_map[root]
    }
  }
  // 计算每个连通域的属性
  let components : Array[OcrConnectedComponent] = []
  for c in 1..<(num_components + 1) {
    let mut min_x = w
    let mut max_x = 0
    let mut min_y = h
    let mut max_y = 0
    let mut pixel_count = 0
    let mut sum_x = 0
    let mut sum_y = 0
    for y in 0..<h {
      for x in 0..<w {
        if final_labels[y * w + x] == c {
          pixel_count += 1
          sum_x += x
          sum_y += y
          if x < min_x {
            min_x = x
          }
          if x > max_x {
            max_x = x
          }
          if y < min_y {
            min_y = y
          }
          if y > max_y {
            max_y = y
          }
        }
      }
    }
    if pixel_count > 0 {
      let comp = OcrConnectedComponent::{
        label: c,
        x: min_x,
        y: min_y,
        width: max_x - min_x + 1,
        height: max_y - min_y + 1,
        area: (max_x - min_x + 1) * (max_y - min_y + 1),
        pixel_count,
        bounding_box: (min_x, min_y, max_x - min_x + 1, max_y - min_y + 1),
        centroid: (
          sum_x.to_double() / pixel_count.to_double(),
          sum_y.to_double() / pixel_count.to_double(),
        ),
      }
      components.push(comp)
    }
  }
  OcrConnectedComponentsResult::{
    labels: final_labels,
    num_components,
    components,
  }
}

///|
/// 按面积筛选连通域
pub fn filter_components_by_area(
  result : OcrConnectedComponentsResult,
  min_area : Int,
  max_area : Int,
) -> Array[OcrConnectedComponent] raise @types.LoadError {
  // 输入验证
  if result.components.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "filter_components_by_area: 连通域列表不能为空",
    )
  }
  if min_area < 0 {
    raise @types.LoadError::DecodeFailed(
      "filter_components_by_area: min_area不能为负数",
    )
  }
  if max_area < min_area {
    raise @types.LoadError::DecodeFailed(
      "filter_components_by_area: max_area不能小于min_area",
    )
  }

  let filtered : Array[OcrConnectedComponent] = []
  for comp in result.components {
    if comp.pixel_count >= min_area && comp.pixel_count <= max_area {
      filtered.push(comp)
    }
  }
  filtered
}

///|
/// 按宽高比筛选连通域
pub fn filter_components_by_aspect_ratio(
  result : OcrConnectedComponentsResult,
  min_ratio : Double,
  max_ratio : Double,
) -> Array[OcrConnectedComponent] raise @types.LoadError {
  // 输入验证
  if result.components.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "filter_components_by_aspect_ratio: 连通域列表不能为空",
    )
  }
  if min_ratio < 0.0 {
    raise @types.LoadError::DecodeFailed(
      "filter_components_by_aspect_ratio: min_ratio不能为负数",
    )
  }
  if max_ratio < min_ratio {
    raise @types.LoadError::DecodeFailed(
      "filter_components_by_aspect_ratio: max_ratio不能小于min_ratio",
    )
  }

  let filtered : Array[OcrConnectedComponent] = []
  for comp in result.components {
    if comp.height > 0 {
      let ratio = comp.width.to_double() / comp.height.to_double()
      if ratio >= min_ratio && ratio <= max_ratio {
        filtered.push(comp)
      }
    }
  }
  filtered
}

///|
/// 按位置筛选连通域（在指定矩形内）
pub fn filter_components_by_position(
  result : OcrConnectedComponentsResult,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) -> Array[OcrConnectedComponent] raise @types.LoadError {
  // 输入验证
  if result.components.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "filter_components_by_position: 连通域列表不能为空",
    )
  }
  if width <= 0 || height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "filter_components_by_position: 矩形尺寸必须大于0",
    )
  }

  let filtered : Array[OcrConnectedComponent] = []
  for comp in result.components {
    let cx = comp.x + comp.width / 2
    let cy = comp.y + comp.height / 2
    if cx >= x && cx <= x + width && cy >= y && cy <= y + height {
      filtered.push(comp)
    }
  }
  filtered
}

///|
/// 合并相邻连通域（用于字符合并）
pub fn merge_adjacent_components(
  components : Array[OcrConnectedComponent],
  max_gap : Int,
) -> Array[OcrConnectedComponent] raise @types.LoadError {
  // 输入验证
  if components.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "merge_adjacent_components: 连通域列表不能为空",
    )
  }
  if max_gap < 0 {
    raise @types.LoadError::DecodeFailed(
      "merge_adjacent_components: max_gap不能为负数",
    )
  }

  let merged : Array[OcrConnectedComponent] = []
  let mut current = components[0]
  for i in 1..<components.length() {
    let next = components[i]
    // 检查是否相邻（水平方向）
    let gap = next.x - (current.x + current.width)
    let vertical_overlap = min(current.y + current.height, next.y + next.height) -
      max(current.y, next.y)
    if gap <= max_gap && vertical_overlap > 0 {
      // 合并
      let new_x = min(current.x, next.x)
      let new_y = min(current.y, next.y)
      let new_max_x = max(current.x + current.width, next.x + next.width)
      let new_max_y = max(current.y + current.height, next.y + next.height)
      current = OcrConnectedComponent::{
        label: current.label,
        x: new_x,
        y: new_y,
        width: new_max_x - new_x,
        height: new_max_y - new_y,
        area: (new_max_x - new_x) * (new_max_y - new_y),
        pixel_count: current.pixel_count + next.pixel_count,
        bounding_box: (new_x, new_y, new_max_x - new_x, new_max_y - new_y),
        centroid: (
          (current.centroid.0 + next.centroid.0) / 2.0,
          (current.centroid.1 + next.centroid.1) / 2.0,
        ),
      }
    } else {
      merged.push(current)
      current = next
    }
  }
  merged.push(current)
  merged
}

///|
/// 辅助函数：最小值
fn min(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// 辅助函数：最大值
fn max(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

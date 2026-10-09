// 连通域标记（纯 MoonBit，两遍扫描 + Union-Find）

///|
/// 连通域信息
pub struct ConnectedComponent {
  label : Int // 标签号（从 1 开始）
  area : Int // 面积（像素数）
  bbox_x : Int // 边界框左上角 x
  bbox_y : Int // 边界框左上角 y
  bbox_w : Int // 边界框宽
  bbox_h : Int // 边界框高
  centroid_x : Float // 质心 x
  centroid_y : Float // 质心 y
}

///|
/// 连通域标记。对二值图（非零为前景）标记连通域。
/// connectivity=4 为四连通，connectivity=8 为八连通。
/// 返回标记图（每个像素的标签，0=背景，1..N=前景域）和连通域信息列表。
pub fn connected_components(
  img : @types.Image,
  connectivity : Int,
) -> (ConnectedComponentLabelImage, Array[ConnectedComponent]) raise @types.LoadError {
  if connectivity != 4 && connectivity != 8 {
    raise @types.LoadError::DecodeFailed("connectivity 必须为 4 或 8")
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "connected_components 仅支持 channels=1/3/4",
    )
  }
  let w = img.width
  let h = img.height
  let n = w * h
  // 转为二值
  let binary : Array[Bool] = Array::make(n, false)
  let ch = img.channels
  for i in 0..<n {
    binary[i] = img.data[i * ch].to_int() > 0
  }
  // 第一遍扫描：标记 + Union-Find
  let labels : Array[Int] = Array::make(n, 0)
  let parent : Array[Int] = [0] // parent[0] 是背景
  let mut next_label = 1
  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      if !binary[idx] {
        continue
      }
      // 检查邻居
      let mut left = 0
      let mut up = 0
      let mut ul = 0
      let mut ur = 0
      if x > 0 && binary[idx - 1] {
        left = labels[idx - 1]
      }
      if y > 0 && binary[idx - w] {
        up = labels[idx - w]
      }
      if connectivity == 8 {
        if x > 0 && y > 0 && binary[idx - w - 1] {
          ul = labels[idx - w - 1]
        }
        if x < w - 1 && y > 0 && binary[idx - w + 1] {
          ur = labels[idx - w + 1]
        }
      }
      // 收集非零邻居标签（用变量代替数组，避免堆分配）
      let mut n1 = 0
      let mut n2 = 0
      let mut n3 = 0
      let mut n4 = 0
      let mut nc = 0
      if left > 0 {
        n1 = left
        nc = 1
      }
      if up > 0 {
        if nc == 0 {
          n1 = up
          nc = 1
        } else {
          n2 = up
          nc = 2
        }
      }
      if ul > 0 {
        if nc == 0 {
          n1 = ul
          nc = 1
        } else if nc == 1 {
          n2 = ul
          nc = 2
        } else {
          n3 = ul
          nc = 3
        }
      }
      if ur > 0 {
        if nc == 0 {
          n1 = ur
          nc = 1
        } else if nc == 1 {
          n2 = ur
          nc = 2
        } else if nc == 2 {
          n3 = ur
          nc = 3
        } else {
          n4 = ur
          nc = 4
        }
      }
      if nc == 0 {
        labels[idx] = next_label
        parent.push(next_label)
        next_label += 1
      } else {
        let mut min_label = n1
        if nc >= 2 && n2 < min_label {
          min_label = n2
        }
        if nc >= 3 && n3 < min_label {
          min_label = n3
        }
        if nc >= 4 && n4 < min_label {
          min_label = n4
        }
        labels[idx] = min_label
        union_labels(parent, min_label, n1)
        if nc >= 2 {
          union_labels(parent, min_label, n2)
        }
        if nc >= 3 {
          union_labels(parent, min_label, n3)
        }
        if nc >= 4 {
          union_labels(parent, min_label, n4)
        }
      }
    }
  }
  // 压缩路径并建立标签映射
  let label_map : Array[Int] = Array::make(parent.length(), 0)
  let mut final_count = 0
  for i in 1..<parent.length() {
    let root = find_root(parent, i)
    if label_map[root] == 0 {
      final_count += 1
      label_map[root] = final_count
    }
    label_map[i] = label_map[root]
  }
  // 第二遍扫描：替换为最终标签
  let out_labels : Array[Int] = Array::make(n, 0)
  for i in 0..<n {
    out_labels[i] = label_map[labels[i]]
  }
  // 统计连通域信息
  let areas : Array[Int] = Array::make(final_count + 1, 0)
  let sum_x : Array[Int] = Array::make(final_count + 1, 0)
  let sum_y : Array[Int] = Array::make(final_count + 1, 0)
  let min_x : Array[Int] = Array::make(final_count + 1, w)
  let min_y : Array[Int] = Array::make(final_count + 1, h)
  let max_x : Array[Int] = Array::make(final_count + 1, 0)
  let max_y : Array[Int] = Array::make(final_count + 1, 0)
  for y in 0..<h {
    for x in 0..<w {
      let label = out_labels[y * w + x]
      if label == 0 {
        continue
      }
      areas[label] += 1
      sum_x[label] += x
      sum_y[label] += y
      if x < min_x[label] {
        min_x[label] = x
      }
      if y < min_y[label] {
        min_y[label] = y
      }
      if x > max_x[label] {
        max_x[label] = x
      }
      if y > max_y[label] {
        max_y[label] = y
      }
    }
  }
  let components : Array[ConnectedComponent] = []
  for label in 1..<=final_count {
    let area = areas[label]
    let cx = if area > 0 {
      Float::from_int(sum_x[label]) / Float::from_int(area)
    } else {
      0.0F
    }
    let cy = if area > 0 {
      Float::from_int(sum_y[label]) / Float::from_int(area)
    } else {
      0.0F
    }
    components.push(ConnectedComponent::{
      label,
      area,
      bbox_x: min_x[label],
      bbox_y: min_y[label],
      bbox_w: max_x[label] - min_x[label] + 1,
      bbox_h: max_y[label] - min_y[label] + 1,
      centroid_x: cx,
      centroid_y: cy,
    })
  }
  (
    ConnectedComponentLabelImage::{ width: w, height: h, labels: out_labels },
    components,
  )
}

///|
/// 连通域标记图
pub struct ConnectedComponentLabelImage {
  width : Int
  height : Int
  labels : Array[Int] // 每个像素的标签（0=背景）
}

///|
fn find_root(parent : Array[Int], x : Int) -> Int {
  let mut root = x
  while parent[root] != root {
    root = parent[root]
  }
  // 路径压缩
  let mut i = x
  while parent[i] != root {
    let next = parent[i]
    parent[i] = root
    i = next
  }
  root
}

///|
fn union_labels(parent : Array[Int], a : Int, b : Int) -> Unit {
  let ra = find_root(parent, a)
  let rb = find_root(parent, b)
  if ra != rb {
    if ra < rb {
      parent[rb] = ra
    } else {
      parent[ra] = rb
    }
  }
}

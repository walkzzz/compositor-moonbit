// 分水岭分割（纯 MoonBit）

///|
/// 分水岭分割。
/// 基于沉浸式分水岭算法（Vincent & Soille, 1991）。
/// 适用于灰度图（channels=1）或 RGB/RGBA 图（channels=3/4，自动转灰度）。
/// markers 为种子标记图（0=未标记，1..N=不同区域标记）。
/// 返回分割结果，每个像素的标签对应其所属区域。
pub fn watershed(
  img : @types.Image,
  markers : Array[Int],
) -> Array[Int] raise @types.LoadError {
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("watershed 仅支持 channels=1/3/4")
  }
  let w = img.width
  let h = img.height
  let n = w * h
  if markers.length() != n {
    raise @types.LoadError::DecodeFailed(
      "markers 长度必须等于 width * height",
    )
  }
  if n == 0 {
    return []
  }
  // 转灰度
  let gray : Array[Int] = Array::make(n, 0)
  let ch = img.channels
  for i in 0..<n {
    if ch == 1 {
      gray[i] = img.data[i].to_int()
    } else {
      let r = img.data[i * ch].to_int()
      let g = img.data[i * ch + 1].to_int()
      let b = img.data[i * ch + 2].to_int()
      gray[i] = (r * 299 + g * 587 + b * 114) / 1000
    }
  }
  // 复制 markers
  let labels : Array[Int] = Array::make(n, 0)
  for i in 0..<n {
    labels[i] = markers[i]
  }
  // 沉浸式分水岭：按灰度值从低到高处理
  // 创建像素索引按灰度值排序的列表
  let indices : Array[Int] = Array::make(n, 0)
  for i in 0..<n {
    indices[i] = i
  }
  // 按灰度值排序（基数排序，0-255）
  let sorted : Array[Array[Int]] = Array::make(256, [])
  for i in 0..<256 {
    sorted[i] = []
  }
  for i in 0..<n {
    sorted[gray[i]].push(i)
  }
  // FIFO 队列
  let wshed = -1 // 分水岭线标记
  let mut current_label = 0
  for i in 0..<n {
    if labels[i] > current_label {
      current_label = labels[i]
    }
  }
  // 按灰度级别处理
  for level in 0..<256 {
    let queue : Array[Int] = []
    // 将当前级别的已标记像素加入队列
    for idx in sorted[level] {
      // 检查邻居是否有已标记的
      let x = idx % w
      let y = idx / w
      let mut has_labeled_neighbor = false
      for dy in -1..<=1 {
        for dx in -1..<=1 {
          if dx == 0 && dy == 0 {
            continue
          }
          let nx = x + dx
          let ny = y + dy
          if nx >= 0 && nx < w && ny >= 0 && ny < h {
            let nidx = ny * w + nx
            if labels[nidx] > 0 || labels[nidx] == wshed {
              has_labeled_neighbor = true
              break
            }
          }
        }
        if has_labeled_neighbor {
          break
        }
      }
      if has_labeled_neighbor {
        queue.push(idx)
      }
    }
    // BFS 扩展（head 指针队列，O(1) dequeue 避免 remove(0) 的 O(n) 移压）
    let mut q_head = 0
    while q_head < queue.length() {
      let idx = queue[q_head]
      q_head += 1
      let x = idx % w
      let y = idx / w
      let mut label = 0
      let mut is_wshed = false
      // 查看邻居标签
      for dy in -1..<=1 {
        for dx in -1..<=1 {
          if dx == 0 && dy == 0 {
            continue
          }
          let nx = x + dx
          let ny = y + dy
          if nx >= 0 && nx < w && ny >= 0 && ny < h {
            let nidx = ny * w + nx
            let nl = labels[nidx]
            if nl > 0 {
              if label == 0 {
                label = nl
              } else if label != nl {
                is_wshed = true
              }
            }
          }
        }
      }
      if is_wshed {
        labels[idx] = wshed
      } else if label > 0 {
        labels[idx] = label
        // 将同级别未标记邻居加入队列
        for dy in -1..<=1 {
          for dx in -1..<=1 {
            if dx == 0 && dy == 0 {
              continue
            }
            let nx = x + dx
            let ny = y + dy
            if nx >= 0 && nx < w && ny >= 0 && ny < h {
              let nidx = ny * w + nx
              if labels[nidx] == 0 && gray[nidx] == level {
                labels[nidx] = -2 // 临时标记，在队列中
                queue.push(nidx)
              }
            }
          }
        }
      }
    }
    // 清除临时标记
    for idx in sorted[level] {
      if labels[idx] == -2 {
        labels[idx] = 0
      }
    }
  }
  labels
}

///|
/// 自动分水岭分割（使用局部最小值作为种子点）。
/// 适用于灰度图（channels=1）或 RGB/RGBA 图（channels=3/4，自动转灰度）。
/// 返回标签图和区域数量。
pub fn watershed_auto(
  img : @types.Image,
) -> (Array[Int], Int) raise @types.LoadError {
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "watershed_auto 仅支持 channels=1/3/4",
    )
  }
  let w = img.width
  let h = img.height
  let n = w * h
  if n == 0 {
    return ([], 0)
  }
  // 转灰度
  let gray : Array[Int] = Array::make(n, 0)
  let ch = img.channels
  for i in 0..<n {
    if ch == 1 {
      gray[i] = img.data[i].to_int()
    } else {
      let r = img.data[i * ch].to_int()
      let g = img.data[i * ch + 1].to_int()
      let b = img.data[i * ch + 2].to_int()
      gray[i] = (r * 299 + g * 587 + b * 114) / 1000
    }
  }
  // 寻找局部最小值作为种子点
  let markers : Array[Int] = Array::make(n, 0)
  let mut current_label = 0
  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      let val = gray[idx]
      let mut is_min = true
      for dy in -1..<=1 {
        for dx in -1..<=1 {
          if dx == 0 && dy == 0 {
            continue
          }
          let nx = x + dx
          let ny = y + dy
          if nx >= 0 && nx < w && ny >= 0 && ny < h {
            let nidx = ny * w + nx
            if gray[nidx] < val {
              is_min = false
              break
            }
          }
        }
        if !is_min {
          break
        }
      }
      if is_min && markers[idx] == 0 {
        current_label += 1
        // BFS 标记连通的等值像素（head 指针队列，避免 remove 开销）
        let stack : Array[Int] = [idx]
        let mut sp = 0
        markers[idx] = current_label
        while sp < stack.length() {
          let pidx = stack[sp]
          sp += 1
          let px = pidx % w
          let py = pidx / w
          for dy in -1..<=1 {
            for dx in -1..<=1 {
              if dx == 0 && dy == 0 {
                continue
              }
              let nx = px + dx
              let ny = py + dy
              if nx >= 0 && nx < w && ny >= 0 && ny < h {
                let nidx = ny * w + nx
                if markers[nidx] == 0 && gray[nidx] == val {
                  markers[nidx] = current_label
                  stack.push(nidx)
                }
              }
            }
          }
        }
      }
    }
  }
  let labels = watershed(img, markers)
  (labels, current_label)
}

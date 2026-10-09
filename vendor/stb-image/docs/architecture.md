# image 架构文档

> 版本 v5.3.0 | 286 公开函数 + 1 常量 + 47 类型 | 1203 测试 × 4 目标 (native/wasm-gc/js/wasm)

## 概述

image 是 纯 MoonBit 图像处理库，无 C FFI 依赖，提供完整的图像解码/编码/缩放/处理能力。采用多子包架构（types, pure, lib, process, meta, util），根包 re-export 保持向后兼容 API。四目标 (native/wasm-gc/js/wasm) 均使用纯 MoonBit 实现，各 1203 测试通过。

## 功能分类

```mermaid
mindmap
  root((image))
    格式 I/O
      解码 15 种格式
      编码 14 种格式
      自动检测
      动画 GIF/APNG
      流式解码
    像素类型
      8位 Image
      16位 Image16
      浮点 ImageF
    缩放
      7 种滤波器
      4 种边缘模式
      sRGB 色彩空间
      Seam Carving
    色彩
      HSV HSL 转换
      YCbCr XYZ Lab CMYK
      亮度 对比度 伽马
      CLAHE
      Retinex SSR MSR MSRCR
      去雾
    滤波
      方框 高斯 中值 双边
      Gabor 滤波器组
      NLM 去噪
      Haar 小波去噪
      图像修复 inpaint
    边缘检测
      Sobel Laplacian Prewitt
      Canny
      Harris 角点
      Hough 变换
      轮廓提取
    特征检测
      ORB FAST+BRIEF
      SIFT DoG 128维
      模板匹配
      光流 LK+HS
    特征匹配
      SIFT 匹配 Lowe比率
      RANSAC 单应性
    分割
      K-means
      区域生长
      分水岭
      泛洪填充
      SLIC 超像素
      grabCut
    纹理
      LBP
      GLCM
      Gabor
      距离变换
    频域
      FFT IFFT
      DCT IDCT
      频域滤波
      Haar 小波
    形态学
      腐蚀 膨胀
      开 闭运算
      梯度 顶帽 黑帽
      骨架化
    质量
      MSE PSNR SSIM
      直方图
      积分图像
    元数据
      EXIF 读写
      PNG 文本块
    安全
      fuzzing 审计
      整数溢出防护
```

## 包结构概览

```mermaid
flowchart TB
    subgraph Root["根包 (src/)"]
        RE["reexport.mbt<br/>283 pub fn + 47 types"]
        Bench["bench.mbt ()"]
    end

    subgraph TypesPkg["types/ — 全目标类型"]
        TypeDef["image_types.mbt<br/>Image · Image16 · ImageF<br/>ImageInfo · GifAnimation · PngAnimation · LoadError"]
    end

    subgraph Pure["pure/ — 纯 MoonBit 后端 (全目标)"]
        PureCodec["codec/ — 格式编解码"]
        PureColor["color/ — 色彩调整/转换/映射"]
        PureUtil["util/ — 配置/信息/缩放/zlib"]
    end

    subgraph Lib["lib/ — pure 侧统一 API"]
        LibEntry["lib.mbt<br/>格式自动分派"]
    end

    subgraph Process["process/ — 图像处理"]
        Transform["transform · geometry<br/>裁剪 · 旋转 · 仿射 · 透视"]
        Color["color · clahe · retinex · dehaze<br/>HSV · HSL · CLAHE"]
        Filter["filter · bilateral · gabor<br/>模糊 · 锐化 · 去噪"]
        Edge["edge · canny · harris · hough<br/>sobel · contour · LBP"]
        Segment["segment · morphology · watershed<br/>kmeans · region_growing · SLIC"]
        Freq["frequency · fft · haar · dct<br/>频域分析"]
        Feature["feature · glcm · histogram<br/>积分图像 · Harris · LBP"]
    end

    subgraph Meta["meta/ — 元数据"]
        EXIF["exif.mbt"]
        PNGMeta["png_meta.mbt"]
    end

    subgraph Util["util/ — 工具函数"]
        PixelOps["pixel_ops · pixel_advanced"]
        Compose["image_compose · image_noise"]
        Blend["color_map (13 混合模式)"]
        Stats["image_stats · image_util"]
    end

    Root --> Lib
    Root --> Process
    Root --> Meta
    Root --> Util
    Lib --> Pure
    Pure -.-> TypesPkg
    Process -.-> TypesPkg
```

## 包依赖关系

```mermaid
flowchart TB
    Root["根包 src/<br/>reexport.mbt · bench"]
    Types["types/<br/>全目标类型（纯 MoonBit）"]
    Pure["pure/<br/>纯 MoonBit 后端（3 子包：codec/color/util）"]
    Lib["lib/<br/>pure 侧统一 API + 格式分派"]
    Process["process/<br/>图像处理（纯 MoonBit, 7 子子包）"]
    Meta["meta/<br/>元数据（纯 MoonBit）"]
    Util["util/<br/>工具函数（纯 MoonBit）"]

    Root --> Lib
    Root --> Process
    Root --> Meta
    Root --> Util
    Pure --> Types
    Lib --> Types
    Lib --> Pure
    Process --> Types
    Meta --> Types
    Util --> Types

    classDef pure fill:#e1f5fe,stroke:#01579b
    class Types,Pure,Lib,Process,Meta,Util pure
```

## 纯 MoonBit 架构

```mermaid
flowchart LR
    subgraph MoonBit["MoonBit 层（全目标）"]
        Types["image_types.mbt<br/>Image · Image16 · ImageF"]
        Pure["pure/{codec,color,util}/<br/>纯 MoonBit 编解码 + 处理"]
        Lib["lib/<br/>统一 API + 格式分派"]
    end

    Types --> Pure
    Pure --> Lib
```

**架构约束**：
- 所有代码纯 MoonBit 实现，无 C FFI 依赖
- 四目标 (native/wasm-gc/js/wasm) 共用同一套代码
- 像素数据存储在 MoonBit 管理的 `Bytes` 中，无跨语言内存边界

## 子包详解

### lib/ — pure 侧统一 API + 格式分派

```mermaid
flowchart TB
    subgraph LibPkg["lib/ (统一入口)"]
        LibEntry["lib.mbt<br/>detect_format · load_from_bytes_auto<br/>load_16_from_bytes_auto<br/>encode_* 委托"]
    end
```

**职责**：格式自动分派、编解码委托，委托 @pure/codec 实现纯 MoonBit 后端

**关键设计**：
- `Image.data : Bytes` — 像素数据存储在 MoonBit 管理的 `Bytes` 中
- `LoadError` — 四种错误变体：`FileIO` / `UnsupportedFormat` / `DecodeFailed` / `EncodeFailed`
- `req_channels` — 可选参数强制输出通道数（1=灰度, 2=灰度+Alpha, 3=RGB, 4=RGBA）

### pure/ — 纯 MoonBit 后端

```mermaid
flowchart TB
    subgraph PurePkg["pure/ (纯 MoonBit, 3 子包)"]
        direction TB
        subgraph CodecSub["codec/ — 格式编解码"]
            PC1["PNG · JPEG · BMP · GIF"]
            PC2["QOI · TGA · PSD · HDR"]
            PC3["PNM · TIFF · ICO · CUR"]
            PC4["ICNS · APNG · WebP"]
        end
        subgraph ColorSub["color/ — 色彩处理"]
            PC5["color_adjust · color_convert<br/>color_map · color_segment"]
        end
        subgraph UtilSub["util/ — 工具"]
            PC6["config · image_info<br/>resize · zlib"]
        end
    end
```

**职责**：所有格式编解码和基础色彩/工具操作的纯 MoonBit 实现

### process/ — 图像处理

```mermaid
flowchart TB
    subgraph ProcPkg["process/ (纯 MoonBit, 7 子子包)"]
        direction TB
        subgraph TransformSub["transform/ — 几何变换"]
            T1["transform.mbt<br/>crop · rotate_90/180/270 · flip_h"]
            T2["geometry.mbt<br/>warp_affine · rotate · warp_perspective"]
            T3["draw.mbt<br/>draw_copy · draw_over · draw_line/rect/circle/polygon"]
            T4["pyramid.mbt<br/>高斯/拉普拉斯金字塔 · 多频带融合"]
            T5["seam_carving.mbt<br/>内容感知缩放"]
        end
        subgraph ColorSub["color/ — 色彩处理"]
            C1["color_convert.mbt<br/>to_grayscale · to_rgb · to_rgba<br/>premultiply · unpremultiply"]
            C2["color_adjust.mbt<br/>brightness · contrast · gamma · invert<br/>HSV · HSL · YCbCr · XYZ · Lab · CMYK"]
            C3["color_segment.mbt<br/>K-means · 区域生长 · 泛洪填充"]
            C4["adaptive_threshold.mbt<br/>mean · gaussian · otsu"]
            C5["clahe.mbt<br/>CLAHE"]
            C6["dehaze.mbt<br/>暗通道先验去雾"]
            C7["retinex.mbt<br/>SSR · MSR · MSRCR · 色调映射"]
        end
        subgraph EdgeSub["edge/ — 边缘检测"]
            E1["edge_detect.mbt<br/>laplacian · prewitt"]
            E2["canny.mbt<br/>Canny 边缘"]
            E3["contour.mbt<br/>Moore 边界跟踪 · 凸包 · 矩"]
            E4["hough.mbt<br/>直线检测 + NMS · 圆检测"]
        end
        subgraph FeatureSub["feature/ — 特征提取"]
            F1["histogram.mbt<br/>compute · equalize · normalize · matching · compare"]
            F2["image_quality.mbt<br/>mse · psnr · ssim"]
            F3["integral_image.mbt<br/>O(1) 矩形查询"]
            F4["lbp.mbt<br/>基本 + 均匀 LBP"]
            F5["gabor.mbt<br/>Gabor 滤波"]
            F6["glcm.mbt<br/>灰度共生矩阵"]
            F7["harris.mbt<br/>Harris · Shi-Tomasi 角点"]
        end
        subgraph FilterSub["filter/ — 滤波"]
            Fi1["filter.mbt<br/>box_blur · gaussian_blur · median_blur · sharpen<br/>sobel · laplacian · prewitt"]
            Fi2["bilateral_filter.mbt<br/>保边去噪"]
            Fi3["nlm_denoise.mbt<br/>非局部均值"]
        end
        subgraph FrequencySub["frequency/ — 频域"]
            Fr1["fft.mbt<br/>fft_2d · ifft_2d · magnitude · shift"]
            Fr2["freq_filter.mbt<br/>freq_filter · freq_filter_gaussian"]
            Fr3["haar_wavelet.mbt<br/>Haar 小波"]
            Fr4["dct.mbt<br/>DCT · IDCT"]
        end
        subgraph SegmentSub["segment/ — 分割"]
            S1["morphology.mbt<br/>erode · dilate · open · close · gradient · tophat · blackhat"]
            S2["quantize.mbt<br/>floyd_steinberg · median_cut"]
            S3["kmeans_quantize.mbt<br/>K-means 量化"]
            S4["connected_components.mbt<br/>labeling + Union-Find"]
            S5["distance_transform.mbt<br/>距离变换 · 骨架化"]
            S6["watershed.mbt<br/>分水岭分割"]
            S7["slic.mbt<br/>SLIC 超像素"]
        end
    end
```

**职责**：所有纯 MoonBit 图像处理算法，无 C FFI 依赖，全目标支持

**关键设计**：
- 仅依赖 `@types`（类型定义）和 `@math`（数学函数）
- 所有函数接受 `Image` 返回 `Image`，支持函数组合
- 36 个类型中多数定义在此包（`Complex`, `FFTResult`, `FreqFilterType`, `ConnectedComponent`, ...）

### meta/ — 元数据

```mermaid
flowchart TB
    subgraph MetaPkg["meta/ (纯 MoonBit)"]
        EXIF["exif.mbt<br/>read_exif_from_bytes<br/>write_exif_to_bytes · create_exif_segment<br/>ExifInfo (make, model, date_time, orientation)"]
        PNG["png_meta.mbt<br/>read_png_text_chunks<br/>PngTextChunk (keyword, text)"]
    end
```

**职责**：EXIF 读写和 PNG 文本块元数据读取

### util/ — 工具函数

```mermaid
flowchart TB
    subgraph UtilPkg["util/ (纯 MoonBit)"]
        PixelOps["pixel_ops.mbt<br/>threshold · posterize · extract_channel"]
        PixelAdv["pixel_advanced.mbt<br/>set_alpha · fill_alpha · replace_color · apply_lut"]
        Compose["image_compose.mbt<br/>hstack · vstack · tile · flip_v · transpose"]
        Noise["image_noise.mbt<br/>add_noise_gaussian · salt_pepper"]
        ColorMap["color_map.mbt<br/>gradient_map · 13 blend modes · apply_colormap"]
        Stats["image_stats.mbt<br/>compute_stats · mean_value"]
        Util["image_util.mbt<br/>pad · border · resize_to_cover/contain · pixelate · convolve"]
    end
```

**职责**：像素操作、图像合成、噪声、色彩映射、统计等工具函数

## 数据流

### 处理流水线概览

```mermaid
flowchart LR
    File["文件/字节"] --> Load["加载<br/>8/16/float"]
    Load --> Img["Image / Image16 / ImageF"]
    Img --> Proc["处理流水线"]
    Proc --> Out["输出图像"]
    Out --> Write["写入<br/>PNG/BMP/JPEG/..."]
    Write --> Result["文件/字节"]

    subgraph Proc["处理流水线 (可组合)"]
        direction TB
        P1["色彩调整<br/>亮度 · 对比度 · 伽马 · CLAHE · Retinex · 去雾"]
        P2["滤波<br/>模糊 · 锐化 · 双边 · NLM · Gabor · 修复"]
        P3["几何<br/>裁剪 · 旋转 · 仿射 · 透视 · 缩放 · Seam Carving"]
        P4["边缘/特征<br/>Sobel · Canny · Harris · Hough · ORB · SIFT"]
        P5["分割<br/>K-means · 分水岭 · 轮廓 · SLIC · grabCut"]
        P6["频域<br/>FFT · DCT · 滤波 · Haar 小波"]
        P7["质量<br/>MSE · PSNR · SSIM · 直方图 · 光流"]
    end

    Img -.-> Meta["元数据<br/>EXIF · PNG 文本块"]
    Img -.-> Detect["格式检测<br/>decode_any · detect_format"]
```

### 加载-处理-写入序列图

```mermaid
sequenceDiagram
    participant User as 用户代码
    participant Root as reexport.mbt
    participant Lib as lib/
    participant Pure as pure/codec/
    participant Proc as process/

    User->>Root: load_from_bytes(png_bytes)
    Root->>Lib: @lib.load_from_bytes_auto(bytes)
    Lib->>Pure: @codec.decode_png_pure(bytes)
    Pure-->>Lib: Image
    Lib-->>Root: Image
    Root-->>User: Image

    User->>Root: gaussian_blur(img, 5, 1.0)
    Root->>Proc: @filter.gaussian_blur(img, 5, 1.0)
    Proc-->>Root: Image (blurred)
    Root-->>User: Image

    User->>Root: write_png_to_bytes(result)
    Root->>Lib: @lib.encode_png(img)
    Lib->>Pure: @codec.encode_png_pure(img)
    Pure-->>Lib: Bytes
    Lib-->>Root: Bytes
    Root-->>User: Bytes
```

### 格式检测流程

```mermaid
flowchart TB
    Input["输入 Bytes"] --> Magic["检查魔数字节<br/>PNG: 89 50 4E 47<br/>JPEG: FF D8<br/>BMP: 42 4D<br/>GIF: 47 49 46<br/>QOI: 71 6F 69 66<br/>WebP: 52 49 46 46<br/>..."]
    Magic --> Format{"格式识别"}
    Format -->|PNG| PNG["纯 MoonBit<br/>PNG 解码"]
    Format -->|JPEG| JPEG["纯 MoonBit<br/>JPEG 解码"]
    Format -->|BMP| BMP["纯 MoonBit<br/>BMP 解码"]
    Format -->|GIF| GIF["纯 MoonBit<br/>GIF 解码"]
    Format -->|QOI| QOI["纯 MoonBit<br/>QOI 解码"]
    Format -->|PNM| PNM["纯 MoonBit<br/>PNM 解码"]
    Format -->|WebP| WebP["纯 MoonBit<br/>WebP 解码"]
    Format -->|PSD/HDR| Other["纯 MoonBit<br/>PSD/HDR 解码"]
    Format -->|未知| Err["UnsupportedFormat"]
    PNG --> Image["Image"]
    JPEG --> Image
    BMP --> Image
    GIF --> Image
    QOI --> Image
    PNM --> Image
    WebP --> Image
    Other --> Image
```

## API 分类

```mermaid
flowchart TB
    subgraph IO["I/O (25 函数)"]
        Load["加载 (3)"]
        Write["写入 (5)"]
        Resize["缩放 (1)"]
        Detect["检测 (3)"]
        Query["查询 (3)"]
        Config["配置 (8)"]
        FileIO["其他 (2)"]
    end

    subgraph Proc["处理 (213+ 函数)"]
        Color["色彩 (40+)"]
        Filter["滤波 (18)"]
        Geo["几何 (15)"]
        Edge["边缘/特征 (25+)"]
        Seg["分割 (20)"]
        Freq["频域 (13)"]
        Tex["纹理 (14)"]
        Morph["形态学 (15)"]
        Qual["质量 (8)"]
    end

    subgraph UtilFn["工具 (21 函数)"]
    end
    subgraph Safety["安全 (3+1)"]
        CheckDims["check_dims"]
        SafeMul["safe_mul / safe_mul3"]
        MaxDim["MAX_IMAGE_DIMENSION"]
        Pixel["像素操作 (3)"]
        PixelAdv["高级像素 (4)"]
        Compose["图像合成 (4)"]
        Noise["噪声 (2)"]
        ColorMap["色彩映射 (2)"]
        Stats["统计 (2)"]
        UtilMisc["图像工具 (4)"]
    end

    subgraph Codec["编解码 (20 函数)"]
        QOI["QOI (2)"]
        ICO["ICO/ICNS/CUR (7)"]
        GIF["GIF/PNM (5)"]
        TIFF["TIFF/APNG/WebP (6)"]
    end

    subgraph MetaFn["元数据 (4 函数)"]
        EXIF["EXIF (3)"]
        PNG["PNG 文本块 (1)"]
    end

    Types["47 类型<br/>Image · Image16 · ImageF · ..."]
```

## 类型体系

```mermaid
classDiagram
    class Image {
        +Int width
        +Int height
        +Int channels
        +Bytes data
    }
    class Image16 {
        +Int width
        +Int height
        +Int channels
        +Bytes data
    }
    class ImageF {
        +Int width
        +Int height
        +Int channels
        +Bytes data
    }
    class ImageInfo {
        +Int width
        +Int height
        +Int channels
    }
    class GifAnimation {
        +Array~Image~ frames
        +Array~Int~ delays
    }
    class LoadError {
        <<enum>>
        FileIO(String)
        UnsupportedFormat(String)
        DecodeFailed(String)
        EncodeFailed(String)
    }
    class ImageFormat {
        <<enum>>
        Png
        Jpeg
        Bmp
        Gif
        Tga
        Psd
        Hdr
        Pnm
        Qoi
        Unknown
    }
    class ResizeFilter {
        <<enum>>
        Default
        Box
        Triangle
        CubicBSPline
        CatmullROM
        Mitchell
        PointSample
    }
    class ResizeEdge {
        <<enum>>
        Clamp
        Reflect
        Wrap
        Zero
    }
```

> 上述仅展示 9 个核心类型。完整 47 个类型列表（含 `PngAnimation`、`ExifInfo`、`PngTextChunk`、`ImageStats`、`Complex`、`FFTResult`、`ConnectedComponent`、`HoughLine`、`Contour`、`GlcmFeatures`、`HaarWaveletResult`、`CornerPoint`、`HistCompareMethod`、`StructuringElement`、`PerspectiveMatrix`、`AffineMatrix`、`Moments`、`Circle`、`Colormap`、`SuperpixelResult`、`SiftKeyPoint`、`SiftDescriptor`、`SiftMatch`、`StreamInfo`、`OrbKeyPoint`、`OrbDescriptor`、`DescriptorMatch`、`TemplateMatchMethod`、`TemplateMatchResult`、`FlowResult` 等 38 个处理/元数据/工具类型）详见 [api_reference.md](api_reference.md)。

## 项目结构

```
image/
├── moon.mod                  # 模块配置 (v4.8.0, preferred_target = native)
├── README.md                 # 项目说明（中文）
├── docs/
│   ├── architecture.md       # 架构文档（本文）
│   ├── api_reference.md      # 完整 API 参考
│   ├── changelog.md          # 版本历史
│   ├── roadmap.md            # 迭代路线图
│   ├── comparison.md         # mooncakes.io 图像库对比
│   └── skill.md              # 包使用指南
├── src/
│   ├── moon.pkg              # 根包：re-export + 基准测试
│   ├── reexport.mbt          # 向后兼容API（283 pub fn + 47 类型）
│   ├── reexport_test.mbt     # re-export 测试
│   ├── bench.mbt             # 性能基准测试
│   ├── types/                # 全目标类型包（Image/Image16/ImageF/ImageInfo 等）
│   │   ├── moon.pkg          # 依赖 @debug
│   │   └── image_types.mbt   # 跨目标共享类型定义
│   ├── pure/                 # 纯 MoonBit 后端（全目标，3 子包）
│   │   ├── codec/            # 编解码：BMP/QOI/TGA/PNM/PSD/GIF/PNG/JPEG/HDR/TIFF/ICO/CUR/ICNS/APNG/WebP
│   │   ├── color/            # 色彩：color_adjust, color_convert, color_map
│   │   ├── util/             # 工具：config, image_info, resize, zlib
│   │   └── */*_test.mbt      # pure 后端测试
│   ├── lib/                  # pure 侧统一 API + 自动格式分派
│   │   ├── moon.pkg          # 依赖 @types, @pure, @debug
│   │   ├── lib.mbt           # 统一入口 + 格式自动分派
│   │   └── lib_test.mbt      # lib 测试
│   ├── process/              # 图像处理（纯MoonBit，7 个子子包）
│   │   ├── moon.pkg          # 空占位包
│   │   ├── transform/        # 裁剪/旋转/翻转/金字塔/绘制/透视/seam carving
│   │   ├── color/            # 色彩转换/调整/CLAHE/Retinex/去雾/分割/阈值
│   │   ├── filter/           # 模糊/锐化/双边/NLM/Gabor
│   │   ├── edge/             # Sobel/Laplacian/Prewitt/Canny/Hough/轮廓
│   │   ├── frequency/        # FFT/频域滤波/Haar小波/DCT
│   │   ├── feature/          # 直方图/积分图像/GLCM/Harris/LBP/质量评估
│   │   └── segment/          # 形态学/量化/连通域/分水岭/距离变换/SLIC
│   ├── meta/                 # 元数据（纯MoonBit）
│   │   ├── moon.pkg          # 导入 @types
│   │   ├── exif.mbt          # read_exif_from_bytes/write_exif_to_bytes
│   │   ├── png_meta.mbt      # read_png_text_chunks/...
│   │   └── *_test.mbt        # 元数据测试
│   ├── util/                 # 工具函数（纯MoonBit）
│   │   ├── moon.pkg          # 导入 @types, @process/transform, @debug, @math
│   │   ├── image_util.mbt    # pad/border/resize_to_cover/contain/pixelate/...
│   │   ├── pixel_ops.mbt     # threshold/posterize/extract_channel/swap_channels
│   │   ├── pixel_advanced.mbt# set_alpha/fill_alpha/replace_color/apply_lut
│   │   ├── image_stats.mbt   # compute_stats/mean_value
│   │   ├── image_compose.mbt # hstack/vstack/tile/flip_vertical/transpose
│   │   ├── image_noise.mbt   # add_noise_gaussian/add_noise_salt_pepper
│   │   ├── color_map.mbt     # gradient_map/blend_*/apply_colormap
│   │   └── *_test.mbt        # 工具测试
│   └── testdata/             # 测试图像（PNG/BMP/GIF/JPG + 损坏文件）
```

## 设计决策

### 1. 多子包架构（v2.0）

**问题**：单包超过 30 个源文件，编译慢、职责不清

**方案**：按职责拆分为 `types`（全目标类型）/ `pure`（纯 MoonBit 后端，3 子包：codec/color/util）/ `lib`（pure 侧统一 API）/ `process`（图像处理，7 子包）/ `meta`（元数据）/ `util`（工具函数），根包 re-export 保持 API 兼容。

**收益**：编译并行化、职责清晰、可独立测试、多目标支持

### 2. re-export 策略

**问题**：`pub let` 无法 re-export 带标签参数的函数

**方案**：普通函数用 `pub let` 直接别名，带标签参数的函数用 `pub fn` 包装器保留默认值

### 3. 纯 MoonBit 全目标

**问题**：C FFI 仅支持 native 目标，wasm/js 无法使用

**方案**：v2.0 移除所有 C FFI 依赖，全部用纯 MoonBit 重写。像素数据存储在 MoonBit `Bytes` 中，无跨语言内存边界。四目标 (native/wasm-gc/js/wasm) 共用同一套代码

### 4. pure 子包拆分

**原则**：
- `pure/codec/` — 所有格式编解码（BMP/QOI/TGA/PNM/PSD/GIF/PNG/JPEG/HDR/TIFF/ICO/CUR/ICNS/APNG/WebP）
- `pure/color/` — 色彩调整/转换/映射
- `pure/util/` — 工具（配置/信息/缩放/zlib inflate）

### 5. `pub(all) struct` vs `pub struct`

**问题**：测试中需要构造 struct 实例

**方案**：需要外部构造的类型用 `pub(all) struct`（如 `HoughLine`, `Contour`, `CornerPoint`），仅内部使用的用 `pub struct`

## 安全机制 (v4.10.0)

### 维度溢出守卫

**问题**：恶意图像可声明超大 width/height 导致 OOM 或整数溢出（width × height × channels 溢出后分配小缓冲区，写入越界）

**方案**：
- `MAX_IMAGE_DIMENSION = 65535` — 单边像素上限，覆盖所有常见格式最大尺寸
- `check_dims(width, height, channels)` — 所有解码器入口调用，校验三重条件：
  1. width/height/channels 均为正数
  2. width/height 不超过 MAX_IMAGE_DIMENSION
  3. width × height × channels 不超过 Int 最大值（防溢出）
- `safe_mul` / `safe_mul3` — 溢出安全乘法，返回 `Int?`，溢出时返回 `None`

**覆盖范围**：PNG / BMP / GIF / TIFF / WebP / JPEG / HDR / QOI / TGA / PNM 全部 10 种解码器

**测试**：19 项安全测试（safety_test.mbt）+ 5 项大尺寸溢出测试（overflow_test.mbt）


## 性能特征

| 操作 | 复杂度 | 备注 |
|------|--------|------|
| 加载/写入 | O(n) | n = 像素数，纯 MoonBit |
| 缩放 | O(n) | 纯 MoonBit resize |
| box_blur | O(n) | 滑动窗口优化 |
| gaussian_blur | O(n × r) | 可分离核，r = 半径 |
| bilateral_filter | O(n × r²) | r = 半径 |
| bilateral_filter_fast | O(n × r² / s²) | s = 降采样因子 |
| nlm_denoise | O(n × s² × p²) | s = 搜索窗口, p = 块大小 |
| fft_2d | O(n log n) | Cooley-Tukey radix-2 |
| connected_components | O(n × α(n)) | Union-Find，α ≈ 4 |
| integral_image | O(n) | 预处理 |
| integral_sum/mean/variance | O(1) | 矩形查询 |
| distance_transform | O(n) | 两遍扫描 |
| hough_lines | O(n × θ) | θ = 角度分辨率 |
| watershed | O(n log n) | 优先队列 |
| dehaze | O(n × p²) | p = 暗通道块大小 |

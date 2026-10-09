#!/usr/bin/env python3
"""
PDF OCR 处理脚本
使用 stb-image MoonBit 库的 OCR 功能处理扫描版 PDF

工作流程：
1. 将 PDF 页面转换为图像
2. 评估扫描质量
3. 图像预处理（去噪、对比度增强、二值化）
4. 版面分析
5. OCR 识别
6. 输出结果（文本/hOCR/JSON）
"""

import os
import sys
import subprocess
import json
from pathlib import Path

# 检查依赖
def check_dependencies():
    """检查必要的依赖工具"""
    dependencies = {
        'pdftoppm': 'poppler-utils',
    }
    
    missing = []
    for cmd, desc in dependencies.items():
        result = subprocess.run(['which', cmd], capture_output=True, text=True)
        if result.returncode != 0:
            missing.append(f"{cmd} ({desc})")
    
    if missing:
        print("缺少以下依赖：")
        for m in missing:
            print(f"  - {m}")
        return False
    return True

def pdf_to_images(pdf_path, output_dir, dpi=200, first_page=None, last_page=None):
    """
    将 PDF 转换为 PNG 图像
    
    Args:
        pdf_path: PDF 文件路径
        output_dir: 输出目录
        dpi: 分辨率
        first_page: 起始页（1-based）
        last_page: 结束页（1-based）
    
    Returns:
        图像文件路径列表
    """
    os.makedirs(output_dir, exist_ok=True)
    
    cmd = ['pdftoppm', '-png', '-r', str(dpi)]
    if first_page:
        cmd.extend(['-f', str(first_page)])
    if last_page:
        cmd.extend(['-l', str(last_page)])
    cmd.extend([pdf_path, os.path.join(output_dir, 'page')])
    
    print(f"正在转换 PDF: {pdf_path}")
    print(f"  分辨率: {dpi} DPI")
    if first_page or last_page:
        print(f"  页码范围: {first_page or 1} - {last_page or '最后一页'}")
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"转换失败: {result.stderr}")
        return []
    
    # 收集生成的图像文件
    images = sorted(Path(output_dir).glob('page-*.png'))
    print(f"  生成了 {len(images)} 页图像")
    return [str(img) for img in images]

def evaluate_image_quality(image_path):
    """
    评估图像质量（使用 Python PIL 进行简单评估）
    
    实际项目中应调用 MoonBit OCR 模块的 evaluate_scan_quality 函数
    """
    try:
        from PIL import Image
        import numpy as np
        
        img = Image.open(image_path).convert('L')
        arr = np.array(img, dtype=np.float64)
        
        brightness = np.mean(arr)
        contrast = np.std(arr)
        
        # 锐度（拉普拉斯方差）
        from scipy import ndimage
        laplacian = ndimage.laplace(arr)
        sharpness = np.var(laplacian)
        
        # 噪声估计
        noise_level = np.std(arr[:100, :100]) if arr.shape[0] > 100 and arr.shape[1] > 100 else 10
        
        # 综合评分
        score = 50.0
        score += max(0, 100 - abs(brightness - 128) * 0.5) * 0.2
        score += min(100, contrast * 2) * 0.3
        score += min(100, sharpness) * 0.3
        score += max(0, 100 - noise_level * 2) * 0.2
        
        issues = []
        if brightness < 50:
            issues.append("图像过暗")
        if brightness > 200:
            issues.append("图像过亮")
        if contrast < 30:
            issues.append("对比度不足")
        if sharpness < 20:
            issues.append("图像模糊")
        if noise_level > 30:
            issues.append("噪声较高")
        
        return {
            'brightness': float(brightness),
            'contrast': float(contrast),
            'sharpness': float(sharpness),
            'noise_level': float(noise_level),
            'overall_score': float(min(100, max(0, score))),
            'issues': issues
        }
    except ImportError as e:
        return {
            'error': f"缺少依赖: {e}",
            'note': '请安装 Pillow, numpy, scipy: pip install pillow numpy scipy'
        }

def preprocess_image(image_path, output_path, method='otsu'):
    """
    图像预处理（使用 Python PIL 进行简单预处理）
    
    实际项目中应调用 MoonBit OCR 模块的 scan_document_preprocess 函数
    """
    try:
        from PIL import Image, ImageFilter, ImageEnhance
        
        img = Image.open(image_path)
        
        # 1. 去噪（中值滤波）
        img = img.filter(ImageFilter.MedianFilter(size=3))
        
        # 2. 对比度增强
        enhancer = ImageEnhance.Contrast(img)
        img = enhancer.enhance(1.2)
        
        # 3. 二值化
        gray = img.convert('L')
        if method == 'otsu':
            # Otsu 阈值
            import numpy as np
            arr = np.array(gray)
            hist, _ = np.histogram(arr, bins=256, range=(0, 256))
            total = arr.size
            sum_total = np.dot(np.arange(256), hist)
            sum_bg = 0
            weight_bg = 0
            max_variance = 0
            threshold = 128
            for i in range(256):
                weight_bg += hist[i]
                if weight_bg == 0:
                    continue
                weight_fg = total - weight_bg
                if weight_fg == 0:
                    break
                sum_bg += i * hist[i]
                mean_bg = sum_bg / weight_bg
                mean_fg = (sum_total - sum_bg) / weight_fg
                variance = weight_bg * weight_fg * (mean_bg - mean_fg) ** 2
                if variance > max_variance:
                    max_variance = variance
                    threshold = i
            binary = gray.point(lambda x: 255 if x > threshold else 0, '1')
        else:
            binary = gray.point(lambda x: 255 if x > 128 else 0, '1')
        
        binary.save(output_path)
        return output_path
    except ImportError as e:
        print(f"预处理失败: {e}")
        return None

def analyze_layout(image_path):
    """
    版面分析（使用 Python 进行简单的投影分析）
    
    实际项目中应调用 MoonBit OCR 模块的 analyze_layout_scan 函数
    """
    try:
        from PIL import Image
        import numpy as np
        
        img = Image.open(image_path).convert('L')
        arr = np.array(img)
        
        # 水平投影
        horizontal_proj = np.sum(arr < 128, axis=1)
        
        # 检测文本行
        blocks = []
        in_line = False
        line_start = 0
        threshold = arr.shape[1] / 50
        
        for y in range(len(horizontal_proj)):
            if horizontal_proj[y] > threshold:
                if not in_line:
                    line_start = y
                    in_line = True
                line_end = y
            else:
                if in_line:
                    # 检测这一行的文本范围
                    line_region = arr[line_start:line_end+1, :]
                    col_proj = np.sum(line_region < 128, axis=0)
                    text_cols = np.where(col_proj > 0)[0]
                    if len(text_cols) > 0:
                        min_x = int(text_cols[0])
                        max_x = int(text_cols[-1])
                        blocks.append({
                            'x': min_x,
                            'y': line_start,
                            'width': max_x - min_x + 1,
                            'height': line_end - line_start + 1,
                            'type': 'text'
                        })
                    in_line = False
        
        return blocks
    except ImportError as e:
        print(f"版面分析失败: {e}")
        return []

def run_ocr_pipeline(pdf_path, output_dir='ocr_output', dpi=200, first_page=None, last_page=None):
    """
    运行完整的 OCR 处理流水线
    
    Args:
        pdf_path: PDF 文件路径
        output_dir: 输出目录
        dpi: 分辨率
        first_page: 起始页
        last_page: 结束页
    """
    print("=" * 60)
    print("stb-image OCR 处理流水线")
    print("=" * 60)
    print()
    
    # 检查依赖
    if not check_dependencies():
        print("\n请安装缺少的依赖后重试")
        return
    
    # 创建输出目录
    os.makedirs(output_dir, exist_ok=True)
    images_dir = os.path.join(output_dir, 'images')
    preprocessed_dir = os.path.join(output_dir, 'preprocessed')
    
    # 1. PDF 转图像
    print("\n[步骤 1/5] PDF 转图像")
    print("-" * 40)
    images = pdf_to_images(pdf_path, images_dir, dpi, first_page, last_page)
    if not images:
        print("PDF 转换失败，终止处理")
        return
    
    # 2. 质量评估
    print("\n[步骤 2/5] 扫描质量评估")
    print("-" * 40)
    quality_results = []
    for i, img_path in enumerate(images):
        print(f"\n第 {i+1} 页: {os.path.basename(img_path)}")
        quality = evaluate_image_quality(img_path)
        quality_results.append(quality)
        if 'error' in quality:
            print(f"  评估失败: {quality['error']}")
            print(f"  提示: {quality.get('note', '')}")
        else:
            print(f"  亮度: {quality['brightness']:.1f}")
            print(f"  对比度: {quality['contrast']:.1f}")
            print(f"  锐度: {quality['sharpness']:.1f}")
            print(f"  噪声水平: {quality['noise_level']:.1f}")
            print(f"  综合质量评分: {quality['overall_score']:.1f}/100")
            if quality['issues']:
                print(f"  检测到的问题:")
                for issue in quality['issues']:
                    print(f"    - {issue}")
    
    # 3. 图像预处理
    print("\n[步骤 3/5] 图像预处理")
    print("-" * 40)
    os.makedirs(preprocessed_dir, exist_ok=True)
    preprocessed_images = []
    for i, img_path in enumerate(images):
        output_path = os.path.join(preprocessed_dir, f'page-{i+1:03d}.png')
        print(f"第 {i+1} 页: 预处理中...")
        result = preprocess_image(img_path, output_path, method='otsu')
        if result:
            preprocessed_images.append(result)
            print(f"  完成: {os.path.basename(result)}")
        else:
            print(f"  失败，使用原图")
            preprocessed_images.append(img_path)
    
    # 4. 版面分析
    print("\n[步骤 4/5] 版面分析")
    print("-" * 40)
    layout_results = []
    for i, img_path in enumerate(preprocessed_images):
        print(f"第 {i+1} 页: 版面分析中...")
        blocks = analyze_layout(img_path)
        layout_results.append(blocks)
        print(f"  检测到 {len(blocks)} 个文本块")
        for j, block in enumerate(blocks[:5]):
            print(f"    块 {j+1}: 位置({block['x']},{block['y']}) 尺寸({block['width']}x{block['height']})")
        if len(blocks) > 5:
            print(f"    ... 还有 {len(blocks) - 5} 个文本块")
    
    # 5. 生成结果报告
    print("\n[步骤 5/5] 生成结果报告")
    print("-" * 40)
    
    # 生成 JSON 报告
    report = {
        'pdf_path': pdf_path,
        'total_pages': len(images),
        'dpi': dpi,
        'pages': []
    }
    
    for i in range(len(images)):
        page_report = {
            'page_number': i + 1,
            'image_path': images[i],
            'preprocessed_path': preprocessed_images[i] if i < len(preprocessed_images) else None,
            'quality': quality_results[i] if i < len(quality_results) else None,
            'layout_blocks': layout_results[i] if i < len(layout_results) else [],
            'text_blocks_count': len(layout_results[i]) if i < len(layout_results) else 0
        }
        report['pages'].append(page_report)
    
    report_path = os.path.join(output_dir, 'ocr_report.json')
    with open(report_path, 'w', encoding='utf-8') as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print(f"  JSON 报告: {report_path}")
    
    # 生成文本摘要
    summary_path = os.path.join(output_dir, 'ocr_summary.txt')
    with open(summary_path, 'w', encoding='utf-8') as f:
        f.write("stb-image OCR 处理报告\n")
        f.write("=" * 60 + "\n\n")
        f.write(f"PDF 文件: {pdf_path}\n")
        f.write(f"总页数: {len(images)}\n")
        f.write(f"分辨率: {dpi} DPI\n\n")
        
        f.write("各页质量评估:\n")
        f.write("-" * 40 + "\n")
        for i, quality in enumerate(quality_results):
            if 'error' not in quality:
                f.write(f"第 {i+1} 页: 评分 {quality['overall_score']:.1f}/100")
                f.write(f" (亮度:{quality['brightness']:.0f} 对比度:{quality['contrast']:.0f} 锐度:{quality['sharpness']:.0f})")
                if quality['issues']:
                    f.write(f" 问题: {', '.join(quality['issues'])}")
                f.write("\n")
        
        f.write("\n各页版面分析:\n")
        f.write("-" * 40 + "\n")
        for i, blocks in enumerate(layout_results):
            f.write(f"第 {i+1} 页: 检测到 {len(blocks)} 个文本块\n")
            for j, block in enumerate(blocks[:3]):
                f.write(f"  块 {j+1}: ({block['x']},{block['y']}) {block['width']}x{block['height']}\n")
            if len(blocks) > 3:
                f.write(f"  ... 还有 {len(blocks) - 3} 个文本块\n")
    
    print(f"  文本摘要: {summary_path}")
    
    print("\n" + "=" * 60)
    print("OCR 处理完成！")
    print(f"输出目录: {os.path.abspath(output_dir)}")
    print("=" * 60)

def main():
    if len(sys.argv) < 2:
        print("用法: python pdf_ocr.py <pdf文件路径> [输出目录] [DPI] [起始页] [结束页]")
        print()
        print("示例:")
        print("  python pdf_ocr.py document.pdf")
        print("  python pdf_ocr.py document.pdf output 300 1 5")
        print()
        print("注意: 此脚本使用 Python 进行预处理演示。")
        print("      完整的 MoonBit OCR 识别功能需要编译 MoonBit 程序调用。")
        sys.exit(1)
    
    pdf_path = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else 'ocr_output'
    dpi = int(sys.argv[3]) if len(sys.argv) > 3 else 200
    first_page = int(sys.argv[4]) if len(sys.argv) > 4 else None
    last_page = int(sys.argv[5]) if len(sys.argv) > 5 else None
    
    if not os.path.exists(pdf_path):
        print(f"错误: 文件不存在 - {pdf_path}")
        sys.exit(1)
    
    run_ocr_pipeline(pdf_path, output_dir, dpi, first_page, last_page)

if __name__ == '__main__':
    main()

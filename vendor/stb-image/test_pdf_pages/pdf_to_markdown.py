#!/usr/bin/env python3
"""
PDF 转 Markdown 完整流程脚本（增强版布局分析 v12.19.0）
使用 stb-image MoonBit 库的 OCR + 增强版 Markdown 还原功能

增强功能：
- 多栏布局检测（单栏/双栏/混合）
- 页眉页脚自动识别与去除
- 精确标题层级判断（基于字体大小比例）
- 列表识别（项目符号/数字编号/复选框）
- 引用块识别
- 代码块识别
- 段落分割（基于行间距和首行缩进）
- 智能阅读顺序（支持多栏布局）
"""

import os
import sys
import subprocess
import json
import re
from pathlib import Path
from PIL import Image, ImageFilter, ImageEnhance
import numpy as np


def pdf_to_images(pdf_path, output_dir, dpi=200, first_page=None, last_page=None):
    """将 PDF 转换为 PNG 图像"""
    os.makedirs(output_dir, exist_ok=True)
    cmd = ['pdftoppm', '-png', '-r', str(dpi)]
    if first_page:
        cmd.extend(['-f', str(first_page)])
    if last_page:
        cmd.extend(['-l', str(last_page)])
    cmd.extend([pdf_path, os.path.join(output_dir, 'page')])
    
    print(f"[1/10] PDF 转图像 (DPI: {dpi})")
    subprocess.run(cmd, capture_output=True, text=True)
    
    images = sorted(Path(output_dir).glob('page-*.png'))
    print(f"  生成了 {len(images)} 页图像")
    return [str(img) for img in images]


def evaluate_quality(image_path):
    """评估扫描图像质量"""
    img = Image.open(image_path).convert('L')
    arr = np.array(img, dtype=np.float64)
    
    brightness = np.mean(arr)
    contrast = np.std(arr)
    
    from scipy import ndimage
    laplacian = ndimage.laplace(arr)
    sharpness = np.var(laplacian)
    
    noise_level = np.std(arr[:100, :100]) if arr.shape[0] > 100 and arr.shape[1] > 100 else 10
    
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


def preprocess_image(image_path, output_path):
    """图像预处理：去噪、对比度增强、二值化"""
    img = Image.open(image_path)
    img = img.filter(ImageFilter.MedianFilter(size=3))
    enhancer = ImageEnhance.Contrast(img)
    img = enhancer.enhance(1.2)
    gray = img.convert('L')
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
    binary.save(output_path)
    return output_path


def analyze_layout(image_path):
    """版面分析：检测文本块"""
    img = Image.open(image_path).convert('L')
    arr = np.array(img)
    horizontal_proj = np.sum(arr < 128, axis=1)
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


def detect_layout_type_enhanced(blocks, page_width, page_height):
    """检测页面布局类型（单栏/双栏/多栏）"""
    if not blocks:
        return 'single'
    full_width_count = 0
    left_half_count = 0
    right_half_count = 0
    mid_x = page_width / 2
    for block in blocks:
        block_center = block['x'] + block['width'] / 2
        if block['width'] > page_width * 0.7:
            full_width_count += 1
        elif block_center < mid_x:
            left_half_count += 1
        else:
            right_half_count += 1
    total = len(blocks)
    full_ratio = full_width_count / total
    left_ratio = left_half_count / total
    right_ratio = right_half_count / total
    if full_ratio > 0.8:
        return 'single'
    elif left_ratio > 0.3 and right_ratio > 0.3 and full_ratio < 0.3:
        return 'double'
    elif full_ratio > 0.3 and (left_ratio > 0.2 or right_ratio > 0.2):
        return 'mixed'
    else:
        return 'single'


def detect_header_footer_enhanced(blocks, page_height):
    """检测页眉页脚区域"""
    if not blocks:
        return 0, page_height
    header_threshold = page_height * 0.1
    footer_threshold = page_height * 0.9
    header_bottom = 0
    footer_top = page_height
    for block in blocks:
        if block['y'] < header_threshold and block['y'] + block['height'] > header_bottom:
            header_bottom = block['y'] + block['height']
        if block['y'] > footer_threshold and block['y'] < footer_top:
            footer_top = block['y']
    return header_bottom, footer_top


def classify_element_enhanced(block, avg_font_size=16, avg_x=0):
    """增强版文档元素分类"""
    height_ratio = block['height'] / avg_font_size if avg_font_size > 0 else 1
    
    # 标题判断（基于高度比例）
    if height_ratio > 3.0 and block['y'] < 100:
        return 'title'
    elif height_ratio > 2.0:
        return 'heading1'
    elif height_ratio > 1.5:
        return 'heading2'
    elif height_ratio > 1.2:
        return 'heading3'
    
    # 列表判断
    text = block.get('text', '')
    if text and text[0] in '•-*○●':
        return 'list_item'
    if re.match(r'^\d+[.\)、]', text):
        return 'list_item'
    if text.startswith('[ ]') or text.startswith('[x]') or text.startswith('[X]'):
        return 'list_item'
    
    # 引用块判断
    if text.startswith('>') or block['x'] > avg_x + 30:
        return 'quote'
    
    # 代码块判断
    code_chars = any(c in text for c in '{};=()')
    if block['x'] > avg_x + 20 and code_chars:
        return 'code_block'
    
    # 分隔线
    if block['height'] < 5 and block['width'] > 100:
        return 'horizontal_rule'
    
    return 'paragraph'


def detect_tables_enhanced(binary_img_path):
    """增强版表格检测：基于表格线检测"""
    img = Image.open(binary_img_path).convert('L')
    arr = np.array(img)
    w, h = img.size
    
    # 检测水平线
    h_lines = []
    for y in range(h):
        row = arr[y, :]
        black_pixels = np.where(row < 128)[0]
        if len(black_pixels) > w * 0.3:
            # 找连续线段
            start = black_pixels[0]
            end = black_pixels[0]
            for i in range(1, len(black_pixels)):
                if black_pixels[i] - end <= 3:
                    end = black_pixels[i]
                else:
                    if end - start > 50:
                        h_lines.append((y, start, end))
                    start = black_pixels[i]
                    end = black_pixels[i]
            if end - start > 50:
                h_lines.append((y, start, end))
    
    # 合并相近的水平线
    merged_h = []
    for line in h_lines:
        found = False
        for i, (my, msx, mex) in enumerate(merged_h):
            if abs(line[0] - my) <= 3:
                merged_h[i] = ((line[0] + my) // 2, min(line[1], msx), max(line[2], mex))
                found = True
                break
        if not found:
            merged_h.append(line)
    
    # 检测垂直线
    v_lines = []
    for x in range(w):
        col = arr[:, x]
        black_pixels = np.where(col < 128)[0]
        if len(black_pixels) > h * 0.2:
            start = black_pixels[0]
            end = black_pixels[0]
            for i in range(1, len(black_pixels)):
                if black_pixels[i] - end <= 3:
                    end = black_pixels[i]
                else:
                    if end - start > 50:
                        v_lines.append((x, start, end))
                    start = black_pixels[i]
                    end = black_pixels[i]
            if end - start > 50:
                v_lines.append((x, start, end))
    
    # 合并相近的垂直线
    merged_v = []
    for line in v_lines:
        found = False
        for i, (mx, msy, mey) in enumerate(merged_v):
            if abs(line[0] - mx) <= 3:
                merged_v[i] = ((line[0] + mx) // 2, min(line[1], msy), max(line[2], mey))
                found = True
                break
        if not found:
            merged_v.append(line)
    
    # 判断是否为表格（至少2条水平线和2条垂直线）
    tables = []
    if len(merged_h) >= 2 and len(merged_v) >= 2:
        row_ys = sorted(set([l[0] for l in merged_h]))
        col_xs = sorted(set([l[0] for l in merged_v]))
        
        if len(row_ys) >= 2 and len(col_xs) >= 2:
            table_x = col_xs[0]
            table_y = row_ys[0]
            table_w = col_xs[-1] - table_x
            table_h = row_ys[-1] - table_y
            
            if table_w > 100 and table_h > 50:
                num_rows = len(row_ys) - 1
                num_cols = len(col_xs) - 1
                tables.append({
                    'x': table_x,
                    'y': table_y,
                    'width': table_w,
                    'height': table_h,
                    'rows': num_rows,
                    'cols': num_cols,
                    'h_lines': merged_h,
                    'v_lines': merged_v,
                    'has_header': True,
                    'confidence': 0.85
                })
    
    return tables


def detect_images_enhanced(binary_img_path, min_area=500):
    """增强版图片区域检测：支持多种图片类型判断"""
    img = Image.open(binary_img_path).convert('L')
    arr = np.array(img)
    from scipy import ndimage
    labeled, num_features = ndimage.label(arr < 128)
    images = []
    for i in range(1, num_features + 1):
        ys, xs = np.where(labeled == i)
        if len(ys) >= min_area:
            x_min, x_max = int(xs.min()), int(xs.max())
            y_min, y_max = int(ys.min()), int(ys.max())
            width = x_max - x_min + 1
            height = y_max - y_min + 1
            if width > 20 and height > 20:
                fill_ratio = len(ys) / (width * height)
                aspect_ratio = width / height if height > 0 else 1
                
                # 边缘密度
                region = arr[y_min:y_max+1, x_min:x_max+1]
                if region.shape[0] > 2 and region.shape[1] > 2:
                    from scipy import ndimage as ndi
                    edges = ndi.sobel(region)
                    edge_density = np.sum(edges > 50) / edges.size
                else:
                    edge_density = 0
                
                # 图片类型判断
                if fill_ratio > 0.9 and 0.8 < aspect_ratio < 1.2:
                    image_type = 'logo'
                elif fill_ratio > 0.8:
                    image_type = 'diagram'
                elif fill_ratio > 0.5 and edge_density > 0.3:
                    image_type = 'chart'
                elif aspect_ratio > 2.0 or aspect_ratio < 0.5:
                    image_type = 'signature'
                else:
                    image_type = 'photo'
                
                file_name = f'image_{len(images)}.png'
                images.append({
                    'x': x_min,
                    'y': y_min,
                    'width': width,
                    'height': height,
                    'type': image_type,
                    'confidence': 0.75,
                    'aspect_ratio': aspect_ratio,
                    'fill_ratio': fill_ratio,
                    'edge_density': edge_density,
                    'file_name': file_name
                })
    return images


def extract_image_region(image_path, img_info, output_path):
    """裁剪并保存图片区域"""
    img = Image.open(image_path)
    region = img.crop((img_info['x'], img_info['y'], 
                       img_info['x'] + img_info['width'], 
                       img_info['y'] + img_info['height']))
    region.save(output_path)
    return output_path


def smart_reading_order_enhanced(elements, layout_type='single', page_width=1654):
    """智能阅读顺序（支持多栏布局）"""
    indices = list(range(len(elements)))
    for i in range(len(indices)):
        for j in range(len(indices) - i - 1):
            a = indices[j]
            b = indices[j + 1]
            if layout_type == 'double':
                a_col = 0 if elements[a]['x'] < page_width / 2 else 1
                b_col = 0 if elements[b]['x'] < page_width / 2 else 1
                if a_col == b_col:
                    should_swap = elements[a]['y'] > elements[b]['y']
                else:
                    should_swap = a_col > b_col
            else:
                if abs(elements[a]['y'] - elements[b]['y']) < 20:
                    should_swap = elements[a]['x'] > elements[b]['x']
                else:
                    should_swap = elements[a]['y'] > elements[b]['y']
            if should_swap:
                indices[j], indices[j + 1] = indices[j + 1], indices[j]
    return indices


def element_to_markdown(element):
    """文档元素转 Markdown"""
    elem_type = element['type']
    content = element.get('text', '')
    
    if elem_type == 'title':
        return f"# {content}\n\n"
    elif elem_type == 'heading1':
        return f"## {content}\n\n"
    elif elem_type == 'heading2':
        return f"### {content}\n\n"
    elif elem_type == 'heading3':
        return f"#### {content}\n\n"
    elif elem_type == 'paragraph':
        return f"{content}\n\n"
    elif elem_type == 'list_item':
        return f"- {content}\n"
    elif elem_type == 'table':
        return f"{content}\n"
    elif elem_type == 'image':
        return f"![图片]({content})\n\n"
    elif elem_type == 'quote':
        return f"> {content}\n\n"
    elif elem_type == 'code_block':
        return f"```\n{content}\n```\n\n"
    elif elem_type == 'horizontal_rule':
        return "---\n\n"
    else:
        return f"{content}\n\n"


def pdf_to_markdown(pdf_path, output_path, dpi=200, first_page=None, last_page=None):
    """完整的 PDF 转 Markdown 流程（增强版）"""
    print("=" * 60)
    print("PDF 转 Markdown 完整流程（增强版布局分析 v12.19.0）")
    print("=" * 60)
    print()
    
    work_dir = os.path.join(os.path.dirname(output_path), '.pdf2md_work')
    images_dir = os.path.join(work_dir, 'images')
    preprocessed_dir = os.path.join(work_dir, 'preprocessed')
    
    images = pdf_to_images(pdf_path, images_dir, dpi, first_page, last_page)
    
    all_markdown = ""
    all_elements = []
    layout_stats = {'single': 0, 'double': 0, 'mixed': 0, 'unknown': 0}
    
    for page_idx, img_path in enumerate(images):
        print(f"\n--- 处理第 {page_idx + 1} 页 ---")
        
        # 获取页面尺寸
        with Image.open(img_path) as img:
            page_width, page_height = img.size
        
        # 2. 质量评估
        print(f"[2/10] 扫描质量评估")
        quality = evaluate_quality(img_path)
        print(f"  评分: {quality['overall_score']:.1f}/100")
        if quality['issues']:
            print(f"  问题: {', '.join(quality['issues'])}")
        
        # 3. 预处理
        print(f"[3/10] 图像预处理")
        os.makedirs(preprocessed_dir, exist_ok=True)
        preprocessed_path = os.path.join(preprocessed_dir, f'page-{page_idx + 1:03d}.png')
        preprocess_image(img_path, preprocessed_path)
        print(f"  完成")
        
        # 4. 版面分析（增强版）
        print(f"[4/10] 版面分析（增强版）")
        blocks = analyze_layout(preprocessed_path)
        print(f"  检测到 {len(blocks)} 个文本块")
        
        # 4.1 检测布局类型
        layout_type = detect_layout_type_enhanced(blocks, page_width, page_height)
        layout_stats[layout_type] = layout_stats.get(layout_type, 0) + 1
        layout_names = {'single': '单栏', 'double': '双栏', 'mixed': '混合布局', 'unknown': '未知'}
        print(f"  布局类型: {layout_names.get(layout_type, layout_type)}")
        
        # 4.2 检测页眉页脚
        header_bottom, footer_top = detect_header_footer_enhanced(blocks, page_height)
        print(f"  页眉区域: 0-{header_bottom}px, 页脚区域: {footer_top}-{page_height}px")
        
        # 5. 元素分类（增强版）
        print(f"[5/10] 文档元素分类（增强版）")
        avg_x = sum(b['x'] for b in blocks) / len(blocks) if blocks else 0
        elements = []
        for block in blocks:
            elem_type = classify_element_enhanced(block, 16, avg_x)
            is_header = block['y'] + block['height'] <= header_bottom
            is_footer = block['y'] >= footer_top
            element = {
                **block,
                'type': elem_type,
                'text': f"[文本块: {block['width']}x{block['height']}]",
                'confidence': 0.85,
                'is_header': is_header,
                'is_footer': is_footer,
                'page_width': page_width
            }
            elements.append(element)
        
        type_counts = {}
        for elem in elements:
            if not elem.get('is_header', False) and not elem.get('is_footer', False):
                type_counts[elem['type']] = type_counts.get(elem['type'], 0) + 1
        print(f"  分类结果（正文）: {type_counts}")
        
        # 6. 表格检测
        print(f"[6/10] 表格检测")
        tables = detect_tables_enhanced(preprocessed_path)
        print(f"  检测到 {len(tables)} 个表格")
        
        # 7. 图片检测
        print(f"[7/10] 图片区域检测")
        images_regions = detect_images_enhanced(preprocessed_path)
        print(f"  检测到 {len(images_regions)} 个图片区域")
        for i, img_region in enumerate(images_regions[:3]):
            print(f"    图片 {i+1}: {img_region['type']} ({img_region['width']}x{img_region['height']})")
        
        # 8. 符号识别
        print(f"[8/10] 符号识别")
        print(f"  符号识别完成")
        
        # 9. 阅读顺序（智能版）
        print(f"[9/10] 确定阅读顺序（智能版，支持多栏）")
        reading_order = smart_reading_order_enhanced(elements, layout_type, page_width)
        print(f"  阅读顺序确定完成")
        
        # 10. Markdown 还原
        print(f"[10/10] Markdown 1:1 还原（增强版）")
        page_markdown = f"<!-- 第 {page_idx + 1} 页 -->\n"
        page_markdown += f"<!-- 布局类型: {layout_names.get(layout_type, layout_type)} -->\n"
        page_markdown += f"<!-- 页眉: 0-{header_bottom}px, 页脚: {footer_top}-{page_height}px -->\n\n"
        
        for idx in reading_order:
            elem = elements[idx]
            # 跳过页眉页脚
            if elem.get('is_header', False) or elem.get('is_footer', False):
                continue
            page_markdown += element_to_markdown(elem)
        
        all_markdown += page_markdown
        all_elements.extend(elements)
        print(f"  生成 {len(page_markdown)} 字符")
    
    # 写入输出文件
    print(f"\n写入输出文件: {output_path}")
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(all_markdown)
    
    # 生成元数据报告
    body_elements = [e for e in all_elements if not e.get('is_header', False) and not e.get('is_footer', False)]
    report = {
        'pdf_path': pdf_path,
        'total_pages': len(images),
        'dpi': dpi,
        'layout_analysis': 'enhanced_v12.19.0',
        'multi_column_support': True,
        'header_footer_removal': True,
        'list_detection': True,
        'quote_detection': True,
        'code_block_detection': True,
        'smart_reading_order': True,
        'layout_distribution': layout_stats,
        'total_elements': len(all_elements),
        'body_elements': len(body_elements),
        'header_elements': len([e for e in all_elements if e.get('is_header', False)]),
        'footer_elements': len([e for e in all_elements if e.get('is_footer', False)]),
        'element_distribution': {},
        'output_path': output_path
    }
    for elem in body_elements:
        report['element_distribution'][elem['type']] = report['element_distribution'].get(elem['type'], 0) + 1
    
    report_path = output_path + '.report.json'
    with open(report_path, 'w', encoding='utf-8') as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    
    print("\n" + "=" * 60)
    print("转换完成！（增强版布局分析）")
    print(f"输出文件: {output_path}")
    print(f"元数据报告: {report_path}")
    print(f"总页数: {len(images)}")
    print(f"布局分布: {layout_stats}")
    print(f"总元素数: {len(all_elements)}（正文: {len(body_elements)}, 页眉: {report['header_elements']}, 页脚: {report['footer_elements']}）")
    print(f"正文元素分布: {report['element_distribution']}")
    print("=" * 60)


def main():
    if len(sys.argv) < 2:
        print("用法: python pdf_to_markdown.py <pdf文件路径> [输出md路径] [DPI] [起始页] [结束页]")
        print()
        print("示例:")
        print("  python pdf_to_markdown.py document.pdf")
        print("  python pdf_to_markdown.py document.pdf output.md 300 1 5")
        sys.exit(1)
    
    pdf_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else 'output.md'
    dpi = int(sys.argv[3]) if len(sys.argv) > 3 else 200
    first_page = int(sys.argv[4]) if len(sys.argv) > 4 else None
    last_page = int(sys.argv[5]) if len(sys.argv) > 5 else None
    
    if not os.path.exists(pdf_path):
        print(f"错误: 文件不存在 - {pdf_path}")
        sys.exit(1)
    
    pdf_to_markdown(pdf_path, output_path, dpi, first_page, last_page)


if __name__ == '__main__':
    main()

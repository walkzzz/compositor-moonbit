#!/usr/bin/env python3
"""
将 PNG 图像转换为 MoonBit 可以读取的原始像素数据格式
输出格式：宽度(4字节) + 高度(4字节) + 通道数(4字节) + 像素数据(RGB)
"""
import struct
import sys
from PIL import Image

def png_to_raw(png_path, raw_path):
    img = Image.open(png_path)
    img = img.convert('RGB')
    width, height = img.size
    pixels = list(img.getdata())
    
    with open(raw_path, 'wb') as f:
        # 写入头部：宽度、高度、通道数
        f.write(struct.pack('<III', width, height, 3))
        # 写入像素数据
        for r, g, b in pixels:
            f.write(bytes([r, g, b]))
    
    print(f"转换完成: {png_path} -> {raw_path}")
    print(f"尺寸: {width}x{height}, 3通道")

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("用法: python png_to_raw.py <input.png> <output.raw>")
        sys.exit(1)
    png_to_raw(sys.argv[1], sys.argv[2])

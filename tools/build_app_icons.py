"""Resize the approved transparent artwork for Android and web launchers."""
from pathlib import Path
import json
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = Image.open(root / 'assets/branding/app-icon.png').convert('RGBA')
assert source.getextrema()[3][0] == 0, 'Source must retain transparency'
source = source.crop(source.getbbox())

def save_icon(path, size):
    art = source.copy()
    art.thumbnail((round(size * .90), round(size * .90)), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (size, size))
    canvas.alpha_composite(art, ((size-art.width)//2, (size-art.height)//2))
    canvas.save(root / path, optimize=True)

for density, size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    save_icon(f'android/app/src/main/res/mipmap-{density}/ic_launcher.png', size)
for size in (192, 512):
    save_icon(f'web/icons/Icon-{size}.png', size)
save_icon('web/favicon.png', 32)
manifest = root / 'web/manifest.json'
data = json.loads(manifest.read_text(encoding='utf-8'))
data['icons'] = [dict(src=f'icons/Icon-{s}.png', sizes=f'{s}x{s}', type='image/png', purpose='any') for s in (192,512)]
manifest.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

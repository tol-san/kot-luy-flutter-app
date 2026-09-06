"""Trace the supplied logo silhouette and derive Android vectors. Build-time only."""
from pathlib import Path
import xml.etree.ElementTree as ET
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
image = Image.open(ROOT / 'assets/logo.png').convert('RGBA')
mask = np.asarray(image)[:, :, 3] >= 128
ys, xs = np.where(mask)
x0, y0, x1, y1 = xs.min(), ys.min(), xs.max()+1, ys.max()+1
mask = mask[y0:y1, x0:x1]
# Trace pixel boundaries, including the original counters inside Khmer letters.
edges = {}
for y, x in zip(*np.where(mask)):
    x, y = int(x), int(y)
    h, w = mask.shape
    for exposed, a, b in [
        (y == 0 or not mask[y-1,x], (x,y),(x+1,y)),
        (x == w-1 or not mask[y,x+1], (x+1,y),(x+1,y+1)),
        (y == h-1 or not mask[y+1,x], (x+1,y+1),(x,y+1)),
        (x == 0 or not mask[y,x-1], (x,y+1),(x,y)),
    ]:
        if exposed: edges.setdefault(a, []).append(b)

def simplify(points, epsilon=.65):
    if len(points) < 3: return points
    a, b = np.array(points[0]), np.array(points[-1])
    delta = b-a
    p = np.array(points)
    length = np.linalg.norm(delta)
    distances = (np.abs(delta[0]*(p[:,1]-a[1])-delta[1]*(p[:,0]-a[0])) / length
                 if length else np.linalg.norm(p-a, axis=1))
    i = int(np.argmax(distances))
    if distances[i] <= epsilon: return [points[0], points[-1]]
    return simplify(points[:i+1], epsilon)[:-1]+simplify(points[i:], epsilon)

contours = []
while edges:
    start = next(iter(edges)); current = start; points = [start]
    while True:
        nxt = edges[current].pop()
        if not edges[current]: del edges[current]
        points.append(nxt); current = nxt
        if current == start: break
    if len(points) > 12:
        mid = len(points)//2
        points = simplify(points[:mid+1])[:-1] + simplify(points[mid:])
        contours.append('M'+' L'.join(f'{x} {y}' for x,y in points)+'Z')
path = ' '.join(contours)
logo = f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><path fill="#00512C" fill-rule="evenodd" d="{path}"/></svg>\n'
(ROOT/'assets/illustrations/kot-luy-logo.svg').write_text(logo)

def vector_paths():
    tree = ET.parse(ROOT/'assets/illustrations/wallet-writing.svg')
    result = []
    for p in tree.iter('{http://www.w3.org/2000/svg}path'):
        a = p.attrib
        fill = a.get('fill', 'none'); stroke = a.get('stroke', '#244D37')
        result.append(f'<path android:pathData="{a["d"]}" android:fillColor="{fill if fill != "none" else "#00000000"}" android:strokeColor="{stroke if stroke != "none" else "#00000000"}" android:strokeWidth="{a.get("stroke-width", "4")}" android:strokeLineCap="round" android:strokeLineJoin="round"/>')
    return '\n'.join(result)

res = ROOT/'android/app/src/main/res'
def write_vector(name, width, height, contents):
    (res/'drawable'/name).write_text(f'<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="{width}dp" android:height="{height}dp" android:viewportWidth="{width}" android:viewportHeight="{height}">{contents}</vector>\n')

logo_path = f'<path android:fillColor="#00512C" android:fillType="evenOdd" android:pathData="{path}"/>'
write_vector('launch_art.xml',300,108,f'<group android:translateY="{(108-300*h/w)/2}" android:scaleX="{300/w}" android:scaleY="{300/w}">{logo_path}</group>')
# Maximize the wordmark while keeping its corners inside the 192dp safe circle.
write_vector('launch_icon.xml',288,288,f'<group android:translateX="54" android:translateY="{(288-180*h/w)/2}" android:scaleX="{180/w}" android:scaleY="{180/w}">{logo_path}</group>')
write_vector('launch_brand.xml',200,80,f'<group android:translateX="10" android:translateY="8" android:scaleX="{180/w}" android:scaleY="{180/w}">{logo_path}</group>')
print(f'Logo traced: {w}x{h}, {len(logo.encode())} bytes')

"""Trace the approved launcher alpha into shared SVG and notification resources."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent


def simplify(points, tolerance=0.65):
    if len(points) < 3:
        return points
    ax, ay = points[0]
    bx, by = points[-1]
    dx, dy = bx - ax, by - ay
    length = dx * dx + dy * dy
    best, index = 0, 0
    for i, (x, y) in enumerate(points[1:-1], 1):
        t = max(0, min(1, ((x-ax)*dx+(y-ay)*dy)/length)) if length else 0
        distance = (x-ax-t*dx)**2+(y-ay-t*dy)**2
        if distance > best:
            best, index = distance, i
    if best > tolerance*tolerance:
        return simplify(points[:index+1], tolerance)[:-1] + simplify(points[index:], tolerance)
    return [points[0], points[-1]]


def generate():
    source = Image.open(ROOT/'tools/icon_sources/mascot/monochrome.png').convert('RGBA').crop((64,64,1190,1190))
    w,h = source.size
    alpha = source.getchannel('A')
    mask = alpha.point(lambda x:255 if x>=128 else 0)
    values = mask.tobytes()
    edges = {}
    def add(a,b):
        edges.setdefault(a,[]).append(b)
    for y in range(h):
        for x in range(w):
            i=y*w+x
            if not values[i]:continue
            if y==0 or not values[i-w]:add((x,y),(x+1,y))
            if x==w-1 or not values[i+1]:add((x+1,y),(x+1,y+1))
            if y==h-1 or not values[i+w]:add((x+1,y+1),(x,y+1))
            if x==0 or not values[i-1]:add((x,y+1),(x,y))
    loops=[]
    while edges:
        start=next(iter(edges));at=start;points=[start]
        while True:
            choices=edges[at]
            nxt=choices.pop()
            if not choices:del edges[at]
            at=nxt;points.append(at)
            if at==start:break
        area=abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(points,points[1:])))/2
        if area<12:continue
        # Split the closed contour before simplification to preserve its shape.
        mid=len(points)//2
        points=simplify(points[:mid+1])[:-1]+simplify(points[mid:])
        loops.append('M'+' '.join(f'{x},{y}' for x,y in points[:-1])+'Z')
    path=' '.join(loops)
    svg=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" fill="none">\n  <path fill="#000" fill-rule="evenodd" d="{path}"/>\n</svg>\n'
    for name in ['assets/mascot/brand-mark.svg','assets/glimpse.svg','assets/mono.svg']:
        (ROOT/name).write_text(svg,encoding='utf-8')
    drawable=ROOT/'android/app/src/main/res/drawable/ic_notification.xml'
    drawable.write_text(f'''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp"
    android:viewportWidth="{w}" android:viewportHeight="{h}">
    <path android:fillColor="#FFFFFFFF" android:fillType="evenOdd"
        android:pathData="{path}" />
</vector>
''',encoding='utf-8')
    for density,size in [('mdpi',24),('hdpi',36),('xhdpi',48),('xxhdpi',72),('xxxhdpi',96)]:
        icon=Image.new('RGBA',(size,size),'white')
        icon.putalpha(alpha.resize((size,size),Image.Resampling.LANCZOS))
        out=ROOT/f'android/app/src/main/res/drawable-{density}/ic_notification.png'
        temp=out.with_suffix('.tmp')
        icon.save(temp,format='PNG',optimize=True);temp.replace(out)
    print(f'Traced {len(loops)} contours; SVG {len(svg)} bytes. Updated all notification densities.')


if __name__=='__main__':
    generate()

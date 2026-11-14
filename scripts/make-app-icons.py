"""Generate committed iPhone icons from the user-selected upstream asset.

Requires Pillow locally; GitHub builds use the committed PNGs directly.
"""
from pathlib import Path
from PIL import Image
import json
root=Path(__file__).resolve().parents[1]
source=root/'ios/IconSource/j2me-coffee.png'
catalog=root/'ios/Assets.xcassets'
out=catalog/'AppIcon.appiconset'
out.mkdir(parents=True,exist_ok=True)
image=Image.open(source).convert('RGBA')
assert image.width==image.height
white=Image.new('RGBA',image.size,'white')
white.alpha_composite(image)
image=white.convert('RGB')
slots=[('iphone','20x20',2,40),('iphone','20x20',3,60),
       ('iphone','29x29',2,58),('iphone','29x29',3,87),
       ('iphone','40x40',2,80),('iphone','40x40',3,120),
       ('iphone','60x60',2,120),('iphone','60x60',3,180),
       ('ios-marketing','1024x1024',1,1024)]
entries=[]
for idiom,size,scale,pixels in slots:
    name=f'icon-{pixels}.png'
    image.resize((pixels,pixels),Image.Resampling.LANCZOS).save(out/name,optimize=True)
    entries.append(dict(idiom=idiom,size=size,scale=f'{scale}x',filename=name))
info=dict(version=1,author='xcode')
(catalog/'Contents.json').write_text(json.dumps(dict(info=info),indent=2)+'\n',encoding='utf-8')
(out/'Contents.json').write_text(json.dumps(dict(images=entries,info=info),indent=2)+'\n',encoding='utf-8')
print('Generated opaque RGB iPhone icons in',out)

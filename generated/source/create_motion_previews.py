
from pathlib import Path
import json
from PIL import Image
root=Path(r"C:\Code\UITxVNG\SE116_Nhom5_UITxVNG\generated")
manifest=json.loads((root/"source/animation_manifest.json").read_text())
for name in ("Idle_Sword","Run_Sword"):
    paths=sorted((root/"diagnostics/motion").glob(name+"_*.png"))
    images=[]
    for path in paths:
        image=Image.open(path).convert("RGB")
        edge=min(image.size)
        left=(image.width-edge)//2
        top=(image.height-edge)//2
        images.append(image.crop((left,top,left+edge,top+edge)).resize((512,512),Image.Resampling.LANCZOS))
    print(name,len(images),images[0].size)
    sheet=Image.new("RGB",(images[0].width*4,images[0].height))
    for i,f in enumerate((images[0],images[len(images)//4],images[len(images)//2],images[3*len(images)//4])):
        sheet.paste(f,(i*f.width,0))
    palette=sheet.quantize(colors=192)
    frames=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in images]
    step=manifest[name]["duration"]*1000/len(frames)
    durations=[max(10,round((i+1)*step/10)*10-round(i*step/10)*10) for i in range(len(frames))]
    destination=root/("preview_run.gif" if name=="Run_Sword" else "preview_idle.gif")
    frames[0].save(destination,save_all=True,append_images=frames[1:],duration=durations,loop=0,disposal=2,optimize=False)
    sheet.resize((1024,256)).save(root/("preview_run_strip.png" if name=="Run_Sword" else "preview_idle_strip.png"))
    print(destination,destination.stat().st_size)


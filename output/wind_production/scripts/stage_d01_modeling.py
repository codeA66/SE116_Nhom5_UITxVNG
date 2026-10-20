import json
from pathlib import Path
root=Path(r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG')
p=root/'output/wind_production/asset_state.json'
d=json.loads(p.read_text(encoding='utf-8'))
d['D01']['state']='modeling'
d['D01']['outstanding']='Connected Blender visual self-check, GLB export, and source save.'
d['current_task']='D01 exact-source fragment is built in connected Blender; finish visual self-check/export/save, then proceed to D02.'
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(d['D01']['state'])

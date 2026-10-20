import json, os, shutil
from datetime import datetime, timezone
ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
concept=ROOT+'/output/wind_production/concepts/i02_concept_v1.png';prompt=ROOT+'/output/wind_production/concepts/i02_prompt.txt'
out=ROOT+'/assets/generated/wind_ruins/i02'
assert os.path.isfile(concept) and os.path.isfile(prompt)
assert not os.path.exists(out),'Refusing to overwrite I02 output folder'
os.makedirs(out+'/source',exist_ok=False);os.makedirs(ROOT+'/output/wind_production/i02',exist_ok=True)
open(out+'/source/.gdignore','w',encoding='utf-8').close();shutil.copy2(concept,out+'/concept.png')
path=ROOT+'/output/wind_production/asset_state.json'
with open(path,'r',encoding='utf-8-sig') as f:state=json.load(f)
assert state['completed_count']==38 and state['production_queue']==['I02'] and 'I02' not in state
stamp=datetime.now(timezone.utc).isoformat().replace('+00:00','Z')
state['I02']={'state':'concept_ready_advisory_pending',
 'spec':'Bridge support pier; 1.2 x 1.2 x 5.4 m. Stable square base, shaft tapering inward about 15%, forked top cradle, one stone-course seam. Intact and broken-leaning with matching foot fragment. Keep shaft segments separate so height changes use modules, not stretching.',
 'dimensions':'1.2 x 1.2 x 5.4 m; source shaft segments separate; no included beam',
 'concept':'output/wind_production/concepts/i02_concept_v1.png','prompt':'output/wind_production/concepts/i02_prompt.txt',
 'generation':'built-in imagegen','concept_generated_utc':stamp,'destination':'assets/generated/wind_ruins/i02/',
 'outstanding':'Sol advisory, then 3D geometry/export/self-check pending.'}
state['next_asset']='I02';state['remaining_catalog_order']=['I02'];state['pending_count']=1
state['active_blender_scene']='WindProduction_I01';state['current_task']='I02 concept ready; awaiting one Sol advisory, then build the bridge support pier.';state['last_updated_utc']=stamp
with open(path,'w',encoding='utf-8') as f:json.dump(state,f,ensure_ascii=False,indent=2);f.write('\n')
print('I02_CONCEPT_CHECKPOINT',stamp,state['I02']['destination'])

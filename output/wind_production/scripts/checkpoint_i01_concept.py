import json, os, shutil
from datetime import datetime, timezone
ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
concept=ROOT+'/output/wind_production/concepts/i01_concept_v1.png'
prompt=ROOT+'/output/wind_production/concepts/i01_prompt.txt'
out=ROOT+'/assets/generated/wind_ruins/i01'
assert os.path.isfile(concept) and os.path.isfile(prompt)
assert not os.path.exists(out), 'Refusing to overwrite I01 output folder'
os.makedirs(out+'/source',exist_ok=False)
os.makedirs(ROOT+'/output/wind_production/i01',exist_ok=True)
open(out+'/source/.gdignore','w',encoding='utf-8').close()
shutil.copy2(concept,out+'/concept.png')
state_path=ROOT+'/output/wind_production/asset_state.json'
with open(state_path,'r',encoding='utf-8-sig') as f: state=json.load(f)
assert state['completed_count']==37 and state['production_queue']==['I01','I02']
assert 'I01' not in state
stamp=datetime.now(timezone.utc).isoformat().replace('+00:00','Z')
state['I01']={
 'state':'concept_ready_advisory_pending',
 'spec':'New modular bridge span; 4 x 4.5 x 0.45 m. Length on X, walking width on Z. Four broad deck slabs, two or three broad underside beams. Intact and diagonal-break variants; broken span used where layout allows a gap. Flat X=+/-2 m end connectors for chaining; do not use old bridge dimensions.',
 'dimensions':'4 x 4.5 x 0.45 m; length X; width Z; connector planes X = +/-2 m',
 'concept':'output/wind_production/concepts/i01_concept_v1.png',
 'prompt':'output/wind_production/concepts/i01_prompt.txt',
 'generation':'built-in imagegen',
 'concept_generated_utc':stamp,
 'destination':'assets/generated/wind_ruins/i01/',
 'outstanding':'Sol advisory, then 3D geometry/export/self-check pending.'
}
state['next_asset']='I01'
state['active_blender_scene']='WindProduction_A05'
state['current_task']='I01 concept ready; awaiting one Sol advisory, then build the modular bridge span.'
state['last_updated_utc']=stamp
with open(state_path,'w',encoding='utf-8') as f: json.dump(state,f,ensure_ascii=False,indent=2);f.write('\n')
print('I01_CONCEPT_CHECKPOINT',stamp,state['I01']['destination'])

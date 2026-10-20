import json
from datetime import datetime, timezone
ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
path=ROOT+'/output/wind_production/asset_state.json'
with open(path,'r',encoding='utf-8-sig') as f: state=json.load(f)
assert state['I01']['state']=='concept_ready_advisory_pending'
advice='Lock the catalog envelope to X=4 m, Z=4.5 m walking width, and 0.45 m total thickness. Compress the concept’s deep timber foundation into this shallow profile; use four broad deck slabs and 2–3 underside beams. Keep X=±2 m as flat, full-section mating faces; terminate curbs and trim flush there so corner posts do not obstruct the walking connection. Carry one diagonal fracture through slabs, edge trim, and underside beams with staggered chipped ends and exposed timber, preserving the original outer connector faces and alignment in both variants.'
stamp=datetime.now(timezone.utc).isoformat().replace('+00:00','Z')
state['I01'].update({'state':'advisory_received_modeling_pending','advisor':'sol_advisor',
 'advisory':advice,'advisory_received_from':'sol_advisor','advisory_received_utc':stamp,
 'modeling_started_utc':stamp,'outstanding':'3D geometry/export/self-check pending.'})
state['current_task']='I01 modeling; approved concept and one Sol advisory received.'
state['last_updated_utc']=stamp
with open(path,'w',encoding='utf-8') as f:json.dump(state,f,ensure_ascii=False,indent=2);f.write('\n')
print('I01_ADVISORY_CHECKPOINT',stamp)

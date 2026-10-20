import json
from datetime import datetime, timezone
ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
path=ROOT+'/output/wind_production/asset_state.json'
with open(path,'r',encoding='utf-8-sig') as f:state=json.load(f)
assert state['I02']['state']=='concept_ready_advisory_pending' and state['completed_count']==38
advice='Keep the intact pier within 1.2 x 1.2 x 5.4 m, including the fork. Use a flat square plinth, a shaft narrowing roughly 15%, and chunky fork arms with a clear central cradle. Separate base, repeatable shaft segments, and cradle in the source; add height by inserting segments and keep join faces flush with one visible stone-course seam. Create the broken state from a shared fracture cut so the leaning upper shaft and lower stump have matching surfaces. Derive the loose foot fragment from the same damaged geometry, and keep the square base planted flat.'
stamp=datetime.now(timezone.utc).isoformat().replace('+00:00','Z')
state['I02'].update({'state':'advisory_received_modeling_pending','advisor':'sol_advisor','advisory':advice,
 'advisory_received_from':'sol_advisor','advisory_received_utc':stamp,'modeling_started_utc':stamp,
 'outstanding':'3D geometry/export/self-check pending.'})
state['current_task']='I02 modeling; approved concept and one Sol advisory received.';state['last_updated_utc']=stamp
with open(path,'w',encoding='utf-8') as f:json.dump(state,f,ensure_ascii=False,indent=2);f.write('\n')
print('I02_ADVISORY_CHECKPOINT',stamp)

"""Persistent MCP helper. Each build/save/export call handles exactly one asset.

Only geometry recipes are read from the disabled first draft. Its staging/export/
partial-library-writing code is never executed. Use initialize(), build(code),
then review, save_source(), and export_current() as separate MCP calls.
"""
import ast
import bpy
import json
import math
import struct
import os
from pathlib import Path
from mathutils import Vector

WORK = Path('C:/Code/UITxVNG/SE116_Nhom5_UITxVNG/output/wind_palace_production')
DEST = Path('C:/Code/UITxVNG/SE116_Nhom5_UITxVNG/assets/generated/wind_ruins/palace')
BACKUP = Path('C:/Code/UITxVNG/blend_backup/wind_palace')
STATE = WORK / 'asset_state.json'

def initialize():
    if 'WP_SAFE' in bpy.app.driver_namespace:
        return {'already_initialized': True}
    source = (WORK / 'build_palace.py').read_text(encoding='utf-8')
    tree = ast.parse(source)
    # Reuse constructors only, never the disabled batch's execution section.
    start = source.index('import bpy, math')
    end = source.index('# Reusable foundations')
    header = source[start:end].replace('WindPalace_Production_v01','WindPalace_SafeProduction_v02').replace("VERSION = 'v01'","VERSION = 'v02'")
    ns = {'__name__':'wind_palace_safe'}
    exec(compile(header,'palace_helpers','exec'), ns)
    for node in tree.body:
        if isinstance(node, ast.FunctionDef) and node.name in ('leaf','emblem'):
            exec(compile(ast.Module(body=[node],type_ignores=[]),'palace_details','exec'),ns)
    recipe_end = source.index('# Stage assets')
    recipes = {}; current = None
    for node in tree.body:
        if node.lineno <= source[:end].count('\n') or node.lineno > source[:recipe_end].count('\n'):
            continue
        if isinstance(node,ast.FunctionDef): continue
        if isinstance(node,ast.For) and isinstance(node.target,ast.Tuple) and any(isinstance(t,ast.Name) and t.id=='code' for t in node.target.elts):
            for values in ast.literal_eval(node.iter):
                prefix=ast.unparse(node.target)+' = '+repr(values)+'\n'
                recipes[values[0]]=prefix+'\n'.join(ast.unparse(x) for x in node.body)
            current=None
            continue
        is_start=isinstance(node,ast.Assign) and isinstance(node.value,ast.Call) and isinstance(node.value.func,ast.Name) and node.value.func.id=='asset'
        if is_start:
            current=ast.literal_eval(node.value.args[0]);recipes[current]=''
        if current is not None: recipes[current]+=ast.unparse(node)+'\n'
    assert len(recipes)==48, f'Expected 48 distinct recipes, got {len(recipes)}'
    ns['recipes']=recipes;ns['current']=None;ns['source_saved']=False
    bpy.app.driver_namespace['WP_SAFE']=ns
    return {'initialized':True,'recipes':list(recipes),'scene':ns['scene'].name}

def build(code):
    ns=bpy.app.driver_namespace['WP_SAFE']
    completed=json.loads(STATE.read_text(encoding='utf-8'))
    if any(x['code']==code and x.get('version')=='v02' for x in completed['assets']):
        raise RuntimeError('Already exported: '+code)
    before=len(ns['assets'])
    exec(compile(ns['recipes'][code],'palace_'+code,'exec'),ns)
    assert len(ns['assets'])==before+1
    a=ns['assets'][-1];ns['current']=a;ns['source_saved']=False
    if code in ('WP_D03','WP_D04','WP_D05'):
        pole=3.7 if code=='WP_D05' else 3.5
        for o in a['objects']:
            if o.name.startswith('BannerSupport'):
                for v in o.data.vertices:v.co.y+=.24
            if o.name.startswith('WindEmblem'):
                for key in o.data.shape_keys.key_blocks:
                    for v in key.data:
                        u=v.co.x/1.1+.5;t=(pole-.08-v.co.z)/2.45
                        v.co.y=-.035+math.sin(t*4+u*1.4)*.10*t-.018+(.12*max(t,0)**1.4 if key.name=='GentleBreeze' else 0)
    # Layout is only a source gallery. Export is reset to origin.
    a['root'].location=((before%8)*6,(before//8)*9,0)
    for obj in a['collection'].objects: obj['palace_asset']=code
    bpy.context.view_layer.update()
    # Show only new asset in viewport without changing stored render visibility.
    for other in ns['assets']:
        for obj in other['collection'].objects: obj.hide_set(other is not a)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in a['collection'].objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=a['root']
    ensure_uv(a)
    tris=sum(len(o.data.polygons) for o in a['objects'])
    assert tris <= (2000 if a['category']=='interactive' else 5000)
    assert all(len(p.vertices)==3 for o in a['objects'] for p in o.data.polygons)
    assert all(o.scale==Vector((1,1,1)) for o in a['objects'])
    bounds=[o.matrix_local@v.co for o in a['objects'] for v in o.data.vertices]
    minimum=[min(p[j] for p in bounds) for j in range(3)]
    maximum=[max(p[j] for p in bounds) for j in range(3)]
    a['triangles']=tris
    a['size']=[round(maximum[j]-minimum[j],4) for j in range(3)]
    # Match artist viewport to the actual object; respect all other scenes.
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':
            from mathutils import Quaternion
            sp=area.spaces.active;sp.shading.type='MATERIAL'
            region=sp.region_3d
            center=Vector([(minimum[j]+maximum[j])/2 for j in range(3)])+a['root'].location
            direction=Vector((1,-1,1.4)).normalized()
            region.view_rotation=direction.to_track_quat('Z','Y')
            region.view_location=center
            region.view_distance=max(a['size'])*1.65+1
            region.view_perspective='ORTHO'
    return dict(code=code,name=a['name'],triangles=tris,size_xyz=a['size'],meshes=[o.name for o in a['objects']],root=a['root'].name)

def save_source():
    ns=bpy.app.driver_namespace['WP_SAFE']
    assert ns['current'] is not None
    BACKUP.mkdir(parents=True,exist_ok=True)
    path=BACKUP/'wind_palace_safe_master_v02.blend'
    bpy.context.view_layer.update()
    # Standard full-file save, never bpy.data.libraries.write(Scene).
    bpy.ops.wm.save_as_mainfile(filepath=str(path),check_existing=False)
    assert path.is_file() and path.stat().st_size>1024
    ns['source_saved']=True
    return dict(saved=str(path),bytes=path.stat().st_size)

def ensure_uv(a):
    # Vertex colors do not need textures, but Godot's default importer needs
    # TEXCOORD_0 to generate tangents. Per-face dominant-axis projection is
    # nondegenerate for these flat-shaded triangles and preserves vertex colors.
    for obj in a['objects']:
        mesh=obj.data
        uv=mesh.uv_layers.get('UVMap') or mesh.uv_layers.new(name='UVMap')
        mesh.update()
        for poly in mesh.polygons:
            major=max(range(3),key=lambda axis:abs(poly.normal[axis]))
            axes=(1,2) if major==0 else ((0,2) if major==1 else (0,1))
            for li in poly.loop_indices:
                co=mesh.vertices[mesh.loops[li].vertex_index].co
                uv.data[li].uv=(co[axes[0]],co[axes[1]])
        mesh.uv_layers.active=uv

def export_current(repair=False):
    ns=bpy.app.driver_namespace['WP_SAFE'];a=ns['current']
    assert ns['source_saved'], 'Save source before export'
    dest=DEST/a['code'];dest.mkdir(parents=True,exist_ok=True)
    path=dest/(a['code']+'_'+a['name']+'_v02.glb')
    assert repair or not path.exists(), 'Do not overwrite an existing export'
    if repair:
        recorded=json.loads(STATE.read_text(encoding='utf-8'))
        assert any(x['code']==a['code'] and x.get('version')=='v02' and x['glb']==str(path) for x in recorded['assets']), 'Only repair this production run exports'
    staging=DEST.parents[3]/'.godot/wind_palace_export_staging'
    staging.mkdir(parents=True,exist_ok=True)
    staged=staging/path.name
    old_location=a['root'].location.copy()
    try:
        a['root'].location=(0,0,0)
        a['collection'].hide_render=False
        bpy.context.view_layer.update()
        bpy.ops.object.select_all(action='DESELECT')
        for o in a['collection'].objects:
            o.hide_set(False)
            o.select_set(True)
        bpy.context.view_layer.objects.active=a['root']
        props={p.identifier for p in bpy.ops.export_scene.gltf.get_rna_type().properties}
        opts=dict(filepath=str(staged),export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_apply=True,export_animations=True,export_cameras=False,export_lights=False,export_texcoords=True,export_tangents=True)
        if 'export_all_vertex_colors' in props:opts['export_all_vertex_colors']=True
        if any(o.data.shape_keys for o in a['objects']):opts['export_animation_mode']='SCENE'
        bpy.ops.export_scene.gltf(**opts)
        raw=staged.read_bytes();magic,version,length=struct.unpack_from('<III',raw)
        assert magic==0x46546C67 and version==2 and length==len(raw)
        size,kind=struct.unpack_from('<II',raw,12);assert kind==0x4E4F534A
        gltf=json.loads(raw[20:20+size])
        assert not gltf.get('images') and not gltf.get('textures')
        assert not gltf.get('cameras') and not gltf.get('extensions',{}).get('KHR_lights_punctual')
        for mesh in gltf['meshes']:
            for prim in mesh['primitives']:
                for required in ('COLOR_0','TEXCOORD_0','TANGENT'):
                    assert required in prim['attributes'], 'Missing '+required
        assert len(gltf.get('materials',[]))<=2
        os.replace(staged,path)
        a['glb']=str(path)
        data=json.loads(STATE.read_text(encoding='utf-8'))
        data['status']='production_in_progress';data['batch_script_disabled']=True
        data['source_blend_saved']=True
        data['source_master']=str(BACKUP/'wind_palace_safe_master_v02.blend')
        old=next((x for x in data['assets'] if x['code']==a['code'] and x.get('version')=='v02'),{})
        data['assets']=[x for x in data['assets'] if not (x['code']==a['code'] and x.get('version')=='v02')]
        data['assets'].append(dict(old,code=a['code'],name=a['name'],version='v02',category=a['category'],status='uv_tangents_checked_pending_godot',glb=str(path),blend=data['source_master'],triangles=a['triangles'],size_blender_xyz=a['size'],materials=len(gltf.get('materials',[])),meshes=len(gltf.get('meshes',[])),animations=len(gltf.get('animations',[])),uv0=True,tangents=True,notes=a['notes']))
        STATE.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
        return dict(exported=str(path),bytes=len(raw),materials=len(gltf.get('materials',[])),animations=len(gltf.get('animations',[])))
    finally:
        a['root'].location=old_location
        bpy.context.view_layer.update()

def current_preview_setup():
    ns=bpy.app.driver_namespace['WP_SAFE'];a=ns['current'];s=ns['scene']
    for item in ns['assets']:
        item['collection'].hide_render=item is not a
    target=a['root'].location+Vector((0,0,a['size'][2]*.45))
    camera=s.objects.get('WP_PreviewCamera')
    if camera is None:
        camera=bpy.data.objects.new('WP_PreviewCamera',bpy.data.cameras.new('WP_PreviewCamera'))
        s.collection.objects.link(camera)
    camera.data.type='ORTHO';camera.data.ortho_scale=max(a['size'])*1.7+1
    camera.location=target+Vector((8,-12,12));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();s.camera=camera
    for name,offset,power,size in [('WP_Key',(-4,-6,10),1700,6),('WP_Fill',(5,3,7),900,5)]:
        light=s.objects.get(name)
        if light is None:
            light=bpy.data.objects.new(name,bpy.data.lights.new(name,'AREA'));s.collection.objects.link(light)
        light.location=target+Vector(offset);light.rotation_euler=(target-light.location).to_track_quat('-Z','Y').to_euler()
        light.data.energy=power;light.data.shape='DISK';light.data.size=size
    if s.world is None:s.world=bpy.data.worlds.new('WP_PreviewWorld')
    s.world.use_nodes=True
    bg=next(n for n in s.world.node_tree.nodes if n.type=='BACKGROUND')
    bg.inputs['Color'].default_value=(.07,.10,.13,1);bg.inputs['Strength'].default_value=.6
    s.render.resolution_x=800;s.render.resolution_y=700;s.render.resolution_percentage=100
    preview=DEST/a['code']/(a['code']+'_preview_v02.png');s.render.filepath=str(preview)
    return {'camera':camera.name,'preview':str(preview)}

def render_preview():
    ns=bpy.app.driver_namespace['WP_SAFE'];a=ns['current'];s=ns['scene']
    current_preview_setup()
    original=s.render.engine
    try:
        s.render.engine='BLENDER_WORKBENCH'
        s.display.shading.color_type='VERTEX'
        s.display.shading.light='STUDIO'
        s.display.shading.show_shadows=True
        s.display.shading.show_cavity=True
        s.display.shading.cavity_type='BOTH'
        s.display.shading.background_type='WORLD'
        s.world.color=(.035,.055,.07)
        s.render.resolution_x=640;s.render.resolution_y=560
        s.render.image_settings.file_format='PNG'
        bpy.ops.render.render(write_still=True)
    finally:
        s.render.engine=original
    data=json.loads(STATE.read_text(encoding='utf-8'))
    for row in data['assets']:
        if row['code']==a['code'] and row.get('version')=='v02':
            row['preview']=s.render.filepath
    STATE.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    return {'preview':s.render.filepath}

print('Safe production helper loaded; use initialize(), build(code), save_source(), export_current() separately.')

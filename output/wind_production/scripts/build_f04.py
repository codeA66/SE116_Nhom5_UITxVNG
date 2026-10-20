import bpy, json, math, os, bmesh
from mathutils import Matrix, Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/f04'
PRE=ROOT+'/output/wind_production/f04'
CONCEPT=ROOT+'/output/wind_production/concepts/f04_concept_v1.png'
PROMPT=ROOT+'/output/wind_production/concepts/f04_prompt.txt'
GLB=OUT+'/f04_secondary_horizontal_banner.glb'

def source_depth(x,z):
    t=(4.3-z)/2.4;q=(x+.6)/1.2
    return -.16-.20*t*t+.095*math.sin(q*2*math.pi+.3)*t+.045*math.sin(q*4*math.pi)*t

def panel_depth(q,t):
    return -.055-.025*t+.035*math.sin(q*2*math.pi+.3)*math.sin(math.pi*t)+.017*math.sin(q*4*math.pi)*math.sin(math.pi*t)

def copy_faces(src_mesh,face_indices,name,transform):
    faces_src=[src_mesh.polygons[i] for i in face_indices]
    used=sorted({v for p in faces_src for v in p.vertices})
    remap={old:i for i,old in enumerate(used)}
    coords=[transform(src_mesh.vertices[i].co.copy()) for i in used]
    faces=[tuple(remap[v] for v in p.vertices) for p in faces_src]
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(coords,[],faces);me.update()
    for m in src_mesh.materials:me.materials.append(m)
    src_color=src_mesh.color_attributes.get('Color');assert src_color,'F01 Color attribute missing'
    ca=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    uv_layers=[me.uv_layers.new(name=layer.name) for layer in src_mesh.uv_layers]
    old_lookup={}
    for p in faces_src:
        for li in p.loop_indices:old_lookup[(p.index,src_mesh.loops[li].vertex_index)]=li
    for newp,oldp in zip(me.polygons,faces_src):
        for nli,oldvi in zip(newp.loop_indices,oldp.vertices):
            oli=old_lookup[(oldp.index,oldvi)]
            ca.data[nli].color=src_color.data[oli].color
            for k,layer in enumerate(uv_layers):layer.data[nli].uv=src_mesh.uv_layers[k].data[oli].uv
    return me

def linked_copy(src,collection,root,name,transform=None):
    ob=src.copy();ob.data=src.data.copy();ob.name=name;collection.objects.link(ob)
    ob.parent=root;ob.matrix_parent_inverse=Matrix.Identity(4);ob.matrix_basis=Matrix.Identity(4)
    if transform:
        for v in ob.data.vertices:v.co=transform(v.co.copy())
        ob.data.update()
    return ob

def area_light(collection,name,loc,power,size,target):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    ob=bpy.data.objects.new(name,data);collection.objects.link(ob);ob.location=loc
    ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler();return ob

def main():
    default=bpy.data.scenes.get('Scene')
    assert default and all(default.objects.get(n) for n in ('Cube','Camera','Light')),'Original default scene must remain intact'
    assert all(os.path.isfile(p) for p in (CONCEPT,PROMPT)),'F04 concept and prompt must exist before modeling'
    assert not os.path.exists(GLB),'Refusing to overwrite an existing F04 GLB'
    old=bpy.data.scenes.get('WindProduction_F04')
    if old:
        bpy.context.window.scene=default
        for ob in list(old.objects):bpy.data.objects.remove(ob,do_unlink=True)
        bpy.data.scenes.remove(old)
    f01=bpy.data.collections['F01_Export'];root_src=f01.objects['F01_WindMainBanner']
    cloth_src=f01.objects['Cloth_Wind_Animated']
    assert root_src and cloth_src
    os.makedirs(OUT+'/source',exist_ok=True);os.makedirs(PRE,exist_ok=True)
    open(OUT+'/source/.gdignore','a',encoding='utf-8').close()
    scene=bpy.data.scenes.new('WindProduction_F04');bpy.context.window.scene=scene
    scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1.0
    export=bpy.data.collections.new('F04_Export');scene.collection.children.link(export)
    preview=bpy.data.collections.new('F04_Preview_ONLY');scene.collection.children.link(preview)
    source=bpy.data.collections.new('F04_Source_NOT_EXPORTED');scene.collection.children.link(source)
    root=bpy.data.objects.new('F04_Secondary_Horizontal_Banner',None);export.objects.link(root)
    root['catalog']='F04 secondary horizontal wind banner derived directly from F01'
    root['pivot']='pole center at ground; Blender Z=0, Godot Y=0'
    root['dimensions_design_m']='pole4.2; cloth2.4x1.2; top3.7; hem2.5; crossbar2.64'
    root['emblem']='exact F01 open C-ring and three same-direction strokes, original proportions'
    root['placement']='sparse side banner beside the wind path'
    ratio=(4.2-.25)/(4.8-.25)
    def scale_pole(p):return Vector((p.x,p.y,.25+(p.z-.25)*ratio))
    # Stone foot and collars retain the exact F01 source geometry and palette.
    for name in ('Foot_Stone','Foot_Collar'):
        linked_copy(f01.objects[name],export,root,'F04_'+name)
    linked_copy(f01.objects['Pole_Octagonal'],export,root,'F04_Pole_Octagonal',scale_pole)
    linked_copy(f01.objects['Upper_Collar'],export,root,'F04_Upper_Collar',scale_pole)
    # Widen the original F01 crossbar while keeping its depth/profile and its
    # hardware dimensions. End blocks remain just outside the 2.4 m fabric.
    cross_src=f01.objects['Crossbar'];bar_w=2.64;bar_center=3.745
    def scale_bar(p):return Vector((p.x*(bar_w/1.55),p.y,bar_center+(p.z-4.3)*ratio))
    linked_copy(cross_src,export,root,'F04_Crossbar',scale_bar)
    for sign in (-1,1):
        n='Crossbar_End_'+str(sign);ob_src=f01.objects[n]
        shift=sign*(bar_w/2-.0325-.7425)
        def scale_end(p,shift=shift):return Vector((p.x+shift,p.y,bar_center+(p.z-4.3)*ratio))
        linked_copy(ob_src,export,root,'F04_'+n,scale_end)
    # Split the exact F01 cloth object into one clean fabric panel and one exact
    # emblem mesh. The symbol keeps its original 0.8 x 0.85 m shape/proportions.
    ngrid=17*25
    grid_faces=[p.index for p in cloth_src.data.polygons if all(i<ngrid for i in p.vertices)]
    logo_faces=[p.index for p in cloth_src.data.polygons if not all(i<ngrid for i in p.vertices)]
    assert len(grid_faces)==16*24 and len(logo_faces)==224
    def panel_map(v):
        x,y,z=v
        t=max(0.0,min(1.0,(4.3-z)/2.4));q=max(0.0,min(1.0,(x+.6)/1.2))
        return Vector((2*x,panel_depth(q,t),3.7-1.2*t))
    panel_mesh=copy_faces(cloth_src.data,grid_faces,'F04_Cloth_Panel',panel_map)
    panel=bpy.data.objects.new('F04_Cloth_Panel_2p4x1p2',panel_mesh);export.objects.link(panel)
    panel.parent=root;panel.matrix_parent_inverse=Matrix.Identity(4);panel.matrix_basis=Matrix.Identity(4)
    panel['part_role']='single horizontal cream cloth panel; 2.4 x 1.2 m; top attached to crossbar'
    panel['dimensions']='world X width 2.4 m; Blender Z 2.5..3.7 m'
    panel['uv_direction']='source F01 WindUV_TopAnchorU0 retained; u=0 top attachment, u=1 free hem'
    panel['surface']='two broad shallow billows; smooth top edge and clean hem'
    src_logo_vertices=sorted({i for fi in logo_faces for i in cloth_src.data.polygons[fi].vertices})
    srcpts=[cloth_src.data.vertices[i].co for i in src_logo_vertices]
    logo_center_x=(min(v.x for v in srcpts)+max(v.x for v in srcpts))*.5
    logo_center_z=(min(v.z for v in srcpts)+max(v.z for v in srcpts))*.5
    def emblem_map(v):
        sx,sy,sz=v
        x=sx-logo_center_x;z=sz-logo_center_z+3.1
        q=max(0.0,min(1.0,(x+1.2)/2.4));t=max(0.0,min(1.0,(3.7-z)/1.2))
        relief=sy-source_depth(sx,sz)
        return Vector((x,panel_depth(q,t)+.5*relief-.003,z))
    emblem_mesh=copy_faces(cloth_src.data,logo_faces,'F04_ExactF01Emblem',emblem_map)
    emblem=bpy.data.objects.new('F04_Emblem_ExactF01_OpenRing_ThreeStrokes',emblem_mesh);export.objects.link(emblem)
    emblem.parent=root;emblem.matrix_parent_inverse=Matrix.Identity(4);emblem.matrix_basis=Matrix.Identity(4)
    emblem['part_role']='exact F01 emblem, translated/centered at original proportions; no horizontal stretch'
    emblem['source_vertices']=len(src_logo_vertices);emblem['source_faces']=len(logo_faces)
    emblem['surface']='projected onto matching F04 cloth billows with the original vertex-color emblem geometry'
    note=bpy.data.objects.new('F04_Source_F01PivotUVAndLogo_Note',None);source.objects.link(note)
    note.hide_render=True;note.hide_set(True);note['source_only']=True
    note['source']='F01 source components copied and transformed non-destructively; original scene unchanged.'
    note['emblem']='464 original F01 emblem vertices and 224 faces; one shared material, original proportion.'
    meshes=[o for o in export.objects if o.type=='MESH']
    assert len(meshes)==9,[o.name for o in meshes]
    assert len({m.name for o in meshes for m in o.data.materials})==1
    assert all(o.data.color_attributes.get('Color') for o in meshes)
    assert panel.data.uv_layers.get('WindUV_TopAnchorU0') and emblem.data.uv_layers.get('WindUV_TopAnchorU0')
    assert abs(max(v.co.z for v in f01.objects['Pole_Octagonal'].data.vertices)-4.8)<.001
    assert all(default.objects.get(n) for n in ('Cube','Camera','Light'))
    # Preview-only actual fox and studio scene; no guide geometry enters export.
    gm=bpy.data.meshes.new('F04_PreviewGround_Mesh');gm.from_pydata([(-30,-30,-.015),(30,-30,-.015),(30,30,-.015),(-30,30,-.015)],[],[(0,1,2,3)])
    ground_mat=bpy.data.materials.new('F04_PreviewGround_Material');ground_mat.use_nodes=True
    bs=next(n for n in ground_mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(.055,.060,.064,1);bs.inputs['Roughness'].default_value=.9
    gm.materials.append(ground_mat);ground=bpy.data.objects.new('F04_PreviewGround',gm);preview.objects.link(ground)
    world=bpy.data.worlds.new('F04_PreviewWorld');world.use_nodes=True;bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.13,.15,.18,1);bg.inputs['Strength'].default_value=.45;scene.world=world
    area_light(preview,'F04_Key',(-5,-7,10),1500,7,(0,0,2));area_light(preview,'F04_Fill',(6,-3,7),750,5,(0,0,2));area_light(preview,'F04_Rim',(0,5,8),1100,5,(0,0,2))
    cd=bpy.data.cameras.new('F04_PreviewCamera_Data');cam=bpy.data.objects.new('F04_PreviewCamera',cd);preview.objects.link(cam);scene.camera=cam
    cam.location=(5,-8,6);cam.rotation_euler=(Vector((0,0,2))-cam.location).to_track_quat('-Z','Y').to_euler();cd.type='PERSP';cd.sensor_fit='VERTICAL';cd.sensor_height=24;cd.lens=42
    before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb');imported=list(set(bpy.data.objects)-before)
    rig=next((o for o in imported if o.type=='ARMATURE'),None);assert rig,'Actual fox GLB import failed'
    for ob in imported:
        old=ob.name
        for col in list(ob.users_collection):col.objects.unlink(ob)
        preview.objects.link(ob);ob.name='F04_Fox_'+old.replace('.','_')
        if any(k in old.lower() for k in ('icosphere','sword')):ob.hide_render=True;ob.hide_set(True)
    idle=next((a for a in bpy.data.actions if a.name=='Idle'),None);assert idle,'Idle fox action missing'
    if not rig.animation_data:rig.animation_data_create()
    rig.animation_data.action=idle;rig.location=(1.75,-1.35,0);scene.frame_set(1)
    for im in bpy.data.images:
        if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
    scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True;scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.05
    scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
    print('F04_BUILD_READY',json.dumps({'scene':scene.name,'root':root.name,'mesh_parts':len(meshes),'panel_dimensions_design_m':[2.4,1.2],'panel_bounds_z_m':[2.5,3.7],'pole_tip_m':4.2,'crossbar_width_m':bar_w,'emblem_vertices':len(src_logo_vertices),'emblem_faces':len(logo_faces),'emblem_original_proportion':True,'shared_material':meshes[0].data.materials[0].name,'default_scene_preserved':True,'fox_action':rig.animation_data.action.name}))

main()

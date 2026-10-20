import bpy,bmesh,math,os,json
from mathutils import Vector

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/p01'
PRE=ROOT+'/output/wind_production/p01'
CONCEPT=ROOT+'/output/wind_production/concepts/p01_concept_v1.png'
PROMPT=ROOT+'/output/wind_production/concepts/p01_prompt.txt'

def linhex(h):
    q=[int(h[i:i+2],16)/255 for i in (1,3,5)]
    return tuple(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in q)+(1,)

COLORS={
 'stone_dark':linhex('#41413F'),'stone_base':linhex('#55554F'),'stone_light':linhex('#68675F'),
 'wood_dark':linhex('#34332F'),'wood_base':linhex('#49463E'),'wood_light':linhex('#5A554B'),
 'glass_off':linhex('#77776C'),'fracture':linhex('#77746A'),'glow':linhex('#F0EBDD')}

def shared_material():
    m=bpy.data.materials.new('P01_Shared_WeatheredStoneWood_VertexColor');m.use_nodes=True
    bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value=(1,1,1,1);bs.inputs['Roughness'].default_value=.91
    vc=m.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='Color';m.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color'])
    return m

def emission_material():
    m=bpy.data.materials.new('P01_Separate_WarmWhite_Glow');m.use_nodes=True
    nodes=m.node_tree.nodes;links=m.node_tree.links
    bs=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Roughness'].default_value=.68
    vc=nodes.new('ShaderNodeVertexColor');vc.layer_name='Color';links.new(vc.outputs['Color'],bs.inputs['Base Color'])
    emission=bs.inputs.get('Emission Color')
    if emission:emission.default_value=(*COLORS['glow'][:3],1)
    strength=bs.inputs.get('Emission Strength')
    if strength:strength.default_value=.85
    else:raise RuntimeError('Blender Principled BSDF has no emission strength socket')
    return m

def color_for(name,normal,base):
    nl=Vector(normal).normalized()
    if base.startswith('stone') or base=='fracture':
        if nl.z>.65:return COLORS['stone_light'] if base!='fracture' else COLORS['fracture']
        if nl.z<-.65:return COLORS['stone_dark']
        if abs(nl.x)>.75:return COLORS['stone_base']
        return COLORS['stone_dark'] if nl.y<0 else COLORS['stone_base']
    if base.startswith('wood'):
        if nl.z>.65:return COLORS['wood_light']
        if nl.z<-.65:return COLORS['wood_dark']
        return COLORS['wood_base'] if nl.y>=0 else COLORS['wood_dark']
    return COLORS.get(base,COLORS['stone_base'])

def make_mesh(collection,name,verts,faces,mat,color_key,role,props=None,triangulate_ngons=True):
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(verts,[],faces);me.update()
    bm=bmesh.new();bm.from_mesh(me)
    if triangulate_ngons:
        ngon=[f for f in bm.faces if len(f.verts)>4]
        if ngon:bmesh.ops.triangulate(bm,faces=ngon,quad_method='BEAUTY',ngon_method='BEAUTY')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();me.update()
    me.materials.append(mat)
    ca=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    ob=bpy.data.objects.new(name,me);collection.objects.link(ob)
    for poly in me.polygons:
        rgb=color_for(name,poly.normal,color_key)
        for li in poly.loop_indices:ca.data[li].color=rgb
    ob['part_role']=role
    for k,v in (props or {}).items():ob[k]=v
    return ob

def beveled_box(collection,name,center,size,mat,color_key,role,bevel=.012):
    cx,cy,cz=center;dx,dy,dz=[s/2 for s in size]
    verts=[(cx+sx*dx,cy+sy*dy,cz+sz*dz) for sx,sy,sz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    # Apply a single broad chamfer while retaining flat faces and a closed solid.
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(verts,[],faces);me.update()
    bm=bmesh.new();bm.from_mesh(me)
    if bevel>0:
        bmesh.ops.bevel(bm,geom=list(bm.verts)+list(bm.edges),offset=bevel,segments=1,affect='EDGES',profile=.5)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();me.update();me.materials.append(mat)
    ca=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    ob=bpy.data.objects.new(name,me);collection.objects.link(ob)
    for p in me.polygons:
        rgb=color_for(name,p.normal,color_key)
        for li in p.loop_indices:ca.data[li].color=rgb
    ob['part_role']=role;ob['bevel_width_m']=bevel
    return ob

def oct_frustum(collection,name,center_xy,z0,z1,r0,r1,mat,color_key,role,n=8):
    cx,cy=center_xy;verts=[]
    for z,r in ((z0,r0),(z1,r1)):
        for i in range(n):
            a=math.pi/8+i*2*math.pi/n
            verts.append((cx+r*math.cos(a),cy+r*math.sin(a),z))
    faces=[tuple(reversed(range(n))),tuple(n+i for i in range(n))]
    for i in range(n):faces.append((i,(i+1)%n,n+(i+1)%n,n+i))
    return make_mesh(collection,name,verts,faces,mat,color_key,role,{'cross_section_sides':n})

def roof_slope(collection,name,profile,depth,mat,color_key,role):
    # profile is a broad X/Z outline extruded along Y; intentional notches become broad break planes.
    n=len(profile);verts=[]
    for y in (-depth/2,depth/2):verts.extend((x,y,z) for x,z in profile)
    faces=[tuple(reversed(range(n))),tuple(n+i for i in range(n))]
    for i in range(n):faces.append((i,(i+1)%n,n+(i+1)%n,n+i))
    return make_mesh(collection,name,verts,faces,mat,color_key,role,{'profile':'two-plane gable roof, broad planar facets'})

def parent_mesh(ob,root):
    ob.parent=root;ob.matrix_parent_inverse=type(ob.matrix_parent_inverse).Identity(4)

def measure(root):
    obs=[o for o in root.children_recursive if o.type=='MESH']
    pts=[v.co for o in obs for v in o.data.vertices]
    lo=[min(v[i] for v in pts) for i in range(3)];hi=[max(v[i] for v in pts) for i in range(3)]
    health=[];tris=0
    for ob in obs:
        ob.data.calc_loop_triangles();count=len(ob.data.loop_triangles);tris+=count
        bm=bmesh.new();bm.from_mesh(ob.data)
        health.append({'mesh':ob.name,'triangles':count,'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),
            'boundary_edges':sum(e.is_boundary for e in bm.edges),'loose_edges':sum(len(e.link_faces)==0 for e in bm.edges),
            'loose_vertices':sum(len(v.link_edges)==0 for v in bm.verts)});bm.free()
    return {'bounds_min_blender_m':lo,'bounds_max_blender_m':hi,
        'dimensions_blender_xyz_m':[hi[i]-lo[i] for i in range(3)],
        'dimensions_godot_xyz_m':[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]],'mesh_parts':len(obs),'triangles':tris,
        'non_manifold_edges':sum(h['non_manifold_edges'] for h in health),'boundary_edges':sum(h['boundary_edges'] for h in health),
        'loose_edges':sum(h['loose_edges'] for h in health),'loose_vertices':sum(h['loose_vertices'] for h in health),'mesh_health':health}

def construct_variant(collection,root,mat,emissive,variant):
    prefix='P01_'+variant
    def box(key,center,size,color,role,bevel=.012):
        parent_mesh(beveled_box(collection,prefix+'_'+key,center,size,mat,color,role,bevel),root)
    def octa(key,center,z0,z1,r0,r1,color,role):
        parent_mesh(oct_frustum(collection,prefix+'_'+key,center,z0,z1,r0,r1,mat,color,role),root)
    # Same bottom-center pivot, base, post and chamber framing in all states.
    box('Base_Foot',(0,0,.055),(.50,.50,.11),'stone_base','compact_foot',.018)
    octa('Foot_Taper',(0,0),.11,.30,.205,.128,'stone_base','single_tapered_foot')
    octa('Slender_Post',(0,0),.28,.82,.067,.060,'wood_base','slender_main_post')
    box('Chamber_Sill',(0,0,.835),(.43,.43,.045),'stone_base','chamber_sill',.008)
    # A square open frame around one large inset panel, with a dark rear backing and open front.
    zlo=.875;zhi=1.375;zc=(zlo+zhi)/2;h=zhi-zlo
    for side,x in (('Left',-.176),('Right',.176)):
        box('Front_'+side+'_Pillar',(x,-.196,zc),(.045,.042,h),'wood_base','front_window_pillar',.008)
        box('Rear_'+side+'_Pillar',(x,.184,zc),(.045,.042,h),'wood_base','rear_window_pillar',.008)
    for face,y in (('Front',-.196),('Rear',.184)):
        box(face+'_Header',(0,y,zhi-.018),(.39,.042,.036),'wood_dark','window_header',.006)
        box(face+'_Lower_Rail',(0,y,zlo+.018),(.39,.042,.036),'wood_base','window_lower_rail',.006)
    box('Left_Side_Panel',(-.195,-.006,zc),(.016,.34,h-.07),'stone_dark','chamber_side_wall',.003)
    box('Right_Side_Panel',(.195,-.006,zc),(.016,.34,h-.07),'stone_dark','chamber_side_wall',.003)
    box('Rear_Back_Panel',(0,.174,zc),(.31,.014,h-.075),'stone_dark','chamber_backing',.003)
    panel_color='glass_off' if variant!='Lit' else 'glow'
    panelmat=emissive if variant=='Lit' else mat
    panel=beveled_box(collection,prefix+'_Separate_Inset_LightPanel',(0,-.161,zc),(.285,.012,.365),panelmat,panel_color,'separate_switchable_light_panel',.002)
    panel['emission_strength']=.85 if variant=='Lit' else 0.0
    panel['same_geometry_across_unlit_and_lit_states']=True;parent_mesh(panel,root)
    # Exactly two broad gable planes, no extra ridge cap or roof tiers.
    left=[(-.25,1.445),(0,1.600),(0,1.558),(-.25,1.403)]
    right=[(0,1.600),(.25,1.445),(.25,1.403),(0,1.558)]
    parent_mesh(roof_slope(collection,prefix+'_Roof_LeftSlope',left,.50,mat,'stone_base','one_of_two_roof_slopes'),root)
    if variant=='Broken':
        # Remove the inner upper corner of the right slope with three broad, deliberate cuts.
        damaged=[(.12,1.5256),(.25,1.445),(.25,1.403),(.12,1.4836),(.13,1.497),(.15,1.507)]
        roof=roof_slope(collection,prefix+'_Roof_Broken_RightSlope',damaged,.50,mat,'fracture','broken_upper_corner_2_3_broad_planes')
        roof['missing_upper_corner']=True;roof['broad_fracture_planes']=3;parent_mesh(roof,root)
    else:
        parent_mesh(roof_slope(collection,prefix+'_Roof_RightSlope',right,.50,mat,'stone_base','one_of_two_roof_slopes'),root)

def area_light(collection,name,loc,power,size,target):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    obj=bpy.data.objects.new(name,data);collection.objects.link(obj);obj.location=loc;obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler();return obj

def main():
    default=bpy.data.scenes.get('Scene');assert default and all(default.objects.get(n) for n in ('Cube','Camera','Light')),'Original default scene must remain intact'
    assert not os.path.isfile(OUT+'/p01_ceremonial_lantern.glb'),'Refusing to overwrite existing P01 GLB'
    previous=bpy.data.scenes.get('WindProduction_P01')
    if previous:
        bpy.context.window.scene=default;old=list(previous.objects);bpy.data.scenes.remove(previous)
        for ob in old:
            if bpy.data.objects.get(ob.name):bpy.data.objects.remove(ob,do_unlink=True)
        for blocks in (bpy.data.meshes,bpy.data.curves,bpy.data.cameras,bpy.data.lights,bpy.data.materials,bpy.data.worlds):
            for block in list(blocks):
                if block.name.startswith('P01_') and block.users==0:blocks.remove(block)
        for c in list(bpy.data.collections):
            if c.name.startswith('P01_') and c.users==0:bpy.data.collections.remove(c)
    assert os.path.isfile(CONCEPT) and os.path.isfile(PROMPT),'Save actual P01 concept and prompt first'
    os.makedirs(OUT+'/source',exist_ok=True);os.makedirs(PRE,exist_ok=True);open(OUT+'/source/.gdignore','w').close()
    scene=bpy.data.scenes.new('WindProduction_P01');bpy.context.window.scene=scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
    export=bpy.data.collections.new('P01_Export');scene.collection.children.link(export)
    preview=bpy.data.collections.new('P01_Preview_ONLY');scene.collection.children.link(preview)
    source=bpy.data.collections.new('P01_Source_NOT_EXPORTED');scene.collection.children.link(source)
    mat=shared_material();emissive=emission_material();roots=[]
    for variant,loc in [('Off',(-1.35,0,0)),('Broken',(0,0,0)),('Lit',(1.35,0,0))]:
        root=bpy.data.objects.new('P01_Lantern_'+variant,None);export.objects.link(root);root.location=loc
        root['variant']=variant.lower();root['dimensions_target_m']=[.5,.5,1.6];root['pivot']='bottom center between feet; local Z=0'
        root['light_panel']='separate mesh; identical geometry in off/lit; material-only activation'
        construct_variant(export,root,mat,emissive,variant);roots.append(root)
    measurements={r.name:measure(r) for r in roots}
    for r in roots:
        m=measurements[r.name]
        assert m['mesh_parts']==18 and m['non_manifold_edges']==m['boundary_edges']==m['loose_edges']==m['loose_vertices']==0,(r.name,m)
        assert all(abs(m['dimensions_blender_xyz_m'][i]-[.5,.5,1.6][i])<.002 for i in range(3)),(r.name,m)
        assert all(abs(m['bounds_min_blender_m'][i]+m['bounds_max_blender_m'][i])<.002 for i in (0,1)) and abs(m['bounds_min_blender_m'][2])<.002,(r.name,m)
        parts=[o for o in r.children_recursive if o.type=='MESH']
        assert len([o for o in parts if o.get('part_role')=='separate_switchable_light_panel'])==1
        assert len([o for o in parts if o.get('part_role')=='slender_main_post'])==1
        assert len([o for o in parts if o.get('part_role')=='one_of_two_roof_slopes'])==(1 if r.name.endswith('Broken') else 2)
    panels=[next(o for o in r.children_recursive if o.get('part_role')=='separate_switchable_light_panel') for r in roots]
    assert [tuple(round(v,5) for v in p.dimensions) for p in panels].count(tuple(round(v,5) for v in panels[0].dimensions))==3
    assert panels[0].data.materials[0]==panels[1].data.materials[0]==mat and panels[2].data.materials[0]==emissive
    mesh_parts=[o for o in export.objects if o.type=='MESH']
    assert len(mesh_parts)==54,len(mesh_parts)
    assert all(o.data.color_attributes.get('Color') is not None for o in mesh_parts)
    assert all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light'))
    # Preview stage floor and lighting are excluded from the production collection.
    floor_mat=bpy.data.materials.new('P01_PreviewGround_Material');floor_mat.use_nodes=True
    bs=next(n for n in floor_mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(.055,.057,.06,1);bs.inputs['Roughness'].default_value=.96
    me=bpy.data.meshes.new('P01_PreviewGround_Mesh');me.from_pydata([(-30,-30,-.02),(30,-30,-.02),(30,30,-.02),(-30,30,-.02)],[],[(0,1,2,3)]);me.materials.append(floor_mat)
    ground=bpy.data.objects.new('P01_PreviewGround',me);preview.objects.link(ground)
    world=bpy.data.worlds.new('P01_PreviewWorld');world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.055,.057,.06,1);bg.inputs['Strength'].default_value=.55;scene.world=world
    for name,loc,power,size in [('P01_Key',(-4,-6,6),1800,6),('P01_Fill',(4,-5,3),1100,5),('P01_Rim',(0,5,5),1600,6)]:area_light(preview,name,loc,power,size,(0,0,.8))
    cd=bpy.data.cameras.new('P01_PreviewCamera_Data');cam=bpy.data.objects.new('P01_PreviewCamera',cd);preview.objects.link(cam);scene.camera=cam
    cam.location=(0,-6.9,3.5);cam.rotation_euler=(Vector((0,-.04,.78))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24;cam.data.lens=40
    before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb')
    imported=list(set(bpy.data.objects)-before);rig=next((o for o in imported if o.type=='ARMATURE'),None);assert rig,'Actual fox reference import failed'
    for ob in imported:
        old=ob.name
        for col in list(ob.users_collection):col.objects.unlink(ob)
        preview.objects.link(ob);ob.name='P01_Fox_'+old.replace('.','_')
        if any(k in old.lower() for k in ('icosphere','sword')):ob.hide_render=True;ob.hide_set(True)
    idle=next((act for act in bpy.data.actions if act.name=='Idle'),None);assert idle,'Fox Idle action missing'
    if not rig.animation_data:rig.animation_data_create()
    rig.animation_data.action=idle;rig.location=(-2.45,-.78,0);scene.frame_set(1)
    for im in bpy.data.images:
        if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
    source['source_only']=True;source['excluded_from_glb']=True
    for r in roots:
        note=bpy.data.objects.new('P01_PivotNote_'+r.name,None);source.objects.link(note);note.parent=r;note.hide_render=True;note.hide_set(True);note['source_only']=True
    assert all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light'))
    scene.render.engine='CYCLES';scene.cycles.samples=10;scene.cycles.use_denoising=True
    scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.05;scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
    print('P01_BUILD_READY',json.dumps({'scene':scene.name,'variants':{r.name:measure(r) for r in roots},'panels':{'shared_geometry':True,'off_and_broken_material':mat.name,'lit_material':emissive.name,'emission_strength':.85},'materials':[mat.name,emissive.name],'three_states':True,'fox_action':rig.animation_data.action.name,'default_scene_preserved':True}))

main()

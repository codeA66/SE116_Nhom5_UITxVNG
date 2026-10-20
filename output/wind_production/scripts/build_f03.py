import bpy, bmesh, json, math, os
from mathutils import Matrix, Vector

ROOT = r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT = ROOT + '/assets/generated/wind_ruins/f03'
PRE = ROOT + '/output/wind_production/f03'
CONCEPT = ROOT + '/output/wind_production/concepts/f03_concept_v1.png'
PROMPT = ROOT + '/output/wind_production/concepts/f03_prompt.txt'
GLB = OUT + '/f03_collapsed_wind_banner.glb'

def rotation_map():
    # F01 local X -> fallen crossbar Y, local Y -> cloth-facing up Z,
    # local Z -> fallen shaft X; then slope the shaft down by eight degrees.
    cyclic = Matrix(((0,0,1),(1,0,0),(0,1,0)))
    slope = Matrix.Rotation(math.radians(8.0), 3, 'Y')
    return slope @ cyclic

def set_color(mesh, color):
    ca = mesh.color_attributes.get('Color')
    if ca is None:
        ca = mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='CORNER')
    for d in ca.data:
        d.color = color

def make_piece(name, verts, faces, material, side_color, cap_colors=None):
    me = bpy.data.meshes.new(name + '_Mesh')
    me.from_pydata(verts, [], faces)
    me.materials.append(material)
    me.update()
    ca = me.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='CORNER')
    cap_colors = cap_colors or {}
    for poly in me.polygons:
        col = cap_colors.get(poly.index, side_color)
        for li in poly.loop_indices:
            ca.data[li].color = col
    bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me)
    return ob

def make_pole_section(name, template, z0, z1, lower_offsets, upper_offsets, transform=None, translation=Vector((0,0,0))):
    src = template.data
    rings = {}
    for zval in sorted(set((0.25, 4.8))):
        ids = [v for v in src.vertices if abs(v.co.z-zval) < 1e-4]
        ids.sort(key=lambda v: math.atan2(v.co.y, v.co.x))
        assert len(ids) == 8, (zval, len(ids))
        rings[zval] = [(v.co.x, v.co.y) for v in ids]
    base, top = rings[0.25], rings[4.8]
    def radius_at(k, z):
        f = (z-.25)/(4.8-.25)
        return Vector(base[k]).lerp(Vector(top[k]), f)
    verts=[]
    # The eight-sided source section is preserved at each end; the fracture rim
    # uses three broad axial offsets instead of splinter noise.
    for z, offsets in ((z0, lower_offsets), (z1, upper_offsets)):
        for k in range(8):
            p=radius_at(k,z)
            axial=z+offsets[k]-(z0 if transform else 0.0)
            local=Vector((p.x,p.y,axial))
            verts.append(tuple((transform @ local)+translation if transform else local))
    faces=[]
    for k in range(8):
        kn=(k+1)%8
        faces.append((k,kn,8+kn,8+k))
    # Both broad fracture cuts are triangulated from their center; the pale
    # vertex-color facets make each snapped end legible without extra geometry.
    for ring,center_idx,offsets,zc in ((0,16,lower_offsets,z0),(1,17,upper_offsets,z1)):
        center_local=Vector((0,0,zc+sum(offsets)/8-(z0 if transform else 0.0)))
        center=tuple((transform @ center_local)+translation if transform else center_local)
        verts.append(center)
        ci=len(verts)-1
        for k in range(8):
            faces.append((ci,ring*8+k,ring*8+(k+1)%8))
    side=(0.084,0.072,0.056,1.0)
    bright=(0.19,0.125,0.066,1.0)
    mid=(0.145,0.096,0.052,1.0)
    caps={}
    # face 8..15 are lower fracture; face 16..23 upper fracture
    for i in range(8):
        caps[1+8+i] = bright if i in (0,1,2,5,6) else mid
        caps[1+16+i] = bright if i in (0,1,2,5,6) else mid
    # face ordering: 8 side quads, then 8 lower-cap fans, 8 upper-cap fans
    cap_colors={8+i:(bright if i in (0,1,2,5,6) else mid) for i in range(8)}
    cap_colors.update({16+i:(bright if i in (0,1,2,5,6) else mid) for i in range(8)})
    ob=make_piece(name,verts,faces,src.materials[0],side,cap_colors)
    ob['source_geometry']='Eight-sided tapered profile sampled from F01_Pole_Octagonal'
    ob['fracture_planes']='Three broad faceted wedges at both cut ends; matching angular profile'
    return ob

def main():
    default=bpy.data.scenes.get('Scene')
    assert default and all(default.objects.get(n) for n in ('Cube','Camera','Light')), 'Original default scene must remain intact'
    assert os.path.isfile(CONCEPT) and os.path.isfile(PROMPT), 'F03 actual concept and prompt must exist'
    assert not os.path.exists(GLB), 'Refusing to overwrite an existing F03 GLB'
    old=bpy.data.scenes.get('WindProduction_F03')
    if old:
        bpy.context.window.scene=default
        for ob in list(old.objects): bpy.data.objects.remove(ob,do_unlink=True)
        bpy.data.scenes.remove(old)
    f01=bpy.data.collections['F01_Export']
    f01root=f01.objects.get('F01_WindMainBanner')
    sourcepole=f01.objects.get('Pole_Octagonal')
    sourcecloth=f01.objects.get('Cloth_Wind_Animated')
    assert f01root and sourcepole and sourcecloth
    os.makedirs(OUT+'/source',exist_ok=True);os.makedirs(PRE,exist_ok=True)
    open(OUT+'/source/.gdignore','a',encoding='utf-8').close()
    scene=bpy.data.scenes.new('WindProduction_F03')
    bpy.context.window.scene=scene
    scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1.0
    export=bpy.data.collections.new('F03_Export');scene.collection.children.link(export)
    preview=bpy.data.collections.new('F03_Preview_ONLY');scene.collection.children.link(preview)
    source=bpy.data.collections.new('F03_Source_NOT_EXPORTED');scene.collection.children.link(source)
    root=bpy.data.objects.new('F03_Collapsed_WindBanner',None);export.objects.link(root)
    root['catalog']='F03 collapsed banner, derived directly from F01 geometry'
    root['pivot']='stone base center at ground; Blender Z=0, Godot Y=0'
    root['front']='cloth/emblem faces upward for the fallen state'
    root['spec']='about 4.8 x 1.5 x 0.8 m; 1.55 m crossbar; 1.2 x 2.4 m cloth'
    root['interaction']='none; environmental prop'
    rot=rotation_map();break_z=0.72;translation=Vector((0,0,break_z))
    offsets=(0.0,0.055,0.012,-0.043,-0.022,0.047,0.015,-0.034)
    identity=Matrix.Identity(4)
    names=('Foot_Stone','Foot_Collar','Upper_Collar','Crossbar','Crossbar_End_-1','Crossbar_End_1')
    copies={}
    for n in names:
        src=f01.objects.get(n);assert src and src.type=='MESH',n
        ob=src.copy();ob.data=src.data.copy();ob.name='F03_'+n;export.objects.link(ob)
        ob.parent=root;ob.matrix_parent_inverse=identity;ob.matrix_basis=identity
        if n not in ('Foot_Stone','Foot_Collar'):
            for v in ob.data.vertices:
                v.co=rot @ (v.co-Vector((0,0,break_z)))+translation
            ob.data.update()
        copies[n]=ob
    stump=make_pole_section('F03_Pole_Broken_Stump',sourcepole,0.25,break_z,(0,)*8,offsets)
    fallen=make_pole_section('F03_Pole_Fallen_Upper',sourcepole,break_z,4.8,offsets,(0,)*8,rot,translation)
    for ob in (stump,fallen):
        export.objects.link(ob);ob.parent=root;ob.matrix_parent_inverse=identity;ob.matrix_basis=identity
    stump['part_role']='short vertical snapped remnant attached to original stone foot'
    fallen['part_role']='F01 tapered upper pole rotated down eight degrees onto ground'
    # Keep one original F01 mesh, including its exact emblem and UVs. The banner
    # top maps to the fallen crossbar; its width arches over the pole and down to
    # the ground as one broad U-shaped snagged cloth panel.
    cloth=sourcecloth.copy();cloth.data=sourcecloth.data.copy();cloth.name='F03_Cloth_Continuous_F01EmblemSnagged'
    export.objects.link(cloth);cloth.parent=root;cloth.matrix_parent_inverse=identity;cloth.matrix_basis=identity
    for v in cloth.data.vertices:
        sx,sy,sz=v.co
        q=max(0.0,min(1.0,(sx+.6)/1.2))
        t=max(0.0,min(1.0,(4.3-sz)/2.4))
        # Broad fabric sweep from the crossbar back along the pole; a shallow
        # arch wraps over the shaft, while two wide waves create the snag folds.
        x_top=(4.3-break_z)*math.cos(math.radians(8.0))
        x=x_top-2.4*t+0.055*math.sin(2*math.pi*t)*math.sin(math.pi*q)
        y=sx
        shaft_crown=break_z-x*math.sin(math.radians(8.0))+0.16
        shoulder=max(0.0,min(1.0,(abs(q-.5)-.22)/.28))
        arch=0.025+shaft_crown*(1.0-shoulder*shoulder)
        folds=0.035*math.sin(2*math.pi*t+q*math.pi)*math.sin(math.pi*q)
        detail=0.06*(sy+0.30)
        z=max(0.02,arch+folds+detail)
        v.co=(x,y,z)
    cloth.data.update();cloth['part_role']='single continuous F01 cloth panel with exact emblem topology/UVs, draped over shaft'
    cloth['source_geometry']='all 889 vertices and 608 faces retained from F01 Cloth_Wind_Animated'
    cloth['cloth_uv']='original F01 WindUV_TopAnchorU0 preserved; top u=0, free hem u=1'
    cloth['emblem']='exact F01 open C-ring and three same-direction strokes, transformed flush with cloth'
    cloth['shape']='one broad U-shaped transverse drape with two low longitudinal snags'
    # A small source note remains editable but outside the GLB selection.
    note=bpy.data.objects.new('F03_Source_F01PivotAndEmblem_Note',None);source.objects.link(note)
    note.hide_render=True;note.hide_set(True);note['source_only']=True
    note['source']='F01 pole, cloth, UVs, colors, crossbar and emblem sampled/copied without edits to the source scene.'
    # Preview stage and actual fox reference, isolated from the export collection.
    groundmat=bpy.data.materials.new('F03_PreviewGround_Material');groundmat.use_nodes=True
    bs=next(n for n in groundmat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value=(0.055,0.060,0.064,1);bs.inputs['Roughness'].default_value=.92
    gm=bpy.data.meshes.new('F03_PreviewGround_Mesh');gm.from_pydata([(-30,-30,-.015),(30,-30,-.015),(30,30,-.015),(-30,30,-.015)],[],[(0,1,2,3)]);gm.materials.append(groundmat)
    ground=bpy.data.objects.new('F03_PreviewGround',gm);preview.objects.link(ground)
    world=bpy.data.worlds.new('F03_PreviewWorld');world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.13,.15,.18,1);bg.inputs['Strength'].default_value=.45;scene.world=world
    def area(name,loc,power,size,target):
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
        ob=bpy.data.objects.new(name,data);preview.objects.link(ob);ob.location=loc
        ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
    area('F03_Key',(-4,-6,9),1500,6,(2,0,.35));area('F03_Fill',(4,-2,6),700,5,(2,0,.35));area('F03_Rim',(1,5,8),1100,5,(2,0,.35))
    camdata=bpy.data.cameras.new('F03_PreviewCamera_Data');cam=bpy.data.objects.new('F03_PreviewCamera',camdata);preview.objects.link(cam);scene.camera=cam
    cam.location=(5,-7,5);cam.rotation_euler=(Vector((2,0,.35))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24;cam.data.lens=42
    before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb');imported=list(set(bpy.data.objects)-before)
    rig=next((o for o in imported if o.type=='ARMATURE'),None);assert rig,'Actual fox GLB import failed'
    for ob in imported:
        old=ob.name
        for col in list(ob.users_collection):col.objects.unlink(ob)
        preview.objects.link(ob);ob.name='F03_Fox_'+old.replace('.','_')
        if any(k in old.lower() for k in ('icosphere','sword')):ob.hide_render=True;ob.hide_set(True)
    idle=next((a for a in bpy.data.actions if a.name=='Idle'),None);assert idle,'Idle action missing'
    if not rig.animation_data:rig.animation_data_create()
    rig.animation_data.action=idle;rig.location=(1.1,-1.65,0);scene.frame_set(1)
    for im in bpy.data.images:
        if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
    scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True;scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.05
    scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
    meshes=[o for o in export.objects if o.type=='MESH']
    assert len(meshes)==9, [o.name for o in meshes]
    assert all(o.data.color_attributes.get('Color') for o in meshes),'All exported meshes must use F01 vertex colors'
    assert len({m.name for o in meshes for m in o.data.materials})==1,'F03 must use one shared F01 material'
    assert len(cloth.data.vertices)==len(sourcecloth.data.vertices) and len(cloth.data.polygons)==len(sourcecloth.data.polygons)
    assert cloth.data.uv_layers and cloth.data.uv_layers[0].name=='WindUV_TopAnchorU0'
    assert bpy.data.scenes['Scene'].objects.get('Cube') and bpy.data.scenes['Scene'].objects.get('Camera') and bpy.data.scenes['Scene'].objects.get('Light')
    print('F03_BUILD_READY',json.dumps({'scene':scene.name,'root':root.name,'mesh_parts':len(meshes),'cloth_vertices':len(cloth.data.vertices),'cloth_uv':cloth.data.uv_layers[0].name,'shared_material':meshes[0].data.materials[0].name,'default_scene_preserved':True,'fox_action':rig.animation_data.action.name,'parts':[o.name for o in meshes]}))

main()

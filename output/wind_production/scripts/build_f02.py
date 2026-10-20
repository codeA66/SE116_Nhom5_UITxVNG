import bpy, bmesh, math, os, json
from mathutils import Vector, Matrix

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/f02'
PRE=ROOT+'/output/wind_production/f02'
CONCEPT=ROOT+'/output/wind_production/concepts/f02_concept_v1.png'
PROMPT=ROOT+'/output/wind_production/concepts/f02_prompt.txt'
F01_GLB=ROOT+'/assets/generated/wind_ruins/f01/f01_wind_main_banner.glb'

def area_quad(a,b,c,d):
    return ((b-a).cross(c-a).length+(c-a).cross(d-a).length)*.5

def bottom(x):
    return 1.9+.20*(1-abs(x)/.6)

def add_attributes(mesh,uvs,color):
    ca=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    uv=mesh.uv_layers.new(name='WindUV_TopAnchorU0')
    for p in mesh.polygons:
        for li in p.loop_indices:
            vi=mesh.loops[li].vertex_index
            ca.data[li].color=color
            uv.data[li].uv=uvs[vi]

def create_panel(srcmesh,collection,root,template_obj):
    nx,nz=16,24;fine_x,fine_z=32,48
    original=[v.co.copy() for v in srcmesh.vertices[:(nx+1)*(nz+1)]]
    grid_faces=[p for p in srcmesh.polygons if all(i<(nx+1)*(nz+1) for i in p.vertices)]
    assert len(grid_faces)==nx*nz,('F01 grid face count',len(grid_faces))
    old_uv=srcmesh.uv_layers[0];uv_by_vertex={}
    for p in grid_faces:
        for li in p.loop_indices:
            vi=srcmesh.loops[li].vertex_index
            uv_by_vertex.setdefault(vi,old_uv.data[li].uv.copy())
    assert len(uv_by_vertex)==(nx+1)*(nz+1),'F01 cloth UV grid is incomplete'
    old_color=srcmesh.color_attributes.get('Color');assert old_color,'F01 vertex colors missing'
    color=tuple(old_color.data[grid_faces[0].loop_start].color)

    def sample_xt(x,t):
        fx=(x+.6)/1.2*nx;x0=min(int(fx),nx-1);u=fx-x0
        fy=t*nz;z0=min(int(fy),nz-1);v=fy-z0
        ids=[z0*(nx+1)+x0,z0*(nx+1)+x0+1,(z0+1)*(nx+1)+x0+1,(z0+1)*(nx+1)+x0]
        weights=[(1-u)*(1-v),u*(1-v),u*v,(1-u)*v]
        co=Vector((0,0,0));tex=Vector((0,0))
        for idx,w in zip(ids,weights):co+=original[idx]*w;tex+=uv_by_vertex[idx]*w
        return co,tex

    full_coords=[]
    for j in range(fine_z+1):
        for i in range(fine_x+1):
            x=-.6+1.2*i/fine_x;co,tex=sample_xt(x,j/fine_z);full_coords.append(tuple(co))
    # Remap the source surface from each unchanged hem point up to a broad triangular
    # cut line. This removes real cloth area without stretching/inverting the F01 folds.
    tears=[(-.525,-.075,1.0),(.075,.525,1.0)]
    def torn_bottom(x):
        return bottom(x)+sum(d*max(0.0,1-abs(x-(a+b)*.5)/((b-a)*.5)) for a,b,d in tears)
    coords=[];texcoords=[]
    for j in range(fine_z+1):
        for i in range(fine_x+1):
            x=-.6+1.2*i/fine_x;bo=bottom(x);bn=torn_bottom(x)
            z=4.3+(bn-4.3)*j/fine_z;t=(4.3-z)/(4.3-bo)
            co,tex=sample_xt(x,t);coords.append(tuple(co));texcoords.append(tuple(tex))
    faces=[];area_all=0.0;area_remaining=0.0
    for j in range(fine_z):
        for i in range(fine_x):
            ids=(j*(fine_x+1)+i,j*(fine_x+1)+i+1,(j+1)*(fine_x+1)+i+1,(j+1)*(fine_x+1)+i)
            a,b,c,d=[Vector(full_coords[k]) for k in ids];area_all+=area_quad(a,b,c,d)
            a,b,c,d=[Vector(coords[k]) for k in ids];area_remaining+=area_quad(a,b,c,d);faces.append(ids)
    area_lost=area_all-area_remaining
    loss_pct=100*area_lost/area_all
    assert 15<=loss_pct<=25,('F02 cloth area loss outside 15-25%',loss_pct)
    me=bpy.data.meshes.new('F02_TornClothPanel_Mesh')
    me.from_pydata(coords,[],faces);me.update()
    for material in srcmesh.materials:me.materials.append(material)
    add_attributes(me,texcoords,color)
    panel=bpy.data.objects.new('F02_ClothPanel_Torn_TopAnchored',me);collection.objects.link(panel)
    panel.parent=root;panel.matrix_parent_inverse=Matrix.Identity(4);panel.matrix_basis=template_obj.matrix_basis.copy()
    panel['part_role']='F01-derived cloth panel with two broad lower-edge tears'
    panel['cloth_area_loss_percent']=round(loss_pct,3);panel['tears']=2
    panel['cloth_area_surface_before_m2']=area_all;panel['cloth_area_removed_m2']=area_lost
    panel['tears_profile_m']='two 1 m triangular cuts: x=-0.525..-0.075 m and x=0.075..0.525 m'
    panel['upper_attachments_intact']=True;panel['uv_direction']='top u=0, free hem u=1; F01 bilinear UV interpolation preserved'
    group=panel.vertex_groups.new(name='Anchor_Top')
    for vi in range(fine_x+1):group.add([vi],1.0,'REPLACE')
    return panel,loss_pct,area_all,area_lost

def extract_emblem(srcmesh,collection,root,template_obj):
    ngrid=17*25
    faces=[p for p in srcmesh.polygons if not all(i<ngrid for i in p.vertices)]
    assert faces,'F01 emblem geometry not found'
    used=sorted({i for p in faces for i in p.vertices});index={old:i for i,old in enumerate(used)}
    me=bpy.data.meshes.new('F02_F01ExactEmblem_Mesh')
    me.from_pydata([srcmesh.vertices[i].co[:] for i in used],[],[tuple(index[i] for i in p.vertices) for p in faces]);me.update()
    for material in srcmesh.materials:me.materials.append(material)
    old_colors=srcmesh.color_attributes.get('Color');old_uvs=list(srcmesh.uv_layers)
    color=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    uv_layers=[me.uv_layers.new(name=u.name) for u in old_uvs]
    lookup={}
    for p in srcmesh.polygons:
        for li in p.loop_indices:lookup[(p.index,srcmesh.loops[li].vertex_index)]=li
    for np,op in zip(me.polygons,faces):
        for nli,oldvi in zip(np.loop_indices,op.vertices):
            oli=lookup[(op.index,oldvi)]
            color.data[nli].color=old_colors.data[oli].color
            for k,layer in enumerate(uv_layers):layer.data[nli].uv=old_uvs[k].data[oli].uv
    ob=bpy.data.objects.new('F02_ClothEmblem_OpenRing_ThreeStrokes',me);collection.objects.link(ob)
    ob.parent=root;ob.matrix_parent_inverse=Matrix.Identity(4);ob.matrix_basis=template_obj.matrix_basis.copy()
    ob['part_role']='exact F01 open C-ring and three same-direction wind strokes'
    ob['source_geometry']='F01 Cloth_Wind_Animated emblem faces copied vertex-for-vertex'
    return ob

def simple_material(name,color):
    m=bpy.data.materials.new(name);m.use_nodes=True
    bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=.9
    return m

def area_light(collection,name,loc,power,size,target):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    ob=bpy.data.objects.new(name,data);collection.objects.link(ob);ob.location=loc
    ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler();return ob

def main():
    default=bpy.data.scenes.get('Scene');assert default and all(default.objects.get(n) for n in ('Cube','Camera','Light')),'Original default scene must remain intact'
    assert os.path.isfile(F01_GLB) and os.path.isfile(CONCEPT) and os.path.isfile(PROMPT),'F01 GLB and F02 concept artifacts must exist'
    assert not os.path.isfile(OUT+'/f02_torn_wind_banner.glb'),'Refusing to overwrite existing F02 GLB'
    old=bpy.data.scenes.get('WindProduction_F02')
    if old:
        bpy.context.window.scene=default
        for ob in list(old.objects):bpy.data.objects.remove(ob,do_unlink=True)
        bpy.data.scenes.remove(old)
    f01=bpy.data.collections['F01_Export'];source_root=f01.objects.get('F01_WindMainBanner')
    source_cloth=f01.objects.get('Cloth_Wind_Animated')
    assert source_root and source_cloth,'The original F01 source scene must be available and unchanged'
    os.makedirs(OUT+'/source',exist_ok=True);os.makedirs(PRE,exist_ok=True);open(OUT+'/source/.gdignore','w').close()
    scene=bpy.data.scenes.new('WindProduction_F02');bpy.context.window.scene=scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1.0
    export=bpy.data.collections.new('F02_Export');scene.collection.children.link(export)
    preview=bpy.data.collections.new('F02_Preview_ONLY');scene.collection.children.link(preview)
    source=bpy.data.collections.new('F02_Source_NOT_EXPORTED');scene.collection.children.link(source)
    root=bpy.data.objects.new('F02_Torn_WindBanner',None);export.objects.link(root)
    root['catalog']='F02 torn variant derived directly from F01'
    root['pivot']='pole center at ground, Blender Z=0; Godot Y=0'
    root['dimensions_design_m']='pole 4.8; cloth 1.2 x 2.4; cloth top 4.3 bottom 1.9; crossbar 1.55'
    root['front']='Godot +Z / Blender -Y'
    root['emblem']='exact F01 open C-ring and three same-direction strokes'
    copies={}
    for src in list(f01.objects):
        if src==source_root:continue
        cp=src.copy();cp.data=src.data.copy();cp.name='F02_'+src.name;export.objects.link(cp)
        cp.parent=root;cp.matrix_parent_inverse=Matrix.Identity(4);cp.matrix_basis=src.matrix_basis.copy();copies[src.name]=cp
    cloth=copies['Cloth_Wind_Animated'];oldmesh=cloth.data.copy()
    panel,loss_pct,area_all,area_lost=create_panel(oldmesh,export,root,cloth)
    emblem=extract_emblem(oldmesh,export,root,cloth)
    bpy.data.objects.remove(cloth,do_unlink=True)
    if oldmesh.users==0:bpy.data.meshes.remove(oldmesh)
    # Reference locator stays in the editable source but cannot enter the GLB.
    note=bpy.data.objects.new('F02_Source_PivotAndLogo_Note',None);source.objects.link(note);note.hide_render=True;note.hide_set(True)
    note['source_only']=True;note['source']='F01 exact geometry; the only silhouette edits are two broad lower-edge cloth cuts.'
    meshes=[o for o in export.objects if o.type=='MESH']
    assert len({m.name for o in meshes for m in o.data.materials})==1,'F02 must reuse the single F01 palette material'
    assert all(o.data.color_attributes.get('Color') is not None for o in meshes),'Vertex colors must remain on every export mesh'
    assert len(panel.data.uv_layers)==1 and len(emblem.data.uv_layers)==1,'F01 UV layers must remain'
    assert all(bpy.data.scenes['Scene'].objects.get(n) for n in ('Cube','Camera','Light'))
    # Compare emblem vertex positions with the unchanged F01 source emblem vertices.
    old_grid=17*25;old_logo=sorted(tuple(round(v.co[i],7) for i in range(3)) for v in source_cloth.data.vertices[old_grid:])
    new_logo=sorted(tuple(round(v.co[i],7) for i in range(3)) for v in emblem.data.vertices)
    assert old_logo==new_logo,'F02 emblem geometry must match the original F01 geometry exactly'
    # Check the cloth range and the anchored top/free-edge UV direction.
    ppts=[v.co for v in panel.data.vertices]
    panel_dims=[max(v[i] for v in ppts)-min(v[i] for v in ppts) for i in range(3)]
    uv=panel.data.uv_layers[0];uvals=[d.uv.x for d in uv.data]
    assert abs(panel_dims[0]-1.2)<.002 and abs(panel_dims[2]-2.4)<.002,panel_dims
    assert min(uvals)<.001 and max(uvals)>.91,(min(uvals),max(uvals))
    assert 15<=loss_pct<=25
    # Preview only: the project fox on its exact Idle action, with import helpers hidden.
    groundmat=simple_material('F02_PreviewGround_Material',(.055,.060,.064))
    gm=bpy.data.meshes.new('F02_PreviewGround_Mesh');gm.from_pydata([(-30,-30,-.015),(30,-30,-.015),(30,30,-.015),(-30,30,-.015)],[],[(0,1,2,3)]);gm.materials.append(groundmat)
    ground=bpy.data.objects.new('F02_PreviewGround',gm);preview.objects.link(ground)
    world=bpy.data.worlds.new('F02_PreviewWorld');world.use_nodes=True;bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.13,.15,.18,1);bg.inputs['Strength'].default_value=.45;scene.world=world
    for name,loc,power,size in [('F02_Key',(-5,-7,11),1700,7),('F02_Fill',(6,-2,7),850,6),('F02_Rim',(0,5,9),1300,5)]:area_light(preview,name,loc,power,size,(0,0,2.4))
    camdata=bpy.data.cameras.new('F02_PreviewCamera_Data');cam=bpy.data.objects.new('F02_PreviewCamera',camdata);preview.objects.link(cam);scene.camera=cam
    cam.location=(6,-11,7);cam.rotation_euler=(Vector((.25,0,2.4))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='PERSP';cam.data.sensor_fit='VERTICAL';cam.data.sensor_height=24;cam.data.lens=40
    before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb');imported=list(set(bpy.data.objects)-before)
    rig=next((o for o in imported if o.type=='ARMATURE'),None);assert rig,'Actual preview fox import failed'
    for ob in imported:
        old_name=ob.name
        for col in list(ob.users_collection):col.objects.unlink(ob)
        preview.objects.link(ob);ob.name='F02_Fox_'+old_name.replace('.','_')
        if any(k in old_name.lower() for k in ('icosphere','sword')):ob.hide_render=True;ob.hide_set(True)
    idle=next((a for a in bpy.data.actions if a.name=='Idle'),None);assert idle,'Idle fox action missing'
    if not rig.animation_data:rig.animation_data_create()
    rig.animation_data.action=idle;rig.location=(1.35,-.75,0);scene.frame_set(1)
    for im in bpy.data.images:
        if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
    scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True;scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.05
    scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
    measures={'cloth_area_m2_before':area_all,'cloth_area_m2_removed':area_lost,'cloth_area_loss_percent':loss_pct,'panel_dimensions_blender_xyz_m':panel_dims,
      'mesh_parts':len(meshes),'triangles':sum((o.data.calc_loop_triangles() or len(o.data.loop_triangles)) for o in meshes)}
    print('F02_BUILD_READY',json.dumps({'scene':scene.name,'variant':root.name,'measures':measures,'exact_f01_emblem':True,'top_attachment_intact':True,'uv_direction_preserved':True,'material':meshes[0].data.materials[0].name,'default_scene_preserved':True}))

main()

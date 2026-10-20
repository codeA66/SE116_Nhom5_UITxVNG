import bpy, bmesh, math, os, json
from mathutils import Vector, Matrix

ROOT=r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
OUT=ROOT+'/assets/generated/wind_ruins/t02'
PRE=ROOT+'/output/wind_production/t02'
CONCEPT=ROOT+'/output/wind_production/concepts/t02_concept_v1.png'
PROMPT=ROOT+'/output/wind_production/concepts/t02_prompt.txt'
GLB=OUT+'/t02_cliff_corner_wall.glb'
LEVELS=[0.0,.48,.95,1.55,2.10,2.75,4.30,5.55,6.0]

def lin(h):
    rgb=[int(h[i:i+2],16)/255 for i in (1,3,5)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1.0,)

COLORS={
 'front_l':lin('#60615D'),'front_lm':lin('#686965'),'front_mid':lin('#70716C'),
 'front_rm':lin('#686965'),'front_r':lin('#60615D'),'side':lin('#5A5B57'),
 'back':lin('#646560'),'top':lin('#797A74'),'bottom':lin('#50514D'),
 'chip':lin('#7B7C76')
}

def area_light(collection,name,loc,power,size,target):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    ob=bpy.data.objects.new(name,data);collection.objects.link(ob);ob.location=loc
    ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler();return ob

def connector_profile(template,z):
    vs=template.data.vertices
    at_z=[v.co for v in vs if abs(v.co.z-z)<1e-4]
    assert at_z,(z,'T01 has no matching connector-profile ring')
    xmax=max(p.x for p in at_z)
    east=[p for p in at_z if abs(p.x-xmax)<1e-4]
    ylo=min(p.y for p in east);yhi=max(p.y for p in east)
    # A 90-degree copy of the same T01 connector supplies the orthogonal end.
    xlo=-yhi;xhi=-ylo
    return xmax,ylo,yhi,xlo,xhi

def ring_points(template,z,variant):
    xedge,ylo,yhi,xnlo,xnhi=connector_profile(template,z)
    # The two terminal profiles (x=+edge and y=+edge) are sampled from the
    # actual T01 mesh at every shared height. Other vertices form a chamfered L.
    # Convex closes the inner elbow with a single chamfer. Concave pushes that
    # same elbow inward, opening a clear pocket without touching either connector.
    inner_corner=(xnhi-.55,yhi-.55) if variant=='concave' else ((xedge+xnhi)*.5,(yhi+xedge)*.5)
    p=[(-xedge,-xedge),(xnhi,-xedge),(xedge,ylo),(xedge,yhi),
       inner_corner,(xnhi,xedge),(xnlo,xedge),(-xedge,xnhi)]
    if variant=='broken' and z>=4.30:
        t=max(0.0,min(1.0,(z-4.30)/(6.0-4.30)))
        p[0]=(p[0][0]+.98*t,p[0][1]+.91*t)
        p[1]=(p[1][0]-.10*t,p[1][1]+.27*t)
        p[7]=(p[7][0]+.20*t,p[7][1]-.12*t)
    else:
        # Steep base transitions create broad non-walkable stone facets while
        # leaving both connector outlines mathematically fixed.
        if z>0 and z<=1.55:
            t=max(0.0,1.0-z/1.55)
            p[0]=(p[0][0]+.12*t,p[0][1]+.14*t)
            p[1]=(p[1][0]-.03*t,p[1][1]+.08*t)
            p[7]=(p[7][0]+.08*t,p[7][1]-.03*t)
    return [(x,y,z) for x,y in p]

def build_corner_mesh(collection,template,material,name,variant,parent):
    rings=[ring_points(template,z,variant) for z in LEVELS]
    n=len(rings[0]);assert all(len(r)==n for r in rings)
    verts=[v for ring in rings for v in ring];faces=[];keys=[]
    faces.append(tuple(reversed(range(n))));keys.append('bottom')
    base_keys=['front_mid','front_lm','side','front_rm',('front_r' if variant=='concave' else 'front_lm'),'side','back','back']
    for k in range(len(rings)-1):
        for i in range(n):
            faces.append((k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i))
            key=base_keys[i]
            if variant=='broken' and i in (0,1,7) and LEVELS[k]>=4.30:
                key='chip'
            elif i in (0,3) and k in (0,1):
                key='front_lm' if i==0 else 'front_mid'
            keys.append(key)
    faces.append(tuple((len(rings)-1)*n+i for i in range(n)));keys.append('top')
    me=bpy.data.meshes.new(name+'_Mesh');me.from_pydata(verts,[],faces);me.update();me.materials.append(material)
    attr=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    for poly,key in zip(me.polygons,keys):
        for li in poly.loop_indices:attr.data[li].color=COLORS[key]
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free();me.update()
    obj=bpy.data.objects.new(name,me);collection.objects.link(obj);obj.parent=parent
    obj['variant']=variant;obj['dimensions_design_m']='4 x 4 x 6; exact T01 connector profiles at both terminal ends'
    obj['connector_profiles']='East: actual T01 x-positive edge; north: same edge rotated 90 degrees; flat through full 6 m height'
    obj['surface_design']='Two broad perpendicular faces, one large corner chamfer, 3-5 restrained stone planes; steep base transitions only'
    if variant=='broken':obj['damage']='One broad missing exposed upper corner; both T01 connector profiles and lower support retained'
    if variant=='concave':obj['arrangement']='180-degree reversed L presents the opposite, inward-facing exposed planes; same profile set'
    return obj

def main():
    default=bpy.data.scenes.get('Scene')
    assert default and all(default.objects.get(n) for n in ('Cube','Camera','Light')),'Original default scene must remain intact'
    assert all(os.path.isfile(p) for p in (CONCEPT,PROMPT)),'T02 concept and prompt must exist before modeling'
    assert not os.path.exists(GLB),'Refusing to overwrite an existing T02 GLB'
    template=bpy.data.objects.get('T01_Intact_Stone');assert template,'Actual T01 source geometry is unavailable'
    old=bpy.data.scenes.get('WindProduction_T02')
    if old:
        bpy.context.window.scene=default
        for ob in list(old.objects):
            if ob.name.startswith('T02_'):bpy.data.objects.remove(ob,do_unlink=True)
        for col in list(old.collection.children):
            if col.name.startswith('T02_'):old.collection.children.unlink(col);bpy.data.collections.remove(col)
        old_world=old.world;bpy.data.scenes.remove(old,do_unlink=True)
        if old_world and old_world.name=='T02_PreviewWorld' and old_world.users==0:bpy.data.worlds.remove(old_world)
    os.makedirs(OUT+'/source',exist_ok=True);os.makedirs(PRE,exist_ok=True)
    open(OUT+'/source/.gdignore','a',encoding='utf-8').close()
    scene=bpy.data.scenes.new('WindProduction_T02');bpy.context.window.scene=scene
    scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1.0
    export=bpy.data.collections.new('T02_Export');scene.collection.children.link(export)
    preview=bpy.data.collections.new('T02_Preview_ONLY');scene.collection.children.link(preview)
    source=bpy.data.collections.new('T02_Source_NOT_EXPORTED');scene.collection.children.link(source)
    material=template.data.materials[0]
    descriptions=[
      ('T02_Convex_Outer_Corner',(-5.4,0,0),'convex','A broad continuous chamfer joins the two outward corner planes; exact T01 connectors.'),
      ('T02_Concave_Inner_Corner',(0,0,0),'concave','A clear 90-degree inner recess separates the two faces; exact same T01 connectors.'),
      ('T02_Broken_Exposed_Upper_Corner',(5.4,0,0),'broken','Same intact convex source; one exposed upper corner recedes on 2-3 broad planes.')]
    roots=[];models=[]
    for root_name,loc,variant,design in descriptions:
        root=bpy.data.objects.new(root_name,None);export.objects.link(root);root.location=loc
        root['pivot']='bottom center; 4 x 4 m module footprint; bottom z=0'
        root['design']=design;root['variant']=variant
        mesh=build_corner_mesh(export,template,material,root_name+'_Stone',variant,root)
        roots.append(root);models.append(mesh)
    # Preview studio, camera and ground are strictly outside the export collection.
    gm=bpy.data.meshes.new('T02_PreviewGround_Mesh');gm.from_pydata([(-100,-100,-.015),(100,-100,-.015),(100,100,-.015),(-100,100,-.015)],[],[(0,1,2,3)])
    gmat=bpy.data.materials.new('T02_PreviewGround_Material');gmat.use_nodes=True
    bs=next(n for n in gmat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(*[.055,.060,.064],1);bs.inputs['Roughness'].default_value=.9
    gm.materials.append(gmat);ground=bpy.data.objects.new('T02_PreviewGround',gm);preview.objects.link(ground)
    world=bpy.data.worlds.new('T02_PreviewWorld');world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.13,.15,.18,1);bg.inputs['Strength'].default_value=.45;scene.world=world
    area_light(preview,'T02_Key',(-8,-10,13),2200,9,(0,0,2.7));area_light(preview,'T02_Fill',(9,-4,9),1000,7,(0,0,2.7));area_light(preview,'T02_Rim',(0,9,11),1600,7,(0,0,2.7))
    cd=bpy.data.cameras.new('T02_PreviewCamera_Data');cam=bpy.data.objects.new('T02_PreviewCamera',cd);preview.objects.link(cam);scene.camera=cam
    cam.location=(11,-19,12);cam.rotation_euler=(Vector((0,0,2.5))-cam.location).to_track_quat('-Z','Y').to_euler();cd.type='PERSP';cd.sensor_fit='VERTICAL';cd.sensor_height=24;cd.lens=40
    before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb');imported=list(set(bpy.data.objects)-before)
    rig=next((o for o in imported if o.type=='ARMATURE'),None);assert rig,'Actual fox GLB import failed'
    for ob in imported:
        original=ob.name
        for col in list(ob.users_collection):col.objects.unlink(ob)
        preview.objects.link(ob);ob.name='T02_Fox_'+original.replace('.','_')
        if any(k in original.lower() for k in ('icosphere','sword')):ob.hide_render=True;ob.hide_set(True)
    idle=next((a for a in bpy.data.actions if a.name=='Idle'),None);assert idle,'Idle fox action missing'
    if not rig.animation_data:rig.animation_data_create()
    rig.animation_data.action=idle;rig.location=(-8.6,-1.6,0);scene.frame_set(1)
    for im in bpy.data.images:
        if 'fox_palette' in im.name.lower() and not im.packed_file:im.pack()
    scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True;scene.view_settings.view_transform='AgX';scene.view_settings.exposure=.05
    scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
    assert len(roots)==len(models)==3 and all(len(o.data.materials)==1 and o.data.color_attributes.get('Color') for o in models)
    for root in roots:root['connector_reference']='T01_Intact_Stone exact source profile measured at x=+edge and rotated 90 degrees'
    note=bpy.data.objects.new('T02_Source_T01ConnectorMeasurement_Note',None);source.objects.link(note);note.hide_render=True;note.hide_set(True)
    note['source_only']=True;note['source_object']='T01_Intact_Stone actual 4 x 3 x 6 mesh; connector cross-sections sampled at each T01 height ring'
    assert all(default.objects.get(n) for n in ('Cube','Camera','Light'))
    print('T02_BUILD_READY',json.dumps({'scene':scene.name,'variants':[r.name for r in roots],'mesh_parts':len(models),'triangles':sum((o.data.calc_loop_triangles() or len(o.data.loop_triangles)) for o in models),'module_dimensions_m':[4,4,6],'connector_source':template.name,'shared_material':material.name,'default_scene_preserved':True,'fox_action':rig.animation_data.action.name}))

main()

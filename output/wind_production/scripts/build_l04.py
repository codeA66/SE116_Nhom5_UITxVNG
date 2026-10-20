import bpy, bmesh, math, os
from mathutils import Vector

ROOT = r'C:/Code/UITxVNG/SE116_Nhom5_UITxVNG'
CODE = 'L04'
OUT = ROOT + '/assets/generated/wind_ruins/l04'
PRE = ROOT + '/output/wind_production/l04'

def lin(hex_color):
    rgb = [int(hex_color[i:i+2], 16) / 255.0 for i in (1, 3, 5)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb) + (1.0,)

PAL = {
    'stone': lin('#555C58'), 'stone_light': lin('#737A73'),
    'stone_mid': lin('#454C49'), 'stone_dark': lin('#303735'),
    'edge': lin('#646C66'), 'channel': lin('#526B68'),
    'fracture': lin('#899087'), 'cliff': lin('#393F3C'),
    'court': lin('#4A504D'), 'court_light': lin('#525955')
}

def shared_material():
    m = bpy.data.materials.new('L04_Shared_Stone_VertexColor')
    m.use_nodes = True
    bs = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value = (1, 1, 1, 1)
    bs.inputs['Roughness'].default_value = .92
    vc = m.node_tree.nodes.new('ShaderNodeVertexColor')
    vc.layer_name = 'Color'
    m.node_tree.links.new(vc.outputs['Color'], bs.inputs['Base Color'])
    return m

def build_mesh(collection, name, verts, faces, colors, material, parent=None):
    me = bpy.data.meshes.new(name + '_Mesh')
    me.from_pydata(verts, [], faces)
    me.update()
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(me); bm.free(); me.update()
    me.materials.append(material)
    attr = me.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='CORNER')
    for poly, color_name in zip(me.polygons, colors):
        rgba = PAL[color_name]
        for loop_index in poly.loop_indices:
            attr.data[loop_index].color = rgba
    ob = bpy.data.objects.new(name, me)
    collection.objects.link(ob)
    if parent: ob.parent = parent
    return ob

def empty(collection, name, parent=None, description=''):
    ob = bpy.data.objects.new(name, None)
    collection.objects.link(ob)
    ob.empty_display_type = 'PLAIN_AXES'
    if parent: ob.parent = parent
    if description: ob['design'] = description
    return ob

def arc_module(collection, name, root, material, start_deg, end_deg, depth=.9, source=None):
    # A closed annular prism. Its 1.5 m in-plane band has a single broad,
    # shallow front-face channel; .9 m is the front-to-back depth.
    if source is not None:
        ob = bpy.data.objects.new(name, source.data)
        collection.objects.link(ob); ob.parent = root
        ob['source_mesh_reused'] = source.name
        ob['arc_span_degrees'] = float(end_deg - start_deg)
        return ob
    ri, ro = 3.5, 5.0
    g0, g1 = 4.08, 4.42
    front, back = -depth / 2, depth / 2
    inset = .085
    profile = [
        (ri + .07, front), (g0, front), (g0, front + inset),
        (g1, front + inset), (g1, front), (ro - .07, front),
        (ro, front + .07), (ro, back - .07), (ro - .07, back),
        (ri + .07, back), (ri, back - .07), (ri, front + .07)
    ]
    strip_colors = ['stone_light', 'stone_mid', 'channel', 'stone_mid',
                    'stone_light', 'edge', 'stone_dark', 'stone_mid',
                    'stone', 'edge', 'stone_dark', 'stone_mid']
    a0 = math.radians(start_deg + .18); a1 = math.radians(end_deg - .18)
    steps = 8
    verts = []
    for k in range(steps + 1):
        a = a0 + (a1 - a0) * k / steps
        for r, y in profile:
            verts.append((r * math.cos(a), y, r * math.sin(a)))
    faces, colors = [], []
    plen = len(profile)
    for k in range(steps):
        for j in range(plen):
            faces.append((k*plen+j, (k+1)*plen+j,
                          (k+1)*plen+(j+1)%plen, k*plen+(j+1)%plen))
            colors.append(strip_colors[j])
    faces.append(tuple(range(plen))); colors.append('fracture')
    faces.append(tuple(steps*plen+j for j in range(plen))); colors.append('fracture')
    ob = build_mesh(collection, name, verts, faces, colors, material, root)
    ob.location = (0, 6.95, 5.55)
    ob['arc_span_degrees'] = float(end_deg - start_deg)
    ob['outer_radius_m'] = 5.0; ob['inner_radius_m'] = 3.5
    ob['radial_band_m'] = 1.5; ob['front_to_back_depth_m'] = depth
    ob['front_channel_radial_width_m'] = .34; ob['front_channel_recess_m'] = inset
    return ob

def rect_octagon(hx, hy, cut):
    return [(-hx+cut,-hy),(hx-cut,-hy),(hx,-hy+cut),(hx,hy-cut),
            (hx-cut,hy),(-hx+cut,hy),(-hx,hy-cut),(-hx,-hy+cut)]

def rect_prism(collection, name, root, material, center, levels, side_colors=None,
               top_color='stone_light', bottom_color='stone_dark'):
    # Each level is (z, half_x, half_y, corner_cut), centered on (x,y).
    x0, y0 = center
    verts = []
    for z, hx, hy, cut in levels:
        verts.extend((x0+x, y0+y, z) for x, y in rect_octagon(hx, hy, cut))
    faces, colors = [], []
    faces.append(tuple(reversed(range(8)))); colors.append(bottom_color)
    sc = side_colors or ['stone','stone_light','stone_mid','stone','stone_light','stone_mid','stone','stone_mid']
    for layer in range(len(levels)-1):
        for i in range(8):
            faces.append((layer*8+i, layer*8+(i+1)%8,
                          (layer+1)*8+(i+1)%8, (layer+1)*8+i))
            colors.append(sc[i % len(sc)])
    off = (len(levels)-1)*8
    faces.append(tuple(off+i for i in range(8))); colors.append(top_color)
    ob = build_mesh(collection, name, verts, faces, colors, material, root)
    return ob

def add_court(collection, root, material, damaged=False):
    # A quiet low square platform; the four large plates avoid the illustration's tile grid.
    rect_prism(collection, 'L04_'+('Damaged' if damaged else 'Intact')+'_CourtFoundation', root, material,
               (0,0), [(-.38,8.0,8.0,.12),(-.12,7.9,7.9,.12),(-.06,7.78,7.78,.10)],
               side_colors=['stone_dark','stone_mid','stone_dark','stone_mid']*2,
               top_color='stone_mid', bottom_color='stone_dark')
    rect_prism(collection, f"L04_{'Damaged' if damaged else 'Intact'}_CourtSurface", root, material,
               (0,0), [(-.06,7.78,7.78,.10),(0,7.68,7.68,.10)],
               side_colors=['stone_dark']*8, top_color='court', bottom_color='stone_dark')
    # Low boundaries stay outside the 12 x 12 m clear foreground square.
    for side, x in [('Left',-7.63),('Right',7.63)]:
        rect_prism(collection, f"L04_{'Damaged' if damaged else 'Intact'}_LowCourtWall_{side}", root, material,
                   (x,6.0), [(0,.30,2.05,.10),(.36,.24,1.92,.08)],
                   side_colors=['stone_mid','stone','stone_dark','stone_mid']*2,
                   top_color='stone_light', bottom_color='stone_dark')
    rect_prism(collection, f"L04_{'Damaged' if damaged else 'Intact'}_LowCourtWall_Rear", root, material,
               (0,7.62), [(0,7.5,.28,.08),(.48,7.3,.22,.07)],
               side_colors=['stone_mid','stone','stone_dark','stone_mid']*2,
               top_color='stone_light', bottom_color='stone_dark')

def add_foot(collection, name, root, material, x):
    return rect_prism(collection, name, root, material, (x,6.95),
                      [(0,.78,.62,.17),(1.28,.64,.53,.14),(1.42,.58,.49,.12)],
                      side_colors=['stone_mid','stone_light','stone','stone_dark']*2,
                      top_color='stone_light', bottom_color='stone_dark')

def add_side_cliff(collection, root, material):
    # Broken ring rests below the court, against this short side-cliff retaining mass.
    rect_prism(collection, 'L04_Damaged_SideCliffWall', root, material,
               (8.92,9.72), [(-3.0,.42,2.35,.22),(-1.2,.52,2.15,.18),(.42,.42,1.86,.18)],
               side_colors=['cliff','stone_dark','cliff','stone_mid']*2,
               top_color='stone_mid', bottom_color='cliff')
    rect_prism(collection, 'L04_Damaged_SideCliffOutcrop', root, material,
               (9.58,11.42), [(-2.6,.82,.72,.22),(-.9,.62,.56,.18)],
               side_colors=['cliff','stone_mid','cliff','stone_dark']*2,
               top_color='stone_mid', bottom_color='cliff')

def build_state(collection, root, material, damaged=False, intact_modules=None):
    add_court(collection, root, material, damaged)
    add_foot(collection, 'L04_'+('Damaged' if damaged else 'Intact')+'_LowFoot_Left', root, material, -2.86)
    add_foot(collection, 'L04_'+('Damaged' if damaged else 'Intact')+'_LowFoot_Right', root, material, 2.86)
    modules = []
    missing = {1,2} if damaged else set()  # 72 degrees, inside the requested 70-90 degree range.
    for i in range(10):
        a0, a1 = i*36.0, (i+1)*36.0
        if i in missing: continue
        ob = arc_module(collection, f"L04_{'Damaged' if damaged else 'Intact'}_RingArc_{i+1:02d}",
                        root, material, a0, a1)
        modules.append(ob)
    if damaged:
        # Reuse the exact two missing intact meshes; tip them toward the exterior side cliff.
        for j, i in enumerate(sorted(missing), 1):
            src = intact_modules[i]
            frag = arc_module(collection, f'L04_Damaged_FallenMatchingArc_{j:02d}', root, material,
                              i*36.0, (i+1)*36.0, source=src)
            frag.location = (7.60, 13.00, -2.10)
            frag.rotation_euler = (math.radians(60.0), 0.0, 0.0)
            frag['same_source_mesh_as_intact'] = True
        add_side_cliff(collection, root, material)
    root['state'] = 'damaged_missing_72_degree_arc' if damaged else 'intact'
    root['court_dimensions_m'] = [16.0,16.0]
    root['ring_outer_diameter_m'] = 10.0
    root['ring_inner_diameter_m'] = 7.0
    root['ring_radial_band_m'] = 1.5
    root['ring_front_to_back_depth_m'] = .9
    root['ring_arc_modules_present'] = 8 if damaged else 10
    root['broken_sector_degrees'] = 72.0 if damaged else 0.0
    root['foreground_clear_square_m'] = [12.0,12.0]
    return modules

def source_locator(collection, name, loc, description):
    ob = empty(collection, 'L04_Source_'+name, description=description)
    ob.location = loc; ob.hide_render = True; ob.hide_set(True)
    ob['source_only'] = True
    ob['local_coordinates_blender_m'] = [float(v) for v in loc]
    return ob

def preview_setup(scene, preview):
    cd = bpy.data.cameras.new('L04_PreviewCamera_Data')
    cam = bpy.data.objects.new('L04_PreviewCamera', cd); preview.objects.link(cam); scene.camera = cam
    for name,loc,power,size in [('L04_Key',(-15,-20,24),6500,14),('L04_Fill',(15,-8,13),3400,12),('L04_Rim',(1,17,21),5200,12)]:
        ld = bpy.data.lights.new(name,'AREA'); ld.energy=power; ld.shape='DISK'; ld.size=size
        light = bpy.data.objects.new(name,ld); preview.objects.link(light); light.location=loc
        light.rotation_euler=(Vector((0,2,3))-light.location).to_track_quat('-Z','Y').to_euler()
    ground_mat = bpy.data.materials.new('L04_PreviewGround'); ground_mat.diffuse_color=lin('#737875')
    ground_mat.use_nodes=True
    bs=next(n for n in ground_mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value=lin('#737875'); bs.inputs['Roughness'].default_value=.96
    me=bpy.data.meshes.new('L04_PreviewGround_Mesh')
    me.from_pydata([(-100,-100,-.4),(100,-100,-.4),(100,100,-.4),(-100,100,-.4)],[],[(0,1,2,3)])
    me.materials.append(ground_mat); floor=bpy.data.objects.new('L04_PreviewGround',me); preview.objects.link(floor)
    world=bpy.data.worlds.new('L04_PreviewWorld'); world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
    bg.inputs['Color'].default_value=(.34,.36,.36,1); bg.inputs['Strength'].default_value=.78; scene.world=world
    before=set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=ROOT+'/generated/models/fox_spirit.glb')
    imported=list(set(bpy.data.objects)-before); rig=next((o for o in imported if o.type=='ARMATURE'),None)
    if not rig: raise RuntimeError('The actual fox scale reference did not import as a rig')
    for ob in imported:
        old=ob.name
        for c in list(ob.users_collection): c.objects.unlink(ob)
        preview.objects.link(ob); ob.name='L04_Fox_'+old.replace('.','_')
        if any(k in old.lower() for k in ('icosphere','sword')):
            ob.hide_render=True; ob.hide_set(True)
    idle=next((a for a in bpy.data.actions if a.name=='Idle'),None)
    if idle:
        if not rig.animation_data: rig.animation_data_create()
        rig.animation_data.action=idle
    scene.frame_set(1)
    rig.location=(-9,-4.4,0)
    for im in bpy.data.images:
        if 'fox_palette' in im.name.lower() and not im.packed_file:
            im.pack()
    return cam,rig

def main():
    assert bpy.data.scenes.get('Scene') is not None, 'Original default scene must remain preserved'
    assert bpy.data.scenes.get('WindProduction_L04') is None, 'Refusing to duplicate an existing L04 scene'
    os.makedirs(OUT+'/source',exist_ok=True); os.makedirs(PRE,exist_ok=True)
    open(OUT+'/source/.gdignore','w').close()
    scene=bpy.data.scenes.new('WindProduction_L04'); bpy.context.window.scene=scene
    scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1.0
    export=bpy.data.collections.new('L04_Export'); scene.collection.children.link(export)
    preview=bpy.data.collections.new('L04_Preview_ONLY'); scene.collection.children.link(preview)
    source=bpy.data.collections.new('L04_SourceLocators_NOT_EXPORTED'); scene.collection.children.link(source)
    material=shared_material()
    intact=empty(export,'L04_Intact_WindOrchestraRing',description='10 m OD, 7 m opening, 0.9 m depth, 10 broad arcs and one recessed front channel; far side of a 16 m court.')
    damaged=empty(export,'L04_Damaged_WindOrchestraRing',description='Same court and ring, with one exact 72-degree sector reused as a matching fallen fragment below the side cliff.')
    intact_modules={}
    add_court(export,intact,material,False)
    add_foot(export,'L04_Intact_LowFoot_Left',intact,material,-2.86)
    add_foot(export,'L04_Intact_LowFoot_Right',intact,material,2.86)
    for i in range(10):
        intact_modules[i]=arc_module(export,f'L04_Intact_RingArc_{i+1:02d}',intact,material,i*36.0,(i+1)*36.0)
    intact['state']='intact'; intact['court_dimensions_m']=[16,16]; intact['ring_outer_diameter_m']=10.0
    intact['ring_inner_diameter_m']=7.0; intact['ring_radial_band_m']=1.5; intact['ring_front_to_back_depth_m']=.9
    intact['ring_arc_modules_present']=10; intact['foreground_clear_square_m']=[12.0,12.0]
    build_state(export,damaged,material,True,intact_modules)
    source_locator(source,'BottomCenterPivot',(0,0,0),'Per-state model pivot at the center of the courtyard ground plane.')
    source_locator(source,'RingCenter',(0,6.95,5.55),'Center of the 10 m outer diameter circular monument.')
    source_locator(source,'ForegroundClearSquareCenter',(0,-2,0),'12 x 12 m clear square: x=-6..6, y=-8..4.')
    source_locator(source,'FallenArcAndCliffAnchor',(7.60,13.00,-2.10),'Matching 72-degree source arc tilted against the side cliff below the court.')
    source['clear_foreground_bounds_local_m']={'x':[-6,6],'y':[-8,4]}
    source['dimensions']={'court':[16,16],'outer_diameter':10,'inner_diameter':7,'radial_band':1.5,'front_to_back_depth':.9}
    cam,fox=preview_setup(scene,preview)
    intact.location=(-9,0,0); damaged.location=(9,0,0)
    cam.location=(0,-44,32); cam.rotation_euler=(Vector((0,2,3))-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='PERSP'; cam.data.sensor_fit='VERTICAL'; cam.data.sensor_height=24; cam.data.lens=42
    scene.render.engine='CYCLES'; scene.cycles.samples=16; scene.cycles.use_denoising=True
    scene.view_settings.view_transform='AgX'; scene.render.resolution_x=1280; scene.render.resolution_y=720; scene.render.resolution_percentage=100
    for ob in bpy.context.view_layer.objects: ob.select_set(False)
    for ob in export.objects: ob.select_set(True)
    bpy.context.view_layer.objects.active=intact
    print('L04_CREATED',{'scene':scene.name,'export_meshes':sum(o.type=='MESH' for o in export.objects),
          'intact_arcs':sum('Intact_RingArc' in o.name for o in export.objects),
          'damaged_arcs':sum('Damaged_RingArc' in o.name for o in export.objects),
          'fallen_reused_modules':sum('FallenMatchingArc' in o.name for o in export.objects),
          'shared_single_material':material.name,'fox_action':fox.animation_data.action.name if fox.animation_data and fox.animation_data.action else None,
          'default_scene_preserved':bpy.data.scenes.get('Scene') is not None})

main()

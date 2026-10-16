
import bpy, math, os, json
from mathutils import Vector, Matrix
rig=bpy.data.objects["FoxRig"];scene=bpy.context.scene
scene.render.fps=30
def rot(name,x=0,y=0,z=0):
    pb=rig.pose.bones[name];pb.rotation_mode='XYZ'
    pb.rotation_euler=[math.radians(a) for a in (x,y,z)]
def reset(armed):
    for pb in rig.pose.bones:
        pb.rotation_mode='XYZ';pb.location=(0,0,0);pb.rotation_euler=(0,0,0);pb.scale=(1,1,1)
    rot("UpperArm_L",-74,0,4);rot("Forearm_L",-6,0,4)
    rot("UpperArm_R",-55,0,-4);rot("Forearm_R",-12,0,-9)
    rot("Hand_R",85 if armed else 0)
def aim(name,head,target):
    pb=rig.pose.bones[name]
    rest=pb.bone.matrix_local.to_quaternion()
    direction=pb.bone.tail_local-pb.bone.head_local
    rotation=direction.rotation_difference(target-head) @ rest
    pb.matrix=Matrix.Translation(head) @ rotation.to_matrix().to_4x4()
    bpy.context.view_layer.update()
def foot_ik(side,forward,lift):
    thigh=rig.pose.bones["Thigh_"+side];shin=rig.pose.bones["Shin_"+side]
    foot=rig.pose.bones["Foot_"+side]
    hip=thigh.head.copy()
    ankle=Vector((.13 if side=="R" else -.13,-forward,.115+lift))
    d=ankle-hip;length=min(d.length,thigh.bone.length+shin.bone.length-.0005);direction=d.normalized()
    a=(thigh.bone.length**2-shin.bone.length**2+length**2)/(2*length)
    bend=Vector((0,-1,0));bend=(bend-direction*bend.dot(direction)).normalized()
    knee=hip+direction*a+bend*math.sqrt(max(0,thigh.bone.length**2-a*a))
    aim(thigh.name,hip,knee);aim(shin.name,knee,ankle)
    # Feet retain their ground-facing orientation, instead of kicking upward.
    foot.matrix=Matrix.Translation(ankle) @ foot.bone.matrix_local.to_quaternion().to_matrix().to_4x4()
    bpy.context.view_layer.update()
def idle(t,armed):
    p=t*math.tau
    rig.pose.bones["Hips"].location.y=.003*math.sin(p)
    rot("Spine",.6*math.sin(p))
    rot("Head",0,1.2*math.sin(p))
    rot("Tail01",0,0,3*math.sin(p))
    rot("Tail02",0,0,4*math.sin(p-.5))
    rot("Tail03",0,0,5*math.sin(p-1))
def running(t,armed):
    phase=t*math.tau
    # Lower the pelvis enough to allow a small natural stride without
    # hyperextending either short leg. Feet plant flat during stance.
    rig.pose.bones["Hips"].location.y=-.045+.006*math.cos(phase*2)
    rot("Spine",9,0,0);rot("Chest",2,0,1.2*math.sin(phase))
    rot("Head",-8,0,0)
    if armed:
        rot("UpperArm_R",-52+3*math.sin(phase),0,-4)
        rot("Forearm_R",-14,0,-9);rot("Hand_R",87)
    else:
        rot("UpperArm_R",-71+7*math.sin(phase),0,-4)
        rot("Forearm_R",-12,0,-4);rot("Hand_R",0)
    rot("UpperArm_L",-71-7*math.sin(phase),0,4)
    rot("Forearm_L",-12,0,4)
    rot("Tail01",-6,0,4*math.sin(phase-.25))
    rot("Tail02",0,0,6*math.sin(phase-.8));rot("Tail03",0,0,7*math.sin(phase-1.3))
    bpy.context.view_layer.update()
    for side,offset in [("R",0),("L",.5)]:
        q=(t+offset)%1.0
        # Plant: front to back. Swing: return forward with 6 cm clearance.
        if q<.58:
            forward=.13-.24*q/.58;lift=0
        else:
            u=(q-.58)/.42;forward=-.11+.24*(u*u*(3-2*u));lift=.065*math.sin(math.pi*u)
        foot_ik(side,forward,lift)
def airborne(t,fall=False):
    rot("Spine",-4 if fall else -7);rot("Head",3)
    rot("UpperArm_L",-58,0,8)
    rot("UpperArm_R",-48,0,-6);rot("Hand_R",85)
    rot("Thigh_R",-15 if fall else -28)
    rot("Thigh_L",6 if fall else -17)
    rot("Shin_R",24 if fall else 36);rot("Shin_L",12 if fall else 28)
    rot("Foot_R",-8);rot("Foot_L",-8)
    rot("Tail01",-8,0,2*math.sin(t*math.tau));rot("Tail02",4)
def landing(t):
    u=math.sin(t*math.pi)
    rig.pose.bones["Hips"].location.y=-.045*u
    rot("Spine",8*u);rot("Head",-5*u)
    bpy.context.view_layer.update()
    foot_ik("R",.025,0);foot_ik("L",.025,0)
def dodge(t):
    rig.pose.bones["Hips"].location.y=-.035*math.sin(t*math.pi)
    rot("Spine",18);rot("Head",-12)
    rot("UpperArm_L",-78,0,10);rot("UpperArm_R",-58,0,-6)
    rot("Hand_R",95);rot("Tail01",-12);rot("Tail02",-5)
    rot("Thigh_R",-14);rot("Shin_R",20);rot("Thigh_L",12);rot("Shin_L",15)
def pickup(t):
    u=math.sin(t*math.pi)
    rig.pose.bones["Hips"].location.y=-.035*u
    rot("Spine",27*u);rot("Head",4*u)
    rot("UpperArm_R",-74+28*u,0,-6);rot("Forearm_R",-8*u)
    bpy.context.view_layer.update();foot_ik("R",.025,0);foot_ik("L",.025,0)
def flinch(t):
    u=math.sin(t*math.pi);rot("Spine",-10*u);rot("Head",5*u)
    rot("UpperArm_L",-74+6*u,0,4)
def dying(t):
    u=min(1,t*1.6);u=u*u*(3-2*u)
    rot("Root",0,0,82*u);rig.pose.bones["Root"].location=(.08*u,-.12*u,0)
    rot("Spine",12*u);rot("Thigh_R",-18*u);rot("Shin_R",25*u);rot("Hand_R",100)
clips=[("Idle",61,False,lambda t:idle(t,False)),
       ("Idle_Sword",61,True,lambda t:idle(t,True)),
       ("Run",19,False,lambda t:running(t,False)),
       ("Run_Sword",19,True,lambda t:running(t,True)),
       ("Jump",13,True,lambda t:airborne(t,False)),
       ("Fall",31,True,lambda t:airborne(t,True)),
       ("Land",7,True,landing),("Dash",7,True,dodge),("PickUp",34,False,pickup),
       ("Hurt",10,True,flinch),("Death",37,True,dying)]
for name,end,armed,pose in clips:
    action=bpy.data.actions[name]
    # Recreate the motion data in-place: no imported or retargeted action.
    old_name=action.name;rig.animation_data.action=None
    for track in list(rig.animation_data.nla_tracks):
        if track.name==old_name:rig.animation_data.nla_tracks.remove(track)
    bpy.data.actions.remove(action)
    action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action
    for frame in range(1,end+1):
        scene.frame_set(frame);t=(frame-1)/(end-1)
        reset(armed);pose(t)
        for pb in rig.pose.bones:
            pb.keyframe_insert("rotation_euler",frame=frame,group=pb.name)
            pb.keyframe_insert("location",frame=frame,group=pb.name)
    action["duration_seconds"]=(end-1)/30;action["loop"]=name in ["Idle","Idle_Sword","Run","Run_Sword","Fall"]
    rig.animation_data.action=None
    track=rig.animation_data.nla_tracks.new();track.name=name;track.strips.new(name,1,action);track.mute=True
rig.animation_data.action=bpy.data.actions["Idle_Sword"];scene.frame_set(1);scene.frame_start=1;scene.frame_end=61
out=r"C:\Code\UITxVNG\SE116_Nhom5_UITxVNG\generated"
bpy.ops.object.select_all(action='DESELECT')
for n in ["Body","Head","Tail","Eyes","Sword","FoxRig"]:bpy.data.objects[n].select_set(True)
bpy.context.view_layer.objects.active=rig
options=dict(filepath=os.path.join(out,"models","fox_spirit.glb"),export_format='GLB',use_selection=True,export_animations=True,export_yup=True,export_frame_range=False,export_force_sampling=True,export_animation_mode='ACTIONS')
if "export_optimize_animation_size" in bpy.ops.export_scene.gltf.get_rna_type().properties:
    options["export_optimize_animation_size"]=False
bpy.ops.export_scene.gltf(**options)
# Also update the standalone sword with the padded palette.
src=bpy.data.objects["Sword"];pickup=src.copy();pickup.data=src.data.copy()
collection=bpy.data.collections["Fox_New_Design_v03"];collection.objects.link(pickup)
pickup.parent=None;pickup.modifiers.clear();pickup.vertex_groups.clear();pickup.name="SwordPickup"
for v in pickup.data.vertices:
    v.co-=Vector((.575,-.025,.985));v.co.z=-v.co.z
bpy.ops.object.select_all(action='DESELECT');pickup.select_set(True);bpy.context.view_layer.objects.active=pickup
bpy.ops.export_scene.gltf(filepath=os.path.join(out,"models","fox_sword.glb"),export_format='GLB',use_selection=True,export_animations=False)
bpy.data.objects.remove(pickup,do_unlink=True)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out,"source","fox_spirit_animated.blend"))
manifest={}
for action in bpy.data.actions:
    if action.name in [n for n,_,_,_ in clips]+["Attack_Horizontal"]:
        manifest[action.name]={"loop":bool(action.get("loop",False)),"duration":float(action.get("duration_seconds",.6))}
with open(os.path.join(out,"source","animation_manifest.json"),"w",encoding="utf-8") as f:json.dump(manifest,f,indent=2)
print("New locomotion authored; 0.6 s run, planted feet, modest arm motion, offset tail follow.")


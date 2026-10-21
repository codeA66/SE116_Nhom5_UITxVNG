
import bpy, math, os, json
from mathutils import Vector, Matrix, Quaternion
rig=bpy.data.objects["FoxRig"];scene=bpy.context.scene
def P(x,h,f):return Vector((x,-f,h))
def rot(name,x=0,y=0,z=0):
    b=rig.pose.bones[name];b.rotation_mode='XYZ';b.rotation_euler=[math.radians(a) for a in (x,y,z)]
def reset():
    for b in rig.pose.bones:
        b.rotation_mode='XYZ';b.location=(0,0,0);b.rotation_euler=(0,0,0);b.scale=(1,1,1)
def aim(name,head,target):
    b=rig.pose.bones[name];rest=b.bone.matrix_local.to_quaternion()
    q=(b.bone.tail_local-b.bone.head_local).rotation_difference(target-head)@rest
    b.matrix=Matrix.Translation(head)@q.to_matrix().to_4x4();bpy.context.view_layer.update()
def chain(first,second,target,bend):
    a=rig.pose.bones[first];b=rig.pose.bones[second];head=a.head.copy()
    d=target-head;distance=min(d.length,a.bone.length+b.bone.length-.0001)
    direction=d.normalized()
    along=(a.bone.length**2-b.bone.length**2+distance**2)/(2*distance)
    perp=(bend-direction*bend.dot(direction)).normalized()
    joint=head+direction*along+perp*math.sqrt(max(0,a.bone.length**2-along**2))
    aim(first,head,joint);aim(second,joint,target)
def foot(side,forward,lift=0,pitch=0):
    target=P(.13 if side=="R" else -.13,.115+lift,forward)
    chain("Thigh_"+side,"Shin_"+side,target,Vector((0,-1,0)))
    b=rig.pose.bones["Foot_"+side]
    q=Quaternion((1,0,0),math.radians(pitch))@b.bone.matrix_local.to_quaternion()
    b.matrix=Matrix.Translation(target)@q.to_matrix().to_4x4();bpy.context.view_layer.update()
def arm(side,x,h,forward,armed):
    s=1 if side=="R" else -1
    target=P(s*x,h,forward)
    shoulder=rig.pose.bones["UpperArm_"+side].head.copy()
    direction=(target-shoulder).normalized()
    for name in ["UpperArm_"+side,"Forearm_"+side,"Hand_"+side]:
        bone=rig.pose.bones[name]
        start=bone.head.copy()
        aim(name,start,start+direction*bone.bone.length)
    if side=="R" and armed:
        hand=rig.pose.bones["Weapon_R"]
        down=Vector((0,0,-1));blade=Vector((.52,-.38,-.76)).normalized()
        q=down.rotation_difference(blade)@hand.bone.matrix_local.to_quaternion()
        hand.matrix=Matrix.Translation(hand.head)@q.to_matrix().to_4x4()
        bpy.context.view_layer.update()
def tail(phase,amount=1):
    for index,name in enumerate(["Tail01","Tail02","Tail03"]):
        b=rig.pose.bones[name]
        yaw=math.radians((7+index*4)*amount*math.sin(phase-index*.65))
        pitch=math.radians((1.5+index)*amount*math.sin(phase*.0+phase-index*.55+.6))
        q=Quaternion((0,0,1),yaw)@Quaternion((1,0,0),pitch)@b.bone.matrix_local.to_quaternion()
        b.matrix=Matrix.Translation(b.head)@q.to_matrix().to_4x4();bpy.context.view_layer.update()
def shoulders(phase,amount):
    for side,offset,s in [("R",0,1),("L",math.pi,-1)]:
        bone=rig.pose.bones["UpperArm_"+side]
        p=phase+offset
        delta=Vector((s*.003*amount*math.sin(p),.006*amount*math.sin(p-.5),.008*amount*math.cos(p-.35)))
        bone.location=bone.bone.matrix_local.to_quaternion().inverted()@delta
def idle(t,armed):
    p=math.tau*t
    rig.pose.bones["Hips"].location=(.009*math.sin(p),-.02+.005*math.cos(p),0)
    rot("Hips",0,1.4*math.sin(p))
    rot("Spine",1.2+1.1*math.sin(p-.3),-1.0*math.sin(p),-.6*math.sin(p))
    rot("Chest",.7*math.sin(p-.3),0,.5*math.sin(p))
    rig.pose.bones["Chest"].scale=(1+.006*math.sin(p),1+.004*math.sin(p),1+.004*math.sin(p))
    rot("Neck",-.5,0,0);rot("Head",-1.0,3.4*math.sin(p),.6*math.sin(p))
    shoulders(p,.4)
    bpy.context.view_layer.update()
    foot("R",.035);foot("L",.015)
    arm("L",.245,.645+.004*math.sin(p),.015+.006*math.sin(p-.4),False)
    arm("R",.275,.695+.005*math.sin(p-.2),.035,True) if armed else arm("R",.245,.65,.015,False)
    tail(p-.4,.60)
def running(t,armed):
    p=math.tau*t
    rig.pose.bones["Hips"].location=(.010*math.sin(p),-.058+.020*(1-math.cos(p*2))*.5,0)
    rot("Hips",0,-3.0*math.sin(p),1.8*math.sin(p))
    rot("Spine",12,4*math.sin(p),-1.3*math.sin(p))
    rot("Chest",1.2*math.sin(p*2-.5),3*math.sin(p),-.7*math.sin(p))
    rot("Neck",-3);rot("Head",-7+.8*math.sin(p*2),-3*math.sin(p),-.8*math.sin(p))
    shoulders(p,1.0)
    bpy.context.view_layer.update()
    for side,offset in [("R",0),("L",.5)]:
        q=(t+offset)%1
        if q<.45:
            u=q/.45;forward=.18-.34*u
            push=max(0,(u-.70)/.30)
            lift=.026*push*push;pitch=10*push*push
        else:
            u=(q-.45)/.55
            forward=-.16+.34*(u*u*(3-2*u))
            lift=.026*(1-u)+.10*math.sin(math.pi*u)**1.2
            pitch=-8*math.sin(math.pi*u)
        foot(side,forward,lift,pitch)
    # Straight arms swing from the shoulder; no elbow articulation.
    arm("L",.245,.655+.008*math.cos(p),.02+.075*math.sin(p),False)
    if armed:arm("R",.28,.705+.008*math.cos(p*2),.035-.018*math.sin(p),True)
    else:arm("R",.245,.655-.008*math.cos(p),.02-.075*math.sin(p),False)
    tail(p-.9,1.0)
def air(t,fall):
    p=math.tau*t
    rot("Spine",-3 if fall else -7);rot("Head",4)
    rot("Thigh_R",-14 if fall else -25);rot("Shin_R",22 if fall else 43)
    rot("Thigh_L",5 if fall else -19);rot("Shin_L",14 if fall else 35)
    bpy.context.view_layer.update()
    arm("L",.265,.72,.065+.01*math.sin(p),False)
    arm("R",.28,.735,.07,True);tail(p-.5,.45)
def land(t):
    pulse=math.sin(math.pi*t)
    rig.pose.bones["Hips"].location.y=-.02-.065*pulse
    rot("Spine",11*pulse);rot("Head",-6*pulse)
    bpy.context.view_layer.update();foot("R",.035);foot("L",.015)
    arm("L",.255,.665-.02*pulse,.03,False);arm("R",.28,.71,.045,True)
    tail(t*math.tau-.5,.6)
def dash(t):
    pulse=math.sin(math.pi*t)
    rig.pose.bones["Hips"].location.y=-.055
    rot("Spine",23);rot("Chest",-2);rot("Head",-16)
    rot("Thigh_R",-21);rot("Shin_R",32);rot("Thigh_L",18);rot("Shin_L",23)
    bpy.context.view_layer.update()
    arm("L",.25,.665,-.075,False);arm("R",.28,.72,.04,True)
    tail(t*math.pi,.25)
def pickup(t):
    u=math.sin(math.pi*t)
    rig.pose.bones["Hips"].location.y=-.02-.045*u
    rot("Spine",30*u);rot("Head",3*u)
    bpy.context.view_layer.update();foot("R",.055);foot("L",0)
    arm("L",.245,.66-.03*u,.025,False)
    arm("R",.265,.70-.07*u,.05+.10*u,False)
    tail(t*math.tau,.4)
def hurt(t):
    u=math.sin(math.pi*t)
    rig.pose.bones["Hips"].location.y=-.02
    rot("Spine",-13*u);rot("Head",7*u)
    bpy.context.view_layer.update()
    foot("R",.035);foot("L",.015)
    arm("L",.255,.665+.015*u,.025,False);arm("R",.28,.71,.045,True)
    tail(t*math.tau,.25)
def slash(t):
    # Shoulder-driven sweep; the elbow and wrist stay straight.
    if t < .25:
        u=t/.25
        direction=Vector((.22,-.97,.03)).lerp(Vector((.91,-.30,-.28)),u).normalized()
        yaw=-28*u
    elif t < .55:
        u=(t-.25)/.30
        angle=math.radians(-17+145*u)
        direction=Vector((math.cos(angle),-.22,math.sin(angle))).normalized()
        yaw=-28+55*u
    else:
        u=(t-.55)/.45;u=u*u*(3-2*u)
        direction=Vector((-.60,-.22,.79)).lerp(Vector((.22,-.97,.03)),u).normalized()
        yaw=27*(1-u)
    rot("Hips",0,yaw*.25);rot("Spine",4,yaw*.75);rot("Head",-2,-yaw*.35)
    bpy.context.view_layer.update()
    arm("L",.245,.65,-.025,False)
    shoulder=rig.pose.bones["UpperArm_R"].head.copy()
    for name in ["UpperArm_R","Forearm_R","Hand_R"]:
        bone=rig.pose.bones[name];start=bone.head.copy()
        aim(name,start,start+Vector((direction.x,-direction.z,direction.y))*bone.bone.length)
    weapon=rig.pose.bones["Weapon_R"]
    if .12<t<.70:
        blade=Vector((direction.x,-direction.z,0)).normalized()
    else:
        blade=Vector((.52,-.38,-.76)).normalized()
    q=Vector((0,0,-1)).rotation_difference(blade)@weapon.bone.matrix_local.to_quaternion()
    weapon.matrix=Matrix.Translation(weapon.head)@q.to_matrix().to_4x4()
    bpy.context.view_layer.update()
    tail(t*math.tau,.5)
def dying(t):
    u=min(1,t*1.6);u=u*u*(3-2*u)
    rot("Root",0,0,82*u)
    rig.pose.bones["Root"].location=(.08*u,-.12*u,0)
    rot("Spine",12*u);rot("Thigh_R",-18*u);rot("Shin_R",25*u)
    bpy.context.view_layer.update()
    root_rotation=rig.pose.bones["Root"].matrix.to_quaternion()
    for side,s in [("R",1),("L",-1)]:
        direction=root_rotation@P(s*.2,-.98,.015).normalized()
        for name in ["UpperArm_"+side,"Forearm_"+side,"Hand_"+side]:
            b=rig.pose.bones[name];start=b.head.copy()
            aim(name,start,start+direction*b.bone.length)
definitions=[("Idle",91,False,lambda t:idle(t,False)),("Idle_Sword",91,True,lambda t:idle(t,True)),
("Run",17,False,lambda t:running(t,False)),("Run_Sword",17,True,lambda t:running(t,True)),
("Jump",13,False,lambda t:air(t,False)),("Fall",31,True,lambda t:air(t,True)),
("Land",7,False,land),("Dash",7,False,dash),("PickUp",34,False,pickup),("Hurt",10,False,hurt),
("Attack_Horizontal",19,False,slash),("Death",37,False,dying)]
for name,end,loop,pose in definitions:
    rig.animation_data.action=None
    for track in list(rig.animation_data.nla_tracks):
        if track.name==name:rig.animation_data.nla_tracks.remove(track)
    bpy.data.actions.remove(bpy.data.actions[name])
    a=bpy.data.actions.new(name);a.use_fake_user=True;rig.animation_data.action=a
    for f in range(1,end+1):
        scene.frame_set(f);reset();pose((f-1)/(end-1))
        for b in rig.pose.bones:
            b.keyframe_insert("rotation_euler",frame=f,group=b.name)
            b.keyframe_insert("location",frame=f,group=b.name)
            b.keyframe_insert("scale",frame=f,group=b.name)
    a["loop"]=loop or name in ["Idle","Idle_Sword","Run","Run_Sword"]
    a["duration_seconds"]=(end-1)/30
    rig.animation_data.action=None
    tr=rig.animation_data.nla_tracks.new();tr.name=name;tr.strips.new(name,1,a);tr.mute=True
# Let the shoulder cap blend from the torso into the upper arm.
body=bpy.data.objects["Body"];adj=[[] for _ in body.data.vertices]
for e in body.data.edges:
    i,j=e.vertices;adj[i].append(j);adj[j].append(i)
unseen=set(range(len(adj)))
while unseen:
    i=unseen.pop();stack=[i];island=[i]
    while stack:
        for j in adj[stack.pop()]:
            if j in unseen:unseen.remove(j);stack.append(j);island.append(j)
    center=sum((body.data.vertices[i].co for i in island),Vector())/len(island)
    if .19<abs(center.x)<.31 and .91<center.z<1.09:
        for group in body.vertex_groups:group.remove(island)
        upper=body.vertex_groups.get("UpperArm_R" if center.x>0 else "UpperArm_L")
        chest=body.vertex_groups.get("Chest")
        for i in island:
            t=max(0,min(1,(abs(body.data.vertices[i].co.x)-.14)/.13))
            w=t*t*(3-2*t)
            if w>0:upper.add([i],w,'REPLACE')
            if w<1:chest.add([i],1-w,'REPLACE')
rig.animation_data.action=bpy.data.actions["Idle_Sword"];scene.frame_start=1;scene.frame_end=91;scene.frame_set(1)
out=r"C:\Code\UITxVNG\SE116_Nhom5_UITxVNG\assets\characters\fox"
bpy.ops.object.select_all(action='DESELECT')
for n in ["Body","Head","Tail","Eyes","Sword","FoxRig"]:bpy.data.objects[n].select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=os.path.join(out,"fox_spirit.glb"),export_format='GLB',use_selection=True,export_animations=True,export_yup=True,export_frame_range=False,export_force_sampling=True,export_animation_mode='ACTIONS',export_optimize_animation_size=False)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out,"source","fox_spirit_animated.blend"))
manifest={}
for a in bpy.data.actions:
    if a.name in [x[0] for x in definitions]+["Death","Attack_Horizontal"]:
        manifest[a.name]={"loop":bool(a.get("loop",False)),"duration":float(a.get("duration_seconds",.6))}
with open(os.path.join(out,"source","animation_manifest.json"),"w",encoding="utf-8") as f:json.dump(manifest,f,indent=2)
print("Motion authored: straight shoulder-driven arms, separate sword grip, breathing and delayed tail follow.")


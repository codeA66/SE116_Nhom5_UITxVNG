shader_type spatial;
render_mode unshaded,cull_disabled,blend_mix,depth_prepass_alpha;
uniform sampler2D flow : source_color,repeat_disable,filter_linear_mipmap;
uniform vec4 core_color : source_color=vec4(1.0,0.941,0.671,1);
uniform vec4 hot_color : source_color=vec4(1.0,0.769,0.239,1);
uniform vec4 flame_color : source_color=vec4(1.0,0.478,0.035,1);
uniform vec4 edge_color : source_color=vec4(0.725,0.212,0.071,1);
uniform float opacity=0.0;
uniform float charge=0.0;
uniform float pulse=0.0;
uniform float clock=0.0;
uniform float prewarm_scale=1.0;
uniform float flow_speed=1.6;
uniform float curl=0.10;
uniform float edge_width=0.025;
uniform bool swirl=false;
uniform float coil_speed=5.0;
uniform bool particle=false;
uniform bool burst=false;
uniform float gather_count=24.0;
uniform float minimum_count=4.0;
varying float allowed;
void vertex(){
 allowed=1.0;
 if(particle){
  vec3 s=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
  MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*s.x,INV_VIEW_MATRIX[1]*s.y,INV_VIEW_MATRIX[2]*s.z,MODEL_MATRIX[3]);
  if(!burst){allowed=1.0-step(mix(minimum_count,gather_count,charge),float(INSTANCE_ID));}
 }else if(swirl){
  float angle=clock*coil_speed + sin(UV.x*8.0-clock*flow_speed*4.0)*curl;
  VERTEX.xy=mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)))*VERTEX.xy;
 }else{
  float along=clamp(VERTEX.z+0.5,0.0,1.0);
  VERTEX.xy*=mix(1.0,0.80,along);
  VERTEX.y+=along*along*curl*1.5;
  float twist=UV.x*18.85+clock*flow_speed*4.0;
  VERTEX.xz*=1.0+sin(twist+UV.y*8.0)*curl;
  VERTEX.x+=sin(UV.y*9.0-clock*7.0)*curl*UV.y;
 }
 VERTEX*=prewarm_scale;
}
void fragment(){
 if(particle){
  vec2 p=UV*2.0-1.0;
  float mask=1.0-smoothstep(0.55,0.55+edge_width,abs(p.x)+abs(p.y));
  ALBEDO=mix(hot_color.rgb,core_color.rgb,1.0-abs(p.y));
  ALPHA=mask*COLOR.a*opacity*allowed;
 }else if(swirl){
  float flow_wave=sin(UV.x*18.0-clock*flow_speed*8.0)*0.5+0.5;
  vec3 col=mix(edge_color.rgb,flame_color.rgb,step(0.20,flow_wave));
  col=mix(col,hot_color.rgb,step(0.58,flow_wave));
  col=mix(col,core_color.rgb,step(0.85,flow_wave+pulse*0.30));
  float shape=sin(UV.y*3.14159)*(0.6+flow_wave*0.4);
  shape*=smoothstep(0.0,0.08,UV.x)*(1.0-smoothstep(0.88,1.0,UV.x));
  ALBEDO=col;
  ALPHA=opacity*smoothstep(1.0-opacity-edge_width,1.0-opacity+edge_width,shape);
 }else{
  vec4 art=texture(flow,vec2(fract(UV.x-clock*flow_speed),clamp(UV.y,0.02,0.98)));
  float facing=abs(dot(normalize(NORMAL),normalize(VIEW)));
  float heat=clamp(art.g*0.30+facing*0.70+pulse*0.20,0.0,1.0);
  vec3 col=mix(edge_color.rgb,flame_color.rgb,step(0.24,heat));
  col=mix(col,hot_color.rgb,step(0.53,heat));
  col=mix(col,core_color.rgb,step(0.84,heat));
  ALBEDO=col;
  ALPHA=opacity*smoothstep(1.0-opacity-edge_width,1.0-opacity+edge_width,0.45+art.g*0.55);
 }
}

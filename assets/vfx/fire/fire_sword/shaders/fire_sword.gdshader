shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_prepass_alpha;
uniform sampler2D flame_map : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 core_color : source_color = vec4(1.0,0.941,0.671,1.0);
uniform vec4 hot_color : source_color = vec4(1.0,0.769,0.239,1.0);
uniform vec4 flame_color : source_color = vec4(1.0,0.478,0.035,1.0);
uniform vec4 edge_color : source_color = vec4(0.725,0.212,0.071,1.0);
uniform float clock=0.0;
uniform float reveal=0.0;
uniform float dissolve=0.0;
uniform float sweep_sign=1.0;
uniform float prewarm_scale=1.0;
uniform float curl_amount=0.10;
uniform float flow_speed=1.8;
uniform float edge_sharpness=0.025;
uniform bool ember=false;
uniform bool flash=false;
void vertex(){
 if(ember || flash){
  vec3 s=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
  MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*s.x,INV_VIEW_MATRIX[1]*s.y,INV_VIEW_MATRIX[2]*s.z,MODEL_MATRIX[3]);
 }else{
  VERTEX.y+=sin(UV.x*19.0-clock*15.0)*curl_amount*sin(UV.y*3.14159);
 }
 VERTEX*=prewarm_scale;
}
void fragment(){
 if(flash){
  vec2 p=UV*2.0-1.0;
  float rays=pow(abs(cos(2.0*atan(p.y,p.x))),8.0);
  ALBEDO=core_color.rgb;
  ALPHA=1.0-smoothstep(0.13+rays*0.70,0.16+rays*0.72,length(p));
 }else if(ember){
  vec2 p=UV*2.0-1.0;
  float shape=1.0-smoothstep(0.55,0.75,abs(p.x)+abs(p.y));
  ALBEDO=mix(hot_color.rgb,core_color.rgb,1.0-abs(p.y));
  ALPHA=shape*COLOR.a;
 }else{
  float u=sweep_sign>0.0 ? UV.x : 1.0-UV.x;
  float drift=sin(UV.x*13.0-clock*9.0)*0.07;
  vec4 art=texture(flame_map,vec2(fract(UV.x*0.8-clock*flow_speed),clamp(UV.y+drift,0.02,0.98)));
  float heat=clamp((1.0-UV.y)*0.50+art.g*0.75,0.0,1.0);
  vec3 c=mix(edge_color.rgb,flame_color.rgb,step(0.22,heat));
  c=mix(c,hot_color.rgb,step(0.52,heat));
  c=mix(c,core_color.rgb,step(0.83,heat));
  float silhouette=sin(UV.y*3.14159);
  float cut=smoothstep(dissolve-edge_sharpness,dissolve+edge_sharpness,silhouette*(0.65+art.g*0.35));
  float head=1.0-smoothstep(reveal-edge_sharpness,reveal,u);
  float ends=smoothstep(0.0,0.07,u)*(1.0-smoothstep(0.92,1.0,u));
  ALBEDO=c;
  ALPHA=cut*head*ends;
 }
}

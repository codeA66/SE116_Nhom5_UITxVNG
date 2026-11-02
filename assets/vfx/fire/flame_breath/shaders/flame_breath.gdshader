shader_type spatial;
uniform float prewarm_scale = 1.0;
render_mode unshaded, cull_disabled, blend_mix, depth_prepass_alpha;
uniform sampler2D masks : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 core_color : source_color = vec4(1.0,0.94,0.67,1.0);
uniform vec4 hot_color : source_color = vec4(1.0,0.77,0.24,1.0);
uniform float strength : hint_range(0.0,1.0) = 0.0;
uniform float clock = 0.0;
uniform float ground_mode = 0.0;
uniform float accent_mode = 0.0;
uniform float intensity = 1.0;
uniform float pressure = 1.0;
uniform float star_power = 8.0;
uniform float front : hint_range(0.0,1.0) = 1.0;
uniform float retreat : hint_range(0.0,1.0) = 0.0;
uniform float edge_width = 0.018;
uniform float ground_opacity = 0.18;
uniform float wave_speed = 10.0;
uniform float wave_amplitude = 0.018;
void vertex(){
 if(accent_mode>0.5){
  vec3 size=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
  MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*size.x,INV_VIEW_MATRIX[1]*size.y,INV_VIEW_MATRIX[2]*size.z,MODEL_MATRIX[3]);
 }else if(ground_mode<0.5){
  float envelope=sin(UV.y*3.14159);
  VERTEX.x*=pressure*(1.0+sin(UV.y*11.0-clock*wave_speed)*0.035*envelope);
  float roll=UV.x*6.28318+UV.y*13.0-clock*wave_speed;
  VERTEX.xy*=1.0+0.16*sin(roll*2.0)*envelope;
  VERTEX.xy+=vec2(sin(UV.y*12.0-clock*wave_speed),cos(UV.y*9.0-clock*wave_speed))*wave_amplitude*envelope;
  VERTEX.xy*=1.0-smoothstep(0.80,1.0,UV.y);
 }
 VERTEX*=prewarm_scale;
}
void fragment(){
 if(accent_mode>0.5){
  vec2 p=UV*2.0-1.0;
  float radius=length(p);
  float ray=pow(abs(cos(2.0*atan(p.y,p.x))),star_power);
  float shape=1.0-smoothstep(0.12+ray*0.63,0.17+ray*0.68,radius);
  ALBEDO=mix(hot_color.rgb,core_color.rgb,1.0-smoothstep(0.0,0.35,radius))*1.3;
  ALPHA=shape*intensity;
 }else if(ground_mode>0.5){
  float t=UV.y;
  float x=abs(UV.x*2.0-1.0);
  float width=sin(t*3.14159)*0.88;
  float edge=1.0-smoothstep(width*0.55,width+0.02,x);
  ALBEDO=vec3(0.19,0.065,0.025);
  ALPHA=edge*sin(t*3.14159)*strength*ground_opacity;
 }else{
  float t=UV.y;
  // Texture chạy quanh tiết diện khối.
  float turn=UV.x*6.28318;
  vec2 painted=vec2(fract(t*1.3-clock*0.9+COLOR.b*0.2),0.5+sin(turn+t*7.0-clock*3.0)*0.3);
  vec4 flame=texture(masks,painted);
  float heat=clamp(flame.g*0.8+(1.0-COLOR.g)*0.24,0.0,1.0);
  vec3 col=mix(vec3(1.0,0.18,0.008),hot_color.rgb,smoothstep(0.12,0.85,heat));
  col=mix(col,core_color.rgb,COLOR.r*0.85);
  float facing=abs(dot(normalize(NORMAL),normalize(VIEW)));
  ALBEDO=col*mix(0.72,1.10,smoothstep(0.0,0.85,facing));

  float tip=1.0-smoothstep(front-edge_width,front,t);
  tip*=smoothstep(retreat-edge_width,retreat,t);
  float breakup=mix(smoothstep(0.08,0.38,flame.g),1.0,COLOR.r);
  ALPHA=strength*tip*smoothstep(0.0,0.025,t)*breakup;

 }
}

shader_type spatial;
uniform float prewarm_scale = 1.0;
render_mode unshaded, cull_disabled, blend_mix, depth_prepass_alpha;
uniform sampler2D masks : repeat_enable, filter_linear;
uniform vec4 core_color : source_color = vec4(1.0,0.94,0.67,1.0);
uniform vec4 hot_color : source_color = vec4(1.0,0.77,0.24,1.0);
uniform vec4 flame_color : source_color = vec4(1.0,0.48,0.035,1.0);
uniform vec4 outer_color : source_color = vec4(0.84,0.075,0.025,1.0);
uniform float mode = 0.0;
uniform float opacity : hint_range(0.0,1.0) = 0.0;
uniform float pulse = 0.0;
uniform float phase = 0.0;
uniform float speed = 2.4;
uniform float noise_scale = 3.0;
uniform float curl = 0.12;
uniform float edge = 0.025;
uniform float front = 1.0;
uniform float tail = 0.0;
uniform float height_scale = 0.35;
uniform float turns = 2.0;
uniform sampler2D flame_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform bool burning_volume = false;
uniform bool status_crown = false;
uniform float tick_expansion = 0.38;
uniform float wind_clock = 0.0;
uniform sampler2D wind_flow : source_color, repeat_disable, filter_linear_mipmap;
uniform float wind_lean = 0.0;
uniform bool burning_textured = false;
uniform bool burning_stream_mode = false;
uniform vec3 stream_direction = vec3(0.0,0.0,1.0);
uniform float atlas_rate = 12.0;
varying float particle_seed;
uniform bool burning_single_system = false;
uniform int burning_flame_count = 8;
uniform float burning_ember_rise = 1.3;
varying float particle_ember;
varying float particle_frame;
varying vec2 wind_uv;
void vertex(){
 float clock=TIME*speed+phase;
 particle_seed=0.0;
 particle_ember=0.0;
 particle_frame=0.0;
 if(mode>2.5){
  particle_seed=INSTANCE_CUSTOM.x;
  particle_frame=mod(floor(TIME*atlas_rate+particle_seed*2.37),8.0);
  particle_ember=burning_single_system && INSTANCE_ID>=burning_flame_count ? 1.0 : 0.0;
  if(burning_volume){
   float h=UV.y;
   VERTEX.xz*=mix(1.0,0.12,particle_ember);
   VERTEX.y*=mix(1.0,0.12,particle_ember);
   VERTEX.xz+=vec2(sin(h*6.0-clock*3.0+particle_seed),cos(h*8.0-clock*2.5+particle_seed))*h*h*0.20;
   VERTEX.xz*=1.0+sin(clock*4.0+h*9.0+particle_seed)*0.12;
   VERTEX*=1.0+pulse*0.16;
   if(status_crown){
    VERTEX*=1.0+pulse*tick_expansion;
    VERTEX.y+=sin(clock*3.0+phase)*0.045*UV.y;
   }
   if(burning_stream_mode){
    float tip=1.0-UV.y;
    VERTEX.xz*=mix(1.0,0.06,tip);
    VERTEX.x+=tip*tip*0.18;
    VERTEX.yz=vec2(-VERTEX.z,VERTEX.y);
   }
  }else{
  vec3 size=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
  MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*size.x,INV_VIEW_MATRIX[1]*size.y,INV_VIEW_MATRIX[2]*size.z,MODEL_MATRIX[3]);
  VERTEX*=1.0+pulse*0.08;
  VERTEX*=mix(1.0,0.10,particle_ember);
  VERTEX.y+=INSTANCE_CUSTOM.y*burning_ember_rise*particle_ember;
  if(burning_stream_mode){
   vec2 d=(VIEW_MATRIX*vec4(stream_direction,0.0)).xy;
   if(length(d)>0.001){ d=normalize(d); VERTEX.xy=mat2(vec2(d.y,-d.x),vec2(d.x,d.y))*VERTEX.xy; }
  }
  }
 }else if(mode<0.5){
  float h=UV.y;
  float beat=clock*1.7+COLOR.r*6.28318;
  vec2 radial=COLOR.gb*2.0-1.0;
  vec2 tangent=vec2(-radial.y,radial.x);
  VERTEX.xz+=tangent*sin(h*5.5-beat)*curl*h*h;
  VERTEX.y+=sin(beat+h*3.0)*0.08*h;
 }else if(mode<1.5){
  if(COLOR.b>0.5){ VERTEX.z+=front-0.5; }
  wind_uv=vec2(VERTEX.x+0.5,VERTEX.z+0.5);
  float lift=VERTEX.y*height_scale;
  VERTEX.y=lift*(0.9+0.1*sin(wind_clock*20.0+COLOR.r*20.0+UV.y*8.0));
  VERTEX.z+=lift*wind_lean;

 }else{
  float a=clock+UV.y*8.0;
  mat2 r=mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)));
  VERTEX.xz=r*VERTEX.xz;
  VERTEX.xz*=1.0+curl*sin(UV.y*16.0-clock);
 }
 VERTEX*=prewarm_scale;
}
void fragment(){
 float clock=TIME*speed+phase;
 if(mode>2.5){
  if(burning_volume){
   float h=UV.y;
   vec2 cell=vec2(mod(particle_frame,4.0),floor(particle_frame/4.0));
   vec3 painted=texture(flame_atlas,(vec2(UV.x,1.0-h)+cell)/vec2(4.0,2.0)).rgb;
   float swirl=painted.g*0.7+(sin(UV.x*18.85+h*12.0-clock*4.0+particle_seed)*0.5+0.5)*0.3;
   vec3 col=mix(flame_color.rgb,hot_color.rgb,smoothstep(0.15,0.65,1.0-h+swirl*0.22));
   col=mix(col,core_color.rgb,(1.0-smoothstep(0.1,0.6,h))*0.85);
   float facing=abs(dot(normalize(NORMAL),normalize(VIEW)));
   ALBEDO=col*mix(0.60,1.10,facing)*(1.0+pulse*0.15);
   ALBEDO=mix(ALBEDO,core_color.rgb,particle_ember);
   if(status_crown){
    ALBEDO=mix(ALBEDO,core_color.rgb,pulse*0.75)*(1.0+pulse*0.35);
   }
   ALPHA=COLOR.a*opacity;
  }else if(burning_textured && particle_ember<0.5){
   vec2 cell=vec2(mod(particle_frame,4.0),floor(particle_frame/4.0));
   vec4 art=texture(flame_atlas,(UV+cell)/vec2(4.0,2.0));
   ALBEDO=art.rgb*(1.0+pulse*0.15);
   ALPHA=art.a*COLOR.a*opacity;
  }else{
  float h=1.0-UV.y;
  float drift=sin(h*6.0-clock*2.2+particle_seed)*h*0.15;
  float fold=sin(h*15.0-clock*3.5+particle_seed)*h*0.035;
  float x=UV.x-0.5+drift+fold;
  float n=texture(masks,vec2(UV.x+particle_seed,h*1.4-clock*0.7)).r;
  float width=0.46*pow(max(sin(h*3.14159),0.0),0.75)*(1.0-h*0.28);
  width+=(n-0.5)*0.11*h;
  float shape=1.0-smoothstep(width-edge,width+edge,abs(x));
  shape*=smoothstep(0.0,0.07,h)*(1.0-smoothstep(0.92,1.0,h));
  float heat=1.0-abs(x)*2.0-h*0.65+n*0.16;
  vec3 flame=mix(outer_color.rgb,flame_color.rgb,smoothstep(0.20,0.20+edge,heat));
  flame=mix(flame,hot_color.rgb,smoothstep(0.65,0.65+edge,heat));
  flame=mix(flame,core_color.rgb,smoothstep(0.93,0.93+edge,heat));
  ALBEDO=flame*(1.0+pulse*0.35);
  ALBEDO=mix(ALBEDO,mix(hot_color.rgb,core_color.rgb,0.65),particle_ember);
  ALPHA=shape*COLOR.a*opacity;
  }
 }else if(mode<0.5){
  float h=UV.y;
  float seed=COLOR.r*6.28318;
  float wave=sin(h*10.0-clock*2.5+seed)*0.07+sin(h*19.0-clock*3.7+seed)*0.025;
  float x=abs((UV.x-0.5+wave*h)*2.0);
  float n=texture(masks,vec2(UV.x*0.75+COLOR.r,h*1.2-clock*0.6)).r;
  float ragged=0.94-(1.0-n)*0.22*h;
  float shape=1.0-smoothstep(ragged-edge,ragged+edge,x);
  shape*=smoothstep(0.0,0.13,h);
  float heat=1.0-x-h*0.65+wave+n*0.16;
  vec3 flame=mix(outer_color.rgb,flame_color.rgb,smoothstep(0.10,0.10+edge,heat));
  flame=mix(flame,hot_color.rgb,smoothstep(0.60,0.60+edge,heat));
  flame=mix(flame,core_color.rgb,smoothstep(0.90,0.90+edge,heat)*(1.0-smoothstep(0.3,0.6,h)));
  ALBEDO=flame*(1.0+pulse*0.45);
  ALPHA=shape*opacity;
 }else if(mode<1.5){
  float t=wind_uv.y;
  float x=wind_uv.x*2.0-1.0;
  vec4 art=texture(wind_flow,vec2(1.0-UV.y,clamp(UV.x+sin(UV.y*9.0-wind_clock*18.0+COLOR.r*9.0)*0.07,0.0,1.0)));
  float head=exp(-pow((t-front+0.035)/0.085,2.0));
  float gate=smoothstep(tail-edge,tail,t)*(1.0-smoothstep(front-edge,front,t));
  float ripple=0.80+0.20*sin(UV.y*16.0-wind_clock*25.0+COLOR.r*12.0);
  ALBEDO=mix(art.rgb,core_color.rgb,head*0.65)*ripple;
  ALPHA=art.a*gate*opacity;
  if(COLOR.b>0.5){
   float across=sin(UV.x*3.14159);
   float band=sin(UV.y*3.14159);
   ALBEDO=mix(flame_color.rgb,hot_color.rgb,band*0.85);
   ALPHA=across*band*(0.45+0.55*pow(sin(UV.x*23.0+wind_clock*12.0),2.0))*opacity*smoothstep(0.0,0.08,front)*(1.0-tail);
  }

 }else{
 float h=1.0-UV.y;
 vec2 flow=vec2(UV.x*noise_scale,UV.y*2.0+clock);
 if(mode>1.5) flow=vec2(UV.x*noise_scale+clock,UV.y*2.0);
 float n=texture(masks,flow).r;
 float coverage=1.0;
 if(mode<0.5){
  float tongue=0.52+0.3*sin(UV.x*37.699-clock*0.8)+n*0.3;
  coverage=(1.0-smoothstep(tongue-edge,tongue+edge,h))*smoothstep(0.02,0.16,h);
 }else if(mode<1.5){
  float side=abs(UV.x*2.0-1.0);
  float lanes=sin(UV.x*25.132-clock+UV.y*8.0)*0.5+0.5;
  coverage=smoothstep(0.28,0.28+edge,lanes+n*0.4)*(1.0-smoothstep(0.75,1.0,side));
  coverage*=smoothstep(tail-edge,tail,UV.y)*(1.0-smoothstep(front-edge,front,UV.y+(1.0-n)*0.1));
 }else{
  float spiral=sin(UV.x*6.28318*turns+UV.y*13.0-clock*2.0)*0.5+0.5;
  coverage=smoothstep(0.46,0.46+edge,spiral+n*0.25)*smoothstep(0.0,0.08,UV.y)*(1.0-smoothstep(0.8,1.0,UV.y));
 }
 float hot=smoothstep(0.28,0.32,n);
 vec3 col=mix(outer_color.rgb,flame_color.rgb,hot);
 col=mix(col,hot_color.rgb,smoothstep(0.55,0.59,n));
 col=mix(col,core_color.rgb,smoothstep(0.84,0.88,n)*0.7);
 if(mode>0.5 && mode<1.5){
  float streak=pow(max(0.0,sin(UV.x*25.132-clock+UV.y*8.0)),18.0);
  col=mix(col,core_color.rgb,streak*0.7);
 }
 ALBEDO=col*(1.0+pulse*0.65);
 ALPHA=coverage*opacity;
 }
}

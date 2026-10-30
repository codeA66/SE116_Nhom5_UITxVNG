shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform float age=-1.0;
varying vec4 seed;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void vertex(){
	seed=INSTANCE_CUSTOM;
	vec3 s=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*s.x,INV_VIEW_MATRIX[1]*s.y,INV_VIEW_MATRIX[2]*s.z,MODEL_MATRIX[3]);
	float t=max(age,0.0);
	float a=INSTANCE_CUSTOM.r*6.283185;
	MODELVIEW_MATRIX[3]+=VIEW_MATRIX*vec4(cos(a)*t*.8,t*.35,sin(a)*t*.8,0);
	VERTEX.xy*=.5+min(t,1.0)*.85;
}
void fragment(){
	vec2 p=UV*2.0-1.0;
	float n=noise(p*4.0+seed.g*47.0+vec2(age*.8,-age*.5))*.65+noise(p*9.0+seed.b*23.0)*.35;
	float cloud=smoothstep(.22,.68,n)*(1.0-smoothstep(.12,1.0,length(p)));
	ALBEDO=mix(vec3(.23,.14,.08),vec3(.68,.49,.29),n);
	ALPHA=cloud*smoothstep(0.0,.08,age)*(1.0-smoothstep(.45,1.15,age))*.7;
}

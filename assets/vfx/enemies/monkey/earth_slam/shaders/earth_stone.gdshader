shader_type spatial;
render_mode cull_disabled;
uniform float age = -1.0;
uniform bool debris = false;
varying vec4 seed;
void vertex() {
	seed=INSTANCE_CUSTOM;
	float t=max(age,0.0);
	if(debris){
		float a=INSTANCE_CUSTOM.r*6.283185;
		vec3 offset=vec3(cos(a)*t*2.2,max((2.6+INSTANCE_CUSTOM.g*2.5)*t-5.5*t*t,0.0),sin(a)*t*2.2);
		MODELVIEW_MATRIX=VIEW_MATRIX*MODEL_MATRIX;
		MODELVIEW_MATRIX[3]+=VIEW_MATRIX*vec4(offset,0.0);
	}else{
		float delay=INSTANCE_CUSTOM.b*0.075;
		VERTEX.y*=smoothstep(0.015+delay,0.14+delay,t)*(1.0-smoothstep(0.72,1.08,t));
	}
}
void fragment(){
	float fade=1.0-smoothstep(0.82,1.15,age);
	ALBEDO=mix(vec3(0.20,0.105,0.055),vec3(0.48,0.29,0.14),seed.g);
	EMISSION=vec3(0.32,0.13,0.025)*pow(max(1.0-age*2.0,0.0),2.0);
	ROUGHNESS=0.95;
	ALPHA=age>=0.0?fade:0.0;
}

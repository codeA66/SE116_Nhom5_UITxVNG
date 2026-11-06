shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled;
uniform vec4 accent : source_color = vec4(0.65,0.88,0.94,1);
uniform vec4 hot_color : source_color = vec4(0.95,0.99,1,1);
uniform int phase = 0;
uniform float progress = 0.0;
uniform float clock = 0.0;
uniform float opacity = 0.0;
uniform float focus_height = 1.4;
uniform float ray_count = 8.0;
uniform float ray_length = 1.75;
uniform float ray_width = 0.11;
uniform float core_size = 1.1;
uniform float stream_width = 0.038;
uniform float stream_radius = 0.7;
uniform float stream_height = 2.2;
uniform vec3 source_point = vec3(0,1,0);
uniform float charge_core_ratio = 0.48;
uniform float charge_power = 2.0;
uniform float ray_length_variation = 0.28;
uniform float ray_curl = 0.14;
varying float stroke;
varying float core;
void vertex() {
	float id = UV2.x;
	core = UV2.y;
	float u = UV.x;
	float side = UV.y-0.5;
	float angle = id/max(ray_count,1.0)*6.283185;
	vec3 p;
	if (phase < 2) {
		float a = angle+u*6.283185+clock*(1.0+progress);
		float r = stream_radius*(1.0-u)*(1.0-progress*0.65);
		p = vec3(sin(a)*r,focus_height+(1.0-u)*stream_height,cos(a)*r);
		if (phase == 0) p = mix(source_point,vec3(0,focus_height,0),u) + vec3(sin(a)*r,sin(u*3.141593)*stream_radius,cos(a)*r)*sin(u*3.141593);
		vec4 view_point = MODELVIEW_MATRIX*vec4(p,1.0);
		float width = stream_width*sin(u*3.141593)*mix(0.5,1.4,progress);
		POSITION = PROJECTION_MATRIX*(view_point+vec4(side*width,0,0,0));
	} else {
		float variation = mix(1.0-ray_length_variation,1.0,fract(id*0.618034));
		float distance = u*ray_length*variation*mix(0.45,1.0,1.0-pow(1.0-progress,3.0));
		float width = pow(max(sin(u*3.141593),0.0),0.65)*ray_width*(1.0-progress);
		vec4 view_center = VIEW_MATRIX*MODEL_MATRIX*vec4(0,focus_height,0,1);
		float curl = ray_curl*u*u*sin(id*2.4)*(1.0-progress);
		vec2 ray = vec2(cos(angle+curl),sin(angle+curl));
		vec2 normal = vec2(-ray.y,ray.x);
		POSITION = PROJECTION_MATRIX*(view_center+vec4(ray*distance+normal*side*width,0,0));
	}
	if (core > 0.5) {
		vec4 center = VIEW_MATRIX*MODEL_MATRIX*vec4(0,focus_height,0,1);
		float charge = pow(progress,max(charge_power,0.1));
		float diameter = core_size;
		if (phase < 2) diameter *= charge_core_ratio*mix(0.2,1.0,charge);
		POSITION = PROJECTION_MATRIX*(center+vec4((UV-0.5)*diameter,0,0));
	}
	stroke = id;
}
void fragment() {
	if (core > 0.5) {
		if (phase == 0) discard;
		float radial = length(UV*2.0-1.0);
		float halo = (1.0-smoothstep(0.0,1.0,radial));
		float kernel = 1.0-smoothstep(0.14,0.34,radial);
		float alpha = max(kernel,halo*halo*0.42);
		if (phase == 1) alpha *= pow(progress,max(charge_power,0.1))*0.8;
		else alpha *= pow(1.0-progress,2.0);
		ALBEDO = mix(accent.rgb,hot_color.rgb,kernel);
		ALPHA = alpha*opacity;
	} else {
	if (stroke >= ray_count) discard;
	float ends = smoothstep(0.0,0.06,UV.x)*(1.0-smoothstep(0.8,1.0,UV.x));
	float edge = smoothstep(0.0,0.08,UV.y)*(1.0-smoothstep(0.92,1.0,UV.y));
	float erosion = sin(UV.x*47.0+stroke*5.1)*sin(UV.y*19.0+stroke);
	if (phase == 2) ends *= 1.0-smoothstep(1.0-progress,1.05-progress,erosion*0.5+0.5);
	ALBEDO = mix(accent.rgb,hot_color.rgb,step(0.25,UV.y)*step(UV.y,0.75));
	ALPHA = ends*edge*opacity;
	}
}

shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 accent : source_color = vec4(0.65,0.88,0.94,1);
uniform vec4 hot_color : source_color = vec4(0.95,0.99,1,1);
uniform sampler2D mote_texture : source_color, filter_linear;
uniform bool textured = false;
uniform int phase = 1;
uniform float progress = 0.0;
uniform float clock = 0.0;
uniform float opacity = 0.0;
uniform float focus_height = 1.4;
uniform float radius = 2.6;
uniform float height_spread = 2.4;
uniform float spin = 2.2;
uniform float mote_size = 0.055;
uniform float foreground_size = 0.22;
uniform float foreground_depth = 4.5;
uniform float foreground_spread = 2.2;
uniform vec3 toward_camera = vec3(0,0.7,0.7);
uniform int foreground_count = 6;
uniform float spark_radius = 2.1;
uniform float dust_radius = 0.55;
uniform float landing_start = 0.78;
uniform float dust_size = 0.14;
uniform float dust_height = 0.06;
uniform float gather_acceleration = 2.3;
uniform float gather_stagger = 0.48;
uniform float mote_stretch = 4.2;
uniform int total_count = 72;
varying float brightness;
varying float particle_alpha;
varying float streak;
void vertex() {
	float seed = INSTANCE_CUSTOM.r;
	float angle = seed * 6.283185 + clock * spin;
	float rnd = INSTANCE_CUSTOM.g;
	float taper = 1.0 - progress;
	vec3 p;
	float size = mote_size * mix(0.55, 1.5, rnd);
	brightness = 0.65 + rnd * 0.35;
	particle_alpha = 1.0;
	streak = 0.0;
	if (phase == 0) {
		p = vec3(sin(angle)*radius*0.3*taper, focus_height + mix(height_spread,0.0,progress) + rnd*0.4,cos(angle)*radius*0.3*taper);
	} else if (phase == 1) {
		float birth = float(INSTANCE_ID)/float(max(total_count,1))*clamp(gather_stagger,0.0,0.9);
		float life = clamp((progress-birth)/max(1.0-birth,0.01),0.0,1.0);
		float travel = pow(life,max(gather_acceleration,0.1));
		float orbit = seed*6.283185 + spin*(life+life*life);
		float r = radius*(1.0-travel)*mix(0.5,1.0,rnd);
		p = vec3(sin(orbit)*r, focus_height + (rnd-0.5)*height_spread*(1.0-travel),cos(orbit)*r);
		particle_alpha = smoothstep(0.0,0.09,life)*(1.0-smoothstep(0.92,1.0,travel));
		size *= mix(0.65,1.35,travel);
		streak = smoothstep(0.1,0.9,life);
		if (INSTANCE_ID < foreground_count) {
			p.xz *= foreground_spread;
			p += toward_camera * foreground_depth * (1.0-travel);
			size = mix(foreground_size,mote_size,travel);
			streak = 0.0;
		}
	} else if (phase == 2) {
		float t = clamp(progress + rnd*0.1,0.0,1.0);
		p = vec3(sin(angle)*spark_radius*t,focus_height + sin(t*3.141593)*(0.4+rnd),cos(angle)*spark_radius*t);
		size *= 1.0-t;
		streak = 1.0;
	} else {
		float landing = clamp(landing_start,0.1,0.95);
		if (progress < landing) {
			float t = progress/landing;
			float r = mix(radius*0.4,dust_radius,t);
			p = vec3(sin(angle)*r,focus_height*(1.0-t)+rnd*dust_height,cos(angle)*r);
			size *= 1.0-t;
			particle_alpha = 1.0-t;
		} else {
			float t = (progress-landing)/(1.0-landing);
			float r = dust_radius*mix(0.2,1.0,t);
			p = vec3(sin(angle)*r,dust_height+sin(t*3.141593)*dust_size,cos(angle)*r);
			size = dust_size*sin(t*3.141593)*mix(0.7,1.3,rnd);
			particle_alpha = 1.0-t;
		}
	}
	vec4 view_center = VIEW_MATRIX * MODEL_MATRIX * vec4(p,1.0);
	vec2 projected = (VIEW_MATRIX*MODEL_MATRIX*vec4(vec3(0,focus_height,0)-p,0)).xy;
	if (phase == 2) projected = -projected;
	vec2 axis = projected/max(length(projected),0.0001);
	if (dot(axis,axis)<0.01) axis = vec2(1,0);
	vec2 normal = vec2(-axis.y,axis.x);
	vec2 offset = (axis*VERTEX.x*mix(1.0,mote_stretch,streak)+normal*VERTEX.y)*size;
	POSITION = PROJECTION_MATRIX * (view_center + vec4(offset,0,0));
}
void fragment() {
	float radial = length(UV*2.0-1.0);
	float alpha = 1.0-smoothstep(0.12,1.0,radial);
	alpha *= mix(1.0,smoothstep(0.0,0.7,UV.x),streak);
	if (textured) alpha *= texture(mote_texture,UV).a;
	ALBEDO = mix(accent.rgb,hot_color.rgb,brightness*mix(0.25,0.9,streak));
	ALPHA = alpha * opacity * particle_alpha;
}

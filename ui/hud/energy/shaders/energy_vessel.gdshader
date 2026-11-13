shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.88,0.82,0.66,1);
uniform vec4 ink : source_color = vec4(0.03,0.045,0.055,0.7);
uniform vec4 hot : source_color = vec4(0.95,0.92,0.85,1);
uniform float fill_ratio = 0.0;
uniform float wave_height = 0.025;
uniform float wave_speed = 4.0;
uniform float wave_frequency = 8.0;
uniform float idle_wave = 0.18;
uniform float tilt = 0.0;
uniform float activity = 0.0;
uniform float flash = 0.0;
uniform float facet_strength = 0.0;
uniform bool masked = false;
uniform sampler2D mask_texture : filter_linear;
void fragment() {
	vec2 p = UV*2.0-1.0;
	float circle = 1.0-smoothstep(0.965,1.0,length(p));
	float fill = clamp(fill_ratio,0.0,1.0);
	float phase = TIME*wave_speed;
	float wave = sin(UV.x*wave_frequency+phase)*0.72+sin(UV.x*wave_frequency*1.65-phase*0.8)*0.28;
	float boundary = smoothstep(0.0,0.08,fill)*(1.0-smoothstep(0.92,1.0,fill));
	float surface = 1.0-fill+(wave*wave_height*mix(idle_wave,1.0,activity)+p.x*tilt)*boundary;
	float liquid = smoothstep(surface-0.007,surface+0.007,UV.y)*step(0.0001,fill);
	float shine = (1.0-smoothstep(0.0,0.028,abs(UV.y-surface)))*liquid*boundary;
	float depth = clamp((UV.y-surface)/max(1.0-surface,0.001),0.0,1.0);
	vec3 fluid = tint.rgb*mix(1.0,0.70,depth);
	// Mặt cắt đi cùng màu chất lỏng để phần đã tiêu vẫn đọc như khoang rỗng.
	float facets = mix(1.0,-0.65,step(p.x*0.7+0.15,p.y));
	facets -= 0.65*step(0.12,p.x-p.y*0.74);
	fluid = mix(fluid,hot.rgb,max(facets,0.0)*facet_strength);
	fluid *= 1.0+min(facets,0.0)*facet_strength;
	// Bọt dùng cùng mặt cắt với nước để không lọt vào khoang rỗng.
	float bubble_rim = 0.0;
	float bubble_core = 0.0;
	for (int i = 0; i < 5; i++) {
		float seed = float(i);
		float age = fract(TIME * (0.42 + 0.048 * seed) + seed * 0.381);
		float x = 0.5 + sin(seed * 2.399 + 1.2) * 0.28 + sin(age * 7.0 + seed) * 0.023;
		float y = mix(0.91, max(surface - 0.02, 0.05), age);
		float radius = mix(0.025, 0.047, fract(seed * 0.618)) * mix(0.65, 1.12, age);
		float distance_to_bubble = length(UV - vec2(x,y)) / radius;
		float life = smoothstep(0.0, 0.16, age) * (1.0 - smoothstep(0.83, 1.0, age));
		float disk = (1.0 - smoothstep(0.78, 1.12, distance_to_bubble)) * life;
		bubble_core = max(bubble_core, disk);
		bubble_rim = max(bubble_rim, disk * smoothstep(0.40, 0.83, distance_to_bubble));
	}
	fluid *= 1.0 - bubble_core * 0.33;
	fluid = mix(fluid,hot.rgb,bubble_rim * 0.83);
	vec3 color = mix(ink.rgb,fluid,liquid);
	color = mix(color,hot.rgb,clamp(shine*0.65+flash*0.35*liquid,0.0,1.0));
	float alpha = circle*mix(ink.a,1.0,liquid);
	if (masked) alpha *= texture(mask_texture,UV).a;
	COLOR = vec4(color,alpha);
}

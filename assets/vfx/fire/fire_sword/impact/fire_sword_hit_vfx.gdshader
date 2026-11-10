shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 core_color : source_color;
uniform vec4 body_color : source_color;
uniform vec4 edge_color : source_color;
uniform float progress = 0.0;
uniform float opacity = 1.0;
uniform float size = 0.32;
uniform float spread = 0.75;
uniform float forward_push = 0.35;
uniform float edge_width = 0.12;
uniform float reach = 1.65;
uniform vec3 limit_center = vec3(0.0);
uniform bool clip_box = false;
uniform vec3 box_center = vec3(0.0);
uniform vec3 box_size = vec3(1.0);
uniform float warm_scale = 1.0;
varying float kind;
varying float strand;
void vertex() {
	kind = UV2.y;
	strand = UV2.x;
	float u = UV.x;
	float a = (fract(strand * 0.618034) - 0.5) * spread * 6.283185;
	float radius = (u + progress * forward_push) * size;
	float width = sin(u * 3.141593) * size * (kind > 0.5 ? 0.12 : 0.22);
	vec3 p = vec3(sin(a) * radius, sin(u * 3.141593) * size * 0.4, cos(a) * radius);
	p.x += (UV.y - 0.5) * width;
	p.y += (UV.y - 0.5) * width;
	p.z += progress * size * forward_push;
	if (clip_box) p = clamp(p, box_center - box_size * 0.5, box_center + box_size * 0.5);
	vec2 radial = p.xz - limit_center.xz;
	if (length(radial) > reach) p.xz = limit_center.xz + normalize(radial) * reach;
	VERTEX = p * warm_scale;
}
void fragment() {
	float edge = min(UV.y, 1.0 - UV.y);
	float alpha = smoothstep(0.0, 0.08, edge);
	float erode = UV.x + sin(UV.x * 17.0 + strand) * 0.14;
	alpha *= smoothstep(progress - 0.025, progress + 0.025, erode);
	alpha *= smoothstep(0.0, 0.08, UV.x) * (1.0 - smoothstep(0.85, 1.0, UV.x));
	ALBEDO = mix(edge_color.rgb, mix(body_color.rgb, core_color.rgb, step(0.65, UV.y)), step(edge_width, edge));
	ALPHA = alpha * opacity;
}

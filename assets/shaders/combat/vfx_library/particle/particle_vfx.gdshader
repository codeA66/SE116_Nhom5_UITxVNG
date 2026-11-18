shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, skip_vertex_transform;

#include "../vfx_common.gdshaderinc"

uniform sampler2D shape_mask : hint_default_white, filter_linear, repeat_disable;
uniform sampler2D erosion_noise : hint_default_white, filter_linear, repeat_enable;
uniform int atlas_columns : hint_range(1, 16) = 1;
uniform int atlas_rows : hint_range(1, 16) = 1;
uniform int atlas_frames : hint_range(1, 256) = 1;
uniform bool use_particle_age = true;
uniform bool use_particle_rotation = true;
uniform float erosion_start : hint_range(0.0, 1.0) = 0.36;
uniform float erosion_softness : hint_range(0.01, 0.5) = 0.16;
uniform float noise_influence : hint_range(0.0, 1.0) = 0.20;
uniform float intensity : hint_range(0.0, 3.0) = 1.0;

varying float particle_age;

void vertex() {
	particle_age = use_particle_age ? clamp(INSTANCE_CUSTOM.y, 0.0, 1.0) :
		clamp(vfx_progress, 0.0, 1.0);
	float angle = use_particle_rotation ? INSTANCE_CUSTOM.x : 0.0;
	float cosine = cos(angle);
	float sine = sin(angle);
	mat2 rotation = mat2(vec2(cosine, sine), vec2(-sine, cosine));
	vec2 scale = vec2(length(MODELVIEW_MATRIX[0].xyz), length(MODELVIEW_MATRIX[1].xyz));
	VERTEX = MODELVIEW_MATRIX[3].xyz + vec3(rotation * (VERTEX.xy * scale), VERTEX.z);
}

vec2 flipbook_uv(vec2 uv, float age) {
	vec2 grid = vec2(float(max(1, atlas_columns)), float(max(1, atlas_rows)));
	float frames = clamp(float(atlas_frames), 1.0, grid.x * grid.y);
	float frame = min(floor(age * frames), frames - 1.0);
	vec2 tile = vec2(mod(frame, grid.x), floor(frame / grid.x));
	// Giữ mẫu lọc trong ô hiện tại để các frame cạnh nhau không tràn sang nhau.
	vec2 guard = min(0.5 * grid / vec2(textureSize(shape_mask, 0)), vec2(0.49));
	return (tile + mix(guard, 1.0 - guard, clamp(uv, vec2(0.0), vec2(1.0)))) / grid;
}

void fragment() {
	float shape = texture(shape_mask, flipbook_uv(UV, particle_age)).r;
	float grain = texture(erosion_noise, UV).r;
	float fade = clamp((particle_age - erosion_start) / max(1.0 - erosion_start, 0.001), 0.0, 1.0);
	fade = max(fade, step(1.0, particle_age));
	float erosion = vfx_erosion(mix(shape, grain, noise_influence), max(fade, vfx_dissolve), erosion_softness);
	vec4 palette = vfx_sample_palette(shape);
	ALBEDO = palette.rgb * COLOR.rgb * intensity;
	ALPHA = clamp(shape * erosion * palette.a * COLOR.a * vfx_opacity, 0.0, 1.0);
}

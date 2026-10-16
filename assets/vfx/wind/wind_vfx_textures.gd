@tool
class_name WindVfxTextures
extends RefCounted
## Mặt nạ tự vẽ trong Godot, trắng + alpha để màu luôn chỉnh được bằng Resource.

static var _cache: Dictionary = {}


static func mask(kind: StringName, resolution: int) -> Texture2D:
	var key: String = "%s_%d" % [kind, resolution]
	if _cache.has(key):
		return _cache[key] as Texture2D
	var width: int = resolution
	var height: int = resolution / 4 if kind == &"stroke" else resolution
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 71
	noise.frequency = 0.075
	for y: int in height:
		for x: int in width:
			var uv: Vector2 = Vector2(float(x) / (width - 1), float(y) / (height - 1))
			var alpha: float = 0.0
			var core: float = 1.0
			if kind == &"stroke":
				var center: float = 0.5 + sin(uv.x * TAU) * 0.05
				var taper: float = pow(sin(uv.x * PI), 0.7)
				var distance: float = absf(uv.y - center) / maxf(taper, 0.001)
				alpha = (1.0 - smoothstep(0.24, 0.46, distance)) * smoothstep(0.0, 0.12, uv.x) * (1.0 - smoothstep(0.9, 1.0, uv.x))
				core = 0.6 + 0.4 * (1.0 - smoothstep(0.02, 0.16, distance))
			elif kind == &"gust":
				var t: float = uv.x
				var center: float = 0.5 + 0.12 * sin(t * PI * 1.4 - 0.4)
				var width_at_t: float = pow(maxf(sin(t * PI), 0.0), 0.65) * lerpf(0.22, 0.38, t)
				var d: float = absf(uv.y - center)
				var body: float = 1.0 - smoothstep(width_at_t * 0.65, width_at_t, d)
				var channels: float = 0.6 + 0.4 * smoothstep(-0.3, 0.5, sin((uv.y * 3.0 + t * 0.35) * TAU))
				alpha = body * channels * smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.88, 1.0, t))
				core = 0.7 + 0.3 * (1.0 - smoothstep(0.02, 0.15, d))
			elif kind == &"ring":
				var radial: Vector2 = uv * 2.0 - Vector2.ONE
				var d: float = absf(radial.length() - 0.78)
				alpha = (1.0 - smoothstep(0.02, 0.09, d)) * (0.85 + 0.15 * sin(radial.angle() * 7.0))
			elif kind == &"feather":
				var v: float = uv.x
				var d: float = absf(uv.y - 0.5)
				var edge: float = pow(maxf(sin(v * PI), 0.0), 0.7) * 0.44
				var silhouette: float = 1.0 - smoothstep(edge - 0.04, edge + 0.01, d)
				var vein: float = 1.0 - smoothstep(0.015, 0.04, d)
				var barb: float = smoothstep(-0.3, 0.4, sin((v * 15.0 - d * 3.0) * TAU))
				alpha = silhouette * maxf(vein, barb * 0.9) * smoothstep(0.0, 0.06, v) * (1.0 - smoothstep(0.94, 1.0, v))
			else:
				var d: float = (uv * 2.0 - Vector2.ONE).length()
				var n: float = noise.get_noise_2d(x, y) * 0.5 + 0.5
				alpha = (1.0 - smoothstep(0.15, 0.95, d)) * smoothstep(0.15, 0.65, n)
			image.set_pixel(x, y, Color(core, core, core, clampf(alpha, 0.0, 1.0)))
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

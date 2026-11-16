shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

float hash21(vec2 p) {
	vec3 scrambled = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	scrambled += dot(scrambled, scrambled.yzx + 33.33);
	return fract((scrambled.x + scrambled.y) * scrambled.z);
}

vec3 stars(vec2 uv, float scale, float threshold, float radius) {
	vec2 p = uv * scale;
	vec2 id = vec2(floor(p.x), mod(floor(p.y), scale));
	float seed = hash21(id + 8.0);
	if (seed < threshold) {
		return vec3(0.0);
	}
	vec2 at = vec2(hash21(id + 5.1), hash21(id - 3.7)) * 0.62 + 0.19;
	float offset = distance(fract(p), at) / radius;
	float spot = 1.0 - smoothstep(0.12, 0.67, offset);
	float glow = 0.21 * (1.0 - smoothstep(0.22, 1.38, offset));
	float hue = hash21(id * 3.13 + 39.7);
	vec3 cold = mix(vec3(0.23, 0.42, 0.95), vec3(0.36, 0.86, 0.90), hue * 2.0);
	vec3 warm = mix(vec3(0.86, 0.34, 0.76), vec3(1.0, 0.79, 0.41), hue * 2.0 - 1.0);
	vec3 chroma = mix(cold, warm, step(0.5, hue));
	return (spot + glow) * mix(0.42, 0.94, hue) * chroma;
}

void fragment() {
	vec2 p = vec2(UV.x * 0.75, UV.y);
	vec3 color = vec3(0.0, 0.002, 0.007);
	color += stars(p, 87.0, 0.963, 0.155) * 0.59;
	color += stars(p + 0.38, 48.0, 0.978, 0.102);
	ALBEDO = color;
}

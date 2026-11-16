shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform vec4 minerals : source_color = vec4(0.48, 0.39, 0.37, 1.0);
varying vec3 rock_position;

void vertex() {
	rock_position = VERTEX;
}

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float rock_noise(vec3 p) {
	vec3 id = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 offset = vec2(0.0, 1.0);
	float lower = mix(mix(hash31(id), hash31(id + offset.yxx), f.x),
		mix(hash31(id + offset.xyx), hash31(id + offset.yyx), f.x), f.y);
	float upper = mix(mix(hash31(id + offset.xxy), hash31(id + offset.yxy), f.x),
		mix(hash31(id + offset.xyy), hash31(id + vec3(1.0)), f.x), f.y);
	return mix(lower, upper, f.z);
}

void fragment() {
	vec3 p = rock_position;
	vec3 normal = normalize(NORMAL);
	vec3 sunlight = normalize(vec3(-0.54, 0.57, 0.63));
	float lambert = max(dot(normal, sunlight), 0.0);
	float stone = rock_noise(p * 0.35);
	float grain = rock_noise(p * 1.67 + vec3(5.7, 8.1, 1.9));
	float seam = abs(rock_noise(p * 0.61 + stone * 0.7) - 0.51);
	float fissure = 1.0 - smoothstep(0.007, 0.031 + fwidth(seam), seam);
	float weathering = smoothstep(0.39, 0.76, stone);
	float metal = smoothstep(0.71, 0.86, grain) * smoothstep(0.39, 0.57, stone);
	vec3 strata = mix(vec3(0.19, 0.17, 0.16), minerals.rgb, weathering);
	strata *= 0.78 + 0.42 * grain - 0.34 * fissure;
	float rim = pow(1.0 - clamp(normal.z, 0.0, 1.0), 4.0) * 0.13;
	float glint = pow(max(0.0, dot(normal, normalize(sunlight + vec3(0.0, 0.0, 1.0)))), 11.0) * metal;
	vec3 day = strata * (0.29 + lambert * 1.34) * vec3(1.0, 0.94, 0.84);
	vec3 reflected = vec3(0.39, 0.47, 0.57) * rim + vec3(0.38, 0.32, 0.24) * glint;
	ALBEDO = day + reflected;
}

shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 hot : source_color;
uniform vec4 trail : source_color;
uniform bool rocket = false;
uniform float frame = 0.0;

void fragment() {
	float life = 1.0 - UV.y;
	float axis = UV.x * 2.0 - 1.0;
	float bend = sin(UV.y * 18.0) * UV.y * 0.21;
	float distance_to_axis = abs(axis - bend);
	vec3 color;
	float alpha;
	if (rocket) {
		float core = (1.0 - smoothstep(0.04, 0.31, distance_to_axis)) * pow(life, 4.0);
		float fluctuation = 0.8 + 0.2 * sin(frame * 0.42 - UV.y * 13.0);
		float jet = (1.0 - smoothstep(0.07, 0.52, distance_to_axis))
			* (1.0 - smoothstep(0.08, 0.55, UV.y)) * fluctuation;
		vec2 particles = vec2(UV.x * 10.0, UV.y * 15.0 - frame * 0.53);
		vec2 tile = floor(particles);
		float hash = fract(sin(dot(tile, vec2(12.9898, 78.233))) * 43758.5453);
		vec2 grain = fract(particles) - vec2(mix(0.2, 0.8, hash), 0.5);
		float plume_width = mix(0.17, 0.92, smoothstep(0.0, 0.75, UV.y));
		float sparks = (1.0 - smoothstep(0.16, 0.53, length(grain * vec2(1.2, 0.72))))
			* step(0.38, hash) * (1.0 - smoothstep(plume_width * 0.45, plume_width, abs(axis)))
			* smoothstep(0.08, 0.32, UV.y) * pow(life, 0.68);
		vec3 ember = mix(trail.rgb, vec3(0.95, 0.23, 0.55), step(0.58, hash) * smoothstep(0.22, 0.68, UV.y));
		color = mix(ember, hot.rgb, core * 0.88 + sparks * step(0.72, hash) * 0.42);
		alpha = core * 0.94 + jet * 0.67 + sparks * 1.65;
	} else {
		// Trois renflements lumineux reliés par une traînée étroite.
		float length_along = UV.y;
		float phase = frame * 0.19;
		float arc = 0.14 * length_along * sin(length_along * 18.0 - phase);
		float lateral = abs(axis - arc);
		float band = abs(fract(length_along * 3.0 + 0.13) - 0.5);
		float segment = 1.0 - smoothstep(0.04, 0.31, band);
		float radius = mix(0.55, 0.30, length_along);
		float silhouette = 1.0 - smoothstep(0.05, 0.15 + segment * radius, lateral);
		float filament = 1.0 - smoothstep(0.025, 0.10, lateral);
		float flash = 0.78 + 0.22 * cos(length_along * 23.0 - phase);
		color = mix(trail.rgb, hot.rgb, max(0.17 * filament, segment * flash));
		alpha = silhouette * flash * (1.0 - smoothstep(0.67, 1.0, length_along));
	}
	ALBEDO = color;
	ALPHA = min(1.0, alpha);
}

shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 hot : source_color;
uniform vec4 trail : source_color;

void fragment() {
	float life = 1.0 - UV.y;
	float axis = UV.x * 2.0 - 1.0;
	float bend = sin(UV.y * 18.0) * UV.y * 0.21;
	float distance_to_axis = abs(axis - bend);
	float width = mix(0.12, 0.64, smoothstep(0.0, 0.69, UV.y));
	float body = 1.0 - smoothstep(0.08, width, distance_to_axis);
	float pulse = 0.64 + 0.36 * cos(UV.y * 24.0);
	float core = (1.0 - smoothstep(0.04, 0.31, distance_to_axis)) * pow(life, 4.0);
	vec2 grid = UV * vec2(8.0, 13.0);
	vec2 cell = floor(grid);
	float seed = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	vec2 grain = fract(grid) - vec2(mix(0.28, 0.72, seed), 0.5);
	float fleck = (1.0 - smoothstep(0.11, 0.44, length(grain * vec2(1.4, 0.75)))) * step(0.58, seed);
	ALBEDO = mix(trail.rgb, hot.rgb, min(1.0, core * 1.35 + fleck * 0.23));
	ALPHA = min(1.0, core * 0.9 + body * pulse * life * 0.49 + fleck * body * life * 0.76);
}

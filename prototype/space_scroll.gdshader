shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D star_map : filter_nearest, repeat_disable;
uniform ivec3 scroll_pixels = ivec3(0);

vec3 star_color(float sample_value) {
	int packed_star = int(round(sample_value * 255.0));
	int hue = packed_star >> 6;
	float intensity = float(packed_star & 63) / 63.0;
	const vec3 colors[4] = {vec3(0.40, 0.57, 0.97), vec3(0.37, 0.87, 0.93),
		vec3(0.88, 0.51, 0.81), vec3(1.0, 0.82, 0.56)};
	return colors[hue] * intensity;
}

void fragment() {
	// La coordonnée écran donne un texel par pixel, quelle que soit l'échelle du HUD.
	ivec2 pixel = ivec2(FRAGCOORD.xy);
	ivec2 mask = textureSize(star_map, 0) - ivec2(1);
	float far_star = texelFetch(star_map, (pixel - ivec2(0, scroll_pixels.x)) & mask, 0).r;
	float middle_star = texelFetch(star_map, (pixel - ivec2(0, scroll_pixels.y)) & mask, 0).g;
	float near_star = texelFetch(star_map, (pixel - ivec2(0, scroll_pixels.z)) & mask, 0).b;
	vec3 color = vec3(0.0, 0.002, 0.007);
	if (far_star + middle_star + near_star > 0.0) {
		color += star_color(far_star) + star_color(middle_star) + star_color(near_star);
	}
	COLOR = vec4(color, 1.0);
}

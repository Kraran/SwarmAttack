shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D star_map : filter_nearest, repeat_disable;
uniform ivec3 scroll_pixels = ivec3(0);
uniform ivec3 drift_pixels = ivec3(0);

vec3 star_color(float sample_value) {
	int packed_star = int(round(sample_value * 255.0));
	int hue = packed_star >> 6;
	// Légère correction gamma : les étoiles faibles restent lisibles.
	float intensity = pow(float(packed_star & 63) / 63.0, 0.75);
	// Couleurs des types spectraux : bleu (O, B), blanc (A, F), jaune (G, K)
	// et rouge orangé (M). Pas de rose ni de vert, absents du ciel réel.
	const vec3 colors[4] = {vec3(0.62, 0.73, 1.0), vec3(0.92, 0.94, 1.0),
		vec3(1.0, 0.88, 0.64), vec3(1.0, 0.60, 0.38)};
	return colors[hue] * intensity;
}

void fragment() {
	// Un texel par pixel jusqu'à 1440 lignes, puis des texels doublés (4K)
	// pour que les étoiles gardent la même taille apparente.
	int scale = max(1, int(floor(1.0 / SCREEN_PIXEL_SIZE.y / 1080.0 + 0.25)));
	ivec2 pixel = ivec2(FRAGCOORD.xy) / scale;
	ivec2 mask = textureSize(star_map, 0) - ivec2(1);
	float far_star = texelFetch(star_map, (pixel + ivec2(drift_pixels.x, -scroll_pixels.x)) & mask, 0).r;
	float middle_star = texelFetch(star_map, (pixel + ivec2(drift_pixels.y, -scroll_pixels.y)) & mask, 0).g;
	float near_star = texelFetch(star_map, (pixel + ivec2(drift_pixels.z, -scroll_pixels.z)) & mask, 0).b;
	vec3 color = vec3(0.0, 0.002, 0.007);
	if (far_star + middle_star + near_star > 0.0) {
		color += star_color(far_star) + star_color(middle_star) + star_color(near_star);
	}
	COLOR = vec4(color, 1.0);
}

shader_type canvas_item;
render_mode unshaded;

// Composite the supplied white-backed logo over the game's background.
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float white = min(source.r, min(source.g, source.b));
	float alpha = 1.0 - smoothstep(0.80, 0.99, white);
	vec3 ink = clamp((source.rgb - vec3(1.0 - alpha)) / max(alpha, 0.001), 0.0, 1.0);
	COLOR = vec4(ink, source.a * alpha * COLOR.a);
}

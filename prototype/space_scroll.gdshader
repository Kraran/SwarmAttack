shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform sampler2D star_map : filter_linear, repeat_enable;
uniform float vertical_scroll = 0.0;

void fragment() {
	ALBEDO = texture(star_map, vec2(UV.x, UV.y - vertical_scroll)).rgb;
}

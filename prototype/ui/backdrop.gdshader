shader_type canvas_item;

// Skin backdrop in one quad covering the whole visible area (ultra wide included).
// Animated on the GPU: rotating sun rays, breathing glow, drifting halftone and
// short colour flashes on game events. The CPU only sends the clock each frame.
uniform vec2 size = vec2(1280.0, 720.0);     // visible area in canvas units
uniform vec2 origin = vec2(0.0);              // canvas position of the area's top left
uniform vec2 focus = vec2(960.0, 120.0);      // canvas position of the glow centre
uniform float reach = 1468.6;                 // gradient length (base layout diagonal)
uniform float clock = 0.0;
uniform float flash_start = -100.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform vec4 center_color : source_color;
uniform vec4 mid_color : source_color;
uniform vec4 edge_color : source_color;
uniform vec4 ray_color : source_color;
uniform vec4 dot_color : source_color;

const float RAYS = 24.0;

void fragment() {
	vec2 p = origin + UV * size;
	vec2 offset = p - focus;
	float d = length(offset);
	float inner = reach * 0.28;
	float breath = 1.0 + 0.07 * sin(clock * 1.1);
	float glow = d / (inner * breath);
	vec3 color = glow < 1.0
		? mix(center_color.rgb, mid_color.rgb, glow)
		: mix(mid_color.rgb, edge_color.rgb, clamp((d - inner * breath) / (reach - inner), 0.0, 1.0));

	// Rays turn slowly; each one twinkles with its own phase.
	float sector = TAU / RAYS;
	float angle = atan(offset.y, offset.x) + clock * 0.035;
	float index = floor((angle + sector * 0.5) / sector);
	float local = angle - index * sector;
	float width = 0.045 * (1.0 + 0.25 * sin(clock * 0.9 + index * 2.3));
	float ray = (1.0 - smoothstep(width - 0.004, width + 0.004, abs(local)))
		* clamp(1.0 - d / (reach * 0.6), 0.0, 1.0)
		* (0.75 + 0.25 * sin(clock * 1.7 + index * 1.3));
	color = mix(color, ray_color.rgb, ray * ray_color.a);

	// Halftone band along the bottom edge, drifting sideways.
	float band = size.y * 0.3;
	float top = origin.y + size.y - band;
	if (p.y > top - 2.0) {
		float row = floor((p.y - top) / 9.0 + 0.5);
		float cy = top + row * 9.0;
		float shift = mod(cy, 18.0) * 0.5 + clock * 7.0 * (mod(row, 2.0) * 2.0 - 1.0);
		float cx = shift + floor((p.x - shift) / 9.0 + 0.5) * 9.0;
		float strength = clamp((cy - top) / band, 0.0, 1.0);
		float radius = 0.6 + strength * 0.9;
		float dots = (1.0 - smoothstep(radius - 0.5, radius + 0.5, distance(p, vec2(cx, cy)))) * strength * dot_color.a;
		color = mix(color, dot_color.rgb, dots);
	}

	// Event flash: a bright wash from the glow centre that fades in under a second.
	float age = clock - flash_start;
	if (age >= 0.0 && age < 1.2) {
		float flash = exp(-age * 4.0) * clamp(1.0 - d / reach, 0.0, 1.0);
		color += flash_color.rgb * flash * 0.55;
	}
	COLOR = vec4(color, 1.0);
}

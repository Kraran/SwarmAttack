shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.84, 0.89, 0.96, 1.0);
uniform float polish : hint_range(0.0, 1.0) = 0.9;
uniform float emission : hint_range(0.0, 1.0) = 0.0;
varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	// Courbure légère du dessus usiné et reflets directionnels sur les chants.
	vec2 crown = UV - vec2(0.5);
	vec3 normal = normalize(NORMAL + vec3(crown.x * 0.56, -crown.y * 0.49, 0.0));
	vec3 reflected = reflect(vec3(0.0, 0.0, -1.0), normal);
	float horizon = reflected.y + 0.32 * reflected.x;
	float sky = smoothstep(-0.23, -0.01, horizon);
	float softbox = pow(max(0.0, dot(reflected, vec3(-0.48, 0.39, 0.786))), 10.0);
	float strip = exp(-abs(horizon - 0.03) * 18.0) * smoothstep(-0.68, 0.27, -reflected.x);
	float rim = pow(1.0 - max(normal.z, 0.0), 2.7);
	float face = max(0.0, dot(normal, vec3(0.22, -0.48, 0.85)));
	float grain = 0.982 + 0.018 * sin(local_position.x * 15.0 + sin(local_position.z * 9.0));
	vec3 bounced = mix(vec3(0.26, 0.28, 0.34), vec3(0.73, 0.81, 0.97), sky);
	vec3 metal = tint.rgb * bounced * (0.78 + 0.34 * face) * grain;
	metal += vec3(0.71, 0.85, 1.0) * (softbox * 0.69 + strip * 0.53 + rim * 0.19) * polish;
	ALBEDO = clamp(mix(metal, tint.rgb * (0.95 + 0.4 * face), emission), 0.0, 1.0);
}

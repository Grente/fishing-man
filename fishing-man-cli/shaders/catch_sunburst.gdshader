shader_type canvas_item;

// Fixed elliptical glow; soft slow blink on crossing rays (not a fast spin).

uniform vec4 color_dark : source_color = vec4(0.08, 0.28, 0.26, 1.0);
uniform vec4 color_light : source_color = vec4(0.48, 0.90, 0.84, 1.0);
uniform float rays_a : hint_range(12.0, 48.0) = 22.0;
uniform float rays_b : hint_range(12.0, 48.0) = 16.0;
uniform float speed_a = 0.012;
uniform float speed_b = -0.018;
uniform float blink_hz = 0.32;
uniform float oval_rx = 1.08;
uniform float oval_ry = 0.72;
uniform float edge_soft : hint_range(0.01, 0.25) = 0.1;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	vec2 e = vec2(uv.x / oval_rx, uv.y / oval_ry);
	float r = length(e);
	float mask = 1.0 - smoothstep(1.0 - edge_soft, 1.0, r);
	if (mask <= 0.001) {
		discard;
	}

	float ang = atan(e.y, e.x);
	float a = fract((ang + TIME * speed_a) / TAU * rays_a);
	float b = fract((ang + TIME * speed_b) / TAU * rays_b);
	float stripe_a = step(0.5, a);
	float stripe_b = step(0.5, b);
	float cross = abs(stripe_a - stripe_b);

	// Gentle twinkle only (slow sine), not a rapid flash
	float blink = 0.55 + 0.45 * (0.5 + 0.5 * sin(TIME * TAU * blink_hz));
	float lit = mix(0.28, 1.0, cross) * blink;

	vec3 col = mix(color_dark.rgb, color_light.rgb, lit);
	col = mix(col, color_light.rgb * 1.12, exp(-r * 2.6) * 0.35 * blink);
	col *= mix(1.0, 0.5, smoothstep(0.3, 1.0, r));

	COLOR = vec4(col, mask * 0.9);
}

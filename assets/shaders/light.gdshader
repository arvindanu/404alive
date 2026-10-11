shader_type canvas_item;
render_mode unshaded;

// PASS A - runs on the WORLD layer only.
// The world is dim and cold, but never black: a soft band of moonlight lifts the whole playfield
// (ground, obstacles, runner), and the lantern adds a wide warm pool with a little warm bounce.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 light_pos = vec2(0.35, 0.75);
uniform float light_radius = 0.5;
uniform float darkness = 0.32;
uniform vec3 light_col = vec3(1.0, 0.74, 0.46);
uniform float warm = 0.30;
uniform float track_y = 0.78;       // uv.y of the playfield
uniform float track_fill = 0.55;    // how much moonlight opens up the playfield band
uniform vec3 moon_col = vec3(0.52, 0.60, 1.0);
uniform float desat = 0.0;
uniform float fog = 0.0;
uniform float aspect = 1.7777778;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_tex, uv).rgb;
	vec2 d = (uv - light_pos) * vec2(aspect, 1.0);
	float dist = length(d);
	float lit = 1.0 - smoothstep(light_radius * 0.10, light_radius, dist);
	float core = 1.0 - smoothstep(0.0, light_radius * 0.45, dist);
	float band = 1.0 - smoothstep(0.0, 0.34, abs(uv.y - track_y));
	float clear_area = max(lit, band * track_fill);
	float dk = darkness * (1.0 - clear_area);
	col *= 1.0 - dk;
	col = mix(col, col * vec3(0.80, 0.86, 1.08), dk * 0.45);               // cool shadows
	col += vec3(0.014, 0.016, 0.040) * dk;                                  // ambient floor: no crushed blacks
	col += col * moon_col * band * 0.12;                                    // moonlit playfield
	col += col * light_col * (lit * lit * warm + core * 0.25);              // warm lantern bounce
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(l), desat);
	col = mix(col, vec3(0.30, 0.28, 0.36) * (0.4 + l), fog * 0.3);
	COLOR = vec4(col, 1.0);
}

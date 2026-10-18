shader_type canvas_item;

// PSX look — one full-screen pass over the 3D render.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float vertical_resolution : hint_range(90.0, 1080.0) = 240.0;
uniform float colour_steps : hint_range(4.0, 64.0) = 24.0;
uniform float dither_amount : hint_range(0.0, 2.0) = 0.85;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.32;
uniform float saturation : hint_range(0.0, 2.0) = 1.05;
uniform vec3 tint : source_color = vec3(1.0, 0.99, 0.96);
uniform float wobble : hint_range(0.0, 0.02) = 0.0;
uniform float chroma_shift : hint_range(0.0, 0.02) = 0.0;

const float BAYER[16] = float[16](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

void fragment() {
	vec2 uv = SCREEN_UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 res = vec2(vertical_resolution / max(aspect, 0.0001), vertical_resolution);
	vec2 snapped = floor(uv * res) / res;

	if (wobble > 0.0) {
		snapped.x += sin(snapped.y * 42.0 + TIME * 1.7) * wobble;
	}

	vec3 col;
	if (chroma_shift > 0.0) {
		col.r = texture(screen_tex, snapped + vec2(chroma_shift, 0.0)).r;
		col.g = texture(screen_tex, snapped).g;
		col.b = texture(screen_tex, snapped - vec2(chroma_shift, 0.0)).b;
	} else {
		col = texture(screen_tex, snapped).rgb;
	}

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, saturation);
	col *= tint;

	ivec2 px = ivec2(mod(FRAGCOORD.xy, 4.0));
	float threshold = BAYER[px.y * 4 + px.x] / 16.0 - 0.5;
	col += threshold * (dither_amount / colour_steps);
	col = floor(col * colour_steps + 0.5) / colour_steps;

	vec2 c = uv - 0.5;
	float v = 1.0 - dot(c, c) * vignette_strength * 2.2;
	col *= clamp(v, 0.0, 1.0);

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}

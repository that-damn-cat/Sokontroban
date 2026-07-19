shader_type canvas_item;

uniform float transparent_amount : hint_range(0.0, 1.0) = 0.3;
uniform float feather : hint_range(0.0, 0.5) = 0.05;
uniform float angle_degrees : hint_range(0.0, 360.0) = 0.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	// Rotate the UV coordinates around the sprite's center so the fade
	// direction can point any way, not just along the X axis.
	float rad = radians(angle_degrees);
	vec2 dir = vec2(cos(rad), sin(rad));
	float coord = dot(UV - vec2(0.5), dir) + 0.5;

	float edge = transparent_amount;
	float mask = smoothstep(edge - feather, edge + feather, coord);

	tex_color.a *= mask;
	COLOR = tex_color;
}
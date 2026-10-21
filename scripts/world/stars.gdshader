shader_type canvas_item;
// The painted starfield (art/world/stars.png, generated): each star pixel goes out once `dead` (0..1) passes
// its own fixed random threshold, so selling PIXELS puts the sky out pixel by pixel. Island.apply sets `dead`.

uniform float dead : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	uvec2 q = uvec2(floor(UV * vec2(textureSize(TEXTURE, 0))));
	uint n = q.x * 1973u + q.y * 9277u;
	n = (n << 13u) ^ n;
	n = n * (n * n * 15731u + 789221u) + 1376312589u;
	if (float(n & 0x7fffffffu) / 2147483647.0 < dead) {
		discard;
	}
}

// Атмосферный слой поверх кадра: виньетка, зерно и лёгкая дымка.
//
// Три вещи, которые отличают кадр игры от кадра редактора. Виньетка
// собирает взгляд к центру, зерно убивает «пластиковую» чистоту
// плоских заливок, дымка добавляет глубины к дальним планам.

shader_type canvas_item;

uniform float vignette_strength : hint_range(0.0, 1.5) = 0.55;
uniform float vignette_softness : hint_range(0.1, 1.5) = 0.62;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.035;
uniform vec4 haze_color : source_color = vec4(0.05, 0.09, 0.08, 1.0);
uniform float haze_strength : hint_range(0.0, 1.0) = 0.12;
uniform float time_scale = 12.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// Дымка ложится ровным слоем — дальние планы уходят в цвет воздуха.
	vec3 color = mix(vec3(0.0), haze_color.rgb, haze_strength);
	float alpha = haze_strength;

	// Виньетка: расстояние от центра с поправкой на соотношение сторон.
	vec2 centred = uv - vec2(0.5);
	centred.x *= 1.78;
	float dist = length(centred);
	float vignette = smoothstep(vignette_softness, vignette_softness + 0.55, dist);
	alpha = max(alpha, vignette * vignette_strength);
	color = mix(color, vec3(0.0), vignette);

	// Зерно: слегка дрожит во времени, иначе читается как грязь на экране.
	float grain = hash(uv * 1024.0 + fract(TIME * time_scale));
	alpha += (grain - 0.5) * grain_strength;

	COLOR = vec4(color, clamp(alpha, 0.0, 1.0));
}

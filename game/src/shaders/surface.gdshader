// Процедурная поверхность геометрии уровня.
//
// Фактура считается на видеокарте из мировых координат, а не берётся
// из файла: у проекта пока нет художника, а плоская заливка читается
// как заглушка. Привязка к миру, а не к экрану — обязательна, иначе
// текстура «плывёт» при движении камеры.
//
// Один шейдер обслуживает все области: камень Рязани, гранит Петербурга
// и бетон Москвы отличаются параметрами, а не отдельными шейдерами.

shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.12, 0.23, 0.17, 1.0);
uniform vec4 edge_color : source_color = vec4(0.24, 0.45, 0.35, 1.0);
// Цвет прожилок и сколов.
uniform vec4 vein_color : source_color = vec4(0.06, 0.12, 0.09, 1.0);

// Крупность фактуры. Меньше — крупнее пятна.
uniform float grain_scale = 0.035;
// Насколько сильно фактура меняет цвет.
uniform float grain_strength = 0.22;
// Резкость и густота трещин.
uniform float crack_strength = 0.35;
uniform float crack_scale = 0.012;
// Толщина светлой кромки сверху, в пикселях мира.
uniform float edge_width = 3.0;
// Верх блока в мировых координатах — по нему рисуется кромка.
uniform float top_y = 0.0;
// Высота блока, чтобы затемнять низ.
uniform float height = 64.0;

varying vec2 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	// Сглаживание, иначе видна квадратная сетка.
	vec2 u = f * f * (3.0 - 2.0 * f);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Несколько октав шума: крупные пятна плюс мелкое зерно.
float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += value_noise(p) * amp;
		p *= 2.03;
		amp *= 0.5;
	}
	return sum;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec3 color = base_color.rgb;

	// Крупная неоднородность материала.
	float grain = fbm(world_pos * grain_scale);
	color *= 1.0 + (grain - 0.5) * grain_strength * 2.0;

	// Трещины: тонкие тёмные линии по гребням шума.
	float crack_field = fbm(world_pos * crack_scale + vec2(31.4, 7.2));
	float crack = smoothstep(0.48, 0.5, crack_field) - smoothstep(0.5, 0.52, crack_field);
	color = mix(color, vein_color.rgb, crack * crack_strength);

	// Мелкое зерно, чтобы поверхность не выглядела пластиковой.
	float speckle = hash(floor(world_pos * 0.5));
	color *= 0.97 + speckle * 0.06;

	// Освещённая кромка сверху и затемнение вглубь блока.
	float depth = world_pos.y - top_y;
	float edge = 1.0 - smoothstep(0.0, edge_width, depth);
	color = mix(color, edge_color.rgb, edge * 0.85);

	float shade = smoothstep(0.0, height, depth);
	color *= 1.0 - shade * 0.35;

	COLOR = vec4(color, base_color.a);
}

// Экран монитора наблюдения: строчная развёртка, помехи, дрожание.
//
// Чистая картинка с камеры выглядит как окно в другую комнату.
// Помехи и строки превращают её в запись — а от записи ждёшь,
// что в кадре что-то мелькнёт.
//
// Тип spatial, а не canvas_item: экран — это меш в мире, а не элемент
// интерфейса. Режим unshaded обязателен, иначе комнатный свет ложится
// поверх картинки и засвечивает её.

shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D feed : filter_linear, source_color;
// Сила помех: поднимается, когда что-то происходит.
uniform float noise_amount : hint_range(0.0, 1.0) = 0.12;
uniform float scanline_amount : hint_range(0.0, 1.0) = 0.35;
uniform float scanline_count = 240.0;
// Смещение строк — тот самый «сбой сигнала».
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint : source_color = vec3(0.62, 0.82, 0.76);
// Общая яркость экрана. Монитор не должен спорить с лампой в комнате.
uniform float brightness : hint_range(0.0, 2.0) = 0.85;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;

	// Бочка: края экрана слегка выпуклые, как у старого кинескопа.
	vec2 centred = uv - 0.5;
	uv = uv + centred * dot(centred, centred) * 0.1;

	// Сбой: часть строк уезжает вбок.
	if (glitch > 0.001) {
		float band = step(1.0 - glitch, hash(vec2(floor(uv.y * 60.0), floor(TIME * 12.0))));
		uv.x += band * (hash(vec2(floor(TIME * 20.0), floor(uv.y * 60.0))) - 0.5) * 0.22;
	}

	// За пределами экрана — чернота, а не растянутый край.
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		ALBEDO = vec3(0.0);
	} else {
		vec3 color = texture(feed, uv).rgb;

		// Зеленоватый тон дешёвой камеры.
		color = mix(color, color * tint, 0.65);

		// Строчная развёртка.
		float scan = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
		color *= 1.0 - scan * scanline_amount;

		// Зерно сигнала.
		float grain = hash(uv * 512.0 + fract(TIME * 30.0));
		color += (grain - 0.5) * noise_amount;

		// Виньетка объектива.
		float vignette = 1.0 - dot(centred, centred) * 1.05;
		color *= clamp(vignette, 0.0, 1.0);

		ALBEDO = color * brightness;
	}
}

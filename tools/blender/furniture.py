"""Генерация мебели для «Дома, который помнит».

Запуск:
    blender --background --python tools/blender/furniture.py

Скрипт создаёт модели и складывает их в game/assets/models/*.glb.

Главное правило: у настоящей мебели нет острых рёбер. Фаска шириной
в пару миллиметров ловит блик и отличает модель от коробки сильнее,
чем любое количество полигонов. Поэтому фаска стоит почти везде.
"""

import bpy
import bmesh
import math
import os
import sys

OUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "game", "assets", "models",
)


def clear_scene():
    """Пустая сцена: Blender стартует с кубом, светом и камерой."""
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.objects):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def box(name, size, location=(0, 0, 0), bevel=0.004):
    """Скруглённый параллелепипед — основа всей мебели."""
    # primitive_cube_add(size=1) даёт куб со стороной 1, а не 2:
    # масштаб равен нужному размеру, делить пополам не надо.
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (size[0], size[1], size[2])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    if bevel > 0:
        modifier = obj.modifiers.new(name="Bevel", type="BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        modifier.limit_method = "ANGLE"
        modifier.angle_limit = math.radians(40)
        bpy.ops.object.modifier_apply(modifier=modifier.name)

    return obj


def cylinder(name, radius, depth, location=(0, 0, 0), rotation=(0, 0, 0), verts=16):
    bpy.ops.mesh.primitive_cylinder_add(
        radius=radius, depth=depth, location=location, rotation=rotation, vertices=verts
    )
    obj = bpy.context.active_object
    obj.name = name
    return obj


def join(objects, name):
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    result = bpy.context.active_object
    result.name = name
    return result


def shade_smooth_by_angle(obj, angle=35):
    """Гладкое затенение только на плавных изгибах — грани остаются гранями.

    В Blender 4.1+ use_auto_smooth убрали, вместо него оператор
    shade_auto_smooth. Поддерживаем оба варианта: скрипт должен
    пережить обновление движка.
    """
    bpy.context.view_layer.objects.active = obj

    if hasattr(bpy.ops.object, "shade_auto_smooth"):
        bpy.ops.object.shade_auto_smooth(angle=math.radians(angle))
        return

    bpy.ops.object.shade_smooth()
    if hasattr(obj.data, "use_auto_smooth"):
        obj.data.use_auto_smooth = True
        obj.data.auto_smooth_angle = math.radians(angle)


def export(obj, filename):
    """Экспорт в glTF.

    Blender считает вверхом Z, glTF и Godot — Y. Автоматическая конверсия
    экспортёра здесь складывалась с конверсией импортёра Godot, и мебель
    приезжала лежащей набок. Поэтому поворачиваем модель сами и отключаем
    конверсию: одно преобразование вместо двух.
    """
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    obj.rotation_euler = (-math.pi / 2, 0, 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)

    path = os.path.join(OUT_DIR, filename)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=False,
    )
    print("сохранено: %s" % path)


# --- Модели ------------------------------------------------------------

def make_door():
    """Дверь с филёнками и ручкой. Филёнки — то, чем дверь отличается
    от прямоугольника, и они первое, что видит игрок в коридоре."""
    clear_scene()
    parts = [box("leaf", (0.86, 0.045, 2.03), (0, 0, 1.015))]

    # Две филёнки: верхняя длиннее нижней, как на обычной межкомнатной.
    for z, height in ((1.42, 0.78), (0.52, 0.62)):
        frame = box("panel_out", (0.62, 0.05, height), (0, 0, z), bevel=0.006)
        inner = box("panel_in", (0.52, 0.07, height - 0.1), (0, 0, z), bevel=0.004)
        # Углубление режем булевой операцией — так появляется настоящая тень.
        modifier = frame.modifiers.new(name="Cut", type="BOOLEAN")
        modifier.operation = "DIFFERENCE"
        modifier.object = inner
        bpy.context.view_layer.objects.active = frame
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        bpy.data.objects.remove(inner, do_unlink=True)
        parts.append(frame)

    handle = cylinder("handle", 0.018, 0.11, (0.33, -0.055, 1.02), (math.pi / 2, 0, 0))
    knob = cylinder("knob", 0.028, 0.02, (0.33, -0.105, 1.02), (math.pi / 2, 0, 0))
    parts += [handle, knob]

    door = join(parts, "Door")
    export(door, "door.glb")


def make_chair():
    clear_scene()
    parts = [box("seat", (0.44, 0.44, 0.045), (0, 0, 0.45))]

    for x in (-0.19, 0.19):
        for y in (-0.19, 0.19):
            # Задние ножки выше: они продолжаются в спинку.
            height = 0.9 if y > 0 else 0.45
            parts.append(box("leg", (0.035, 0.035, height), (x, y, height / 2)))

    parts.append(box("back_top", (0.44, 0.035, 0.09), (0, 0.19, 0.84)))
    parts.append(box("back_mid", (0.44, 0.03, 0.06), (0, 0.19, 0.66)))

    chair = join(parts, "Chair")
    export(chair, "chair.glb")


def make_table():
    clear_scene()
    parts = [box("top", (1.3, 0.8, 0.05), (0, 0, 0.74))]
    parts.append(box("apron_x", (1.18, 0.06, 0.08), (0, 0.34, 0.68)))
    parts.append(box("apron_x2", (1.18, 0.06, 0.08), (0, -0.34, 0.68)))

    for x in (-0.58, 0.58):
        for y in (-0.33, 0.33):
            parts.append(box("leg", (0.06, 0.06, 0.72), (x, y, 0.36)))

    table = join(parts, "Table")
    export(table, "table.glb")


def make_wardrobe():
    clear_scene()
    parts = [
        box("body", (1.0, 0.56, 2.1), (0, 0, 1.05)),
        box("plinth", (1.02, 0.58, 0.08), (0, 0, 0.04)),
        box("cornice", (1.06, 0.62, 0.06), (0, 0, 2.13)),
    ]

    # Дверцы врезаем углублением, чтобы был виден стык.
    for x in (-0.25, 0.25):
        panel = box("door_panel", (0.46, 0.02, 1.86), (x, -0.29, 1.05), bevel=0.006)
        parts.append(panel)
        parts.append(cylinder("pull", 0.012, 0.14, (x + 0.19, -0.32, 1.05), (math.pi / 2, 0, 0)))

    wardrobe = join(parts, "Wardrobe")
    export(wardrobe, "wardrobe.glb")


def make_lamp():
    """Торшер: видимый источник света. Без него свет идёт ниоткуда."""
    clear_scene()
    parts = [
        cylinder("base", 0.16, 0.03, (0, 0, 0.015), verts=24),
        cylinder("stem", 0.018, 1.35, (0, 0, 0.69), verts=12),
    ]

    bpy.ops.mesh.primitive_cone_add(
        radius1=0.2, radius2=0.14, depth=0.26, location=(0, 0, 1.48), vertices=24
    )
    shade = bpy.context.active_object
    shade.name = "shade"
    parts.append(shade)

    lamp = join(parts, "FloorLamp")
    export(lamp, "floor_lamp.glb")


def make_box_prop():
    """Картонная коробка: скошенные клапаны сверху."""
    clear_scene()
    parts = [box("body", (0.44, 0.36, 0.34), (0, 0, 0.17))]
    for y, angle in ((0.18, 0.5), (-0.18, -0.5)):
        flap = box("flap", (0.44, 0.17, 0.012), (0, y, 0.35))
        flap.rotation_euler = (angle, 0, 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        parts.append(flap)

    crate = join(parts, "CardboardBox")
    export(crate, "cardboard_box.glb")


def make_coffee_machine():
    """Кофемашина. Кофе — сквозная тема всей игры, и точка сохранения
    должна быть узнаваема с порога комнаты."""
    clear_scene()
    parts = [
        box("body", (0.28, 0.34, 0.38), (0, 0, 0.19)),
        # Ниша под чашку: вырезаем углубление, а не рисуем его.
        box("top", (0.28, 0.34, 0.06), (0, 0, 0.41)),
    ]

    niche = box("niche", (0.19, 0.24, 0.16), (0, -0.06, 0.13), bevel=0.003)
    modifier = parts[0].modifiers.new(name="Cut", type="BOOLEAN")
    modifier.operation = "DIFFERENCE"
    modifier.object = niche
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.data.objects.remove(niche, do_unlink=True)

    # Разливочная группа и поддон.
    parts.append(cylinder("spout", 0.02, 0.05, (0, -0.06, 0.235), verts=12))
    parts.append(box("tray", (0.18, 0.22, 0.012), (0, -0.06, 0.055)))
    # Панель кнопок.
    for i in range(3):
        parts.append(cylinder("btn", 0.012, 0.008, (-0.08 + i * 0.08, -0.172, 0.32), (math.pi / 2, 0, 0), verts=10))

    machine = join(parts, "CoffeeMachine")
    export(machine, "coffee_machine.glb")


def make_mirror():
    """Зеркало в раме. Нужно для скримера с запаздывающим отражением,
    поэтому стекло — отдельная плоскость с собственным материалом."""
    clear_scene()
    parts = [
        box("frame", (0.62, 0.05, 1.24), (0, 0, 0.62)),
    ]
    glass = box("glass", (0.52, 0.02, 1.14), (0, -0.02, 0.62), bevel=0.002)
    parts.append(glass)

    mirror = join(parts, "Mirror")
    export(mirror, "mirror.glb")


def make_bed():
    clear_scene()
    parts = [
        box("mattress", (0.95, 1.95, 0.22), (0, 0, 0.42)),
        box("frame", (1.03, 2.03, 0.16), (0, 0, 0.24)),
        box("headboard", (1.03, 0.06, 0.62), (0, 1.0, 0.55)),
        # Подушка и складка одеяла: без них кровать — просто параллелепипед.
        box("pillow", (0.5, 0.3, 0.11), (0, 0.75, 0.58), bevel=0.03),
        box("blanket", (0.99, 1.25, 0.06), (0, -0.3, 0.55), bevel=0.02),
    ]
    for x in (-0.46, 0.46):
        for y in (-0.94, 0.94):
            parts.append(box("leg", (0.07, 0.07, 0.16), (x, y, 0.08)))

    bed = join(parts, "Bed")
    export(bed, "bed.glb")


def make_shelf():
    """Стеллаж с книгами. Книги разной высоты и наклона — иначе полка
    читается как сплошной брусок."""
    clear_scene()
    parts = [
        box("side_l", (0.04, 0.32, 1.8), (-0.44, 0, 0.9)),
        box("side_r", (0.04, 0.32, 1.8), (0.44, 0, 0.9)),
        box("back", (0.92, 0.02, 1.8), (0, 0.16, 0.9)),
    ]

    shelf_heights = (0.32, 0.76, 1.2, 1.64)
    for z in shelf_heights:
        parts.append(box("shelf", (0.88, 0.32, 0.03), (0, 0, z)))

    rng_x = -0.4
    for index, z in enumerate(shelf_heights[:-1]):
        x = -0.4
        while x < 0.36:
            width = 0.03 + (index * 7 + int(x * 100)) % 4 * 0.012
            height = 0.2 + ((index * 5 + int(x * 90)) % 5) * 0.022
            book = box("book", (width, 0.24, height), (x + width / 2, -0.02, z + 0.015 + height / 2))
            # Каждая пятая книга наклонена — глаз цепляется именно за это.
            if (index * 3 + int(x * 80)) % 5 == 0:
                book.rotation_euler = (0, math.radians(9), 0)
                bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
            parts.append(book)
            x += width + 0.006

    shelf = join(parts, "Shelf")
    export(shelf, "shelf.glb")


def make_helmet():
    """Гоночный шлем на полке. Отсылка к Ferrari — и единственный
    предмет в доме, который игрок узнает мгновенно."""
    clear_scene()
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.14, location=(0, 0, 0.14), segments=24, ring_count=16)
    shell = bpy.context.active_object
    shell.name = "shell"
    shell.scale = (1.0, 1.15, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    # Срезаем низ, чтобы шлем стоял, а не катался.
    cutter = box("cut", (0.4, 0.4, 0.12), (0, 0, 0.02), bevel=0)
    modifier = shell.modifiers.new(name="Cut", type="BOOLEAN")
    modifier.operation = "DIFFERENCE"
    modifier.object = cutter
    bpy.context.view_layer.objects.active = shell
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.data.objects.remove(cutter, do_unlink=True)

    visor = box("visor", (0.2, 0.14, 0.09), (0, -0.11, 0.17), bevel=0.01)
    helmet = join([shell, visor], "Helmet")
    shade_smooth_by_angle(helmet)
    export(helmet, "helmet.glb")


def make_suitcase():
    """Чемодан. Катя была почти во всех городах России — вещь,
    которая говорит об этом без единого слова."""
    clear_scene()
    parts = [
        box("body", (0.52, 0.2, 0.72), (0, 0, 0.36)),
        box("seam", (0.53, 0.21, 0.02), (0, 0, 0.4)),
        box("handle_base", (0.16, 0.03, 0.03), (0, 0, 0.735)),
    ]
    parts.append(cylinder("handle", 0.012, 0.16, (0, 0, 0.78), (0, math.pi / 2, 0), verts=10))
    for x in (-0.2, 0.2):
        parts.append(cylinder("wheel", 0.03, 0.02, (x, 0, 0.02), (0, math.pi / 2, 0), verts=12))

    case = join(parts, "Suitcase")
    export(case, "suitcase.glb")


def make_snake():
    """Змея. Слизерин — часть характера хозяйки, поэтому змеи в доме
    не враги, а свои: они подсказывают дорогу и открывают замки.

    Тело строится по кривой: цепочка сегментов с затуханием радиуса
    к хвосту читается как змея, а ровный цилиндр — как шланг.
    """
    clear_scene()
    parts = []

    segments = 26
    length = 1.5
    for i in range(segments):
        t = i / float(segments - 1)
        # Синус даёт изгиб, а сужение к хвосту — узнаваемый силуэт.
        x = math.sin(t * math.pi * 2.2) * 0.16
        y = -length / 2 + t * length
        radius = 0.055 * (1.0 - t * 0.72) + 0.012

        ring = cylinder("seg", radius, length / segments * 1.6, (x, y, radius), verts=10)
        ring.rotation_euler = (math.pi / 2, 0, 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        parts.append(ring)

    # Голова: чуть крупнее шеи и приподнята.
    head_x = math.sin(0.0) * 0.16
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.062, location=(head_x, -length / 2 - 0.03, 0.075), segments=16, ring_count=10)
    head = bpy.context.active_object
    head.name = "head"
    head.scale = (1.0, 1.35, 0.8)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    parts.append(head)

    snake = join(parts, "Snake")
    shade_smooth_by_angle(snake, angle=45)
    export(snake, "snake.glb")


def make_figure():
    """Силуэт человека для скримеров на записи.

    Намеренно без лица и без деталей: на камере наблюдения человек
    и так читается пятном, а любая проработка выдала бы, что фигура
    ненастоящая. Работает силуэт, а не модель.
    """
    clear_scene()
    parts = []

    # Ноги.
    for x in (-0.09, 0.09):
        parts.append(box("leg", (0.13, 0.15, 0.82), (x, 0, 0.41), bevel=0.02))

    # Корпус: сужается к талии и расширяется к плечам.
    parts.append(box("hips", (0.34, 0.19, 0.22), (0, 0, 0.92), bevel=0.03))
    parts.append(box("chest", (0.42, 0.22, 0.42), (0, 0, 1.28), bevel=0.04))

    # Руки вдоль тела.
    for x in (-0.26, 0.26):
        parts.append(box("arm", (0.11, 0.13, 0.62), (x, 0, 1.14), bevel=0.02))

    # Шея и голова.
    parts.append(cylinder("neck", 0.05, 0.09, (0, 0, 1.53), verts=10))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.115, location=(0, 0, 1.66), segments=18, ring_count=12)
    head = bpy.context.active_object
    head.name = "head"
    head.scale = (1.0, 1.15, 1.25)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    parts.append(head)

    figure = join(parts, "Figure")
    shade_smooth_by_angle(figure, angle=50)
    export(figure, "figure.glb")


def make_ceiling_lamp():
    """Потолочная арматура: шнур, патрон, эмалированный плафон.

    Голая светящаяся сфера читается как источник света из движка,
    а не как лампа. Плафон нужен ещё и затем, чтобы свет падал
    конусом вниз, а не ровным шаром во все стороны.
    """
    clear_scene()
    parts = []

    # Шнур от потолка.
    parts.append(cylinder("cord", 0.006, 0.34, (0, 0, 0.17), verts=6))
    # Патрон.
    parts.append(cylinder("socket", 0.028, 0.07, (0, 0, -0.035), verts=12))

    # Плафон-конус, раскрытый вниз.
    bpy.ops.mesh.primitive_cone_add(
        radius1=0.055, radius2=0.17, depth=0.16, location=(0, 0, -0.14), vertices=24
    )
    shade = bpy.context.active_object
    shade.name = "shade"
    parts.append(shade)

    # Ободок по краю плафона: ловит блик и отделяет край от темноты.
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.17, minor_radius=0.006, location=(0, 0, -0.22), major_segments=24, minor_segments=6
    )
    rim = bpy.context.active_object
    rim.name = "rim"
    parts.append(rim)

    lamp = join(parts, "CeilingLamp")
    shade_smooth_by_angle(lamp, angle=40)
    export(lamp, "ceiling_lamp.glb")


def main():
    make_door()
    make_chair()
    make_table()
    make_wardrobe()
    make_lamp()
    make_box_prop()
    make_coffee_machine()
    make_mirror()
    make_bed()
    make_shelf()
    make_helmet()
    make_suitcase()
    make_snake()
    make_figure()
    make_ceiling_lamp()
    print("готово: модели в %s" % OUT_DIR)


if __name__ == "__main__":
    main()

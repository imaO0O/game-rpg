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


def bevel_object(obj, width, segments=2):
    """Фаска отдельным вызовом: нужна там, где объект собран не через box()."""
    bpy.context.view_layer.objects.active = obj
    modifier = obj.modifiers.new(name="Bevel", type="BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    modifier.angle_limit = math.radians(40)
    bpy.ops.object.modifier_apply(modifier=modifier.name)


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

    # Забираем всё, что осталось в сцене, а не только выделенное.
    # Объединение частей срабатывало не всегда, и в файл уходила
    # одна столешница вместо стола — молча, без единой ошибки.
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if len(meshes) > 1:
        print("ВНИМАНИЕ: %s собран из %d кусков, объединяю" % (filename, len(meshes)))
        obj = join(meshes, obj.name)

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

    verts = len(obj.data.vertices)
    dims = obj.dimensions
    print("сохранено: %s — вершин %d, габариты %.2f x %.2f x %.2f"
          % (filename, verts, dims.x, dims.y, dims.z))


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


def limb(name, start, end, radius, taper=0.75):
    """Конечность как усечённый конус между двумя точками.

    Коробки в роли рук и ног читаются деталями конструктора. Конус
    сужается к кисти или стопе, и силуэт сразу становится телом,
    а не набором брусков.
    """
    sx, sy, sz = start
    ex, ey, ez = end
    dx, dy, dz = ex - sx, ey - sy, ez - sz
    length = math.sqrt(dx * dx + dy * dy + dz * dz)

    bpy.ops.mesh.primitive_cone_add(
        radius1=radius,
        radius2=radius * taper,
        depth=length,
        location=((sx + ex) / 2, (sy + ey) / 2, (sz + ez) / 2),
        vertices=12,
    )
    obj = bpy.context.active_object
    obj.name = name

    # Разворачиваем конус вдоль отрезка: по умолчанию он смотрит вверх.
    obj.rotation_euler = (
        math.acos(dz / length) if length > 0 else 0.0,
        0.0,
        math.atan2(dy, dx) + math.pi / 2,
    )
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return obj


def foot(name, position, yaw):
    """Ступня-клин. Обрубленный цилиндр ноги читается протезом."""
    obj = box(name, (0.09, 0.21, 0.055), position, bevel=0.015)
    obj.rotation_euler = (0, 0, yaw)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return obj


def make_figure():
    """Фигура для скримеров.

    Она обязана быть НЕ похожа на Зейда: узнаваемость — худший враг
    скримера. Поэтому здесь всё, чего у живого человека не бывает:
    рост под два метра, руки почти до колен, длинная шея, голова
    склонена набок, плечи на разной высоте.

    Игрок не считает эти пропорции сознательно. Он просто поймёт,
    что перед ним что-то неправильное, и не сможет объяснить, что
    именно, — на этом скример и держится.

    Лица нет: на записи с камеры и в темноте оно не читается,
    а нарисованное выдало бы подделку.
    """
    clear_scene()
    parts = []

    # Ноги: длинные, тонкие, чуть вывернутые.
    parts.append(limb("leg_l", (-0.1, 0.02, 1.02), (-0.13, -0.05, 0.06), 0.06, 0.55))
    parts.append(limb("leg_r", (0.1, -0.01, 1.02), (0.12, 0.07, 0.06), 0.06, 0.55))
    parts.append(foot("foot_l", (-0.13, -0.09, 0.028), math.radians(-8)))
    parts.append(foot("foot_r", (0.12, 0.03, 0.028), math.radians(11)))

    parts.append(box("hips", (0.24, 0.15, 0.18), (0, 0, 1.1), bevel=0.035))

    # Торс намеренно несимметричный: перекошен и повёрнут.
    # Идеально осевой конус — главное, что выдаёт манекен.
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0.015, -0.03, 1.46))
    chest = bpy.context.active_object
    chest.name = "chest"
    chest.scale = (0.3, 0.17, 0.52)
    chest.rotation_euler = (math.radians(11), math.radians(4), math.radians(3))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bevel_object(chest, 0.045)
    parts.append(chest)

    # Плечи на разной высоте и разной толщины.
    parts.append(limb("clav_l", (-0.02, -0.04, 1.7), (-0.2, -0.02, 1.66), 0.06, 0.85))
    parts.append(limb("clav_r", (0.02, -0.04, 1.7), (0.21, -0.06, 1.72), 0.055, 0.85))

    # Руки почти до колен: у человека кисть заканчивается у середины
    # бедра, здесь — заметно ниже.
    parts.append(limb("arm_l", (-0.2, -0.02, 1.64), (-0.29, 0.05, 0.72), 0.048, 0.5))
    parts.append(limb("arm_r", (0.21, -0.06, 1.7), (0.27, -0.13, 0.78), 0.045, 0.5))

    # Длинная шея, склонённая набок.
    parts.append(limb("neck", (0, -0.05, 1.68), (0.04, -0.09, 1.88), 0.04, 0.85))

    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.1, location=(0.05, -0.1, 1.96), segments=20, ring_count=14
    )
    head = bpy.context.active_object
    head.name = "head"
    head.scale = (0.86, 1.05, 1.32)
    # Наклон набок — то, чего живой человек не держит подолгу.
    head.rotation_euler = (math.radians(14), math.radians(-3), math.radians(13))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    parts.append(head)

    figure = join(parts, "Figure")
    shade_smooth_by_angle(figure, angle=55)
    export(figure, "figure.glb")


def make_zade():
    """Зейд для финала: та же фигура, но в пальто и с сумкой.

    В скримерах он безликое пятно на записи. В финале он должен
    читаться конкретным человеком, иначе встреча ничем не отличается
    от очередного силуэта в коридоре.
    """
    clear_scene()
    parts = []

    parts.append(limb("leg_l", (-0.11, 0.02, 0.88), (-0.13, -0.03, 0.05), 0.08, 0.65))
    parts.append(limb("leg_r", (0.11, 0.0, 0.88), (0.12, 0.05, 0.05), 0.08, 0.65))
    parts.append(foot("foot_l", (-0.13, -0.07, 0.025), math.radians(-6)))
    parts.append(foot("foot_r", (0.12, 0.01, 0.025), math.radians(7)))

    # Пальто до колен: чуть расширяется книзу, но не бочкой —
    # при равной ширине сверху и снизу силуэт читается мешком.
    bpy.ops.mesh.primitive_cone_add(
        radius1=0.19, radius2=0.25, depth=0.84, location=(0, -0.01, 1.22), vertices=20
    )
    coat = bpy.context.active_object
    coat.name = "coat"
    coat.scale = (1.0, 0.62, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    parts.append(coat)

    # Плечи поверх пальто: без них верх сходится в конус и человек
    # выглядит воронкой.
    parts.append(cylinder("shoulders", 0.07, 0.38, (0, -0.02, 1.58), (0, math.pi / 2, 0), verts=12))

    # Воротник.
    parts.append(cylinder("collar", 0.105, 0.1, (0, -0.03, 1.66), verts=14))

    # Руки в карманах: короткие отрезки, уходящие в пальто.
    # Обе на месте и разной длины — одну руку легко забыть, а её
    # отсутствие сразу читается как ошибка модели.
    parts.append(limb("arm_l", (-0.21, -0.03, 1.52), (-0.185, -0.09, 1.12), 0.055, 0.9))
    parts.append(limb("arm_r", (0.21, -0.03, 1.52), (0.175, -0.09, 1.18), 0.052, 0.9))

    # Воротник-уступ: без него голова выглядит приклеенной к плечам.
    parts.append(limb("neck", (0, -0.02, 1.62), (0, -0.05, 1.76), 0.05, 0.85))

    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.11, location=(0, -0.06, 1.83), segments=20, ring_count=14
    )
    head = bpy.context.active_object
    head.name = "head"
    head.scale = (0.94, 1.08, 1.22)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    parts.append(head)

    # Сумка через плечо — то, с чем он ходил по её городам.
    parts.append(box("strap", (0.03, 0.02, 0.5), (0.1, -0.11, 1.3), bevel=0.008))
    parts.append(box("bag", (0.22, 0.1, 0.18), (-0.22, -0.1, 1.02), bevel=0.02))

    zade = join(parts, "Zade")
    shade_smooth_by_angle(zade, angle=55)
    export(zade, "zade.glb")


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


def make_mug():
    """Кружка. Кофе — сквозная тема, и брошенная кружка говорит
    о жильце больше, чем целый шкаф."""
    clear_scene()
    parts = []

    body = cylinder("body", 0.042, 0.095, (0, 0, 0.047), verts=20)
    hollow = cylinder("hollow", 0.036, 0.085, (0, 0, 0.055), verts=20)
    modifier = body.modifiers.new(name="Cut", type="BOOLEAN")
    modifier.operation = "DIFFERENCE"
    modifier.object = hollow
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.data.objects.remove(hollow, do_unlink=True)
    parts.append(body)

    # Ручка: половина тора, срезанная плоскостью.
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.032, minor_radius=0.006,
        location=(0.055, 0, 0.05), rotation=(0, math.pi / 2, 0),
        major_segments=16, minor_segments=8
    )
    handle = bpy.context.active_object
    handle.name = "handle"
    parts.append(handle)

    mug = join(parts, "Mug")
    shade_smooth_by_angle(mug, angle=45)
    export(mug, "mug.glb")


def make_book():
    """Книга. Лежит, а не стоит: лежащая читается как оставленная,
    стоящая — как часть обстановки."""
    clear_scene()
    parts = [
        box("cover", (0.15, 0.21, 0.032), (0, 0, 0.016), bevel=0.002),
        # Блок страниц чуть уже обложки — отсюда и тень по краю.
        box("pages", (0.142, 0.2, 0.024), (0, 0, 0.016), bevel=0.001),
        box("spine", (0.012, 0.21, 0.034), (-0.075, 0, 0.017), bevel=0.003),
    ]
    book = join(parts, "Book")
    export(book, "book.glb")


def make_bottle():
    clear_scene()
    parts = [
        cylinder("body", 0.035, 0.19, (0, 0, 0.095), verts=16),
        cylinder("neck", 0.014, 0.08, (0, 0, 0.225), verts=12),
        cylinder("cap", 0.016, 0.022, (0, 0, 0.272), verts=12),
    ]
    # Скос от плеча к горлышку.
    bpy.ops.mesh.primitive_cone_add(
        radius1=0.035, radius2=0.014, depth=0.05, location=(0, 0, 0.215), vertices=16
    )
    shoulder = bpy.context.active_object
    shoulder.name = "shoulder"
    parts.append(shoulder)

    bottle = join(parts, "Bottle")
    shade_smooth_by_angle(bottle, angle=40)
    export(bottle, "bottle.glb")


def make_frame():
    """Рамка с фотографией. Держатель осколков памяти: сама рамка
    из кода, а снимок внутри подставляется из private/."""
    clear_scene()
    parts = [
        box("frame", (0.19, 0.025, 0.25), (0, 0, 0.125), bevel=0.004),
        # Углубление под снимок: без него рамка — просто дощечка.
        box("photo", (0.15, 0.005, 0.21), (0, -0.014, 0.125), bevel=0.001),
        # Подставка сзади, чтобы рамка стояла под углом.
        box("stand", (0.03, 0.06, 0.16), (0, 0.05, 0.08), bevel=0.003),
    ]
    frame = join(parts, "PhotoFrame")
    export(frame, "photo_frame.glb")


def make_clock():
    """Настенные часы. В хорроре они нужны затем, чтобы игрок
    заметил, что стрелка не двигается."""
    clear_scene()
    parts = [
        cylinder("case", 0.13, 0.035, (0, 0, 0), (math.pi / 2, 0, 0), verts=28),
        cylinder("face", 0.118, 0.005, (0, -0.019, 0), (math.pi / 2, 0, 0), verts=28),
        box("hand_h", (0.012, 0.006, 0.06), (0, -0.024, 0.03), bevel=0.001),
        box("hand_m", (0.008, 0.006, 0.09), (0.035, -0.024, 0.01), bevel=0.001),
    ]
    clock = join(parts, "WallClock")
    shade_smooth_by_angle(clock, angle=40)
    export(clock, "wall_clock.glb")


def make_ticket():
    """Билет. Катя была почти во всех городах России — стопка билетов
    рассказывает об этом без единого слова."""
    clear_scene()
    parts = []
    # Несколько листков со сдвигом: одинокий билет читается как мусор.
    for i in range(4):
        sheet = box(
            "ticket",
            (0.075, 0.14, 0.0012),
            (i * 0.004, i * 0.003, 0.0006 + i * 0.0013),
            bevel=0.0004,
        )
        sheet.rotation_euler = (0, 0, math.radians(i * 4 - 6))
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        parts.append(sheet)

    tickets = join(parts, "Tickets")
    export(tickets, "tickets.glb")


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
    make_zade()
    make_ceiling_lamp()
    make_mug()
    make_book()
    make_bottle()
    make_frame()
    make_clock()
    make_ticket()
    print("готово: модели в %s" % OUT_DIR)


if __name__ == "__main__":
    main()

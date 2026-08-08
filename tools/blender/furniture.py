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
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
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
    """Гладкое затенение только на плавных изгибах — грани остаются гранями."""
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth()
    obj.data.use_auto_smooth = True if hasattr(obj.data, "use_auto_smooth") else False
    modifier = obj.modifiers.new(name="Smooth", type="WEIGHTED_NORMAL")
    modifier.keep_sharp = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)


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


def main():
    make_door()
    make_chair()
    make_table()
    make_wardrobe()
    make_lamp()
    make_box_prop()
    print("готово: модели в %s" % OUT_DIR)


if __name__ == "__main__":
    main()

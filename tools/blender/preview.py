"""Рендер превью каждой модели — проверка ассетов до того, как они попадут в игру.

Запуск:
    blender --background --python tools/blender/preview.py

Кладёт PNG рядом с моделями, в game/assets/models/previews/.
Без этого шага сломанная модель обнаруживается только в игре, где
её не отличить от проблемы с освещением или расстановкой.
"""

import bpy
import math
import os
import glob

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODELS_DIR = os.path.join(ROOT, "game", "assets", "models")
OUT_DIR = os.path.join(MODELS_DIR, "previews")


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def setup_studio():
    """Три источника света и серый пол — стандартная студийная выкладка,
    на которой видно и силуэт, и фаски."""
    bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, 0))
    floor = bpy.context.active_object
    mat = bpy.data.materials.new("floor")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.22, 0.22, 0.24, 1)
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
    floor.data.materials.append(mat)

    key = bpy.data.lights.new("key", type="AREA")
    key.energy = 400
    key.size = 3
    key_obj = bpy.data.objects.new("key", key)
    key_obj.location = (2.5, -2.5, 3.5)
    key_obj.rotation_euler = (math.radians(50), 0, math.radians(45))
    bpy.context.collection.objects.link(key_obj)

    fill = bpy.data.lights.new("fill", type="AREA")
    fill.energy = 120
    fill.size = 4
    fill_obj = bpy.data.objects.new("fill", fill)
    fill_obj.location = (-3, -2, 2)
    fill_obj.rotation_euler = (math.radians(65), 0, math.radians(-55))
    bpy.context.collection.objects.link(fill_obj)

    rim = bpy.data.lights.new("rim", type="AREA")
    rim.energy = 200
    rim.size = 2
    rim_obj = bpy.data.objects.new("rim", rim)
    rim_obj.location = (0, 3.5, 2.5)
    rim_obj.rotation_euler = (math.radians(115), 0, 0)
    bpy.context.collection.objects.link(rim_obj)


def frame_object(obj):
    """Камера в три четверти, кадр по габаритам модели."""
    bbox = [obj.matrix_world @ v.co for v in obj.data.vertices]
    if not bbox:
        return None

    xs = [v.x for v in bbox]
    ys = [v.y for v in bbox]
    zs = [v.z for v in bbox]
    centre = ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2)
    size = max(max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs), 0.3)

    distance = size * 2.4
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = 50
    cam = bpy.data.objects.new("cam", cam_data)
    cam.location = (
        centre[0] + distance * 0.75,
        centre[1] - distance * 0.85,
        centre[2] + distance * 0.55,
    )
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam

    track = cam.constraints.new(type="TRACK_TO")
    empty = bpy.data.objects.new("target", None)
    empty.location = centre
    bpy.context.collection.objects.link(empty)
    track.target = empty
    return cam


def render(path):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.filepath = path
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)


def preview_model(path):
    name = os.path.splitext(os.path.basename(path))[0]
    clear_scene()
    setup_studio()

    bpy.ops.import_scene.gltf(filepath=path)
    imported = [o for o in bpy.context.selected_objects if o.type == "MESH"]
    if not imported:
        print("ПУСТО: в %s нет мешей" % name)
        return

    # Берём все куски, а не первый: раньше превью показывало одну
    # столешницу вместо стола и выглядело как сломанная модель,
    # хотя ломался только инструмент проверки.
    obj = imported[0]
    if len(imported) > 1:
        for part in imported:
            part.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.join()
        obj = bpy.context.active_object
    # Модели экспортируются повёрнутыми под систему координат игры,
    # где вверх — это Y. В студии Blender вверх по Z, поэтому без
    # обратного поворота стол лежал ножками под полом и выглядел
    # как одна столешница.
    obj.rotation_euler = (math.pi / 2, 0, 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)

    verts = len(obj.data.vertices)
    dims = obj.dimensions
    print("%s: вершин %d, габариты %.2f x %.2f x %.2f" % (name, verts, dims.x, dims.y, dims.z))

    frame_object(obj)
    render(os.path.join(OUT_DIR, "%s.png" % name))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    files = sorted(glob.glob(os.path.join(MODELS_DIR, "*.glb")))
    if not files:
        print("моделей не найдено в %s" % MODELS_DIR)
        return
    for path in files:
        preview_model(path)
    print("превью готовы: %s" % OUT_DIR)


if __name__ == "__main__":
    main()

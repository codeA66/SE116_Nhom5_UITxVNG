"""Procedural Blender source for enemy models (cloak enemies + fire map Bone Demon caster).

Run: blender -b -P build_enemy_models.py [-- name ...]
names: shield_bearer, wisp_caster, fire_caster, shadow_wolf; none = build all (old behaviour).
"""

import math
import os
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector


ROOT_DIR = os.path.dirname(os.path.abspath(__file__))


def material(name: str, color: tuple[float, float, float], roughness: float = 0.82,
             emission: tuple[float, float, float] | None = None,
             emission_strength: float = 0.0) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    shader = next(node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Roughness"].default_value = roughness
    if emission is not None:
        if "Emission Color" in shader.inputs:
            shader.inputs["Emission Color"].default_value = (*emission, 1.0)
        elif "Emission" in shader.inputs:
            shader.inputs["Emission"].default_value = (*emission, 1.0)
        shader.inputs["Emission Strength"].default_value = emission_strength
    return mat


def clear_scene(name: str) -> tuple[bpy.types.Scene, bpy.types.Collection]:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in bpy.data.collections:
        if block.name != "Collection" and block.users == 0:
            bpy.data.collections.remove(block)
    scene = bpy.context.scene
    scene.name = name
    collection = bpy.data.collections.new(name.replace("_Studio", ""))
    scene.collection.children.link(collection)
    return scene, collection


def link_object(obj: bpy.types.Object, collection: bpy.types.Collection) -> bpy.types.Object:
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    collection.objects.link(obj)
    return obj


def mesh_object(name: str, vertices: list[tuple[float, float, float]],
                faces: list[tuple[int, ...]], materials: list[bpy.types.Material],
                collection: bpy.types.Collection, parent: bpy.types.Object | None = None,
                assignments: list[int] | None = None) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(vertices, [], faces)
    for mat in materials:
        mesh.materials.append(mat)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = parent
    if assignments is not None:
        for polygon, index in zip(obj.data.polygons, assignments):
            polygon.material_index = index
    for polygon in obj.data.polygons:
        polygon.use_smooth = False
    return obj


def loft(name: str, rings: list[tuple[float, float, float, float, float]], sides: int,
         materials: list[bpy.types.Material], collection: bpy.types.Collection,
         parent: bpy.types.Object, phase: float = 0.0) -> bpy.types.Object:
    vertices: list[tuple[float, float, float]] = []
    for y, radius_x, radius_z, offset_x, offset_z in rings:
        for index in range(sides):
            angle = 2.0 * math.pi * index / sides + phase
            vertices.append((offset_x + radius_x * math.cos(angle), y,
                             offset_z + radius_z * math.sin(angle)))
    faces: list[tuple[int, ...]] = [tuple(range(sides - 1, -1, -1))]
    assignments = [0]
    for row in range(len(rings) - 1):
        for column in range(sides):
            current = row * sides + column
            following = row * sides + (column + 1) % sides
            upper = (row + 1) * sides
            faces.append((current, upper + column, upper + (column + 1) % sides, following))
            assignments.append(column % min(3, len(materials)))
    faces.append(tuple((len(rings) - 1) * sides + index for index in range(sides)))
    assignments.append(0)
    return mesh_object(name, vertices, faces, materials, collection, parent, assignments)


def tapered_sleeve(name: str, start: tuple[float, float, float],
                   end: tuple[float, float, float], radius_start: float,
                   radius_end: float, sides: int, mat: bpy.types.Material,
                   collection: bpy.types.Collection, parent: bpy.types.Object,
                   pivot: bool = False) -> bpy.types.Object:
    start_v = Vector(start)
    end_v = Vector(end)
    node = None
    if pivot:
        node = bpy.data.objects.new(name, None)
        collection.objects.link(node)
        node.parent = parent
        node.location = start_v
        node.empty_display_type = "SPHERE"
        node.empty_display_size = 0.05
        parent = node
        end_v -= start_v
        start_v = Vector((0.0, 0.0, 0.0))
    axis = (end_v - start_v).normalized()
    u = axis.cross(Vector((0.0, 0.0, 1.0)))
    if u.length < 0.01:
        u = axis.cross(Vector((0.0, 1.0, 0.0)))
    u.normalize()
    v = axis.cross(u).normalized()
    vertices: list[tuple[float, float, float]] = []
    for center, radius in ((start_v, radius_start), (end_v, radius_end)):
        for index in range(sides):
            point = center + radius * (math.cos(2.0 * math.pi * index / sides) * u
                                       + math.sin(2.0 * math.pi * index / sides) * v)
            vertices.append(tuple(point))
    faces: list[tuple[int, ...]] = [tuple(range(sides - 1, -1, -1))]
    for index in range(sides):
        faces.append((index, (index + 1) % sides, sides + (index + 1) % sides,
                      sides + index))
    faces.append(tuple(sides + index for index in range(sides)))
    obj = mesh_object(name + ("_Sleeve" if pivot else ""), vertices, faces,
                      [mat], collection, parent, [0] * len(faces))
    return node if node is not None else obj


def ico(name: str, location: tuple[float, float, float], scale: tuple[float, float, float],
        mat: bpy.types.Material, collection: bpy.types.Collection,
        parent: bpy.types.Object, subdivisions: int = 1) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1.0,
                                          location=location)
    obj = link_object(bpy.context.object, collection)
    obj.name = name
    obj.parent = parent
    obj.location = location
    obj.scale = scale
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = False
    return obj


def studio(scene: bpy.types.Scene, collection: bpy.types.Collection,
           root: bpy.types.Object, output_dir: str, glb_name: str, blend_name: str) -> None:
    floor_mat = material("Studio_Grey", (0.27, 0.28, 0.30))
    bpy.ops.mesh.primitive_plane_add(size=200.0, location=(0.0, 0.0, -0.02))
    floor = link_object(bpy.context.object, collection)
    floor.name = "StudioFloor"
    floor.rotation_euler.x = math.radians(90.0)
    floor.data.materials.append(floor_mat)
    floor.hide_select = True

    def area(name: str, position: tuple[float, float, float], energy: float,
             color: tuple[float, float, float], size: float) -> None:
        bpy.ops.object.light_add(type="AREA", location=position)
        light = link_object(bpy.context.object, collection)
        light.name = name
        light.data.energy = energy
        light.data.color = color
        light.data.shape = "DISK"
        light.data.size = size
        direction = (Vector((0.0, 0.9, 0.0)) - light.location).normalized()
        up = (Vector((0.0, 1.0, 0.0)) - direction * direction.dot(Vector((0.0, 1.0, 0.0)))).normalized()
        right = direction.cross(up).normalized()
        light.rotation_euler = Matrix((right, up, -direction)).transposed().to_euler()

    area("Key", (3.0, 5.0, 5.0), 450.0, (1.0, 0.91, 0.82), 4.0)
    area("Fill", (-4.0, 3.0, 2.0), 260.0, (0.72, 0.80, 1.0), 3.0)
    area("Rim", (0.0, 4.0, -3.0), 500.0, (0.58, 0.65, 1.0), 3.0)
    bpy.ops.object.camera_add(location=(3.5, 2.7, 5.0))
    camera = link_object(bpy.context.object, collection)
    camera.name = "StudioCamera"
    direction = (Vector((0.0, 0.95, 0.0)) - camera.location).normalized()
    up = (Vector((0.0, 1.0, 0.0)) - direction * direction.dot(Vector((0.0, 1.0, 0.0)))).normalized()
    right = direction.cross(up).normalized()
    camera.rotation_euler = Matrix((right, up, -direction)).transposed().to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.15
    scene.camera = camera
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 960
    scene.render.resolution_y = 960
    scene.render.resolution_percentage = 100
    scene.world.color = (0.33, 0.33, 0.34)

    def descendants(obj: bpy.types.Object) -> list[bpy.types.Object]:
        found = [obj]
        for child in obj.children:
            found.extend(descendants(child))
        return found

    bpy.ops.object.select_all(action="DESELECT")
    hierarchy = descendants(root)
    for obj in hierarchy:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    try:
        bpy.ops.export_scene.gltf(filepath=os.path.join(output_dir, glb_name),
                                  export_format="GLB", use_selection=True,
                                  export_yup=False,
                                  export_apply=True, export_lights=False,
                                  export_cameras=False)
    except TypeError as error:
        raise RuntimeError(f"Blender glTF export enum/API mismatch: {error}") from error
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(output_dir, "source", blend_name))


def build_shield_bearer() -> None:
    out = os.path.join(ROOT_DIR, "shield_bearer")
    os.makedirs(os.path.join(out, "source"), exist_ok=True)
    scene, collection = clear_scene("ShieldBearer_Studio")
    cloak0 = material("Cloak_Charcoal", (0.055, 0.052, 0.065))
    cloak1 = material("Cloak_Facet", (0.085, 0.080, 0.098))
    cloak2 = material("Cloak_Shadow", (0.035, 0.033, 0.044))
    face_void = material("Hood_Void", (0.012, 0.011, 0.018))
    stone = material("Shrine_Stone", (0.24, 0.245, 0.24))
    stone_edge = material("Shrine_Stone_Edge", (0.34, 0.345, 0.33))
    eyes = material("Spirit_Eyes", (0.31, 0.10, 0.29), 0.35, (0.43, 0.10, 0.36), 1.4)
    root = bpy.data.objects.new("ShieldBearerModel", None)
    collection.objects.link(root)
    root.empty_display_type = "PLAIN_AXES"

    loft("Cloak", [(0.10, 0.44, 0.34, 0, -0.03), (0.22, 0.63, 0.43, 0, -0.02),
                     (0.53, 0.51, 0.37, 0, 0), (0.94, 0.38, 0.29, 0, 0),
                     (1.24, 0.48, 0.31, 0, 0), (1.48, 0.54, 0.31, 0, 0),
                     (1.58, 0.30, 0.24, 0, 0)], 9, [cloak0, cloak1, cloak2],
         collection, root, math.pi / 9)
    tapered_sleeve("Cloak_Fold_L", (-0.14, 1.36, 0.11), (-0.47, 0.16, 0.23),
                   0.105, 0.018, 5, cloak1, collection, root)
    tapered_sleeve("Cloak_Fold_R", (0.10, 1.35, 0.14), (0.43, 0.12, 0.18),
                   0.095, 0.014, 5, cloak2, collection, root)
    tapered_sleeve("Sleeve_L", (-0.39, 1.36, 0.02), (-0.80, 0.95, 0.12),
                   0.20, 0.12, 7, cloak0, collection, root)
    tapered_sleeve("Sleeve_R", (0.39, 1.35, 0.0), (0.72, 0.87, 0.16),
                   0.18, 0.10, 7, cloak1, collection, root)
    loft("Hood", [(1.45, 0.29, 0.24, 0, 0), (1.67, 0.25, 0.23, 0, -0.015),
                   (1.91, 0.01, 0.01, -0.035, -0.05)], 7,
         [cloak0, cloak1, cloak2], collection, root, math.pi / 7)
    mesh_object("Face_Void", [(-0.13, 1.53, 0.215), (0.13, 1.53, 0.215),
                               (0.085, 1.72, 0.205), (0, 1.78, 0.19),
                               (-0.085, 1.72, 0.205)], [(0, 1, 2, 3, 4)],
                [face_void], collection, root)
    ico("Eye_L", (-0.055, 1.64, 0.229), (0.022, 0.014, 0.012), eyes,
        collection, root)
    ico("Eye_R", (0.055, 1.64, 0.229), (0.022, 0.014, 0.012), eyes,
        collection, root)

    shield = bpy.data.objects.new("Shield", None)
    collection.objects.link(shield)
    shield.parent = root
    shield.location = (-0.59, 0.84, 0.34)
    shield.empty_display_type = "CUBE"
    outline = [(-0.36, -0.59), (-0.40, 0.28), (-0.31, 0.45), (-0.22, 0.52),
               (-0.10, 0.47), (0.02, 0.58), (0.15, 0.48), (0.32, 0.43),
               (0.38, -0.59)]
    count = len(outline)
    depth = 0.10
    vertices = ([(x, y, -depth / 2) for x, y in outline]
                + [(x, y, depth / 2) for x, y in outline]
                + [(0, 0, depth / 2), (0, 0, -depth / 2)])
    faces = [(2 * count + 1, *range(count - 1, -1, -1)),
             (2 * count, *range(count, 2 * count))]
    assignments = [0, 0]
    for index in range(count):
        faces.append((index, (index + 1) % count, count + (index + 1) % count,
                      count + index))
        assignments.append(1)
    mesh_object("Shield_Slab", vertices, faces, [stone, stone_edge],
                collection, shield, assignments)
    bpy.ops.mesh.primitive_torus_add(major_segments=12, minor_segments=4)
    ring = link_object(bpy.context.object, collection)
    ring.name = "Door_Ring"
    ring.parent = shield
    ring.location = (0, 0.03, 0.061)
    ring.scale = (0.25, 0.25, 0.06)
    ring.data.materials.append(stone_edge)
    for polygon in ring.data.polygons:
        polygon.use_smooth = False
    studio(scene, collection, root, out, "shield_bearer.glb", "shield_bearer.blend")


def build_wisp_caster() -> None:
    out = os.path.join(ROOT_DIR, "wisp_caster")
    os.makedirs(os.path.join(out, "source"), exist_ok=True)
    scene, collection = clear_scene("WispCaster_Studio")
    robe0 = material("Robe_Deep_Plum", (0.105, 0.081, 0.125))
    robe1 = material("Robe_Facet", (0.15, 0.116, 0.17))
    robe2 = material("Robe_Shadow", (0.072, 0.060, 0.091))
    hood_void = material("Hood_Shadow", (0.032, 0.027, 0.041))
    mask_mat = material("Mask_Worn_Ceramic", (0.44, 0.43, 0.41))
    glow = material("Corrupted_Spirit_Glow", (0.40, 0.12, 0.31), 0.3,
                    (0.57, 0.12, 0.42), 2.0)
    glow_edge = material("Orb_Ring_Glow", (0.26, 0.08, 0.23), 0.4,
                         (0.34, 0.08, 0.30), 0.7)
    root = bpy.data.objects.new("WispCasterModel", None)
    collection.objects.link(root)
    root.empty_display_type = "PLAIN_AXES"

    loft("Robe", [(0.06, 0.15, 0.14, 0, -0.02), (0.17, 0.28, 0.24, 0, 0),
                   (0.48, 0.31, 0.27, 0, 0), (0.78, 0.26, 0.23, 0, 0),
                   (1.00, 0.34, 0.25, 0, 0), (1.10, 0.27, 0.23, 0, 0),
                   (1.20, 0.18, 0.17, 0, 0)], 8,
         [robe0, robe1, robe2], collection, root, math.pi / 8)
    tapered_sleeve("Robe_Tail_L", (-0.12, 0.36, 0.0), (-0.28, 0.02, 0.12),
                   0.075, 0.012, 5, robe1, collection, root)
    tapered_sleeve("Robe_Tail_R", (0.10, 0.32, -0.02), (0.25, 0.04, -0.10),
                   0.07, 0.012, 5, robe2, collection, root)
    tapered_sleeve("Arm_L", (-0.22, 0.97, 0.0), (-0.58, 0.63, 0.12),
                   0.13, 0.07, 6, robe0, collection, root)
    arm = tapered_sleeve("Arm_R", (0.22, 0.97, 0.0), (0.44, 1.02, 0.12),
                         0.13, 0.075, 6, robe1, collection, root, pivot=True)
    loft("Hood", [(1.06, 0.24, 0.21, 0, 0), (1.30, 0.22, 0.20, 0, -0.02),
                   (1.51, 0.008, 0.008, -0.02, -0.045)], 7,
         [robe0, robe1, robe2], collection, root, math.pi / 7)
    # A small mask sits inside the hood opening; its simple face avoids an armored look.
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0)
    mask = link_object(bpy.context.object, collection)
    mask.name = "Mask"
    mask.parent = root
    mask.location = (0, 1.22, 0.185)
    mask.scale = (0.145, 0.20, 0.045)
    mask.data.materials.append(mask_mat)
    for polygon in mask.data.polygons:
        polygon.use_smooth = False
    ico("Eye_L", (-0.052, 1.235, 0.228), (0.023, 0.018, 0.012), glow,
        collection, root)
    ico("Eye_R", (0.052, 1.235, 0.228), (0.023, 0.018, 0.012), glow,
        collection, root)

    orb = ico("Orb", (0.42, 0.12, 0.19), (0.14, 0.14, 0.14), glow,
              collection, arm, 2)
    orb.location = (0.42, 0.12, 0.19)
    bpy.ops.mesh.primitive_torus_add(major_segments=12, minor_segments=4)
    halo = link_object(bpy.context.object, collection)
    halo.name = "Orb_Ring"
    halo.parent = arm
    halo.location = (0.42, 0.12, 0.19)
    halo.rotation_euler = (math.radians(62), math.radians(18), math.radians(-20))
    halo.scale = (0.19, 0.19, 0.05)
    halo.data.materials.append(glow_edge)
    for polygon in halo.data.polygons:
        polygon.use_smooth = False
    # A single tapered smoke wisp gives the orb a spirit-like silhouette without clutter.
    tapered_sleeve("Orb_Wisp", (0.37, 0.20, -0.01), (0.49, 0.36, -0.015),
                   0.035, 0.004, 5, glow_edge, collection, arm)
    studio(scene, collection, root, out, "wisp_caster.glb", "wisp_caster.blend")


def chunk(name: str, center: tuple[float, float, float], size: tuple[float, float, float],
          mat, collection: bpy.types.Collection, parent: bpy.types.Object,
          taper: float = 0.82, sides: int = 6) -> bpy.types.Object:
    """Faceted low-poly block (same language as the cloak enemies): a short tapered prism with
    a bevel ring, flat shaded. size = full width / height / depth. mat: one material, or a list whose
    tones alternate around the sides (facet variation like the cloak enemies)."""
    x, y, z = center
    w, h, d = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
    rings = [(y - h, w * taper, d * taper, x, z), (y - h * 0.55, w, d, x, z),
             (y + h * 0.55, w, d, x, z), (y + h, w * taper, d * taper, x, z)]
    return loft(name, rings, sides, mat if isinstance(mat, list) else [mat], collection, parent, math.pi / sides)


def flame_cone(name: str, base: tuple[float, float, float], height: float, radius: float,
               mat: bpy.types.Material, collection: bpy.types.Collection, parent: bpy.types.Object,
               twist: float = 1.0) -> bpy.types.Object:
    """Low-poly flame: a twisting cone that leans and narrows to a point."""
    x, y, z = base
    rings = []
    for i, (t, r) in enumerate(((0.0, 0.75), (0.22, 1.0), (0.5, 0.7), (0.78, 0.35), (1.0, 0.04))):
        sway = math.sin(i * 1.7) * 0.18 * radius * twist
        rings.append((y + height * t, radius * r, radius * r * 0.85, x + sway, z - 0.25 * radius * t))
    return loft(name, rings, 6, [mat], collection, parent, 0.3 * twist)


# Skulls at least this scale get separate teeth (hero head); smaller ones get one bar per row
DETAILED_SKULL_SCALE = 0.6


def faceted_skull(prefix: str, center: tuple[float, float, float], s: float, bone: bpy.types.Material,
                  dark: bpy.types.Material, eye: bpy.types.Material, collection: bpy.types.Collection,
                  parent: bpy.types.Object) -> None:
    """Oversized faceted skull read as a real skull: rounded cranium bulging back and up, brow ridge over
    big recessed eye sockets, cheekbones, inverted-heart nasal hole, narrow upper jaw with separate teeth,
    narrower mandible with jaw angles and a pointed chin, slightly open. Front = +Z."""
    x, y, z = center
    # Cranium: vault bulges backward and upward, flat sloping forehead
    loft(prefix, [(y - 0.02 * s, 0.20 * s, 0.20 * s, x, z - 0.02 * s),
                  (y + 0.08 * s, 0.26 * s, 0.25 * s, x, z - 0.03 * s),
                  (y + 0.18 * s, 0.25 * s, 0.25 * s, x, z - 0.04 * s),
                  (y + 0.26 * s, 0.18 * s, 0.19 * s, x, z - 0.05 * s),
                  (y + 0.31 * s, 0.08 * s, 0.09 * s, x, z - 0.04 * s)],
         8, [bone], collection, parent, math.pi / 8)
    # Upper face / maxilla: narrower than the cranium, pushed forward
    loft(prefix + "_Face", [(y - 0.14 * s, 0.12 * s, 0.09 * s, x, z + 0.10 * s),
                            (y - 0.02 * s, 0.18 * s, 0.14 * s, x, z + 0.08 * s)],
         6, [bone], collection, parent, math.pi / 6)
    # Brow ridge sticks out over the sockets so they read as recessed holes from above
    chunk(prefix + "_Brow", (x, y + 0.115 * s, z + 0.215 * s), (0.42 * s, 0.05 * s, 0.07 * s), bone,
          collection, parent, 0.85, 4)
    for side, sx in (("L", -1.0), ("R", 1.0)):
        # Big round sockets, set behind the brow / cheek line; eye embers sit inside
        ico(prefix + "_Socket_" + side, (x + sx * 0.095 * s, y + 0.045 * s, z + 0.215 * s),
            (0.08 * s, 0.07 * s, 0.025 * s), dark, collection, parent)
        ico(prefix + "_Eye_" + side, (x + sx * 0.095 * s, y + 0.04 * s, z + 0.226 * s),
            (0.035 * s, 0.03 * s, 0.015 * s), eye, collection, parent)
        # Nasal hole: two dark lobes meeting at the top = inverted heart
        tapered_sleeve(prefix + "_Nose_" + side, (x, y - 0.0 * s, z + 0.235 * s),
                       (x + sx * 0.03 * s, y - 0.07 * s, z + 0.24 * s), 0.015 * s, 0.028 * s, 4, dark,
                       collection, parent)
        if s < DETAILED_SKULL_SCALE:
            continue
        # Cheekbone: from under the socket back toward the ear
        tapered_sleeve(prefix + "_Cheek_" + side, (x + sx * 0.10 * s, y - 0.03 * s, z + 0.20 * s),
                       (x + sx * 0.22 * s, y + 0.0 * s, z + 0.02 * s), 0.04 * s, 0.03 * s, 4, bone,
                       collection, parent)
        # Mandible ramus: vertical branch with the jaw angle behind the cheek
        tapered_sleeve(prefix + "_Jaw_Ramus_" + side, (x + sx * 0.14 * s, y - 0.21 * s, z + 0.03 * s),
                       (x + sx * 0.17 * s, y - 0.06 * s, z - 0.02 * s), 0.035 * s, 0.03 * s, 4, bone,
                       collection, parent)
    # Mandible body: narrower than the skull, pointed chin, hangs slightly open
    loft(prefix + "_Jaw", [(y - 0.25 * s, 0.06 * s, 0.05 * s, x, z + 0.14 * s),
                           (y - 0.19 * s, 0.15 * s, 0.12 * s, x, z + 0.07 * s)],
         6, [bone], collection, parent, math.pi / 6)
    if s < DETAILED_SKULL_SCALE:
        # Small skulls (floating / fireball) are seen tiny: one tooth bar per row keeps the triangle budget
        chunk(prefix + "_Tooth_U", (x, y - 0.135 * s, z + 0.17 * s), (0.22 * s, 0.05 * s, 0.04 * s), bone,
              collection, parent, 0.9, 4)
        chunk(prefix + "_Tooth_D", (x, y - 0.185 * s, z + 0.15 * s), (0.17 * s, 0.05 * s, 0.04 * s), bone,
              collection, parent, 0.9, 4)
        return
    # Separate teeth along the dental arch (upper 5, lower 4)
    for row, count, ty, half in (("U", 5, y - 0.135 * s, 0.10), ("D", 4, y - 0.185 * s, 0.075)):
        for i in range(count):
            t = i / (count - 1) * 2.0 - 1.0
            tz = z + (0.185 - 0.05 * t * t) * s
            chunk("%s_Tooth_%s_%d" % (prefix, row, i), (x + t * half * s, ty, tz),
                  (0.03 * s, 0.05 * s, 0.03 * s), bone, collection, parent, 0.8, 4)


def build_fire_caster() -> None:
    """Fire map caster (Quy Xuong Lua), styled like the other enemies: faceted low-poly, flat
    shading, muted palette (ivory-grey bone, dark iron, dark wine cloth) and one accent (orange
    fire / eyes). Oversized horned skull, rib cage, right hand raises a skull fireball, a small
    flaming skull floats by the left shoulder. Parts are built in model space and skinned rigidly
    by rig_fire_caster (names map to bones through FIRE_CASTER_SKIN_RULES)."""
    out = os.path.join(ROOT_DIR, "..", "fire_caster")
    os.makedirs(os.path.join(out, "source"), exist_ok=True)
    scene, collection = clear_scene("FireCaster_Studio")
    bone = material("FireCaster_Bone", (0.50, 0.46, 0.39), 0.9)
    iron = material("FireCaster_Iron", (0.11, 0.095, 0.09), 0.75)
    cloth = material("FireCaster_Cloth", (0.24, 0.045, 0.05), 0.95)
    glow = material("FireCaster_Fire", (0.95, 0.26, 0.04), 0.4, (1.0, 0.22, 0.03), 1.1)

    root = bpy.data.objects.new("FireCasterModel", None)
    collection.objects.link(root)
    root.empty_display_type = "PLAIN_AXES"

    # Legs
    for side, sx in (("L", -1.0), ("R", 1.0)):
        x = sx * 0.16
        tapered_sleeve("Thigh_" + side, (x, 0.88, 0.0), (x, 0.62, 0.02), 0.087, 0.064, 5, bone, collection, root)
        chunk("Knee_Iron_" + side, (x, 0.60, 0.03), (0.20, 0.12, 0.20), iron, collection, root)
        tapered_sleeve("Shin_" + side, (x, 0.58, 0.02), (x, 0.24, 0.0), 0.073, 0.056, 5, bone, collection, root)
        chunk("Shin_Wrap_" + side, (x, 0.33, 0.0), (0.18, 0.11, 0.18), cloth, collection, root, 0.9)
        chunk("Ankle_Iron_" + side, (x, 0.21, 0.0), (0.16, 0.07, 0.16), iron, collection, root)
        chunk("Foot_" + side, (x, 0.08, 0.04), (0.22, 0.16, 0.32), iron, collection, root, 0.78)
    # Hips + tattered loincloth (pointed flaps)
    chunk("Pelvis", (0.0, 0.90, -0.01), (0.36, 0.12, 0.22), bone, collection, root)
    for side, sx in (("L", -1.0), ("R", 1.0)):
        tapered_sleeve("Pelvis_Wing_" + side, (sx * 0.05, 0.90, -0.05), (sx * 0.24, 1.06, 0.02),
                       0.07, 0.035, 4, bone, collection, root)
    chunk("Belt", (0.0, 0.985, 0.0), (0.42, 0.08, 0.27), iron, collection, root, 0.9, 8)
    tapered_sleeve("Loincloth_Front", (0.0, 0.95, 0.14), (0.03, 0.60, 0.16), 0.12, 0.02, 4, cloth, collection, root)
    tapered_sleeve("Loincloth_Back", (0.0, 0.95, -0.13), (-0.03, 0.63, -0.15), 0.13, 0.02, 4, cloth, collection, root)
    tapered_sleeve("Loincloth_Side_L", (-0.19, 0.95, 0.0), (-0.22, 0.72, 0.01), 0.06, 0.01, 4, cloth, collection, root)
    tapered_sleeve("Loincloth_Side_R", (0.19, 0.95, 0.0), (0.21, 0.70, 0.02), 0.06, 0.01, 4, cloth, collection, root)
    # Spine, rib cage, ember heart
    tapered_sleeve("Spine", (0.0, 0.98, -0.07), (0.0, 1.47, -0.05), 0.05, 0.04, 5, bone, collection, root)
    ico("Core_Ember", (0.0, 1.18, -0.01), (0.075, 0.12, 0.06), glow, collection, root)
    for i in range(4):
        y = 1.10 + i * 0.09
        w = 0.17 + 0.03 * min(i, 2)
        for side, sx in (("L", -1.0), ("R", 1.0)):
            tapered_sleeve("Rib_%d_%s_Back" % (i, side), (sx * 0.03, y, -0.06), (sx * w, y - 0.02, 0.02),
                           0.024, 0.022, 4, bone, collection, root)
            tapered_sleeve("Rib_%d_%s_Front" % (i, side), (sx * w, y - 0.02, 0.02), (sx * 0.05, y - 0.06, 0.12),
                           0.022, 0.018, 4, bone, collection, root)
    chunk("Sternum", (0.0, 1.23, 0.125), (0.06, 0.28, 0.04), bone, collection, root, 0.8, 4)
    chunk("Collar", (0.0, 1.47, 0.0), (0.34, 0.06, 0.20), iron, collection, root, 0.9, 8)
    # Iron pauldrons with a spike
    for side, sx in (("L", -1.0), ("R", 1.0)):
        x = sx * 0.27
        loft("Pauldron_" + side, [(1.37, 0.15, 0.15, x, 0.0), (1.46, 0.14, 0.14, x, 0.0),
                                  (1.52, 0.07, 0.08, x, 0.0)], 6, [iron], collection, root, math.pi / 6)
        tapered_sleeve("Pauldron_Spike_" + side, (sx * 0.33, 1.50, -0.02), (sx * 0.41, 1.63, -0.05),
                       0.04, 0.004, 4, iron, collection, root)
    tapered_sleeve("Neck", (0.0, 1.46, 0.0), (0.0, 1.60, 0.0), 0.05, 0.045, 5, bone, collection, root)
    # Left arm hangs, heavy iron fist
    tapered_sleeve("Arm_L_Upper", (-0.32, 1.38, 0.0), (-0.33, 1.12, 0.0), 0.067, 0.056, 5, bone, collection, root)
    chunk("Arm_L_Bracer", (-0.33, 1.04, 0.0), (0.13, 0.16, 0.13), iron, collection, root)
    chunk("Arm_L_Wrap", (-0.33, 0.95, 0.0), (0.12, 0.05, 0.12), cloth, collection, root, 0.95)
    chunk("Arm_L_Fist", (-0.33, 0.85, 0.02), (0.22, 0.20, 0.22), iron, collection, root, 0.8)
    # Left fist burns too (both hands aflame)
    for i, fx in enumerate((-0.06, 0.0, 0.06)):
        tapered_sleeve("Arm_L_Claw_%d" % i, (-0.33 + fx, 0.77, 0.08), (-0.33 + fx * 1.3, 0.68, 0.16),
                       0.026, 0.003, 4, bone, collection, root)
    flame_cone("Arm_L_Flame", (-0.33, 0.84, 0.03), 0.22, 0.085, glow, collection, root)
    # Right arm (rest pose = combat stance): upper arm down and out, forearm forward, fireball held
    # in front of the chest. Joints match FIRE_CASTER_BONES (UpperArm_R / Forearm_R / Hand_R / Orb)
    elbow = (0.46, 1.13, -0.02)
    hand = (0.44, 1.07, 0.22)
    tapered_sleeve("Arm_R_Upper", (0.32, 1.38, 0.0), elbow, 0.067, 0.059, 5, bone, collection, root)
    ico("Arm_R_Elbow", elbow, (0.075, 0.075, 0.075), bone, collection, root)
    tapered_sleeve("Arm_R_Fore", elbow, hand, 0.059, 0.05, 5, bone, collection, root)
    chunk("Arm_R_Bracer", (0.45, 1.10, 0.09), (0.13, 0.13, 0.15), iron, collection, root)
    chunk("Arm_R_Wrap", (0.44, 1.075, 0.18), (0.12, 0.11, 0.04), cloth, collection, root, 0.95)
    # Hand is a hero part (it throws): palm + three long clawed fingers cupping the fireball
    chunk("Finger_Palm", (hand[0], hand[1] + 0.01, hand[2] + 0.02), (0.15, 0.06, 0.13), bone, collection, root, 0.85)
    for i, fx in enumerate((-0.05, 0.0, 0.05)):
        tip = (hand[0] + fx * 1.6, hand[1] + 0.13, hand[2] + 0.05)
        tapered_sleeve("Finger_%d" % i, (hand[0] + fx, hand[1] + 0.02, hand[2] + 0.03), tip,
                       0.026, 0.017, 4, bone, collection, root)
        tapered_sleeve("Finger_Claw_%d" % i, tip, (tip[0] + fx * 0.3, tip[1] + 0.06, tip[2] + 0.04),
                       0.017, 0.002, 4, iron, collection, root)
    # Fireball (separate mesh on the Orb bone): small glowing skull wrapped in a flame
    orb = (0.44, 1.22, 0.25)
    faceted_skull("OrbSkull", orb, 0.42, glow, iron, glow, collection, root)
    flame_cone("OrbFlame", (orb[0], orb[1] - 0.02, orb[2] - 0.03), 0.30, 0.11, glow, collection, root, -1.0)
    for i, (dx, dy, dz) in enumerate(((0.15, 0.04, 0.02), (-0.14, -0.03, 0.05), (0.04, -0.14, -0.05), (-0.05, 0.15, 0.08))):
        ico("Orb_Debris_%d" % i, (orb[0] + dx, orb[1] + dy, orb[2] + dz), (0.03, 0.025, 0.03), iron, collection, root)
    # Head: oversized horned skull with a flame crown
    faceted_skull("Skull", (0.0, 1.78, 0.0), 1.0, bone, iron, glow, collection, root)
    for side, sx in (("L", -1.0), ("R", 1.0)):
        tapered_sleeve("Horn_" + side, (sx * 0.15, 1.95, -0.03), (sx * 0.24, 2.11, -0.08), 0.05, 0.005, 5,
                       iron, collection, root)
    flame_cone("HeadFlame", (0.0, 1.97, -0.04), 0.40, 0.15, glow, collection, root)
    flame_cone("HeadFlame_Side", (0.07, 1.98, 0.02), 0.22, 0.07, glow, collection, root, -1.0)
    # Small flaming skull floating near the left shoulder
    small = (-0.52, 1.62, 0.05)
    faceted_skull("FloatSkull", small, 0.42, bone, iron, glow, collection, root)
    flame_cone("FloatFlame", (small[0], small[1] + 0.07, small[2] - 0.02), 0.18, 0.06, glow, collection, root)

    rig_fire_caster(scene, collection, root)
    studio(scene, collection, root, out, "fire_caster.glb", "fire_caster.blend")


# ---------- Fire caster rig ----------
# Rigid voxel rig: every block follows exactly one bone (weight 1), so blocks never bend.
# All bones point along +Y (model up) with roll 0, so every bone's local axes equal the model axes:
# X = right, Y = up, Z = front. Rotation X pitches forward (+) / back (-), Z tilts sideways.
# (name, parent, joint position in model space)
FIRE_CASTER_BONES = [
    ("Root", None, (0.0, 0.0, 0.0)),
    ("Hips", "Root", (0.0, 0.92, 0.0)),
    ("Loincloth", "Hips", (0.0, 0.95, 0.0)),
    ("Spine", "Hips", (0.0, 1.0, -0.03)),
    ("Chest", "Spine", (0.0, 1.28, 0.0)),
    ("Neck", "Chest", (0.0, 1.48, 0.0)),
    ("Head", "Neck", (0.0, 1.56, 0.0)),
    ("FloatSkull", "Chest", (-0.52, 1.62, 0.05)),
    ("Shoulder_L", "Chest", (-0.22, 1.42, 0.0)),
    ("UpperArm_L", "Shoulder_L", (-0.32, 1.38, 0.0)),
    ("Forearm_L", "UpperArm_L", (-0.33, 1.13, 0.0)),
    ("Hand_L", "Forearm_L", (-0.33, 0.95, 0.0)),
    ("Shoulder_R", "Chest", (0.22, 1.42, 0.0)),
    ("UpperArm_R", "Shoulder_R", (0.32, 1.38, 0.0)),
    ("Forearm_R", "UpperArm_R", (0.46, 1.13, -0.02)),
    ("Hand_R", "Forearm_R", (0.44, 1.07, 0.22)),
    ("Orb", "Hand_R", (0.44, 1.22, 0.25)),
    ("Thigh_L", "Hips", (-0.16, 0.86, 0.0)),
    ("Shin_L", "Thigh_L", (-0.16, 0.60, 0.0)),
    ("Foot_L", "Shin_L", (-0.16, 0.16, 0.0)),
    ("Thigh_R", "Hips", (0.16, 0.86, 0.0)),
    ("Shin_R", "Thigh_R", (0.16, 0.60, 0.0)),
    ("Foot_R", "Shin_R", (0.16, 0.16, 0.0)),
]
# Object name prefix -> bone (first match wins; side suffix _L / _R handled by the rules)
FIRE_CASTER_SKIN_RULES = [
    ("Foot_", "Foot_{s}"), ("Ankle_Iron_", "Shin_{s}"), ("Shin_", "Shin_{s}"), ("Knee_", "Shin_{s}"),
    ("Thigh_", "Thigh_{s}"), ("Pelvis", "Hips"), ("Belt", "Hips"), ("Loincloth", "Loincloth"),
    ("Spine", "Spine"), ("Core_Ember", "Spine"), ("Rib_", "Spine"), ("Sternum", "Chest"),
    ("Collar", "Chest"), ("Pauldron", "Shoulder_{s}"), ("Neck", "Neck"),
    ("Arm_L_Upper", "UpperArm_L"), ("Arm_L_Bracer", "Forearm_L"), ("Arm_L_Wrap", "Forearm_L"),
    ("Arm_L_Fist", "Hand_L"), ("Arm_L_Claw", "Hand_L"), ("Arm_L_Flame", "Hand_L"), ("Arm_R_Upper", "UpperArm_R"), ("Arm_R_Elbow", "UpperArm_R"),
    ("Arm_R_Fore", "Forearm_R"), ("Arm_R_Bracer", "Forearm_R"), ("Arm_R_Wrap", "Forearm_R"),
    ("Finger_", "Hand_R"), ("Skull", "Head"), ("Horn_", "Head"), ("HeadFlame", "Head"),
    ("FloatSkull", "FloatSkull"), ("FloatFlame", "FloatSkull"),
]
# Fireball parts stay a separate (non-skinned) mesh on the Orb bone: Godot scales it while charging
FIRE_CASTER_ORB_PREFIXES = ("OrbSkull", "OrbFlame", "Orb_Debris")


def _bone_for(name: str, rules: list) -> str:
    """Bone for a block by name prefix (first match wins); "{s}" in the bone name becomes the block side L / R."""
    side = "L" if "_L" in name else "R"
    for prefix, bone_name in rules:
        if name.startswith(prefix):
            return bone_name.format(s=side)
    raise RuntimeError("No bone rule for block " + name)


def _all_children(obj: bpy.types.Object) -> list[bpy.types.Object]:
    found = []
    for child in obj.children:
        found.append(child)
        found.extend(_all_children(child))
    return found


def _join(objects: list[bpy.types.Object], name: str) -> bpy.types.Object:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.name = name
    return joined


def _bake_transform(obj: bpy.types.Object) -> bpy.types.Object:
    """Unparent (keeping the world transform), then apply location / rotation / scale into the mesh."""
    world = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = world
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def _make_armature(collection: bpy.types.Collection, root: bpy.types.Object, data_name: str,
                   bones: list) -> bpy.types.Object:
    """Armature "Rig" under root. Every bone points along +Y with roll 0, so its local axes equal the
    model axes (X right, Y up, Z front). bones: (name, parent, joint position in model space)."""
    bpy.context.view_layer.update()
    arm_data = bpy.data.armatures.new(data_name)
    rig = bpy.data.objects.new("Rig", arm_data)
    collection.objects.link(rig)
    rig.parent = root
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    edit_bones = {}
    for name, parent, head in bones:
        eb = arm_data.edit_bones.new(name)
        eb.head = head
        eb.tail = (head[0], head[1] + 0.08, head[2])
        eb.roll = 0.0
        if parent:
            eb.parent = edit_bones[parent]
            eb.use_connect = False
        edit_bones[name] = eb
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def _skin_rigid(rig: bpy.types.Object, parts: list, rules: list, body_name: str) -> bpy.types.Object:
    """Rigid skin: each block follows one bone with weight 1 (blocks never bend), joined into one mesh.
    glTF ignores the node transform of a skinned mesh, so every transform is baked into the vertices."""
    for obj in parts:
        group = obj.vertex_groups.new(name=_bone_for(obj.name, rules))
        group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    body = _bake_transform(_join(parts, body_name))
    body.parent = rig
    modifier = body.modifiers.new("Armature", "ARMATURE")
    modifier.object = rig
    return body


def _remove_empties(root: bpy.types.Object) -> None:
    for obj in _all_children(root):
        if obj.type == "EMPTY":
            bpy.data.objects.remove(obj, do_unlink=True)


def rig_fire_caster(scene: bpy.types.Scene, collection: bpy.types.Collection, root: bpy.types.Object) -> None:
    rig = _make_armature(collection, root, "FireCasterRig", FIRE_CASTER_BONES)
    meshes = [obj for obj in _all_children(root) if obj.type == "MESH"]
    orb_parts = [obj for obj in meshes if obj.name.startswith(FIRE_CASTER_ORB_PREFIXES)]
    _skin_rigid(rig, [obj for obj in meshes if obj not in orb_parts], FIRE_CASTER_SKIN_RULES, "FireCasterBody")
    # Fireball: separate mesh, origin moved to the Orb joint so Godot scales it in place while charging
    orb = _bake_transform(_join(orb_parts, "OrbMesh"))
    joint = Vector(dict((b[0], b[2]) for b in FIRE_CASTER_BONES)["Orb"])
    orb.data.transform(Matrix.Translation(-joint))
    orb.parent = rig
    orb.parent_type = "BONE"
    orb.parent_bone = "Orb"
    orb.matrix_world = Matrix.Translation(joint)
    _remove_empties(root)
    _fire_caster_actions(scene, rig)


def _key(rig: bpy.types.Object, frame: int, poses: dict) -> None:
    """poses: bone -> (rotation_euler xyz, location xyz or None[, scale xyz]). Unlisted bones key to rest.
    Scale is keyed only on rigs flagged rig["key_scale"] (squash & stretch), so older rigs export unchanged."""
    key_scale = bool(rig.get("key_scale", False))
    for pose_bone in rig.pose.bones:
        entry = poses.get(pose_bone.name, ((0.0, 0.0, 0.0), None))
        rot, loc = entry[0], entry[1]
        pose_bone.rotation_mode = "XYZ"
        pose_bone.rotation_euler = rot
        pose_bone.location = loc if loc is not None else (0.0, 0.0, 0.0)
        pose_bone.keyframe_insert("rotation_euler", frame=frame)
        pose_bone.keyframe_insert("location", frame=frame)
        if key_scale:
            pose_bone.scale = entry[2] if len(entry) > 2 else (1.0, 1.0, 1.0)
            pose_bone.keyframe_insert("scale", frame=frame)


def _action(rig: bpy.types.Object, name: str, keys: list) -> None:
    """keys: list of (seconds, poses). Each clip is its own action (glTF exports one animation per action)."""
    fps = bpy.context.scene.render.fps
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = action
    for seconds, poses in keys:
        _key(rig, int(round(seconds * fps)), poses)
    rig.animation_data.action = None


def _pose(base: dict, **over) -> dict:
    """Copy of a pose dict with some bones replaced (keyword = bone name)."""
    result = dict(base)
    result.update(over)
    return result


def _fire_caster_actions(scene: bpy.types.Scene, rig: bpy.types.Object) -> None:
    """Clips for the fire caster. Axis notes (bones have identity rest frames, model axes):
    rotating a bone that hangs down by -X swings it forward, +X swings it back; for the left arm -Z
    swings it outward, for the right arm +Z; rotating Chest / Hips by +Y turns the right shoulder back."""
    scene.render.fps = 30
    r = math.radians
    # Combat stance (Idle base): wide knees-bent stance, chest forward, elbows out, flaming fists low
    stance = {
        "Hips": ((0, 0, 0), (0.0, -0.03, 0.0)),
        "Thigh_L": ((r(-8), 0, r(-9)), None), "Thigh_R": ((r(-8), 0, r(9)), None),
        "Shin_L": ((r(14), 0, r(4)), None), "Shin_R": ((r(14), 0, r(-4)), None),
        "Foot_L": ((r(-6), 0, r(5)), None), "Foot_R": ((r(-6), 0, r(-5)), None),
        "Chest": ((r(7), 0, 0), None), "Head": ((r(-7), 0, 0), None),
        "UpperArm_L": ((r(-10), 0, r(-35)), None), "Forearm_L": ((r(-70), 0, r(20)), None),
        "UpperArm_R": ((r(-5), 0, r(10)), None),
    }
    breathe = _pose(stance,
                    Chest=((r(10), 0, 0), (0.0, 0.015, 0.0)), Head=((r(-9), 0, r(2)), None),
                    Shoulder_L=((0, 0, 0), (0.0, 0.015, 0.0)), Shoulder_R=((0, 0, 0), (0.0, 0.015, 0.0)),
                    Forearm_L=((r(-76), 0, r(20)), None), UpperArm_R=((r(-9), 0, r(12)), None),
                    FloatSkull=((0, r(20), 0), (0.0, 0.10, -0.04)), Loincloth=((r(6), 0, 0), None))
    _action(rig, "Idle", [(0.0, stance), (0.6, breathe), (1.2, stance)])

    # Walk: torso leans well forward, long strides, both arms trail back like dragging flames
    lean = {
        "Spine": ((r(12), 0, 0), None), "Chest": ((r(8), 0, 0), None), "Head": ((r(-14), 0, 0), None),
        "UpperArm_L": ((r(35), 0, r(-20)), None), "Forearm_L": ((r(-15), 0, 0), None),
        "UpperArm_R": ((r(30), 0, r(18)), None), "Forearm_R": ((r(40), 0, 0), None),
        "Loincloth": ((r(-10), 0, 0), None),
    }
    stride = r(32)
    step_a = _pose(lean, Thigh_L=((-stride, 0, 0), None), Thigh_R=((stride * 0.8, 0, 0), None),
                   Shin_R=((r(30), 0, 0), None), Hips=((0, r(-6), 0), (0.0, -0.02, 0.0)),
                   Chest=((r(8), r(8), 0), None))
    pass_a = _pose(lean, Shin_L=((r(40), 0, 0), None), Hips=((0, 0, 0), (0.0, 0.035, 0.0)),
                   FloatSkull=((0, 0, 0), (0.0, 0.05, 0.0)))
    step_b = _pose(lean, Thigh_L=((stride * 0.8, 0, 0), None), Thigh_R=((-stride, 0, 0), None),
                   Shin_L=((r(30), 0, 0), None), Hips=((0, r(6), 0), (0.0, -0.02, 0.0)),
                   Chest=((r(8), r(-8), 0), None))
    pass_b = _pose(lean, Shin_R=((r(40), 0, 0), None), Hips=((0, 0, 0), (0.0, 0.035, 0.0)),
                   FloatSkull=((0, 0, 0), (0.0, 0.05, 0.0)))
    _action(rig, "Walk", [(0.0, step_a), (0.15, pass_a), (0.3, step_b), (0.45, pass_b), (0.6, step_a)])

    # Cast: overhand throw. Wind up = fireball pulled back behind the head, shoulders twisted,
    # left arm reaching forward, left foot forward; release exactly at 0.8 s (attack.active_start)
    wind_up = _pose(stance,
                    # Upper arm swung 140° back (elbow above the shoulder); forearm +130° then points straight up,
                    # holding the fireball high behind the head (forearm angle = -90° - upper arm angle)
                    UpperArm_R=((r(140), 0, r(22)), None), Forearm_R=((r(130), 0, 0), None),
                    Chest=((r(-4), r(30), 0), None), Spine=((r(-6), 0, 0), None), Head=((r(-4), r(-20), 0), None),
                    UpperArm_L=((r(-65), 0, r(-15)), None), Forearm_L=((r(-25), 0, 0), None),
                    Thigh_L=((r(-25), 0, r(-6)), None), Shin_L=((r(18), 0, 0), None),
                    Thigh_R=((r(10), 0, r(8)), None), Hips=((0, r(12), 0), (0.0, -0.04, 0.0)))
    release = _pose(stance,
                    # Arm thrown straight forward; extra lift compensates the torso leaning into the throw
                    UpperArm_R=((r(-108), 0, r(4)), None), Forearm_R=((r(80), 0, 0), None),
                    Chest=((r(10), r(-25), 0), None), Spine=((r(14), 0, 0), None), Head=((r(-14), r(12), 0), None),
                    UpperArm_L=((r(30), 0, r(-25)), None), Forearm_L=((r(-40), 0, 0), None),
                    Thigh_L=((r(-32), 0, r(-6)), None), Shin_L=((r(10), 0, 0), None),
                    Thigh_R=((r(18), 0, r(8)), None), Shin_R=((r(20), 0, 0), None),
                    Hips=((0, r(-12), 0), (0.0, -0.06, 0.06)))
    follow = _pose(release, UpperArm_R=((r(-90), 0, r(-12)), None), Chest=((r(14), r(-32), 0), None),
                   Spine=((r(18), 0, 0), None))
    _action(rig, "Cast", [(0.0, stance), (0.5, wind_up), (0.72, wind_up), (0.8, release), (0.95, follow),
                          (1.3, stance)])

    _action(rig, "Hurt", [
        (0.0, stance),
        (0.06, _pose(stance, Chest=((r(-18), 0, r(6)), None), Head=((r(-20), 0, 0), None),
                     Hips=((0, 0, 0), (0.0, 0.0, -0.06)))),
        (0.22, stance),
    ])
    _action(rig, "Death", [
        (0.0, stance),
        (0.25, {"Thigh_L": ((r(-50), 0, 0), None), "Thigh_R": ((r(-50), 0, 0), None),
                "Shin_L": ((r(70), 0, 0), None), "Shin_R": ((r(70), 0, 0), None),
                "Hips": ((0, 0, 0), (0.0, -0.30, 0.0)), "Head": ((r(15), 0, r(10)), None)}),
        (0.55, {"Root": ((r(85), 0, 0), (0.0, 0.0, 0.0)), "Thigh_L": ((r(-30), 0, 0), None),
                "Thigh_R": ((r(-20), 0, 0), None), "Head": ((r(20), 0, r(40)), None),
                "UpperArm_L": ((r(-60), 0, 0), None), "UpperArm_R": ((r(-40), 0, 0), None),
                "FloatSkull": ((0, 0, r(60)), (0.0, -1.2, 0.3))}),
        (0.7, {"Root": ((r(90), 0, 0), (0.0, 0.0, 0.0)), "Thigh_L": ((r(-30), 0, 0), None),
               "Thigh_R": ((r(-20), 0, 0), None), "Head": ((r(20), 0, r(45)), None),
               "UpperArm_L": ((r(-60), 0, 0), None), "UpperArm_R": ((r(-40), 0, 0), None),
               "FloatSkull": ((0, 0, r(60)), (0.0, -1.3, 0.3))}),
    ])


# ---------- Shadow wolf ----------
# Quadruped rigid rig, same axis rules as the fire caster (bone frames = model axes, front = +Z).
# A bone pointing forward (+Z: neck, head, jaw) pitches DOWN with +X; a leg hanging down swings BACK with +X.
# Lean hunting wolf: deep chest, tucked waist, hips a bit lower than the shoulders, long legs with a clear
# elbow and a Z-shaped hind leg (knee forward, hock back). The BackPaw bone sits at the hock so the
# metatarsus + paw move together.
SHADOW_WOLF_BONES = [
    ("Root", None, (0.0, 0.0, 0.0)),
    ("Hips", "Root", (0.0, 0.84, -0.42)),
    ("Tail", "Hips", (0.0, 0.88, -0.60)),
    ("Tail2", "Tail", (0.0, 0.78, -0.80)),
    ("Tail3", "Tail2", (0.0, 0.70, -0.98)),
    ("Tail4", "Tail3", (0.0, 0.73, -1.14)),
    ("Mane_B", "Hips", (0.0, 0.98, -0.30)),
    ("Spine", "Hips", (0.0, 0.86, -0.10)),
    ("Mane_M", "Spine", (0.0, 1.00, 0.08)),
    ("Spine2", "Spine", (0.0, 0.86, 0.08)),
    ("Chest", "Spine2", (0.0, 0.84, 0.28)),
    ("Mane_F", "Chest", (0.0, 1.00, 0.42)),
    ("Neck", "Chest", (0.0, 0.90, 0.42)),
    ("Head", "Neck", (0.0, 0.98, 0.68)),
    ("Jaw", "Head", (0.0, 0.88, 0.80)),
    ("FrontUpper_L", "Chest", (0.19, 0.84, 0.34)),
    ("FrontLower_L", "FrontUpper_L", (0.21, 0.48, 0.28)),
    ("FrontPaw_L", "FrontLower_L", (0.21, 0.20, 0.31)),
    ("FrontUpper_R", "Chest", (-0.19, 0.84, 0.34)),
    ("FrontLower_R", "FrontUpper_R", (-0.21, 0.48, 0.28)),
    ("FrontPaw_R", "FrontLower_R", (-0.21, 0.20, 0.31)),
    ("BackUpper_L", "Hips", (0.19, 0.84, -0.42)),
    ("BackLower_L", "BackUpper_L", (0.21, 0.52, -0.26)),
    ("BackPaw_L", "BackLower_L", (0.21, 0.26, -0.54)),
    ("BackUpper_R", "Hips", (-0.19, 0.84, -0.42)),
    ("BackLower_R", "BackUpper_R", (-0.21, 0.52, -0.26)),
    ("BackPaw_R", "BackLower_R", (-0.21, 0.26, -0.54)),
]
SHADOW_WOLF_SKIN_RULES = [
    ("FrontUpper_", "FrontUpper_{s}"), ("FrontLower_", "FrontLower_{s}"), ("FrontPaw_", "FrontPaw_{s}"),
    ("FrontClaw_", "FrontPaw_{s}"), ("BackUpper_", "BackUpper_{s}"), ("BackLower_", "BackLower_{s}"),
    ("BackPaw_", "BackPaw_{s}"), ("BackClaw_", "BackPaw_{s}"),
    ("Jaw", "Jaw"), ("Head", "Head"), ("Snout", "Head"), ("Ear_", "Head"), ("Eye_", "Head"),
    ("Nose", "Head"), ("Tooth", "Head"), ("Neck", "Neck"), ("ChestBulk", "Chest"),
    ("Mane_F", "Mane_F"), ("Mane_M", "Mane_M"), ("Mane_B", "Mane_B"), ("Torso_Front", "Spine2"), ("Torso", "Spine"),
    ("Haunch", "Hips"), ("Tail4", "Tail4"), ("Tail3", "Tail3"), ("Tail2", "Tail2"), ("Tail", "Tail"),
]
# Mane tufts from the nape over the shoulders: (z, top y of the neck/withers there, tuft length)
SHADOW_WOLF_MANE = [(0.62, 1.04, 0.16), (0.54, 1.01, 0.20), (0.46, 0.99, 0.22), (0.38, 0.97, 0.19),
                    (0.30, 0.96, 0.15)]
# Low back spikes fading toward the tail: (z, base y, height)
SHADOW_WOLF_SPINES = [(0.14, 0.97, 0.10), (0.02, 0.95, 0.08), (-0.12, 0.94, 0.07), (-0.26, 0.93, 0.06),
                      (-0.40, 0.92, 0.05)]


def build_shadow_wolf() -> None:
    """Shadow wolf (Soi Bong Dem), faceted low-poly like the other enemies, three alternating dark fur
    tones, glowing white eyes / fangs / claws. Lean hunter silhouette: wedge skull with long tapering
    snout, big swept-back ears, brow ridge over slanted eyes, separate jaw with two long upper and two
    short lower canines; mane of pointed tufts flaring from the nape over the shoulders; bushy two-part
    tail curling up; three curved claws per paw. Rigid rig + clips for the stalk / pounce / bite AI."""
    out = os.path.join(ROOT_DIR, "..", "shadow_wolf")
    os.makedirs(os.path.join(out, "source"), exist_ok=True)
    scene, collection = clear_scene("ShadowWolf_Studio")
    fur = [material("ShadowWolf_Fur_A", (0.030, 0.030, 0.036), 1.0),
           material("ShadowWolf_Fur_B", (0.052, 0.050, 0.060), 1.0),
           material("ShadowWolf_Fur_C", (0.018, 0.018, 0.022), 1.0)]
    glow = material("ShadowWolf_Glow", (1.0, 1.0, 1.0), 0.3, (1.0, 1.0, 1.0), 2.5)
    tone = iter([fur[i % 3] for i in range(400)])
    root = bpy.data.objects.new("ShadowWolfModel", None)
    collection.objects.link(root)
    root.empty_display_type = "PLAIN_AXES"

    def sleeve(name, a, b, r0, r1, sides=5, mat=None):
        tapered_sleeve(name, a, b, r0, r1, sides, mat or next(tone), collection, root)

    # Body: deep chest, waist tucked up, compact haunches slightly lower than the withers
    chunk("ChestBulk", (0.0, 0.78, 0.26), (0.40, 0.42, 0.44), fur, collection, root, 0.78, 6)
    sleeve("Torso_Front", (0.0, 0.84, 0.16), (0.0, 0.85, -0.08), 0.20, 0.17, 6)
    sleeve("Torso", (0.0, 0.85, -0.08), (0.0, 0.84, -0.36), 0.17, 0.14, 6)
    # Belly is hidden from the top-down camera: fewer sides, triangles go to the head / shoulders / hips
    sleeve("Torso_Belly", (0.0, 0.66, 0.20), (0.0, 0.76, -0.24), 0.10, 0.05, 4)
    # Haunch peaks above the spine line (wolf hindquarters), not sunk below it
    chunk("Haunch", (0.0, 0.87, -0.42), (0.34, 0.30, 0.30), fur, collection, root, 0.8, 6)
    # Neck rises forward, head carried level with the withers
    sleeve("Neck", (0.0, 0.86, 0.38), (0.0, 0.97, 0.66), 0.15, 0.115, 6)
    # Head: wedge skull, long snout tapering to the nose, brow ridge over slanted eyes
    chunk("Head", (0.0, 1.00, 0.72), (0.28, 0.20, 0.24), fur, collection, root, 0.75, 6)
    sleeve("Snout", (0.0, 0.98, 0.80), (0.0, 0.93, 1.08), 0.085, 0.04, 4)
    ico("Nose", (0.0, 0.935, 1.09), (0.035, 0.03, 0.025), fur[2], collection, root)
    sleeve("Jaw", (0.0, 0.88, 0.80), (0.0, 0.875, 1.03), 0.06, 0.03, 4)
    for side, sx in (("L", 1.0), ("R", -1.0)):
        # Big ears swept back and outward
        sleeve("Ear_" + side, (sx * 0.08, 1.07, 0.70), (sx * 0.14, 1.24, 0.58), 0.06, 0.004, 4)
        ico("Eye_" + side, (sx * 0.075, 1.02, 0.84), (0.035, 0.016, 0.022), glow, collection, root)
        sleeve("Head_Brow_" + side, (sx * 0.035, 1.045, 0.87), (sx * 0.12, 1.06, 0.80), 0.022, 0.012, 4)
        # Upper jaw: one long canine + small serrated row behind it
        sleeve("Tooth_%s_C" % side, (sx * 0.045, 0.93, 1.00), (sx * 0.05, 0.83, 1.02), 0.017, 0.002, 4, glow)
        for i, z in enumerate((0.95, 0.91, 0.87, 0.83)):
            sleeve("Tooth_%s_%d" % (side, i), (sx * 0.055, 0.925, z), (sx * 0.055, 0.895, z + 0.01),
                   0.011, 0.002, 4, glow)
        # Lower jaw: one short canine pointing up
        sleeve("Jaw_Tooth_" + side, (sx * 0.035, 0.885, 0.99), (sx * 0.04, 0.94, 0.98), 0.013, 0.002, 4, glow)
    # Mane: pointed tufts from the nape over the shoulders, the outer ones flaring sideways
    for i, (z, top, length) in enumerate(SHADOW_WOLF_MANE):
        for k, sx in enumerate((-1.0, 0.0, 1.0)):
            spread = 0.11 if sx else 0.0
            sleeve("Mane_F_%d_%d" % (i, k), (sx * 0.06, top - 0.04 - abs(sx) * 0.03, z),
                   (sx * (0.06 + spread + length * 0.4), top + length * (0.55 if sx else 0.8), z - length * 0.7),
                   0.055, 0.004, 4)
    # Low back spikes fading toward the tail
    for i, (z, base_y, height) in enumerate(SHADOW_WOLF_SPINES):
        part = "Mane_M" if z > -0.2 else "Mane_B"
        sleeve("%s_%d" % (part, i), (0.0, base_y, z), (0.0, base_y + height, z - 0.08), 0.045, 0.003, 4)
    # Tail: bushy, thick in the middle, droops then curls up to a point
    sleeve("Tail", (0.0, 0.88, -0.58), (0.0, 0.78, -0.80), 0.06, 0.09, 5)
    sleeve("Tail2", (0.0, 0.78, -0.80), (0.0, 0.70, -0.98), 0.09, 0.11, 6)
    sleeve("Tail3", (0.0, 0.70, -0.98), (0.0, 0.73, -1.14), 0.11, 0.07, 6)
    sleeve("Tail4", (0.0, 0.73, -1.14), (0.0, 0.88, -1.24), 0.07, 0.006, 5)
    # Legs: long, elbow back on the front legs; Z-shaped hind legs (thick thigh, knee forward, hock back)
    for side, sx in (("L", 1.0), ("R", -1.0)):
        x = sx * 0.21
        sleeve("FrontUpper_" + side, (sx * 0.19, 0.88, 0.34), (x, 0.48, 0.28), 0.10, 0.06)
        # Forearm down to the low wrist (the "front knee" of a canine), then a short pastern slanting forward
        sleeve("FrontLower_" + side, (x, 0.48, 0.28), (x, 0.20, 0.31), 0.055, 0.045, 4)
        sleeve("FrontPaw_Wrist_" + side, (x, 0.20, 0.31), (x, 0.08, 0.38), 0.045, 0.04, 4)
        chunk("FrontPaw_" + side, (x, 0.05, 0.41), (0.13, 0.09, 0.17), fur, collection, root, 0.8)
        sleeve("BackUpper_" + side, (sx * 0.18, 0.88, -0.42), (x, 0.52, -0.26), 0.13, 0.07)
        sleeve("BackLower_" + side, (x, 0.52, -0.26), (x, 0.26, -0.54), 0.06, 0.042, 4)
        sleeve("BackPaw_Meta_" + side, (x, 0.26, -0.54), (x, 0.10, -0.50), 0.042, 0.04, 4)
        chunk("BackPaw_" + side, (x, 0.05, -0.45), (0.12, 0.09, 0.16), fur, collection, root, 0.8)
        # Three curved claws per paw: a cone going forward then hooking down
        for i, dx in enumerate((-0.04, 0.0, 0.04)):
            for prefix, z0 in (("FrontClaw", 0.48), ("BackClaw", -0.38)):
                cx = x + dx
                sleeve("%s_%s_%d_a" % (prefix, side, i), (cx, 0.07, z0), (cx + dx * 0.2, 0.06, z0 + 0.06),
                       0.022, 0.012, 4, glow)
                sleeve("%s_%s_%d_b" % (prefix, side, i), (cx + dx * 0.2, 0.06, z0 + 0.06),
                       (cx + dx * 0.3, 0.0, z0 + 0.09), 0.012, 0.002, 4, glow)

    rig = _make_armature(collection, root, "ShadowWolfRig", SHADOW_WOLF_BONES)
    _skin_rigid(rig, [obj for obj in _all_children(root) if obj.type == "MESH"], SHADOW_WOLF_SKIN_RULES,
                "ShadowWolfBody")
    _remove_empties(root)
    _shadow_wolf_actions(scene, rig)
    studio(scene, collection, root, out, "shadow_wolf.glb", "shadow_wolf.blend")


def _legs(fl: float, fr: float, bl: float, br: float, bend: float = 0.0) -> dict:
    """Leg swing (degrees, +back / -forward) for the four upper legs; lower legs fold by `bend` when
    the upper leg is swung back (paw lifts)."""
    r = math.radians
    pose = {}
    for name, angle in (("FrontUpper_L", fl), ("FrontUpper_R", fr), ("BackUpper_L", bl), ("BackUpper_R", br)):
        pose[name] = ((r(angle), 0, 0), None)
        lower = name.replace("Upper", "Lower")
        if bend and angle > 0:
            # Front knees fold backward (+X), back hocks fold forward (-X)
            fold = bend if name.startswith("Front") else -bend
            pose[lower] = ((r(fold), 0, 0), None)
    return pose


def _shadow_wolf_actions(scene: bpy.types.Scene, rig: bpy.types.Object) -> None:
    """Clips. Neck / Head -X = look up. Tail bones point backward: +X lifts them. Spine / Spine2 -X arches
    the back up (gallop reach), +X rounds it (gather); Y = side bend."""
    scene.render.fps = 30
    r = math.radians
    # Base stance: head carried level with the withers so the top-down camera sees the snout and ears;
    # jaw slightly open, tail low with the tip curling up
    base = {"Neck": ((r(-14), 0, 0), None), "Head": ((r(4), 0, 0), None), "Jaw": ((r(10), 0, 0), None),
            "Tail": ((r(-6), 0, 0), None), "Tail3": ((r(8), 0, 0), None), "Tail4": ((r(14), 0, 0), None)}
    breathe = _pose(base, Chest=((0, 0, 0), (0.0, 0.02, 0.0)), Head=((r(1), r(6), 0), None),
                    Tail2=((0, r(8), 0), None), Tail3=((r(10), r(10), 0), None), Tail4=((r(18), r(12), 0), None),
                    Jaw=((r(14), 0, 0), None), Mane_F=((r(-4), 0, 0), None), Mane_M=((r(-3), 0, 0), None))
    _action(rig, "Idle", [(0.0, base), (0.6, breathe), (1.2, base)])

    # Walk: diagonal pairs (front-left with back-right), spine swings side to side, tail counter-sways
    def walk(sign):
        return _pose(base, **_legs(-20 * sign, 20 * sign, 20 * sign, -20 * sign, 35),
                     Hips=((0, r(-3 * sign), 0), None), Spine2=((0, r(3 * sign), 0), None),
                     Chest=((0, r(3 * sign), 0), None), Tail2=((0, r(-8 * sign), 0), None),
                     Tail3=((r(8), r(-10 * sign), 0), None), Tail4=((r(14), r(-12 * sign), 0), None))
    mid = _pose(base, Root=((0, 0, 0), (0.0, 0.03, 0.0)), Mane_M=((r(4), 0, 0), None))
    _action(rig, "Walk", [(0.0, walk(1)), (0.2, mid), (0.4, walk(-1)), (0.6, mid), (0.8, walk(1))])

    # Run: gallop, the four spine segments arch up on the reach and round on the gather
    reach = _pose(base, **_legs(-45, -38, 40, 46, 0), Spine=((r(-5), 0, 0), None), Spine2=((r(-5), 0, 0), None),
                  Root=((0, 0, 0), (0.0, 0.08, 0.0)), Neck=((r(-18), 0, 0), None),
                  Tail=((r(14), 0, 0), None), Tail2=((r(10), 0, 0), None), Tail3=((r(6), 0, 0), None),
                  Tail4=((r(6), 0, 0), None),
                  Mane_F=((r(12), 0, 0), None), Mane_M=((r(10), 0, 0), None), Mane_B=((r(8), 0, 0), None))
    gather = _pose(base, **_legs(38, 44, -40, -34, 55), Spine=((r(6), 0, 0), None), Spine2=((r(6), 0, 0), None),
                   Root=((0, 0, 0), (0.0, -0.02, 0.0)), Neck=((r(-6), 0, 0), None),
                   Tail=((r(-10), 0, 0), None), Tail2=((r(-8), 0, 0), None), Tail3=((r(16), 0, 0), None),
                   Tail4=((r(20), 0, 0), None),
                   Mane_F=((r(-8), 0, 0), None), Mane_M=((r(-8), 0, 0), None), Mane_B=((r(-6), 0, 0), None))
    _action(rig, "Run", [(0.0, reach), (0.22, gather), (0.45, reach)])

    # Stalk: body sunk, head level and forward (still readable from above), mane raised, tail straight back
    low = _pose(base, Root=((0, 0, 0), (0.0, -0.10, 0.0)), Neck=((r(2), 0, 0), None), Head=((r(-6), 0, 0), None),
                Tail=((r(-2), 0, 0), None), Tail3=((0, 0, 0), None), Tail4=((r(4), 0, 0), None),
                Jaw=((r(14), 0, 0), None), Spine2=((r(4), 0, 0), None),
                Mane_F=((r(-10), 0, 0), None), Mane_M=((r(-8), 0, 0), None),
                FrontLower_L=((r(16), 0, 0), None), FrontLower_R=((r(16), 0, 0), None),
                BackLower_L=((r(-14), 0, 0), None), BackLower_R=((r(-14), 0, 0), None))
    s1 = _pose(low, **_legs(-14, 10, 10, -14, 30), Tail4=((r(4), r(10), 0), None))
    s2 = _pose(low, **_legs(10, -14, -14, 10, 30), Tail4=((r(4), r(-10), 0), None))
    _action(rig, "Stalk", [(0.0, s1), (0.5, s2), (1.0, s1)])

    # Crouch (telegraph, 0.5 s): haunches drop like a spring, back rounds, mane bristles, tail lashes up
    crouch = _pose(low, Root=((0, 0, 0), (0.0, -0.16, -0.04)), Hips=((r(8), 0, 0), None),
                   Spine=((r(6), 0, 0), None), Spine2=((r(6), 0, 0), None),
                   BackUpper_L=((r(-28), 0, 0), None), BackUpper_R=((r(-28), 0, 0), None),
                   BackLower_L=((r(48), 0, 0), None), BackLower_R=((r(48), 0, 0), None),
                   FrontUpper_L=((r(-10), 0, 0), None), FrontUpper_R=((r(-10), 0, 0), None),
                   FrontLower_L=((r(30), 0, 0), None), FrontLower_R=((r(30), 0, 0), None),
                   Jaw=((r(26), 0, 0), None), Tail=((r(16), 0, 0), None), Tail2=((r(10), 0, 0), None),
                   Tail3=((r(10), 0, 0), None), Tail4=((r(10), 0, 0), None),
                   Mane_F=((r(-22), 0, 0), None), Mane_M=((r(-18), 0, 0), None), Mane_B=((r(-14), 0, 0), None))
    _action(rig, "Crouch", [(0.0, base), (0.5, crouch)])

    # Pounce: stretched leap (back arched long), jaws wide, snap shut at 0.3 s
    leap = _pose(base, **_legs(-70, -64, 55, 60, 0), Root=((r(-8), 0, 0), (0.0, 0.20, 0.0)),
                 Spine=((r(-6), 0, 0), None), Spine2=((r(-6), 0, 0), None),
                 Neck=((r(-24), 0, 0), None), Head=((r(-4), 0, 0), None), Jaw=((r(40), 0, 0), None),
                 Tail=((r(18), 0, 0), None), Tail2=((r(6), 0, 0), None), Tail3=((0, 0, 0), None),
                 Tail4=((0, 0, 0), None),
                 Mane_F=((r(14), 0, 0), None), Mane_M=((r(12), 0, 0), None), Mane_B=((r(10), 0, 0), None))
    snap = _pose(leap, Jaw=((0, 0, 0), None), Neck=((r(-8), 0, 0), None))
    land = _pose(base, **_legs(-10, -6, -20, -16, 0), Root=((0, 0, 0), (0.0, -0.06, 0.0)), Neck=((r(0), 0, 0), None),
                 Spine2=((r(5), 0, 0), None))
    _action(rig, "Pounce", [(0.0, crouch), (0.18, leap), (0.3, snap), (0.48, land), (0.6, base)])

    # Bite: head lunges forward, jaw open then snaps at 0.2 s (attack active frame)
    open_ = _pose(base, Neck=((r(-20), 0, 0), (0.0, 0.0, -0.04)), Jaw=((r(40), 0, 0), None), Head=((r(-8), 0, 0), None))
    snap_b = _pose(base, Neck=((r(-2), 0, 0), (0.0, -0.02, 0.10)), Jaw=((0, 0, 0), None), Head=((r(8), 0, 0), None),
                   Spine2=((r(4), 0, 0), None),
                   FrontUpper_L=((r(-12), 0, 0), None), FrontUpper_R=((r(-12), 0, 0), None))
    _action(rig, "Bite", [(0.0, base), (0.12, open_), (0.2, snap_b), (0.45, base)])

    _action(rig, "Hurt", [(0.0, base),
                          (0.07, _pose(base, Chest=((r(-12), 0, r(6)), None), Spine2=((r(-6), 0, 0), None),
                                       Neck=((r(-32), 0, 0), None), Tail3=((r(20), 0, 0), None),
                                       Root=((0, 0, 0), (0.0, 0.0, -0.08)))),
                          (0.25, base)])
    # Death: collapses onto its side (rolls about the long axis), legs and tail limp
    side = {"Root": ((0, 0, r(-82)), (0.0, 0.30, 0.0)), "Neck": ((r(6), 0, r(12)), None),
            "Jaw": ((r(28), 0, 0), None), "Tail": ((0, r(25), 0), None), "Tail3": ((0, r(10), 0), None),
            "Spine2": ((0, r(6), 0), None), "Mane_F": ((0, 0, r(12)), None), **_legs(-20, 10, 18, -8, 40)}
    _action(rig, "Death", [(0.0, base),
                           (0.25, _pose(base, Root=((0, 0, r(-18)), (0.0, -0.12, 0.0)), Neck=((r(12), 0, 0), None),
                                        FrontLower_L=((r(40), 0, 0), None), FrontLower_R=((r(40), 0, 0), None))),
                           (0.6, side), (0.8, side)])



# ---------- Lava slime ----------
# Squash & stretch rig: Body carries every block, so scaling Body squashes the whole slime (ears / eyes are
# child bones and follow). Same axis rules as the other rigs (bone frames = model axes, front = +Z).
LAVA_SLIME_BONES = [
    ("Root", None, (0.0, 0.0, 0.0)),
    ("Body", "Root", (0.0, 0.0, 0.0)),
    ("Ear_L", "Body", (0.20, 0.58, -0.04)),
    ("Ear_R", "Body", (-0.20, 0.58, -0.04)),
    ("Eyes", "Body", (0.0, 0.33, 0.44)),
]
LAVA_SLIME_SKIN_RULES = [("Ear_", "Ear_{s}"), ("Eye_", "Eyes"), ("Slime", "Body"), ("Bump", "Body"), ("Crack", "Body")]
# Dome profile (y, half width, half depth): flat base, wide low belly, rounded top
LAVA_SLIME_PROFILE = [(0.0, 0.56, 0.45), (0.05, 0.59, 0.48), (0.26, 0.57, 0.46), (0.45, 0.47, 0.38),
                      (0.59, 0.30, 0.25), (0.66, 0.10, 0.09)]
# Glowing Y cracks: (angle around the dome in degrees, 90 = front; height y; arm length)
LAVA_SLIME_CRACKS = [(148, 0.17, 0.17), (32, 0.15, 0.16), (66, 0.50, 0.13), (220, 0.30, 0.18),
                     (320, 0.32, 0.17)]
# Small square bumps on the skin: (angle, y, size)
LAVA_SLIME_BUMPS = [(122, 0.30, 0.055), (58, 0.30, 0.05), (92, 0.13, 0.05), (82, 0.05, 0.04),
                    (36, 0.06, 0.09), (250, 0.40, 0.06)]


def _slime_surface(angle_deg: float, y: float, lift: float = 0.0) -> tuple[float, float, float]:
    """Point on the dome at angle / height (interpolates the profile), pushed out by lift."""
    profile = LAVA_SLIME_PROFILE
    for (y0, w0, d0), (y1, w1, d1) in zip(profile, profile[1:]):
        if y0 <= y <= y1:
            t = (y - y0) / (y1 - y0)
            w, d = w0 + (w1 - w0) * t, d0 + (d1 - d0) * t
            break
    else:
        w, d = profile[-1][1], profile[-1][2]
    a = math.radians(angle_deg)
    return ((w + lift) * math.cos(a), y, (d + lift) * math.sin(a))


def build_lava_slime() -> None:
    """Lava slime (Slime Dung Nham), faceted low-poly: red dome with two alternating tones, two square ear
    nubs, glowing pill eyes, small square bumps and glowing Y-shaped cracks. 0.8 m tall with the ears.
    Squash & stretch clips (Body scale) for the hop / fuse (swell) / deflate AI."""
    out = os.path.join(ROOT_DIR, "..", "lava_slime")
    os.makedirs(os.path.join(out, "source"), exist_ok=True)
    scene, collection = clear_scene("LavaSlime_Studio")
    skin = [material("LavaSlime_Skin_A", (0.62, 0.07, 0.04), 0.6, (0.5, 0.04, 0.01), 0.35),
            material("LavaSlime_Skin_B", (0.78, 0.13, 0.06), 0.6, (0.6, 0.08, 0.02), 0.35)]
    bump = material("LavaSlime_Bump", (0.85, 0.20, 0.10), 0.6, (0.7, 0.12, 0.04), 0.4)
    crack = material("LavaSlime_Crack", (1.0, 0.50, 0.08), 0.4, (1.0, 0.45, 0.05), 1.0)
    eye = material("LavaSlime_Eye", (1.0, 0.85, 0.35), 0.3, (1.0, 0.80, 0.30), 1.0)
    root = bpy.data.objects.new("LavaSlimeModel", None)
    collection.objects.link(root)
    root.empty_display_type = "PLAIN_AXES"

    loft("Slime", [(y, w, d, 0.0, 0.0) for y, w, d in LAVA_SLIME_PROFILE], 10, skin, collection, root,
         math.pi / 10)
    for side, sx in (("L", 1.0), ("R", -1.0)):
        chunk("Ear_" + side, (sx * 0.20, 0.68, -0.04), (0.17, 0.20, 0.15), skin, collection, root, 0.75, 4)
        # Pill eyes: vertical capsules sitting on the front face
        tapered_sleeve("Eye_" + side, (sx * 0.13, 0.23, 0.465), (sx * 0.13, 0.43, 0.43), 0.06, 0.06, 6,
                       eye, collection, root)
    for i, (angle, y, size) in enumerate(LAVA_SLIME_BUMPS):
        chunk("Bump_%d" % i, _slime_surface(angle, y, size * 0.2), (size, size, size), bump, collection, root,
              0.85, 4)
    # Y crack: three arms from a center point, each bent slightly so they hug the dome
    for i, (angle, y, length) in enumerate(LAVA_SLIME_CRACKS):
        center = _slime_surface(angle, y, 0.008)
        arm_dir = math.degrees(length / 0.45)
        for k, (da, dy) in enumerate(((0.0, 1.0), (-0.87, -0.5), (0.87, -0.5))):
            tip = _slime_surface(angle + da * arm_dir, min(max(y + dy * length, 0.02), 0.64), 0.008)
            tapered_sleeve("Crack_%d_%d" % (i, k), center, tip, 0.022, 0.008, 4, crack, collection, root)

    rig = _make_armature(collection, root, "LavaSlimeRig", LAVA_SLIME_BONES)
    rig["key_scale"] = True
    _skin_rigid(rig, [obj for obj in _all_children(root) if obj.type == "MESH"], LAVA_SLIME_SKIN_RULES,
                "LavaSlimeBody")
    _remove_empties(root)
    _lava_slime_actions(scene, rig)
    studio(scene, collection, root, out, "lava_slime.glb", "lava_slime.blend")


def _squash(sx: float, sy: float, y: float = 0.0, tilt: float = 0.0) -> tuple:
    """Body pose: scale (sx, sy, sx), lifted by y, tilted sideways by tilt degrees."""
    return ((0.0, 0.0, math.radians(tilt)), (0.0, y, 0.0), (sx, sy, sx))


def _lava_slime_actions(scene: bpy.types.Scene, rig: bpy.types.Object) -> None:
    """Clips. Body scale = squash & stretch; ears flop sideways with Z, mirrored per side."""
    scene.render.fps = 30
    r = math.radians
    rest = {"Body": _squash(1.0, 1.0)}
    _action(rig, "Idle", [(0.0, rest),
                          (0.6, {"Body": _squash(1.04, 0.95), "Ear_L": ((0, 0, r(-8)), None),
                                 "Ear_R": ((0, 0, r(8)), None)}),
                          (1.2, rest)])
    # Hop (also the Walk clip): squash, stretch up, apex, stretch down, squash on landing
    land = {"Body": _squash(1.16, 0.80), "Ear_L": ((0, 0, r(-14)), None), "Ear_R": ((0, 0, r(14)), None)}
    _action(rig, "Walk", [(0.0, land),
                          (0.12, {"Body": _squash(0.88, 1.18, 0.20), "Ear_L": ((0, 0, r(10)), None),
                                  "Ear_R": ((0, 0, r(-10)), None)}),
                          (0.30, {"Body": _squash(1.0, 1.02, 0.34)}),
                          (0.46, {"Body": _squash(0.92, 1.10, 0.10), "Ear_L": ((0, 0, r(12)), None),
                                  "Ear_R": ((0, 0, r(-12)), None)}),
                          (0.54, land), (0.6, land)])
    # Swell (fuse, played stretched to the fuse time): grows and shakes harder and harder
    keys = [(0.0, rest)]
    for i, (scale, tilt) in enumerate(((1.06, 3), (1.11, -4), (1.17, 5), (1.24, -6), (1.32, 7), (1.40, 0))):
        keys.append((0.25 * (i + 1), {"Body": _squash(scale, scale * 0.96, 0.0, tilt),
                                     "Eyes": ((0, 0, 0), None, (1.0, 1.0 + 0.1 * i, 1.0))}))
    _action(rig, "Swell", keys)
    # Deflate (fuse cancelled): hiss back down past rest, then settle
    _action(rig, "Deflate", [(0.0, {"Body": _squash(1.3, 1.25)}), (0.18, {"Body": _squash(1.1, 0.85)}),
                             (0.4, rest)])
    _action(rig, "Hurt", [(0.0, rest), (0.07, {"Body": _squash(1.22, 0.74, 0.0, 6)}), (0.25, rest)])
    # Death (killed without exploding): melts into a flat puddle
    _action(rig, "Death", [(0.0, rest), (0.2, {"Body": _squash(1.25, 0.6)}),
                           (0.6, {"Body": _squash(1.55, 0.08)}), (0.8, {"Body": _squash(1.55, 0.08)})])

BUILDERS = {
    "shield_bearer": build_shield_bearer,
    "wisp_caster": build_wisp_caster,
    "fire_caster": build_fire_caster,
    "shadow_wolf": build_shadow_wolf,
    "lava_slime": build_lava_slime,
}
# Names after "--" pick which models to build; none = all (old behaviour)
_requested = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for _name in (_requested or list(BUILDERS)):
    BUILDERS[_name]()
print("Built: " + ", ".join(_requested or list(BUILDERS)))

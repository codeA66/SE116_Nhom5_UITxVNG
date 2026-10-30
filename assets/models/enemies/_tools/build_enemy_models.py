"""Procedural Blender source for the two cloak enemies used in the movement test."""

import math
import os

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


build_shield_bearer()
build_wisp_caster()
print("Built ShieldBearer and WispCaster GLB plus editable Blender sources.")

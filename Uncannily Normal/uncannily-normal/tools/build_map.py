"""
Build map.tscn — the street outside the shop.

A night street: road, sidewalks, the shop building, parked cars, trees,
fences, dumpsters, barriers and traffic lights. Everything is a real node so
it can be dragged around in the editor.

Run from the project root:  python tools/build_map.py
"""
from pathlib import Path

OUT = Path("map.tscn")

# --- layout -----------------------------------------------------------------
ROAD_W = 12.0          # x extent of the road
STREET_LEN = 60.0      # z extent
SHOP_Z = -10.0         # where the shop front sits

ext = []
sub = []
nodes = ['\n[node name="MAP" type="Node3D"]']
_eid = 0
_sid = 0


def ext_res(kind: str, path: str) -> str:
    global _eid
    for k, p, i in ext:
        if p == path:
            return i
    _eid += 1
    i = f"e{_eid}"
    ext.append((kind, path, i))
    return i


def sub_res(kind: str, lines: list) -> str:
    global _sid
    _sid += 1
    i = f"s{_sid}"
    sub.append((kind, i, lines))
    return i


def box(name, parent, center, size, mat, collide=True):
    mesh_id = sub_res("BoxMesh", [
        f"size = Vector3({size[0]}, {size[1]}, {size[2]})",
        f"material = SubResource(\"{mat}\")",
    ])
    tf = (f"Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, "
          f"{center[0]}, {center[1]}, {center[2]})")
    nodes.append(f'\n[node name="{name}" type="MeshInstance3D" parent="{parent}"]'
                 f"\ntransform = {tf}\nmesh = SubResource(\"{mesh_id}\")")
    if collide:
        shape_id = sub_res("BoxShape3D", [
            f"size = Vector3({size[0]}, {size[1]}, {size[2]})",
        ])
        nodes.append(
            f'\n[node name="{name}Col" type="CollisionShape3D" parent="{parent}/{name}"]'
            f"\ntransform = {tf}\nshape = SubResource(\"{shape_id}\")"
        )


def mat(name, colour, rough=0.85, metal=0.0):
    return sub_res("StandardMaterial3D", [
        f"albedo_color = Color({colour[0]}, {colour[1]}, {colour[2]}, 1)",
        f"roughness = {rough}",
        f"metallic = {metal}",
    ])


def instance(name, parent, path, x, y, z, ry=0.0, s=1.0):
    """Instance a GLB/OBJ/FBX scene at a position."""
    scene = ext_res("PackedScene", path)
    rot = f"Transform3D({1 if abs(ry) < 0.01 else __import__('math').cos(ry)}, 0, "
    # build rotation manually for clarity
    import math
    c, sn = math.cos(ry), math.sin(ry)
    tf = (f"Transform3D({c}, 0, {sn}, 0, 1, 0, {-sn}, 0, {c}, {x}, {y}, {z})")
    nodes.append(f'\n[node name="{name}" parent="{parent}" instance=ExtResource("{scene}")]'
                 f"\ntransform = {tf}")


# ============================================================================
# materials
# ============================================================================
M_ROAD = mat("MRoad", (0.09, 0.09, 0.10), 0.95)
M_SIDEWALK = mat("MSidewalk", (0.28, 0.28, 0.29), 0.95)
M_SHOP = mat("MShop", (0.45, 0.42, 0.38), 0.9)

# ============================================================================
# the street — road surface and two sidewalks
# ============================================================================
box("Road", ".", (0, -0.05, 0), (ROAD_W, 0.1, STREET_LEN), M_ROAD)
box("SidewalkL", ".", (-(ROAD_W * 0.5 + 1.5), 0.0, 0), (3.0, 0.2, STREET_LEN), M_SIDEWALK)
box("SidewalkR", ".", ((ROAD_W * 0.5 + 1.5), 0.0, 0), (3.0, 0.2, STREET_LEN), M_SIDEWALK)

# ============================================================================
# the shop building (BurgerPiz) facing the street
# ============================================================================
SHOP = ext_res("PackedScene", "res://Assets/BurgerPiz/BurgerPiz/Models/BurgerPiz.glb")
nodes.append(
    f'\n[node name="ShopBuilding" parent="." instance=ExtResource("{SHOP}")]'
    f"\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, {SHOP_Z})"
)

# ============================================================================
# parked cars (PSX_Style_Cars — Godot imports OBJ on project open)
# ============================================================================
CARS = [
    ("Car_A", "Car 01/Car.obj", -8.0, -2.5, 0.0),
    ("Car_B", "Car 02/Car2.obj", -3.0, -2.5, 0.0),
    ("Car_C", "Car 03/Car3.obj", 3.0, -2.5, 0.0),
    ("Car_D", "Car 05/Car5_Taxi.obj", 8.0, -2.5, 0.0),
]
for name, fname, x, z, ry in CARS:
    p = f"Assets/PSX_Style_Cars_by_GGBot_(August2023)/{fname}"
    instance(name, ".", p, x, 0.0, z, ry, 1.0)

# ============================================================================
# trees along the far sidewalk (tree_pack — Godot imports FBX on project open)
# ============================================================================
TREES = [
    ("Tree_01", "tree01.fbx", -12.0, 6.0),
    ("Tree_02", "tree02.fbx", -12.0, -8.0),
    ("Tree_03", "tree03.fbx", 12.0, 4.0),
    ("Tree_04", "tree04.fbx", 12.0, -12.0),
    ("Bush_01", "bush01.fbx", -12.0, 0.0),
    ("Bush_02", "bush02.fbx", 12.0, -4.0),
]
for name, fname, x, z in TREES:
    p = f"Assets/tree_pack_1.1/models/{fname}"
    instance(name, ".", p, x, 0.0, z, 0.0, 1.0)

# ============================================================================
# fences behind the shop
# ============================================================================
FENCE_DIR = "Assets/all_fences/Fences/brick_fence"
FENCES = [
    ("Fence_01", "brick_wall.glb", -10.0, -14.0),
    ("Fence_02", "brick_wall.glb", -6.0, -14.0),
    ("Fence_03", "brick_wall.glb", -2.0, -14.0),
    ("Fence_04", "brick_wall.glb", 2.0, -14.0),
    ("Fence_05", "brick_wall.glb", 6.0, -14.0),
    ("Fence_06", "brick_wall.glb", 10.0, -14.0),
]
for name, fname, x, z in FENCES:
    p = f"Assets/all_fences/Fences/brick_fence/{fname}"
    instance(name, ".", p, x, 0.0, z, 0.0, 1.0)

# ============================================================================
# dumpsters and litter (URBAN Litter)
# ============================================================================
LITTER = [
    ("Dumpster_01", "Dumpsters/dumpster_diagonal_closed.glb", -9.0, -6.5),
    ("Dumpster_02", "Dumpsters/dumpster_diagonal_closed_blue.glb", 9.5, -6.5),
    ("Trash_01", "Trash/trashbag_1.glb", -5.0, -6.0),
    ("Trash_02", "TrashCan/trash_can.glb", 5.0, -6.0),
]
for name, fname, x, z in LITTER:
    p = f"Assets/URBAN/URBAN/Litter/{fname}"
    instance(name, ".", p, x, 0.0, z, 0.0, 1.0)

# ============================================================================
# barriers (URBAN Cones & Barriers)
# ============================================================================
BARRIER_DIRS = __import__('os').listdir("Assets/URBAN/URBAN/Cones & Barriers")
BARRIER_FILES = []
for d in BARRIER_DIRS:
    dp = f"Assets/URBAN/URBAN/Cones & Barriers/{d}"
    if __import__('os').path.isdir(dp):
        for f in __import__('os').listdir(dp):
            if f.endswith('.glb'):
                BARRIER_FILES.append(f"{d}/{f}")
BARRIER_FILES = BARRIER_FILES[:6]
for i, fname in enumerate(BARRIER_FILES):
    p = f"Assets/URBAN/URBAN/Cones & Barriers/{fname}"
    instance(f"Barrier_{i:02d}", ".", p, -4.0 + i * 1.5, 0.0, 3.0, 0.0, 1.0)

# ============================================================================
# traffic lights
# ============================================================================
TL_DIR = "Assets/URBAN/URBAN/Traffic lights"
TL_FILES = [f for f in __import__('os').listdir(TL_DIR) if f.endswith('.glb')][:4]
for i, fname in enumerate(TL_FILES):
    p = f"Assets/URBAN/URBAN/Traffic lights/{fname}"
    instance(f"TrafficLight_{i:02d}", ".", p, -6.0 + i * 4.0, 0.0, -3.0, 0.0, 1.0)

# ============================================================================
# street lights (simple poles with a cold glow)
# ============================================================================
M_POLE = mat("MPole", (0.15, 0.15, 0.16), 0.6, 0.8)
for i, x in enumerate(range(-20, 21, 10)):
    box(f"Pole_{i}", ".", (x, 2.0, 5.5), (0.15, 4.0, 0.15), M_POLE)
    nodes.append(
        f'\n[node name="StreetLight_{i}" type="OmniLight3D" parent="."]'
        f"\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, 4.0, 5.5)"
        f"\nlight_color = Color(0.75, 0.82, 0.95, 1)"
        f"\nlight_energy = 3.0"
        f"\nomni_range = 16.0"
    )

# ============================================================================
# the player + HUD
# ============================================================================
PLAYER_SCENE = ext_res("PackedScene", "res://player.tscn")
HUD_SCRIPT = ext_res("Script", "res://ui/hud.gd")
PSX_SCRIPT = ext_res("Script", "res://style/psx_layer.gd")

nodes.append(
    f'\n[node name="Player" parent="." instance=ExtResource("{PLAYER_SCENE}")]'
    f"\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.2, 8.0)"
)
nodes.append(
    f'\n[node name="HUD" type="CanvasLayer" parent="."]'
    f'\nscript = ExtResource("{HUD_SCRIPT}")'
)
nodes.append(
    f'\n[node name="PSX" type="CanvasLayer" parent="."]'
    f'\nscript = ExtResource("{PSX_SCRIPT}")'
)

# ============================================================================
# assemble
# ============================================================================
out = [f"[gd_scene load_steps={len(ext) + len(sub) + 1} format=3]", ""]
for kind, path, i in ext:
    out.append(f'[ext_resource type="{kind}" path="{path}" id="{i}"]')
out.append("")
for kind, i, lines in sub:
    out.append(f'[sub_resource type="{kind}" id="{i}"]')
    out.extend(lines)
    out.append("")
out.append("\n".join(nodes))
out.append("")

OUT.write_text("\n".join(out), encoding="utf-8")

txt = OUT.read_text(encoding="utf-8")
print(f"wrote {OUT}  ({len(txt)} bytes)")
print(f"  ext_resources: {len(ext)}")
print(f"  sub_resources: {len(sub)}")
print(f"  node blocks:   {txt.count('[node ')}")
print(f"  malformed ][node lines: {txt.count('][node')}  (must be 0)")

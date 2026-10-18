"""
Build shop.tscn — the 5am shop (ACT 0).

Emits the room, shelves, counter, the list items and the decoys as real scene
nodes so they can all be dragged around in the Godot editor afterwards.

Run from the project root:  python tools/build_shop.py
"""
from pathlib import Path

OUT = Path("shop/shop.tscn")

# --- layout (metres) --------------------------------------------------------
ROOM_W = 22.0
ROOM_D = 18.0
WALL_H = 3.4
WALL_T = 0.3

ext = []
sub = []
nodes = ['\n[node name="Shop" type="Node3D"]']
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


def body(name, parent, center, script_id, **props):
    lines = [f'\n[node name="{name}" type="StaticBody3D" parent="{parent}"]']
    lines.append(
        f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, "
        f"{center[0]}, {center[1]}, {center[2]})"
    )
    lines.append(f'script = ExtResource("{script_id}")')
    for k, v in props.items():
        lines.append(f'{k} = {v}' if not isinstance(v, str) else f'{k} = "{v}"')
    nodes.append("\n".join(lines))


def mat(name, colour, rough=0.85, metal=0.0):
    return sub_res("StandardMaterial3D", [
        f"albedo_color = Color({colour[0]}, {colour[1]}, {colour[2]}, 1)",
        f"roughness = {rough}",
        f"metallic = {metal}",
    ])


# ============================================================================
# materials
# ============================================================================
M_FLOOR = mat("MFloor", (0.30, 0.29, 0.27), 0.9)
M_WALL = mat("MWall", (0.55, 0.53, 0.48), 0.95)
M_CEIL = mat("MCeil", (0.45, 0.44, 0.42), 0.95)
M_SHELF = mat("MShelf", (0.38, 0.27, 0.20), 0.8)
M_COUNTER = mat("MCounter", (0.26, 0.28, 0.30), 0.7, 0.2)
M_ITEM = mat("MItem", (0.80, 0.78, 0.72), 0.6)
M_TRAP = mat("MTrap", (0.40, 0.11, 0.11), 0.7)
M_CRATE = mat("MCrate", (0.45, 0.33, 0.20), 0.9)

# ============================================================================
# the room
# ============================================================================
box("Floor", ".", (0, -WALL_T * 0.5, 0), (ROOM_W, WALL_T, ROOM_D), M_FLOOR)
box("Ceiling", ".", (0, WALL_H, 0), (ROOM_W, WALL_T, ROOM_D), M_CEIL)
box("WallN", ".", (0, WALL_H * 0.5, -ROOM_D * 0.5), (ROOM_W, WALL_H, WALL_T), M_WALL)
box("WallE", ".", (ROOM_W * 0.5, WALL_H * 0.5, 0), (WALL_T, WALL_H, ROOM_D), M_WALL)
box("WallW", ".", (-ROOM_W * 0.5, WALL_H * 0.5, 0), (WALL_T, WALL_H, ROOM_D), M_WALL)
box("WallS_L", ".", (-(ROOM_W * 0.25 + 0.9), WALL_H * 0.5, ROOM_D * 0.5),
    (ROOM_W * 0.5 - 1.8, WALL_H, WALL_T), M_WALL)
box("WallS_R", ".", ((ROOM_W * 0.25 + 0.9), WALL_H * 0.5, ROOM_D * 0.5),
    (ROOM_W * 0.5 - 1.8, WALL_H, WALL_T), M_WALL)
box("WallS_Top", ".", (0, WALL_H - 0.5, ROOM_D * 0.5), (3.6, 1.0, WALL_T), M_WALL)

# ============================================================================
# shelves
# ============================================================================
SHELF_H = 2.0
SHELF_D = 0.7
shelf_runs = [(-6.5, -4.0, 7.0), (6.5, -4.0, 7.0), (-6.5, 1.5, 7.0), (6.5, 1.5, 7.0)]
for i, (sx, sz, slen) in enumerate(shelf_runs):
    for sgn in (-1, 1):
        box(f"ShelfUpright_{i}_{sgn}", ".", (sx + sgn * slen * 0.5, SHELF_H * 0.5, sz),
            (0.12, SHELF_H, SHELF_D), M_SHELF)
    for level, ly in enumerate((0.55, 1.25, 1.95)):
        box(f"ShelfBoard_{i}_{level}", ".", (sx, ly, sz), (slen, 0.08, SHELF_D), M_SHELF)

# ============================================================================
# counter + back shelf + produce crates
# ============================================================================
box("Counter", ".", (0, 0.55, -6.6), (8.0, 1.1, 0.9), M_COUNTER)
box("CounterTop", ".", (0, 1.13, -6.6), (8.2, 0.08, 1.0), M_SHELF)
box("BackShelf", ".", (0, 1.6, -8.2), (8.0, 0.1, 0.5), M_SHELF)

# produce crates using the new Vegetables / Apples packs
VEG = ext_res("PackedScene", "res://Assets/Vegetables/Vegetables/Veggies_glb.glb")
APPLE = ext_res("PackedScene", "res://Assets/Free Apple Pack/Free Apple Pack/Apples_glb.glb")
for i, (x, z, src) in enumerate([(-9.5, -6.5, VEG), (9.5, -6.5, APPLE)]):
    box(f"Crate_{i}", ".", (x, 0.25, z), (1.4, 0.5, 1.0), M_CRATE)
    nodes.append(
        f'\n[node name="Produce_{i}" parent="." instance=ExtResource("{src}")]'
        f"\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, 0.55, {z})"
    )

# ============================================================================
# the list items + decoys
# ============================================================================
SHELF_SCRIPT = ext_res("Script", "res://shop/shelf_item.gd")
ITEM_SIZE = (0.34, 0.42, 0.30)

placements = [
    ("Item_Milk",     "milk",     "MILK",     -8.5, 0.78, -4.0, M_ITEM),
    ("Item_Bread",    "bread",    "BREAD",    -4.5, 0.78, -4.0, M_ITEM),
    ("Item_Pickles",  "pickles",  "PICKLES",   4.5, 0.78, -4.0, M_ITEM),
    ("Item_Soap",     "soap",     "SOAP",      8.5, 0.78, -4.0, M_ITEM),
    ("Item_Eggs",     "eggs",     "EGGS",     -8.5, 1.48,  1.5, M_ITEM),
    ("Item_Candles",  "candles",  "CANDLES",   8.5, 1.48,  1.5, M_ITEM),
    ("Decoy_1", "", "A TIN OF SOMETHING", -4.5, 1.48, -4.0, M_ITEM),
    ("Decoy_2", "", "A BOTTLE",            4.5, 1.48, -4.0, M_ITEM),
    ("Decoy_3", "", "A BOX",              -8.5, 0.78,  1.5, M_ITEM),
    ("Decoy_4", "", "A JAR",              -4.5, 0.78,  1.5, M_ITEM),
    ("Decoy_5", "", "SOMETHING DAMP",      4.5, 0.78,  1.5, M_ITEM),
    ("Decoy_6", "", "A CAN",               8.5, 0.78,  1.5, M_ITEM),
    ("Decoy_7", "", "A BOX OF POWDER",    -4.5, 1.48,  1.5, M_ITEM),
]

for name, iid, label, x, y, z, m in placements:
    body(name, ".", (x, y, z), SHELF_SCRIPT, item_id=iid, item_label=label, prompt="[E]  TAKE")
    box("Mesh", name, (0, 0, 0), ITEM_SIZE, m, collide=False)
    shape_id = sub_res("BoxShape3D", [
        f"size = Vector3({ITEM_SIZE[0]}, {ITEM_SIZE[1]}, {ITEM_SIZE[2]})",
    ])
    nodes.append(
        f'\n[node name="Col" type="CollisionShape3D" parent="{name}"]'
        f"\nshape = SubResource(\"{shape_id}\")"
    )

# ============================================================================
# lights — a cold strip down the middle, plus a faint moon through the door.
# One of the strip lights is dead, which is the first thing the player notices.
# ============================================================================
for i in range(5):
    lx = -ROOM_W * 0.5 + (i + 0.5) * (ROOM_W / 5)
    dead = (i == 2)
    nodes.append(
        f'\n[node name="Light_{i}" type="OmniLight3D" parent="."]'
        f"\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {lx}, {WALL_H - 0.35}, 0)"
        f"\nlight_color = Color(0.92, 0.94, 0.88, 1)"
        f"\nlight_energy = {0.0 if dead else 4.5}"
        f"\nomni_range = 18.0"
        f"\nomni_attenuation = 1.2"
    )

# A cold directional fill so the room never falls to pure black.
nodes.append(
    '\n[node name="Moon" type="DirectionalLight3D" parent="."]'
    "\ntransform = Transform3D(0.86, -0.35, 0.35, 0, 0.7, 0.7, -0.5, -0.61, 0.61, 0, 8, 0)"
    "\nlight_color = Color(0.55, 0.62, 0.78, 1)"
    "\nlight_energy = 0.55"
    "\nshadow_enabled = false"
)

# ============================================================================
# employee + shop controller + player + UI
# ============================================================================
EMP_SCRIPT = ext_res("Script", "res://shop/employee.gd")
SHOP_SCRIPT = ext_res("Script", "res://shop/shop.gd")
PLAYER_SCENE = ext_res("PackedScene", "res://player.tscn")
HUD_SCRIPT = ext_res("Script", "res://ui/hud.gd")
PSX_SCRIPT = ext_res("Script", "res://style/psx_layer.gd")

nodes.append(
    f'\n[node name="Employee" type="CharacterBody3D" parent="."]'
    f"\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -5.0)"
    f'\nscript = ExtResource("{EMP_SCRIPT}")'
    f"\npost_position = Vector3(0, 0, -5.0)"
)
nodes.append(
    f'\n[node name="EmployeeCol" type="CollisionShape3D" parent="Employee"]'
    f"\nshape = SubResource(\"EmpShape\")"
)
nodes.append(
    f'\n[node name="EmployeeBody" type="MeshInstance3D" parent="Employee"]'
    f"\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.95, 0)"
    f'\nmesh = SubResource("EmpMesh")'
)

nodes.append(
    f'\n[node name="ShopController" type="Node3D" parent="."]'
    f'\nscript = ExtResource("{SHOP_SCRIPT}")'
    f"\ncontract_position = Vector3(0, 1.2, -6.6)"
)
nodes.append(
    f'\n[node name="Player" parent="." instance=ExtResource("{PLAYER_SCENE}")]'
    f"\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.2, 7.5)"
)
nodes.append(
    f'\n[node name="HUD" type="CanvasLayer" parent="."]'
    f'\nscript = ExtResource("{HUD_SCRIPT}")'
)
nodes.append(
    f'\n[node name="PSX" type="CanvasLayer" parent="."]'
    f'\nscript = ExtResource("{PSX_SCRIPT}")'
)

emp_shape = sub_res("CapsuleShape3D", ["radius = 0.32", "height = 1.8"])
emp_mesh = sub_res("CapsuleMesh", [
    "radius = 0.32", "height = 1.8", "radial_segments = 10", "rings = 6",
])
for i, n in enumerate(nodes):
    nodes[i] = n.replace('SubResource("EmpShape")', f'SubResource("{emp_shape}")')
    nodes[i] = nodes[i].replace('SubResource("EmpMesh")', f'SubResource("{emp_mesh}")')

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

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("\n".join(out), encoding="utf-8")

txt = OUT.read_text(encoding="utf-8")
print(f"wrote {OUT}  ({len(txt)} bytes)")
print(f"  ext_resources: {len(ext)}")
print(f"  sub_resources: {len(sub)}")
print(f"  node blocks:   {txt.count('[node ')}")
print(f"  malformed ][node lines: {txt.count('][node')}  (must be 0)")

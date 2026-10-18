#!/usr/bin/env python3
"""_gen_shop.py - Generate scenes/map2.tscn (the 5am shop interior).

Wires the surviving systems/ scripts into a real walkable shop so the trap loop
fires in-play:

  buy THE LAST ONE -> trap_item._reveal_trap() -> 3-slide cutscene
  -> GameState.trapped_in_shop -> escape counts down
  -> night cutscene -> back ExitDoor opens -> reach the back -> home.

Map2 is reached from the street; the player lands through the open FRONT
doorway and the sealed EXIT is the back door (opened by escape.gd at night).

Run:  python tools/_gen_shop.py
"""
from pathlib import Path
import math

ROOT = Path(r"C:/Users/Santi/Uncannily Normal/uncannily-normal")
OUT = ROOT / "scenes" / "map2.tscn"

# --- layout ---------------------------------------------------------------
W, D, H, T = 22.0, 18.0, 3.4, 0.3
DOOR_W, DOOR_H = 3.6, 2.4
ITEM_S = (0.34, 0.42, 0.30)
TRAP_S = (0.36, 0.42, 0.30)
CRATE_S = (0.90, 0.50, 0.90)
BACK_Z = -D / 2          # back interior wall centre (z slab)
FRONT_Z = D / 2          # front doorway centre
COUNTER_Z = -6.6
COUNTER_TOP_Y = 1.13

# --- resource builders (all defined before any use) -----------------------
ext = []
sub = []
nodes = []
_ctr = [0]
_ext = {}
_mat = {}
_mesh = {}
_shape = {}

def nid(p="n"):
    _ctr[0] += 1
    return "%s%d" % (p, _ctr[0])

def E(kind, path):
    if path in _ext:
        return _ext[path]
    eid = "e" + str(len(_ext) + 1)
    _ext[path] = eid
    ext.append((kind, path, eid))
    return eid

def MAT(name, albedo, rough=0.9, metal=0.0, emit=None):
    if name in _mat:
        return _mat[name]
    mid = nid("M")
    _mat[name] = mid
    props = ["albedo_color = Color(%r, %r, %r, 1)" % (albedo[0], albedo[1], albedo[2]),
             "roughness = %r" % rough, "metallic = %r" % metal]
    if emit:
        props += ["emission_enabled = true",
                  "emission = Color(%r, %r, %r, 1)" % (emit[0], emit[1], emit[2]),
                  "emission_energy = %r" % emit[3]]
    sub.append(("StandardMaterial3D", mid, props))
    return mid

def MESH(size, mat):
    k = (tuple(round(v, 4) for v in size), mat)
    if k in _mesh:
        return _mesh[k]
    mid = nid("mesh")
    _mesh[k] = mid
    sub.append(("BoxMesh", mid, ["size = Vector3(%r, %r, %r)" % (size[0], size[1], size[2]),
                                 'material = SubResource("%s")' % mat]))
    return mid

def SHAPE(size):
    k = tuple(round(v, 4) for v in size)
    if k in _shape:
        return _shape[k]
    sid = nid("sh")
    _shape[k] = sid
    sub.append(("BoxShape3D", sid, ["size = Vector3(%r, %r, %r)" % (size[0], size[1], size[2])]))
    return sid

def tf(x, y, z, ang=0.0):
    r = math.radians(ang)
    cs, sn = round(math.cos(r), 6), round(math.sin(r), 6)
    return "Transform3D(%r, 0, %r, 0, 1, 0, %r, 0, %r, %r, %r, %r)" % (cs, sn, -sn, cs, x, y, z)

def solid(name, parent, cx, cy, cz, size, mat, ang=0.0):
    mi = MESH(size, mat)
    shi = SHAPE(size)
    nodes.append('[node name="%s" type="StaticBody3D" parent="%s"]\ntransform = %s'
                 % (name, parent, tf(cx, cy, cz, ang)))
    nodes.append('[node name="%sCol" type="CollisionShape3D" parent="%s"]\nshape = SubResource("%s")'
                 % (name, name, shi))
    nodes.append('[node name="%sMesh" type="MeshInstance3D" parent="%s"]\nmesh = SubResource("%s")'
                 % (name, name, mi))

def item(name, parent, cx, cy, cz, script, shape_id, mesh_id, exports=None):
    hdr = '[node name="%s" type="Area3D" parent="%s"]\ntransform = %s\nscript = ExtResource("%s")' % (
        name, parent, tf(cx, cy, cz, 0.0), script)
    if exports:
        for k, v in exports:
            hdr += "\n%s = %s" % (k, v)
    nodes.append(hdr)
    nodes.append('[node name="%sCol" type="CollisionShape3D" parent="%s"]\nshape = SubResource("%s")'
                 % (name, name, shape_id))
    nodes.append('[node name="Mesh" type="MeshInstance3D" parent="%s"]\nmesh = SubResource("%s")'
                 % (name, mesh_id))

def plain(name, parent, cx, cy, cz, mesh_id):
    nodes.append('[node name="%s" type="MeshInstance3D" parent="%s"]\ntransform = %s\nmesh = SubResource("%s")'
                 % (name, parent, tf(cx, cy, cz, 0.0), mesh_id))

# --- materials ------------------------------------------------------------
FLOOR   = MAT("floor",   (0.30, 0.29, 0.27), 0.95, 0.00)
WALL    = MAT("wall",    (0.55, 0.53, 0.48), 0.95, 0.00, (0.40, 0.39, 0.36, 0.15))
CEIL    = MAT("ceil",    (0.45, 0.44, 0.42), 0.95, 0.05)
SHELF   = MAT("shelf",   (0.38, 0.27, 0.20), 0.80, 0.00)
COUNTER = MAT("counter", (0.26, 0.28, 0.30), 0.70, 0.20, (0.26, 0.28, 0.30, 0.22))
ITEM    = MAT("item",    (0.80, 0.78, 0.72), 0.60, 0.00, (0.08, 0.08, 0.06, 0.25))
TRAP    = MAT("trap",    (0.40, 0.11, 0.11), 0.70, 0.00, (0.40, 0.10, 0.10, 0.55))
CRATE   = MAT("crate",   (0.45, 0.33, 0.20), 0.90, 0.00)
DOOR    = MAT("door",    (0.22, 0.20, 0.19), 0.75, 0.15, (0.22, 0.20, 0.19, 0.25))
EMP = MAT("emp", (0.55, 0.53, 0.48), 0.95, 0.00)  # share wall colour for the NPC

# --- environment ----------------------------------------------------------
ENV_ID = nid("env")
sub.append(("Environment", ENV_ID, [
    "background_mode = 1",
    "background_color = Color(0.01, 0.012, 0.02, 1)",
    "ambient_light_color = Color(0.08, 0.10, 0.15, 1)",
    "ambient_light_energy = 0.65",
    "fog_enabled = true",
    "fog_density = 0.010",
    "fog_light_color = Color(0.08, 0.10, 0.15, 1)",
    "fog_aerial_depth = 0.85",
    "tonemap_mode = 2",
    "tonemap_white_point = 4.0",
]))

# --- employee capsule -----------------------------------------------------
EMP_MESH = nid("emesh")
sub.append(("CapsuleMesh", EMP_MESH, [
    "radius = 0.32", "height = 1.7", "radial_segments = 10", "rings = 6",
    'material = SubResource("%s")' % EMP,
]))
EMP_SH = nid("esh")
sub.append(("CapsuleShape3D", EMP_SH, ["radius = 0.32", "height = 1.7"]))

# --- scripts / scenes -----------------------------------------------------
S_HUNGER = E("Script", "res://systems/hunger.gd")
S_SAVE   = E("Script", "res://systems/save_system.gd")
S_LHUM   = E("Script", "res://systems/light_hum.gd")
S_EMP    = E("Script", "res://systems/employee.gd")
S_TRAP   = E("Script", "res://systems/trap_item.gd")
S_SHELF  = E("Script", "res://systems/shelf_item.gd")
S_SHOP   = E("Script", "res://systems/shop_controller.gd")
S_DOOR   = E("Script", "res://systems/door.gd")
S_ESCAPE = E("Script", "res://systems/escape.gd")
S_PLAYER = E("PackedScene", "res://scenes/player.tscn")

# ===========================================================================
# room shell
# ===========================================================================
nodes.append('[node name="Map2" type="Node3D"]')
solid("Floor",   ".", 0, -T * 0.5, 0, (W, T, D), FLOOR)
solid("Ceiling", ".", 0, H, 0, (W, T, D), CEIL)

HALF_WALL = W / 2 - DOOR_W / 2           # 9.2
solid("WallN_L", ".", -(HALF_WALL / 2), H / 2, BACK_Z, (HALF_WALL, H, T), WALL)
solid("WallN_R", ".",  (HALF_WALL / 2), H / 2, BACK_Z, (HALF_WALL, H, T), WALL)
solid("WallE", ".",  W / 2, H / 2, 0, (T, H, D), WALL)
solid("WallW", ".", -W / 2, H / 2, 0, (T, H, D), WALL)
solid("WallS_L",  ".", -(HALF_WALL / 2), H / 2, FRONT_Z, (HALF_WALL, H, T), WALL)
solid("WallS_R",  ".",  (HALF_WALL / 2), H / 2, FRONT_Z, (HALF_WALL, H, T), WALL)
solid("WallS_Top", ".", 0, H - 0.5, FRONT_Z, (DOOR_W, 1.0, T), WALL)

# ===========================================================================
# back exit door (starts sealed; escape.gd calls open())
# ===========================================================================
nodes.append('[node name="ExitDoor" type="StaticBody3D" parent="."]\ntransform = %s\nscript = ExtResource("%s")'
             % (tf(0, DOOR_H * 0.5, BACK_Z + T * 0.5), S_DOOR))
nodes.append('[node name="ExitDoorCol" type="CollisionShape3D" parent="ExitDoor"]\nshape = SubResource("%s")'
             % SHAPE((DOOR_W, DOOR_H, T)))
nodes.append('[node name="ExitDoorMesh" type="MeshInstance3D" parent="ExitDoor"]\nmaterial_override = SubResource("%s")\nmesh = SubResource("%s")'
             % (DOOR, MESH((DOOR_W, DOOR_H, T), DOOR)))

# ===========================================================================
# shelves (4 runs: front-left, front-right, back-left, back-right)
# ===========================================================================
U_W, U_H, U_D = 0.12, 2.0, 0.70
B_W, B_H, B_D = 7.00, 0.08, 0.70
runs = [(-6.5, -4.0, 7.0), (6.5, -4.0, 7.0), (-6.5, 1.5, 7.0), (6.5, 1.5, 7.0)]
for i, (sx, sz, slen) in enumerate(runs):
    for sgn in (-1, 1):
        ux = sx + sgn * slen * 0.5
        solid("ShelfUpright_%d_%d" % (i, sgn), ".", ux, U_H * 0.5, sz, (U_W, U_H, U_D), SHELF)
    for level, ly in enumerate((0.55, 1.25, 1.95)):
        solid("ShelfBoard_%d_%d" % (i, level), ".", sx, ly, sz, (slen, B_H, B_D), SHELF)

# ===========================================================================
# counter + produce crates
# ===========================================================================
solid("CounterBody", ".", 0, 0.55, COUNTER_Z, (8.0, 1.1, 0.90), COUNTER)
solid("CounterTop",  ".", 0, 1.13, COUNTER_Z, (8.20, 0.08, 1.00), COUNTER)
solid("Crate_Veg",   ".", -9.5, CRATE_S[1] * 0.5, -6.5, CRATE_S, CRATE)
solid("Crate_Apple", ".",  9.5, CRATE_S[1] * 0.5, -6.5, CRATE_S, CRATE)

# ===========================================================================
# shopping-list items (Area3D, E-interactable) + decoys + the trap
# ===========================================================================
LIST = [
    ("Item_Milk",    "milk",    "MILK",    -8.5, 0.78, -4.0),
    ("Item_Bread",   "bread",   "BREAD",   -4.5, 0.78, -4.0),
    ("Item_Pickles", "pickles", "PICKLES",  4.5, 0.78, -4.0),
    ("Item_Soap",    "soap",    "SOAP",     8.5, 0.78, -4.0),
    ("Item_Eggs",    "eggs",    "EGGS",    -8.5, 1.48,  1.5),
    ("Item_Candles", "candles", "CANDLES",  8.5, 1.48,  1.5),
]
for name, iid, label, x, y, z in LIST:
    item(name, ".", x, y, z, S_SHELF, SHAPE(ITEM_S), MESH(ITEM_S, ITEM),
         [("item_id", '"%s"' % iid), ("item_label", '"%s"' % label)])

DECOYS = [
    ("Decoy_1", -4.5, 1.48, -4.0), ("Decoy_2", 4.5, 1.48, -4.0),
    ("Decoy_3", -8.5, 2.18, -4.0), ("Decoy_4", -4.5, 2.18, -4.0),
    ("Decoy_5",  4.5, 2.18, -4.0), ("Decoy_6", 8.5, 2.18, -4.0),
    ("Decoy_7", -4.5, 0.78,  1.5), ("Decoy_8", 4.5, 0.78,  1.5),
]
for name, x, y, z in DECOYS:
    plain(name, ".", x, y, z, MESH(ITEM_S, ITEM))

# THE LAST ONE — on the counter front edge
item("TrapItem", ".", 0, COUNTER_TOP_Y + 0.19, COUNTER_Z + 0.9,
     S_TRAP, SHAPE(TRAP_S), MESH(TRAP_S, TRAP))

# ===========================================================================
# employee, shop controller, escape, player
# ===========================================================================
nodes.append('[node name="Employee" type="CharacterBody3D" parent="."]\ntransform = %s\nscript = ExtResource("%s")'
             % (tf(0, 0, -4.0), S_EMP))
nodes.append('[node name="EmpCol" type="CollisionShape3D" parent="Employee"]\nshape = SubResource("%s")' % EMP_SH)
nodes.append('[node name="EmpMesh" type="MeshInstance3D" parent="Employee"]\ntransform = %s\nmesh = SubResource("%s")'
             % (tf(0, 0.95, 0), EMP_MESH))

nodes.append('[node name="ShopController" type="Node3D" parent="."]\ntransform = %s\nscript = ExtResource("%s")\ncontract_position = Vector3(0, 0.2, 0)'
             % (tf(0, COUNTER_TOP_Y + 0.2, COUNTER_Z), S_SHOP))

nodes.append('[node name="Escape" type="Node3D" parent="."]\nscript = ExtResource("%s")' % S_ESCAPE)

nodes.append('[node name="Player" parent="." instance=ExtResource("%s")]\ntransform = %s'
             % (S_PLAYER, tf(0, 0.2, 6.0)))

# ===========================================================================
# systems + atmosphere (match map0: HungerNode, SaveSystem, Lights+light_hum,
# NightEnvironment, Moon)
# ===========================================================================
nodes.append('[node name="HungerNode" type="Node" parent="."]\nscript = ExtResource("%s")' % S_HUNGER)
nodes.append('[node name="SaveSystem" type="Node" parent="."]\nscript = ExtResource("%s")' % S_SAVE)

nodes.append('[node name="Lights" type="Node3D" parent="."]\nscript = ExtResource("%s")' % S_LHUM)
for i in range(5):
    lx = -W / 2 + (i + 0.5) * (W / 5)
    dead = (i == 2)
    nodes.append('[node name="ShopLight_%d" type="OmniLight3D" parent="Lights"]\ntransform = %s\nlight_color = Color(0.92, 0.94, 0.88, 1)\nlight_energy = %r\nomni_range = 18.0\nomni_attenuation = 1.2'
                 % (i, tf(lx, H - 0.35, 0), 0.0 if dead else 4.5))

nodes.append('[node name="Moon" type="DirectionalLight3D" parent="."]\ntransform = Transform3D(0.8645072, -0.3562327, 0.35457805, 0, 0.7054588, 0.7087509, -0.50262046, -0.61272025, 0.60987425, 0, 8, 0)\nlight_color = Color(0.55, 0.62, 0.78, 1)\nlight_energy = 0.55\nshadow_enabled = false')

nodes.append('[node name="NightEnvironment" type="WorldEnvironment" parent="."]\nenvironment = SubResource("%s")' % ENV_ID)

# ===========================================================================
# assemble
# ===========================================================================
out = ["[gd_scene load_steps=%d format=3]" % (len(ext) + len(sub) + 1), ""]
for kind, path, eid in ext:
    out.append('[ext_resource type="%s" path="%s" id="%s"]' % (kind, path, eid))
out.append("")
for typ, sid, props in sub:
    out.append('[sub_resource type="%s" id="%s"]' % (typ, sid))
    out.extend(props)
    out.append("")
out.append("\n".join(nodes))
out.append("")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("\n".join(out), encoding="utf-8")
txt = OUT.read_text(encoding="utf-8")
print("wrote %s  (%d bytes)" % (OUT, len(txt)))
print("  ext_resources:", len(ext))
print("  sub_resources:", len(sub))
print("  node blocks:", txt.count("[node "))
print("  malformed ][node:", txt.count("][node"), "(must be 0)")

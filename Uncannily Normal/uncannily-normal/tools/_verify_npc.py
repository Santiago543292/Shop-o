#!/usr/bin/env python3
"""
tools/_verify_npc.py — file-level structural verification of the NPC family.

No Godot engine required. Checks that every file exists, the scripts declare
the right base class / exports, the .tscn scenes bind the right script and
have the right root type, and that map0/map1 actually reference + wire the new
instances (ext_resource -> instance -> properties). Prints [PASS]/[FAIL] per
check and exits non-zero on any failure.

Run:  python3 tools/_verify_npc.py
"""
import re, sys
from pathlib import Path

ROOT = Path(r"C:\Users\Santi\Uncannily Normal\uncannily-normal")
fails = []
passed = 0

def check(name, cond):
    global passed
    if cond:
        passed += 1
        print(f"[PASS] {name}")
    else:
        fails.append(name)
        print(f"[FAIL] {name}")

def read(rel):
    p = ROOT / rel
    return p, p.read_text(encoding="utf-8") if p.exists() else ""

# --- scripts exist + content checks ---------------------------------------
npc_gd,       _ = read("systems/npc.gd")
shop_gd,     _ = read("systems/shopkeeper.gd")
lock_gd,     _ = read("systems/locked_door.gd")
demo_gd,     _ = read("systems/demo_blocker.gd")
npc_tscn,    npc_t = read("systems/npc.tscn")
shop_tscn,   shp = read("systems/shopkeeper.tscn")
lock_tscn,   lck = read("systems/locked_door.tscn")
demo_tscn,   dmb = read("systems/demo_blocker.tscn")

check("npc.gd exists", npc_gd.exists())
check("shopkeeper.gd exists", shop_gd.exists())
check("locked_door.gd exists", lock_gd.exists())
check("demo_blocker.gd exists", demo_gd.exists())
check("npc.tscn exists", npc_tscn.exists())
check("shopkeeper.tscn exists", shop_tscn.exists())
check("locked_door.tscn exists", lock_tscn.exists())
check("demo_blocker.tscn exists", demo_tscn.exists())

def has(src, pat):
    return re.search(pat, src, re.MULTILINE) is not None

# npc.gd
check("npc.gd: CharacterBody3D base", has(npc_gd.read_text(), r"extends CharacterBody3D"))
check("npc.gd: class_name NPC", has(npc_gd.read_text(), r"class_name NPC"))
check("npc.gd: waypoint: NodePath export", has(npc_gd.read_text(), r"@export var waypoint: NodePath"))
check("npc.gd: _patrol()", has(npc_gd.read_text(), r"func _patrol"))
check("npc.gd: _look() (no _look_at left)", has(npc_gd.read_text(), r"func _look") and not has(npc_gd.read_text(), r"func _look_at"))
check("npc.gd: interact() present", has(npc_gd.read_text(), r"func interact\(\) -> void:"))
check("npc.gd: no leftover _targets/_step_patrol/_advance_patrol",
      not has(npc_gd.read_text(), r"_targets|_step_patrol|_advance_patrol|waypoint_paths"))

# shopkeeper.gd
s = shop_gd.read_text()
check("shopkeeper.gd: extends NPC", has(s, r"extends NPC"))
check("shopkeeper.gd: food_name/price exports", has(s, r'food_name :?= "APPLE"') and has(s, r"@export var price"))
check("shopkeeper.gd: interact() override", has(s, r"func interact\(\) -> void:"))
check("shopkeeper.gd: add_food gate", has(s, r"GameState.add_food\(food_name\)"))

# locked_door.gd
l = lock_gd.read_text()
check("locked_door.gd: extends door.gd", has(l, r"extends \"res://systems/door\.gd\""))
check("locked_door.gd: requires_flag export", has(l, r"@export var requires_flag"))
check("locked_door.gd: open()/close() override (no door sfx)", has(l, r"func open\(\) -> void:") and has(l, r"func close\(\) -> void:"))
check("locked_door.gd: no play_sound() call in code (comment-aware)", not any("play_sound" in ln for ln in l.splitlines() if not ln.strip().startswith("#")))

# demo_blocker.gd
d = demo_gd.read_text()
check("demo_blocker.gd: extends Area3D + class_name", has(d, r"extends Area3D") and has(d, r"class_name DemoBlocker"))
check("demo_blocker.gd: block_flag + _disarm", has(d, r'block_flag := "demo_complete"') and has(d, r"func _disarm"))
check("demo_blocker.gd: frees Block child on disarm", has(d, r'get_node_or_null\("Block"\)') and has(d, r"_block\.queue_free\(\)"))

# --- .tscn structure ------------------------------------------------------
def root_type_and_script(text):
    m_root = re.search(r'^\[node name="(\w+)" type="(\w+)"', text, re.MULTILINE)
    m_ext  = re.search(r'path="(res://systems/[^"]+\.gd)" id="1_', text)
    m_script = re.search(r'script = ExtResource\("1_[^"]+"\)', text)
    return (m_root.group(2) if m_root else None), (m_ext.group(1) if m_ext else None)

check("npc.tscn: CharacterBody3D + npc.gd", root_type_and_script(npc_t) == ("CharacterBody3D", "res://systems/npc.gd"))
check("shopkeeper.tscn: CharacterBody3D + shopkeeper.gd", root_type_and_script(shp) == ("CharacterBody3D", "res://systems/shopkeeper.gd"))
check("locked_door.tscn: StaticBody3D + locked_door.gd", root_type_and_script(lck) == ("StaticBody3D", "res://systems/locked_door.gd"))
check("demo_blocker.tscn: Area3D + demo_blocker.gd", root_type_and_script(dmb) == ("Area3D", "res://systems/demo_blocker.gd"))
check("demo_blocker.tscn: Block StaticBody3D child (physical wall)", '[node name="Block" type="StaticBody3D"' in dmb)

# --- map wiring -----------------------------------------------------------
map1, m1 = read("scenes/map1.tscn")
map0, m0 = read("scenes/map0.tscn")
check("map1: all 4 NPC scene ext_resources",
      all(p in m1 for p in ["npc.tscn","shopkeeper.tscn","locked_door.tscn","demo_blocker.tscn"]))
check("map1: Shopkeeper1 at diner (-2..8)", '[node name="Shopkeeper1"' in m1 and "food_name = \"APPLE\"" in m1)
check("map1: LockedDoor1 with requires_flag", '[node name="LockedDoor1"' in m1 and 'requires_flag = "storage_key"' in m1)
check("map1: DemoGate sealing bus exit", '[node name="DemoGate"' in m1 and 'block_flag = "demo_complete"' in m1)
check("map1: BusExit gated by demo_complete", 'BusExit' in m1 and 'require_flag = "demo_complete"' in m1)

check("map0: npc.tscn ext_resource", 'npc.tscn' in m0)
check("map0: Walker with waypoint=NodePath(\"WP1\")", '[node name="Walker"' in m0 and 'waypoint = NodePath("WP1")' in m0)
check("map0: WP1 child under Walker", '[node name="WP1" type="Marker3D" parent="Walker"' in m0)

# --- parse traps ----------------------------------------------------------
check("no bare 'for _ in' in systems/ (parse trap)", True)
# scan systems/*.gd
bad = []
for f in (ROOT / "systems").glob("*.gd"):
    for ln in f.read_text(encoding="utf-8").splitlines():
        if re.search(r'\bfor _ in\b', ln):
            bad.append(f"{f.name}: {ln.strip()}")
check("no bare 'for _ in' in systems/*.gd", not bad)
for b in bad:
    print(f"    -> {b}")

print(f"\n=== {passed} passed, {len(fails)} failed ===")
sys.exit(1 if fails else 0)

#!/usr/bin/env python3
"""
tools/_wire_npcs.py — wire the NPC family into the demo maps (map0, map1).

Idempotent: re-running will not duplicate ext_resources or instance nodes. It
only adds what is missing. No Godot needed — this is plain text editing of the
.tscn files, so it runs in python3 (no engine lock).

Adds to map1 (THE STREETS):
  - Shopkeeper    (diner seller)        @ the diner, sells APPLE for $5
  - LockedDoor    (storage back door)   requires_flag="storage_key"
  - DemoBlocker   (seals the bus exit)   block_flag="demo_complete"
  - BusExit       (existing)            require_flag="demo_complete" + msg
Adds to map0 (THE BUS STOP):
  - Walker (NPC patrolling) + its Waypoint child marker
"""
import re, sys
from pathlib import Path

ROOT = Path(r"C:\Users\Santi\Uncannily Normal\uncannily-normal")
NPC_SCENE     = "res://systems/npc.tscn"
SHOP_SCENE    = "res://systems/shopkeeper.tscn"
LOCK_SCENE    = "res://systems/locked_door.tscn"
DEMO_SCENE    = "res://systems/demo_blocker.tscn"

def uid():
    """monotonic unique_id ints well away from existing ~2e9 values"""
    uid.n += 1
    return uid.n
uid.n = 3_000_000_000

def load_steps(text):
    m = re.search(r'load_steps=(\d+)', text)
    return int(m.group(1)) if m else None

def set_load_steps(text, n):
    return re.sub(r'load_steps=\d+', f'load_steps={n}', text, count=1)

def ext_ids(text):
    return set(re.findall(r'id="([^"]+)"', text))  # fragile: grabs all ids

def has_ext(text, path):
    return f'path="{path}"' in text

def insert_exts(text, new_exts):
    """insert [ext_resource ...] lines after the last existing [ext_resource]."""
    lines = text.splitlines(keepends=True)
    last = -1
    for i, ln in enumerate(lines):
        if ln.startswith("[ext_resource"):
            last = i
    block = ""
    for path, eid in new_exts:
        if not has_ext(text, path):
            block += f'[ext_resource type="PackedScene" path="{path}" id="{eid}"]\n'
    if not block:
        return text, 0
    if last == -1:
        # insert after the [gd_scene] header line
        for i, ln in enumerate(lines):
            if ln.startswith("[gd_scene"):
                lines.insert(i + 1, block)
                break
    else:
        lines.insert(last + 1, block)
    return "".join(lines), len([b for b in block.splitlines() if b.startswith("[ext_resource")])

def add_props_to_node(text, node_name, props_lines):
    """insert property lines right after a [node name=...] header."""
    pat = re.compile(r'(\[node name="' + re.escape(node_name) + r'"[^\n]*\n)')
    def repl(m):
        return m.group(1) + "".join(props_lines)
    return pat.sub(repl, text, count=1)

def append_nodes(text, blocks):
    """append [node ...] blocks at end of file (before trailing newline)."""
    block = "".join(blocks)
    if text.endswith("\n"):
        return text + block
    return text + "\n" + block

def T(x, y, z):
    return f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})"

# -------- map1: streets/diner --------
def wire_map1(text):
    new_exts = []
    if not has_ext(text, NPC_SCENE):   new_exts.append((NPC_SCENE, "95_npc"))
    if not has_ext(text, SHOP_SCENE):  new_exts.append((SHOP_SCENE, "96_sk"))
    if not has_ext(text, LOCK_SCENE):  new_exts.append((LOCK_SCENE, "97_ld"))
    if not has_ext(text, DEMO_SCENE):  new_exts.append((DEMO_SCENE, "98_db"))
    text, added = insert_exts(text, new_exts)
    ls = load_steps(text)
    if ls is not None:
        text = set_load_steps(text, ls + added)

    # seal the bus exit (map1 -> map2) behind the demo gate
    if 'name="BusExit"' in text and 'require_flag = "demo_complete"' not in text:
        text = add_props_to_node(text, "BusExit",
            ['require_flag = "demo_complete"\n',
             'blocked_message = "the demo ends here for now. keep exploring."\n'])

    # append instances (idempotent by name)
    blocks = []
    if '[node name="Shopkeeper1"' not in text:
        blocks.append(f'[node name="Shopkeeper1" parent="." instance=ExtResource("96_sk") unique_id={uid()}]\n'
                      f'{T(-2.0, 1.62, 8.0)}\n'
                      f'food_name = "APPLE"\n'
                      f'price = 5\n')
    if '[node name="LockedDoor1"' not in text:
        blocks.append(f'[node name="LockedDoor1" parent="." instance=ExtResource("97_ld") unique_id={uid()}]\n'
                      f'{T(0.0, 1.62, 5.0)}\n'
                      f'requires_flag = "storage_key"\n')
    if '[node name="DemoGate"' not in text:
        blocks.append(f'[node name="DemoGate" parent="." instance=ExtResource("98_db") unique_id={uid()}]\n'
                      f'{T(74.48, 0.2, 72.41)}\n'
                      f'block_flag = "demo_complete"\n'
                      f'block_message = "the demo ends here for now.\\nkeep exploring."\n')
    text = append_nodes(text, blocks)
    return text

# -------- map0: bus stop --------
def wire_map0(text):
    new_exts = []
    if not has_ext(text, NPC_SCENE): new_exts.append((NPC_SCENE, "14_npc"))
    text, added = insert_exts(text, new_exts)
    ls = load_steps(text)
    if ls is not None:
        text = set_load_steps(text, ls + added)
    blocks = []
    if '[node name="Walker"' not in text:
        blocks.append('[node name="Walker" parent="." instance=ExtResource("14_npc") unique_id=%d]\n'
                      % uid() + T(20.0, 0.0, 40.0) + 'waypoint = NodePath("WP1")\n')
        blocks.append('[node name="WP1" type="Marker3D" parent="Walker" unique_id=%d]\n' % uid()
                      + T(10.0, 0.0, 0.0) + '\n')
    text = append_nodes(text, blocks)
    return text

def main():
    edits = [(ROOT / "scenes/map1.tscn", wire_map1),
             (ROOT / "scenes/map0.tscn", wire_map0)]
    for path, fn in edits:
        text = path.read_text(encoding="utf-8")
        before = len(text)
        text = fn(text)
        path.write_text(text, encoding="utf-8")
        print(f"{path.name}: {before} -> {len(text)} bytes")

if __name__ == "__main__":
    main()

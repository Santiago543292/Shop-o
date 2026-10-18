"""
Wire all system scripts into the map and shop scenes.

Adds: MapController, Hunger, BusStop, SaveSystem to each map scene.
Adds: Employee, Contract, CustomerSystem, TrapItems to the shop scene.

Run: python tools/wire_systems.py
"""
import re
from pathlib import Path

ROOT = Path("C:/Users/Santi/Uncannily Normal/uncannily-normal")

MAPS = [
    ("scenes/map0.tscn", "map0", "res://scenes/map1.tscn"),
    ("scenes/map1.tscn", "map1", "res://scenes/map2.tscn"),
    ("scenes/map2.tscn", "map2", ""),
]

for path, map_id, next_map in MAPS:
    p = ROOT / path
    txt = p.read_text(encoding="utf-8")

    if "HungerNode" in txt:
        print(f"  {path} already wired, skipping")
        continue

    # Find last ext_resource
    lines = txt.split("\n")
    last_ext_idx = 0
    for i, line in enumerate(lines):
        if line.startswith("[ext_resource"):
            last_ext_idx = i

    # Add ext_resources for all systems
    new_exts = [
        f'[ext_resource type="Script" path="res://systems/hunger.gd" id="10_hunger"]',
        f'[ext_resource type="Script" path="res://systems/bus_stop.gd" id="11_bus"]',
        f'[ext_resource type="Script" path="res://systems/save_system.gd" id="12_save"]',
    ]
    for j, ext in enumerate(new_exts):
        lines.insert(last_ext_idx + 1 + j, ext)

    # Build system nodes
    new_nodes = []

    # Hunger system
    new_nodes.append("""
[node name="HungerNode" type="Node" parent="."]
script = ExtResource("10_hunger")
""")

    # Bus stop progression
    new_nodes.append(f"""
[node name="BusStopNode" type="Node3D" parent="."]
script = ExtResource("11_bus")
next_map_id = "{map_id}"
next_map = "{next_map}"
""")

    # Save system
    new_nodes.append("""
[node name="SaveSystem" type="Node" parent="."]
script = ExtResource("12_save")
""")

    txt = "\n".join(lines)
    txt += "\n".join(new_nodes) + "\n"

    p.write_text(txt, encoding="utf-8")
    print(f"  wired {path}")

# Wire the shop scene
shop = ROOT / "shop/shop.tscn"
txt = shop.read_text(encoding="utf-8")
if "EmployeeNode" not in txt:
    lines = txt.split("\n")
    last_ext_idx = 0
    for i, line in enumerate(lines):
        if line.startswith("[ext_resource"):
            last_ext_idx = i

    new_exts = [
        '[ext_resource type="Script" path="res://systems/employee.gd" id="20_emp"]',
        '[ext_resource type="Script" path="res://systems/customer.gd" id="21_cust"]',
        '[ext_resource type="Script" path="res://systems/trap_item.gd" id="22_trap"]',
        '[ext_resource type="Script" path="res://systems/save_system.gd" id="23_save"]',
    ]
    for j, ext in enumerate(new_exts):
        lines.insert(last_ext_idx + 1 + j, ext)

    new_nodes = []

    # Employee
    new_nodes.append("""
[node name="EmployeeNode" type="CharacterBody3D" parent="."]
script = ExtResource("20_emp")
post_position = Vector3(0, 0, -5.0)
""")

    # Customer system
    new_nodes.append("""
[node name="CustomerSystem" type="Node3D" parent="."]
script = ExtResource("21_cust")
customer_interval = 15.0
max_customers = 3
""")

    # Save system
    new_nodes.append("""
[node name="SaveSystem" type="Node" parent="."]
script = ExtResource("23_save")
""")

    txt = "\n".join(lines)
    txt += "\n".join(new_nodes) + "\n"
    shop.write_text(txt, encoding="utf-8")
    print("  wired shop/shop.tscn")

print("done")

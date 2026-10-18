"""
Add lights, collisions, and map controller to all three map scenes.

Run from the project root:  python tools/fix_maps.py
"""
from pathlib import Path

MAPS = [
    ("scenes/map0.tscn", "map0", "THE BUS STOP", "FIND THE BUS STOP", "res://scenes/map1.tscn"),
    ("scenes/map1.tscn", "map1", "THE STREETS", "EXPLORE AND FIND FOOD", "res://scenes/map2.tscn"),
    ("scenes/map2.tscn", "map2", "THE SHOP", "BUY EVERYTHING ON THE LIST", ""),
]

for path, map_id, title, objective, next_map in MAPS:
    p = Path(path)
    txt = p.read_text(encoding="utf-8")

    # Skip if already patched
    if "MapController" in txt:
        print(f"  {path} already patched, skipping")
        continue

    # Find the root node name
    root_name = "MAP0" if "map0" in path else ("MAP" if "map1" in path else "Map2")

    # Build the new nodes to add
    new_nodes = []

    # Map controller
    new_nodes.append(f'''
[node name="MapController" type="Node3D" parent="."]
script = ExtResource("1_mapctrl")
map_id = "{map_id}"
map_title = "{title}"
map_objective = "{objective}"
next_map = "{next_map}"
''')

    # Directional light (cold moon fill)
    new_nodes.append('''
[node name="Moon" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.86, -0.35, 0.35, 0, 0.7, 0.7, -0.5, -0.61, 0.61, 0, 8, 0)
light_color = Color(0.55, 0.62, 0.78, 1)
light_energy = 0.5
shadow_enabled = false
''')

    # Omni lights along the street
    for i, x in enumerate(range(-15, 16, 10)):
        new_nodes.append(f'''
[node name="StreetLight_{i}" type="OmniLight3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, 4.0, 5.0)
light_color = Color(0.75, 0.82, 0.95, 1)
light_energy = 4.0
omni_range = 16.0
''')

    # Collision shapes for the bus stop meshes
    # We add invisible box colliders as siblings
    new_nodes.append('''
[node name="BusStopCollider" type="StaticBody3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.5, 0)

[node name="BusStopCol" type="CollisionShape3D" parent="BusStopCollider"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)
shape = SubResource("1_buscol")
''')

    # Add the ext_resource for the map controller script
    # Insert after the last ext_resource line
    lines = txt.split("\n")
    last_ext_idx = 0
    for i, line in enumerate(lines):
        if line.startswith("[ext_resource"):
            last_ext_idx = i

    # Insert the new ext_resource after the last one
    new_ext = f'[ext_resource type="Script" path="res://maps/map_controller.gd" id="1_mapctrl"]'
    lines.insert(last_ext_idx + 1, new_ext)

    # Add the sub_resource for the bus stop collider shape
    # Insert after the last sub_resource block
    last_sub_idx = 0
    for i, line in enumerate(lines):
        if line.startswith("[sub_resource"):
            last_sub_idx = i

    # Find the end of the last sub_resource block
    sub_end = last_sub_idx
    for i in range(last_sub_idx + 1, len(lines)):
        if lines[i].startswith("[") and not lines[i].startswith("[sub_resource"):
            sub_end = i
            break
    else:
        sub_end = len(lines)

    new_sub = '''[sub_resource type="BoxShape3D" id="1_buscol"]
size = Vector3(2.5, 3.0, 1.5)'''
    lines.insert(sub_end, new_sub)

    # Add the new nodes at the end
    txt = "\n".join(lines)
    txt += "\n".join(new_nodes) + "\n"

    p.write_text(txt, encoding="utf-8")
    print(f"  patched {path}")

print("done")

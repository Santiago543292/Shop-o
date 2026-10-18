"""
Add ground, building colliders, tree colliders, and lights to all maps.

Run from the project root:  python tools/fix_maps_v2.py
"""
from pathlib import Path

MAPS = [
    ("scenes/map0.tscn", "MAP0", "House"),
    ("scenes/map1.tscn", "MAP", "BurgerPiz2"),
    ("scenes/map2.tscn", "Map2", "6twelve"),
]

for path, root_name, building_name in MAPS:
    p = Path(path)
    txt = p.read_text(encoding="utf-8")

    if "GroundMesh" in txt:
        print(f"  {path} already patched, skipping")
        continue

    lines = txt.split("\n")

    # Find the last ext_resource line
    last_ext_idx = 0
    for i, line in enumerate(lines):
        if line.startswith("[ext_resource"):
            last_ext_idx = i

    # Add new ext_resources
    new_exts = [
        '[ext_resource type="Script" path="res://maps/ground.gd" id="2_ground"]',
    ]
    for j, ext in enumerate(new_exts):
        lines.insert(last_ext_idx + 1 + j, ext)

    # Find insertion point for sub_resources (after last sub_resource block)
    last_sub_idx = 0
    for i, line in enumerate(lines):
        if line.startswith("[sub_resource"):
            last_sub_idx = i

    sub_end = len(lines)
    for i in range(last_sub_idx + 1, len(lines)):
        if lines[i].startswith("[") and not lines[i].startswith("[sub_resource"):
            sub_end = i
            break

    # Add sub_resources
    new_subs = "\n".join([
        '[sub_resource type="BoxMesh" id="BoxMesh_ground"]',
        'size = Vector3(60, 0.2, 60)',
        '',
        '[sub_resource type="BoxShape3D" id="BoxShape3D_ground"]',
        'size = Vector3(60, 0.2, 60)',
        '',
        '[sub_resource type="BoxShape3D" id="BoxShape3D_building"]',
        'size = Vector3(12, 8, 10)',
        '',
        '[sub_resource type="BoxShape3D" id="BoxShape3D_tree"]',
        'size = Vector3(1.5, 4, 1.5)',
    ])
    lines.insert(sub_end, new_subs)

    # Build new nodes
    new_nodes = []

    # Ground
    new_nodes.append("\n".join([
        '[node name="Ground" type="StaticBody3D" parent="."]',
        '',
        '[node name="GroundMesh" type="MeshInstance3D" parent="Ground"]',
        'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.1, 0)',
        'mesh = SubResource("BoxMesh_ground")',
        '',
        '[node name="GroundCol" type="CollisionShape3D" parent="Ground"]',
        'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)',
        'shape = SubResource("BoxShape3D_ground")',
    ]))

    # Building collider
    new_nodes.append("\n".join([
        '[node name="BuildingCollider" type="StaticBody3D" parent="."]',
        'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 4, 0)',
        '',
        '[node name="BuildingCol" type="CollisionShape3D" parent="BuildingCollider"]',
        'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)',
        'shape = SubResource("BoxShape3D_building")',
    ]))

    # Tree colliders
    tree_positions = [(-15, 2, 8), (-15, 2, -8), (15, 2, 6), (15, 2, -10)]
    for i, (tx, ty, tz) in enumerate(tree_positions):
        new_nodes.append("\n".join([
            f'[node name="TreeCollider_{i}" type="StaticBody3D" parent="."]',
            f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {tx}, {ty}, {tz})',
            '',
            f'[node name="TreeCol_{i}" type="CollisionShape3D" parent="TreeCollider_{i}"]',
            'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)',
            'shape = SubResource("BoxShape3D_tree")',
        ]))

    # Street lights
    light_positions = [(-10, 5, 6), (0, 5, 6), (10, 5, 6), (-10, 5, -6), (0, 5, -6), (10, 5, -6)]
    for i, (lx, ly, lz) in enumerate(light_positions):
        new_nodes.append("\n".join([
            f'[node name="Lamp_{i}" type="OmniLight3D" parent="."]',
            f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {lx}, {ly}, {lz})',
            'light_color = Color(0.75, 0.82, 0.95, 1)',
            'light_energy = 4.0',
            'omni_range = 18.0',
        ]))

    # Lamp poles
    for i, (lx, ly, lz) in enumerate(light_positions):
        new_nodes.append("\n".join([
            f'[node name="Pole_{i}" type="MeshInstance3D" parent="."]',
            f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {lx}, {ly - 2.5}, {lz})',
            'mesh = SubResource("BoxMesh_ground")',
        ]))

    txt = "\n".join(lines)
    txt += "\n" + "\n".join(new_nodes) + "\n"

    p.write_text(txt, encoding="utf-8")
    print(f"  patched {path}")

print("done")

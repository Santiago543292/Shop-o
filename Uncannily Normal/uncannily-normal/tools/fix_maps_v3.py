"""
Fix all map colliders and lights to match actual object positions.
Removes misplaced nodes, adds correct ones using URBAN assets.

Run: python tools/fix_maps_v3.py
"""
import re
from pathlib import Path

ROOT = Path("C:/Users/Santi/Uncannily Normal/uncannily-normal")

MAPS = [
    ("scenes/map0.tscn", "MAP0", "House", (53.72, 1.91, 41.51)),
    ("scenes/map1.tscn", "MAP", "BurgerPiz2", (74.48, 2.07, 72.44)),
    ("scenes/map2.tscn", "Map2", "6twelve", (-21.61, 1.62, 19.16)),
]

# URBAN street light asset
STREET_LIGHT = "res://Assets/URBAN/URBAN/Traffic lights/street_light.glb"

for path, root_name, building_name, bus_pos in MAPS:
    p = ROOT / path
    txt = p.read_text(encoding="utf-8")
    
    lines = txt.split("\n")
    out = []
    skip_until_next = False
    
    for line in lines:
        # Skip old misplaced colliders and lights
        if any(x in line for x in [
            'BuildingCollider', 'BuildingCol',
            'TreeCollider_', 'TreeCol_',
            'BusStopCollider', 'BusStopCol',
            'Lamp_0', 'Lamp_1', 'Lamp_2', 'Lamp_3', 'Lamp_4', 'Lamp_5',
            'Pole_0', 'Pole_1', 'Pole_2', 'Pole_3', 'Pole_4', 'Pole_5',
            'StreetLight_', 'StreetLights',
            'MapController', 'Moon', 'Ground', 'GroundMesh', 'GroundCol',
        ]):
            skip_until_next = True
            continue
        
        if skip_until_next:
            if line.startswith('[') or (line.strip() == '' and out and out[-1].strip() == ''):
                skip_until_next = False
                if line.strip() != '':
                    out.append(line)
            continue
        
        out.append(line)
    
    txt = "\n".join(out)
    
    # Now add correct nodes
    new_nodes = []
    
    # Ground
    new_nodes.append("""
[node name="Ground" type="StaticBody3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.1, 0)

[node name="GroundMesh" type="MeshInstance3D" parent="Ground"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)
mesh = SubResource("BoxMesh_ground")

[node name="GroundCol" type="CollisionShape3D" parent="Ground"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)
shape = SubResource("BoxShape3D_ground")
""")
    
    # Building collider at origin (buildings are at origin)
    new_nodes.append("""
[node name="BuildingCollider" type="StaticBody3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 4, 0)

[node name="BuildingCol" type="CollisionShape3D" parent="BuildingCollider"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)
shape = SubResource("BoxShape3D_building")
""")
    
    # Bus stop collider at exact position
    bx, by, bz = bus_pos
    new_nodes.append(f"""
[node name="BusStopCollider" type="StaticBody3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {bx}, 1.5, {bz})

[node name="BusStopCol" type="CollisionShape3D" parent="BusStopCollider"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)
shape = SubResource("BoxShape3D_ground")
""")
    
    # Street lights using URBAN asset, positioned along the road
    light_positions = [
        (bx - 10, 5, bz - 5), (bx, 5, bz - 5), (bx + 10, 5, bz - 5),
        (bx - 10, 5, bz + 5), (bx, 5, bz + 5), (bx + 10, 5, bz + 5),
    ]
    for i, (lx, ly, lz) in enumerate(light_positions):
        new_nodes.append(f"""
[node name="StreetLight_{i}" parent="." instance=ExtResource("e_streetlight")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {lx}, {ly}, {lz})
""")
    
    # Moon light
    new_nodes.append("""
[node name="Moon" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.86, -0.35, 0.35, 0, 0.7, 0.7, -0.5, -0.61, 0.61, 0, 8, 0)
light_color = Color(0.55, 0.62, 0.78, 1)
light_energy = 0.5
shadow_enabled = false
""")
    
    # Add street light ext_resource
    lines = txt.split("\n")
    last_ext_idx = 0
    for i, line in enumerate(lines):
        if line.startswith("[ext_resource"):
            last_ext_idx = i
    lines.insert(last_ext_idx + 1, f'[ext_resource type="PackedScene" path="{STREET_LIGHT}" id="e_streetlight"]')
    txt = "\n".join(lines)
    
    txt += "\n".join(new_nodes) + "\n"
    p.write_text(txt, encoding="utf-8")
    print(f"  fixed {path}")

print("done")

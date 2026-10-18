"""
Remove all mesh nodes from maps 0-2, keep only lights and collisions.

- Remove StreetLight instances (meshes) → keep Lamp OmniLight3D nodes
- Remove Pole meshes → keep only the light
- Remove GroundMesh → keep only GroundCol
- Keep all CollisionShape3D nodes (invisible colliders)

Run: python tools/clean_maps.py
"""
import re
from pathlib import Path

ROOT = Path("C:/Users/Santi/Uncannily Normal/uncannily-normal")

MAPS = [
    "scenes/map0.tscn",
    "scenes/map1.tscn",
    "scenes/map2.tscn",
]

for path in MAPS:
    p = ROOT / path
    txt = p.read_text(encoding="utf-8")

    lines = txt.split("\n")
    out = []
    skip = False

    for line in lines:
        # Skip mesh nodes and street light instances
        if any(x in line for x in [
            'GroundMesh',
            'StreetLight_0', 'StreetLight_1', 'StreetLight_2',
            'StreetLight_3', 'StreetLight_4', 'StreetLight_5',
            'Pole_0', 'Pole_1', 'Pole_2', 'Pole_3', 'Pole_4', 'Pole_5',
            'instance=ExtResource("e_streetlight")',
        ]):
            skip = True
            continue

        if skip:
            if line.startswith('[') or (line.strip() == '' and out and out[-1].strip() == ''):
                skip = False
                if line.strip() != '':
                    out.append(line)
            continue

        out.append(line)

    txt = "\n".join(out)
    p.write_text(txt, encoding="utf-8")
    print(f"  cleaned {path}")

print("done")

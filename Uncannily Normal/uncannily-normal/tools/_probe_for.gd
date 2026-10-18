extends Node3D
## Isolation probe: does this Godot 4.7 build accept `for _ in range()` (discard var)?
@export var warmup_frames := 60

func _ready() -> void:
    for _i in range(warmup_frames):
        print("PROBE_UNDERSCORE_OK")
    get_tree().quit(0)

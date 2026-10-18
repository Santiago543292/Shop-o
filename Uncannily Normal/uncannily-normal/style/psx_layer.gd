extends CanvasLayer

const SHADER := preload("res://style/psx.gdshader")

var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	layer = 5
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	add_child(_rect)


func set_damage(t: float) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("wobble", lerpf(0.0, 0.008, t))
	_mat.set_shader_parameter("chroma_shift", lerpf(0.0, 0.006, t))
	_mat.set_shader_parameter("saturation", lerpf(1.05, 0.55, t))
	_mat.set_shader_parameter("vertical_resolution", lerpf(240.0, 150.0, t))


func set_enabled(on: bool) -> void:
	if _rect != null:
		_rect.visible = on

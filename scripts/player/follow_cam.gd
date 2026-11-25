extends Camera3D
## Третье лицо: камера — ребёнок SpringArm3D (пирамида коллизии).
## К стенам подтягивается сразу, назад выезжает плавно.

@export var smoothing := 12.0
var _len := -1.0


func _process(delta: float) -> void:
	var arm := get_parent() as SpringArm3D
	if arm == null:
		return
	if not current:
		_len = -1.0
		return
	var hit := arm.get_hit_length()
	var sgn := 1.0
	if absf(position.z) > 0.05:
		sgn = signf(position.z)
	var target := sgn * hit
	if _len < 0.0 or absf(target) < absf(_len) - 0.01:
		_len = target
	else:
		_len = lerpf(_len, target, 1.0 - exp(-smoothing * delta))
	position = Vector3(0.0, 0.0, _len)

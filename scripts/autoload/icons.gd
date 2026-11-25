extends Node
## Иконки предметов (автозагрузка Icons). Рисует 3D-модель предмета в маленьком
## отдельном мире и делает из неё картинку. Пока картинка не готова — отдаёт заглушку.

signal icon_ready(key: String)

const SIZE := 128

var _cache: Dictionary = {}
var _queue: Array[Array] = []
var _busy := false
var _viewport: SubViewport
var _stage: Node3D
var _camera: Camera3D
var _placeholder: Texture2D
var _enabled := true


func _ready() -> void:
	_enabled = DisplayServer.get_name() != "headless"
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0.08))
	_placeholder = ImageTexture.create_from_image(img)
	if not _enabled:
		return
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZE, SIZE)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0)
	sun.light_energy = 1.3
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_viewport.add_child(_camera)
	_stage = Node3D.new()
	_viewport.add_child(_stage)


func get_icon(kind: String, id: StringName, cond: float = 100.0) -> Texture2D:
	var key := _key(kind, id, cond)
	if _cache.has(key):
		return _cache[key]
	if _enabled and not _queue.any(func(q): return q[0] == key):
		_queue.append([key, kind, id, cond])
		_pump()
	return _placeholder


func key_of(kind: String, id: StringName, cond: float = 100.0) -> String:
	return _key(kind, id, cond)


func _key(kind: String, id: StringName, cond: float) -> String:
	return "%s:%s%s" % [kind, id, ":broken" if kind == "rod" and cond <= 0.0 else ""]


func _pump() -> void:
	if _busy or _queue.is_empty():
		return
	_busy = true
	while not _queue.is_empty():
		var job: Array = _queue.pop_front()
		await _render(job[0], job[1], job[2], job[3])
	_busy = false


func _render(key: String, kind: String, id: StringName, cond: float) -> void:
	for c in _stage.get_children():
		c.free()
	var model := ItemModels.build(kind, id, cond)
	_stage.add_child(model)
	# Длинные вещи (удочки) кладём по диагонали, рыбу — боком.
	if kind == "rod":
		model.rotation = Vector3(0, 0, -0.78)
	elif kind == "fish":
		model.rotation = Vector3(0, -0.35, 0.15)
	else:
		model.rotation = Vector3(0.15, -0.5, 0)
	var box := _aabb(model)
	var center := box.get_center()
	var radius := box.size.length() * 0.5
	var dist := radius / tan(deg_to_rad(_camera.fov * 0.5)) * 1.05
	_camera.position = center + Vector3(0, radius * 0.25, dist)
	_camera.look_at(center)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img := _viewport.get_texture().get_image()
	if img:
		_cache[key] = ImageTexture.create_from_image(img)
		icon_ready.emit(key)


func _aabb(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b := m.get_aabb()
		var xf := node.global_transform.affine_inverse() * m.global_transform
		b = xf * b
		b = node.transform * b
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	if first:
		box = AABB(Vector3(-0.1, 0, -0.1), Vector3(0.2, 0.2, 0.2))
	return box

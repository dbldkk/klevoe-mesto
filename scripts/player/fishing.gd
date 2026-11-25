class_name FishingController
extends Node3D
## Ловля рыбы: заброс -> ожидание -> поклёв -> подсечка -> вываживание.
##
## Кто клюнет, какого веса и когда — решает СЕРВЕР (хост).
## Вываживание считается у владельца удочки, чтобы управление не тормозило.
##
## Вываживание:
##  * держишь ЛКМ — подматываешь, натяжение растёт; отпустил — ослабляешь;
##  * у рыбы есть силы: пока леска натянута, она устаёт и тянет слабее —
##    поэтому даже бамбуковой удочкой можно вытащить крупную рыбу, если не спешить;
##  * сильное натяжение изнашивает удочку; на тяжёлой рыбе и в зарослях — гораздо быстрее;
##  * удочка на нуле — ломается (чинит Дядя Толя);
##  * перетянул до предела — лопнет леска, провисла надолго — рыба сойдёт.

enum State { IDLE, CHARGING, FLYING, WAITING, BITE, FIGHT }

const CHARGE_TIME := 1.2
const MIN_CAST := 3.0
const BITE_WINDOW := 0.9          ## на подсечку (у редкой рыбы меньше)
const CATCH_DISTANCE := 1.8
const SLACK_LIMIT := 3.0
const SNAP_LIMIT := 0.6
const RANDOM_ESCAPE_PER_SEC := 0.006

@onready var player: CharacterBody3D = get_parent()
@onready var bobber: MeshInstance3D = $Bobber
@onready var line_mesh: MeshInstance3D = $Line

var state: State = State.IDLE
var charge := 0.0

# Вываживание (читает HUD)
var tension := 0.0
var distance := 0.0
var start_distance := 0.0
var surge := false
var stamina := 100.0
var reeling := false
var in_reeds := false
var heavy := false
## Рывок рыбы в сторону: -1 влево, 1 вправо, 0 — нет. Держи противоположную клавишу (A/D).
var dash_dir := 0
var dash_ok := false
## Рыба выпрыгнула («свеча») — надо отпустить ЛКМ, иначе сорвёт.
var jump_time := 0.0
## Поплавок «играет» (ложная поклёвка) — подсекать рано.
var nibble := 0.0
var zone := "open"

var _rng := RandomNumberGenerator.new()
var _imesh := ImmediateMesh.new()
var _tween: Tween
var _cast_id := 0
var _bite_pending := false
var _bite_timer := 0.0
var _bite_window := 0.0
var _hooked_fish: FishData
var _hooked_kg := 0.0
var _surge_timer := 0.0
var _snag_timer := 0.0
var _snap_time := 0.0
var _slack_time := 0.0
var _land_pos := Vector3.ZERO
var _cast_dir := Vector3.FORWARD
var _time := 0.0
var _dash_timer := 0.0
var _dash_left := 0.0
var _jump_timer := 0.0
var _nibble_timer := 0.0
var _bite_total := BITE_WINDOW
var _cast_rod_slot: Dictionary = {}
var _cast_bait: StringName = &""
var _throw_t := -1.0
var _hook_t := -1.0


func _ready() -> void:
	_rng.randomize()
	line_mesh.mesh = _imesh
	line_mesh.global_transform = Transform3D.IDENTITY
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.95, 0.95, 0.95)
	line_mesh.material_override = mat
	bobber.visible = false


func is_busy() -> bool:
	return state != State.IDLE


var _bob_mat: StandardMaterial3D


## Ночью поплавок светится (светлячок).
func _glow_bobber() -> void:
	if _bob_mat == null:
		_bob_mat = (bobber.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
		_bob_mat.emission_enabled = true
		_bob_mat.emission = Color(1.0, 0.45, 0.2)
		bobber.material_override = _bob_mat
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	_bob_mat.emission_energy_multiplier = dc.darkness() * 4.0 if dc else 0.0


func _process(delta: float) -> void:
	_time += delta
	if bobber.visible:
		_glow_bobber()
	if player.is_multiplayer_authority():
		_update_local(delta)
		player.fish_state = state
		player.bobber_pos = bobber.global_position
	else:
		var show: bool = player.fish_state >= State.FLYING
		if show and not bobber.visible:
			bobber.global_position = player.bobber_pos
		bobber.visible = show
		bobber.global_position = bobber.global_position.lerp(player.bobber_pos, minf(delta * 15.0, 1.0))
	_draw_line()


# ---------------------------------------------------------------- локальная логика

func _update_local(delta: float) -> void:
	var blocked: bool = Events.ui_open or player.input_cooldown > 0.0 or player.is_busy_body() \
		or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	var click := not blocked and Input.is_action_just_pressed("fish_action")

	# Удочку убрали из рук — сматываем.
	if state != State.IDLE and (Inventory.get_rod() == null or not is_same(Inventory.held_rod_slot(), _cast_rod_slot)):
		_finish("", Color.WHITE)
		return

	match state:
		State.IDLE:
			if click and Inventory.held_rod_slot() != null:
				_try_start_charge()
		State.CHARGING:
			if blocked:
				cancel()
				return
			charge = minf(charge + delta / CHARGE_TIME, 1.0)
			if not Input.is_action_pressed("fish_action"):
				_cast()
		State.FLYING:
			pass
		State.WAITING:
			nibble = maxf(nibble - delta, 0.0)
			var bob := sin(_time * 2.0) * 0.02
			if nibble > 0.0:
				bob += sin(_time * 22.0) * 0.035
			bobber.global_position = _land_pos + Vector3.UP * bob
			if click:
				if nibble > 0.0:
					# Подсёк на ложной поклёвке — рыба испугалась, наживку объели.
					if _rng.randf() < 0.5:
						Inventory.consume_bait(_cast_bait)
					Sfx.play("splash", _land_pos, -6.0)
					_finish("Рано подсёк — рыба только пробовала наживку. Ждать надо, пока поплавок утонет", Color.ORANGE)
				else:
					_finish("Смотал удочку", Color.LIGHT_GRAY)
			elif _bite_pending:
				_bite_timer -= delta
				_nibble_timer -= delta
				if _nibble_timer <= 0.0 and _bite_timer > 1.2:
					_nibble_timer = _rng.randf_range(1.5, 4.0)
					nibble = _rng.randf_range(0.35, 0.7)
					Sfx.play("nibble", _land_pos, -10.0)
				if _bite_timer <= 0.0:
					_start_bite()
		State.BITE:
			_bite_window -= delta
			bobber.global_position = _land_pos + Vector3(0, -0.12 + sin(_time * 30.0) * 0.06, 0)
			if click:
				# Чем раньше подсёк, тем надёжнее; в самом конце окна рыба может сойти.
				var late := 1.0 - _bite_window / _bite_total
				if late > 0.7 and _rng.randf() < (late - 0.7) * 1.6:
					Inventory.consume_bait(_cast_bait)
					_finish("Поздно подсёк — рыба выплюнула крючок", Color.TOMATO)
				else:
					_hook()
			elif _bite_window <= 0.0:
				Inventory.consume_bait(_cast_bait)
				_finish("Рыба съела наживку…", Color.TOMATO)
		State.FIGHT:
			_update_fight(delta, blocked)


func _try_start_charge() -> void:
	var s = Inventory.held_rod_slot()
	if s.get("cond", 100.0) <= 0.0:
		Events.notify("Удочка сломана. Починить можно у Дяди Толи на рынке", Color.TOMATO)
		return
	if player.swimming:
		Events.notify("В воде не порыбачишь", Color.LIGHT_GRAY)
		return
	if player.vehicle and not player.vehicle.allows_fishing(player.seat):
		Events.notify("Отсюда не порыбачишь" if player.vehicle.kind != "boat" else "Сначала остановись (W/S отпусти)", Color.LIGHT_GRAY)
		return
	if Inventory.get_bait_count() <= 0:
		Events.notify("Нет наживки! Купи в «Шестёрочке» или… поищи в кустах", Color.TOMATO)
		return
	state = State.CHARGING
	charge = 0.0
	_cast_rod_slot = s
	_cast_bait = Inventory.equipped_bait


func _cast() -> void:
	var rod := Inventory.get_rod()
	var d := Inventory.drunk / 100.0
	var dist := lerpf(MIN_CAST, rod.max_cast, charge) * _rng.randf_range(1.0 - 0.3 * d, 1.0 + 0.1 * d)
	var fwd := -player.global_basis.z
	fwd.y = 0.0
	_cast_dir = fwd.normalized().rotated(Vector3.UP, _rng.randf_range(-0.3, 0.3) * d)

	var target: Vector3 = player.global_position + _cast_dir * dist
	var hit := _probe(target)
	var land := Vector3(target.x, Terrain.WATER_Y, target.z)
	var in_water := false
	if not hit.is_empty():
		land = hit.position
		in_water = hit.collider is Terrain and Terrain.is_water(land.x, land.z)
		if in_water:
			land.y = Terrain.WATER_Y

	state = State.FLYING
	_throw_t = 0.0
	Sfx.play("cast", player.global_position, -4.0)
	var start: Vector3 = player.get_rod_tip()
	bobber.global_position = start
	bobber.visible = true
	var arc := 1.5 + dist * 0.15
	_tween = create_tween()
	_tween.tween_method(
		func(t: float) -> void:
			bobber.global_position = start.lerp(land, t) + Vector3.UP * sin(t * PI) * arc,
		0.0, 1.0, 0.5 + charge * 0.5)
	_tween.finished.connect(_on_landed.bind(in_water, land))


## Луч сверху вниз: что под точкой — земля, пирс или дно озера.
func _probe(p: Vector3) -> Dictionary:
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 12.0, p + Vector3.DOWN * 20.0, 1)
	return space.intersect_ray(q)


func _on_landed(in_water: bool, land: Vector3) -> void:
	if state != State.FLYING:
		return
	if not in_water:
		_finish("Мимо воды", Color.LIGHT_GRAY)
		return
	_land_pos = land
	in_reeds = Reeds.in_zone(land)
	var dep := Terrain.depth(land.x, land.z)
	zone = "reeds" if in_reeds else ("deep" if dep > 3.6 else "open")
	if Terrain.is_far(land.x, land.z):
		if not in_reeds and dep > 6.0:
			zone = "pit"
		zone = "far_" + zone
	if in_reeds:
		Events.notify("Закинул в заросли — тут клюёт крупнее, но легко зацепиться", Color(0.7, 0.9, 0.6))
	state = State.WAITING
	_cast_id += 1
	_bite_pending = false
	_nibble_timer = _rng.randf_range(1.0, 3.0)
	nibble = 0.0
	Sfx.play("splash", land, -8.0)
	NetUtil.call_server(self, "request_bite", [_cast_id, _cast_bait, Inventory.drunk, zone])


func _start_bite() -> void:
	_bite_pending = false
	state = State.BITE
	nibble = 0.0
	var r := int(_hooked_fish.rarity) if _hooked_fish else 0
	_bite_total = BITE_WINDOW * (1.0 - 0.1 * r) * (1.0 - Inventory.drunk / 100.0 * 0.25)
	_bite_window = _bite_total
	Sfx.play("bite", _land_pos)
	Events.notify("Клюёт! Жми ЛКМ!", Color.YELLOW)


func _hook() -> void:
	if not Inventory.consume_bait(_cast_bait):
		_finish("Наживка с этого заброса закончилась — закинь снова", Color.ORANGE)
		return
	state = State.FIGHT
	_hook_t = 0.0
	var flat := _land_pos - player.global_position
	flat.y = 0.0
	start_distance = maxf(flat.length(), CATCH_DISTANCE + 1.0)
	distance = start_distance
	tension = 30.0
	stamina = 100.0
	surge = false
	_surge_timer = _rng.randf_range(1.0, 2.5)
	_snag_timer = _rng.randf_range(2.0, 5.0)
	_snap_time = 0.0
	_slack_time = 0.0
	dash_dir = 0
	_dash_timer = _rng.randf_range(2.0, 4.0)
	jump_time = 0.0
	_jump_timer = _rng.randf_range(5.0, 10.0)
	Sfx.play("hook", player.global_position, -4.0)
	var rod := Inventory.get_rod()
	heavy = _hooked_kg > rod.max_kg * 1.15
	if heavy:
		Events.notify("Что-то ОЧЕНЬ тяжёлое! Удочка рассчитана до %.0f кг — может не выдержать. R — отпустить" % rod.max_kg,
			Color.ORANGE)
	elif _hooked_fish.rarity >= FishData.Rarity.RARE:
		Events.notify("Сидит крупная! Не торопись", Color(0.6, 0.8, 1.0))


func _update_fight(delta: float, blocked: bool) -> void:
	var rod := Inventory.get_rod()
	if rod == null:
		_finish("Рыба ушла", Color.TOMATO)
		return
	if not blocked and Input.is_action_just_pressed("release_fish"):
		_finish("Отпустил рыбу. Удочка цела.", Color.LIGHT_BLUE)
		return

	reeling = not blocked and Input.is_action_pressed("fish_action")
	Sfx.loop("reel", reeling)

	# Рывки в сторону: рыба уходит влево/вправо — держи противоположную клавишу (A/D).
	var strong := _hooked_fish.strength * (0.6 + 0.4 * stamina / 100.0)
	_dash_timer -= delta
	if dash_dir == 0 and _dash_timer <= 0.0:
		dash_dir = -1 if _rng.randf() < 0.5 else 1
		_dash_left = _rng.randf_range(1.0, 2.0) * clampf(strong, 0.6, 1.6)
		Sfx.play("splash", bobber.global_position, -8.0)
	var dash_k := 0.0
	if dash_dir != 0:
		_dash_left -= delta
		var want := "move_right" if dash_dir < 0 else "move_left"
		var wrong := "move_left" if dash_dir < 0 else "move_right"
		dash_ok = not blocked and Input.is_action_pressed(want) and not Input.is_action_pressed(wrong)
		dash_k = -0.6 if dash_ok else 1.0
		if _dash_left <= 0.0:
			dash_dir = 0
			_dash_timer = _rng.randf_range(2.5, 5.5) / clampf(strong, 0.7, 1.8)
	# «Свеча»: рыба выпрыгивает — сразу отпусти ЛКМ.
	if _hooked_fish.rarity >= FishData.Rarity.UNCOMMON or _hooked_kg > 1.5:
		_jump_timer -= delta
		if jump_time <= 0.0 and _jump_timer <= 0.0:
			jump_time = 0.7
			_jump_timer = _rng.randf_range(6.0, 12.0)
			Sfx.play("splash_big", bobber.global_position, -4.0)
		if jump_time > 0.0:
			jump_time -= delta
			if reeling and jump_time < 0.55:
				tension += 70.0 * delta
				stamina = minf(stamina + 6.0 * delta, 100.0)

	_surge_timer -= delta
	if _surge_timer <= 0.0:
		surge = not surge
		_surge_timer = _rng.randf_range(0.6, 1.6) if surge else _rng.randf_range(1.5, 4.0)

	# Сила рыбы относительно удочки (0..1, плавно насыщается).
	var power := _hooked_kg / rod.max_kg * _hooked_fish.strength
	var pull := 1.0 - exp(-power * 0.6)
	var fresh := 0.3 + 0.7 * stamina / 100.0
	var p := pull * fresh * (1.0 if surge else 0.55)
	# Рыба тяжелее, чем рассчитана удочка, — тянет сильнее и подматывается медленнее.
	var over := maxf(_hooked_kg / rod.max_kg - 1.0, 0.0)
	var extra := clampf(over * 0.1, 0.0, 0.35) * fresh
	var snag := 12.0 if in_reeds else 0.0

	if reeling:
		tension = move_toward(tension, 28.0 + 72.0 * (p + extra) + snag, 45.0 * delta)
		distance -= rod.reel_speed * (1.0 - 0.75 * p) / (1.0 + 0.2 * over) * delta
	else:
		tension = move_toward(tension, 4.0 + 30.0 * p + snag * 0.5, 40.0 * delta)
		distance += p * 2.0 * delta
	# Рывок: не повёл удилище — леска натягивается и рыба уходит; повёл — рыба устаёт быстрее.
	if dash_k > 0.0:
		tension += 26.0 * strong * delta
		distance += 1.4 * strong * delta
		stamina = minf(stamina + 3.0 * delta, 100.0)
	elif dash_k < 0.0:
		stamina = maxf(stamina - 4.0 * delta, 0.0)
	var shaky := (1.0 + Inventory.drunk / 100.0 * 1.5) * (0.6 if Inventory.calm_time > 0.0 else 1.0)
	tension += _rng.randf_range(-1.0, 1.0) * (18.0 if surge else 6.0) * shaky * delta

	# Зацеп за траву — резкий рывок.
	if in_reeds:
		_snag_timer -= delta
		if _snag_timer <= 0.0:
			_snag_timer = _rng.randf_range(2.5, 6.0)
			tension += 22.0
			Events.notify("Зацеп за траву!", Color(0.7, 0.9, 0.6))
	tension = clampf(tension, 0.0, 100.0)
	distance = minf(distance, start_distance + 8.0)

	# Рыба устаёт, пока леска натянута; отдыхает, когда слабо.
	var size_k := 1.0 + _hooked_kg * 0.12
	if tension > 25.0:
		stamina = maxf(stamina - (3.0 + tension * 0.09) / size_k * delta, 0.0)
	else:
		stamina = minf(stamina + 4.0 * delta, 100.0)

	# Износ удочки
	if tension > 70.0:
		var wear := (tension - 70.0) / 30.0 * 4.0 * sqrt(1.0 + over) * (2.0 if in_reeds else 1.0) / rod.toughness
		if Inventory.wear_rod(wear * delta):
			Inventory.changed.emit()
			player.refresh_held()
			_announce("%s сломал(а) удочку!" % player.player_name)
			Sfx.play("rod_break", player.global_position)
			_finish("ТРЕСК! %s сломалась. Почини у Дяди Толи" % rod.display_name, Color.RED)
			return

	# Перетянул до предела — леска лопается
	if tension >= 98.0:
		_snap_time += delta
	else:
		_snap_time = maxf(_snap_time - delta, 0.0)
	if _snap_time >= SNAP_LIMIT:
		Sfx.play("line_snap", player.global_position)
		_finish("Леска лопнула, рыба ушла", Color.TOMATO)
		return

	if tension < 8.0:
		_slack_time += delta
	else:
		_slack_time = 0.0
	if _slack_time >= SLACK_LIMIT:
		_finish("Леска провисла — рыба сошла с крючка", Color.TOMATO)
		return

	if _rng.randf() < RANDOM_ESCAPE_PER_SEC * delta * (2.0 if surge else 1.0):
		_finish("Рыба сорвалась!", Color.TOMATO)
		return

	if distance <= CATCH_DISTANCE:
		_catch()
		return

	var pos: Vector3 = player.global_position + _cast_dir * distance
	pos.y = Terrain.WATER_Y - 0.08
	if surge:
		pos += Vector3(_rng.randf_range(-0.15, 0.15), 0, _rng.randf_range(-0.15, 0.15))
	if dash_dir != 0:
		pos += player.global_basis.x * dash_dir * (0.8 + 0.4 * sin(_time * 6.0))
	if jump_time > 0.0:
		pos.y += sin(jump_time / 0.7 * PI) * 0.9
	bobber.global_position = pos


func _catch() -> void:
	Sfx.play("splash_big", bobber.global_position, -3.0)
	Sfx.play("catch")
	var f := _hooked_fish
	var tn := get_tree().get_first_node_in_group("tournament")
	if tn:
		tn.report_catch(f.id, _hooked_kg)
	Inventory.add_fish(f.id, _hooked_kg)
	_announce("%s поймал(а): %s, %.2f кг" % [player.player_name, f.display_name, _hooked_kg])
	_finish("Поймал: %s, %.2f кг (%s)" % [f.display_name, _hooked_kg, FishData.rarity_name(f.rarity)],
		FishData.rarity_color(f.rarity))
	player.show_catch(f.id)


func _finish(message: String, color: Color) -> void:
	Sfx.loop("reel", false)
	dash_dir = 0
	jump_time = 0.0
	nibble = 0.0
	if message != "":
		Events.notify(message, color)
	if _tween and _tween.is_valid():
		_tween.kill()
	state = State.IDLE
	charge = 0.0
	tension = 0.0
	reeling = false
	surge = false
	in_reeds = false
	heavy = false
	_bite_pending = false
	_hooked_fish = null
	_cast_rod_slot = {}
	_cast_bait = &""
	_throw_t = -1.0
	_hook_t = -1.0
	bobber.visible = false


func cancel() -> void:
	if state != State.IDLE:
		_finish("", Color.WHITE)


## Словами: насколько далеко рыба и сколько у неё сил.
func distance_word() -> String:
	var k := distance / maxf(start_distance, 0.01)
	var d := "Рыба далеко" if k > 0.7 else ("Рыба ближе…" if k > 0.35 else "Рыба совсем рядом!")
	var s := "" if stamina > 60 else (" · устаёт" if stamina > 25 else " · выдохлась!")
	return d + s


func _announce(text: String) -> void:
	if Net.is_online() and multiplayer.get_peers().size() > 0:
		show_announcement.rpc(text)


# ---------------------------------------------------------------- сеть

@rpc("any_peer", "reliable")
func request_bite(cast_id: int, bait_id: StringName, drunk: float, where: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != player.get_multiplayer_authority():
		return
	if GameData.get_bait(bait_id) == null:
		return
	drunk = clampf(drunk, 0.0, 100.0)
	Weather.update_conditions(get_tree())
	var f := GameData.roll_fish(bait_id, _rng, drunk, where)
	var kg := GameData.roll_weight(f, _rng, drunk, where)
	var delay := GameData.roll_bite_delay(bait_id, _rng, drunk)
	var owner_id := player.get_multiplayer_authority()
	NetUtil.call_peer(self, owner_id, "receive_bite", [cast_id, delay, f.id, kg])


@rpc("any_peer", "reliable")
func receive_bite(cast_id: int, delay: float, fish_id: StringName, kg: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	if cast_id != _cast_id or state != State.WAITING:
		return
	_hooked_fish = GameData.get_fish(fish_id)
	_hooked_kg = kg
	_bite_timer = delay
	_bite_pending = _hooked_fish != null


@rpc("any_peer", "reliable")
func show_announcement(text: String) -> void:
	Events.notify(text, Color(0.75, 0.85, 1.0))


# ---------------------------------------------------------------- леска

func _draw_line() -> void:
	_imesh.clear_surfaces()
	if not bobber.visible:
		return
	var a: Vector3 = player.get_rod_tip()
	var b: Vector3 = bobber.global_position
	var fighting: bool = player.fish_state == State.FIGHT
	var sag := 0.05 if fighting else 0.25 + a.distance_to(b) * 0.03
	_imesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	const SEGMENTS := 16
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		_imesh.surface_add_vertex(a.lerp(b, t) + Vector3.DOWN * sin(t * PI) * sag)
	_imesh.surface_end()


## Анимация рук от первого лица и вращение ручки катушки. Вызывается из игрока после его кадра.
func apply_hand_anim(delta: float) -> void:
	if not player.is_multiplayer_authority() or player.third_person:
		_spin_reel(player.model, delta)
		return
	if _throw_t >= 0.0:
		_throw_t += delta
		if _throw_t > 0.45:
			_throw_t = -1.0
	if _hook_t >= 0.0:
		_hook_t += delta
		if _hook_t > 0.35:
			_hook_t = -1.0
	var hand: Node3D = player.fp_hand
	var rot := Vector3.ZERO
	match state:
		State.CHARGING:
			var c := charge
			rot = Vector3(0.85 + c * 0.55, 0.18, 0.22)
		State.FLYING:
			var u := clampf(_throw_t / 0.16, 0.0, 1.0) if _throw_t >= 0.0 else 1.0
			if u < 1.0:
				rot = Vector3(lerpf(1.3, -1.05, u), lerpf(0.2, -0.12, u), lerpf(0.2, -0.1, u))
			else:
				var rest := clampf((_throw_t - 0.16) / 0.28, 0.0, 1.0) if _throw_t >= 0.0 else 1.0
				rot = Vector3(lerpf(-1.05, -0.15, rest), lerpf(-0.12, 0.0, rest), 0.0)
		State.WAITING:
			rot = Vector3(-0.12 + sin(_time * 1.6) * 0.03, 0.0, 0.0)
		State.BITE:
			rot = Vector3(-0.1, sin(_time * 18.0) * 0.12, 0.0)
		State.FIGHT:
			if _hook_t >= 0.0 and _hook_t < 0.22:
				var j := sin(clampf(_hook_t / 0.22, 0.0, 1.0) * PI)
				rot = Vector3(-0.85 * j, 0.0, 0.15 * j)
			else:
				var pump := sin(_time * 7.0) * 0.18
				rot = Vector3(-0.2 + pump, 0.0, 0.05)
		_:
			rot = Vector3.ZERO
	var k := minf(delta * 14.0, 1.0)
	hand.rotation = hand.rotation.lerp(rot, k)
	_spin_reel(player._fp_item, delta)
	_spin_reel(player.model, delta)


func _spin_reel(from: Node, delta: float) -> void:
	if from == null:
		return
	var crank := from.find_child("ReelCrank", true, false) as Node3D
	if crank == null:
		return
	if state == State.FIGHT and reeling:
		crank.rotate_x(delta * 14.0)
	elif state == State.FIGHT:
		crank.rotate_x(delta * 3.5)

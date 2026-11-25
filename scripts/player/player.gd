extends CharacterBody3D
## Игрок: ходьба, плавание, камера 1/3 лица, взаимодействие взглядом,
## предмет в руках (панель 1-9), выпивка, еда, курение, туалет, драки, броски бутылок,
## сон, укрытия, переноска коробок, передача денег.
## Узел называется по peer id владельца — каждый компьютер управляет только своим игроком.

const WALK_SPEED := 4.5
const SPRINT_SPEED := 7.5
const SWIM_SPEED := 2.3
const JUMP_VELOCITY := 4.8
const MOUSE_SENSITIVITY := 0.0025
const INTERACT_DISTANCE := 3.5
## Куда возвращают после нокаута — к дому.
const SOBER_PER_SEC := 0.18
const HEAL_PER_SEC := 0.3
const THROW_SPEED := 15.0
const BOTTLE_HIT_DAMAGE := 18.0
## Нужды (в секунду)
const HUNGER_PER_SEC := 0.07
const BLADDER_PER_SEC := 0.08
const BOWEL_PER_SEC := 0.03
const STINK_TIME := 120.0
## Драка
const FIST := {"damage": 7.0, "range": 1.8, "cooldown": 0.55, "pose": "punch"}
const BAT := {"damage": 25.0, "range": 2.5, "cooldown": 0.85, "pose": "swing"}
## Перегар: рядом с сильно пьяным пьянеешь сам.
const FUMES_RADIUS := 3.2
const FUMES_DRUNK := 70.0
const FUMES_PER_SEC := 0.45

# Рассылаются другим игрокам через MultiplayerSynchronizer (узел Sync).
@export var player_name: String = "Рыбак"
@export var head_pitch: float = 0.0
@export var fish_state: int = 0
@export var bobber_pos: Vector3 = Vector3.ZERO
@export var held_kind: String = ""
@export var held_id: StringName = &""
@export var held_cond: float = 100.0
@export var drunk: float = 0.0
@export var pose: String = "idle"
@export var stinky: float = 0.0
@export var skin: Dictionary = {}
@export var sleeping: bool = false
@export var hidden: bool = false
@export var carrying: bool = false
## Что несём: "box" (коробка) или "sack" (мешок с фермы).
@export var carry_kind: String = "box"
@export var light_on: bool = false
## В каком транспорте сидим (путь к узлу) и на каком месте (0 — водитель).
@export var vehicle_path: String = ""
@export var seat: int = -1

@onready var head: Node3D = $Head
@onready var fp_camera: Camera3D = $Head/FPCamera
@onready var spring_arm: SpringArm3D = $Head/SpringArm3D
@onready var tp_camera: Camera3D = $Head/SpringArm3D/TPCamera
@onready var body: Node3D = $Body
@onready var model: CharacterModel = $Body/Model
@onready var fp_hand: Node3D = $Head/FPHand
@onready var name_label: Label3D = $NameLabel
@onready var fishing: FishingController = $Fishing
@onready var interact_area: Area3D = $InteractArea
@onready var collision: CollisionShape3D = $Collision

var third_person := false
var swimming := false
## Короткая пауза после захвата мыши, чтобы этот же клик не сработал как действие.
var input_cooldown := 0.0
var focus: Interactable = null
var hide_spot: Node3D = null

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _t := 0.0
var _lurch_timer := 3.0
var _knocked_out := false
var _action := ""            ## "drink", "eat", "pee", "poop", "smoke", "bait", "swing", "punch"
var _action_timer := 0.0
var _attack_cd := 0.0
var _shown_held := "-"
var _fp_item: Node3D
var _fp_rod_tip: Marker3D
var _fp_extra: Node3D
var _last_pos := Vector3.ZERO
var _hunger_warn := 0.0
var _fumes_warn := 0.0
var _stink_fx: CPUParticles3D
var _smoke_fx: CPUParticles3D
var _pee_fx: CPUParticles3D
var _flies: Array[Node3D] = []
var _status_label: Label3D
var _hic_label: Label3D
var _hic_timer := 4.0
var _styled_for := {}
var _base_face := "neutral"
var _bed_return := Vector3.ZERO
var _hide_return := Vector3.ZERO
var _head_base_y := 1.6
var _pitch_before := 0.0
var _snd_pose := ""
var _step_acc := 0.0
var _pee_snd: AudioStreamPlayer3D
var vehicle: Node3D = null
var _seat_yaw := 0.0
var _veh_send := 0.0
var _flashlight: SpotLight3D
## Тост: кто предложил и до какого времени можно чокнуться.
var _toast_from := 0
var _toast_name := ""
var _toast_until := 0.0
var _toast_said: Label3D
## «Белочка»: сколько подряд держится сильное опьянение и идёт ли горячка.
var _drunk_hi := 0.0
var _belochka: Node3D


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	add_to_group("players")
	spring_arm.add_excluded_object(get_rid())
	_build_fx()
	_flashlight = SpotLight3D.new()
	_flashlight.spot_range = 30.0
	_flashlight.spot_angle = 30.0
	_flashlight.spot_attenuation = 0.6
	_flashlight.light_energy = 8.0
	_flashlight.light_color = Color(1.0, 0.95, 0.8)
	_flashlight.position = Vector3(0.15, -0.1, -0.2)
	_flashlight.visible = false
	head.add_child(_flashlight)
	_toast_said = Label3D.new()
	_toast_said.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_toast_said.no_depth_test = true
	_toast_said.font_size = 40
	_toast_said.pixel_size = 0.006
	_toast_said.outline_size = 10
	_toast_said.modulate = Color(1.0, 0.9, 0.5)
	_toast_said.position.y = 2.65
	_toast_said.visible = false
	add_child(_toast_said)
	_last_pos = global_position
	name_label.font_size = 46
	name_label.outline_size = 14
	name_label.pixel_size = 0.0055
	name_label.position.y = 2.3
	if is_multiplayer_authority():
		add_to_group("local_player")
		player_name = Net.player_name
		skin = Saves.skin.duplicate()
		_style_model()
		global_position = Net.spawn_position
		rotation.y = Net.spawn_rotation
		name_label.visible = false
		_status_label.visible = false
		Inventory.changed.connect(refresh_held)
		Inventory.selection_changed.connect(refresh_held)
		refresh_held()
		_apply_camera_mode()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		input_cooldown = 0.3


## Внешность из скина игрока (выбирается в главном меню).
func _style_model() -> void:
	_styled_for = skin.duplicate()
	if skin.is_empty():
		var h := absi(hash(player_name))
		model.apply_skin({"shirt": h % 10, "pants": (h / 3) % 6, "hat": 1 + (h / 7) % 3, "hat_color": (h / 5) % 7,
			"face": (h / 11) % 4})
	else:
		model.apply_skin(skin)
	_base_face = model.face_name
	_shown_held = "-"


func _build_fx() -> void:
	_stink_fx = _particles(Color(0.45, 0.62, 0.12, 0.55), 0.07, 24, Vector3(0, 1.0, 0))
	_stink_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_stink_fx.emission_sphere_radius = 0.5
	_stink_fx.gravity = Vector3(0, 0.5, 0)
	_stink_fx.scale_amount_min = 0.6
	_stink_fx.scale_amount_max = 1.8
	_smoke_fx = _particles(Color(0.85, 0.85, 0.85, 0.45), 0.05, 14, Vector3(0, 1.72, -0.25))
	_smoke_fx.gravity = Vector3(0, 0.35, 0)
	_smoke_fx.direction = Vector3(0, 0.4, -1)
	_smoke_fx.spread = 25.0
	_smoke_fx.scale_amount_max = 2.5
	_pee_fx = _particles(Color(1.0, 0.88, 0.25, 0.9), 0.02, 40, Vector3(0, 0.85, -0.25))
	_pee_fx.lifetime = 0.7
	_pee_fx.direction = Vector3(0, 0.3, -1)
	_pee_fx.spread = 4.0
	_pee_fx.initial_velocity_min = 2.0
	_pee_fx.initial_velocity_max = 2.4
	_pee_fx.gravity = Vector3(0, -9.8, 0)
	_pee_fx.local_coords = false
	for i in 4:
		var f := Art.add_mesh(self, Art.sphere(0.014, 4), Art.color(Color(0.05, 0.05, 0.05)), Vector3.ZERO)
		f.visible = false
		_flies.append(f)
	_status_label = Label3D.new()
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.no_depth_test = true
	_status_label.font_size = 32
	_status_label.outline_size = 10
	_status_label.pixel_size = 0.005
	_status_label.position.y = 2.08
	add_child(_status_label)
	_hic_label = Label3D.new()
	_hic_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hic_label.font_size = 40
	_hic_label.outline_size = 10
	_hic_label.pixel_size = 0.005
	_hic_label.text = "ик!"
	_hic_label.modulate = Color(1, 0.8, 0.6, 0)
	add_child(_hic_label)


func _particles(color: Color, size: float, amount: int, pos: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 2.0
	p.direction = Vector3.UP
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.4
	var m := Art.sphere(size, 6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	p.mesh = m
	p.position = pos
	p.emitting = false
	add_child(p)
	return p


func get_rod_tip() -> Vector3:
	if is_multiplayer_authority() and not third_person and _fp_rod_tip:
		return _fp_rod_tip.global_position
	return model.get_rod_tip()


func _apply_camera_mode() -> void:
	fp_camera.current = not third_person
	tp_camera.current = third_person
	body.visible = third_person and not hidden
	fp_hand.visible = not third_person and not sleeping and not hidden


func _exclude_vehicle_from_camera(v: Node3D, on: bool) -> void:
	if v == null:
		return
	var nodes: Array = [v]
	nodes.append_array(v.find_children("*", "CollisionObject3D", true, false))
	for n in nodes:
		if not (n is CollisionObject3D):
			continue
		var rid: RID = (n as CollisionObject3D).get_rid()
		if on:
			spring_arm.add_excluded_object(rid)
		else:
			spring_arm.remove_excluded_object(rid)


func look_dir() -> Vector3:
	var cam := fp_camera if not third_person else tp_camera
	return -cam.global_basis.z


func is_busy_body() -> bool:
	return _knocked_out or _action != "" or sleeping or hidden


## Обновить, что в руках (после смены ячейки/износа).
func refresh_held() -> void:
	if not is_multiplayer_authority():
		return
	var s = Inventory.selected_slot()
	held_kind = s.kind if s else ""
	held_id = s.id if s else &""
	held_cond = s.get("cond", 100.0) if s else 100.0
	if carrying:
		held_kind = ""
	_update_fp_item()


func _update_fp_item() -> void:
	var key := "%s:%s:%s:%s:%s" % [held_kind, held_id, held_cond <= 0.0, carrying, carry_kind]
	if key == _shown_held:
		return
	_shown_held = key
	if _fp_item:
		_fp_item.queue_free()
		_fp_item = null
		_fp_rod_tip = null
	if carrying:
		_fp_item = ItemModels.build("box", &"box")
		_fp_item.position = Vector3(-0.32, -0.25, -0.15)
		fp_hand.add_child(_fp_item)
	elif held_kind != "":
		_fp_item = ItemModels.build(held_kind, held_id, held_cond)
		fp_hand.add_child(_fp_item)
		match held_kind:
			"rod":
				_fp_item.rotation = Vector3(-0.8, 0, 0.05)
				_fp_item.position = Vector3(0.06, -0.55, 0.3)
				_fp_rod_tip = _fp_item.find_child("RodTip", true, false) as Marker3D
				if _fp_rod_tip == null:
					_fp_rod_tip = Marker3D.new()
					_fp_rod_tip.position = Vector3(0, 2.2, 0)
					_fp_item.add_child(_fp_rod_tip)
			"weapon":
				_fp_item.rotation = Vector3(-0.5, 0.2, -0.3)
				_fp_item.position = Vector3(0.05, -0.25, 0.1)
			_:
				_fp_item.position = Vector3(-0.05, -0.05, -0.05)
				_fp_item.rotation = Vector3(0.1, 0.4, 0)
	model.set_held(held_kind, held_id, held_cond)
	model.set_carry(carrying, carry_kind)


# ------------------------------------------------------------ ввод

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or Events.ui_open or _knocked_out:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and captured:
		var sens := MOUSE_SENSITIVITY * Settings.mouse_sens
		if vehicle:
			_seat_yaw -= event.relative.x * sens
		else:
			rotate_y(-event.relative.x * sens)
		head_pitch = clampf(head_pitch - event.relative.y * sens * (-1.0 if Settings.invert_y else 1.0), -1.45, 1.45)
		return
	if event is InputEventMouseButton and event.pressed and not captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		input_cooldown = 0.25
		return
	if event is InputEventMouseButton and event.pressed and not fishing.is_busy():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			Inventory.select((Inventory.selected + Inventory.HOTBAR - 1) % Inventory.HOTBAR)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			Inventory.select((Inventory.selected + 1) % Inventory.HOTBAR)
			return

	if _chug_on and (event.is_action("fish_action")):
		get_viewport().set_input_as_handled()
		return
	var handled := true
	if event.is_action_pressed("accept") and _offer.size() > 0:
		accept_dispute()
	elif event.is_action_pressed("dispute"):
		var t: Node = focus.get_parent() if focus else null
		if t and t.is_in_group("players") and t != self:
			var ui := get_tree().get_first_node_in_group("dispute_ui")
			if ui:
				ui.open(t)
		else:
			Events.notify("Посмотри на другого игрока, чтобы поспорить", Color.LIGHT_GRAY)
	elif event.is_action_pressed("ui_cancel"):
		_open_ui("pause_menu")
	elif event.is_action_pressed("inventory"):
		_open_ui("inventory_ui")
	elif event.is_action_pressed("map"):
		_open_ui("map_ui")
	elif event.is_action_pressed("toggle_camera"):
		third_person = not third_person
		_apply_camera_mode()
	elif event.is_action_pressed("flashlight"):
		toggle_flashlight()
	elif event.is_action_pressed("toast"):
		propose_toast()
	elif vehicle:
		if event.is_action_pressed("interact"):
			vehicle.request_exit()
		elif event.is_action_pressed("fish_action") and not fishing.is_busy() and Inventory.held_rod_slot() == null:
			use_selected()
		elif event.is_action_pressed("jump") and seat == 0:
			vehicle.honk()
	elif sleeping:
		if event.is_action_pressed("jump") or event.is_action_pressed("interact"):
			get_up()
	elif hidden:
		if event.is_action_pressed("interact") or event.is_action_pressed("jump"):
			exit_hide()
		elif event.is_action_pressed("pee"):
			start_toilet("pee")
		elif event.is_action_pressed("poop"):
			start_toilet("poop")
	elif event.is_action_pressed("interact"):
		if focus and focus.get_prompt(self) != "":
			focus.interact(self)
	elif event.is_action_pressed("gift"):
		if focus and focus.get_gift_prompt(self) != "":
			focus.gift(self)
	elif event.is_action_pressed("cycle_bait"):
		Inventory.cycle_bait()
		var b := GameData.get_bait(Inventory.equipped_bait)
		if b:
			_play_bait_anim()
			Events.notify("Насадил: %s" % b.display_name, Color(0.9, 0.9, 0.8))
	elif event.is_action_pressed("pee"):
		start_toilet("pee")
	elif event.is_action_pressed("poop"):
		start_toilet("poop")
	elif event.is_action_pressed("drop_cart"):
		if not Inventory.cart.is_empty() and Inventory.theft == Inventory.Theft.NONE:
			Inventory.drop_cart()
			Events.notify("Выложил всё обратно на полки", Color.LIGHT_GRAY)
	elif event.is_action_pressed("fish_action") and not fishing.is_busy() and Inventory.held_rod_slot() == null:
		if input_cooldown <= 0.0:
			use_selected()
	else:
		handled = false
		if not fishing.is_busy():
			for i in Inventory.HOTBAR:
				if event.is_action_pressed("slot_%d" % (i + 1)):
					Inventory.select(i)
					handled = true
	if handled:
		get_viewport().set_input_as_handled()


func _open_ui(group: String) -> void:
	var ui := get_tree().get_first_node_in_group(group)
	if ui:
		ui.open()


## ЛКМ с предметом в руках (кроме удочки — ею ловит FishingController).
func use_selected() -> void:
	if is_busy_body():
		return
	if carrying:
		Events.notify("Руки заняты коробкой", Color.LIGHT_GRAY)
		return
	var s = Inventory.selected_slot()
	if s == null:
		_attack(FIST)
		return
	match s.kind:
		"drink":
			try_drink()
		"food":
			try_eat(Inventory.selected)
		"bait":
			Inventory.equip_bait(s.id)
			_play_bait_anim()
			Events.notify("Насадил: %s" % GameData.item_name("bait", s.id), Color(0.9, 0.9, 0.8))
		"bottle":
			throw_bottle()
		"weapon":
			_attack(BAT)
		"smoke":
			try_smoke()
		"tool":
			if s.id == &"net":
				var nets := get_tree().get_first_node_in_group("nets")
				if nets:
					nets.try_place(self)
		"misc":
			if s.id == &"brine":
				drink_brine()


func _update_focus() -> void:
	var from := head.global_position
	var to := from + look_dir() * INTERACT_DISTANCE
	if third_person:
		to += look_dir() * 1.5
	# Стены (слой 1) тоже ловят луч — чтобы нельзя было «покупать сквозь стену».
	var q := PhysicsRayQueryParameters3D.create(from, to, Interactable.LAYER | 1)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.exclude = [interact_area.get_rid(), get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	focus = hit.collider as Interactable if not hit.is_empty() and hit.collider is Interactable else null


# ------------------------------------------------------------ выпивка, еда, курение

func try_drink() -> void:
	if is_busy_body() or swimming:
		return
	if fishing.state not in [FishingController.State.IDLE, FishingController.State.WAITING]:
		return
	var d := Inventory.take_drink()
	if d == null:
		Events.notify("Выпить нечего. Сходи в «Шестёрочку» или «Бухло и Табак»", Color.LIGHT_GRAY)
		return
	_drink(d, "")


func _drink(d: DrinkData, from_name: String) -> void:
	_begin_action("drink", 1.1)
	if hangover > 0.0:
		cure_hangover(0.5 if d.strength >= 25.0 else 0.25, "Опохмелился… полегчало")
	_check_toast_join()
	Inventory.add_drunk(d.strength)
	Inventory.damage(d.health_cost)
	Inventory.bladder = minf(Inventory.bladder + d.bladder, 100.0)
	Inventory.stat_add("drinks")
	var line: String = ["*глык-глык*", "Ухх, хорошо пошла!", "За клёв!", "*крякнул*"].pick_random()
	if from_name != "":
		line = "%s угостил(а) тебя: %s. %s" % [from_name, d.display_name, line]
	Events.notify(line, Color(1.0, 0.85, 0.5))
	var drink_id := d.id
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		var bottles := get_tree().get_first_node_in_group("bottles")
		if bottles and is_inside_tree():
			var side := global_basis.x * randf_range(-0.6, 0.6) - global_basis.z * 0.5
			bottles.request_drop(drink_id, global_position + side + Vector3.UP * 1.2))


func try_eat(slot_index: int) -> void:
	if is_busy_body():
		return
	var s = Inventory.slot(slot_index)
	if s == null:
		return
	var name_txt := GameData.item_name(s.kind, s.id)
	if Inventory.eat_slot(slot_index):
		_begin_action("eat", 1.0)
		Events.notify("Съел: %s. *ням*" % name_txt, Color.PALE_GREEN)


func try_smoke() -> void:
	if is_busy_body() or swimming:
		return
	var s = Inventory.selected_slot()
	if s == null or s.kind != "smoke":
		return
	var m := GameData.get_misc(s.id)
	Inventory.remove_slot(Inventory.selected)
	_begin_action("smoke", 4.0)
	Inventory.calm_time = maxf(Inventory.calm_time, 0.0) + 90.0 * m.power
	Inventory.satiety = minf(Inventory.satiety + 6.0, 100.0)
	Inventory.damage(1.0 * m.power)
	Inventory.stat_add("smokes")
	_show_fp_extra("cig", Vector3(-0.12, -0.08, -0.1), 4.0)
	Events.notify(["*затянулся*", "Эх, хорошо…", "*кашляет*"].pick_random(), Color(0.85, 0.85, 0.85))


@rpc("any_peer", "reliable")
func receive_drink(drink_id: StringName, from_name: String) -> void:
	if not is_multiplayer_authority():
		return
	var d := GameData.get_drink(drink_id)
	if d:
		_drink(d, from_name)


func _begin_action(what: String, time: float) -> void:
	_action = what
	_action_timer = time


## Анимация насаживания наживки: кусочек летит к крючку.
func _play_bait_anim() -> void:
	if _action != "" or carrying:
		return
	_begin_action("bait", 1.1)
	var bait_id := Inventory.equipped_bait
	_show_fp_extra("bait", Vector3(-0.25, -0.15, -0.1), 1.1, bait_id)
	if _fp_extra:
		var tw := _fp_extra.create_tween()
		tw.tween_property(_fp_extra, "position", Vector3(0.0, 0.05, -0.25), 0.6)
		tw.tween_property(_fp_extra, "scale", Vector3.ONE * 0.2, 0.4)


## Временный предмет в левой руке от первого лица (сигарета, наживка).
func _show_fp_extra(kind: String, pos: Vector3, time: float, id: StringName = &"") -> void:
	if _fp_extra:
		_fp_extra.queue_free()
	_fp_extra = ItemModels.build(kind, id)
	_fp_extra.position = pos
	if kind == "cig":
		_fp_extra.rotation = Vector3(-1.2, 0, 0.4)
		_fp_extra.scale = Vector3.ONE * 1.6
	fp_hand.add_child(_fp_extra)
	var node := _fp_extra
	get_tree().create_timer(time).timeout.connect(func() -> void:
		if is_instance_valid(node):
			node.queue_free())


# ------------------------------------------------------------ драка

func _attack(w: Dictionary) -> void:
	if _attack_cd > 0.0 or swimming or fishing.is_busy():
		return
	_attack_cd = w.cooldown
	_begin_action(w.pose, 0.4)
	# Замах в руке от первого лица.
	var tw := fp_hand.create_tween()
	tw.tween_property(fp_hand, "rotation", Vector3(0.3, 0.6, 0.2), 0.12)
	tw.tween_property(fp_hand, "rotation", Vector3(-0.4, -0.5, -0.2), 0.12)
	tw.tween_property(fp_hand, "rotation", Vector3.ZERO, 0.2)
	get_tree().create_timer(0.16).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var target := _melee_target(w.range)
		var combat := get_tree().get_first_node_in_group("combat")
		if target and combat:
			combat.request_hit(target, w.damage * (1.0 + Inventory.drunk / 200.0)))


func _melee_target(reach: float) -> Node:
	var space := get_world_3d().direct_space_state
	var sh := SphereShape3D.new()
	sh.radius = 0.55
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	var dir := look_dir()
	dir.y = clampf(dir.y, -0.3, 0.3)
	q.transform = Transform3D(Basis(), head.global_position + dir.normalized() * reach * 0.6 + Vector3.DOWN * 0.3)
	q.collision_mask = 8
	q.exclude = [get_rid()]
	var best: Node = null
	var best_d := INF
	for r in space.intersect_shape(q, 8):
		var n: Node = r.collider
		var target := n
		while target and not target.is_in_group("players") and not target.has_method("on_melee_hit"):
			target = target.get_parent()
		if target == null or target == self:
			continue
		var d := (target as Node3D).global_position.distance_to(global_position)
		if d < best_d and d < reach + 0.8:
			best_d = d
			best = target
	return best


# ------------------------------------------------------------ участковый

var _jail_t := 0.0
var _jail_out := Vector3.ZERO
var _jail_solo := false
var _jail_skip := 0.0
var _digging := false


@rpc("any_peer", "reliable")
func police_warning(reason: String) -> void:
	if is_multiplayer_authority():
		Events.notify("За тобой идёт участковый! (%s) Беги или прячься" % reason, Color(0.5, 0.7, 1.0))
		Sfx.play("whistle")


## Посадили «на сутки».
@rpc("any_peer", "reliable")
func go_to_jail(secs: float, cell: Vector3, out: Vector3, reason: String, solo: bool) -> void:
	if not is_multiplayer_authority() or multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	if vehicle:
		vehicle.request_exit()
		exit_vehicle(false)
	if hidden:
		exit_hide()
	if carrying:
		drop_box("")
	fishing.cancel()
	Inventory.drop_cart()
	var fine := roundi(Inventory.money * 0.15)
	Inventory.money -= fine
	Inventory.drunk = 0.0
	Inventory.stat_add("jailed")
	Inventory.changed.emit()
	global_position = cell
	velocity = Vector3.ZERO
	_jail_t = secs
	_jail_out = out
	_jail_solo = solo
	_jail_skip = 8.0 if solo else 0.0
	_digging = false
	Events.blackout.emit("«На сутки»: %s. Штраф %d ₽" % [reason, fine])
	Events.notify("Сидишь в КПЗ (%d с). Под нарами — ложка: копай, когда дежурная не смотрит." % int(secs), Color(0.6, 0.75, 1.0))


func _tick_jail(delta: float) -> void:
	if _jail_t <= 0.0:
		return
	_jail_t -= delta
	if _jail_t <= 0.0:
		_release_from_jail()


func _release_from_jail() -> void:
	_jail_t = 0.0
	_digging = false
	global_position = _jail_out
	velocity = Vector3.ZERO
	if _jail_solo and _jail_skip > 0.05:
		var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
		if dc:
			dc.minutes = minf(dc.minutes + _jail_skip * 60.0, DayCycle.FAINT_MIN - 60.0)
		Events.notify("Отпустили. На улице уже другое время.", Color(0.6, 0.75, 1.0))
	else:
		Events.notify("Отпустили. Смотри не попадайся снова.", Color(0.6, 0.75, 1.0))
	_jail_skip = 0.0


func jail_left() -> float:
	return _jail_t


func is_jailed() -> bool:
	return _jail_t > 0.0


func start_jail_dig() -> void:
	if _jail_t <= 0.0 or fishing.is_busy():
		return
	_digging = true


func stop_jail_dig() -> void:
	_digging = false


func apply_dig_stroke() -> void:
	if _jail_t <= 0.0:
		return
	_jail_t = maxf(0.4, _jail_t - (6.0 if _jail_solo else 12.0))
	if _jail_solo:
		_jail_skip = maxf(0.4, _jail_skip - 0.8)
	Events.notify("Земля поддалась. Осталось %d с." % int(_jail_t), Color(0.75, 0.85, 0.6))
	if _jail_t <= 0.5:
		_release_from_jail()


func jail_caught_digging() -> void:
	_digging = false
	_jail_t += 15.0
	if _jail_solo:
		_jail_skip += 1.0
	Events.notify("Дежурная видела. Накинули срок.", Color(1.0, 0.5, 0.4))


# ------------------------------------------------------------ споры на деньги

var _offer: Dictionary = {}       ## входящее предложение: {from, name, kind, stake, until}
var _dispute: Dictionary = {}     ## идущий спор: {opp, opp_name, kind, stake, t, goal}
var _goal_marker: Node3D
var _chug_on := false
var _chug_drunk := 0.0
var _chug_choke := 0.0
var _chug_ui: CanvasLayer
var _chug_bars: Array[ProgressBar] = []
var _chug_drink: StringName = &""

const STRONG := [&"vodka", &"samogon", &"cognac", &"port"]


func _strong_drink() -> StringName:
	for id in STRONG:
		if Inventory.count_of("drink", id) > 0:
			return id
	return &""


func can_dispute(kind: String, stake: int) -> String:
	if not _dispute.is_empty():
		return "Ты уже споришь!"
	if Inventory.money < stake:
		return "Денег на такой спор нет"
	if kind == "chug" and _strong_drink() == &"":
		return "Нужна крепкая бутылка: водка, самогон, коньяк или портвейн"
	if kind == "swim" and _swim_goal().is_empty():
		return "Отсюда переплывать нечего — подойди к берегу"
	return ""


func propose_dispute(t: Node, kind: String, stake: int) -> void:
	var peer := t.name.to_int()
	NetUtil.call_peer(t, peer, "dispute_offer", [multiplayer.get_unique_id(), player_name, kind, stake])
	Events.notify("Предложил спор %s на %d ₽. Ждём ответа…" % [t.player_name, stake], Color(1, 0.85, 0.5))


func _kind_text(kind: String) -> String:
	return "переплывёт озеро" if kind == "swim" else "выпьет бутылку залпом"


@rpc("any_peer", "reliable")
func dispute_offer(from: int, from_name: String, kind: String, stake: int) -> void:
	if not is_multiplayer_authority():
		return
	_offer = {"from": from, "name": from_name, "kind": kind, "stake": stake, "until": _t + 20.0}
	Events.notify("%s спорит на %d ₽, что %s! %s — принять" % [from_name, stake, _kind_text(kind), Controls.key_label("accept")], Color(1, 0.85, 0.4))
	Sfx.play("notify")


func accept_dispute() -> void:
	var o := _offer
	_offer = {}
	if o.is_empty() or _t > float(o.until):
		return
	if Inventory.money < int(o.stake):
		Events.notify("Не хватает денег, чтобы принять спор", Color.TOMATO)
		return
	Inventory.money -= int(o.stake)
	Inventory.changed.emit()
	var p := get_tree().get_root().get_node_or_null("World/Players/%d" % int(o.from))
	if p:
		NetUtil.call_peer(p, int(o.from), "dispute_accepted", [multiplayer.get_unique_id(), player_name, o.kind, o.stake])
		_dispute = {"opp": int(o.from), "opp_name": o.name, "kind": o.kind, "stake": int(o.stake), "watch": true}
		Events.notify("Спор принят! %s %s — посмотрим…" % [o.name, _kind_text(o.kind)], Color(1, 0.85, 0.4))


@rpc("any_peer", "reliable")
func dispute_accepted(opp: int, opp_name: String, kind: String, stake: int) -> void:
	if not is_multiplayer_authority():
		return
	var p := get_tree().get_root().get_node_or_null("World/Players/%d" % opp)
	if Inventory.money < stake or not _dispute.is_empty() or (kind == "chug" and _strong_drink() == &""):
		if p:
			NetUtil.call_peer(p, opp, "dispute_over", [player_name, false, kind, stake, true])
		return
	Inventory.money -= stake
	Inventory.changed.emit()
	_dispute = {"opp": opp, "opp_name": opp_name, "kind": kind, "stake": stake, "t": 0.0}
	Sfx.play("cheer", null, -8.0)
	if kind == "swim":
		var g := _swim_goal()
		_dispute.goal = g.goal
		_dispute.limit = g.limit
		_show_goal(g.goal)
		Events.notify("%s принял спор! Плыви к флагу на том берегу — %d с. Без лодки!" % [opp_name, int(g.limit)], Color(1, 0.85, 0.4))
	else:
		_start_chug()


## Финиш на том берегу: идём от игрока через озеро до суши.
func _swim_goal() -> Dictionary:
	var p := global_position
	var c: Vector2 = Terrain.FAR_C if p.z < -95.0 else Terrain.LAKE_C
	var d := Vector3(c.x - p.x, 0, c.y - p.z).normalized()
	var water := 0.0
	var started := false
	for i in 260:
		var q := p + d * float(i)
		var wet := Terrain.depth(q.x, q.z) > 0.4
		if wet:
			started = true
			water += 1.0
		elif started and water > 14.0:
			var goal := p + d * float(i + 2)
			goal.y = Terrain.height(goal.x, goal.z)
			return {"goal": goal, "limit": water / 1.7 + 25.0}
		elif started:
			return {}
		if i > 12 and not started:
			return {}
	return {}


func _show_goal(at: Vector3) -> void:
	if _goal_marker:
		_goal_marker.queue_free()
	_goal_marker = Node3D.new()
	get_parent().add_child(_goal_marker)
	_goal_marker.global_position = at
	Art.add_mesh(_goal_marker, Art.cyl(0.05, 0.05, 3.0, 6), Art.color(Color(0.4, 0.3, 0.2)), Vector3(0, 1.5, 0))
	Art.add_mesh(_goal_marker, Art.box(Vector3(0.9, 0.55, 0.02)), Build.glow_mat(Color(1.0, 0.25, 0.15), 1.5), Vector3(0.45, 2.7, 0))
	Art.add_mesh(_goal_marker, Art.cyl(0.4, 0.4, 40.0, 8), Build.glow_mat(Color(1.0, 0.5, 0.2, 0.25), 0.8), Vector3(0, 20.0, 0))
	Build.text(_goal_marker, Vector3(0, 3.4, 0), "ФИНИШ СПОРА", 40, Color(1, 0.8, 0.3), 0.005, 0.0, true).no_depth_test = true


func _tick_dispute(delta: float) -> void:
	if not _offer.is_empty() and _t > float(_offer.until):
		_offer = {}
	if _dispute.is_empty() or _dispute.get("watch", false):
		return
	_dispute.t = float(_dispute.t) + delta
	if _dispute.kind == "swim":
		if vehicle:
			_dispute_end(false, "На лодке не считается!")
			return
		var g: Vector3 = _dispute.goal
		if Vector2(g.x - global_position.x, g.z - global_position.z).length() < 5.0:
			_dispute_end(true, "Доплыл! Спор выигран")
		elif float(_dispute.t) > float(_dispute.limit):
			_dispute_end(false, "Не успел доплыть — спор проигран")
	elif _chug_on:
		_tick_chug(delta)


func _start_chug() -> void:
	_chug_drink = _strong_drink()
	_chug_on = true
	_chug_drunk = 0.0
	_chug_choke = 0.0
	if _chug_ui == null:
		_chug_ui = CanvasLayer.new()
		_chug_ui.layer = 5
		var pc := UiKit.panel(Vector2(460, 0))
		pc.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		pc.position.y -= 220
		_chug_ui.add_child(pc)
		var v := VBoxContainer.new()
		pc.add_child(v)
		v.add_child(UiKit.label("ЗАЛПОМ! Держи ЛКМ — пьёшь. Подкатывает — отпусти!", 17, Color(1, 0.85, 0.5)))
		for t in ["Выпито", "Подкатывает"]:
			var r := HBoxContainer.new()
			var l := UiKit.label(t, 15)
			l.custom_minimum_size.x = 120
			r.add_child(l)
			var b := UiKit.bar(Color(0.95, 0.85, 0.3) if t == "Выпито" else Color(0.95, 0.4, 0.25), Vector2(300, 18))
			r.add_child(b)
			v.add_child(r)
			_chug_bars.append(b)
		add_child(_chug_ui)
	_chug_ui.visible = true
	Events.notify("Спор принят! Открывай %s и — залпом!" % GameData.item_name("drink", _chug_drink), Color(1, 0.85, 0.4))


func _tick_chug(delta: float) -> void:
	var holding := Input.is_action_pressed("fish_action") and not Events.ui_open
	if holding:
		_chug_drunk += delta * 16.0
		_chug_choke += delta * (20.0 + Inventory.drunk * 0.3) + (randf() * 40.0 if randf() < delta * 1.2 else 0.0)
		_action = "drink"
		_action_timer = 0.2
		if fmod(_t, 0.25) < delta:
			Sfx.play("gulp", global_position + Vector3.UP * 1.5, -10.0, 0.15)
	else:
		_chug_choke = maxf(_chug_choke - delta * 38.0, 0.0)
	_chug_bars[0].value = _chug_drunk
	_chug_bars[1].value = _chug_choke
	_chug_bars[1].modulate = Color(1, 0.3, 0.2) if _chug_choke > 70.0 else Color.WHITE
	if _chug_choke >= 100.0:
		Sfx.play("cough", global_position + Vector3.UP * 1.5)
		Inventory.add_drunk(15.0)
		Inventory.remove_item("drink", _chug_drink, 1)
		_dispute_end(false, "Поперхнулся! Кашель, слёзы — спор проигран")
	elif _chug_drunk >= 100.0:
		Inventory.add_drunk(38.0)
		Inventory.remove_item("drink", _chug_drink, 1)
		Inventory.stat_add("drinks")
		var bottles := get_tree().get_first_node_in_group("bottles")
		if bottles:
			bottles.request_drop(_chug_drink, global_position - global_basis.z * 0.6 + Vector3.UP * 1.2)
		_dispute_end(true, "До дна! Даже не поморщился — спор выигран")


func _dispute_end(win: bool, line: String) -> void:
	var d := _dispute
	_dispute = {}
	_chug_on = false
	if _chug_ui:
		_chug_ui.visible = false
	if _goal_marker:
		_goal_marker.queue_free()
		_goal_marker = null
	var stake: int = d.stake
	if win:
		Inventory.money += stake * 2
		Inventory.stat_add("disputes_won")
		Sfx.play("cheer", null, -4.0)
		Events.notify("%s +%d ₽" % [line, stake * 2], Color(0.6, 1.0, 0.6))
	else:
		Events.notify("%s (−%d ₽)" % [line, stake], Color.TOMATO)
	Inventory.changed.emit()
	var p := get_tree().get_root().get_node_or_null("World/Players/%d" % int(d.opp))
	if p:
		NetUtil.call_peer(p, int(d.opp), "dispute_over", [player_name, win, d.kind, stake, false])


## Итог спора у второй стороны. cancelled — не состоялся (вернуть ставку).
@rpc("any_peer", "reliable")
func dispute_over(who: String, who_won: bool, kind: String, stake: int, cancelled: bool) -> void:
	if not is_multiplayer_authority():
		return
	_dispute = {}
	if cancelled:
		Inventory.money += stake
		Events.notify("%s передумал спорить. Деньги вернулись" % who, Color.LIGHT_GRAY)
	elif who_won:
		Events.notify("%s %s — ты проиграл спор (−%d ₽)" % [who, "доплыл" if kind == "swim" else "выпил до дна", stake], Color.TOMATO)
	else:
		Inventory.money += stake * 2
		Inventory.stat_add("disputes_won")
		Events.notify("%s не справился — спор твой! +%d ₽" % [who, stake * 2], Color(0.6, 1.0, 0.6))
	Inventory.changed.emit()


## Участковый поймал — окно «договориться».
@rpc("any_peer", "reliable")
func bribe_offer(police_path: NodePath, reason: String, secs: float) -> void:
	if not is_multiplayer_authority() or multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	if vehicle:
		vehicle.request_exit()
		exit_vehicle(false)
	if hidden:
		exit_hide()
	fishing.cancel()
	velocity = Vector3.ZERO
	var ui := get_tree().get_first_node_in_group("bribe_ui")
	for g in ["store_ui", "trader_ui", "casino_ui", "give_ui", "house_ui", "inventory_ui", "map_ui"]:
		var o := get_tree().get_first_node_in_group(g)
		if o and o.visible and o.has_method("close"):
			o.close()
	if ui:
		ui.offer(get_node(police_path), reason, secs)


## Врезались на машине/велике (присылает сервер).
@rpc("any_peer", "reliable")
func crash_hurt(amount: float) -> void:
	if not is_multiplayer_authority() or multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	Inventory.damage(amount)
	Events.notify(["Бах! Врезался…", "Ой, столб откуда-то взялся", "Тормоза придумали трусы… ай"].pick_random(), Color.TOMATO)
	if Inventory.health <= 0.0:
		knock_out("Разбился…")


## Нас ударили (присылает сервер).
@rpc("any_peer", "reliable")
func take_melee(amount: float, from_name: String) -> void:
	if not is_multiplayer_authority():
		return
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	if sleeping or _knocked_out:
		return
	if hidden:
		exit_hide()
	Inventory.damage(amount)
	Sfx.play("punch", global_position + Vector3.UP)
	if carrying:
		drop_box("Уронил коробку от удара!")
	Events.notify("%s бьёт тебя!" % from_name, Color.TOMATO)
	velocity += -global_basis.z * -3.5 + Vector3.UP * 1.5
	if Inventory.health <= 0.0:
		knock_out("Тебя вырубил %s…" % from_name)


# ------------------------------------------------------------ туалет

func start_toilet(what: String) -> void:
	if (is_busy_body() and not hidden) or fishing.is_busy() or swimming or carrying or _action != "":
		return
	if what == "pee":
		if Inventory.bladder < 12.0:
			Events.notify("Пока не хочется", Color.LIGHT_GRAY)
			return
		_begin_action("pee", 3.0)
		_pitch_before = head_pitch
		if not hidden:
			var tw := create_tween()
			tw.tween_property(self, "head_pitch", -0.85, 0.4)
		Events.notify("*журчит*", Color(0.95, 0.9, 0.5))
	else:
		if Inventory.bowel < 15.0:
			Events.notify("Пока не хочется", Color.LIGHT_GRAY)
			return
		_begin_action("poop", 4.0)
		Events.notify("*кряхтит*", Color(0.8, 0.65, 0.4))


func _in_outhouse() -> bool:
	return hidden and hide_spot != null and hide_spot.get("kind") == "outhouse"


func _finish_toilet(what: String, accident: bool) -> void:
	var mess := get_tree().get_first_node_in_group("mess")
	var shop := get_tree().get_first_node_in_group("shop") as ShopController
	var clean := _in_outhouse() and not accident
	if what == "pee":
		Inventory.bladder = 0.0
		if not hidden:
			var tw := create_tween()
			tw.tween_property(self, "head_pitch", _pitch_before, 0.4)
		if mess and not clean:
			mess.request_puddle(global_position - global_basis.z * 0.6)
		if accident:
			stinky = STINK_TIME * 0.5
	else:
		Inventory.bowel = 0.0
		Inventory.stat_add("poops")
		if mess and not clean:
			mess.request_poop(global_position + global_basis.z * 0.4)
		if accident:
			stinky = STINK_TIME
		elif not clean:
			Events.notify("Облегчился. Какашку можно подобрать (E) — на неё клюёт крупная рыба", Color(0.8, 0.65, 0.4))
	if clean:
		Events.notify("Культурно сходил в туалет", Color(0.8, 0.9, 0.8))
	elif shop and shop.is_inside(global_position):
		shop.report_mess()


func _accident(what: String) -> void:
	_finish_toilet(what, true)
	var txt := "%s %s!" % [player_name, "описался" if what == "pee" else "обделался"]
	if Net.is_online() and multiplayer.get_peers().size() > 0:
		fishing.show_announcement.rpc(txt)
	Events.notify("Не дотерпел… Теперь от тебя воняет. Искупайся в озере!", Color.ORANGE)


# ------------------------------------------------------------ бутылки и здоровье

func throw_bottle() -> void:
	if Inventory.count_of("bottle", &"empty") <= 0:
		return
	var bottles := get_tree().get_first_node_in_group("bottles")
	if bottles == null:
		return
	Inventory.remove_item("bottle", &"empty", 1)
	Inventory.stat_add("bottles_thrown")
	var dir := look_dir()
	var wobble := Inventory.drunk / 100.0 * 0.25
	dir = dir.rotated(Vector3.UP, randf_range(-wobble, wobble)).normalized()
	var pos := head.global_position + dir * 0.8
	bottles.request_throw(pos, dir * THROW_SPEED + Vector3.UP * 2.0 + velocity * 0.5)


@rpc("any_peer", "reliable")
func take_hit(amount: float, from_name: String) -> void:
	if not is_multiplayer_authority():
		return
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	Inventory.damage(amount)
	Events.notify("%s попал(а) в тебя бутылкой!" % from_name, Color.TOMATO)
	velocity += -look_dir() * 3.0


func knock_out(text: String) -> void:
	if _knocked_out:
		return
	if hidden:
		exit_hide()
	if vehicle:
		vehicle.request_exit()
		exit_vehicle(false)
	if carrying:
		drop_box("")
	_knocked_out = true
	_action = ""
	Inventory.stat_add("blackouts")
	fishing.cancel()
	Events.blackout.emit(text)
	await get_tree().create_timer(1.6).timeout
	global_position = Layout.spawn() + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1, 1))
	velocity = Vector3.ZERO
	Inventory.drunk = minf(Inventory.drunk, 40.0)
	Inventory.health = maxf(Inventory.health, 40.0)
	Inventory.satiety = maxf(Inventory.satiety, 30.0)
	var lost := 0
	if Inventory.money > 0:
		lost = roundi(Inventory.money * randf_range(0.2, 0.5))
		Inventory.money -= lost
	Inventory.drop_cart()
	Inventory.changed.emit()
	await get_tree().create_timer(1.6).timeout
	_knocked_out = false
	if lost > 0:
		Events.notify("Очнулся у дома. Карманы кто-то обчистил: −%d ₽" % lost, Color.TOMATO)
	else:
		Events.notify("Голова трещит… Как я дома оказался?", Color.LIGHT_GRAY)


## Ненадолго показать пойманную рыбу в руках.
func show_catch(fish_id: StringName) -> void:
	held_kind = "fish"
	held_id = fish_id
	model.set_held("fish", fish_id)
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if is_inside_tree():
			_shown_held = "-"
			refresh_held())


# ------------------------------------------------------------ сон

func go_to_bed(foot: Vector3, head_dir: Vector3) -> void:
	if sleeping or is_busy_body() or fishing.is_busy():
		return
	if carrying:
		drop_box("")
	_bed_return = global_position
	sleeping = true
	velocity = Vector3.ZERO
	collision.disabled = true
	global_position = foot
	rotation.y = atan2(head_dir.x, head_dir.z)
	_pitch_before = head_pitch
	head.position = Vector3(0, 0.55, 1.6)
	head_pitch = 1.35
	fp_hand.visible = false
	Events.notify("Лёг спать. Когда лягут все — хост выберет, до скольки спать. Пробел — встать", Color(0.8, 0.85, 1.0))


func get_up() -> void:
	var dc := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if dc and dc.phase == DayCycle.Phase.SUMMARY:
		return
	_leave_bed()


func _leave_bed() -> void:
	if not sleeping:
		return
	sleeping = false
	collision.disabled = false
	head.position = Vector3(0, _head_base_y, 0)
	head_pitch = 0.0
	global_position = _bed_return
	_apply_camera_mode()


## Вызывает DayCycle, когда начался новый день.
func wake_up() -> void:
	_leave_bed()


# ------------------------------------------------------------ похмелье

## 0..1 — насколько плохо. Проходит само за ~5 минут, быстрее — рассол или «опохмелиться».
var hangover := 0.0
var _hang_fx: CanvasLayer
var _hang_rect: ColorRect


func start_hangover(k: float) -> void:
	hangover = k
	Events.notify(["Голова раскалывается… где рассол?", "Ох… свет режет глаза. Рассольчику бы",
		"Вчера было хорошо. Сегодня — нет"].pick_random(), Color(0.9, 0.8, 0.6))
	if _hang_fx == null:
		_hang_fx = CanvasLayer.new()
		_hang_fx.layer = 2
		_hang_rect = ColorRect.new()
		_hang_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_hang_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
uniform float k = 0.0;
uniform float t = 0.0;
uniform sampler2D screen : hint_screen_texture, filter_linear;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float w = k * 0.006;
	uv += vec2(sin(t * 1.3 + uv.y * 6.0), cos(t * 1.1 + uv.x * 5.0)) * w;
	vec3 a = texture(screen, uv + c * k * 0.012).rgb;
	vec3 b = texture(screen, uv - c * k * 0.012).rgb;
	vec3 col = mix(a, b, 0.5);
	float pulse = 0.5 + 0.5 * sin(t * 2.2);
	col += vec3(1.0, 0.97, 0.9) * k * (0.12 + 0.1 * pulse);
	col = mix(col, vec3(dot(col, vec3(0.3, 0.59, 0.11))), k * 0.25);
	float vig = smoothstep(0.35, 0.85, length(c));
	col *= 1.0 - vig * k * 0.45;
	COLOR = vec4(col, 1.0);
}"""
		var m := ShaderMaterial.new()
		m.shader = sh
		_hang_rect.material = m
		_hang_fx.add_child(_hang_rect)
		add_child(_hang_fx)
	_hang_fx.visible = true


func cure_hangover(amount: float, line: String) -> void:
	if hangover <= 0.0:
		return
	hangover = maxf(hangover - amount, 0.0)
	Events.notify(line, Color(0.7, 1.0, 0.7))


func drink_brine() -> void:
	if is_busy_body() or swimming:
		return
	if not Inventory.remove_item("misc", &"brine", 1):
		return
	_begin_action("drink", 1.1)
	Sfx.play("gulp", global_position + Vector3.UP * 1.5, -6.0)
	Inventory.add_drunk(-12.0)
	if hangover > 0.0:
		hangover = 0.0
		Events.notify("Ах-х… рассольчик! Жизнь налаживается", Color(0.7, 1.0, 0.7))
	else:
		Events.notify("Солёненько. Протрезвел немного", Color(0.8, 0.95, 0.7))


func _tick_hangover(delta: float) -> void:
	if hangover <= 0.0:
		if _hang_fx and _hang_fx.visible:
			_hang_fx.visible = false
			head.rotation.z = 0.0
		return
	hangover = maxf(hangover - delta / 300.0, 0.0)
	var m := _hang_rect.material as ShaderMaterial
	m.set_shader_parameter("k", hangover)
	m.set_shader_parameter("t", _t)
	# камера чуть «плывёт»
	if not vehicle and not sleeping:
		head.rotation.z = sin(_t * 0.9) * 0.03 * hangover


# ------------------------------------------------------------ укрытия

func enter_hide(spot: Node3D, inside: Vector3, look_yaw: float) -> void:
	if hidden or is_busy_body() or fishing.is_busy():
		return
	if carrying:
		drop_box("")
	_hide_return = global_position
	hide_spot = spot
	hidden = true
	collision.disabled = true
	collision_layer = 0
	velocity = Vector3.ZERO
	global_position = inside
	rotation.y = look_yaw
	head_pitch = 0.0
	_apply_camera_mode()
	var hint := "Сидишь в укрытии. E — вылезти"
	if spot.get("kind") == "outhouse":
		hint += ". Здесь можно культурно сходить в туалет (Q)"
	Events.notify(hint, Color(0.75, 0.9, 0.75))


func exit_hide() -> void:
	if not hidden:
		return
	hidden = false
	if hide_spot and hide_spot.has_method("leave"):
		hide_spot.leave()
	hide_spot = null
	collision.disabled = false
	collision_layer = 8
	global_position = _hide_return
	_apply_camera_mode()


# ------------------------------------------------------------ коробки (подработка)

func pick_box(kind := "box") -> bool:
	if carrying or is_busy_body() or fishing.is_busy():
		return false
	carry_kind = kind
	carrying = true
	_shown_held = "-"
	refresh_held()
	return true


func deliver_box() -> bool:
	if not carrying:
		return false
	carrying = false
	_shown_held = "-"
	refresh_held()
	return true


## Споткнулся с коробкой: шатнуло, коробка разбилась.
func stumble() -> void:
	if not carrying:
		return
	velocity += -global_basis.z * 2.5 + Vector3.UP * 1.2
	var tw := create_tween()
	tw.tween_property(self, "head_pitch", head_pitch - 0.5, 0.12)
	tw.tween_property(self, "head_pitch", head_pitch, 0.35)
	if carry_kind == "sack":
		Sfx.play("sack", global_position)
		drop_box(["Уронил мешок — комбикорм по всей траве!", "Мешок порвался… Тётя Валя будет ругаться"].pick_random())
		return
	Sfx.play("box_break", global_position)
	Inventory.stat_add("boxes_broken")
	drop_box(["Споткнулся! Коробка вдребезги…", "Ой-ой… Коробка разбилась", "Запнулся о кочку — минус коробка"].pick_random())


func drop_box(text: String) -> void:
	if not carrying:
		return
	carrying = false
	_shown_held = "-"
	refresh_held()
	if text != "":
		Events.notify(text, Color.TOMATO)


# ------------------------------------------------------------ другой игрок смотрит на нас

func get_prompt(_by: Node) -> String:
	if is_multiplayer_authority() or sleeping:
		return ""
	return "Передать деньги или вещь — %s" % player_name


func interact(_by: Node) -> void:
	var ui := get_tree().get_first_node_in_group("give_ui")
	if ui:
		ui.open(self)


func get_gift_prompt(_by: Node) -> String:
	if is_multiplayer_authority():
		return ""
	var d := Inventory.get_drink()
	return "Угостить %s: %s" % [player_name, d.display_name] if d else ""


func gift(_by: Node) -> void:
	var d := Inventory.take_drink()
	if d:
		receive_drink.rpc_id(get_multiplayer_authority(), d.id, Net.player_name)
		Events.notify("Угостил %s: %s" % [player_name, d.display_name], Color(1.0, 0.85, 0.5))


## Передать деньги этому игроку (вызывает отправитель).
func send_money(amount: int) -> bool:
	if amount <= 0 or amount > Inventory.money:
		return false
	Inventory.money -= amount
	Inventory.changed.emit()
	receive_money.rpc_id(get_multiplayer_authority(), amount, Net.player_name)
	Events.notify("Передал %s: %d ₽" % [player_name, amount], Color.GOLD)
	return true


## Передать вещь из ячейки.
func send_item(slot_index: int) -> bool:
	var s = Inventory.slot(slot_index)
	if s == null:
		return false
	var data := {"kind": s.kind, "id": String(s.id), "count": s.count, "cond": s.get("cond", 100.0)}
	Inventory.remove_slot(slot_index, s.count)
	receive_item.rpc_id(get_multiplayer_authority(), data, Net.player_name)
	Events.notify("Отдал %s: %s" % [player_name, GameData.item_name(data.kind, StringName(data.id))], Color.GOLD)
	return true


@rpc("any_peer", "reliable")
func receive_money(amount: int, from_name: String) -> void:
	if not is_multiplayer_authority():
		return
	Inventory.money += maxi(amount, 0)
	Inventory.changed.emit()
	Sfx.play("coin")
	Events.notify("%s передал тебе %d ₽" % [from_name, amount], Color.GOLD)


@rpc("any_peer", "reliable")
func receive_item(data: Dictionary, from_name: String) -> void:
	if not is_multiplayer_authority():
		return
	var kind: String = data.kind
	var id := StringName(data.id)
	if Inventory.add_item(kind, id, int(data.count), false, float(data.get("cond", 100.0))):
		Events.notify("%s отдал тебе: %s" % [from_name, GameData.item_name(kind, id)], Color.GOLD)
	else:
		# Не влезло — возвращаем.
		var sender := multiplayer.get_remote_sender_id()
		var back := get_tree().get_root().get_node_or_null("World/Players/%d" % sender)
		if back:
			back.receive_item.rpc_id(sender, data, "Инвентарь %s полон, вещь вернулась" % player_name)
		Events.notify("%s пытался что-то отдать, но инвентарь полон" % from_name, Color.TOMATO)


# ------------------------------------------------------------ кадр

var _pp_prev := Vector3.ZERO     ## где был в начале последнего тика физики
var _head_off := Vector3.ZERO    ## сдвиг головы (камеры) для плавности между тиками


func _process(delta: float) -> void:
	# В транспорте садимся по сглаженному положению каждый кадр отрисовки (а не только в физике) — без дёрганья.
	if vehicle and is_multiplayer_authority():
		_follow_vehicle()
	_smooth_camera()
	_t += delta
	name_label.text = player_name
	# Внешний вид — у всех, кто видит этого игрока.
	model.drunk = drunk / 100.0
	model.stinky = stinky > 0.0
	model.fish_state = fish_state
	model.pose = pose
	var flat := global_position - _last_pos
	flat.y = 0.0
	model.speed = lerpf(model.speed, flat.length() / maxf(delta, 0.001), minf(delta * 10.0, 1.0))
	_last_pos = global_position
	var face := _base_face
	if pose == "ko" or pose == "sleep":
		face = "sleep"
	elif pose == "crouch":
		face = "angry"
	elif drunk > 45.0:
		face = "drunk"
	model.set_face(face)
	_sound_tick(flat.length())
	_flashlight.visible = light_on and not hidden and not sleeping
	_toast_said.visible = _toast_said.modulate.a > 0.02
	_toast_said.modulate.a = maxf(_toast_said.modulate.a - delta * 0.25, 0.0)
	if not is_multiplayer_authority() and vehicle_path != "":
		var v := get_node_or_null(vehicle_path) as Node3D
		if v and v.has_method("seat_transform") and seat >= 0:
			global_position = v.seat_transform(seat).origin
	_stink_fx.emitting = stinky > 0.0 and not hidden
	_smoke_fx.emitting = pose == "smoke"
	_pee_fx.emitting = pose == "pee" and not hidden
	_pee_fx.global_basis = global_basis
	for i in _flies.size():
		var f := _flies[i]
		f.visible = stinky > 0.0 and not hidden
		if f.visible:
			var a := _t * (4.0 + i) + i * 1.7
			f.position = Vector3(cos(a) * 0.45, 1.1 + sin(_t * 6.0 + i) * 0.35, sin(a) * 0.45)
	if not is_multiplayer_authority():
		_update_remote(delta)
		return

	_tick_needs(delta)
	_tick_fumes(delta)
	_tick_belochka(delta)
	_tick_jail(delta)
	_tick_hangover(delta)
	_tick_dispute(delta)
	drunk = Inventory.drunk
	stinky = maxf(stinky - delta, 0.0)
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	Inventory.calm_time = maxf(Inventory.calm_time - delta, 0.0)

	# Поза
	if _knocked_out:
		pose = "ko"
	elif sleeping:
		pose = "sleep"
	elif vehicle:
		pose = "sit_fish" if fishing.is_busy() else (vehicle.seat_pose(seat) if _action == "" else _action)
	elif swimming:
		pose = "swim"
	elif _action in ["drink", "eat", "pee", "smoke", "bait", "swing", "punch"]:
		pose = _action
	elif _action == "poop":
		pose = "crouch"
	elif carrying:
		pose = "carry"
	elif fishing.is_busy():
		pose = "fish"
	else:
		pose = "idle"

	if _action != "":
		_action_timer -= delta
		if _action_timer <= 0.0:
			var done := _action
			_action = ""
			if done == "pee" or done == "poop":
				_finish_toilet(done, false)

	# Камера плывёт у пьяного (сигарета успокаивает).
	var d := drunk / 100.0 * (0.6 if Inventory.calm_time > 0.0 else 1.0)
	for cam in [fp_camera, tp_camera]:
		cam.rotation.z = sin(_t * 0.7) * 0.12 * d
		cam.rotation.x = sin(_t * 1.13) * 0.05 * d
	fp_camera.fov = Settings.fov + sin(_t * 0.5) * 6.0 * d
	tp_camera.fov = Settings.fov
	if not sleeping:
		var hy := 0.95 if _action == "poop" else _head_base_y
		head.position.y = lerpf(head.position.y, hy, delta * 6.0)
		if _action == "poop":
			head.position.x = sin(_t * 30.0) * 0.008
	if fishing.is_busy():
		fishing.apply_hand_anim(delta)
	elif _action == "drink" or _action == "smoke":
		fp_hand.rotation.x = lerpf(fp_hand.rotation.x, -0.5, delta * 10.0)
	elif _action != "swing" and _action != "punch":
		fp_hand.rotation = fp_hand.rotation.lerp(Vector3.ZERO, minf(delta * 10.0, 1.0))
	fp_hand.position.y = lerpf(fp_hand.position.y, -0.5 if swimming else -0.32, delta * 8.0)
	_update_focus()


# ------------------------------------------------------------ фонарик

func toggle_flashlight() -> void:
	if Inventory.count_of("tool", &"flashlight") <= 0:
		light_on = false
		Events.notify("Нет фонарика. Продаётся в «Шестёрочке»", Color.LIGHT_GRAY)
		return
	light_on = not light_on
	Sfx.play("click", null, -6.0)


# ------------------------------------------------------------ тосты

const TOASTS := ["За клёв!", "Ну, за рыбалку!", "Чтоб клевало и не срывалось!", "За тех, кто в лодке!",
	"Чтоб удочка не ломалась!", "Будем!", "За щуку на десять кило!", "Ну, со свиданьицем!"]


## T — поднять тост. Кто рядом выпьет в ближайшие 8 секунд — чокнется с тобой.
func propose_toast() -> void:
	if is_busy_body():
		return
	if Inventory.get_drink() == null:
		Events.notify("Нечем чокаться — нужна бутылка", Color.LIGHT_GRAY)
		return
	var line: String = TOASTS.pick_random()
	NetUtil.call_all(self, "toast_offer", [line])
	try_drink()


@rpc("any_peer", "call_remote", "reliable")
func toast_offer(line: String) -> void:
	_toast_said.text = "«%s»" % line
	_toast_said.modulate.a = 1.0
	var me := get_tree().get_first_node_in_group("local_player")
	if me and me != self and (me as Node3D).global_position.distance_to(global_position) < 7.0:
		me._toast_from = get_multiplayer_authority()
		me._toast_name = player_name
		me._toast_until = Time.get_ticks_msec() / 1000.0 + 8.0
		Events.notify("%s поднял тост: «%s» — выпей (ЛКМ), чтобы чокнуться!" % [player_name, line], Color(1.0, 0.85, 0.5))
	elif me == self:
		Events.notify("Ты: «%s»" % line, Color(1.0, 0.85, 0.5))


## Выпил, пока висел чужой тост, — чокнулись (бонус обоим).
func _check_toast_join() -> void:
	if _toast_from == 0 or Time.get_ticks_msec() / 1000.0 > _toast_until:
		return
	var other := get_tree().get_root().get_node_or_null("World/Players/%d" % _toast_from)
	_toast_from = 0
	_toast_bonus(_toast_name)
	if other:
		other.toast_joined.rpc_id(other.get_multiplayer_authority(), Net.player_name)


@rpc("any_peer", "reliable")
func toast_joined(who: String) -> void:
	if is_multiplayer_authority():
		_toast_bonus(who)


func _toast_bonus(with_name: String) -> void:
	Sfx.play("bottle_clink", global_position + Vector3.UP)
	Inventory.health = minf(Inventory.health + 6.0, Inventory.MAX_HEALTH)
	Inventory.satiety = minf(Inventory.satiety + 3.0, 100.0)
	Inventory.stat_add("toasts")
	Inventory.changed.emit()
	Events.notify("*дзынь* Чокнулись с %s! На душе потеплело" % with_name, Color(1.0, 0.85, 0.5))


# ------------------------------------------------------------ белочка

func _tick_belochka(delta: float) -> void:
	if Inventory.drunk >= 90.0 and not sleeping:
		_drunk_hi += delta
	else:
		_drunk_hi = maxf(_drunk_hi - delta * 2.0, 0.0)
	if (_belochka == null or not is_instance_valid(_belochka)) and _drunk_hi > 12.0 and Inventory.drunk >= 90.0:
		_belochka = load("res://scripts/player/belochka.gd").new()
		_belochka.player = self
		get_tree().root.add_child(_belochka)
		Inventory.stat_add("belochka")
	elif _belochka and is_instance_valid(_belochka) and Inventory.drunk < 60.0:
		_belochka.finish()
		_belochka = null
		_drunk_hi = 0.0


# ------------------------------------------------------------ транспорт

func enter_vehicle(v: Node3D, s: int) -> void:
	if hidden:
		exit_hide()
	if carrying:
		drop_box("Коробку пришлось бросить")
	fishing.cancel()
	vehicle = v
	seat = s
	vehicle_path = str(v.get_path())
	_seat_yaw = 0.0
	_exclude_vehicle_from_camera(v, true)
	collision.disabled = true
	velocity = Vector3.ZERO
	swimming = false
	_follow_vehicle()
	Events.notify(v.enter_hint(s), Color(0.8, 0.9, 1.0))


func exit_vehicle(into_water: bool) -> void:
	if vehicle == null:
		return
	var v := vehicle
	var p: Vector3 = v.exit_point(seat)
	_exclude_vehicle_from_camera(v, false)
	vehicle = null
	seat = -1
	vehicle_path = ""
	collision.disabled = false
	head.position.y = _head_base_y
	global_position = p
	rotation = Vector3(0, v.global_rotation.y + _seat_yaw, 0)
	velocity = Vector3.UP * (2.0 if into_water else 0.0)
	Sfx.loop("engine", false)
	Sfx.loop("oars", false)
	Sfx.loop("bike", false)


func _follow_vehicle() -> void:
	if not is_instance_valid(vehicle):
		exit_vehicle(false)
		return
	var t: Transform3D = vehicle.seat_transform(seat)
	global_position = t.origin
	rotation = Vector3(0, vehicle.smooth_yaw() + _seat_yaw, 0)
	head.position.y = lerpf(head.position.y, 1.05 if vehicle.kind != "bike" else 1.45, 0.2)
	velocity = Vector3.ZERO


## Водитель: W/S — газ/назад, A/D — руль. Отправляем хосту 20 раз в секунду.
func _drive(delta: float) -> void:
	_veh_send -= delta
	if _veh_send > 0.0:
		return
	_veh_send = 0.05
	var th := 0.0
	var st := 0.0
	if not Events.ui_open and not fishing.is_busy():
		th = Input.get_axis("move_back", "move_forward")
		st = Input.get_axis("move_left", "move_right")
	vehicle.send_input(th, st, Inventory.drunk)


## Звуки действий и шагов — у всех, кто рядом (по синхронизированной позе).
func _sound_tick(moved: float) -> void:
	if pose != _snd_pose:
		var p := global_position + Vector3.UP
		match pose:
			"drink":
				Sfx.play("bottle_open", p, -8.0)
				get_tree().create_timer(0.25).timeout.connect(func() -> void: Sfx.play("drink", global_position + Vector3.UP, -4.0))
				get_tree().create_timer(1.2).timeout.connect(func() -> void: Sfx.play("ah", global_position + Vector3.UP, -8.0))
			"eat": Sfx.play("eat", p, -4.0)
			"smoke":
				Sfx.play("lighter", p, -6.0)
				if drunk > 50.0:
					get_tree().create_timer(2.0).timeout.connect(func() -> void: Sfx.play("cough", global_position + Vector3.UP, -6.0))
			"punch", "swing": Sfx.play("whoosh", p, -6.0)
			"crouch": Sfx.play("poop", p, -6.0)
			"ko": Sfx.play("ko", p)
			"swim":
				if _snd_pose != "":
					Sfx.play("splash_big", p)
			"carry":
				if _snd_pose != "":
					Sfx.play("box_pick", p, -6.0)
		_snd_pose = pose
		if _pee_snd == null:
			_pee_snd = AudioStreamPlayer3D.new()
			_pee_snd.bus = "Effects"
			_pee_snd.stream = Sfx.stream_of("pee")
			_pee_snd.volume_db = -10.0
			_pee_snd.unit_size = 4.0
			_pee_snd.position = Vector3(0, 0.8, -0.4)
			add_child(_pee_snd)
		if pose == "pee" and not hidden:
			_pee_snd.play()
		else:
			_pee_snd.stop()
	# Шаги
	if pose in ["idle", "carry", "fish"] and not swimming and not sleeping and not hidden and is_on_floor_any():
		_step_acc += moved
		var stride := 0.9 if model.speed < 5.5 else 1.15
		if _step_acc >= stride:
			_step_acc = 0.0
			Sfx.play(_surface(), global_position, -26.0 if is_multiplayer_authority() else -22.0, 0.1)
	else:
		_step_acc = 0.0


func is_on_floor_any() -> bool:
	return is_on_floor() if is_multiplayer_authority() else true


## По чему идём: дорога/пол — «твёрдо», пирс и доски — «дерево», иначе трава.
func _surface() -> String:
	var p := global_position
	if absf(p.x) < 1.4 and p.z < -4.9 and p.z > -14.3:
		return "step_wood"
	if Layout.road_distance(p.x, p.z) < Layout.ROAD_W / 2 + 0.3:
		return "step_hard"
	for n in ["World/House"]:
		var b := get_tree().root.get_node_or_null(n) as Node3D
		if b and absf(b.to_local(p).x) < 4.5 and absf(b.to_local(p).z) < 3.5:
			return "step_wood"
	if Layout.is_busy(p.x, p.z, -0.5):
		return "step_hard"
	return "step_grass"


## Что видят другие: ник, «пьяный», «воняет», «ик!».
func _update_remote(delta: float) -> void:
	if skin != _styled_for:
		_style_model()
	var key := "%s:%s:%s:%s:%s" % [held_kind, held_id, held_cond <= 0.0, carrying, carry_kind]
	if key != _shown_held:
		_shown_held = key
		model.set_held(held_kind, held_id, held_cond)
		model.set_carry(carrying, carry_kind)
	body.visible = not hidden
	name_label.visible = not hidden
	var tags: Array[String] = []
	if drunk >= 80.0:
		tags.append("в стельку")
	elif drunk >= 45.0:
		tags.append("пьяный")
	if stinky > 0.0:
		tags.append("воняет")
	if sleeping:
		tags.append("спит")
	if drunk >= 90.0:
		tags.append("ловит белочку")
	_status_label.text = " · ".join(tags)
	_status_label.visible = not hidden and not tags.is_empty()
	_status_label.modulate = Color(0.75, 1.0, 0.45) if stinky > 0.0 else Color(1.0, 0.7, 0.5)
	name_label.modulate = Color(0.75, 1.0, 0.45) if stinky > 0.0 else Color.WHITE
	# «ик!» у пьяных
	if drunk >= 60.0 and not hidden and not sleeping:
		_hic_timer -= delta
		if _hic_timer <= 0.0:
			_hic_timer = randf_range(2.5, 6.0)
			Sfx.play("hic", global_position + Vector3(0, 1.6, 0), -6.0, 0.15)
			_hic_label.position = Vector3(randf_range(-0.3, 0.3), 1.9, 0)
			_hic_label.modulate.a = 1.0
			var tw := _hic_label.create_tween()
			tw.tween_property(_hic_label, "position:y", 2.6, 1.2)
			tw.parallel().tween_property(_hic_label, "modulate:a", 0.0, 1.2)


## Перегар: рядом с сильно пьяным игроком пьянеешь сам.
func _tick_fumes(delta: float) -> void:
	_fumes_warn = maxf(_fumes_warn - delta, 0.0)
	for p in get_tree().get_nodes_in_group("players"):
		if p == self or p.hidden or p.drunk < FUMES_DRUNK:
			continue
		if p.global_position.distance_to(global_position) < FUMES_RADIUS:
			Inventory.add_drunk(FUMES_PER_SEC * (p.drunk / 100.0) * delta)
			if _fumes_warn <= 0.0:
				_fumes_warn = 25.0
				Events.notify("От %s так разит перегаром, что у тебя кружится голова" % p.player_name,
					Color(1.0, 0.8, 0.55))


func _tick_needs(delta: float) -> void:
	Inventory.drunk = maxf(Inventory.drunk - SOBER_PER_SEC * delta, 0.0)
	var k := 0.25 if sleeping else 1.0
	Inventory.satiety = maxf(Inventory.satiety - HUNGER_PER_SEC * k * delta, 0.0)
	Inventory.bladder = minf(Inventory.bladder + BLADDER_PER_SEC * k * delta, 100.0)
	Inventory.bowel = minf(Inventory.bowel + BOWEL_PER_SEC * k * delta, 100.0)
	if Inventory.satiety < 10.0:
		Inventory.health = maxf(Inventory.health - 0.35 * delta, 0.0)
		_hunger_warn -= delta
		if _hunger_warn <= 0.0:
			_hunger_warn = 30.0
			Events.notify("Живот урчит… Надо поесть", Color.ORANGE)
	elif Inventory.health > 0.0:
		Inventory.health = minf(Inventory.health + HEAL_PER_SEC * delta, Inventory.MAX_HEALTH)
	if _knocked_out or sleeping:
		return
	if Inventory.drunk >= 99.9:
		knock_out("Ты вырубился…")
	elif Inventory.health <= 0.0:
		knock_out("Тебя вырубили…")
	elif Inventory.bladder >= 100.0 and _action == "":
		_accident("pee")
	elif Inventory.bowel >= 100.0 and _action == "":
		_accident("poop")
	# С коробкой можно споткнуться (чаще пьяным и на бегу/по кочкам) — коробка разбивается.
	if carrying:
		var moving := Vector2(velocity.x, velocity.z).length() > 0.5
		var chance := (0.012 + Inventory.drunk * 0.0006) if moving else 0.0
		if Inventory.drunk > 60.0:
			chance += 0.01 * Inventory.drunk / 60.0
		if randf() < chance * delta:
			stumble()


## Тело двигается 60 раз в секунду (физика), а кадров на мониторе бывает 144 — камера ступенькой.
## Сдвигаем голову туда, где тело «было бы» сейчас между тиками.
func _smooth_camera() -> void:
	if not is_multiplayer_authority():
		return
	head.position -= _head_off
	var off := Vector3.ZERO
	if not vehicle and not sleeping and _pp_prev.distance_to(global_position) < 2.0:
		var f := Engine.get_physics_interpolation_fraction()
		off = global_basis.inverse() * ((_pp_prev - global_position) * (1.0 - f))
	_head_off = off
	head.position += off


func _physics_process(delta: float) -> void:
	_pp_prev = global_position
	head.rotation.x = head_pitch
	if not is_multiplayer_authority():
		return

	input_cooldown = maxf(input_cooldown - delta, 0.0)
	if sleeping or hidden:
		velocity = Vector3.ZERO
		return
	if vehicle:
		_follow_vehicle()
		if seat == 0:
			_drive(delta)
		return
	var d := Inventory.drunk / 100.0
	_update_swimming()

	var can_move := not Events.ui_open and not _knocked_out and _action != "pee" and _action != "poop" \
		and _action != "smoke" and fishing.state == FishingController.State.IDLE

	var input := Vector2.ZERO
	if can_move:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if input != Vector2.ZERO and d > 0.05:
			input += Vector2(sin(_t * 0.9), sin(_t * 0.6) * 0.3) * 0.6 * d
		rotate_y(sin(_t * 0.45) * 0.003 * d)
	var dir := transform.basis * Vector3(input.x, 0, input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()

	if swimming:
		var spd := SWIM_SPEED * (1.4 if Input.is_action_pressed("sprint") else 1.0)
		velocity.x = move_toward(velocity.x, dir.x * spd, 8.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * spd, 8.0 * delta)
		var target_y := Terrain.WATER_Y - 1.3
		velocity.y = (target_y - global_position.y) * 3.0
		if can_move and Input.is_action_just_pressed("jump"):
			var ahead := global_position - global_basis.z * 1.0
			if Terrain.height(ahead.x, ahead.z) > Terrain.WATER_Y - 1.1:
				velocity.y = 5.5
				velocity += -global_basis.z * 2.5
			else:
				velocity.y = 2.0
	else:
		if not is_on_floor():
			velocity.y -= _gravity * delta
		if can_move and Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY
		var sprint := Input.is_action_pressed("sprint") and not carrying
		var speed := SPRINT_SPEED if sprint else WALK_SPEED
		speed *= 1.0 - 0.35 * d
		if carrying:
			speed *= 0.8
		# С тяжёлой добычей бежать труднее.
		if Inventory.theft == Inventory.Theft.CHASED:
			speed *= 1.0 - clampf(Inventory.theft_value / 2500.0, 0.0, 0.3)
		if Terrain.is_water(global_position.x, global_position.z) and global_position.y < Terrain.WATER_Y:
			speed *= 0.55
		if dir:
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed * 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0, speed * 10.0 * delta)
		if d > 0.55 and can_move:
			_lurch_timer -= delta
			if _lurch_timer <= 0.0:
				_lurch_timer = randf_range(1.5, 4.0)
				velocity += global_basis.x * randf_range(-1.0, 1.0) * 4.0 * d

	var was_air := not is_on_floor()
	var fall_speed := -velocity.y
	move_and_slide()
	# Прыгнул с коробкой и приземлился — половина шанса споткнуться.
	if carrying and was_air and is_on_floor() and fall_speed > 3.0 and randf() < 0.5:
		stumble()

	if global_position.y < -20.0:
		global_position = Layout.spawn()
		velocity = Vector3.ZERO


## Глубоко — плывём. Падение в воду трезвит и смывает вонь.
func _update_swimming() -> void:
	if vehicle:
		swimming = false
		return
	var p := global_position
	var deep := Terrain.depth(p.x, p.z) > 1.25 and p.y < Terrain.WATER_Y - 0.9
	if deep and not swimming:
		swimming = true
		fishing.cancel()
		_action = ""
		if carrying:
			drop_box("Коробка утонула…")
		Inventory.drunk = maxf(Inventory.drunk - 10.0, 0.0)
		if stinky > 0.0:
			stinky = 0.0
			Events.notify("Плюх! Заодно и помылся", Color(0.6, 0.85, 1.0))
		else:
			Events.notify("Плюх! Плыви к пологому берегу или к лестнице у пирса (Пробел — вылезти)",
				Color(0.6, 0.85, 1.0))
	elif swimming and not deep:
		swimming = false


## Лестница у пирса и другие точки, где можно выбраться.
func climb_to(point: Vector3) -> void:
	global_position = point
	velocity = Vector3.ZERO
	swimming = false

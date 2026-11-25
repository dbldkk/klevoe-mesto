extends CharacterBody3D
## Гость-драчун на гулянке в клубе. До драки сидит за столом, в драку — лезет к ближайшему игроку
## и бьёт. Вырубишь — лежит до конца праздника (и жених доплатит «за порядок»). Решает хост.

@export var guest_name: String = "Кум Серёга"
@export var skin_id: int = 0
@export var active: bool = false
@export var hp: float = 60.0
@export var down: bool = false

const SPEED := 3.6
const HIT := 4.0
const HITS_PER_TARGET := 4   ## потом «ладно, мир!» и ищет другого

var _home := Vector3.ZERO
var _target := 0
var _punch_cd := 0.0
var _punch_t := 0.0
var _think := 0.0
var _hits: Dictionary = {}       ## peer -> сколько раз ударил
var _rest := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var model: CharacterModel
var _label: Label3D
var _prev := Vector3.ZERO


func _ready() -> void:
	add_to_group("brawlers")
	add_to_group("npc")
	collision_layer = 8
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.38
	sh.height = 1.85
	cs.shape = sh
	cs.position.y = 0.93
	add_child(cs)
	model = CharacterModel.new()
	model.apply_skin([{"shirt": 4, "pants": 0, "skin": 2, "hat": 1, "hat_color": 0}, {"shirt": 1, "pants": 3, "skin": 0, "hat": 4}][skin_id % 2])
	model.fat = skin_id % 2 == 1
	add_child(model)
	model.set_face("player_b")
	_label = Build.text(self, Vector3(0, 2.2, 0), guest_name, 34, Color(1, 0.85, 0.7), 0.006, 0.0, true)
	_home = position


func display_name() -> String:
	return guest_name


func start_brawl() -> void:
	_hits.clear()
	active = true
	down = false
	hp = 60.0


func stop_brawl() -> void:
	active = false
	down = false
	hp = 60.0
	position = _home


func on_melee_hit(by: int, damage: float) -> void:
	if not multiplayer.is_server() or down:
		return
	if not active:
		active = true   # сам напросился
	_target = by
	hp -= damage
	if hp <= 0.0:
		down = true
		active = false
		var p := get_tree().get_root().get_node_or_null("World/Players/%d" % by)
		var club := get_tree().get_first_node_in_group("club")
		if p and club:
			club.call("_say", "%s успокоил %s! Жених благодарит!" % [p.player_name, guest_name])
			NetUtil.call_peer(club, by, "prize", [300, "навёл порядок на гулянке"])


func _physics_process(delta: float) -> void:
	if not Net.is_online():
		return
	var club := get_tree().get_first_node_in_group("club")
	var party_on: bool = club != null and int(club.kind) != 0
	visible = party_on
	_animate(delta)
	if not multiplayer.is_server():
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.5
	_punch_cd = maxf(_punch_cd - delta, 0.0)
	_punch_t = maxf(_punch_t - delta, 0.0)
	velocity.x = 0.0
	velocity.z = 0.0
	if not party_on or down or not active:
		if not down:
			var to := _home - position
			to.y = 0.0
			if to.length() > 0.5:
				var d: Vector3 = ((get_parent() as Node3D).global_basis * to).normalized()
				velocity.x = d.x * 1.5
				velocity.z = d.z * 1.5
		move_and_slide()
		return
	_think -= delta
	_rest -= delta
	if _rest > 0.0:
		move_and_slide()
		return
	if _think <= 0.0:
		_think = 2.0
		_target = _nearest(club as Node3D)
	var t := get_tree().get_root().get_node_or_null("World/Players/%d" % _target) as Node3D
	if t == null:
		move_and_slide()
		return
	var dir := t.global_position - global_position
	dir.y = 0.0
	var dist := dir.length()
	global_rotation.y = lerp_angle(global_rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 8.0, 0.0, 1.0))
	if dist > 1.3:
		dir = dir.normalized()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
	elif _punch_cd <= 0.0:
		_punch_cd = 1.6
		_punch_t = 0.4
		NetUtil.call_peer(t, _target, "take_melee", [HIT, guest_name])
		_hits[_target] = int(_hits.get(_target, 0)) + 1
		if int(_hits[_target]) >= HITS_PER_TARGET:
			_rest = 10.0
			_think = 0.0
			var club2 := get_tree().get_first_node_in_group("club")
			if club2:
				club2.call("_say", "%s: «Ладно-ладно, мир! Давай лучше выпьем»" % guest_name)
	move_and_slide()


func _nearest(club: Node3D) -> int:
	var best := 0
	var bd := 26.0
	for p in get_tree().get_nodes_in_group("players"):
		var pp := p as Node3D
		if p.hidden or p.sleeping or pp.global_position.distance_to(club.global_position) > 16.0:
			continue
		if int(_hits.get(p.name.to_int(), 0)) >= HITS_PER_TARGET:
			continue
		var d := pp.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = p.name.to_int()
	return best


func _animate(delta: float) -> void:
	var moved := global_position - _prev
	moved.y = 0.0
	_prev = global_position
	model.speed = lerpf(model.speed, moved.length() / maxf(delta, 0.001), minf(delta * 8.0, 1.0))
	model.drunk = 0.8
	if down:
		model.pose = "ko"
		_label.text = "%s · отдыхает" % guest_name
	elif active:
		model.pose = "punch" if _punch_t > 0.0 else "idle"
		model.set_face("angry")
		_label.text = "%s · «Ты меня уважаешь?!»" % guest_name
	else:
		model.pose = "sit"
		model.set_face("player_b")
		_label.text = guest_name

class_name ThimbleMan
extends CharacterBody3D
## Наперсточник Гоша. Играет в напёрстки (ставь что угодно, шанс маленький, выигрыш большой).
## Ударишь — даст сдачи. Вырубишь — выпадет его касса (часть всего, что он у вас выиграл).

enum S { NORMAL, HOSTILE, KO }

const MAX_HP := 120.0
const SPEED := 5.0
const PUNCH_DAMAGE := 15.0
const PUNCH_COOLDOWN := 1.0
const KO_TIME := 200.0
const START_BANK := 600

@export var state: int = S.NORMAL
@export var hp: float = MAX_HP

var bank: int = START_BANK          ## только на сервере
var dealer: CasinoDealer
var _target := 0
var _timer := 0.0
var _punch_cd := 0.0
var _punch_t := 0.0
var _post := Vector3.ZERO
var _post_rot := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _prev := Vector3.ZERO


func _ready() -> void:
	Chatter.attach.call_deferred(self, "m", SpeechBank.thimble(), 2.3, 6.0, "thimble")
	add_to_group("npc")
	_post = position
	_post_rot = rotation.y
	dealer = load("res://scripts/world/npc/casino_dealer.gd").new() as CasinoDealer
	dealer.name = "Dealer"
	dealer.game = "thimbles"
	dealer.dealer_name = "Гоша"
	dealer.face = "gosha"
	dealer.skin_data = {"shirt": 8, "pants": 1, "skin": 1, "hat": 1, "hat_color": 0, "face": 0}
	add_child(dealer)
	Net.hosted.connect(_load)
	Saves.before_save.connect(_save)
	Events.new_day.connect(func(_d: int) -> void:
		if multiplayer.is_server() and state == S.KO:
			state = S.NORMAL
			hp = MAX_HP)


func display_name() -> String:
	return "Гоша"


func can_play() -> bool:
	return state == S.NORMAL


func refuse_line() -> String:
	return "Гоша в отключке" if state == S.KO else "Гоша: «Ща я тебе сыграю!»"


## Ставка сыграла — Гоша копит выигрыш.
func on_bet_result(_peer: int, stake: int, result: Dictionary) -> void:
	if float(result.get("mult", 0)) <= 0.0:
		bank += stake
	else:
		bank = maxi(bank - stake * (int(result.mult) - 1), 100)


func on_melee_hit(by: int, damage: float) -> void:
	if not multiplayer.is_server() or state == S.KO:
		return
	hp -= damage
	if hp <= 0.0:
		state = S.KO
		_timer = KO_TIME
		var loot := roundi(bank * 0.6)
		bank = 300
		NetUtil.call_peer(self, by, "receive_loot", [loot])
		_announce("%s уложил Гошу! Из карманов выпало %d ₽" % [Net.peer_names.get(by, "Кто-то"), loot])
		var combat := get_tree().get_first_node_in_group("combat")
		if combat:
			combat.report_knockout(by, "Гоша в нокауте!")
		return
	if state != S.HOSTILE:
		_announce("Гоша: «Ах ты ж!..» — полез в драку")
	state = S.HOSTILE
	_target = by
	_timer = 20.0


@rpc("authority", "reliable")
func receive_loot(amount: int) -> void:
	Inventory.money += amount
	Inventory.stat_add("earned", amount)
	Inventory.changed.emit()
	Events.notify("Подобрал Гошину кассу: +%d ₽" % amount, Color.GOLD)


func _announce(text: String) -> void:
	NetUtil.call_all(self, "announce", [text])


@rpc("authority", "reliable")
func announce(text: String) -> void:
	Events.notify(text, Color(0.75, 0.85, 1.0))


func _physics_process(delta: float) -> void:
	if not Net.is_online():
		return
	_update_visual(delta)
	if not multiplayer.is_server():
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var goal := Vector3.INF
	velocity.x = 0.0
	velocity.z = 0.0
	match state:
		S.HOSTILE:
			_timer -= delta
			_punch_cd = maxf(_punch_cd - delta, 0.0)
			var t := get_tree().get_root().get_node_or_null("World/Players/%d" % _target) as Node3D
			if t == null or t.pose == "ko" or _timer <= 0.0 or t.global_position.distance_to(global_position) > 25.0:
				state = S.NORMAL
			else:
				var dist := t.global_position.distance_to(global_position)
				_face(t.global_position, delta * 6.0)
				if dist > 1.4:
					goal = t.global_position
				elif _punch_cd <= 0.0:
					_punch_cd = PUNCH_COOLDOWN
					_punch_t = 0.3
					NetUtil.call_peer(t, _target, "take_melee", [PUNCH_DAMAGE, "Гоша"])
		S.NORMAL:
			var post: Vector3 = (get_parent() as Node3D).to_global(_post)
			if global_position.distance_to(post) > 0.3:
				goal = post
			else:
				rotation.y = lerp_angle(rotation.y, _post_rot, delta * 3.0)
		S.KO:
			_timer -= delta
			if _timer <= 0.0:
				state = S.NORMAL
				hp = MAX_HP
				_announce("Гоша очухался и снова зазывает народ")
	if goal != Vector3.INF:
		var dir := goal - global_position
		dir.y = 0.0
		if dir.length() > 0.1:
			dir = dir.normalized()
			velocity.x = dir.x * SPEED
			velocity.z = dir.z * SPEED
			_face(global_position + dir, delta * 5.0)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	NpcMotion.move(self, delta)


func _face(p: Vector3, w: float) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() > 0.05:
		global_rotation.y = lerp_angle(global_rotation.y, atan2(-d.x, -d.z), clampf(w, 0.0, 1.0))


func _update_visual(delta: float) -> void:
	if dealer == null or dealer.model == null:
		return
	var m := dealer.model
	var moved := global_position - _prev
	moved.y = 0.0
	_prev = global_position
	m.speed = moved.length() / maxf(delta, 0.001)
	_punch_t = maxf(_punch_t - delta, 0.0)
	match state:
		S.KO:
			m.pose = "ko"
			m.set_face("sleep")
		S.HOSTILE:
			m.pose = "punch" if _punch_t > 0.0 else "idle"
			m.set_face("angry")
		_:
			m.pose = "talk" if int(Time.get_ticks_msec() / 1500) % 3 == 0 else "idle"
			m.set_face("gosha")


func _save() -> void:
	Saves.set_section("thimbles", {"bank": bank})


func _load() -> void:
	bank = int(Saves.get_section("thimbles").get("bank", START_BANK))
	state = S.NORMAL
	hp = MAX_HP

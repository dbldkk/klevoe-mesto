class_name CharacterModel
extends Node3D
## Человечек из простых форм с нарисованным лицом (в духе Schedule I).
## Сам анимирует ходьбу и позы. Смотрит вдоль -Z, стоит на y = 0.
##
## Снаружи задают: speed (м/с), pose, drunk (0..1), stinky, set_face(), set_held(), apply_skin().

enum Hat { NONE, CAP, BEANIE, USHANKA, BALD, BANGS }

## Палитры для выбора скина в меню.
const SHIRTS := [Color(0.3, 0.45, 0.3), Color(0.6, 0.22, 0.18), Color(0.2, 0.32, 0.6), Color(0.62, 0.52, 0.18),
	Color(0.32, 0.33, 0.36), Color(0.72, 0.42, 0.12), Color(0.45, 0.22, 0.5), Color(0.85, 0.85, 0.82),
	Color(0.12, 0.12, 0.14), Color(0.25, 0.55, 0.55)]
const PANTS := [Color(0.22, 0.24, 0.3), Color(0.15, 0.15, 0.16), Color(0.3, 0.35, 0.22), Color(0.42, 0.33, 0.22),
	Color(0.25, 0.3, 0.5), Color(0.5, 0.5, 0.52)]
const SKINS := [Color(0.95, 0.79, 0.66), Color(0.88, 0.68, 0.52), Color(0.72, 0.52, 0.38), Color(0.5, 0.35, 0.25),
	Color(1.0, 0.86, 0.76)]
const HAT_COLORS := [Color(0.2, 0.22, 0.25), Color(0.65, 0.14, 0.1), Color(0.25, 0.38, 0.2), Color(0.2, 0.3, 0.6),
	Color(0.85, 0.75, 0.2), Color(0.4, 0.3, 0.2), Color(0.9, 0.9, 0.9)]
const HAT_NAMES := ["Без шапки", "Кепка", "Шапка", "Ушанка", "Лысый", "Чёлка"]
const FACES := ["neutral", "smile", "player_b", "angry"]
const FACE_NAMES := ["Обычное", "Весёлое", "Небритое", "Суровое"]
const OUTFIT_NAMES := ["Обычный", "Друг из общаги"]
const LINGERIE_COLORS := [Color(0.08, 0.07, 0.08), Color(0.48, 0.08, 0.14), Color(0.3, 0.14, 0.32)]

@export var skin: Color = Color(0.93, 0.76, 0.62)
@export var shirt: Color = Color(0.3, 0.45, 0.3)
@export var pants: Color = Color(0.22, 0.24, 0.3)
@export var shoes: Color = Color(0.15, 0.12, 0.1)
@export var hat: Hat = Hat.CAP
@export var hat_color: Color = Color(0.2, 0.22, 0.25)
@export var hair_color: Color = Color(0.3, 0.2, 0.12)
@export var face_name: String = "neutral"
@export var outfit: int = 0   ## 0 обычный, 1 открытая цветочная рубашка и тёмные трусы
@export var female: bool = false
@export var lingerie: int = 0   ## 0 нет, 1 чёрное, 2 бордо, 3 фиолетовое (бра и трусики, без наготы)
@export var stockings: bool = false
@export var fat: bool = false
@export var height_scale: float = 1.0
@export var stripes: bool = false        ## тельняшка

## "idle", "fish", "drink", "eat", "swim", "crouch", "pee", "ko", "sit", "talk", "phone",
## "sleep", "swing", "punch", "smoke", "bait", "carry"
## Если true, каждый кадр подтягивает position.y к 0 (ноги на полу родителя).
## Выключить, если персонаж стоит на возвышении (сцена, пилон и т.п.).
var settle_floor: bool = true
var pose: String = "idle"
var fish_state: int = 0
var _last_fish_state: int = -1
var speed: float = 0.0
var drunk: float = 0.0
var stinky: bool = false
var head_tilt := Vector2.ZERO

var hips: Node3D
var spine: Node3D
var head: Node3D
var leg_l: Node3D
var leg_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var elbow_l: Node3D
var elbow_r: Node3D
var hand_socket: Node3D
var _face: MeshInstance3D
var _held: Node3D
var _held_kind := ""
var _rod_tip: Marker3D
var _box: Node3D
var _skin_mat: StandardMaterial3D
var _pants_mat: StandardMaterial3D
var _phase := 0.0
var _t := 0.0
var _pose_t := 0.0
var _last_pose := ""
var _built := false
var _shown_flush := -1.0
var _shown_dirty := false


func _ready() -> void:
	_build()


## Скин из словаря профиля: {shirt, pants, skin, hat, hat_color, face, stripes, outfit}
func apply_skin(d: Dictionary) -> void:
	shirt = SHIRTS[clampi(int(d.get("shirt", 0)), 0, SHIRTS.size() - 1)]
	pants = PANTS[clampi(int(d.get("pants", 0)), 0, PANTS.size() - 1)]
	skin = SKINS[clampi(int(d.get("skin", 0)), 0, SKINS.size() - 1)]
	hat = clampi(int(d.get("hat", 1)), 0, HAT_NAMES.size() - 1) as Hat
	hat_color = HAT_COLORS[clampi(int(d.get("hat_color", 0)), 0, HAT_COLORS.size() - 1)]
	face_name = FACES[clampi(int(d.get("face", 0)), 0, FACES.size() - 1)]
	stripes = bool(d.get("stripes", false))
	outfit = clampi(int(d.get("outfit", 0)), 0, OUTFIT_NAMES.size() - 1)
	if outfit == 1:
		hair_color = Color(0.16, 0.10, 0.07)
		shoes = Color(0.12, 0.10, 0.09)
	restyle()


func _build() -> void:
	if _built:
		return
	_built = true
	var shirt_m := Art.color(shirt, 0.85)
	_pants_mat = StandardMaterial3D.new()
	_pants_mat.albedo_color = pants
	_pants_mat.roughness = 0.9
	_skin_mat = StandardMaterial3D.new()
	_skin_mat.albedo_color = skin
	_skin_mat.roughness = 0.55
	_skin_mat.rim_enabled = true
	_skin_mat.rim = 0.15
	var skin_m := _skin_mat
	var pants_m := _pants_mat
	var shoe_m := Art.color(shoes, 0.6)

	hips = _pivot(self, Vector3(0, 0.9, 0))
	var is_lingerie := female and lingerie > 0
	var boxers := outfit == 1 and not is_lingerie
	var ling_m := Art.color(LINGERIE_COLORS[clampi(lingerie - 1, 0, LINGERIE_COLORS.size() - 1)], 0.55)
	var hip_scl := Vector3(1.2, 1.0, 0.95) if female else Vector3(1, 1, 0.85)
	var hip_mat: Material = ling_m if is_lingerie else (Art.color(Color(0.07, 0.07, 0.08), 0.9) if boxers else pants_m)
	Art.add_mesh(hips, Art.capsule(0.13, 0.4), hip_mat, Vector3(0, 0.0, 0), Vector3(0, 0, PI / 2), hip_scl)
	# ремень с пряжкой (не для короткого белья)
	if not boxers and not is_lingerie:
		var belt := Art.color(Color(0.14, 0.1, 0.08), 0.5)
		Art.add_mesh(hips, Art.cyl(0.2, 0.2, 0.05, 14), belt, Vector3(0, 0.08, 0), Vector3.ZERO, Vector3(1.0, 1, 0.66))
		Art.add_mesh(hips, Art.box(Vector3(0.06, 0.045, 0.02)), Art.color(Color(0.75, 0.7, 0.5), 0.3, 0.8), Vector3(0, 0.08, -0.135))

	var shorts_m := Art.color(Color(0.07, 0.07, 0.08), 0.9)
	var waist_m := Art.color(Color(0.92, 0.92, 0.93), 0.7)
	if boxers:
		Art.add_mesh(hips, Art.cyl(0.2, 0.2, 0.05, 12), waist_m, Vector3(0, 0.06, 0))
	if is_lingerie:
		Art.add_mesh(hips, Art.cyl(0.2, 0.2, 0.04, 12), ling_m, Vector3(0, 0.08, 0), Vector3.ZERO, Vector3(1.2 if female else 1.0, 1, 0.7))
	for side in [-1, 1]:
		var leg := _pivot(hips, Vector3(side * (0.12 if female else 0.1), -0.05, 0))
		var knee: Node3D
		if is_lingerie:
			var leg_m: Material = Art.color(Color(0.08, 0.06, 0.07), 0.35) if stockings else skin_m
			# трусики сверху и бедро до колена — иначе между тазом и икрами дыра, и тело «летит»
			Art.add_mesh(leg, Art.capsule(0.085, 0.22), ling_m, Vector3(0, -0.06, 0))
			Art.add_mesh(leg, Art.capsule(0.07, 0.46), leg_m, Vector3(0, -0.2, 0))
			knee = _pivot(leg, Vector3(0, -0.42, 0))
			Art.add_mesh(knee, Art.capsule(0.065, 0.44), leg_m, Vector3(0, -0.2, 0))
			# туфелька на каблуке, без логотипов
			Art.add_mesh(knee, Art.box(Vector3(0.1, 0.035, 0.2)), ling_m, Vector3(0, -0.43, -0.03))
			Art.add_mesh(knee, Art.cyl(0.014, 0.014, 0.07, 6), ling_m, Vector3(0, -0.48, 0.07))
			if side < 0:
				leg_l = leg
				knee_l = knee
			else:
				leg_r = leg
				knee_r = knee
			continue
		if boxers:
			Art.add_mesh(leg, Art.capsule(0.09, 0.28), shorts_m, Vector3(0, -0.1, 0))
			knee = _pivot(leg, Vector3(0, -0.42, 0))
			Art.add_mesh(knee, Art.capsule(0.07, 0.44), skin_m, Vector3(0, -0.2, 0))
			# простые тёмные тапки, без логотипов
			Art.add_mesh(knee, Art.box(Vector3(0.12, 0.03, 0.24)), Art.color(Color(0.1, 0.1, 0.1), 0.9), Vector3(0, -0.43, -0.04))
			if side < 0:
				leg_l = leg
				knee_l = knee
			else:
				leg_r = leg
				knee_r = knee
			continue
		Art.add_mesh(leg, Art.capsule(0.085, 0.46), pants_m, Vector3(0, -0.2, 0))
		knee = _pivot(leg, Vector3(0, -0.42, 0))
		Art.add_mesh(knee, Art.capsule(0.075, 0.44), pants_m, Vector3(0, -0.2, 0))
		Art.add_mesh(knee, Art.cyl(0.082, 0.082, 0.05, 10), pants_m, Vector3(0, -0.33, 0))   # отворот штанины
		# ботинок: подошва, верх, круглый носок
		Art.add_mesh(knee, Art.box(Vector3(0.13, 0.035, 0.27)), Art.color(Color(0.06, 0.05, 0.05), 0.9), Vector3(0, -0.425, -0.05))
		Art.add_mesh(knee, Art.box(Vector3(0.12, 0.07, 0.17)), shoe_m, Vector3(0, -0.375, -0.01))
		Art.add_mesh(knee, Art.sphere(0.065, 10), shoe_m, Vector3(0, -0.39, -0.12), Vector3.ZERO, Vector3(0.95, 0.6, 1.1))
		if side < 0:
			leg_l = leg
			knee_l = knee
		else:
			leg_r = leg
			knee_r = knee

	spine = _pivot(hips, Vector3(0, 0.08, 0))
	var floral := outfit == 1 and not is_lingerie
	var floral_m: Material = Art.floral(2.2) if floral else shirt_m
	var torso_m: Material = skin_m if (floral or is_lingerie) else shirt_m
	if stripes and not floral and not is_lingerie:
		torso_m = _striped(shirt)
	if floral:
		shirt_m = floral_m
	var tw := 0.92 if female else 1.05
	Art.add_mesh(spine, Art.capsule(0.2 if female else 0.22, 0.64), torso_m, Vector3(0, 0.28, 0), Vector3.ZERO, Vector3(tw, 1, 0.68))
	# плечи — чтобы руки не «торчали» из коробки
	var shw := 0.19 if female else 0.24
	for sd in [-1.0, 1.0]:
		Art.add_mesh(spine, Art.sphere(0.085 if female else 0.095, 10), skin_m if (floral or is_lingerie) else torso_m, Vector3(sd * shw, 0.5, 0), Vector3.ZERO, Vector3(1, 0.85, 1))
	if is_lingerie:
		# бра: чашки и лямки — одежда, не анатомия
		Art.add_mesh(spine, Art.cyl(0.16, 0.16, 0.045, 12), ling_m, Vector3(0, 0.36, -0.01), Vector3.ZERO, Vector3(1.1, 1, 0.7))
		for sd in [-1.0, 1.0]:
			var cup := Art.add_mesh(spine, Art.sphere(0.07, 10), ling_m, Vector3(sd * 0.075, 0.42, -0.12), Vector3.ZERO, Vector3(1.15, 0.85, 0.85))
			cup.name = "Bra"
			Art.add_mesh(spine, Art.box(Vector3(0.018, 0.22, 0.01)), ling_m, Vector3(sd * 0.13, 0.52, -0.02), Vector3(sd * -0.35, 0, 0))
	elif floral:
		# расстёгнутая короткая рубашка с цветочным принтом, грудь открыта
		for sd in [-1.0, 1.0]:
			var panel := Art.add_mesh(spine, Art.box(Vector3(0.16, 0.55, 0.04)), floral_m, Vector3(sd * 0.14, 0.3, -0.02), Vector3(0, sd * 0.55, sd * 0.15))
			panel.name = "FloralShirt"
		Art.add_mesh(spine, Art.box(Vector3(0.34, 0.06, 0.16)), floral_m, Vector3(0, 0.56, 0.0))  # ворот
	else:
		# воротник и пуговицы
		var collar := Art.color(shirt.darkened(0.25), 0.85)
		Art.add_mesh(spine, Art.cyl(0.1, 0.13, 0.06, 12), collar, Vector3(0, 0.58, 0.0))
		for k in 3:
			Art.add_mesh(spine, Art.sphere(0.012, 6), Art.color(shirt.darkened(0.45), 0.5), Vector3(0, 0.46 - k * 0.11, -0.152))
		# карман на груди
		Art.add_mesh(spine, Art.box(Vector3(0.09, 0.08, 0.01)), collar, Vector3(0.1, 0.43, -0.148))
	if fat:
		Art.add_mesh(spine, Art.sphere(0.21, 12), torso_m, Vector3(0, 0.16, -0.08), Vector3.ZERO, Vector3(1.1, 0.9, 0.9))

	head = _pivot(spine, Vector3(0, 0.6, 0))
	Art.add_mesh(head, Art.cyl(0.07, 0.08, 0.1, 8), skin_m, Vector3(0, 0.02, 0))
	Art.add_mesh(head, Art.sphere(0.2, 16), skin_m, Vector3(0, 0.19, 0), Vector3.ZERO, Vector3(1.0, 1.1, 0.95))
	for side in [-1, 1]:
		Art.add_mesh(head, Art.sphere(0.045, 8), skin_m, Vector3(side * 0.195, 0.18, 0.0), Vector3.ZERO, Vector3(0.6, 1, 1))
		Art.add_mesh(head, Art.sphere(0.02, 6), Art.color(skin.darkened(0.25), 0.6), Vector3(side * 0.205, 0.18, 0.0))   # ушная раковина
	# нос — «картошкой», щёки и подбородок
	var nose_s := 0.032 if female else 0.042
	Art.add_mesh(head, Art.sphere(nose_s, 10), skin_m, Vector3(0, 0.16, -0.198), Vector3.ZERO, Vector3(0.9, 1.0, 1.0))
	Art.add_mesh(head, Art.sphere(0.024 if female else 0.03, 8), Art.color(skin.lerp(Color(0.9, 0.4, 0.35), 0.35 if female else 0.25), 0.55), Vector3(0, 0.145, -0.215))
	Art.add_mesh(head, Art.sphere(0.12, 12), skin_m, Vector3(0, 0.07, -0.06), Vector3.ZERO, Vector3(1.1, 0.7, 1.0))
	if hat != Hat.BALD and not female:
		# бакенбарды / виски из-под шапки
		for side in [-1, 1]:
			Art.add_mesh(head, Art.box(Vector3(0.03, 0.09, 0.07)), Art.color(hair_color, 0.9), Vector3(side * 0.19, 0.22, 0.02))
	var quad := QuadMesh.new()
	quad.size = Vector2(0.34, 0.34)
	_face = Art.add_mesh(head, quad, Art.face(face_name), Vector3(0, 0.19, -0.184), Vector3(0, PI, 0))
	_face.rotation = Vector3(0, PI, 0)
	_build_hat()
	if female and hat != Hat.BALD:
		_build_long_hair()

	for side in [-1, 1]:
		var arm := _pivot(spine, Vector3(side * (0.22 if female else 0.27), 0.5, 0))
		var sleeve_m: Material = skin_m if is_lingerie else (floral_m if floral else (shirt_m if not stripes else torso_m))
		Art.add_mesh(arm, Art.capsule(0.065 if female else 0.07, 0.34), sleeve_m, Vector3(0, -0.14, 0))
		var elbow := _pivot(arm, Vector3(0, -0.29, 0))
		if is_lingerie or floral:
			Art.add_mesh(elbow, Art.capsule(0.055 if female else 0.06, 0.3), skin_m, Vector3(0, -0.12, 0))
		else:
			Art.add_mesh(elbow, Art.capsule(0.06, 0.3), shirt_m if not stripes else torso_m, Vector3(0, -0.12, 0))
			Art.add_mesh(elbow, Art.cyl(0.065, 0.06, 0.05, 10), Art.color(shirt.darkened(0.2), 0.85), Vector3(0, -0.25, 0))   # манжет
		# кисть: ладонь + большой палец
		Art.add_mesh(elbow, Art.box(Vector3(0.075, 0.1, 0.05)), skin_m, Vector3(0, -0.32, 0))
		Art.add_mesh(elbow, Art.sphere(0.04, 8), skin_m, Vector3(0, -0.375, -0.005), Vector3.ZERO, Vector3(0.95, 0.8, 0.7))
		Art.add_mesh(elbow, Art.capsule(0.018, 0.07), skin_m, Vector3(-side * 0.035, -0.31, -0.03), Vector3(0.4, 0, side * 0.5))
		if side < 0:
			arm_l = arm
			elbow_l = elbow
		else:
			arm_r = arm
			elbow_r = elbow
			hand_socket = _pivot(elbow, Vector3(0, -0.3, -0.02))
	scale = Vector3.ONE * height_scale
	_shown_flush = -1.0
	_shown_dirty = false


func _build_long_hair() -> void:
	var hm := Art.color(hair_color, 0.9)
	# объём сзади и длинные пряди — без усов и короткой мужской стрижки
	Art.add_mesh(head, Art.sphere(0.21, 12), hm, Vector3(0, 0.24, 0.05), Vector3.ZERO, Vector3(1.12, 0.95, 1.15))
	Art.add_mesh(head, Art.capsule(0.1, 0.5), hm, Vector3(0, -0.08, 0.14), Vector3(0.35, 0, 0))
	for s in [-1.0, 1.0]:
		Art.add_mesh(head, Art.capsule(0.045, 0.32), hm, Vector3(s * 0.17, 0.0, 0.04), Vector3(0.25, 0, s * 0.2))
	# чёлка
	Art.add_mesh(head, Art.box(Vector3(0.22, 0.07, 0.06)), hm, Vector3(0.0, 0.28, -0.16), Vector3(0.35, 0, 0))
	Art.add_mesh(head, Art.box(Vector3(0.08, 0.09, 0.05)), hm, Vector3(-0.08, 0.24, -0.18), Vector3(0.5, 0.1, 0))


func _build_hat() -> void:
	var hm := Art.color(hat_color, 0.85)
	match hat:
		Hat.CAP:
			Art.add_mesh(head, Art.sphere(0.205, 14), hm, Vector3(0, 0.24, 0), Vector3.ZERO, Vector3(1.02, 0.65, 1.0))
			Art.add_mesh(head, Art.box(Vector3(0.26, 0.025, 0.16)), hm, Vector3(0, 0.27, -0.24))
		Hat.BEANIE:
			Art.add_mesh(head, Art.sphere(0.21, 14), hm, Vector3(0, 0.27, 0), Vector3.ZERO, Vector3(1.03, 0.75, 1.03))
			Art.add_mesh(head, Art.sphere(0.05, 8), Art.color(hat_color.lightened(0.3)), Vector3(0, 0.44, 0))
		Hat.USHANKA:
			Art.add_mesh(head, Art.cyl(0.21, 0.22, 0.16, 14), hm, Vector3(0, 0.33, 0))
			for side in [-1, 1]:
				Art.add_mesh(head, Art.box(Vector3(0.05, 0.16, 0.16)), hm, Vector3(side * 0.21, 0.2, 0), Vector3(0, 0, side * 0.15))
			Art.add_mesh(head, Art.box(Vector3(0.3, 0.07, 0.04)), Art.color(hat_color.lightened(0.2)), Vector3(0, 0.35, -0.21))
		Hat.BALD:
			pass
		Hat.BANGS:
			var hm2 := Art.color(hair_color, 0.9)
			Art.add_mesh(head, Art.sphere(0.215, 14), hm2, Vector3(0, 0.26, 0.02), Vector3.ZERO, Vector3(1.05, 0.78, 1.08))
			# растрёпанная чёлка на глаза
			Art.add_mesh(head, Art.box(Vector3(0.22, 0.08, 0.08)), hm2, Vector3(-0.02, 0.28, -0.16), Vector3(0.35, 0.1, 0))
			Art.add_mesh(head, Art.box(Vector3(0.1, 0.1, 0.05)), hm2, Vector3(0.08, 0.24, -0.18), Vector3(0.6, -0.2, 0.2))
			Art.add_mesh(head, Art.box(Vector3(0.09, 0.11, 0.05)), hm2, Vector3(-0.1, 0.25, -0.17), Vector3(0.5, 0.15, -0.15))
			for side in [-1, 1]:
				Art.add_mesh(head, Art.box(Vector3(0.05, 0.14, 0.08)), hm2, Vector3(side * 0.18, 0.16, 0.0))
		_:
			Art.add_mesh(head, Art.sphere(0.205, 14), Art.color(hair_color, 0.9), Vector3(0, 0.24, 0.02), Vector3.ZERO, Vector3(1.02, 0.7, 1.0))
	_apply_lod()


## Оптимизация: мелкие детали (пуговицы, пряжка, уши, пальцы) не рисуем издалека и без теней;
## всего человека — не дальше 90 м.
func _apply_lod() -> void:
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var sz := mi.mesh.get_aabb().size * mi.scale
		var big := maxf(sz.x, maxf(sz.y, sz.z))
		if big < 0.13:
			mi.visibility_range_end = 16.0
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			mi.visibility_range_end = 90.0


func _striped(base: Color) -> StandardMaterial3D:
	var img := Image.create(8, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		var c := Color.WHITE if (y / 6) % 2 == 0 else base
		for x in 8:
			img.set_pixel(x, y, c)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.85
	return m


## Пересобрать после смены цветов/шапки.
func restyle() -> void:
	var held_kind := _held_kind
	for c in get_children():
		c.free()
	_held = null
	_held_kind = ""
	_rod_tip = null
	_box = null
	_built = false
	scale = Vector3.ONE
	_build()
	if held_kind != "":
		_held_kind = ""


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


# ------------------------------------------------------------ управление

func set_face(name: String) -> void:
	if name == face_name and _face:
		return
	face_name = name
	if _face:
		_face.material_override = Art.face(name)


## Что в правой руке. kind = "" — пусто.
func set_held(kind: String, id: StringName, cond: float = 100.0) -> void:
	_build()
	if _held:
		_held.queue_free()
		_held = null
		_rod_tip = null
	_held_kind = kind
	if kind == "":
		return
	_held = ItemModels.build(kind, id, cond)
	hand_socket.add_child(_held)
	match kind:
		"rod":
			_held.rotation = Vector3(-PI / 2 + 0.5, 0, 0)
			_held.position = Vector3(0, 0, 0.15)
			_rod_tip = _held.find_child("RodTip", true, false) as Marker3D
			if _rod_tip == null:
				_rod_tip = Marker3D.new()
				_rod_tip.position = Vector3(0, 2.2, 0)
				_held.add_child(_rod_tip)
		"weapon":
			_held.rotation = Vector3(-PI / 2 + 0.3, 0, 0)
			_held.position = Vector3(0, 0, 0.1)
		"fish":
			_held.scale = Vector3.ONE * 0.4
		_:
			_held.position = Vector3(0, -0.05, -0.02)


## Коробка в руках (подработка грузчиком).
var _box_kind := ""


func set_carry(on: bool, kind := "box") -> void:
	_build()
	if _box and (not on or kind != _box_kind):
		_box.queue_free()
		_box = null
	if on and _box == null:
		_box_kind = kind
		_box = ItemModels.build(kind, &"box")
		_box.position = Vector3(0, 0.12, -0.38)
		spine.add_child(_box)



## Позы ловли по синхронизированному fish_state (0 простой заброс, 1 зарядка, 2 бросок, …).
func _fish_arms(tgt: Dictionary) -> void:
	# 0 idle / 1 charge / 2 flying / 3 waiting / 4 bite / 5 fight
	match fish_state:
		1:
			tgt.arm_r = 2.4; tgt.elbow_r = 0.9; tgt.arm_l = 1.6; tgt.elbow_l = 1.1
			tgt.arm_rz = -0.4; tgt.spine_x = -0.15; tgt.spine_y = 0.25
		2:
			var u := clampf(_pose_t / 0.18, 0.0, 1.0)
			tgt.arm_r = lerpf(2.5, 0.7, u); tgt.elbow_r = lerpf(1.0, 0.25, u)
			tgt.arm_l = lerpf(1.6, 0.7, u); tgt.elbow_l = 0.7
			tgt.spine_y = lerpf(0.3, -0.2, u)
		4:
			tgt.arm_r = 1.0 + sin(_t * 16.0) * 0.25; tgt.elbow_r = 0.7
			tgt.arm_l = 0.9; tgt.elbow_l = 0.9; tgt.arm_lz = 0.35
		5:
			var pump := sin(_t * 7.0)
			tgt.arm_r = 1.15 + pump * 0.25; tgt.elbow_r = 0.85 - pump * 0.25
			tgt.arm_l = 1.0; tgt.elbow_l = 1.0; tgt.arm_lz = 0.4
			tgt.spine_x = 0.08
		_:
			tgt.arm_r = 1.0; tgt.elbow_r = 0.6; tgt.arm_l = 0.8; tgt.elbow_l = 0.9; tgt.arm_lz = 0.35


func get_rod_tip() -> Vector3:
	return _rod_tip.global_position if _rod_tip else global_position + Vector3.UP * 1.5


## Совместимость со старым кодом NPC.
func set_head_tilt(x: float, z: float = 0.0) -> void:
	head_tilt = Vector2(x, z)


func _update_materials() -> void:
	# Пьяный краснеет, вонючий — пятно на штанах.
	var flush := snappedf(clampf((drunk - 0.3) / 0.7, 0.0, 1.0), 0.05)
	if flush != _shown_flush:
		_shown_flush = flush
		_skin_mat.albedo_color = skin.lerp(Color(0.95, 0.42, 0.38), flush * 0.55)
	if stinky != _shown_dirty:
		_shown_dirty = stinky
		_pants_mat.albedo_color = pants.lerp(Color(0.35, 0.25, 0.08), 0.55) if stinky else pants


# ------------------------------------------------------------ анимация

func _process(delta: float) -> void:
	if not _built:
		return
	_t += delta
	if pose != _last_pose:
		_last_pose = pose
		_pose_t = 0.0
	if fish_state != _last_fish_state:
		_last_fish_state = fish_state
		_pose_t = 0.0
	_pose_t += delta
	_update_materials()
	var amp := clampf(speed / 4.5, 0.0, 1.3)
	_phase += delta * (4.0 + speed * 1.6) * (1.0 if amp > 0.05 else 0.0)
	var s := sin(_phase)
	var k := delta * 12.0

	var tgt := {
		"hips_y": 0.9 + absf(s) * 0.04 * amp, "root_x": 0.0, "spine_x": 0.05 * amp,
		"leg_l": s * 0.65 * amp, "leg_r": -s * 0.65 * amp,
		"knee_l": -maxf(0.0, -s) * 1.0 * amp, "knee_r": -maxf(0.0, s) * 1.0 * amp,
		"arm_l": -s * 0.55 * amp, "arm_r": s * 0.55 * amp, "arm_lz": -0.08, "arm_rz": 0.08,
		"elbow_l": 0.25 + 0.2 * amp, "elbow_r": 0.25 + 0.2 * amp, "head_x": 0.0, "spine_y": 0.0,
	}
	match pose:
		"fish":
			_fish_arms(tgt)
		"drink":
			tgt.arm_r = 2.5; tgt.elbow_r = 1.9; tgt.head_x = -0.4
		"eat":
			tgt.arm_r = 2.0; tgt.elbow_r = 2.1; tgt.head_x = 0.1
		"smoke":
			var puff := 0.5 + 0.5 * sin(_pose_t * 2.2)
			tgt.arm_r = 1.6 + 0.6 * puff; tgt.elbow_r = 1.6 + 0.6 * puff; tgt.head_x = -0.1
		"bait":
			tgt.arm_r = 1.0; tgt.elbow_r = 1.3; tgt.arm_l = 1.1; tgt.elbow_l = 1.4
			tgt.arm_lz = 0.35; tgt.arm_rz = -0.25; tgt.head_x = 0.55
		"carry":
			tgt.arm_r = 1.25 + s * 0.05 * amp; tgt.arm_l = 1.25; tgt.elbow_r = 0.5; tgt.elbow_l = 0.5
			tgt.arm_lz = 0.15; tgt.arm_rz = -0.15
		"swing":
			# Замах и удар за ~0.4 с.
			var t := clampf(_pose_t / 0.4, 0.0, 1.0)
			tgt.arm_r = lerpf(2.8, 0.9, t); tgt.elbow_r = lerpf(1.2, 0.2, t)
			tgt.spine_y = lerpf(0.5, -0.5, t); tgt.arm_l = 1.0; tgt.elbow_l = 0.8
		"punch":
			var t := clampf(_pose_t / 0.25, 0.0, 1.0)
			tgt.arm_r = lerpf(0.6, 1.55, t); tgt.elbow_r = lerpf(1.6, 0.05, t)
			tgt.spine_y = lerpf(0.3, -0.3, t); tgt.arm_l = 1.1; tgt.elbow_l = 1.8
		"talk":
			tgt.arm_r = 0.5 + sin(_t * 4.0) * 0.3; tgt.elbow_r = 0.9; tgt.arm_l = 0.3 + sin(_t * 3.1) * 0.2
		"phone":
			tgt.arm_r = 1.1; tgt.elbow_r = 1.9; tgt.head_x = 0.5
		"swim":
			tgt.root_x = -1.1
			tgt.arm_l = 1.5 + sin(_t * 3.0) * 1.3; tgt.arm_r = 1.5 + sin(_t * 3.0 + PI) * 1.3
			tgt.arm_lz = -0.6; tgt.arm_rz = 0.6
			tgt.leg_l = sin(_t * 6.0) * 0.35; tgt.leg_r = -sin(_t * 6.0) * 0.35
			tgt.head_x = -0.9
		"crouch":
			# Тужится: подрагивает.
			var strain := sin(_t * 18.0) * 0.015
			tgt.hips_y = 0.42 + strain; tgt.leg_l = 1.5; tgt.leg_r = 1.5; tgt.knee_l = -2.3; tgt.knee_r = -2.3
			tgt.arm_l = 0.7; tgt.arm_r = 0.7; tgt.elbow_l = 0.8; tgt.elbow_r = 0.8; tgt.spine_x = 0.35
		"pee":
			tgt.arm_l = 0.45; tgt.arm_r = 0.45; tgt.elbow_l = 0.7; tgt.elbow_r = 0.7; tgt.head_x = 0.5
			tgt.arm_lz = 0.3; tgt.arm_rz = -0.3
		"sit":
			tgt.hips_y = 0.5; tgt.leg_l = 1.5; tgt.leg_r = 1.5; tgt.knee_l = -1.5; tgt.knee_r = -1.5
		"sit_fish":
			tgt.hips_y = 0.5; tgt.leg_l = 1.5; tgt.leg_r = 1.5; tgt.knee_l = -1.5; tgt.knee_r = -1.5
			_fish_arms(tgt)
		"row":
			var r := sin(_t * 3.0)
			tgt.hips_y = 0.5; tgt.leg_l = 1.4; tgt.leg_r = 1.4; tgt.knee_l = -1.3; tgt.knee_r = -1.3
			tgt.arm_l = 1.1 + r * 0.6; tgt.arm_r = 1.1 + r * 0.6; tgt.elbow_l = 0.5 - r * 0.4; tgt.elbow_r = 0.5 - r * 0.4
			tgt.spine_x = 0.15 + r * 0.2
		"drive":
			tgt.hips_y = 0.5; tgt.leg_l = 1.4; tgt.leg_r = 1.4; tgt.knee_l = -1.4; tgt.knee_r = -1.4
			tgt.arm_l = 1.25; tgt.arm_r = 1.25; tgt.elbow_l = 0.5; tgt.elbow_r = 0.5; tgt.arm_lz = 0.15; tgt.arm_rz = -0.15
		"bike":
			var pd := sin(_t * 7.0 * clampf(speed / 4.0, 0.0, 1.5))
			tgt.hips_y = 0.85; tgt.spine_x = 0.3
			tgt.leg_l = 0.9 + pd * 0.5; tgt.leg_r = 0.9 - pd * 0.5; tgt.knee_l = -1.2 - pd * 0.4; tgt.knee_r = -1.2 + pd * 0.4
			tgt.arm_l = 1.1; tgt.arm_r = 1.1; tgt.elbow_l = 0.4; tgt.elbow_r = 0.4; tgt.arm_lz = 0.2; tgt.arm_rz = -0.2
		"ko":
			tgt.root_x = 1.45; tgt.hips_y = 0.25; tgt.arm_l = 2.8; tgt.arm_r = 0.4; tgt.arm_lz = -0.6
		"sleep":
			tgt.root_x = 1.5; tgt.hips_y = 0.9; tgt.arm_l = 0.2; tgt.arm_r = 0.2; tgt.arm_lz = -0.2; tgt.arm_rz = 0.2
			tgt.head_x = 0.1 + sin(_t * 1.2) * 0.03

	if settle_floor:
		position.y = lerpf(position.y, 0.0, k)
	rotation.x = lerp_angle(rotation.x, tgt.root_x, k * 0.5)
	hips.position.y = lerpf(hips.position.y, tgt.hips_y, k)
	spine.rotation.x = lerp_angle(spine.rotation.x, tgt.spine_x, k)
	spine.rotation.y = lerp_angle(spine.rotation.y, tgt.spine_y, k * 1.5)
	leg_l.rotation.x = lerp_angle(leg_l.rotation.x, tgt.leg_l, k)
	leg_r.rotation.x = lerp_angle(leg_r.rotation.x, tgt.leg_r, k)
	knee_l.rotation.x = lerp_angle(knee_l.rotation.x, tgt.knee_l, k)
	knee_r.rotation.x = lerp_angle(knee_r.rotation.x, tgt.knee_r, k)
	var ka := k * (2.5 if pose == "swing" or pose == "punch" else 1.0)
	arm_l.rotation.x = lerp_angle(arm_l.rotation.x, tgt.arm_l, ka)
	arm_r.rotation.x = lerp_angle(arm_r.rotation.x, tgt.arm_r, ka)
	arm_l.rotation.z = lerp_angle(arm_l.rotation.z, tgt.arm_lz, k)
	arm_r.rotation.z = lerp_angle(arm_r.rotation.z, tgt.arm_rz, k)
	elbow_l.rotation.x = lerp_angle(elbow_l.rotation.x, tgt.elbow_l, ka)
	elbow_r.rotation.x = lerp_angle(elbow_r.rotation.x, tgt.elbow_r, ka)

	# Пьяного качает; дыхание.
	var d := drunk
	spine.rotation.z = sin(_t * 1.3) * 0.16 * d
	head.rotation.x = lerp_angle(head.rotation.x, tgt.head_x + head_tilt.x + sin(_t * 0.9) * 0.12 * d, k)
	head.rotation.z = lerp_angle(head.rotation.z, head_tilt.y + sin(_t * 1.1 + 1.0) * 0.18 * d, k)
	spine.scale.y = 1.0 + sin(_t * 2.0) * 0.008

class_name ShoreMovement
extends RefCounted
## Поплавок держит ноги слишком низко для крутого склона. При движении к
## суше поднимаем их к рельефу впереди, сохраняя обычные столкновения тела.
## Работает на обоих озёрах, в протоке и у островов, без точек телепортации.

static func assist(body: CharacterBody3D, direction: Vector3) -> void:
	var p := body.global_position
	var depth := Terrain.depth(p.x, p.z)
	var near_shore := depth > 0.01 and depth < 3.0 and p.y < Terrain.WATER_Y + 0.5
	body.floor_max_angle = 1.35 if near_shore else 0.8
	if not near_shore or direction.length_squared() < 0.01:
		return
	var forward := Vector3(direction.x, 0, direction.z).normalized()
	var ahead := p + forward * 0.7
	var here_y := Terrain.height(p.x, p.z)
	var ahead_y := Terrain.height(ahead.x, ahead.z)
	# Помогаем только подняться по берегу, не всплывать посреди озера.
	if ahead_y <= here_y + 0.015 or ahead_y < Terrain.WATER_Y - 2.2:
		return
	var target_y := maxf(here_y, ahead_y) + 0.18
	var lift := clampf((target_y - p.y) * 7.0, 0.0, 5.0)
	body.velocity.y = maxf(body.velocity.y, lift)

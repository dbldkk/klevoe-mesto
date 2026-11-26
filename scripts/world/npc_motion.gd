class_name NpcMotion
extends RefCounted
## Land actors share shore avoidance and recovery; boats never use this helper.

static func safe_point(p: Vector3) -> Vector3:
	for ring in 18:
		for i in 12:
			var angle := TAU * i / 12.0
			var q := p + Vector3(cos(angle), 0, sin(angle)) * ring
			if q.x < Terrain.X0 + 2 or q.x > Terrain.X1 - 2 or q.z < Terrain.Z0 + 2 or q.z > Terrain.Z1 - 2:
				continue
			if Terrain.depth(q.x, q.z) <= 0.0 and Terrain.height(q.x, q.z) > Terrain.WATER_Y + 0.15:
				q.y = Terrain.height(q.x, q.z) + 0.15
				return q
	return Layout.spawn()


static func supported(body: CharacterBody3D, p: Vector3) -> bool:
	if not p.is_finite() or p.x < Terrain.X0 + 1 or p.x > Terrain.X1 - 1 or p.z < Terrain.Z0 + 1 or p.z > Terrain.Z1 - 1:
		return false
	if Terrain.depth(p.x, p.z) <= 0.05:
		return absf(Terrain.height(p.x, p.z) - body.global_position.y) < 1.1
	# A bridge or pier is valid even though the terrain below it is wet.
	var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.8, p + Vector3.DOWN * 1.5, 1, [body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and not hit.collider is Terrain and hit.normal.y > 0.6


static func move(body: CharacterBody3D, delta: float) -> void:
	var data: Dictionary = body.get_meta("land_motion", {})
	if data.is_empty():
		data = {"safe":safe_point(body.global_position), "check":0.0, "blocked":false}
		body.floor_snap_length = 0.45
	data.check -= delta
	if data.check <= 0.0:
		data.check = 0.12
		var at := body.global_position
		var below := at.is_finite() and at.y < Terrain.height(at.x, at.z) - 0.6
		var submerged := at.is_finite() and Terrain.depth(at.x, at.z) > 0.1 and at.y < Terrain.WATER_Y + 0.1
		if not at.is_finite() or below or submerged or absf(at.x) > 112.0 or at.z < -217.0 or at.z > 102.0:
			body.global_position = data.safe
			body.reset_physics_interpolation()
			body.velocity = Vector3.ZERO
		elif body.is_on_floor() and supported(body, at):
			data.safe = at + Vector3.UP * 0.08
		var flat := Vector3(body.velocity.x, 0, body.velocity.z)
		data["blocked"] = false
		if flat.length() > 0.1:
			var look := body.global_position + flat.normalized() * (0.75 + flat.length() * 0.12)
			if not supported(body, look):
				data["blocked"] = true
	if data.get("blocked",false):
		body.velocity.x = 0.0
		body.velocity.z = 0.0
	body.set_meta("land_motion", data)
	body.move_and_slide()

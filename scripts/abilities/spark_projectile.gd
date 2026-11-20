class_name SparkProjectile
extends Node3D
## Centelha Ancestral: bola de fogo que voa reto até o alcance e explode no
## primeiro obstáculo ou criatura. Usa um raio por quadro (do ponto anterior
## ao novo), então não atravessa nada mesmo rápido.

signal hit_target(target: Node, damage: float)
signal finished

var direction := Vector3.FORWARD
var speed := 20.0
var max_range := 15.0
var damage := 25.0
var source: Node3D
var color := Color(1, 0.55, 0.15)
## Camadas que param a centelha: mundo (1) e inimigos (4 = 8).
var collision_mask := 1 | 8

var _travelled := 0.0
var _done := false


func _ready() -> void:
	_build()


func _physics_process(delta: float) -> void:
	if _done:
		return
	var step := direction * speed * delta
	var from := global_position
	var to := from + step
	var params := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	if source is CollisionObject3D:
		params.exclude = [(source as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(params)
	if not hit.is_empty():
		global_position = hit["position"]
		var target: Object = hit["collider"]
		if target != null and target.has_method("receive_damage"):
			var info := DamageInfo.create(damage, &"player:ancestral_spark", &"fire", source)
			var applied: float = target.receive_damage(info)
			if target.has_method("apply_knockback"):
				target.apply_knockback(direction * 4.0)
			hit_target.emit(target, applied)
		_explode()
		return
	global_position = to
	_travelled += step.length()
	if _travelled >= max_range:
		_explode()


func _explode() -> void:
	_done = true
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.amount = 24
	burst.lifetime = 0.5
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.initial_velocity_min = 2.0
	burst.initial_velocity_max = 5.0
	burst.gravity = Vector3(0, 2, 0)
	burst.scale_amount_min = 0.06
	burst.scale_amount_max = 0.14
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 4
	mesh.rings = 2
	mesh.material = _glow_material(color)
	burst.mesh = mesh
	get_parent().add_child(burst)
	burst.global_position = global_position
	burst.emitting = true
	get_tree().create_timer(0.8).timeout.connect(burst.queue_free)
	finished.emit()
	queue_free()


func _glow_material(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _build() -> void:
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	sphere.radial_segments = 8
	sphere.rings = 4
	sphere.material = _glow_material(color.lightened(0.4))
	core.mesh = sphere
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 5.0
	add_child(light)
	var trail := CPUParticles3D.new()
	trail.amount = 30
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.spread = 20.0
	trail.initial_velocity_min = 0.2
	trail.initial_velocity_max = 0.6
	trail.gravity = Vector3(0, 1.5, 0)
	trail.scale_amount_min = 0.05
	trail.scale_amount_max = 0.1
	var tmesh := SphereMesh.new()
	tmesh.radius = 0.5
	tmesh.height = 1.0
	tmesh.radial_segments = 4
	tmesh.rings = 2
	tmesh.material = _glow_material(color)
	trail.mesh = tmesh
	add_child(trail)

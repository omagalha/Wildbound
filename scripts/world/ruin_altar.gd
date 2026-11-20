class_name RuinAltar
extends StaticBody3D
## Altar do Primeiro Fogo. Apagado até as marcas despertarem; desperto, o
## braseiro acende e pulsa; depois de concedida a recompensa, queima calmo
## para sempre (e, como todo fogo, espanta lobos à noite).

var ruin: AncestralRuin
var awake := false
var done := false
var _fire: MeshInstance3D
var _fire_mat: StandardMaterial3D
var _light: OmniLight3D
var _fear: FireLight
var _sparks: CPUParticles3D
var _time := 0.0


func _ready() -> void:
	collision_layer = 1 | 4
	collision_mask = 0
	_build()
	set_state(awake, done)


func _process(delta: float) -> void:
	_time += delta
	if _light != null and _light.visible:
		var pulse := 1.0 if done else 1.0 + sin(_time * 4.0) * 0.35
		_light.light_energy = 2.0 * pulse
		_fire.scale = Vector3.ONE * (0.9 + sin(_time * 7.0) * 0.08) * (1.0 if done else 1.2)


func get_interaction_prompt() -> String:
	if done:
		return "Altar do Primeiro Fogo"
	if awake:
		return "Tocar o altar desperto"
	return "Altar apagado (%d/%d marcas)" % [ruin.active_marks(), ruin.required_marks] if ruin != null else "Altar apagado"


func can_interact(_interactor: InteractionDetector) -> bool:
	return true


func interact(_interactor: InteractionDetector) -> Dictionary:
	return ruin.use_altar() if ruin != null else {"ok": false, "message": ""}


func set_state(is_awake: bool, is_done: bool) -> void:
	awake = is_awake
	done = is_done
	var lit := awake or done
	if _fire != null:
		_fire.visible = lit
		_light.visible = lit
		_fear.visible = lit
		_sparks.emitting = lit


func _build() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.4, 0.38, 0.36)
	stone.roughness = 1.0
	var base := BoxMesh.new()
	base.size = Vector3(1.6, 0.9, 1.6)
	base.material = stone
	var mi := MeshInstance3D.new()
	mi.mesh = base
	mi.position = Vector3(0, 0.7, 0)
	add_child(mi)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.2, 1.6)
	shape.shape = box
	shape.position = Vector3(0, 0.6, 0)
	add_child(shape)
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.6
	bowl.bottom_radius = 0.35
	bowl.height = 0.35
	bowl.radial_segments = 8
	bowl.rings = 0
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.2, 0.18, 0.17)
	bowl.material = dark
	var b := MeshInstance3D.new()
	b.mesh = bowl
	b.position = Vector3(0, 1.32, 0)
	add_child(b)
	_fire_mat = StandardMaterial3D.new()
	_fire_mat.albedo_color = Color(1.0, 0.6, 0.2)
	_fire_mat.emission_enabled = true
	_fire_mat.emission = Color(1.0, 0.45, 0.1)
	_fire_mat.emission_energy_multiplier = 4.0
	_fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var flame := CylinderMesh.new()
	flame.top_radius = 0.0
	flame.bottom_radius = 0.42
	flame.height = 0.9
	flame.radial_segments = 6
	flame.rings = 0
	flame.material = _fire_mat
	_fire = MeshInstance3D.new()
	_fire.mesh = flame
	_fire.position = Vector3(0, 1.9, 0)
	_fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fire)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.6, 0.3)
	_light.omni_range = 10.0
	_light.position = Vector3(0, 2.2, 0)
	add_child(_light)
	_fear = FireLight.new()
	_fear.radius = 9.0
	add_child(_fear)
	_sparks = CPUParticles3D.new()
	_sparks.amount = 20
	_sparks.lifetime = 1.4
	_sparks.direction = Vector3(0, 1, 0)
	_sparks.spread = 25.0
	_sparks.initial_velocity_min = 1.0
	_sparks.initial_velocity_max = 2.2
	_sparks.gravity = Vector3(0, 0.5, 0)
	_sparks.scale_amount_min = 0.03
	_sparks.scale_amount_max = 0.07
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.5
	spark_mesh.height = 1.0
	spark_mesh.radial_segments = 4
	spark_mesh.rings = 2
	spark_mesh.material = _fire_mat
	_sparks.mesh = spark_mesh
	_sparks.position = Vector3(0, 1.8, 0)
	add_child(_sparks)

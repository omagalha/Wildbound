class_name CreatureModel
extends Node
## Modelo animado de uma criatura (animais low-poly do Quaternius).
##
## Fica como filho da criatura (HostileCreature ou CreatureController). Coloca
## o modelo dentro do nó "Visual" da criatura, esconde as formas provisórias,
## ajusta o tamanho, troca cores por nome de material e toca a animação que a
## criatura pede em get_anim_state() ("idle", "walk", "run", "alert",
## "attack", "stunned", "eat", "happy", "death"). Dano recebido pisca o
## modelo e toca a reação de golpe.

@export var model_scene: PackedScene
## Comprimento do focinho à cauda, em metros (o modelo é escalado para isso).
@export var target_length: float = 1.2
## Giro extra se o modelo não olhar para +Z.
@export var yaw_offset_degrees: float = 0.0
## Nome do material -> nova cor.
@export var color_overrides: Dictionary = {}
## Nome do material -> cor de brilho (olhos que brilham no escuro).
@export var glow_overrides: Dictionary = {}
## Estado da criatura -> nome da animação no modelo.
@export var clips: Dictionary = {
	"idle": "Idle", "walk": "Walk", "run": "Gallop", "alert": "Idle_2_HeadLow",
	"attack": "Attack", "stunned": "Idle_HitReact2", "eat": "Eating",
	"happy": "Idle_2", "death": "Death", "hit": "Idle_HitReact1",
}
## Velocidade (m/s) em que andar e galopar tocam em ritmo normal.
@export var walk_reference_speed: float = 1.6
@export var run_reference_speed: float = 5.5

const LOOPING := ["idle", "walk", "run", "alert", "eat", "happy", "stunned"]

var model: Node3D
var anim: AnimationPlayer
var current := ""
var _creature: Node3D
var _hit_left := 0.0
var _flash_left := 0.0
var _flash_material: StandardMaterial3D
var _meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	_creature = get_parent() as Node3D
	var visual := _creature.get_node_or_null("Visual") as Node3D if _creature != null else null
	if model_scene == null or visual == null:
		return
	for child in visual.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
	model = model_scene.instantiate() as Node3D
	model.name = "Model"
	visual.add_child(model)
	model.rotation.y = deg_to_rad(yaw_offset_degrees)
	_fit_size()
	_apply_colors()
	anim = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer if not model.find_children("*", "AnimationPlayer", true, false).is_empty() else null
	if anim != null:
		for key in LOOPING:
			var clip_name: String = clips.get(key, "")
			if anim.has_animation(clip_name):
				anim.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.albedo_color = Color(1, 1, 1, 0.65)
	var health := _creature.get_node_or_null("Health") as HealthComponent
	if health != null:
		health.damaged.connect(_on_damaged)
	_play("idle")


func _physics_process(delta: float) -> void:
	if anim == null or not _creature.has_method("get_anim_state"):
		return
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			for mesh in _meshes:
				mesh.material_overlay = null
	var wanted: String = _creature.get_anim_state()
	if _hit_left > 0.0 and wanted != "death":
		_hit_left -= delta
		return
	var speed := Vector2(_creature.velocity.x, _creature.velocity.z).length() if "velocity" in _creature else 0.0
	match wanted:
		"walk": _play(wanted, clampf(speed / walk_reference_speed, 0.6, 1.8))
		"run": _play(wanted, clampf(speed / run_reference_speed, 0.7, 1.8))
		_: _play(wanted)


func has_clip(state: String) -> bool:
	return anim != null and anim.has_animation(clips.get(state, ""))


func _play(state: String, speed: float = 1.0) -> void:
	var clip_name: String = clips.get(state, "")
	if not anim.has_animation(clip_name):
		return
	anim.speed_scale = speed
	if current != state:
		anim.play(clip_name, 0.15)
		current = state


func _on_damaged(_info: DamageInfo) -> void:
	_flash_left = 0.12
	for mesh in _meshes:
		mesh.material_overlay = _flash_material
	if _creature.has_method("get_anim_state") and _creature.get_anim_state() == "death":
		return
	if has_clip("hit"):
		current = ""
		anim.speed_scale = 1.0
		anim.play(clips["hit"], 0.05)
		current = "hit"
		_hit_left = minf(anim.get_animation(clips["hit"]).length, 0.5)


func _fit_size() -> void:
	var box := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		_meshes.append(mesh)
		var local := model.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	var length := maxf(box.size.z, box.size.x)
	if length > 0.01 and target_length > 0.0:
		var s := target_length / length
		model.scale = Vector3.ONE * s
		model.position.y = -box.position.y * s  # patas no chão


func _apply_colors() -> void:
	for mesh in _meshes:
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var base := mesh.mesh.surface_get_material(i) as StandardMaterial3D
			if base == null:
				continue
			var key := base.resource_name
			if not color_overrides.has(key) and not glow_overrides.has(key):
				continue
			var mat := base.duplicate() as StandardMaterial3D
			if color_overrides.has(key):
				mat.albedo_color = color_overrides[key]
			if glow_overrides.has(key):
				mat.emission_enabled = true
				mat.emission = glow_overrides[key]
				mat.emission_energy_multiplier = 3.0
			mesh.set_surface_override_material(i, mat)

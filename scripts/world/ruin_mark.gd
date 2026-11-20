class_name RuinMark
extends StaticBody3D
## Marca ancestral: pedra em pé com uma runa. Apagada brilha fraco e pulsa
## (pista); acesa brilha forte e solta um feixe de luz para o céu, visível de
## longe. [E] acende (uma vez, para sempre).

var ruin: AncestralRuin
var index := 0
var active := false
var _rune_mat: StandardMaterial3D
var _beam: MeshInstance3D
var _light: OmniLight3D
var _time := 0.0


func _ready() -> void:
	collision_layer = 1 | 4
	collision_mask = 0
	_build()


func _process(delta: float) -> void:
	_time += delta
	if _rune_mat == null:
		return
	if active:
		_rune_mat.emission_energy_multiplier = 3.0 + sin(_time * 2.0) * 0.4
	else:
		_rune_mat.emission_energy_multiplier = 0.4 + (sin(_time * 2.5) * 0.5 + 0.5) * 0.6


func get_interaction_prompt() -> String:
	return "Tocar a marca ancestral"


func can_interact(_interactor: InteractionDetector) -> bool:
	return not active


func interact(_interactor: InteractionDetector) -> Dictionary:
	return ruin.activate_mark(index) if ruin != null else {"ok": false, "message": ""}


func set_active(value: bool) -> void:
	active = value
	if _beam != null:
		_beam.visible = value
	if _light != null:
		_light.light_energy = 1.6 if value else 0.3


func _build() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.45, 0.44, 0.42)
	stone.roughness = 1.0
	var slab := BoxMesh.new()
	slab.size = Vector3(0.9, 1.8, 0.35)
	slab.material = stone
	var mi := MeshInstance3D.new()
	mi.mesh = slab
	mi.position = Vector3(0, 0.9, 0)
	mi.rotation.z = 0.06
	add_child(mi)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 1.8, 0.4)
	shape.shape = box
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)
	_rune_mat = StandardMaterial3D.new()
	_rune_mat.albedo_color = Color(1.0, 0.6, 0.2)
	_rune_mat.emission_enabled = true
	_rune_mat.emission = Color(1.0, 0.5, 0.15)
	_rune_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for side in [-1.0, 1.0]:
		# Runa: um losango com um traço, nos dois lados da pedra.
		var rune := PrismMesh.new()
		rune.size = Vector3(0.36, 0.5, 0.02)
		rune.material = _rune_mat
		var r := MeshInstance3D.new()
		r.mesh = rune
		r.position = Vector3(0, 1.15, 0.185 * side)
		add_child(r)
		var bar := BoxMesh.new()
		bar.size = Vector3(0.06, 0.5, 0.02)
		bar.material = _rune_mat
		var b := MeshInstance3D.new()
		b.mesh = bar
		b.position = Vector3(0, 0.75, 0.185 * side)
		add_child(b)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.6, 0.25)
	_light.omni_range = 5.0
	_light.light_energy = 0.3
	_light.position = Vector3(0, 1.2, 0.6)
	add_child(_light)
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(1.0, 0.65, 0.3, 0.16)
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.emission_enabled = true
	beam_mat.emission = Color(1.0, 0.55, 0.2)
	beam_mat.emission_energy_multiplier = 0.6
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.05
	beam_mesh.bottom_radius = 0.14
	beam_mesh.height = 14.0
	beam_mesh.radial_segments = 8
	beam_mesh.rings = 0
	beam_mesh.material = beam_mat
	_beam = MeshInstance3D.new()
	_beam.mesh = beam_mesh
	_beam.position = Vector3(0, 8.8, 0)
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	add_child(_beam)

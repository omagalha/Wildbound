class_name InteractionMarker
extends Node3D
## Indicador animado sobre o objeto interativo em foco: um losango que brilha,
## gira e quica, com a tecla [E] embaixo, e um anel que pulsa no chão.
##
## Só escuta o InteractionDetector (focus_changed). Some com uma animação
## curta quando o foco sai.

@export var detector: InteractionDetector
## Folga acima do topo do objeto.
@export var height_margin: float = 0.45
@export var color: Color = Color(1.0, 0.84, 0.35)

var target: Node3D
var _time := 0.0
var _show := 0.0  # 0 escondido -> 1 visível (anima a entrada e a saída)
var _gem: MeshInstance3D
var _ring: MeshInstance3D
var _key: Label3D
var _top := 1.0


func _ready() -> void:
	_build()
	visible = false
	if detector != null:
		detector.focus_changed.connect(_on_focus_changed)


func _process(delta: float) -> void:
	_time += delta
	var wanted := 1.0 if target != null and is_instance_valid(target) else 0.0
	_show = move_toward(_show, wanted, delta * 6.0)
	visible = _show > 0.01
	if not visible:
		return
	if target != null and is_instance_valid(target):
		global_position = target.global_position
	var pop := _ease_out_back(_show)
	var bob := sin(_time * 4.0) * 0.08
	_gem.position.y = _top + height_margin + bob
	_gem.rotation.y = _time * 2.2
	_gem.scale = Vector3.ONE * pop * (1.0 + sin(_time * 8.0) * 0.06)
	_key.position.y = _gem.position.y - 0.32
	_key.modulate.a = _show
	_key.outline_modulate.a = _show
	var pulse := fmod(_time * 0.9, 1.0)
	_ring.scale = Vector3.ONE * lerpf(0.6, 1.3, pulse) * pop
	(_ring.material_override as StandardMaterial3D).albedo_color.a = (1.0 - pulse) * 0.6 * _show


func is_showing() -> bool:
	return target != null and visible


func _on_focus_changed(new_target: Node, _prompt: String) -> void:
	target = new_target as Node3D
	if target != null:
		_top = _height_of(target)
		global_position = target.global_position


## Altura do topo do objeto acima da origem (pela caixa dos visuais).
func _height_of(node: Node3D) -> float:
	var top := 0.6
	for child in node.find_children("*", "VisualInstance3D", true, false):
		var vis := child as VisualInstance3D
		if not vis.is_visible_in_tree():
			continue
		var box := vis.global_transform * vis.get_aabb()
		top = maxf(top, box.end.y - node.global_position.y)
	return minf(top, 4.0)


func _ease_out_back(t: float) -> float:
	var c := 1.70158
	return 1.0 + (c + 1.0) * pow(t - 1.0, 3) + c * pow(t - 1.0, 2)


func _build() -> void:
	var gem_mat := StandardMaterial3D.new()
	gem_mat.albedo_color = color
	gem_mat.emission_enabled = true
	gem_mat.emission = color
	gem_mat.emission_energy_multiplier = 1.6
	gem_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gem_mat.no_depth_test = true
	gem_mat.render_priority = 10
	var gem_mesh := CylinderMesh.new()  # dois cones = losango
	gem_mesh.top_radius = 0.0
	gem_mesh.bottom_radius = 0.13
	gem_mesh.height = 0.18
	gem_mesh.radial_segments = 4
	gem_mesh.rings = 0
	gem_mesh.material = gem_mat
	_gem = MeshInstance3D.new()
	_gem.name = "Gem"
	_gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_gem)
	var upper := MeshInstance3D.new()
	upper.mesh = gem_mesh
	upper.position.y = 0.09
	upper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gem.add_child(upper)
	var lower := MeshInstance3D.new()
	lower.mesh = gem_mesh
	lower.position.y = -0.09
	lower.rotation.x = PI
	lower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gem.add_child(lower)

	_key = Label3D.new()
	_key.name = "Key"
	_key.text = "E"
	_key.font_size = 64
	_key.outline_size = 16
	_key.pixel_size = 0.004
	_key.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_key.no_depth_test = true
	_key.modulate = Color(1, 1, 1)
	_key.outline_modulate = Color(0.1, 0.08, 0.02)
	add_child(_key)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(color.r, color.g, color.b, 0.6)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var torus := TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.7
	torus.rings = 24
	torus.ring_segments = 4
	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	_ring.mesh = torus
	_ring.material_override = ring_mat
	_ring.position.y = 0.05
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

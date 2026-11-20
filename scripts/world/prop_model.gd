@tool
class_name PropModel
extends Node3D
## Coloca um modelo do Fantasy Props (Quaternius) já corrigido.
##
## Os materiais vêm 100% metálicos (padrão da exportação) e, sem reflexos,
## o metal fica azul/preto: aqui o metal vira cinza fosco e a madeira, fosca.
## Opcionalmente cria colisão em caixa pelo tamanho do modelo (camada mundo).

@export var model: PackedScene:
	set(value):
		model = value
		if is_inside_tree():
			_rebuild()
@export var model_scale: float = 1.0:
	set(value):
		model_scale = value
		if is_inside_tree():
			_rebuild()
## Cria uma caixa de colisão (camada 1) do tamanho do modelo.
@export var solid: bool = false
## Tinge todas as superfícies (branco = cor original).
@export var tint: Color = Color.WHITE

var instance: Node3D
var _body: StaticBody3D

static var _material_cache := {}  # material original + tinta -> corrigido


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if instance != null:
		instance.queue_free()
		instance = null
	if _body != null:
		_body.queue_free()
		_body = null
	if model == null:
		return
	instance = model.instantiate() as Node3D
	instance.scale = Vector3.ONE * model_scale
	add_child(instance)
	fix_materials(instance, tint)
	if solid and not Engine.is_editor_hint():
		_add_collision()


## Corrige os materiais de todas as malhas sob [param root].
static func fix_materials(root: Node, tint_color: Color = Color.WHITE) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for i in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if base == null:
				continue
			var key := "%d|%s" % [base.get_instance_id(), tint_color.to_html()]
			if not _material_cache.has(key):
				var mat := base.duplicate() as StandardMaterial3D
				var is_metal := base.resource_name.to_lower().contains("metal")
				mat.metallic = 0.0
				mat.metallic_texture = null
				mat.roughness = 0.6 if is_metal else 0.85
				mat.albedo_color = mat.albedo_color * tint_color
				_material_cache[key] = mat
			mi.set_surface_override_material(i, _material_cache[key])


## Caixa que envolve o modelo, no espaço deste nó.
func bounds() -> AABB:
	var box := AABB()
	var first := true
	if instance == null:
		return box
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var local := global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box


func _add_collision() -> void:
	var box := bounds()
	if box.size.length() < 0.01:
		return
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = box.size
	shape.shape = b
	shape.position = box.get_center()
	_body.add_child(shape)
	add_child(_body)

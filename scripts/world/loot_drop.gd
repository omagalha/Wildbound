class_name LootDrop
extends StaticBody3D
## Itens largados no chão (ex.: carne de um javali abatido). [E] para pegar.
##
## Fica só na camada de interativos (não bloqueia ninguém). Pega o quanto
## couber no inventário; o resto continua no chão. Some sozinho depois de
## [member lifetime] segundos. Não é salvo: é uma recompensa do momento.

signal collected(items: Dictionary)

@export var items: Dictionary = {}
@export var label: String = "Restos"
@export var lifetime: float = 180.0

var _age := 0.0
var _visual: Node3D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	shape.shape = sphere
	shape.position = Vector3(0, 0.3, 0)
	add_child(shape)
	_build_visual()


func _physics_process(delta: float) -> void:
	_age += delta
	if _visual != null:
		_visual.rotation.y += delta * 1.2
		_visual.position.y = 0.25 + sin(_age * 3.0) * 0.05
	if lifetime > 0.0 and _age >= lifetime:
		queue_free()


func get_interaction_prompt() -> String:
	return "Pegar %s" % _items_text()


func can_interact(_interactor: InteractionDetector) -> bool:
	return not items.is_empty()


func interact(interactor: InteractionDetector) -> Dictionary:
	var inventory: Inventory = interactor.inventory if interactor != null else null
	if inventory == null or items.is_empty():
		return {"ok": false, "message": "Nada para pegar"}
	var taken := {}
	for id in items.keys():
		var got := inventory.add_up_to(StringName(id), int(items[id]))
		if got > 0:
			taken[id] = got
			items[id] = int(items[id]) - got
			if int(items[id]) <= 0:
				items.erase(id)
	if taken.is_empty():
		return {"ok": false, "message": "Inventário cheio"}
	collected.emit(taken)
	var parts := []
	for id in taken:
		parts.append("+%d %s" % [taken[id], _item_name(inventory, StringName(id))])
	if items.is_empty():
		queue_free()
	return {"ok": true, "message": " · ".join(parts)}


const CATALOG_PATH := "res://resources/items/item_catalog.tres"


func _items_text() -> String:
	var catalog := load(CATALOG_PATH) as ItemCatalog
	var parts := []
	for id in items:
		var item := catalog.get_item(StringName(id)) if catalog != null else null
		parts.append("%d %s" % [int(items[id]), item.display_name if item != null else String(id)])
	return ", ".join(parts) if not parts.is_empty() else label


func _item_name(inventory: Inventory, id: StringName) -> String:
	var item := inventory.catalog.get_item(id) if inventory.catalog != null else null
	return item.display_name if item != null else String(id)


func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.3, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.15, 0.1)
	mat.emission_energy_multiplier = 0.4
	mat.roughness = 0.8
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.26
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = mat
	for i in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = Vector3(-0.12 + i * 0.24, 0, 0)
		mi.rotation.z = 0.5 - i
		_visual.add_child(mi)
	var bone_mat := StandardMaterial3D.new()
	bone_mat.albedo_color = Color(0.95, 0.92, 0.85)
	var bone := CylinderMesh.new()
	bone.top_radius = 0.03
	bone.bottom_radius = 0.03
	bone.height = 0.4
	bone.radial_segments = 5
	bone.rings = 0
	bone.material = bone_mat
	var bmi := MeshInstance3D.new()
	bmi.mesh = bone
	bmi.rotation.z = PI * 0.5
	_visual.add_child(bmi)

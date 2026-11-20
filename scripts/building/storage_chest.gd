class_name StorageChest
extends BuildingPiece
## Baú: guarda itens na base. [E] abre o ChestMenu (que escuta o
## InteractionDetector). O conteúdo é um Inventory próprio, vai para o save
## e impede a remoção enquanto houver algo dentro.

signal opened
signal closed

@onready var storage: Inventory = $Storage
## Tampa: osso "Chest_Top" do modelo (ou um nó "Lid" nas versões antigas).
@onready var _lid: Node3D = get_node_or_null("Lid")
var _skeleton: Skeleton3D
var _lid_bone := -1
var _lid_rest := Quaternion.IDENTITY

var is_open := false
var _lid_angle := 0.0


func _ready() -> void:
	var model := get_node_or_null("Model")
	if model != null:
		var found := model.find_children("*", "Skeleton3D", true, false)
		if not found.is_empty():
			_skeleton = found[0]
			_lid_bone = _skeleton.find_bone("Chest_Top")
			if _lid_bone >= 0:
				_lid_rest = _skeleton.get_bone_pose_rotation(_lid_bone)


func _physics_process(delta: float) -> void:
	var target := -1.15 if is_open else 0.0
	_lid_angle = move_toward(_lid_angle, target, delta * 5.0)
	if _lid != null:
		_lid.rotation.x = _lid_angle
	elif _lid_bone >= 0:
		_skeleton.set_bone_pose_rotation(_lid_bone, _lid_rest * Quaternion(Vector3.RIGHT, _lid_angle))


func lid_angle() -> float:
	return _lid_angle


func get_interaction_prompt() -> String:
	if storage == null or storage.get_all().is_empty():
		return "Abrir baú (vazio)"
	return "Abrir baú (%d/%d)" % [storage.used_slots(), storage.capacity]


func can_interact(_interactor: InteractionDetector) -> bool:
	return piece_id != &""


func interact(_interactor: InteractionDetector) -> Dictionary:
	return {"ok": true, "message": "", "open_chest": true}


func set_open(value: bool) -> void:
	if is_open == value:
		return
	is_open = value
	if value:
		opened.emit()
	else:
		closed.emit()


func blocks_removal() -> bool:
	return storage != null and not storage.get_all().is_empty()


func get_piece_data() -> Dictionary:
	var items := {}
	var all := storage.get_all()
	for id in all:
		items[String(id)] = all[id]
	return {"items": items}


func apply_piece_data(data: Dictionary) -> void:
	if typeof(data.get("items")) == TYPE_DICTIONARY:
		storage.load_counts(data["items"])


## Move até [param amount] de [param id] de um inventário para outro.
## Devolve quanto foi movido (nunca some nem duplica item).
static func transfer(from: Inventory, to: Inventory, id: StringName, amount: int) -> int:
	if from == null or to == null or amount <= 0:
		return 0
	var available := mini(from.count(id), amount)
	if available <= 0:
		return 0
	var moved := to.add_up_to(id, available)
	if moved > 0:
		from.remove_item(id, moved)
	return moved

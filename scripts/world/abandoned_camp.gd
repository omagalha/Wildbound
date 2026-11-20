class_name AbandonedCamp
extends Node3D
## Acampamento abandonado: barris, caixotes, bancada, saco e uma fogueira
## apagada, arrumados ao redor do centro com sorteio fixo pela semente.
## Abre clareira na floresta procedural. Tem um baú com saque sorteado na
## primeira vez; o conteúdo vai para o save (por nome do acampamento), então
## um baú esvaziado continua vazio. Chegar perto avisa e dá XP de descoberta.

signal discovered(camp: AbandonedCamp)

const CHEST_SCENE := "res://scenes/building/storage_chest.tscn"
## [item, mínimo, máximo, chance]
const LOOT_TABLE := [
	[&"wood", 4, 10, 0.8], [&"stone", 3, 8, 0.7], [&"fiber", 4, 10, 0.7],
	[&"flint", 1, 4, 0.5], [&"wild_berries", 3, 8, 0.6], [&"cooked_meat", 1, 3, 0.45],
	[&"bandage", 1, 3, 0.5], [&"torch", 1, 1, 0.3], [&"iron_ore", 2, 5, 0.3],
	[&"iron_ingot", 1, 2, 0.12],
]

const PROPS := [
	["res://assets/props/Barrel.gltf", true], ["res://assets/props/Barrel_Apples.gltf", true],
	["res://assets/props/Crate_Wooden.gltf", true], ["res://assets/props/Bag.gltf", false],
	["res://assets/props/Bucket_Wooden_1.gltf", false], ["res://assets/props/FarmCrate_Apple.gltf", false],
	["res://assets/props/Stool.gltf", false], ["res://assets/props/Pot_1.gltf", false],
]
const CENTERPIECES := [
	"res://assets/props/Workbench.gltf", "res://assets/props/WeaponStand.gltf",
	"res://assets/props/Cauldron.gltf", "res://assets/props/Bench.gltf",
]

@export var camp_seed: int = 1
@export var prop_count: int = 11
@export var clear_radius: float = 9.0
@export var camp_name: String = "Acampamento abandonado"
@export var discovery_radius: float = 12.0
@export var player: Node3D
@export var experience: ExperienceComponent
@export var hud: SurvivalHUD

var chest: StorageChest
var is_discovered := false
var _check_left := 0.0


func _ready() -> void:
	add_to_group(&"forest_clearing")
	add_to_group(&"abandoned_camps")
	var rng := RandomNumberGenerator.new()
	rng.seed = camp_seed
	_campfire_remains()
	var center: String = CENTERPIECES[rng.randi() % CENTERPIECES.size()]
	_place(center, true, Vector3(0, 0, -2.6), rng.randf_range(-0.3, 0.3))
	for i in prop_count:
		var spec: Array = PROPS[rng.randi() % PROPS.size()]
		var angle := TAU * i / prop_count + rng.randf_range(-0.25, 0.25)
		var dist := rng.randf_range(1.7, 3.6)
		var pos := Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		if pos.distance_to(Vector3(0, 0, -2.6)) < 1.4:
			continue
		_place(spec[0], spec[1], pos, rng.randf() * TAU)
	_spawn_chest()


func _process(delta: float) -> void:
	if is_discovered or player == null:
		return
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = 0.5
	var d := player.global_position - global_position
	d.y = 0.0
	if d.length() <= discovery_radius:
		discover()


func discover() -> void:
	if is_discovered:
		return
	is_discovered = true
	if experience != null and experience.rules != null:
		experience.award_first(&"discovery", StringName("camp_" + String(name)), experience.rules.discovery_xp)
	if hud != null:
		hud.show_message("Você encontrou: %s. Talvez ainda haja algo no baú." % camp_name, 4.0)
	discovered.emit(self)


## Saque sorteado pela semente (mesmo resultado sempre, até o save mudar).
static func roll_loot(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13
	var loot := {}
	for entry in LOOT_TABLE:
		if rng.randf() < float(entry[3]):
			loot[entry[0]] = rng.randi_range(int(entry[1]), int(entry[2]))
	if loot.size() < 3:
		loot[&"wood"] = int(loot.get(&"wood", 0)) + 6
		loot[&"bandage"] = int(loot.get(&"bandage", 0)) + 1
	return loot


func _spawn_chest() -> void:
	chest = (load(CHEST_SCENE) as PackedScene).instantiate() as StorageChest
	chest.name = "LootChest"
	chest.piece_id = StringName("camp_" + String(name))  # interativo, mas não é peça do jogador
	add_child(chest)
	chest.position = Vector3(2.4, 0, -2.2)
	chest.rotation.y = -0.6
	chest.storage.load_counts(roll_loot(camp_seed))


func get_save_data() -> Dictionary:
	var data := chest.get_piece_data() if chest != null else {}
	data["discovered"] = is_discovered
	return data


func apply_save_data(data: Dictionary) -> void:
	if chest != null:
		chest.apply_piece_data(data)
	is_discovered = bool(data.get("discovered", false))


func _place(path: String, solid: bool, pos: Vector3, yaw: float) -> PropModel:
	var prop := PropModel.new()
	prop.solid = solid
	prop.model = load(path)
	add_child(prop)
	prop.position = pos
	prop.rotation.y = yaw
	return prop


## Pedras em roda e toras queimadas no centro.
func _campfire_remains() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.45, 0.44, 0.42)
	stone.roughness = 1.0
	var ash := StandardMaterial3D.new()
	ash.albedo_color = Color(0.12, 0.11, 0.1)
	ash.roughness = 1.0
	for i in 8:
		var a := TAU * i / 8.0
		var mesh := SphereMesh.new()
		mesh.radius = 0.18
		mesh.height = 0.22
		mesh.radial_segments = 5
		mesh.rings = 2
		mesh.material = stone
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = Vector3(cos(a) * 0.65, 0.07, sin(a) * 0.65)
		add_child(mi)
	for i in 3:
		var log := CylinderMesh.new()
		log.top_radius = 0.07
		log.bottom_radius = 0.08
		log.height = 0.8
		log.radial_segments = 6
		log.rings = 0
		log.material = ash
		var mi := MeshInstance3D.new()
		mi.mesh = log
		mi.position = Vector3(0, 0.08, 0)
		mi.rotation = Vector3(PI * 0.5, TAU * i / 3.0, 0)
		add_child(mi)

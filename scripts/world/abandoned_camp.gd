class_name AbandonedCamp
extends Node3D
## Acampamento abandonado: barris, caixotes, bancada, saco e uma fogueira
## apagada, arrumados ao redor do centro com sorteio fixo pela semente.
## Só decoração com colisão; abre clareira na floresta procedural.

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


func _ready() -> void:
	add_to_group(&"forest_clearing")
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

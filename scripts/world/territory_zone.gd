class_name TerritoryZone
extends Node3D
## Zona circular do mundo (Territory Raids 2, MVP): segura ou de atenção.
## Criaturas hostis nunca perseguem dentro de uma zona segura.

enum Level { SAFE, ATTENTION }

@export var zone_name: String = "Clareira inicial"
@export var level: Level = Level.SAFE
@export var radius: float = 20.0
## Uma frase curta mostrada no HUD.
@export var description: String = ""


func _ready() -> void:
	add_to_group(&"territory_zones")


func contains(point: Vector3) -> bool:
	var d := point - global_position
	d.y = 0.0
	return d.length() <= radius


func level_text() -> String:
	return "Zona segura" if level == Level.SAFE else "Zona de atenção"


## A zona que contém o ponto (atenção vence segura se sobrepostas), ou null.
static func zone_at(tree: SceneTree, point: Vector3) -> TerritoryZone:
	var found: TerritoryZone = null
	for node in tree.get_nodes_in_group(&"territory_zones"):
		var zone := node as TerritoryZone
		if zone != null and zone.contains(point):
			if found == null or zone.level > found.level:
				found = zone
	return found


static func is_safe(tree: SceneTree, point: Vector3) -> bool:
	var zone := zone_at(tree, point)
	return zone != null and zone.level == Level.SAFE

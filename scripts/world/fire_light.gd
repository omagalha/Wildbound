class_name FireLight
extends Node3D
## Uma fonte de fogo que espanta criaturas que temem a luz (Lobos Sombrios).
##
## Está ativa enquanto estiver visível na árvore: a tocha só aparece acesa,
## e a fogueira fica sempre acesa. As criaturas consultam
## [method is_point_lit] em vez de varrer luzes da cena.

const GROUP := &"fire_lights"

## Raio de proteção, em metros.
@export var radius: float = 7.0


func _ready() -> void:
	add_to_group(GROUP)


func is_active() -> bool:
	if not is_inside_tree() or not is_visible_in_tree():
		return false
	# A prévia do modo de construção não tem id: ainda não é uma fogueira de verdade.
	var piece := get_parent() as BuildingPiece
	return piece == null or piece.piece_id != &""


## Algum fogo ativo protege [param point]? [param margin] aumenta o raio.
static func is_point_lit(tree: SceneTree, point: Vector3, margin: float = 0.0) -> bool:
	if tree == null:
		return false
	for node in tree.get_nodes_in_group(GROUP):
		var fire := node as FireLight
		if fire == null or not fire.is_active():
			continue
		var d := fire.global_position - point
		d.y = 0.0
		if d.length() <= fire.radius + margin:
			return true
	return false

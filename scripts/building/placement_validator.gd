class_name PlacementValidator
extends RefCounted
## Verificações geométricas de posicionamento (GDD 011, seções 4, 5 e 9).
##
## Só lê o mundo; nunca altera estado. Todas as consultas são feitas sob demanda
## (quando a prévia muda), nunca como varredura do mundo.

const WORLD_MASK := 1
const BLOCKING_MASK := 1 | 2  # mundo + jogador: não se constrói em cima de ninguém

var _space: PhysicsDirectSpaceState3D


func _init(space: PhysicsDirectSpaceState3D) -> void:
	_space = space


## true se a caixa de validação da peça colide com algo do mundo ou com o jogador.
func overlaps(definition: BuildingPieceDefinition, transform: Transform3D) -> bool:
	var shape := BoxShape3D.new()
	shape.size = definition.validation_size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = transform * Transform3D(Basis.IDENTITY, definition.validation_center)
	query.collision_mask = BLOCKING_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return not _space.intersect_shape(query, 1).is_empty()


## Raio para baixo a partir de [param from]. Devolve {} se não acertar nada.
func ray_down(from: Vector3, depth: float, exclude: Array[RID] = []) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * depth, WORLD_MASK, exclude)
	return _space.intersect_ray(query)


## Chão sob os quatro cantos de uma fundação livre: desnível máximo e inclinação.
## Devolve "" se estiver tudo certo, ou o motivo.
func check_ground_corners(transform: Transform3D, half_extent: float, max_height_diff: float, max_slope_degrees: float) -> String:
	var heights: Array[float] = []
	var min_up := cos(deg_to_rad(max_slope_degrees))
	for corner in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
		var point: Vector3 = transform * (corner * half_extent)
		var hit := ray_down(point + Vector3.UP * 1.0, 2.0)
		if hit.is_empty() or hit.get("collider") is BuildingPiece:
			return "Sem chão firme"
		if (hit["normal"] as Vector3).y < min_up:
			return "Terreno inclinado demais"
		heights.append((hit["position"] as Vector3).y)
	if heights.max() - heights.min() > max_height_diff:
		return "Terreno irregular demais"
	return ""


## Apoio de um objeto livre: três pontos da base precisam tocar uma superfície logo abaixo.
func check_free_support(definition: BuildingPieceDefinition, transform: Transform3D, tolerance: float = 0.2) -> String:
	var half := definition.validation_size * 0.5
	var base_y := transform.origin.y
	for offset in [Vector3(-half.x, 0, -half.z), Vector3(half.x, 0, -half.z), Vector3(0, 0, half.z)]:
		var point: Vector3 = transform * offset
		var hit := ray_down(point + Vector3.UP * 0.5, 0.5 + tolerance + 0.3)
		if hit.is_empty() or absf((hit["position"] as Vector3).y - base_y) > tolerance:
			return "Sem apoio sob o objeto"
	return ""

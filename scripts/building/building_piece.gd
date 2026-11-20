class_name BuildingPiece
extends StaticBody3D
## Raiz de toda peça construída. Fica na camada "world" (1): jogador, câmera e
## criaturas colidem com ela. A prévia usa a mesma cena sem colisão.

## Id estável, gerado ao construir.
var piece_id: StringName = &""
var definition: BuildingPieceDefinition
## Peça que apoia esta (fundação sob uma parede, telhado ou objeto). Vazio = chão.
var support_id: StringName = &""
## Tempo de jogo (s) em que foi colocada; usado na janela de devolução de 10 s.
var placed_at: float = 0.0


func get_snap_points() -> Array[SnapPoint]:
	var points: Array[SnapPoint] = []
	for child in find_children("*", "SnapPoint", true, false):
		points.append(child as SnapPoint)
	return points


## Desliga colisão e aplica um material de prévia em todas as malhas.
func make_preview(material: Material) -> void:
	collision_layer = 0
	collision_mask = 0
	for node in find_children("*", "CollisionShape3D", true, false):
		(node as CollisionShape3D).disabled = true
	for node in find_children("*", "Light3D", true, false):
		(node as Light3D).visible = false
	set_preview_material(material)


func set_preview_material(material: Material) -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = material
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

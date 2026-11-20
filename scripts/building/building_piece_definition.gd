class_name BuildingPieceDefinition
extends Resource
## Dados de uma peça de construção (GDD 011). Sem lógica além de consultas simples.

enum Kind { STRUCTURAL, FREE }

## Id estável (salvo no save; nunca renomear).
@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.STRUCTURAL
## Tipo de encaixe que a peça ocupa: "foundation", "wall" ou "roof". Vazio = livre.
@export var snap_type: StringName = &""
## Custo em itens: {id_do_item: quantidade}.
@export var cost: Dictionary = {}
@export var scene: PackedScene
## Caixa usada para checar sobreposição (local, já reduzida para encostar sem colidir).
@export var validation_size: Vector3 = Vector3.ONE
@export var validation_center: Vector3 = Vector3.ZERO
## Fundação pode ser colocada sozinha no terreno, sem encaixe.
@export var allows_free_ground_placement: bool = false
## Inclinação máxima do terreno (graus) para peças apoiadas no chão.
@export var max_slope_degrees: float = 20.0
## Conhecimento exigido (GDD 010; no MVP, liberado por nível). Vazio = nenhum.
@export var required_knowledge: StringName = &""
## Telhado: exige pelo menos uma parede na fundação abaixo (GDD 011, seção 4).
@export var needs_wall_support: bool = false


func is_structural() -> bool:
	return kind == Kind.STRUCTURAL


func cost_text(catalog: ItemCatalog) -> String:
	var parts: PackedStringArray = []
	for item_id in cost:
		var item := catalog.get_item(item_id) if catalog != null else null
		parts.append("%d %s" % [int(cost[item_id]), item.display_name if item != null else String(item_id)])
	return ", ".join(parts)

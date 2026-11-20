class_name ItemDefinition
extends Resource
## Dados de um tipo de item. Sem lógica.
##
## O id é estável e nunca deve ser renomeado depois de publicado
## (saves futuros guardam ids, nunca referências a recursos).

@export var id: StringName = &""
@export var display_name: String = ""
## Quantidade máxima por espaço do inventário.
@export_range(1, 999) var max_stack: int = 50
## Fome recuperada ao comer. 0 = não é comida.
@export_range(0.0, 100.0) var food_value: float = 0.0


func is_food() -> bool:
	return food_value > 0.0

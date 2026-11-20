class_name CraftingRecipe
extends Resource
## Uma receita de fabricação. Só dados.
##
## O id é estável (o save e o XP de "primeira fabricação" guardam ids).

@export var id: StringName = &""
@export var display_name: String = ""
## Frase curta mostrada no menu (o que o item faz).
@export var description: String = ""
## Itens consumidos: id -> quantidade.
@export var inputs: Dictionary = {}
## Itens produzidos: id -> quantidade.
@export var outputs: Dictionary = {}
## Estação exigida por perto: &"" (nenhuma) ou &"campfire".
@export var station: StringName = &""
## Conhecimento exigido (vem da subida de nível). Vazio = sempre disponível.
@export var required_knowledge: StringName = &""

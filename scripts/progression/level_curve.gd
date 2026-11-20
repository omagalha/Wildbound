class_name LevelCurve
extends Resource
## Curva de níveis e desbloqueios automáticos (GDD 009/010).
##
## XP para passar do nível L para L+1 = base_xp + step_xp × (L − 1)
## (100, 150, 200, 250…: acumulados 100 / 250 / 450 / 700 no MVP — KNOWLEDGE_TREE.md 10.2).

@export var base_xp: int = 100
@export var step_xp: int = 50
@export var max_level: int = 5
## Nomes dos níveis (índice 0 = nível 1).
@export var level_names: PackedStringArray = []
## Desbloqueios automáticos: {nível: [ids de conhecimento]} (origem "auto_level").
@export var unlocks: Dictionary = {}
## Nomes exibidos dos conhecimentos: {id: nome}.
@export var knowledge_names: Dictionary = {}


## XP acumulado necessário para estar no nível informado.
func xp_for_level(level: int) -> int:
	var total := 0
	for l in range(1, clampi(level, 1, max_level)):
		total += base_xp + step_xp * (l - 1)
	return total


func level_for_xp(xp: int) -> int:
	var level := 1
	while level < max_level and xp >= xp_for_level(level + 1):
		level += 1
	return level


func level_name(level: int) -> String:
	return level_names[level - 1] if level >= 1 and level <= level_names.size() else ""


func unlocks_at(level: int) -> Array:
	return Array(unlocks.get(level, []))


## Nível que libera um conhecimento, ou 0 se nenhum.
func level_unlocking(knowledge_id: StringName) -> int:
	for level in unlocks:
		if Array(unlocks[level]).has(knowledge_id) or Array(unlocks[level]).has(String(knowledge_id)):
			return int(level)
	return 0


func knowledge_name(knowledge_id: StringName) -> String:
	return String(knowledge_names.get(knowledge_id, knowledge_names.get(String(knowledge_id), String(knowledge_id))))

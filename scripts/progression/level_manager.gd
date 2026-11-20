class_name LevelManager
extends Node
## Nível geral de sobrevivente (GDD 009/010). Calculado a partir do XP pela
## [LevelCurve]; ao subir, aprende automaticamente os conhecimentos do nível
## (origem "auto_level", já no formato que a árvore da 1.0 vai migrar).
##
## Efeito do MVP: "knowledge_gathering_capacity" (nível 4) dá +5 espaços de inventário
## (escolha provisória para a pendência P-PG-04).

signal level_up(new_level: int, level_name: String, unlocked: Array)

const CAPACITY_KNOWLEDGE := &"knowledge_gathering_capacity"

@export var curve: LevelCurve
@export var experience: ExperienceComponent
@export var knowledge: KnowledgeManager
@export var inventory: Inventory
@export var base_inventory_capacity: int = 20
@export var capacity_bonus: int = 5

var level: int = 1


func _ready() -> void:
	if experience != null:
		experience.xp_changed.connect(_on_xp_changed)
	_learn_up_to(level, false)


func xp_into_level() -> int:
	return experience.total_xp - curve.xp_for_level(level) if experience != null and curve != null else 0


func xp_needed_for_next() -> int:
	if curve == null or level >= curve.max_level:
		return 0
	return curve.xp_for_level(level + 1) - curve.xp_for_level(level)


func is_max_level() -> bool:
	return curve != null and level >= curve.max_level


## Ajusta o nível a um XP salvo (carregamento). Sem notificações; desbloqueios unidos.
func sync_to_xp(xp: int) -> void:
	if curve == null:
		return
	level = curve.level_for_xp(xp)
	_learn_up_to(level, false)


func _on_xp_changed(total: int) -> void:
	if curve == null:
		return
	var target := curve.level_for_xp(total)
	while level < target:
		level += 1
		var unlocked := _learn_level(level)
		level_up.emit(level, curve.level_name(level), unlocked)


func _learn_up_to(target: int, _notify: bool) -> void:
	for l in range(1, target + 1):
		_learn_level(l)
	_apply_effects()


func _learn_level(l: int) -> Array:
	var learned := []
	if knowledge == null or curve == null:
		return learned
	for id in curve.unlocks_at(l):
		if knowledge.learn(StringName(id), KnowledgeManager.ORIGIN_AUTO_LEVEL):
			learned.append(StringName(id))
	_apply_effects()
	return learned


## Efeitos idempotentes dos conhecimentos (seguro chamar várias vezes).
func _apply_effects() -> void:
	if inventory != null and knowledge != null:
		inventory.capacity = base_inventory_capacity + (capacity_bonus if knowledge.is_known(CAPACITY_KNOWLEDGE) else 0)

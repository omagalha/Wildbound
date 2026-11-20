class_name KnowledgeManager
extends Node
## Conhecimentos aprendidos (GDD 010). No MVP todos vêm do nível ("auto_level");
## a 1.0 acrescenta compra com pontos. Construção e domesticação só consultam
## [method is_known] — nenhuma regra de conhecimento é duplicada nesses sistemas.

signal knowledge_learned(id: StringName, origin: StringName)

const ORIGIN_AUTO_LEVEL := &"auto_level"

var _known: Dictionary = {}  # StringName -> origem


func is_known(id: StringName) -> bool:
	return id == &"" or _known.has(id)


func learn(id: StringName, origin: StringName = ORIGIN_AUTO_LEVEL) -> bool:
	if id == &"" or _known.has(id):
		return false  # nunca duplica
	_known[id] = origin
	knowledge_learned.emit(id, origin)
	return true


func get_all() -> Dictionary:
	return _known.duplicate()


## Restaura do save, unindo ao que já se sabe (desbloqueios nunca se perdem).
func restore(data: Dictionary) -> void:
	for id in data:
		if not _known.has(StringName(id)):
			_known[StringName(id)] = StringName(data[id])

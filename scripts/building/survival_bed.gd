class_name SurvivalBed
extends BuildingPiece
## Leito de Sobrevivência (GDD 008/011): objeto livre que pode virar o ponto de respawn.
##
## Construir não ativa o leito: o jogador precisa interagir com ele.
## Também fica na camada 3 para ser encontrado pelo InteractionDetector.

signal set_as_respawn_requested(bed: SurvivalBed)

var is_active_respawn := false


func get_interaction_prompt() -> String:
	return "Ponto de retorno (ativo)" if is_active_respawn else "Definir como ponto de retorno"


func can_interact(_interactor: InteractionDetector) -> bool:
	return not is_active_respawn


func interact(_interactor: InteractionDetector) -> Dictionary:
	if is_active_respawn:
		return {"ok": false, "message": "Este leito já é o ponto de retorno"}
	set_as_respawn_requested.emit(self)
	return {"ok": true, "message": "Ponto de retorno definido"}
